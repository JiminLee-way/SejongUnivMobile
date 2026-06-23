import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/academic/data/datasources/grade_calculator_storage.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/grade_calculator_models.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/academic_providers.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/providers/enrolled_courses_providers.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/providers/timetable_providers.dart';

final gradeCalculatorNowProvider = Provider<DateTime>((ref) => DateTime.now());

final gradeCalculatorStorageProvider = Provider<GradeCalculatorStorage>(
  (ref) => SecureGradeCalculatorStorage(),
);

final gradeCalculatorBaselineProvider = FutureProvider<GradeCalculatorBaseline>(
  (ref) async {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const GradeCalculatorBaseline(
        userId: '',
        terms: [],
        defaultTermId: null,
        baselineFingerprints: {},
      );
    }

    final now = ref.watch(gradeCalculatorNowProvider);
    final currentInfo = currentGradeCalculatorTerm(
      now: now,
      studentYear: user.studentYear,
    );
    final remote = await ref.watch(academicRemoteProvider.future);
    final all = await remote.fetchGrades();

    final details = await Future.wait([
      for (final semester in all.semesters)
        _fetchSemesterDetail(remote, all.selectedSemester, semester),
    ]);
    final pastTerms = <GradeCalculatorTerm>[
      for (final detail in details)
        if (detail != null) _termFromSelectedSemester(detail),
    ]..sort(_compareTerms);

    final currentTerm = await _loadCurrentTerm(ref, currentInfo);
    pastTerms.removeWhere((term) => term.id == currentTerm.id);
    final labelled = markRetakeCandidates(
      _applyAcademicLabels([
        ...pastTerms,
        currentTerm,
      ], currentInfo: currentInfo),
    );
    return GradeCalculatorBaseline(
      userId: user.userId,
      terms: labelled,
      defaultTermId: currentTerm.id,
      baselineFingerprints: {
        for (final term in labelled) term.id: term.baselineFingerprint,
      },
    );
  },
);

final gradeCalculatorProvider =
    AsyncNotifierProvider<GradeCalculatorNotifier, GradeCalculatorSnapshot>(
      GradeCalculatorNotifier.new,
    );

class GradeCalculatorNotifier extends AsyncNotifier<GradeCalculatorSnapshot> {
  GradeCalculatorBaseline? _baseline;

  @override
  Future<GradeCalculatorSnapshot> build() async {
    final baseline = await ref.watch(gradeCalculatorBaselineProvider.future);
    _baseline = baseline;
    final storage = ref.watch(gradeCalculatorStorageProvider);
    final saved = baseline.userId.isEmpty
        ? null
        : await storage.read(baseline.userId);
    return _mergeSavedState(baseline, saved);
  }

  Future<void> updateGrade(
    String termId,
    String courseId,
    GradeCalculatorGrade grade,
  ) {
    return _updateCourse(
      termId,
      courseId,
      (course) => course.copyWith(grade: grade),
    );
  }

  Future<void> updateCredits(String termId, String courseId, double credits) {
    return _updateCourse(
      termId,
      courseId,
      (course) => course.copyWith(credits: credits < 0 ? 0 : credits),
    );
  }

  Future<void> updateName(String termId, String courseId, String name) {
    return _updateCourse(
      termId,
      courseId,
      (course) => course.copyWith(name: name),
    );
  }

  Future<void> updateMajor(String termId, String courseId, bool isMajor) {
    return _updateCourse(
      termId,
      courseId,
      (course) => course.copyWith(isMajor: isMajor),
    );
  }

  Future<void> toggleRetakeExcluded(String termId, String courseId) {
    return _updateCourse(
      termId,
      courseId,
      (course) => course.copyWith(retakeExcluded: !course.retakeExcluded),
    );
  }

  Future<void> addCourse(String termId) async {
    final snapshot = state.asData?.value;
    if (snapshot == null) return;
    final id = 'manual:$termId:${DateTime.now().microsecondsSinceEpoch}';
    final nextTerms = [
      for (final term in snapshot.terms)
        if (term.id == termId)
          term.copyWith(
            courses: [
              ...term.courses,
              GradeCalculatorCourse(
                id: id,
                name: '',
                credits: 0,
                grade: GradeCalculatorGrade.aPlus,
                isMajor: false,
                retakeExcluded: false,
                localOnly: true,
              ),
            ],
          )
        else
          term,
    ];
    await _setTerms(snapshot, nextTerms);
  }

