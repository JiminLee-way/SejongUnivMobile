import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';

/// 오늘(now 기준)의 다음 강의 시작 정보 — 없으면 null.
///
/// - 주말이면 Weekday enum에 없는 요일이라 항상 null
/// - 오늘 강의는 있었지만 모두 시작 시각이 지났으면 null
/// - 현재 진행 중인 강의는 "다음"이 아니므로 제외
///
/// 반환값은 `(course, startsAt)` 레코드 — 위젯에서 시각만 따로 포매팅하기 쉽게.
({Course course, HMTime startsAt})? findNextLectureToday(
  Iterable<Course> courses,
  DateTime now,
) {
  final today = _todayWeekday(now);
  if (today == null) return null;

  final nowMin = now.hour * 60 + now.minute;
  Course? bestCourse;
  HMTime? bestStart;
  int bestMin = 24 * 60;

  for (final c in courses) {
    for (final t in c.times) {
      if (t.weekday != today) continue;
      final startMin = t.start.totalMinutes;
      if (startMin <= nowMin) continue;
      if (startMin < bestMin) {
        bestMin = startMin;
        bestCourse = c;
        bestStart = t.start;
      }
    }
  }

  if (bestCourse == null || bestStart == null) return null;
  return (course: bestCourse, startsAt: bestStart);
}

/// 오늘(now 기준) 아직 끝나지 않은 강의 수.
///
/// "남은"의 정의는 종료 시각이 [now]를 지나지 않은 것 — 현재 진행 중인 강의도
/// 포함한다. (홈 Topbar의 "남은 강의 N개"가 "방금 끝났다"로 0으로 떨어지지 않게.)
/// 주말이면 항상 0.
int remainingLecturesToday(Iterable<Course> courses, DateTime now) {
  final today = _todayWeekday(now);
  if (today == null) return 0;
  final nowMin = now.hour * 60 + now.minute;
  var count = 0;
  for (final c in courses) {
    for (final t in c.times) {
      if (t.weekday != today) continue;
      if (t.end.totalMinutes > nowMin) count++;
    }
  }
  return count;
}

Weekday? _todayWeekday(DateTime now) {
  switch (now.weekday) {
    case DateTime.monday:
      return Weekday.mon;
    case DateTime.tuesday:
      return Weekday.tue;
    case DateTime.wednesday:
      return Weekday.wed;
    case DateTime.thursday:
      return Weekday.thu;
    case DateTime.friday:
      return Weekday.fri;
    default:
      return null;
  }
}
