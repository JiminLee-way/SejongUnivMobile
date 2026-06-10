/// libseat 시설예약 도메인 — 스터디룸 / 시네마룸 / S-Lounge.
///
/// 열람실([ReadingRoom])과 달리 "시간 grid × 룸" 예약 구조. roomGB가
/// 카테고리 분류 키.
library;

enum FacilityCategory {
  /// 스터디룸 (12인 1실, 6인 12실).
  studyRoom(
    'S1',
    '스터디룸',
    '/mobile/MA/sroomList.php',
    '/mobile/MA/sroomMap.php',
  ),

  /// 시네마룸 (3인 6실).
  cinema('S2', '시네마룸', '/mobile/MA/cinemaList.php', '/mobile/MA/cinemaMap.php'),

  /// S-Lounge (6인 9실, 4인 9실).
  sLounge(
    'S3',
    'S-Lounge',
    '/mobile/MA/loungeList.php',
    '/mobile/MA/loungeMap.php',
  );

  const FacilityCategory(this.roomGB, this.label, this.listPath, this.mapPath);
  final String roomGB;
  final String label;
  final String listPath;
  final String mapPath;
}

/// 시설 그룹 — list page의 한 카드. 예: "6인실 02~04 스터디룸".
///
/// 그룹 식별: ([roomGB], [seq]) — mapPath query에 그대로 전달.
class FacilityGroup {
  const FacilityGroup({
    required this.category,
    required this.seq,
    required this.title,
    required this.subtitle,
    required this.seatCnt,
  });
  final FacilityCategory category;
  final int seq;

  /// 큰 라벨 — "스터디룸 12인실".
  final String title;

  /// 작은 라벨 — "01스터디룸" 또는 "02스터디룸 ~ 04스터디룸".
  final String subtitle;

  /// 정원 (URL query `seatCnt`).
  final int seatCnt;
}

/// 시설 예약 가능 상태.
enum SlotStatus { available, reserved, disabled }

/// 시간 × 룸 grid의 한 cell.
class FacilitySlot {
  const FacilitySlot({
    required this.roomLabel,
    required this.sroomNo,
    required this.time,
    required this.status,
  });

  /// "01스터디룸" 같은 룸 표시명.
  final String roomLabel;

  /// libseat 백엔드의 글로벌 룸 식별자. 카테고리 무관 단일 ID 공간이라
  /// 라벨에서 파싱하면 충돌(예: "시네마룸4"·"SL4"·"04스터디룸" 모두 4).
  /// 반드시 응답 a href의 `sroomNo=` 쿼리에서 가져온다.
  final int sroomNo;

  /// "09:00" 등 시작 시각.
  final String time;
  final SlotStatus status;

  bool get isReservable => status == SlotStatus.available;
}

/// 한 룸의 하루 시간 grid — 새 디자인이 룸을 행 단위로 펼쳐 그리기 위해
/// FacilityMap을 평탄화한 결과.
class RoomSchedule {
  const RoomSchedule({
    required this.group,
    required this.roomLabel,
    required this.sroomNo,
    required this.roomIndex,
    required this.minCapacity,
    required this.maxCapacity,
    required this.slots,
  });

  /// 룸이 속한 그룹 (reserveSlot에 필요).
  final FacilityGroup group;

  /// "01스터디룸" 등 표시명.
  final String roomLabel;

  /// libseat 백엔드의 글로벌 룸 식별자(예약 form의 `roomNo` 파라미터).
  /// 카테고리간 충돌 회피 위해 응답 a href에서 직접 추출.
  final int sroomNo;

  /// 룸 번호(1, 2, …) — 카드 좌측 큰 숫자. roomLabel에서 추출(표시용).
  final int roomIndex;

  /// 최소 인원(스터디룸 12인실=6, 6인실=3, 시네마룸=1, S-Lounge 6인=2, 4인=2).
  final int minCapacity;

  /// 정원 = group.seatCnt.
  final int maxCapacity;

  /// 운영 시간대(10~22)별 status. 길이는 [LibseatHours.all]과 동일.
  final List<RoomTimeSlot> slots;

