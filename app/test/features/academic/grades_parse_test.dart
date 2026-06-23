import 'package:flutter_test/flutter_test.dart';

import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';

void main() {
  group('grade parsing', () {
    test('current semester response maps to selected semester detail', () {
      final semester = GradeSelectedSemester.fromJson(_currentSemesterJson);

      expect(semester.year, '2026');
      expect(semester.smtCd, '10');
      expect(semester.smtCdNm, '1학기');
      expect(semester.summary.reqCdt, 18);
      expect(semester.summary.appCdt, 3);
      expect(semester.summary.avgMrks, 3.0);
      expect(semester.courses, hasLength(2));
      expect(semester.courses.first.curiNm, '리눅스의기초및실습');
    });

    test('unpublished current grades do not become zero-point scores', () {
      final unpublished = GradeCourseRecord.fromJson(
        _currentSemesterJson['courses'][0] as Map<String, dynamic>,
      );
      final missingScore = GradeCourseRecord.fromJson(
        _currentSemesterJson['courses'][1] as Map<String, dynamic>,
      );
      final published = GradeCourseRecord.fromJson({
        'curiNm': '자료구조',
        'cdt': 3,
        'curiTypeCdNm': '전필',
        'grade': 'A0',
        'mrks': 4.0,
        'reInfo': null,
      });

      expect(unpublished.mrks, isNull);
      expect(unpublished.scoreLabel, '-');
      expect(missingScore.scoreLabel, '-');
      expect(published.scoreLabel, '4.0');
    });
  });
}

final _currentSemesterJson = <String, dynamic>{
  'year': '2026',
  'smtCd': '10',
  'smtCdNm': '1학기',
  'summary': {'reqCdt': 18, 'appCdt': 3, 'avgMrks': 3.0},
  'courses': <Map<String, dynamic>>[
    {
      'curiNm': '리눅스의기초및실습',
      'cdt': 3,
      'curiTypeCdNm': '전선',
      'reInfo': null,
      'grade': '교수미게시',
      'mrks': null,
    },
    {
      'curiNm': '컴퓨터구조및운영체제',
      'cdt': 3,
      'curiTypeCdNm': '전선',
      'reInfo': null,
      'grade': 'B0',
      'mrks': null,
    },
  ],
};
