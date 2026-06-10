import 'package:flutter_test/flutter_test.dart';

import 'package:sejong_smart_campus/features/ucheck/domain/entities/lecture_with_attendance.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_lecture.dart';

/// 출석 윈도우 SSOT([AttendWindowX]) 단위 테스트.
///
/// 핵심: 실서버 `start_time`은 콜론 없는 `"HHmm"`라, 과거 `_parseHm`(콜론 split)은
/// production에서 매번 null을 돌려줘 자동출석·알림이 전부 죽어있었다. 그 회귀를
/// 막고, 정규/지각/마감 경계(기본 10/5/10분)를 고정한다.

LectureWithAttendance _lec({
  String startTime = '1000',
  String dayWeek = '',
  int? attendSmin,
  int? attendEmin,
  int? laterMin,
  int stateCdAttend = 0,
}) => LectureWithAttendance(
  lecture: const UCheckLecture(curriculumNm: '자료구조및실습'),
  startTime: startTime,
  dayWeek: dayWeek,
  attendSmin: attendSmin,
  attendEmin: attendEmin,
  laterMin: laterMin,
  stateCdAttend: stateCdAttend,
);

/// 고정 날짜(2026-06-04) 위의 시:분 — dayWeek 일관성 확보.
DateTime _at(int h, int m) => DateTime(2026, 6, 4, h, m);

void main() {
  group('startDateTimeOn — 형식 robust 파싱', () {
    test('실서버 "HHmm" 파싱', () {
      expect(
        _lec(startTime: '1000').startDateTimeOn(_at(0, 0)),
        DateTime(2026, 6, 4, 10, 0),
      );
    });
    test('데모 "HH:mm" 파싱', () {
      expect(
        _lec(startTime: '10:00').startDateTimeOn(_at(0, 0)),
        DateTime(2026, 6, 4, 10, 0),
      );
    });
    test('3자리 "Hmm" 파싱 (예 "900")', () {
      expect(
        _lec(startTime: '900').startDateTimeOn(_at(0, 0)),
        DateTime(2026, 6, 4, 9, 0),
      );
    });
    test('빈/이상값은 null', () {
      expect(_lec(startTime: '').startDateTimeOn(_at(0, 0)), isNull);
      expect(_lec(startTime: 'ab').startDateTimeOn(_at(0, 0)), isNull);
      expect(_lec(startTime: '99:99').startDateTimeOn(_at(0, 0)), isNull);
    });
  });

  group('attendWindowAt — 기본 offset(10/5/10), 10:00 강의', () {
    test('09:49 → beforeOpen', () {
      expect(_lec().attendWindowAt(_at(9, 49)), AttendWindowState.beforeOpen);
    });
    test('09:50 → onTime (열림)', () {
      expect(_lec().attendWindowAt(_at(9, 50)), AttendWindowState.onTime);
    });
    test('10:05 → onTime (정규 경계 포함)', () {
      expect(_lec().attendWindowAt(_at(10, 5)), AttendWindowState.onTime);
    });
    test('10:06 → lateOpen (지각)', () {
      expect(_lec().attendWindowAt(_at(10, 6)), AttendWindowState.lateOpen);
    });
    test('10:15 → lateOpen (지각 경계 포함)', () {
      expect(_lec().attendWindowAt(_at(10, 15)), AttendWindowState.lateOpen);
    });
    test('10:16 → closed (마감)', () {
      expect(_lec().attendWindowAt(_at(10, 16)), AttendWindowState.closed);
    });
    test('isAttendOpenAt: 윈도우 안 true / 밖 false', () {
      expect(_lec().isAttendOpenAt(_at(10, 0)), isTrue);
      expect(_lec().isAttendOpenAt(_at(10, 15)), isTrue);
      expect(_lec().isAttendOpenAt(_at(10, 16)), isFalse);
      expect(_lec().isAttendOpenAt(_at(9, 49)), isFalse);
    });
  });

  group('요일 게이팅', () {
    test('오늘 요일과 다르면 notToday', () {
      final today = ucheckDayWeek(_at(10, 0));
      final other = today == '2' ? '3' : '2';
      expect(
        _lec(dayWeek: other).attendWindowAt(_at(10, 0)),
        AttendWindowState.notToday,
      );
    });
    test('오늘 요일이면 시간 윈도우대로', () {
      final today = ucheckDayWeek(_at(10, 0));
      expect(
        _lec(dayWeek: today).attendWindowAt(_at(10, 0)),
        AttendWindowState.onTime,
      );
    });
  });

  group('서버 제공 offset 존중', () {
    test('attendSmin=20/Emin=0/laterMin=0 → 09:40 열림, 10:00 이후 마감', () {
      final l = _lec(attendSmin: 20, attendEmin: 0, laterMin: 0);
      expect(l.attendWindowAt(_at(9, 39)), AttendWindowState.beforeOpen);
      expect(l.attendWindowAt(_at(9, 40)), AttendWindowState.onTime);
      expect(l.attendWindowAt(_at(10, 0)), AttendWindowState.onTime);
      expect(l.attendWindowAt(_at(10, 1)), AttendWindowState.closed);
    });
  });
}
