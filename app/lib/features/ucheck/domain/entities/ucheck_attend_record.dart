// UCheck 출결 레코드 한 건 — 한 강의의 한 차시(week × class).
//
// 원본: `UCheckDtos.kt`의 `UCheckAttendRecord`. 모든 시간 필드를 String 그대로
// 보존하고 표시용 포맷팅은 `UCheckAttendRecordX` extension getter로 분리.

/// 한 차시(week × class)의 출결 기록.
///
/// `attendType` 매핑: `"1"=출석`, `"2"=지각`, `"3"=결석`, `"4"=조퇴`.
/// `checkType` 매핑: `"1"=BLE`, `"2"=QR`.
class UCheckAttendRecord {
  const UCheckAttendRecord({
    this.lectureNo = 0,
    this.lectureWeek = 0,
    this.classNo = 0,
    this.sClassNo = 0,
    this.checkType,
    this.attendDate,
    this.outDate,
    this.attendNo = 0,
    this.lectureDate,
    this.startTime,
    this.endTime,
    this.roomCd,
    this.roomNm,
    this.attendType,
    this.attendProgress,
    this.inoutType,
    this.lectureType,
    this.autoAttendYn,
    this.studentNo,
  });

  /// 강의 PK.
  final int lectureNo;

  /// 주차 (1..총주차).
  final int lectureWeek;

  /// 차시 번호.
  final int classNo;

  /// 세부 차시 번호 (한 차시를 쪼갠 경우).
  final int sClassNo;

  /// 체크 방식 — `"1"=BLE`, `"2"=QR`, null=미체크.
  final String? checkType;

  /// 출석 찍은 시각 — `"yyyyMMddHHmmss"` 14자 (예: `"20260304145740"`).
  final String? attendDate;

  /// 조퇴 시각 — `"yyyyMMddHHmmss"` 14자.
  final String? outDate;

  /// 출결 레코드 PK.
  final int attendNo;

  /// 강의 일자 — `"yyyyMMdd"` 8자 (예: `"20260304"`).
  final String? lectureDate;

  /// 강의 시작 시각 — `"HHmm"` 4자 (예: `"1500"`).
  final String? startTime;

  /// 강의 종료 시각 — `"HHmm"` 4자 (예: `"1630"`).
  final String? endTime;

  /// 강의실 코드.
  final String? roomCd;

  /// 강의실 표시명.
  final String? roomNm;

  /// `"1"=출석`, `"2"=지각`, `"3"=결석`, `"4"=조퇴`.
  final String? attendType;

  /// 출석 진행 상태.
  final String? attendProgress;

  /// 입실/퇴실 구분.
  final String? inoutType;

  /// 강의 타입.
  final String? lectureType;

  /// 자동 출석 여부 (`"Y"`/`"N"`).
  final String? autoAttendYn;

  /// 학생 학번.
  final String? studentNo;

  factory UCheckAttendRecord.fromJson(Map<String, dynamic> json) {
    return UCheckAttendRecord(
      lectureNo: (json['lecture_no'] as num?)?.toInt() ?? 0,
      lectureWeek: (json['lecture_week'] as num?)?.toInt() ?? 0,
      classNo: (json['class_no'] as num?)?.toInt() ?? 0,
      sClassNo: (json['s_class_no'] as num?)?.toInt() ?? 0,
      checkType: json['check_type'] as String?,
      attendDate: json['attend_date'] as String?,
      outDate: json['out_date'] as String?,
      attendNo: (json['attend_no'] as num?)?.toInt() ?? 0,
      lectureDate: json['lecture_date'] as String?,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      roomCd: json['room_cd'] as String?,
      roomNm: json['room_nm'] as String?,
      attendType: json['attend_type'] as String?,
      attendProgress: json['attend_progress'] as String?,
      inoutType: json['inout_type'] as String?,
      lectureType: json['lecture_type'] as String?,
      autoAttendYn: json['auto_attend_yn'] as String?,
      studentNo: json['student_no'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lecture_no': lectureNo,
    'lecture_week': lectureWeek,
    'class_no': classNo,
    's_class_no': sClassNo,
    'check_type': checkType,
    'attend_date': attendDate,
    'out_date': outDate,
    'attend_no': attendNo,
    'lecture_date': lectureDate,
    'start_time': startTime,
    'end_time': endTime,
    'room_cd': roomCd,
    'room_nm': roomNm,
    'attend_type': attendType,
    'attend_progress': attendProgress,
    'inout_type': inoutType,
    'lecture_type': lectureType,
    'auto_attend_yn': autoAttendYn,
    'student_no': studentNo,
  };
}

/// 표시용 포맷팅 헬퍼.
///
/// 원본 DTO는 wire-format(`"20260304145740"`)으로만 들고 있고, 한국어 라벨/
/// 콜론 포함 시각 같은 view-formatting은 여기서만 한다.
extension UCheckAttendRecordX on UCheckAttendRecord {
  /// `"1"→"출석"`, `"2"→"지각"`, `"3"→"결석"`, `"4"→"조퇴"`, null→`""`.
  String get attendTypeLabel {
    switch (attendType) {
      case '1':
        return '출석';
      case '2':
        return '지각';
      case '3':
        return '결석';
      case '4':
        return '조퇴';
      default:
        return '';
    }
  }

  /// `"1"→"BLE"`, `"2"→"QR"`, 그 외 `""`.
  String get checkTypeLabel {
    switch (checkType) {
      case '1':
        return 'BLE';
      case '2':
        return 'QR';
      default:
        return '';
    }
  }

  /// `"20260304145740"` → `"14:57:40"`. 길이가 14 미만이면 `""`.
  String get attendTimeFormatted {
    final d = attendDate;
    if (d == null || d.length < 14) return '';
    return '${d.substring(8, 10)}:${d.substring(10, 12)}:${d.substring(12, 14)}';
  }

  /// `"20260304"` → `"03.04"`. 길이가 8 미만이면 원본 그대로.
  String get lectureDateFormatted {
    final d = lectureDate;
    if (d == null) return '';
    if (d.length < 8) return d;
    return '${d.substring(4, 6)}.${d.substring(6, 8)}';
  }

  /// `"1500"` → `"15:00"`. 길이가 4 미만이면 원본 그대로.
  String get startTimeFormatted {
    final t = startTime;
    if (t == null) return '';
    if (t.length < 4) return t;
    return '${t.substring(0, 2)}:${t.substring(2, 4)}';
  }

  /// `"1630"` → `"16:30"`. 길이가 4 미만이면 원본 그대로.
  String get endTimeFormatted {
    final t = endTime;
    if (t == null) return '';
    if (t.length < 4) return t;
    return '${t.substring(0, 2)}:${t.substring(2, 4)}';
  }
}