  Future<void> deleteCourse(String termId, String courseId) async {
    final snapshot = state.asData?.value;
    if (snapshot == null) return;
    final nextTerms = [
      for (final term in snapshot.terms)
        if (term.id == termId)
          term.copyWith(
            courses: [
              for (final course in term.courses)
                if (course.id != courseId) course,
            ],
          )
        else
          term,
    ];
    await _setTerms(snapshot, nextTerms);
  }

  Future<void> resetTerm(String termId) async {
    final snapshot = state.asData?.value;
    final baselineTerm = _baselineTerm(termId);
    if (snapshot == null || baselineTerm == null) return;
    final nextTerms = [
      for (final term in snapshot.terms)
        if (term.id == termId) baselineTerm else term,
    ];
    await _setTerms(snapshot, nextTerms);
  }

  Future<void> syncTerm(String termId) async {
    await resetTerm(termId);
    ref.invalidate(gradeCalculatorBaselineProvider);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidate(gradeCalculatorBaselineProvider);
    ref.invalidateSelf();
  }

  Future<void> _updateCourse(
    String termId,
    String courseId,
    GradeCalculatorCourse Function(GradeCalculatorCourse course) update,
  ) async {
    final snapshot = state.asData?.value;
    if (snapshot == null) return;
    final nextTerms = [
      for (final term in snapshot.terms)
        if (term.id == termId)
          term.copyWith(
            courses: [
              for (final course in term.courses)
                if (course.id == courseId) update(course) else course,
            ],
          )
        else
          term,
    ];
    await _setTerms(snapshot, nextTerms);
  }

  Future<void> _setTerms(
    GradeCalculatorSnapshot snapshot,
    List<GradeCalculatorTerm> terms,
  ) async {
    final next = _recomputeDirty(snapshot.copyWith(terms: terms));
    state = AsyncData(next);
    await _persist(next);
  }

  GradeCalculatorSnapshot _recomputeDirty(GradeCalculatorSnapshot snapshot) {
    final baseline = _baseline;
    if (baseline == null) return snapshot;
    final baselineTerms = {for (final term in baseline.terms) term.id: term};
    final dirty = <String>{};
    for (final term in snapshot.terms) {
      final baselineTerm = baselineTerms[term.id];
      final currentBase = baseline.baselineFingerprints[term.id];
      final savedBase = snapshot.savedBaselineFingerprints[term.id];
      final changed =
          baselineTerm == null ||
          term.editableSignature != baselineTerm.editableSignature;
      final serverChanged =
          savedBase != null && currentBase != null && savedBase != currentBase;
      if (changed || serverChanged) dirty.add(term.id);
    }
    return snapshot.copyWith(dirtyTermIds: dirty);
  }

  Future<void> _persist(GradeCalculatorSnapshot snapshot) async {
    if (snapshot.userId.isEmpty) return;
    final storage = ref.read(gradeCalculatorStorageProvider);
    final dirtyTerms = [
      for (final term in snapshot.terms)
        if (snapshot.dirtyTermIds.contains(term.id)) term,
    ];
    if (dirtyTerms.isEmpty) {
      await storage.delete(snapshot.userId);
      return;
    }
    await storage.write(
      snapshot.userId,
      GradeCalculatorSavedState(
        schemaVersion: 1,
        baseFingerprints: {
          for (final term in dirtyTerms)
            term.id: snapshot.baselineFingerprints[term.id] ?? '',
        },
        terms: dirtyTerms,
        updatedAt: DateTime.now(),
      ),
    );
  }

  GradeCalculatorTerm? _baselineTerm(String termId) {
    final baseline = _baseline;
    if (baseline == null) return null;
    for (final term in baseline.terms) {
      if (term.id == termId) return term;
    }
    return null;
  }
}

