import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/academic_providers.dart';
import 'package:sejong_smart_campus/features/academic/presentation/screens/grades_screen.dart';

void main() {
  testWidgets('current semester screen shows only current grade detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSemesterGradeProvider.overrideWith((ref) async {
            return _currentSemester;
          }),
        ],
        child: const MaterialApp(home: CurrentSemesterGradeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('당해학기 성적'), findsOneWidget);
    expect(find.text('2026년 1학기'), findsOneWidget);
    expect(find.text('리눅스의기초및실습'), findsOneWidget);
    expect(find.text('교수미게시'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
    expect(find.text('전체 학기 요약'), findsNothing);
    expect(find.text('학기 선택'), findsNothing);
  });

  testWidgets('all-semester grade screen keeps summary and semester selector', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gradesProvider.overrideWith((ref) async {
            return _allGrades;
          }),
        ],
        child: const MaterialApp(home: GradesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('성적'), findsOneWidget);
    expect(find.text('전체 학기 요약'), findsOneWidget);
    expect(find.text('학기 선택'), findsOneWidget);
    expect(find.text('2026년 1학기'), findsOneWidget);
  });
}

final _currentSemester = GradeSelectedSemester(
  year: '2026',
  smtCd: '10',
  smtCdNm: '1학기',
  summary: (reqCdt: 18, appCdt: 3, avgMrks: 3.0),
  courses: const [
    GradeCourseRecord(
      curiNm: '리눅스의기초및실습',
      cdt: 3,
      curiTypeCdNm: '전선',
      grade: '교수미게시',
      mrks: null,
    ),
    GradeCourseRecord(
      curiNm: '컴퓨터구조및운영체제',
      cdt: 3,
      curiTypeCdNm: '전선',
      grade: 'B0',
      mrks: null,
    ),
  ],
);

final _allGrades = GradeInquiry(
  overallSummary: const GradeOverallSummary(
    reqCdt: 120,
    appCdt: 96,
    totMrks: 340.0,
    gruCdt: 96,
    avgMrks: 3.54,
    sco: 88,
  ),
  semesters: const [
    GradeSemesterSummary(
      yearSmtNm: '2026-1',
      year: '2026',
      smtCd: '10',
      reqCdt: 18,
      appCdt: 3,
      sco: 88,
      avgMrks: 3.0,
    ),
  ],
  selectedSemester: _currentSemester,
);
