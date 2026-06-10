// `UCheckLecture` + 그 강의의 출결 레코드 + (모바일에서 머지된) 비콘 정보를
// 묶은 도메인 wrapper.
//
// 화면(UCheck 메인 카드, 강의 디테일)에서 가장 자주 쓰는 단위 — 출석률 등
// 파생 값을 한 곳에서 노출한다.

import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_attend_record.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_lecture.dart';

/// 강의 + 출결 기록 + 비콘 메타.
///
/// `lecture`/`records`는 웹 API에서 오고, `beaconAddresses`/`beaconLocalNames`
/// /`apType`/`attendSmin`/`attendEmin`/`laterMin` + mobile context 전부 모바일
/// `UCheckMobileLecture`에서 머지한 값. BLE attendCheck.do 호출 시 모든 필드
/// 필요.
class LectureWithAttendance {
  const LectureWithAttendance({
    required this.lecture,
    this.records = const <UCheckAttendRecord>[],
    this.beaconAddresses = const <String>[],
    this.beaconLocalNames = const <String>[],
    this.apType = '',
    this.attendSmin,
    this.attendEmin,
    this.laterMin,
    this.classNo = 0,
    this.roomCd = '',
    this.roomNm = '',
    this.curWeek = 0,
    this.totalWeek = 0,
    this.startTime = '',
    this.endTime = '',
    this.dayWeek = '',
    this.stateCdAttend = 0,
    this.lectureType = 1,
    this.outCheckYn = 'N',
    this.attendUseYn = 'Y',
  });

  /// 강의 본체.
  final UCheckLecture lecture;

  /// 이 강의의 모든 차시 출결 레코드.
  final List<UCheckAttendRecord> records;

  /// BLE 비콘 MAC 주소 (모바일 `b_maddr` + `t_maddr` 머지).
  final List<String> beaconAddresses;

  /// BLE 비콘 local name.
  final List<String> beaconLocalNames;

  /// 모바일 API의 `ap_type` (B/D/S/P).
  final String apType;

  /// 출석 인정 시작 분 (강의 시작 기준).
  final int? attendSmin;

  /// 출석 인정 끝 분.
  final int? attendEmin;

  /// 지각 인정 분.
  final int? laterMin;

  /// daydata의 `class_no` — attendCheck.do `cno` 페이로드.
  final int classNo;

  /// daydata의 `room_cd` — 한글 가능 (`센B105`). attendCheck.do `room_cd` 페이로드.
  final String roomCd;

  /// daydata의 `room_nm` — 표시용.
  final String roomNm;

  /// daydata의 `cur_week` — attendCheck.do `lecture_week` 페이로드.
  final int curWeek;

  /// daydata의 `total_week`.
  final int totalWeek;

  /// 강의 시작 — V2 자동출석 시간 매칭에 사용. **실서버는 `"HHmm"`**(콜론 없음,
  /// 예 `"1000"`), 데모는 `"HH:mm"`. 파싱은 [AttendWindowX.startDateTimeOn]이
  /// 두 형식을 모두 처리한다.
  final String startTime;

  /// 강의 종료 — `"HHmm"`(실서버) 또는 `"HH:mm"`(데모).
  final String endTime;

  /// `"2"=월..."7"=토` (UCheck 규약, ISO와 다름).
  final String dayWeek;

  /// `state_cd_attend` — 0=미출석, ≠0=이미 출석 처리됨. V2에서 출석 중복 방지에 사용.
  final int stateCdAttend;

  /// `lecture_type` — 1=일반.
  final int lectureType;

  /// `"Y"`/`"N"` — 퇴실 체크 가능 강의 여부 (실험실습 등).
  final String outCheckYn;

  /// `"Y"`/`"N"` — 출석 기능 사용 여부.
  final String attendUseYn;

  /// 총 차시 수.
  int get totalClasses => records.length;

  /// `attendType == "1"` 카운트.
  int get presentCount => records.where((r) => r.attendType == '1').length;

  /// `attendType == "2"` 카운트.
  int get lateCount => records.where((r) => r.attendType == '2').length;

  /// `attendType == "3"` 카운트.
  int get absentCount => records.where((r) => r.attendType == '3').length;

  /// `attendType == "4"` 카운트.
  int get earlyLeaveCount => records.where((r) => r.attendType == '4').length;

  /// 출석률 (출석+지각 / 총 차시) × 100. 차시가 0이면 100.0 — UI에서 "기록 없음"
  /// 표시는 별도 분기로 처리한다.
  double get attendanceRate {
    if (totalClasses == 0) return 100.0;
    return ((presentCount + lateCount) / totalClasses) * 100;
  }