Future<GradeSelectedSemester?> _fetchSemesterDetail(
  dynamic remote,
  GradeSelectedSemester? selected,
  GradeSemesterSummary semester,
) async {
  if (selected != null &&
      selected.year == semester.year &&
      selected.smtCd == semester.smtCd) {
    return selected;
  }
  try {
    return await remote.fetchGradeSemester(semester.year, semester.smtCd);
  } catch (_) {
    return GradeSelectedSemester(
      year: semester.year,
      smtCd: semester.smtCd,
      smtCdNm: semester.yearSmtNm,
      summary: (
        reqCdt: semester.reqCdt,
        appCdt: semester.appCdt,
        avgMrks: semester.avgMrks,
      ),
      courses: const [],
    );
  }
}

Future<GradeCalculatorTerm> _loadCurrentTerm(
  Ref ref,
  GradeCalculatorCurrentTerm currentInfo,
) async {
  final remote = await ref.read(academicRemoteProvider.future);
  GradeSelectedSemester? selected;
  try {
    final fetched = await remote.fetchCurrentSemesterGrade();
    if (fetched.courses.isNotEmpty) selected = fetched;
  } catch (_) {
    selected = null;
  }
  if (selected != null) {
    final normalized = GradeSelectedSemester(
      year: selected.year.isEmpty
          ? currentInfo.calendarYear.toString()
          : selected.year,
      smtCd: selected.smtCd.isEmpty ? currentInfo.smtCd : selected.smtCd,
      smtCdNm: selected.smtCdNm.isEmpty
          ? '${currentInfo.semesterNo}학기'
          : selected.smtCdNm,
      summary: selected.summary,
      courses: selected.courses,
    );
    return _termFromSelectedSemester(normalized, isCurrent: true);
  }

  final year = currentInfo.calendarYear.toString();
  final smtCd = currentInfo.smtCd;
  final termId = gradeCalculatorTermId(year, smtCd);
  final fallbackSemester = timetableSemesterFor(
    currentInfo.calendarYear,
    currentInfo.semesterNo,
  );
  final fallbackCourses = await _fallbackCurrentCourses(
    ref,
    fallbackSemester,
    termId,
  );
  return GradeCalculatorTerm(
    id: termId,
    label: currentInfo.label,
    year: year,
    smtCd: smtCd,
    semesterNo: currentInfo.semesterNo,
    isCurrent: true,
    serverLabel: '$year년 ${currentInfo.semesterNo}학기',
    courses: fallbackCourses,
  );
}

Future<List<GradeCalculatorCourse>> _fallbackCurrentCourses(
  Ref ref,
  Semester? semester,
  String termId,
) async {
  if (semester == null) return const [];
  try {
    final summary = await ref.read(enrolledSummaryProvider(semester).future);
    if (summary.courses.isNotEmpty) {
      return [
        for (var i = 0; i < summary.courses.length; i++)
          gradeCalculatorCourseFromEnrolled(
            course: summary.courses[i],
            termId: termId,
            index: i,
          ),
      ];
    }
  } catch (_) {}

  try {
    final timetable = await ref.read(
      timetableForSemesterProvider(semester).future,
    );
    return [
      for (var i = 0; i < timetable.courses.length; i++)
        gradeCalculatorCourseFromTimetable(
          course: timetable.courses[i],
          termId: termId,
          index: i,
        ),
    ];
  } catch (_) {
    return const [];
  }
}

GradeCalculatorTerm _termFromSelectedSemester(
  GradeSelectedSemester selected, {
  bool isCurrent = false,
}) {
  final year = selected.year;
  final smtCd = selected.smtCd;
  final id = gradeCalculatorTermId(year, smtCd);
  final semesterNo = semesterNoFromSmtCd(smtCd);
  final serverLabel = selected.smtCdNm.trim().isEmpty
      ? '$year년'
      : '$year년 ${selected.smtCdNm}';
  return GradeCalculatorTerm(
    id: id,
    label: serverLabel,
    year: year,
    smtCd: smtCd,
    semesterNo: semesterNo,
    isCurrent: isCurrent,
    serverLabel: serverLabel,
    courses: [
      for (var i = 0; i < selected.courses.length; i++)
        gradeCalculatorCourseFromRecord(
          record: selected.courses[i],
          termId: id,
          index: i,
        ),
    ],
  );
}

