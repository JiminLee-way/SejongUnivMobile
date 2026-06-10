import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';
import 'package:sejong_smart_campus/features/library/domain/entities/seat_reservation.dart';

/// 학술정보원 열람실 카탈로그 (시연용).
///
/// 실제 데이터는 백엔드 `/v1/library/rooms` 엔드포인트로 교체. 좌석 좌표는
/// `assets/library/room_NN_seats.json`에서 lazy-load.
///
/// `roomNo`는 좌석 예약 파라미터와 일치.
///
/// 제1열람실(원본 11,12)과 제4열람실(원본 15,16)은 시스템상 A/B로 나뉘어
/// 있지만 물리적으로는 같은 공간이라 가상 ID(1112, 1516)로 묶어서 통합
/// 좌석맵 + 통합 카드로 노출. 좌석맵 진입 시 한 캔버스 안에 A/B 양쪽이 같이
/// 보이고, 각 좌석에 `wing: A | B` 메타가 붙어 있어 백엔드 호출 시
/// 원본 room_no로 분기 가능.
const libraryRooms = <LibraryRoom>[
  LibraryRoom(
    roomNo: 1112,
    name: '학술정보원 B1 제1열람실',
    shortLabel: '제1열람실',
    totalCapacity: 189,
    mockOccupied: 51,
    hasSeatMap: true,
  ),
  LibraryRoom(
    roomNo: 13,
    name: '학술정보원 1F 제2열람실',
    shortLabel: '제2열람실',
    totalCapacity: 111,
    mockOccupied: 83,
    hasSeatMap: true,
  ),
  LibraryRoom(
    roomNo: 14,
    name: '학술정보원 2F 제3열람실',
    shortLabel: '제3열람실',
    totalCapacity: 107,
    mockOccupied: 72,
    hasSeatMap: true,
  ),
  LibraryRoom(
    roomNo: 1516,
    name: '학술정보원 3F 제4열람실',
    shortLabel: '제4열람실',
    totalCapacity: 292,
    mockOccupied: 106,
    hasSeatMap: true,
  ),
  LibraryRoom(
    roomNo: 17,
    name: '학술정보원 4F 제5열람실',
    shortLabel: '제5열람실',
    totalCapacity: 95,
    mockOccupied: 47,
    hasSeatMap: true,
  ),
  LibraryRoom(
    roomNo: 18,
    name: '학술정보원 5F 제6열람실',
    shortLabel: '제6열람실',
    totalCapacity: 165,
    mockOccupied: 60,
    hasSeatMap: true,
  ),
];

/// 현재 사용 중인 좌석 — 홈 화면의 `_activeSeat`과 동일 의미. 실제로는 단일
/// truth source로 두 화면 모두에서 참조해야 하지만, 시연 단계라 같은 모양을
/// 두 곳에 둠.
SeatReservation mockActiveLibraryReservation() {
  final now = DateTime.now();
  return SeatReservation(
    id: 'lib_42',
    roomName: '2F 제1열람실 42번',
    startedAt: now.subtract(const Duration(minutes: 60)),
    expiresAt: now.add(const Duration(minutes: 13, seconds: 51)),
  );
}

LibraryUsageRecord _u(
  int y,
  int mo,
  int d,
  int h1,
  int m1,
  int h2,
  int m2,
  String room,
  LibraryUsageStatus s,
) {
  final start = DateTime(y, mo, d, h1, m1);
  // 종료시각이 시작보다 작으면 익일.
  final endSameDay = DateTime(y, mo, d, h2, m2);
  final end = endSameDay.isBefore(start)
      ? endSameDay.add(const Duration(days: 1))
      : endSameDay;
  return LibraryUsageRecord(
    startedAt: start,
    endedAt: end,
    roomLabel: room,
    status: s,
  );
}