  /// 비콘 정보 머지나 records 갱신용 — record가 immutable이라 copy로 처리.
  LectureWithAttendance copyWith({
    UCheckLecture? lecture,
    List<UCheckAttendRecord>? records,
    List<String>? beaconAddresses,
    List<String>? beaconLocalNames,
    String? apType,
    int? attendSmin,
    int? attendEmin,
    int? laterMin,
    int? classNo,
    String? roomCd,
    String? roomNm,
    int? curWeek,
    int? totalWeek,
    String? startTime,
    String? endTime,
    String? dayWeek,
    int? stateCdAttend,
    int? lectureType,
    String? outCheckYn,
    String? attendUseYn,
  }) {
    return LectureWithAttendance(
      lecture: lecture ?? this.lecture,
      records: records ?? this.records,
      beaconAddresses: beaconAddresses ?? this.beaconAddresses,
      beaconLocalNames: beaconLocalNames ?? this.beaconLocalNames,
      apType: apType ?? this.apType,
      attendSmin: attendSmin ?? this.attendSmin,
      attendEmin: attendEmin ?? this.attendEmin,
      laterMin: laterMin ?? this.laterMin,
      classNo: classNo ?? this.classNo,
      roomCd: roomCd ?? this.roomCd,
      roomNm: roomNm ?? this.roomNm,
      curWeek: curWeek ?? this.curWeek,
      totalWeek: totalWeek ?? this.totalWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      dayWeek: dayWeek ?? this.dayWeek,
      stateCdAttend: stateCdAttend ?? this.stateCdAttend,
      lectureType: lectureType ?? this.lectureType,
      outCheckYn: outCheckYn ?? this.outCheckYn,
      attendUseYn: attendUseYn ?? this.attendUseYn,
    );
  }
}

/// UCheck `day_week` 규약: "2"=월…"7"=토, "1"=일. DateTime.weekday는 Mon=1…Sun=7.
/// 매핑: Mon=1→"2" … Sat=6→"7", Sun=7→"1".
String ucheckDayWeek(DateTime d) {
  final w = d.weekday;
  return w == 7 ? '1' : (w + 1).toString();
}

/// 출석 윈도우 단계 — [AttendWindowX.attendWindowAt]가 반환.
///
/// 시간 경계(강의 시작 기준, 서버 제공 offset 또는 기본 10/5/10분):
/// ```
///  start-attendSmin   start+attendEmin   start+attendEmin+laterMin
///        │                  │                      │
///   beforeOpen │  onTime    │       lateOpen       │  closed
/// ```
/// 기본값(attendSmin=10, attendEmin=5, laterMin=10)이면 10:00 강의 기준
/// 정규 09:50~10:05, 지각 10:05~10:15.
enum AttendWindowState {
  /// 오늘 요일 강의가 아님.
  notToday,

  /// 시작 시각을 파싱하지 못함 — 윈도우 판단 불가(버튼은 보수적으로 허용).
  unknown,

  /// 아직 출석 가능 시간 전.
  beforeOpen,

  /// 정규 출석 가능.
  onTime,

  /// 지각 출석 가능(`late`는 예약어라 lateOpen).
  lateOpen,

  /// 출석 마감(윈도우 종료 이후).
  closed,
}

/// 출석 윈도우 계산 — 자동출석 funnel([AutoAttendController])과 출석 버튼이
/// **동일한 한 곳**에서 시간 판단을 공유하도록 하는 SSOT.
extension AttendWindowX on LectureWithAttendance {
  int get _attendSminOr => attendSmin ?? 10;
  int get _attendEminOr => attendEmin ?? 5;
  int get _laterMinOr => laterMin ?? 10;

  /// `startTime`을 [base]의 날짜에 얹은 DateTime. **`"HHmm"`/`"HH:mm"` 모두**
  /// 처리(숫자만 추출 → 좌측 0 패딩 → HH/mm). 파싱 실패 시 null.
  DateTime? startDateTimeOn(DateTime base) {
    final digits = startTime.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 3) return null; // 최소 "Hmm"
    final padded = digits.padLeft(4, '0');
    final h = int.tryParse(padded.substring(0, 2));
    final m = int.tryParse(padded.substring(2, 4));
    if (h == null || m == null || h > 23 || m > 59) return null;
    return DateTime(base.year, base.month, base.day, h, m);
  }

  /// [now] 기준 출석 윈도우 단계. dayWeek가 오늘과 다르면 [AttendWindowState.notToday].
  AttendWindowState attendWindowAt(DateTime now) {
    if (dayWeek.isNotEmpty && dayWeek != ucheckDayWeek(now)) {
      return AttendWindowState.notToday;
    }
    final start = startDateTimeOn(now);
    if (start == null) return AttendWindowState.unknown;
    final open = start.subtract(Duration(minutes: _attendSminOr));
    final onTimeEnd = start.add(Duration(minutes: _attendEminOr));
    final windowEnd = onTimeEnd.add(Duration(minutes: _laterMinOr));
    if (now.isBefore(open)) return AttendWindowState.beforeOpen;
    if (!now.isAfter(onTimeEnd))
      return AttendWindowState.onTime; // [open..onTimeEnd]
    if (!now.isAfter(windowEnd))
      return AttendWindowState.lateOpen; // (onTimeEnd..windowEnd]
    return AttendWindowState.closed;
  }

  /// 정규 또는 지각 — 즉, 지금 출석 가능한지.
  bool isAttendOpenAt(DateTime now) {
    final s = attendWindowAt(now);
    return s == AttendWindowState.onTime || s == AttendWindowState.lateOpen;
  }
}