GradeCalculatorSnapshot _mergeSavedState(
  GradeCalculatorBaseline baseline,
  GradeCalculatorSavedState? saved,
) {
  final savedById = {
    for (final term in saved?.terms ?? const <GradeCalculatorTerm>[])
      term.id: term,
  };
  final mergedTerms = <GradeCalculatorTerm>[];
  for (final baselineTerm in baseline.terms) {
    final savedTerm = savedById[baselineTerm.id];
    if (savedTerm == null) {
      mergedTerms.add(baselineTerm);
    } else {
      mergedTerms.add(_mergeTerm(baselineTerm, savedTerm));
    }
  }
  for (final savedTerm in saved?.terms ?? const <GradeCalculatorTerm>[]) {
    if (!baseline.terms.any((term) => term.id == savedTerm.id)) {
      mergedTerms.add(savedTerm);
    }
  }

  final snapshot = GradeCalculatorSnapshot(
    userId: baseline.userId,
    terms: mergedTerms,
    defaultTermId: baseline.defaultTermId,
    baselineFingerprints: baseline.baselineFingerprints,
    savedBaselineFingerprints: saved?.baseFingerprints ?? const {},
    dirtyTermIds: const {},
  );
  final baselineTerms = {for (final term in baseline.terms) term.id: term};
  final dirty = <String>{};
  for (final term in mergedTerms) {
    final baselineTerm = baselineTerms[term.id];
    final currentBase = baseline.baselineFingerprints[term.id];
    final savedBase = saved?.baseFingerprints[term.id];
    final changed =
        baselineTerm == null ||
        term.editableSignature != baselineTerm.editableSignature;
    final serverChanged =
        savedBase != null && currentBase != null && savedBase != currentBase;
    if (changed || serverChanged) dirty.add(term.id);
  }
  return snapshot.copyWith(dirtyTermIds: dirty);
}

GradeCalculatorTerm _mergeTerm(
  GradeCalculatorTerm baselineTerm,
  GradeCalculatorTerm savedTerm,
) {
  final savedCourses = {
    for (final course in savedTerm.courses) course.id: course,
  };
  final baselineCourseIds = baselineTerm.courses
      .map((course) => course.id)
      .toSet();
  return baselineTerm.copyWith(
    courses: [
      for (final baselineCourse in baselineTerm.courses)
        if (savedCourses[baselineCourse.id] case final savedCourse?)
          savedCourse.copyWith(
            retakeCandidate: baselineCourse.retakeCandidate,
            category: baselineCourse.category,
            reInfo: baselineCourse.reInfo,
            localOnly: baselineCourse.localOnly,
          )
        else
          baselineCourse,
      for (final savedCourse in savedTerm.courses)
        if (savedCourse.localOnly &&
            !baselineCourseIds.contains(savedCourse.id))
          savedCourse,
    ],
  );
}

List<GradeCalculatorTerm> _applyAcademicLabels(
  List<GradeCalculatorTerm> terms, {
  required GradeCalculatorCurrentTerm currentInfo,
}) {
  if (terms.isEmpty) return terms;
  final currentIndex = terms.length - 1;
  final currentAcademicIndex =
      (currentInfo.studentYear - 1) * 2 + (currentInfo.semesterNo - 1);
  return [
    for (var i = 0; i < terms.length; i++)
      terms[i].copyWith(
        label: _labelForAcademicIndex(
          currentAcademicIndex - (currentIndex - i),
          fallback: terms[i].serverLabel ?? terms[i].label,
        ),
      ),
  ];
}

String _labelForAcademicIndex(int index, {required String fallback}) {
  if (index < 0) return fallback;
  final gradeYear = index ~/ 2 + 1;
  final semesterNo = index % 2 + 1;
  return '$gradeYear학년 $semesterNo학기';
}

int _compareTerms(GradeCalculatorTerm a, GradeCalculatorTerm b) {
  final yearA = int.tryParse(a.year) ?? 0;
  final yearB = int.tryParse(b.year) ?? 0;
  if (yearA != yearB) return yearA.compareTo(yearB);
  return _smtOrder(a.smtCd).compareTo(_smtOrder(b.smtCd));
}

int _smtOrder(String smtCd) {
  switch (smtCd.trim()) {
    case '10':
      return 1;
    case '15':
      return 2;
    case '20':
      return 3;
    case '25':
      return 4;
    default:
      return int.tryParse(smtCd) ?? 0;
  }
}