/// 사용자의 실제 학교 좌석 시스템에서 받은 이용 내역 (시연용 mock).
/// 최신순으로 정렬. 미반납 다수 — 본인이 보던 화면의 실제 데이터를 그대로 박음.
final mockLibraryUsageHistory = <LibraryUsageRecord>[
  _u(2026, 3, 27, 20, 55, 2, 56, '제2열람실', LibraryUsageStatus.unreturned),
  _u(2026, 3, 27, 20, 23, 20, 53, '제4열람실A', LibraryUsageStatus.completed),
  _u(2026, 3, 27, 14, 45, 14, 45, '제1열람실A', LibraryUsageStatus.completed),
  _u(2026, 3, 27, 13, 27, 14, 41, '제3열람실', LibraryUsageStatus.completed),
  _u(2025, 11, 4, 17, 6, 23, 6, '제4열람실A', LibraryUsageStatus.unreturned),
  _u(2025, 9, 30, 22, 30, 4, 30, '제4열람실B', LibraryUsageStatus.completed),
  _u(2025, 9, 29, 16, 1, 22, 1, '제4열람실A', LibraryUsageStatus.unreturned),
  _u(2025, 9, 27, 20, 39, 21, 34, '제4열람실B', LibraryUsageStatus.completed),
  _u(2025, 9, 21, 21, 33, 0, 9, '제4열람실A', LibraryUsageStatus.completed),
  _u(2025, 6, 17, 8, 16, 14, 17, '제5열람실', LibraryUsageStatus.unreturned),
  _u(2025, 5, 25, 21, 3, 3, 4, '제5열람실', LibraryUsageStatus.unreturned),
  _u(2025, 5, 18, 15, 11, 21, 11, '제4열람실A', LibraryUsageStatus.unreturned),
  _u(2025, 5, 11, 17, 10, 23, 10, '제4열람실B', LibraryUsageStatus.unreturned),
  _u(2025, 4, 27, 10, 57, 22, 35, '제6열람실', LibraryUsageStatus.unreturned),
  _u(2025, 4, 23, 6, 19, 12, 19, '제5열람실', LibraryUsageStatus.unreturned),
  _u(2025, 4, 23, 1, 30, 4, 30, '제5열람실', LibraryUsageStatus.completed),
  _u(2025, 4, 20, 1, 44, 3, 44, '제4열람실A', LibraryUsageStatus.completed),
  _u(2025, 4, 16, 20, 11, 2, 11, '제4열람실A', LibraryUsageStatus.unreturned),
  _u(2025, 4, 15, 11, 44, 17, 45, '제4열람실A', LibraryUsageStatus.unreturned),
  _u(2025, 4, 14, 10, 25, 22, 19, '제4열람실A', LibraryUsageStatus.unreturned),
  _u(2025, 4, 13, 21, 29, 23, 17, '제4열람실B', LibraryUsageStatus.completed),
  _u(2025, 4, 12, 19, 7, 1, 7, '제4열람실B', LibraryUsageStatus.unreturned),
  _u(2025, 4, 12, 19, 5, 19, 7, '제4열람실A', LibraryUsageStatus.completed),
  _u(2025, 4, 9, 22, 25, 0, 18, '제4열람실A', LibraryUsageStatus.completed),
  _u(2025, 4, 8, 18, 32, 20, 49, '제4열람실B', LibraryUsageStatus.completed),
  _u(2025, 4, 7, 22, 38, 23, 24, '제4열람실B', LibraryUsageStatus.completed),
  _u(2025, 4, 6, 0, 55, 4, 30, '제4열람실A', LibraryUsageStatus.completed),
  _u(2025, 4, 5, 16, 47, 22, 47, '제4열람실A', LibraryUsageStatus.unreturned),
  _u(2025, 4, 1, 20, 20, 2, 20, '제4열람실A', LibraryUsageStatus.unreturned),
  _u(2025, 3, 29, 21, 15, 22, 5, '제4열람실B', LibraryUsageStatus.completed),
  _u(2025, 3, 25, 21, 37, 22, 41, '제4열람실B', LibraryUsageStatus.completed),
  _u(2025, 3, 25, 15, 40, 16, 25, '제4열람실B', LibraryUsageStatus.completed),
  _u(2025, 3, 18, 19, 41, 21, 6, '제4열람실A', LibraryUsageStatus.completed),
  _u(2025, 3, 10, 12, 9, 17, 6, '제4열람실B', LibraryUsageStatus.completed),
  _u(2025, 3, 10, 12, 7, 12, 9, '제4열람실A', LibraryUsageStatus.completed),
  _u(2025, 3, 5, 20, 7, 22, 22, '제4열람실A', LibraryUsageStatus.completed),
  _u(2025, 3, 5, 9, 27, 15, 27, '제4열람실A', LibraryUsageStatus.unreturned),
  _u(2025, 3, 4, 23, 30, 9, 26, '제1열람실B', LibraryUsageStatus.completed),
  _u(2025, 3, 4, 20, 56, 22, 29, '제4열람실A', LibraryUsageStatus.completed),
  _u(2025, 3, 3, 13, 54, 19, 55, '제5열람실', LibraryUsageStatus.unreturned),
  _u(2025, 3, 1, 9, 48, 15, 49, '제4열람실A', LibraryUsageStatus.unreturned),
  _u(2025, 3, 1, 9, 46, 9, 48, '제4열람실B', LibraryUsageStatus.completed),
  _u(2025, 2, 28, 21, 35, 3, 35, '제5열람실', LibraryUsageStatus.unreturned),
];

/// 미반납 1건당 24시간 이용 정지 (가정). 학교 실제 정책에 맞춰 백엔드에서
/// 계산하는 게 맞지만 시연용으로 상수 가정.
const int kPenaltyDaysPerUnreturned = 1;

int mockUnreturnedCount() => mockLibraryUsageHistory
    .where((r) => r.status == LibraryUsageStatus.unreturned)
    .length;

/// 누적 정지 일수 = 미반납 × 1일. 실제로는 같은 날 여러 건이 있어도 1일로
/// 묶거나, 학기 단위 누적 등 더 복잡한 규칙이 있을 수 있음.
int mockPenaltyDays() => mockUnreturnedCount() * kPenaltyDaysPerUnreturned;
