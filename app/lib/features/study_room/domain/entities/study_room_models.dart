/// 스터디룸 도메인 — 현황 + 예약 내역.
library;

class StudyRoomStatus {
  const StudyRoomStatus({
    required this.id,
    required this.roomNumber,
    required this.roomName,
    required this.remainingTime,
    required this.total,
  });
  final int id;
  final String roomNumber;
  final String roomName;
  final int remainingTime;
  final int total;

  /// 사용률 — 0.0(완전 점유) ~ 1.0(완전 비어있음).
  double get availabilityRatio {
    if (total <= 0) return 0;
    return (remainingTime / total).clamp(0.0, 1.0);
  }

  bool get isFull => remainingTime == 0;

  factory StudyRoomStatus.fromJson(Map<String, dynamic> json) =>
      StudyRoomStatus(
        id: (json['id'] as num).toInt(),
        roomNumber: (json['roomNumber'] ?? '').toString(),
        roomName: (json['roomName'] ?? '').toString(),
        remainingTime: ((json['remainingTime'] as num?) ?? 0).toInt(),
        total: ((json['total'] as num?) ?? 0).toInt(),
      );
}

class StudyRoomReservation {
  const StudyRoomReservation({
    required this.roomNumber,
    required this.roomName,
    required this.status,
    required this.requestDateTime,
  });
  final String roomNumber;
  final String roomName;
  final String status;
  final String requestDateTime; // YYYYMMDD

  factory StudyRoomReservation.fromJson(Map<String, dynamic> json) =>
      StudyRoomReservation(
        roomNumber: (json['roomNumber'] ?? '').toString(),
        roomName: (json['roomName'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        requestDateTime: (json['requestDateTime'] ?? '').toString(),
      );

  /// "20250509" → "2025.05.09".
  String get prettyDate {
    if (requestDateTime.length < 8) return requestDateTime;
    return '${requestDateTime.substring(0, 4)}.${requestDateTime.substring(4, 6)}.${requestDateTime.substring(6, 8)}';
  }
}
