enum SeatStatus { active, extended, returned, expired }

class SeatReservation {
  const SeatReservation({
    required this.id,
    required this.roomName,
    required this.startedAt,
    required this.expiresAt,
    this.status = SeatStatus.active,
    this.roomNo,
    this.seatNo,
  });

  final String id;
  final String roomName;
  final DateTime startedAt;
  final DateTime expiresAt;
  final SeatStatus status;

  /// 실 libseat room_no — 반납/연장(`returnSeat.php`/`extdSeat.php`) 호출용.
  /// mock 예약에선 null.
  final int? roomNo;

  /// 좌석 번호 — 반납/연장 호출용. mock 예약에선 null.
  final String? seatNo;

  Duration remaining(DateTime now) {
    final diff = expiresAt.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// 연장 가능 여부 — 서버 정책상 종료 120분 전부터. UI 게이팅용.
  bool canExtendAt(DateTime now) =>
      !isExpired && remaining(now) <= const Duration(minutes: 120);
}
