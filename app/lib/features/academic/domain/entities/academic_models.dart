/// 학사 캘린더 · 학생 일정 · 성적 도메인.
library;

enum AcademicCalendarMode { month, year }

class AcademicCalendarCategory {
  const AcademicCalendarCategory({required this.code, required this.label});

  final String code;
  final String label;

  static const university = AcademicCalendarCategory(code: '0001', label: '대학');

  static const values = <AcademicCalendarCategory>[
    university,
    AcademicCalendarCategory(code: '0002', label: '일반대학원'),
    AcademicCalendarCategory(code: '0003', label: '경영전문대학원'),
    AcademicCalendarCategory(code: '0004', label: '교육대학원'),
    AcademicCalendarCategory(code: '0005', label: '관광대학원'),
    AcademicCalendarCategory(code: '0006', label: '융합예술대학원'),
    AcademicCalendarCategory(code: '0007', label: '공공정책대학원'),
  ];

  static AcademicCalendarCategory byCode(String code) {
    return values.firstWhere(
      (category) => category.code == code,
      orElse: () => university,
    );
  }
}

class AcademicCalendarEvent {
  const AcademicCalendarEvent({
    required this.title,
    required this.titleEng,
    required this.startDate,
    required this.endDate,
    required this.categoryCode,
    required this.categoryName,
    required this.sourceYear,
    required this.sourceMonth,
  });

  final String title;
  final String titleEng;
  final DateTime startDate;
  final DateTime endDate;
  final String categoryCode;
  final String categoryName;
  final int sourceYear;
  final int sourceMonth;

  factory AcademicCalendarEvent.fromOfficialJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? value) {
      final raw = (value ?? '').toString().trim();
      if (raw.isEmpty) return DateTime(1970);
      final parsed = DateTime.parse(raw);
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    final start = parseDate(json['frDt']);
    final end = parseDate(json['toDt']);
    return AcademicCalendarEvent(
      title: (json['scmSubject'] ?? '').toString().trim(),
      titleEng: (json['scmSubjectEng'] ?? '').toString().trim(),
      startDate: start,
      endDate: end.isBefore(start) ? start : end,
      categoryCode: (json['collDiv'] ?? '').toString().trim(),
      categoryName: (json['collDivNm'] ?? '').toString().trim(),
      sourceYear: ((json['scmYear'] as num?) ?? start.year).toInt(),
      sourceMonth: ((json['scmMonth'] as num?) ?? start.month).toInt(),
    );
  }

  bool occursOn(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(startDate) && !d.isAfter(endDate);
  }

  bool overlaps(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !endDate.isBefore(s) && !startDate.isAfter(e);
  }

  String get dateLabel {
    final start = _formatDate(startDate);
    final end = _formatDate(endDate);
    if (start == end) return start;
    return '$start ~ $end';
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)}';
  }
}

class AcademicCalendarRange {
  const AcademicCalendarRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

AcademicCalendarRange academicCalendarMonthGridRange(int year, int month) {
  final first = DateTime(year, month, 1);
  final start = first.subtract(Duration(days: first.weekday % 7));
  return AcademicCalendarRange(
    start: start,
    end: start.add(const Duration(days: 41)),
  );
}

List<DateTime> academicCalendarMonthGridDays(int year, int month) {
  final range = academicCalendarMonthGridRange(year, month);
  return List<DateTime>.generate(
    42,
    (index) => range.start.add(Duration(days: index)),
  );
}

List<AcademicCalendarEvent> sortAcademicCalendarEvents(
  Iterable<AcademicCalendarEvent> events,
) {
  final sorted = events.toList();
  sorted.sort((a, b) {
    final byStart = a.startDate.compareTo(b.startDate);
    if (byStart != 0) return byStart;
    final byEnd = a.endDate.compareTo(b.endDate);
    if (byEnd != 0) return byEnd;
    return a.title.compareTo(b.title);
  });
  return sorted;
}

Map<int, List<AcademicCalendarEvent>> groupAcademicEventsByStartMonth(
  Iterable<AcademicCalendarEvent> events,
) {
  final grouped = <int, List<AcademicCalendarEvent>>{
    for (var month = 1; month <= 12; month++) month: <AcademicCalendarEvent>[],
  };
  for (final event in sortAcademicCalendarEvents(events)) {
    final month = event.startDate.month;
    if (grouped.containsKey(month)) {
      grouped[month]!.add(event);
    }
  }
  return grouped;
}

/// `/api/publicapi/academic-calendar/daily?date=YYYYMMDD` 한 항목.
/// `/api/secureapi/academic-calendar/student/daily-all?date=...`도 동일 모양.
class CalendarItem {
  const CalendarItem({
    required this.subject,
    this.fromDate,
    this.toDate,
    this.divisionName,
    this.period,
    this.tms,
    this.courseScheduleGroupName,
  });
  final String subject;

