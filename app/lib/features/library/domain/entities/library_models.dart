import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';

/// 좌석 상태.
///
/// 실제 백엔드는 `available` / `occupied` / `fixed` / `unavailable` 4종이지만
/// 클라이언트에는 `reserved`(내가 예약 보류 중) 같은 상태도 추가될 수 있음.
enum SeatStatus {
  available,
  occupied,
  fixed,
  unavailable;

  bool get isReservable => this == SeatStatus.available;

  String get label => switch (this) {
    SeatStatus.available => '사용가능',
    SeatStatus.occupied => '사용중',
    SeatStatus.fixed => '고정석',
    SeatStatus.unavailable => '사용불가',
  };

  Color get color => switch (this) {
    SeatStatus.available => AppColors.primary, // 크림슨 (대학 상징색)
    SeatStatus.occupied => const Color(0xFF94A3B8), // slate-400
    SeatStatus.fixed => const Color(0xFFC8A24B), // 학교 골드 액센트
    SeatStatus.unavailable => const Color(0xFF1A1A1A), // 거의 검정
  };

  Color get onColor => Colors.white;
}

/// 단일 좌석의 캔버스 좌표 (원본 811×1441 기준 픽셀).
class SeatPosition {
  const SeatPosition({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.wing,
  });

  final int id;
  final double x;
  final double y;
  final double w;
  final double h;

  /// 통합 열람실(제1=1112, 제4=1516)에서만 'A'/'B'. 단일 열람실은 null.
  /// 예약·좌석맵 호출 시 실 room_no 분기에 사용 ([resolveLibseatRoomNo]).
  final String? wing;

  Rect get rect => Rect.fromLTWH(x, y, w, h);
}

/// 통합 가상 열람실 ID에서 실제 libseat `room_no`를 복원한다.
///
/// 학술정보원은 제1·제4열람실을 시스템상 A/B 두 room_no로 나눠 운영한다
/// (제1=11·12, 제4=15·16). 앱은 물리적으로 같은 공간이라 1112/1516 가상 ID로
/// 묶어 한 좌석맵에 노출하지만, **예약(setSeat.php)은 반드시 실 room_no로**
/// 호출해야 한다. 가상 ID를 그대로 보내면 서버가 "자율 발권으로 모바일 좌석
/// 예약을 이용하실 수 없습니다." 로 거절한다.
///
/// 4자리 가상 ID 규약: `앞 2자리 = A wing, 뒤 2자리 = B wing`
/// (1112 → A:11/B:12, 1516 → A:15/B:16). 2자리 실 room_no는 그대로 반환.
/// wing이 null인 통합석은 안전하게 A(앞 2자리)로 간주.
int resolveLibseatRoomNo(int displayRoomNo, String? wing) {
  if (displayRoomNo <= 99) return displayRoomNo;
  return wing == 'B' ? displayRoomNo % 100 : displayRoomNo ~/ 100;
}

/// 한 열람실의 전체 레이아웃.
///
/// 좌표는 실제 DOM을 기준으로 측정한 값. 따라서 배경 이미지(`map_NN.jpg`)와
/// 픽셀 단위로 정렬됨.
class RoomLayout {
  const RoomLayout({
    required this.roomNo,
    required this.name,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.backgroundAsset,
    required this.seats,
    required this.bbox,
  });

  final int roomNo;
  final String name;
  final double canvasWidth;
  final double canvasHeight;
  final String backgroundAsset;
  final List<SeatPosition> seats;
  final Rect bbox;

  double get aspectRatio => canvasWidth / canvasHeight;

