// UCheck 강의 + 출결 카운트 DTO 모음.
//
// 시간 필드(`totalLectureTime`, `startTime`, `endTime` 등)는 원본 API의
// 문자열 형태를 그대로 보존하고 파싱은 extension에서 담당한다 — DTO 자체는
// 가능한 한 wire-format에 가까워야 디버깅/캐싱이 쉽다.

/// UCheck 웹 API 강의 한 건 + 누적 출결 카운트.
///
/// `totalLectureTime`은 `"월/15:00~16:30/센B105\n수/15:00~16:30/센B105"`
/// 형식의 multi-line 문자열이며 [UCheckLectureX.parseTimes]로 파싱한다.
class UCheckLecture {
  const UCheckLecture({
    this.lectureNo = 0,
    this.curriculumCd = '',
    this.curriculumNm = '',
    this.curdetailCd = '',
    this.teacherNm,
    this.teacherNo,
    this.lectureDeptNm,
    this.totalLectureTime,
    this.unitNo = 0.0,
    this.unitTime = 0.0,
    this.attendCnt = 0,
    this.tardinessCnt = 0,
    this.absenceCnt = 0,
    this.earlyLeaveCnt = 0,
    this.unfinishAttendCnt = 0,
    this.stuAttendCnt = 0,
    this.proAttendCnt = 0,
    this.lectureYear = 0,
    this.lectureTerm = 0,
    this.studentNo = '',
  });

  /// 강의 PK (UCheck 내부 식별자).
  final int lectureNo;

  /// 교과목 코드.
  final String curriculumCd;

  /// 교과목명.
  final String curriculumNm;

  /// 분반/세부 코드.
  final String curdetailCd;

  /// 담당 교수명.
  final String? teacherNm;

  /// 담당 교수 사번.
  final String? teacherNo;

  /// 개설 학과명.
  final String? lectureDeptNm;

  /// `"월/15:00~16:30/센B105\n수/15:00~16:30/센B105"` 멀티라인 문자열.
  final String? totalLectureTime;

  /// 학점.
  final double unitNo;

  /// 주당 강의 시간.
  final double unitTime;

  /// 출석 누적.
  final int attendCnt;

  /// 지각 누적.
  final int tardinessCnt;

  /// 결석 누적.
  final int absenceCnt;

  /// 조퇴 누적.
  final int earlyLeaveCnt;

  /// 미처리(아직 시간이 안 지난) 누적.
  final int unfinishAttendCnt;

  /// 학생측 누적 출석 카운트(서버 측 별도 집계).
  final int stuAttendCnt;

  /// 교수측 누적 출석 카운트.
  final int proAttendCnt;

  /// 강의 학년도 (예: 2026).
  final int lectureYear;

  /// 학기 (1=1학기, 2=2학기, 3=여름, 4=겨울).
  final int lectureTerm;

  /// 학생 학번.
  final String studentNo;

