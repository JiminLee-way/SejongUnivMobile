/// 학술정보원 예약 도메인.
///
/// 모바일 HTML 응답을 native로 매핑한 모델들.
/// 백엔드가 JSON을 안 주기 때문에 [LibseatRemote]가 HTML scraping으로 채운다.
library;

class ReadingRoom {
  const ReadingRoom({
    required this.roomNo,
    required this.name,
    required int used,
    required int total,
  }) : total = total < 0 ? 0 : total,
       used = total <= 0
           ? 0
           : used < 0
           ? 0
           : used > total
           ? total
           : used;

  /// `seatMap.php?param_room_no=<roomNo>` query param에 그대로 사용.
  final int roomNo;

  /// "제1열람실A" 등 표시명.
  final String name;

  /// 사용 중 좌석 수.
  final int used;

  /// 총 좌석 수.
  final int total;

  int get free => (total - used).clamp(0, total);
  double get usageRatio => total == 0 ? 0 : (used / total).clamp(0.0, 1.0);
}

/// "제1열람실A" / "제1열람실B"처럼 A/B로 분리된 실 room을
/// 사용자에게 보여주는 base label("제1열람실")로 합산한다.
List<ReadingRoom> mergeReadingRoomsByBase(List<ReadingRoom> rooms) {
  final order = <String>[];
  final byBase = <String, List<ReadingRoom>>{};
  for (final room in rooms) {
    final base = readingRoomBaseName(room.name);
    if (!byBase.containsKey(base)) order.add(base);
    byBase.putIfAbsent(base, () => []).add(room);
  }
  return [
    for (final base in order)
      ReadingRoom(
        roomNo: byBase[base]!.first.roomNo,
        name: base,
        used: byBase[base]!.fold(0, (sum, room) => sum + room.used),
        total: byBase[base]!.fold(0, (sum, room) => sum + room.total),
      ),
  ];
}

String readingRoomBaseName(String name) =>
    name.replaceAll(RegExp(r'[A-Za-z]\s*$'), '').trim();

/// 좌석 한 칸 상태.
///
/// libseat HTML이 좌석 cell의 class로 표현하는 4가지 — 시각적 색만 다르고
/// click 가능 여부에 영향.
enum SeatStatus {
  /// 사용 가능 — tap 시 [LibseatRemote.reserveSeat] 호출 가능.
  available,

  /// 사용 중 — 다른 사용자가 차지.
  used,

  /// 고정석 — 특정 사용자에게 할당된 자리.
  fixed,

  /// 사용 불가 — 점검/제한.
  disabled,
}

class Seat {
  const Seat({
    required this.roomNo,
    required this.seatNo,
    required this.status,
  });
  final int roomNo;
  final String seatNo;
  final SeatStatus status;

  bool get isReservable => status == SeatStatus.available;
}

/// `mySeat.php`가 보여주는 현재 발권 정보.
///
/// null이면 "발권·예약 내용이 없습니다.".
class MySeat {
  const MySeat({
    required this.roomNo,
    required this.roomName,
    required this.seatNo,
    required this.startTime,
    required this.endTime,
    required this.extensionsUsed,
    this.issuedDate,
    this.reserveNo,
  });

  final int roomNo;
  final String roomName;
  final String seatNo;

  /// "HH:mm" 형식 그대로. 날짜는 서버 카드 날짜가 있으면 그 날짜, 없으면 오늘.
  final String startTime;
  final String endTime;

  /// 연장 횟수 (libseat 페이지 그대로).
  final int extensionsUsed;

  /// mySeat.php 카드 상단의 서버 날짜. 없으면 기존처럼 현재 날짜 기준으로 파싱.
  final DateTime? issuedDate;

  /// 시설예약(스터디룸/시네마룸/S-Lounge) 취소에 필요한 예약번호.
  /// 열람실(좌석)에는 없음 — null 가능.
  final String? reserveNo;

  /// `HH:mm` 또는 `HH시 mm분` → DateTime (오늘 기준, end < start면 익일).
  DateTime get startedAt => _parseTimeOnDate(startTime, date: issuedDate);
  DateTime get expiresAt {
    final s = startedAt;
    final e = _parseTimeOnDate(endTime, date: issuedDate, anchor: s);
    return e;
  }

  static DateTime _parseTimeOnDate(
    String hhmm, {
    DateTime? date,
    DateTime? anchor,
  }) {
    final now = DateTime.now();
    final base = date ?? now;
    final m = RegExp(r'(\d{1,2})[:시]?\s*(\d{1,2})').firstMatch(hhmm);
    if (m == null) {
      return DateTime(base.year, base.month, base.day);
    }
    final h = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    var dt = DateTime(base.year, base.month, base.day, h, mm);
    if (anchor != null && dt.isBefore(anchor)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }
}

/// libseat 열람실 표시명 → 실제 `room_no`(11~18) 복원.
///
/// `mySeat.php`/시설 페이지는 "제4열람실A" 같은 이름만 노출하므로, 반납·연장
/// (`returnSeat.php`/`extdSeat.php`)에 필요한 실 room_no를 이름에서 역산한다.
/// 매핑(roomList 실측 고정): 제1A=11 제1B=12 / 제2=13 / 제3=14 / 제4A=15
/// 제4B=16 / 제5=17 / 제6=18. 단순 숫자 추출("제4열람실A"→4)은 틀리므로 금지.
/// 인식 실패 시 0.
int libseatRoomNoFromName(String name) {
  final m = RegExp(r'제\s*([1-6])\s*열람실\s*([ABab])?').firstMatch(name);
  if (m != null) {
    const baseA = {1: 11, 2: 13, 3: 14, 4: 15, 5: 17, 6: 18};
    final base = baseA[int.parse(m.group(1)!)]!;
    return (m.group(2)?.toUpperCase() == 'B') ? base + 1 : base;
  }
  final cleaned = name.replaceAll(RegExp(r'[^0-9]'), '');
  return cleaned.isEmpty ? 0 : (int.tryParse(cleaned) ?? 0);
}

/// `mySeat.php` 하단 이력 한 줄.
class SeatHistoryEntry {
  const SeatHistoryEntry({
    required this.date,
    required this.timeRange,
    required this.roomName,
    required this.status,
  });
  final String date; // "2026.03.27"
  final String timeRange; // "20:55~02:56"
  final String roomName;
  final String status; // "사용완료" | "미반납"
}

/// 좌석 예약/반납 응답.
class LibseatResult {
  const LibseatResult({required this.success, required this.message});
  final bool success;
  final String message;
}
