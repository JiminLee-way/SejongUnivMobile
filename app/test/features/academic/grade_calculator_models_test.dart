import 'package:flutter_test/flutter_test.dart';

import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/grade_calculator_models.dart';

void main() {
  group('GradeCalculatorGrade', () {
    test('maps Sejong grade labels to 4.5-scale points', () {
      expect(GradeCalculatorGrade.aPlus.points, 4.5);
      expect(GradeCalculatorGrade.a0.points, 4.0);
      expect(GradeCalculatorGrade.bPlus.points, 3.5);
      expect(GradeCalculatorGrade.b0.points, 3.0);
      expect(GradeCalculatorGrade.cPlus.points, 2.5);
      expect(GradeCalculatorGrade.c0.points, 2.0);
      expect(GradeCalculatorGrade.dPlus.points, 1.5);
      expect(GradeCalculatorGrade.d0.points, 1.0);
      expect(GradeCalculatorGrade.f.points, 0.0);
      expect(GradeCalculatorGrade.p.points, isNull);
      expect(GradeCalculatorGrade.np.points, isNull);
    });

    test('defaults empty and unpublished current grades to A+', () {
      expect(
        GradeCalculatorGrade.parseForCalculator(null),
        GradeCalculatorGrade.aPlus,
      );
      expect(
        GradeCalculatorGrade.parseForCalculator(''),
        GradeCalculatorGrade.aPlus,
      );
      expect(
        GradeCalculatorGrade.parseForCalculator('교수미게시'),
        GradeCalculatorGrade.aPlus,
      );
      expect(
        GradeCalculatorGrade.parseForCalculator('BO'),
        GradeCalculatorGrade.b0,
      );
    });
  });

  test('calculates GPA, major GPA, earned credits, and percentage', () {
    final summary = calculateGradeCalculatorSummary([
      GradeCalculatorTerm(
        id: '2026-10',
        label: '2학년 1학기',
        year: '2026',
        smtCd: '10',
        semesterNo: 1,
        isCurrent: true,
        courses: const [
          GradeCalculatorCourse(
            id: 'major-a',
            name: '전공 A',
            credits: 3,
            grade: GradeCalculatorGrade.aPlus,
            isMajor: true,
            retakeExcluded: false,
          ),
          GradeCalculatorCourse(
            id: 'general-b',
            name: '교양 B',
            credits: 3,
            grade: GradeCalculatorGrade.b0,
            isMajor: false,
            retakeExcluded: false,
          ),
          GradeCalculatorCourse(
            id: 'pass',
            name: '패스',
            credits: 1,
            grade: GradeCalculatorGrade.p,
            isMajor: false,
            retakeExcluded: false,
          ),
          GradeCalculatorCourse(
            id: 'major-f',
            name: '전공 F',
            credits: 2,
            grade: GradeCalculatorGrade.f,
            isMajor: true,
            retakeExcluded: false,
          ),
          GradeCalculatorCourse(
            id: 'np',
            name: '논패스',
            credits: 1,
            grade: GradeCalculatorGrade.np,
            isMajor: true,
            retakeExcluded: false,
          ),
          GradeCalculatorCourse(
            id: 'retake',
            name: '재수강 제외',
            credits: 3,
            grade: GradeCalculatorGrade.aPlus,
            isMajor: true,
            retakeExcluded: true,
          ),
        ],
      ),
    ]);

    expect(summary.gpa, closeTo(22.5 / 8, 0.0001));
    expect(summary.majorGpa, closeTo(13.5 / 5, 0.0001));
    expect(summary.earnedCredits, 7);
    expect(summary.majorEarnedCredits, 3);
    expect(summary.percentage, closeTo(82.125, 0.0001));
  });

  test('uses official Sejong percentage conversion formula', () {
    expect(sejongPercentageFromGpa(4.5), closeTo(100, 0.0001));
    expect(sejongPercentageFromGpa(4.4), closeTo(98, 0.0001));
    expect(sejongPercentageFromGpa(4.0), closeTo(94, 0.0001));
  });

  test('converts server course records with unpublished grade as A+', () {
    final course = gradeCalculatorCourseFromRecord(
      record: const GradeCourseRecord(
        curiNm: '자료구조및실습',
        cdt: 3,
        curiTypeCdNm: '전선',
        grade: '교수미게시',
        mrks: null,
      ),
      termId: '2026-10',
      index: 0,
    );

    expect(course.grade, GradeCalculatorGrade.aPlus);
    expect(course.isMajor, isTrue);
  });

  test('selects current tab label from date and student year', () {
    final term = currentGradeCalculatorTerm(
      now: DateTime(2026, 6, 23),
      studentYear: 2,
    );

    expect(term.calendarYear, 2026);
    expect(term.semesterNo, 1);
    expect(term.smtCd, '10');
    expect(term.label, '2학년 1학기');
  });
}
