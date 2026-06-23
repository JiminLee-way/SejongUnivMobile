import 'package:flutter_test/flutter_test.dart';

import 'package:sejong_smart_campus/features/academic/data/datasources/grade_calculator_storage.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/grade_calculator_models.dart';

void main() {
  test('memory storage saves, loads, and deletes per user', () async {
    final storage = MemoryGradeCalculatorStorage();
    final state = GradeCalculatorSavedState(
      schemaVersion: 1,
      baseFingerprints: const {'2026-10': 'base-a'},
      updatedAt: DateTime.utc(2026, 6, 23),
      terms: const [
        GradeCalculatorTerm(
          id: '2026-10',
          label: '2학년 1학기',
          year: '2026',
          smtCd: '10',
          semesterNo: 1,
          isCurrent: true,
          courses: [
            GradeCalculatorCourse(
              id: 'course-1',
              name: '자료구조및실습',
              credits: 3,
              grade: GradeCalculatorGrade.aPlus,
              isMajor: true,
              retakeExcluded: false,
            ),
          ],
        ),
      ],
    );

    await storage.write('student-a', state);
    await storage.write('student-b', GradeCalculatorSavedState.empty());

    final loaded = await storage.read('student-a');
    expect(loaded, isNotNull);
    expect(loaded!.baseFingerprints['2026-10'], 'base-a');
    expect(loaded.terms.single.courses.single.name, '자료구조및실습');

    await storage.delete('student-a');
    expect(await storage.read('student-a'), isNull);
    expect(await storage.read('student-b'), isNotNull);
  });
}
