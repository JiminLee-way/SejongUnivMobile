import 'dart:math' as math;

import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/enrolled_course.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';

enum GradeCalculatorGrade {
  aPlus(label: 'A+', points: 4.5),
  a0(label: 'A0', points: 4.0),
  bPlus(label: 'B+', points: 3.5),
  b0(label: 'B0', points: 3.0),
  cPlus(label: 'C+', points: 2.5),
  c0(label: 'C0', points: 2.0),
  dPlus(label: 'D+', points: 1.5),
  d0(label: 'D0', points: 1.0),
  f(label: 'F', points: 0.0),
  p(label: 'P', points: null),
  np(label: 'NP', points: null);

  const GradeCalculatorGrade({required this.label, required this.points});

  final String label;
  final double? points;

  bool get countsForGpa => this != p && this != np;
  bool get earnsCredit => this != f && this != np;

  static GradeCalculatorGrade parseForCalculator(Object? value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty || raw == '교수미게시') return GradeCalculatorGrade.aPlus;
    final normalized = raw.toUpperCase().replaceAll('O', '0');
    for (final grade in GradeCalculatorGrade.values) {
      if (grade.label == normalized) return grade;
    }
    return GradeCalculatorGrade.aPlus;
  }

  static GradeCalculatorGrade? tryParse(Object? value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty || raw == '교수미게시') return null;
    final normalized = raw.toUpperCase().replaceAll('O', '0');
    for (final grade in GradeCalculatorGrade.values) {
      if (grade.label == normalized) return grade;
    }
    return null;
  }
}

class GradeCalculatorCourse {
  const GradeCalculatorCourse({
    required this.id,
    required this.name,
    required this.credits,
    required this.grade,
    required this.isMajor,
    required this.retakeExcluded,
    this.retakeCandidate = false,
    this.localOnly = false,
    this.category,
    this.reInfo,
  });

  final String id;
  final String name;
  final double credits;
  final GradeCalculatorGrade grade;
  final bool isMajor;
  final bool retakeExcluded;
  final bool retakeCandidate;
  final bool localOnly;
  final String? category;
  final String? reInfo;

  bool get countsInTotals => !retakeExcluded && credits > 0;
  bool get countsForGpa => countsInTotals && grade.countsForGpa;
  bool get earnsCredit => countsInTotals && grade.earnsCredit;

  String get creditsLabel {
    if (credits == credits.roundToDouble()) return credits.toInt().toString();
    return credits.toStringAsFixed(1);
  }

  GradeCalculatorCourse copyWith({
    String? id,
    String? name,
    double? credits,
    GradeCalculatorGrade? grade,
    bool? isMajor,
    bool? retakeExcluded,
    bool? retakeCandidate,
    bool? localOnly,
    String? category,
    String? reInfo,
  }) {
    return GradeCalculatorCourse(
      id: id ?? this.id,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      grade: grade ?? this.grade,
      isMajor: isMajor ?? this.isMajor,
      retakeExcluded: retakeExcluded ?? this.retakeExcluded,
      retakeCandidate: retakeCandidate ?? this.retakeCandidate,
      localOnly: localOnly ?? this.localOnly,
      category: category ?? this.category,
      reInfo: reInfo ?? this.reInfo,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'credits': credits,
    'grade': grade.label,
    'isMajor': isMajor,
    'retakeExcluded': retakeExcluded,
    'retakeCandidate': retakeCandidate,
    'localOnly': localOnly,
    'category': category,
    'reInfo': reInfo,
  };

  factory GradeCalculatorCourse.fromJson(Map<String, dynamic> json) {
    return GradeCalculatorCourse(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      credits: ((json['credits'] as num?) ?? 0).toDouble(),
      grade: GradeCalculatorGrade.parseForCalculator(json['grade']),
      isMajor: json['isMajor'] == true,
      retakeExcluded: json['retakeExcluded'] == true,
      retakeCandidate: json['retakeCandidate'] == true,
      localOnly: json['localOnly'] == true,
      category: json['category'] as String?,
      reInfo: json['reInfo'] as String?,
    );
  }

  String get editableSignature {
    return [
      name.trim(),
      credits.toStringAsFixed(1),
      grade.label,
      isMajor ? 'M' : 'N',
      retakeExcluded ? 'X' : 'I',
      localOnly ? 'L' : 'S',
    ].join('|');
  }
}

class GradeCalculatorTerm {
  const GradeCalculatorTerm({
    required this.id,
    required this.label,
    required this.year,
    required this.smtCd,
    required this.semesterNo,
    required this.isCurrent,
    required this.courses,
    this.serverLabel,
  });