  factory UCheckLecture.fromJson(Map<String, dynamic> json) {
    return UCheckLecture(
      lectureNo: (json['lecture_no'] as num?)?.toInt() ?? 0,
      curriculumCd: json['curriculum_cd'] as String? ?? '',
      curriculumNm: json['curriculum_nm'] as String? ?? '',
      curdetailCd: json['curdetail_cd'] as String? ?? '',
      teacherNm: json['teacher_nm'] as String?,
      teacherNo: json['teacher_no'] as String?,
      lectureDeptNm: json['lecture_dept_nm'] as String?,
      totalLectureTime: json['total_lecture_time'] as String?,
      unitNo: (json['unit_no'] as num?)?.toDouble() ?? 0.0,
      unitTime: (json['unit_time'] as num?)?.toDouble() ?? 0.0,
      attendCnt: (json['attend_cnt'] as num?)?.toInt() ?? 0,
      tardinessCnt: (json['tardiness_cnt'] as num?)?.toInt() ?? 0,
      absenceCnt: (json['absence_cnt'] as num?)?.toInt() ?? 0,
      earlyLeaveCnt: (json['early_leave_cnt'] as num?)?.toInt() ?? 0,
      unfinishAttendCnt: (json['unfinish_attend_cnt'] as num?)?.toInt() ?? 0,
      stuAttendCnt: (json['stu_attend_cnt'] as num?)?.toInt() ?? 0,
      proAttendCnt: (json['pro_attend_cnt'] as num?)?.toInt() ?? 0,
      lectureYear: (json['lecture_year'] as num?)?.toInt() ?? 0,
      lectureTerm: (json['lecture_term'] as num?)?.toInt() ?? 0,
      studentNo: json['student_no'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'lecture_no': lectureNo,
    'curriculum_cd': curriculumCd,
    'curriculum_nm': curriculumNm,
    'curdetail_cd': curdetailCd,
    'teacher_nm': teacherNm,
    'teacher_no': teacherNo,
    'lecture_dept_nm': lectureDeptNm,
    'total_lecture_time': totalLectureTime,
    'unit_no': unitNo,
    'unit_time': unitTime,
    'attend_cnt': attendCnt,
    'tardiness_cnt': tardinessCnt,
    'absence_cnt': absenceCnt,
    'early_leave_cnt': earlyLeaveCnt,
    'unfinish_attend_cnt': unfinishAttendCnt,
    'stu_attend_cnt': stuAttendCnt,
    'pro_attend_cnt': proAttendCnt,
    'lecture_year': lectureYear,
    'lecture_term': lectureTerm,
    'student_no': studentNo,
  };
}

/// 한 줄의 강의 시간 — `parseTimes()`가 만들어주는 record-like wrapper.
///
/// `dayOfWeek`은 ISO 8601 스타일 1=월요일..7=일요일 정수로 저장한다
/// (원본 Kotlin은 한글 `"월"` 문자열이었지만 Flutter에서는 정수가 더 다루기 쉬움).
class LectureTimeEntry {
  const LectureTimeEntry({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
  });

  /// 1=월, 2=화, 3=수, 4=목, 5=금, 6=토, 7=일. 매칭 실패 시 0.
  final int dayOfWeek;

  /// `"HH:mm"` 24시간 형식.
  final String startTime;

  /// `"HH:mm"` 24시간 형식.
  final String endTime;

  /// 강의실 표기 (예: `"센B105"`).
  final String room;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LectureTimeEntry &&
          dayOfWeek == other.dayOfWeek &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          room == other.room;

  @override
  int get hashCode => Object.hash(dayOfWeek, startTime, endTime, room);

  @override
  String toString() =>
      'LectureTimeEntry(day=$dayOfWeek, $startTime~$endTime @ $room)';
}

/// 한글 요일 → ISO 정수 매핑.
const Map<String, int> _koreanWeekdayMap = <String, int>{
  '월': 1,
  '화': 2,
  '수': 3,
  '목': 4,
  '금': 5,
  '토': 6,
  '일': 7,
};

/// `UCheckLecture` 헬퍼.
extension UCheckLectureX on UCheckLecture {
  /// `totalLectureTime`을 줄 단위로 split → `"요일/시작~끝/강의실"` 토큰 파싱.
  ///
  /// 빈 줄/포맷 오류는 조용히 건너뛴다 (UCheck 서버가 가끔 trailing newline을
  /// 붙여 보내기 때문).
  List<LectureTimeEntry> parseTimes() {
    final src = totalLectureTime;
    if (src == null || src.trim().isEmpty) return const <LectureTimeEntry>[];
    final entries = <LectureTimeEntry>[];
    for (final line in src.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('/');
      if (parts.length < 3) continue;
      final dayKor = parts[0].trim();
      final dayInt = _koreanWeekdayMap[dayKor] ?? 0;
      final timeParts = parts[1].split('~');
      final start = timeParts.isNotEmpty ? timeParts[0].trim() : '';
      final end = timeParts.length >= 2 ? timeParts[1].trim() : '';
      final room = parts.sublist(2).join('/').trim();
      entries.add(
        LectureTimeEntry(
          dayOfWeek: dayInt,
          startTime: start,
          endTime: end,
          room: room,
        ),
      );
    }
    return entries;
  }
}

/// UCheck 웹 API 공통 응답 envelope — 제네릭 wrapper.
///
/// 원본 Kotlin은 `data: T?` + `message`/`summary` 필드를 같이 들고 있는데,
/// spec은 `content`로 부르므로 두 명칭 모두 지원하도록 fromJson에서 fallback.
class UCheckResponse<T> {
  const UCheckResponse({
    this.resultCode = '',
    this.message = '',
    this.content,
    this.summary,
  });

  /// 서버가 내려주는 결과 코드 (성공 시 보통 `"OK"` 또는 `"0000"`).
  final String resultCode;

  /// 사람이 읽는 오류/안내 메시지.
  final String message;

  /// 실제 데이터 페이로드 — 타입은 호출부에서 정한다.
  final T? content;

  /// 페이지네이션 요약(`total_count` 등).
  final UCheckSummary? summary;

  /// 제네릭 fromJson — `T`의 fromJson을 [fromContentJson] 콜백으로 받는다.
  factory UCheckResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? raw) fromContentJson,
  ) {
    final raw = json['data'] ?? json['content'];
    return UCheckResponse<T>(
      resultCode: json['result_code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      content: raw == null ? null : fromContentJson(raw),
      summary: (json['summary'] as Map<String, dynamic>?) != null
          ? UCheckSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 페이지네이션/카운트 요약.
class UCheckSummary {
  const UCheckSummary({this.totalCount = 0});

  final int totalCount;

  factory UCheckSummary.fromJson(Map<String, dynamic> json) {
    return UCheckSummary(
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }
}