  /// `2026-05-04` 같은 일자 — 공개 daily 응답에서만 옴.
  final String? fromDate;
  final String? toDate;

  /// "학부" / "산업대학원" 등.
  final String? divisionName;

  /// "2026-02-27 ∼ 2026-06-15" 식 텍스트 — 학생용 daily-all 응답.
  final String? period;
  final String? tms;
  final String? courseScheduleGroupName;

  factory CalendarItem.fromJson(Map<String, dynamic> json) {
    return CalendarItem(
      subject: (json['subject'] ?? '').toString(),
      fromDate: json['fromDate'] as String?,
      toDate: json['toDate'] as String?,
      divisionName: json['divisionName'] as String?,
      period: json['period'] as String?,
      tms: json['tms'] as String?,
      courseScheduleGroupName: json['courseScheduleGroupName'] as String?,
    );
  }

  String get dateLabel {
    if (fromDate != null && toDate != null) return '$fromDate ∼ $toDate';
    if (period != null) return period!;
    return '';
  }

  /// 같은 일정인지 — subject + 기간(혹은 period)만 동일하면 묶는다.
  /// `divisionName`은 다르더라도 같은 일정으로 본다 (Sejong 서버가 학과별로
  /// 동일 row를 N번 반복 반환하므로).
  String get dedupKey {
    final f = fromDate ?? '';
    final t = toDate ?? '';
    final p = period ?? '';
    final tm = tms ?? '';
    return '$subject|$f|$t|$p|$tm';
  }
}

/// 같은 [CalendarItem.dedupKey]를 가진 row들의 묶음.
/// 표시할 땐 subject/기간은 한 번만 보이고 [divisions] 칩으로 학과 N개 나열.
class CalendarItemGroup {
  const CalendarItemGroup({
    required this.representative,
    required this.divisions,
  });
  final CalendarItem representative;

  /// 학과 이름들 — 원래 응답 순서 그대로 유지, 중복 제거.
  final List<String> divisions;

  String get subject => representative.subject;
  String get dateLabel => representative.dateLabel;
  String? get tms => representative.tms;
  String? get courseScheduleGroupName => representative.courseScheduleGroupName;

  /// 동일 [CalendarItem.dedupKey] 끼리 묶어 group list로 변환.
  /// 입력 순서를 보존(첫 등장 순서대로 group ordering).
  static List<CalendarItemGroup> groupItems(List<CalendarItem> items) {
    final byKey = <String, List<CalendarItem>>{};
    final order = <String>[];
    for (final it in items) {
      final k = it.dedupKey;
      if (!byKey.containsKey(k)) {
        order.add(k);
        byKey[k] = [];
      }
      byKey[k]!.add(it);
    }
    final out = <CalendarItemGroup>[];
    for (final k in order) {
      final group = byKey[k]!;
      final divs = <String>[];
      final seen = <String>{};
      for (final it in group) {
        final n = it.divisionName;
        if (n != null && n.isNotEmpty && seen.add(n)) divs.add(n);
      }
      out.add(CalendarItemGroup(representative: group.first, divisions: divs));
    }
    return out;
  }
}

/// `/academic-calendar/monthly-marks?year=Y&month=M` 응답.
/// 해당 월에 일정이 있는 day-of-month(1~31) set만.
class MonthlyMarks {
  const MonthlyMarks({
    required this.year,
    required this.month,
    required this.scheduleDays,
  });
  final int year;
  final int month;
  final Set<int> scheduleDays;

  static MonthlyMarks empty(int year, int month) =>
      MonthlyMarks(year: year, month: month, scheduleDays: const <int>{});

  factory MonthlyMarks.fromJson(Map<String, dynamic> json) {
    final raw = (json['scheduleDates'] as List?) ?? const [];
    return MonthlyMarks(
      year: ((json['year'] as num?) ?? 0).toInt(),
      month: ((json['month'] as num?) ?? 0).toInt(),
      scheduleDays: raw.map((e) => (e as num).toInt()).toSet(),
    );
  }
}

/// `/academic-calendar/organization-types` 항목.
/// 학과/대학원 필터 chip — orgCode는 `student/daily?orgCode=...` query에 사용.
class OrganizationType {
  const OrganizationType({required this.code, required this.name});
  final String code;
  final String name;

  factory OrganizationType.fromJson(Map<String, dynamic> json) =>
      OrganizationType(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );
}

// ─── 성적 ──────────────────────────────────────────────────────────────────

class GradeOverallSummary {
  const GradeOverallSummary({
    required this.reqCdt,
    required this.appCdt,
    required this.totMrks,
    required this.gruCdt,
    required this.avgMrks,
    required this.sco,
  });