  String get capacityLabel => minCapacity == maxCapacity
      ? '$maxCapacity명'
      : '$minCapacity ~ $maxCapacity명';
}

/// 한 시간 slot — 새 디자인에서 막대 한 칸.
class RoomTimeSlot {
  const RoomTimeSlot({required this.hour, required this.status});

  /// 시작 시각(10~22).
  final int hour;
  final SlotStatus status;

  /// "10:00" 같은 표시용 라벨.
  String get label => '${hour.toString().padLeft(2, '0')}:00';

  bool get isReservable => status == SlotStatus.available;
}

/// 내 시설 예약 한 건 — `mySeat.php`의 스터디룸/시네마룸/S-Lounge 탭 .item.
///
/// `cancelSroom(reserveNo)` JS 콜백에서 reserveNo를 추출해 [FacilityRemote.
/// cancelReservation]에 전달.
class FacilityReservation {
  const FacilityReservation({
    required this.category,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.roomLabel,
    required this.status,
    this.reserveNo,
  });

  /// "S1층 04스터디룸" → studyRoom.
  final FacilityCategory category;

  /// "2026.05.26" → DateTime(2026, 5, 26).
  final DateTime date;

  /// "18:00".
  final String startTime;

  /// "20:00".
  final String endTime;

  /// "S1층 04스터디룸" / "S2층 시네마룸02-3인실" / "S3층 SL1".
  final String roomLabel;

  /// "예약취소", "예약부도", "예약완료", "사용중", "사용완료" 등 원문 그대로.
  final String status;

  /// 취소 가능한 활성 예약일 때만 채워짐. JS 콜백 인자에서 추출.
  final String? reserveNo;

  /// 시간 표시 — "18:00 ~ 20:00".
  String get timeLabel => '$startTime ~ $endTime';

  /// 활성(취소·부도·완료 모두 종료 상태) 외 — 취소 버튼 노출 여부.
  bool get isActive {
    final s = status.trim();
    if (s.contains('취소')) return false;
    if (s.contains('부도')) return false;
    if (s.contains('완료')) return false;
    return true;
  }

  /// 카테고리 색조 hint — 메인 톤과 어울리는 색 매핑.
  FacilityReservationStatusKind get statusKind {
    final s = status.trim();
    if (s.contains('취소')) return FacilityReservationStatusKind.cancelled;
    if (s.contains('부도')) return FacilityReservationStatusKind.noShow;
    if (s.contains('완료')) return FacilityReservationStatusKind.completed;
    if (s.contains('중')) return FacilityReservationStatusKind.inUse;
    return FacilityReservationStatusKind.upcoming;
  }
}

enum FacilityReservationStatusKind {
  upcoming,
  inUse,
  completed,
  cancelled,
  noShow,
}

/// 시설예약 운영 시간 상수 — 학기중 평일 10~22 기준.
///
/// 토/방학 등 단축 운영은 v2에서 [RoomSchedule] 생성 시 슬롯을 disabled로
/// 표기. 현재는 13개 슬롯을 모두 그리되 백엔드 응답에 없는 시간은 disabled.
class LibseatHours {
  const LibseatHours._();
  static const List<int> all = <int>[
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
  ];
  static const List<int> firstRow = <int>[10, 11, 12, 13, 14, 15, 16];
  static const List<int> secondRow = <int>[17, 18, 19, 20, 21, 22];
}

/// `*Map.php` 응답 한 페이지.
class FacilityMap {
  const FacilityMap({
    required this.dateLabel,
    required this.rooms,
    required this.times,
    required this.slots,
  });

  /// "23 (토)" 등 페이지 상단 날짜 표시.
  final String dateLabel;

  /// 컬럼 = 룸 list ("01스터디룸").
  final List<String> rooms;

  /// 행 = 시간 list ("09:00").
  final List<String> times;

  /// rooms.length × times.length 평탄화 (row-major: times 먼저 × rooms).
  final List<FacilitySlot> slots;
}