  /// JSON 자산에서 룸 좌표 + 시연용 좌석 상태를 함께 로드.
  ///
  /// 실제 운영에서는 좌표(static)는 그대로 두고 상태는 `/v1/library/rooms/{id}`
  /// polling으로 받아오는 구조. 현재는 추출 시점의 스냅샷이 JSON에 박혀있다.
  static Future<RoomData> loadFromAsset({required int roomNo}) async {
    final jsonAsset = 'assets/library/room_${roomNo}_seats.json';
    final backgroundAsset = 'assets/library/map_$roomNo.jpg';
    final raw = await rootBundle.loadString(jsonAsset);
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    final canvas = json['canvas'] as Map<String, dynamic>;
    final bboxJson = json['bbox'] as Map<String, dynamic>;
    final seatsJson = json['seats'] as List<dynamic>;
    final seats = <SeatPosition>[];
    final statuses = <int, SeatStatus>{};
    for (final raw in seatsJson) {
      final s = raw as Map<String, dynamic>;
      final id = s['id'] as int;
      seats.add(
        SeatPosition(
          id: id,
          x: (s['x'] as num).toDouble(),
          y: (s['y'] as num).toDouble(),
          w: (s['w'] as num).toDouble(),
          h: (s['h'] as num).toDouble(),
          wing: s['wing'] as String?,
        ),
      );
      statuses[id] = _parseStatus(s['status'] as String?);
    }
    return RoomData(
      layout: RoomLayout(
        roomNo: json['room_no'] as int,
        name: json['name'] as String,
        canvasWidth: (canvas['w'] as num).toDouble(),
        canvasHeight: (canvas['h'] as num).toDouble(),
        backgroundAsset: backgroundAsset,
        bbox: Rect.fromLTRB(
          (bboxJson['minX'] as num).toDouble(),
          (bboxJson['minY'] as num).toDouble(),
          (bboxJson['maxX'] as num).toDouble(),
          (bboxJson['maxY'] as num).toDouble(),
        ),
        seats: seats,
      ),
      statuses: statuses,
    );
  }

  static SeatStatus _parseStatus(String? raw) {
    return switch (raw) {
      'available' => SeatStatus.available,
      'occupied' => SeatStatus.occupied,
      'fixed' => SeatStatus.fixed,
      'unavailable' => SeatStatus.unavailable,
      _ => SeatStatus.available,
    };
  }
}

/// 좌표 + 시연용 점유 상태 묶음.
class RoomData {
  const RoomData({required this.layout, required this.statuses});
  final RoomLayout layout;
  final SeatStatusMap statuses;
}

/// 열람실 표시용 메타데이터 — 빠른 카드/탭 UI에서 사용.
///
/// `mockOccupied` 는 시연용 — 실제 운영에서는 `/v1/library/rooms` polling으로
/// 실시간 사용량을 받아온다.
class LibraryRoom {
  const LibraryRoom({
    required this.roomNo,
    required this.name,
    required this.shortLabel,
    required this.totalCapacity,
    required this.mockOccupied,
    this.hasSeatMap = false,
  });

  final int roomNo;
  final String name;

  /// "제1열람실A" 같은 짧은 라벨.
  final String shortLabel;

  /// 시스템상의 총 정원.
  final int totalCapacity;

  /// 시연용 현재 사용 수.
  final int mockOccupied;

  /// 좌석 좌표 + 배경 이미지 asset이 있는지 여부.
  ///
  /// 1차에서는 `room_no=11`(제1열람실A)만 좌표가 추출돼 있고, 나머지는
  /// 동일한 방법으로 추후 추출 예정. `false`면 카드 탭 시 시연용 안내만 표시.
  final bool hasSeatMap;
}

/// 좌석 ID → 상태 매핑.
typedef SeatStatusMap = Map<int, SeatStatus>;

/// 이용 내역 상태.
enum LibraryUsageStatus {
  completed, // 사용완료 — 정상 반납
  unreturned, // 미반납 — 시간 종료 후 반납 안 함 → 제재 대상
  autoReturned; // 자동반납 — 자리비움 등으로 시스템이 회수

  String get label => switch (this) {
    LibraryUsageStatus.completed => '사용완료',
    LibraryUsageStatus.unreturned => '미반납',
    LibraryUsageStatus.autoReturned => '자동반납',
  };

  Color get color => switch (this) {
    LibraryUsageStatus.completed => AppColors.secondary,
    LibraryUsageStatus.unreturned => AppColors.primary,
    LibraryUsageStatus.autoReturned => AppColors.outline,
  };

  bool get isPenalty => this == LibraryUsageStatus.unreturned;
}

/// 한 건의 이용 내역.
class LibraryUsageRecord {
  const LibraryUsageRecord({
    required this.startedAt,
    required this.endedAt,
    required this.roomLabel,
    required this.status,
  });

  final DateTime startedAt;
  final DateTime endedAt;

  /// "제1열람실A", "제4열람실B" 등 진입할 때 사용한 카드 라벨.
  final String roomLabel;
  final LibraryUsageStatus status;

  Duration get duration => endedAt.difference(startedAt);
}

/// 디자인 토큰 reference — 좌석 위 텍스트, 선택 highlight 등에 쓸 색.
const seatSelectedRing = AppColors.primary;