  /// 신청 학점 / 취득 학점 / 총 평점환산 / 졸업 인정 / 평균 평점 / 환산점수
  final int reqCdt;
  final int appCdt;
  final double totMrks;
  final int gruCdt;
  final double avgMrks;
  final int sco;

  factory GradeOverallSummary.fromJson(Map<String, dynamic> json) {
    return GradeOverallSummary(
      reqCdt: ((json['reqCdt'] as num?) ?? 0).toInt(),
      appCdt: ((json['appCdt'] as num?) ?? 0).toInt(),
      totMrks: ((json['totMrks'] as num?) ?? 0).toDouble(),
      gruCdt: ((json['gruCdt'] as num?) ?? 0).toInt(),
      avgMrks: ((json['avgMrks'] as num?) ?? 0).toDouble(),
      sco: ((json['sco'] as num?) ?? 0).toInt(),
    );
  }
}

class GradeSemesterSummary {
  const GradeSemesterSummary({
    required this.yearSmtNm,
    required this.year,
    required this.smtCd,
    required this.reqCdt,
    required this.appCdt,
    required this.sco,
    required this.avgMrks,
  });
  final String yearSmtNm;
  final String year;
  final String smtCd;
  final int reqCdt;
  final int appCdt;
  final int sco;
  final double avgMrks;

  factory GradeSemesterSummary.fromJson(Map<String, dynamic> json) {
    return GradeSemesterSummary(
      yearSmtNm: (json['yearSmtNm'] ?? '').toString(),
      year: (json['year'] ?? '').toString(),
      smtCd: (json['smtCd'] ?? '').toString(),
      reqCdt: ((json['reqCdt'] as num?) ?? 0).toInt(),
      appCdt: ((json['appCdt'] as num?) ?? 0).toInt(),
      sco: ((json['sco'] as num?) ?? 0).toInt(),
      avgMrks: ((json['avgMrks'] as num?) ?? 0).toDouble(),
    );
  }
}

class GradeCourseRecord {
  const GradeCourseRecord({
    required this.curiNm,
    required this.cdt,
    required this.curiTypeCdNm,
    required this.grade,
    required this.mrks,
    this.reInfo,
  });
  final String curiNm;
  final int cdt;
  final String curiTypeCdNm;
  final String grade;
  final double mrks;
  final String? reInfo;

  factory GradeCourseRecord.fromJson(Map<String, dynamic> json) {
    return GradeCourseRecord(
      curiNm: (json['curiNm'] ?? '').toString(),
      cdt: ((json['cdt'] as num?) ?? 0).toInt(),
      curiTypeCdNm: (json['curiTypeCdNm'] ?? '').toString(),
      grade: (json['grade'] ?? '').toString(),
      mrks: ((json['mrks'] as num?) ?? 0).toDouble(),
      reInfo: json['reInfo'] as String?,
    );
  }
}

class GradeSelectedSemester {
  const GradeSelectedSemester({
    required this.year,
    required this.smtCd,
    required this.smtCdNm,
    required this.summary,
    required this.courses,
  });
  final String year;
  final String smtCd;
  final String smtCdNm;
  final ({int reqCdt, int appCdt, double avgMrks}) summary;
  final List<GradeCourseRecord> courses;

  factory GradeSelectedSemester.fromJson(Map<String, dynamic> json) {
    final s = (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GradeSelectedSemester(
      year: (json['year'] ?? '').toString(),
      smtCd: (json['smtCd'] ?? '').toString(),
      smtCdNm: (json['smtCdNm'] ?? '').toString(),
      summary: (
        reqCdt: ((s['reqCdt'] as num?) ?? 0).toInt(),
        appCdt: ((s['appCdt'] as num?) ?? 0).toInt(),
        avgMrks: ((s['avgMrks'] as num?) ?? 0).toDouble(),
      ),
      courses: ((json['courses'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(GradeCourseRecord.fromJson)
          .toList(),
    );
  }
}

class GradeInquiry {
  const GradeInquiry({
    required this.overallSummary,
    required this.semesters,
    required this.selectedSemester,
  });
  final GradeOverallSummary overallSummary;
  final List<GradeSemesterSummary> semesters;
  final GradeSelectedSemester? selectedSemester;

  factory GradeInquiry.fromJson(Map<String, dynamic> json) {
    return GradeInquiry(
      overallSummary: GradeOverallSummary.fromJson(
        (json['overallSummary'] as Map).cast<String, dynamic>(),
      ),
      semesters: ((json['semesters'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(GradeSemesterSummary.fromJson)
          .toList(),
      selectedSemester: json['selectedSemester'] is Map
          ? GradeSelectedSemester.fromJson(
              (json['selectedSemester'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}
