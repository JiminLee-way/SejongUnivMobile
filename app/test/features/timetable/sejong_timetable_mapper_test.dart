import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/timetable/data/datasources/sejong_timetable_mapper.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';

/// 시간표 셀 → CourseTime 병합 회귀.
///
/// 핵심 회귀: **팀티칭(공동담당) 강의는 sjapp이 한 30분 슬롯을 담당 교수 수만큼
/// 중복 cell로 내려준다**(예: 임베디드시스템 = 김재호 + 석문기, hourCd 3,3,4,4,…).
/// 중복을 건너뛰지 않으면 연속 병합(== segEnd+1)이 매 슬롯마다 깨져 한 강의가
/// 30분짜리 블록 여러 개로 쪼개져 겹쳐 그려지던 버그를 막는다.
void main() {
  // sjapp `timetable.courses` cell 한 칸 생성 헬퍼.
  Map<String, dynamic> cell({
    required String dayCd,
    required int hourCd,
    String curiNo = '006139',
    String className = '001',
    String curiNm = '임베디드시스템',
    String roomNmAlias = '센B104',
    String empNm = '김재호 교수',
  }) => {
    'dayCd': dayCd,
    'hourCd': hourCd.toString().padLeft(2, '0'),
    'curiNm': curiNm,
    'roomNmAlias': roomNmAlias,
    'empNm': empNm,
    'className': className,
    'curiNo': curiNo,
    'curiTypeCdNm': '전선',
  };

  CourseTime onlyTimeOf(Timetable t, String name) {
    final c = t.courses.firstWhere((c) => c.name == name);
    expect(c.times.length, 1, reason: '$name 은 한 블록으로 병합돼야 한다');
    return c.times.single;
  }

  group('SejongTimetableMapper 팀티칭 중복 hourCd 병합', () {
    test('임베디드시스템(김재호+석문기): hourCd 3,3..8,8 → 09:00–12:00 단일 블록', () {
      // 실데이터 형태: 금(dayCd=5) 09:00–12:00, 교수 2명이라 각 슬롯이 2번씩.
      final cells = <Map<String, dynamic>>[];
      for (final h in [3, 4, 5, 6, 7, 8]) {
        cells.add(cell(dayCd: '5', hourCd: h, empNm: '김재호 교수'));
        cells.add(cell(dayCd: '5', hourCd: h, empNm: '석문기 교수'));
      }

      final t = SejongTimetableMapper.buildTimetable(
        semester: Semester.spring2026,
        enrolled: [
          {
            'curiNo': '006139',
            'className': '001',
            'name': '임베디드시스템',
            'professor': '김재호, 석문기',
            'building': '센B104',
            'credits': 3,
            'category': '전선',
          },
        ],
        cells: cells,
        cyberLectures: const [],
      );

      final time = onlyTimeOf(t, '임베디드시스템');
      expect(time.weekday, Weekday.fri);
      expect(time.start.format(), '09:00');
      expect(time.end.format(), '12:00');
      // 공동담당 교수는 enrolled에서 그대로 노출(첫 교수만 남지 않음).
      expect(
        t.courses.firstWhere((c) => c.name == '임베디드시스템').professor,
        '김재호, 석문기',
      );
    });

    test('일반 강의(중복 없음): 연속 4슬롯은 그대로 한 블록', () {
      final cells = [
        for (final h in [5, 6, 7, 8])
          cell(
            dayCd: '2',
            hourCd: h,
            curiNo: '011488',
            curiNm: '자료구조및실습',
            roomNmAlias: '센B105',
            empNm: '최창희 교수',
          ),
      ];
      final t = SejongTimetableMapper.buildTimetable(
        semester: Semester.spring2026,
        enrolled: const [],
        cells: cells,
        cyberLectures: const [],
      );
      final time = onlyTimeOf(t, '자료구조및실습');
      expect(time.start.format(), '10:00');
      expect(time.end.format(), '12:00');
    });

    test('같은 날 실제 공강(gap): 중복이 있어도 두 블록으로 분리 유지', () {
      // 오전 3,4 / 오후 9,10 — 각 교수 2명 중복. gap을 가로질러 병합하면 안 된다.
      final cells = <Map<String, dynamic>>[];
      for (final h in [3, 4, 9, 10]) {
        cells.add(cell(dayCd: '2', hourCd: h, empNm: '김재호 교수'));
        cells.add(cell(dayCd: '2', hourCd: h, empNm: '석문기 교수'));
      }
      final t = SejongTimetableMapper.buildTimetable(
        semester: Semester.spring2026,
        enrolled: const [],
        cells: cells,
        cyberLectures: const [],
      );
      final c = t.courses.firstWhere((c) => c.name == '임베디드시스템');
      expect(c.times.length, 2, reason: '실제 gap은 병합되면 안 된다');
      final sorted = [...c.times]
        ..sort((a, b) => a.start.totalMinutes.compareTo(b.start.totalMinutes));
      expect(sorted[0].start.format(), '09:00');
      expect(sorted[0].end.format(), '10:00');
      expect(sorted[1].start.format(), '12:00');
      expect(sorted[1].end.format(), '13:00');
    });
  });
}
