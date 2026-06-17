import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/academic/data/datasources/sejong_academic_remote.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';

void main() {
  group('official academic calendar parsing', () {
    const fixture = '''
{
  "data": [
    {
      "scmYear": 2026,
      "scmMonth": 6,
      "collDiv": "0001",
      "collDivNm": "학부",
      "scmSubject": "하계 계절학기 수강신청",
      "scmSubjectEng": "Course registration for Summer Session",
      "frDt": "2026-06-01",
      "toDt": "2026-06-04"
    },
    {
      "scmYear": 2026,
      "scmMonth": 6,
      "collDiv": "0001",
      "collDivNm": "학부",
      "scmSubject": "하계방학 시작 및 계절학기 개강",
      "scmSubjectEng": "Summer Vacation Begins / Summer Session Begins",
      "frDt": "2026-06-23",
      "toDt": "2026-06-23"
    },
    {
      "scmYear": 2026,
      "scmMonth": 12,
      "collDiv": "0001",
      "collDivNm": "학부",
      "scmSubject": "2학기 기말고사 성적 열람 및 정정",
      "scmSubjectEng": "Fall Semester Final Examination Grades Check",
      "frDt": "2026-12-29",
      "toDt": "2027-01-02"
    }
  ]
}
''';

    test('parses JSON string into sorted official events', () {
      final events = SejongAcademicRemote.parseOfficialCalendarResponse(
        fixture,
      );

      expect(events, hasLength(3));
      expect(events.first.title, '하계 계절학기 수강신청');
      expect(events.first.titleEng, 'Course registration for Summer Session');
      expect(events.first.categoryCode, '0001');
      expect(events.first.categoryName, '학부');
      expect(events.first.sourceYear, 2026);
      expect(events.first.sourceMonth, 6);
      expect(events.first.startDate, DateTime(2026, 6));
      expect(events.first.endDate, DateTime(2026, 6, 4));
      expect(events.first.dateLabel, '2026.06.01 ~ 2026.06.04');
    });

    test('parses Map responses and handles one-day events', () {
      final events = SejongAcademicRemote.parseOfficialCalendarResponse(
        jsonDecode(fixture) as Map<String, dynamic>,
      );
      final single = events[1];

      expect(single.startDate, DateTime(2026, 6, 23));
      expect(single.endDate, DateTime(2026, 6, 23));
      expect(single.dateLabel, '2026.06.23');
      expect(single.occursOn(DateTime(2026, 6, 23)), isTrue);
      expect(single.occursOn(DateTime(2026, 6, 24)), isFalse);
    });

    test('month grid range uses Sunday-start six-week range', () {
      final range = academicCalendarMonthGridRange(2026, 6);
      final days = academicCalendarMonthGridDays(2026, 6);

      expect(range.start, DateTime(2026, 5, 31));
      expect(range.end, DateTime(2026, 7, 11));
      expect(days, hasLength(42));
      expect(days.first, DateTime(2026, 5, 31));
      expect(days.last, DateTime(2026, 7, 11));
    });

    test('annual grouping uses the event start month', () {
      final events = SejongAcademicRemote.parseOfficialCalendarResponse(
        fixture,
      );
      final grouped = groupAcademicEventsByStartMonth(events);

      expect(grouped[6]!.map((e) => e.title), [
        '하계 계절학기 수강신청',
        '하계방학 시작 및 계절학기 개강',
      ]);
      expect(grouped[12]!.single.title, '2학기 기말고사 성적 열람 및 정정');
      expect(grouped[1], isEmpty);
    });
  });
}