  final String id;
  final String label;
  final String year;
  final String smtCd;
  final int semesterNo;
  final bool isCurrent;
  final List<GradeCalculatorCourse> courses;
  final String? serverLabel;

  GradeCalculatorSummary get summary => calculateGradeCalculatorSummary([this]);

  GradeCalculatorTerm copyWith({
    String? id,
    String? label,
    String? year,
    String? smtCd,
    int? semesterNo,
    bool? isCurrent,
    List<GradeCalculatorCourse>? courses,
    String? serverLabel,
  }) {
    return GradeCalculatorTerm(
      id: id ?? this.id,
      label: label ?? this.label,
      year: year ?? this.year,
      smtCd: smtCd ?? this.smtCd,
      semesterNo: semesterNo ?? this.semesterNo,
      isCurrent: isCurrent ?? this.isCurrent,
      courses: courses ?? this.courses,
      serverLabel: serverLabel ?? this.serverLabel,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'year': year,
    'smtCd': smtCd,
    'semesterNo': semesterNo,
    'isCurrent': isCurrent,
    'serverLabel': serverLabel,
    'courses': courses.map((course) => course.toJson()).toList(),
  };

  factory GradeCalculatorTerm.fromJson(Map<String, dynamic> json) {
    return GradeCalculatorTerm(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      year: (json['year'] ?? '').toString(),
      smtCd: (json['smtCd'] ?? '').toString(),
      semesterNo: ((json['semesterNo'] as num?) ?? 0).toInt(),
      isCurrent: json['isCurrent'] == true,
      serverLabel: json['serverLabel'] as String?,
      courses: ((json['courses'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => GradeCalculatorCourse.fromJson(row.cast()))
          .toList(),
    );
  }

  String get editableSignature {
    return courses.map((course) => course.editableSignature).join(';;');
  }

  String get baselineFingerprint {
    return [
      id,
      label,
      year,
      smtCd,
      semesterNo,
      isCurrent ? 'current' : 'past',
      editableSignature,
    ].join('::');
  }
}

class GradeCalculatorSummary {
  const GradeCalculatorSummary({
    required this.gpa,
    required this.majorGpa,
    required this.earnedCredits,
    required this.majorEarnedCredits,
    required this.gpaCredits,
    required this.percentage,
    required this.gradeDistribution,
  });

  final double? gpa;
  final double? majorGpa;
  final double earnedCredits;
  final double majorEarnedCredits;
  final double gpaCredits;
  final double? percentage;
  final Map<GradeCalculatorGrade, int> gradeDistribution;

  String get gpaLabel => _gpaLabel(gpa);
  String get majorGpaLabel => _gpaLabel(majorGpa);
  String get earnedCreditsLabel => _creditsLabel(earnedCredits);
  String get majorEarnedCreditsLabel => _creditsLabel(majorEarnedCredits);

  static String _gpaLabel(double? value) {
    if (value == null) return '-';
    return value.toStringAsFixed(2);
  }
}

class GradeCalculatorBaseline {
  const GradeCalculatorBaseline({
    required this.userId,
    required this.terms,
    required this.defaultTermId,
    required this.baselineFingerprints,
  });

  final String userId;
  final List<GradeCalculatorTerm> terms;
  final String? defaultTermId;
  final Map<String, String> baselineFingerprints;
}

class GradeCalculatorSnapshot {
  const GradeCalculatorSnapshot({
    required this.userId,
    required this.terms,
    required this.defaultTermId,
    required this.baselineFingerprints,
    required this.savedBaselineFingerprints,
    required this.dirtyTermIds,
  });

  final String userId;
  final List<GradeCalculatorTerm> terms;
  final String? defaultTermId;
  final Map<String, String> baselineFingerprints;
  final Map<String, String> savedBaselineFingerprints;
  final Set<String> dirtyTermIds;

  GradeCalculatorSummary get summary => calculateGradeCalculatorSummary(terms);

  GradeCalculatorTerm? termById(String id) {
    for (final term in terms) {
      if (term.id == id) return term;
    }
    return null;
  }

  bool shouldShowSync(String termId) => dirtyTermIds.contains(termId);

  GradeCalculatorSnapshot copyWith({
    List<GradeCalculatorTerm>? terms,
    String? defaultTermId,
    Map<String, String>? baselineFingerprints,
    Map<String, String>? savedBaselineFingerprints,
    Set<String>? dirtyTermIds,
  }) {
    return GradeCalculatorSnapshot(
      userId: userId,
      terms: terms ?? this.terms,
      defaultTermId: defaultTermId ?? this.defaultTermId,
      baselineFingerprints: baselineFingerprints ?? this.baselineFingerprints,
      savedBaselineFingerprints:
          savedBaselineFingerprints ?? this.savedBaselineFingerprints,
      dirtyTermIds: dirtyTermIds ?? this.dirtyTermIds,
    );
  }
}

class GradeCalculatorCurrentTerm {
  const GradeCalculatorCurrentTerm({
    required this.calendarYear,
    required this.semesterNo,
    required this.smtCd,
    required this.studentYear,
  });

  final int calendarYear;
  final int semesterNo;
  final String smtCd;
  final int studentYear;

  String get label => '$studentYear학년 $semesterNo학기';
}

GradeCalculatorCurrentTerm currentGradeCalculatorTerm({
  required DateTime now,
  required int studentYear,
}) {
  final semesterNo = now.month >= 3 && now.month <= 8 ? 1 : 2;
  final calendarYear = now.month <= 2 ? now.year - 1 : now.year;
  return GradeCalculatorCurrentTerm(
    calendarYear: calendarYear,
    semesterNo: semesterNo,
    smtCd: semesterNo == 1 ? '10' : '20',
    studentYear: math.max(studentYear, 1),
  );
}

GradeCalculatorSummary calculateGradeCalculatorSummary(
  Iterable<GradeCalculatorTerm> terms,
) {
  var gpaNumerator = 0.0;
  var gpaCredits = 0.0;
  var majorNumerator = 0.0;
  var majorGpaCredits = 0.0;
  var earnedCredits = 0.0;
  var majorEarnedCredits = 0.0;
  final distribution = <GradeCalculatorGrade, int>{
    for (final grade in GradeCalculatorGrade.values) grade: 0,
  };

  for (final term in terms) {
    for (final course in term.courses) {
      if (course.retakeExcluded || course.credits <= 0) continue;
      distribution[course.grade] = (distribution[course.grade] ?? 0) + 1;
      if (course.earnsCredit) {
        earnedCredits += course.credits;
        if (course.isMajor) majorEarnedCredits += course.credits;
      }
      final points = course.grade.points;
      if (points != null && course.countsForGpa) {
        gpaNumerator += points * course.credits;
        gpaCredits += course.credits;
        if (course.isMajor) {
          majorNumerator += points * course.credits;
          majorGpaCredits += course.credits;
        }
      }
    }
  }

  final gpa = gpaCredits == 0 ? null : gpaNumerator / gpaCredits;
  final majorGpa = majorGpaCredits == 0
      ? null
      : majorNumerator / majorGpaCredits;
  return GradeCalculatorSummary(
    gpa: gpa,
    majorGpa: majorGpa,
    earnedCredits: earnedCredits,
    majorEarnedCredits: majorEarnedCredits,
    gpaCredits: gpaCredits,
    percentage: sejongPercentageFromGpa(gpa),
    gradeDistribution: distribution,
  );
}

double? sejongPercentageFromGpa(double? gpa) {
  if (gpa == null) return null;
  if (gpa >= 4.4) return 100 - (4.5 - gpa) * 20;
  return 98 - (4.4 - gpa) * 10;
}

bool isMajorCourseType(String value) => value.trim().contains('전');

GradeCalculatorCourse gradeCalculatorCourseFromRecord({
  required GradeCourseRecord record,
  required String termId,
  required int index,
}) {
  return GradeCalculatorCourse(
    id: 'grade:$termId:${_slug(record.curiNm)}:$index',
    name: record.curiNm,
    credits: record.cdt.toDouble(),
    grade: GradeCalculatorGrade.parseForCalculator(record.grade),
    isMajor: isMajorCourseType(record.curiTypeCdNm),
    retakeExcluded: false,
    retakeCandidate: (record.reInfo ?? '').trim().isNotEmpty,
    localOnly: false,
    category: record.curiTypeCdNm,
    reInfo: record.reInfo,
  );
}

GradeCalculatorCourse gradeCalculatorCourseFromEnrolled({
  required EnrolledCourse course,
  required String termId,
  required int index,
}) {
  return GradeCalculatorCourse(
    id: 'enrolled:$termId:${_slug(course.name)}:$index',
    name: course.name,
    credits: course.credits,
    grade: GradeCalculatorGrade.aPlus,
    isMajor: isMajorCourseType(course.category),
    retakeExcluded: false,
    category: course.category,
  );
}

GradeCalculatorCourse gradeCalculatorCourseFromTimetable({
  required Course course,
  required String termId,
  required int index,
}) {
  return GradeCalculatorCourse(
    id: 'timetable:$termId:${_slug(course.name)}:$index',
    name: course.name,
    credits: course.credits.toDouble(),
    grade: GradeCalculatorGrade.aPlus,
    isMajor: false,
    retakeExcluded: false,
  );
}

List<GradeCalculatorTerm> markRetakeCandidates(
  List<GradeCalculatorTerm> terms,
) {
  final seen = <String, List<({int termIndex, int courseIndex})>>{};
  final mutable = [
    for (final term in terms) term.copyWith(courses: [...term.courses]),
  ];
  for (var termIndex = 0; termIndex < mutable.length; termIndex++) {
    final courses = mutable[termIndex].courses;
    for (var courseIndex = 0; courseIndex < courses.length; courseIndex++) {
      final course = courses[courseIndex];
      final key = _slug(course.name);
      final previous = seen[key];
      if (key.isNotEmpty && previous != null && previous.isNotEmpty) {
        courses[courseIndex] = course.copyWith(retakeCandidate: true);
        for (final hit in previous) {
          final prevCourses = mutable[hit.termIndex].courses;
          prevCourses[hit.courseIndex] = prevCourses[hit.courseIndex].copyWith(
            retakeCandidate: true,
          );
        }
      }
      seen.putIfAbsent(key, () => []).add((
        termIndex: termIndex,
        courseIndex: courseIndex,
      ));
    }
  }
  return mutable;
}

String gradeCalculatorTermId(String year, String smtCd) => '$year-$smtCd';

int semesterNoFromSmtCd(String smtCd) => smtCd.trim() == '20' ? 2 : 1;

Semester? timetableSemesterFor(int calendarYear, int semesterNo) {
  if (calendarYear == 2025 && semesterNo == 1) return Semester.spring2025;
  if (calendarYear == 2025 && semesterNo == 2) return Semester.fall2025;
  if (calendarYear == 2026 && semesterNo == 1) return Semester.spring2026;
  return null;
}

String _creditsLabel(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

String _slug(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
}
