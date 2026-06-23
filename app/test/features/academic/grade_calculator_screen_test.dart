import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sejong_smart_campus/features/academic/data/datasources/grade_calculator_storage.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/grade_calculator_models.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/grade_calculator_providers.dart';
import 'package:sejong_smart_campus/features/academic/presentation/screens/grade_calculator_screen.dart';

void main() {
  testWidgets('calculator opens on current term and supports grade edits', (
    tester,
  ) async {
    final storage = MemoryGradeCalculatorStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gradeCalculatorBaselineProvider.overrideWith(
            (ref) async => _baseline,
          ),
          gradeCalculatorStorageProvider.overrideWith((ref) => storage),
        ],
        child: const MaterialApp(home: GradeCalculatorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('학점계산기'), findsOneWidget);
    expect(find.text('2학년 1학기'), findsWidgets);
    expect(find.text('자료구조및실습'), findsOneWidget);
    expect(find.text('동기화 학기'), findsNothing);

    await tester.ensureVisible(find.text('자료구조및실습'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('A+').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A+').last);
    await tester.pumpAndSettle();
    expect(find.text('C+'), findsOneWidget);

    await tester.tap(find.text('C+'));
    await tester.pumpAndSettle();

    expect(find.text('C+'), findsWidgets);
    expect(find.text('동기화 학기'), findsOneWidget);
  });

  testWidgets('calculator can add a blank local row', (tester) async {
    final storage = MemoryGradeCalculatorStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gradeCalculatorBaselineProvider.overrideWith(
            (ref) async => _baseline,
          ),
          gradeCalculatorStorageProvider.overrideWith((ref) => storage),
        ],
        child: const MaterialApp(home: GradeCalculatorScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('더 입력하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('더 입력하기'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('동기화 학기'), findsOneWidget);
  });
}

final _terms = [
  GradeCalculatorTerm(
    id: '2025-10',
    label: '1학년 1학기',
    year: '2025',
    smtCd: '10',
    semesterNo: 1,
    isCurrent: false,
    courses: const [
      GradeCalculatorCourse(
        id: 'grade:2025-10:프로그래밍:0',
        name: '프로그래밍',
        credits: 3,
        grade: GradeCalculatorGrade.bPlus,
        isMajor: true,
        retakeExcluded: false,
      ),
    ],
  ),
  GradeCalculatorTerm(
    id: '2026-10',
    label: '2학년 1학기',
    year: '2026',
    smtCd: '10',
    semesterNo: 1,
    isCurrent: true,
    courses: const [
      GradeCalculatorCourse(
        id: 'grade:2026-10:자료구조및실습:0',
        name: '자료구조및실습',
        credits: 3,
        grade: GradeCalculatorGrade.aPlus,
        isMajor: true,
        retakeExcluded: false,
      ),
    ],
  ),
];

final _baseline = GradeCalculatorBaseline(
  userId: '20260001',
  terms: _terms,
  defaultTermId: '2026-10',
  baselineFingerprints: {
    for (final term in _terms) term.id: term.baselineFingerprint,
  },
);
