import 'package:flutter/material.dart';

/// 시간표 도메인 모델.
///
/// 시안용 mock 데이터는 [data/mock/mock_timetable.dart] 참조.
/// API 연결 시 동일한 형태로 매핑한다.

enum Semester {
  spring2025(short: '25-1', label: '2025년 1학기', regular: true),
  summer2025(short: '25-S', label: '2025년 여름학기', regular: false),
  fall2025(short: '25-2', label: '2025년 2학기', regular: true),
  winter2025(short: '25-W', label: '2025년 겨울학기', regular: false),
  spring2026(short: '26-1', label: '2026년 1학기', regular: true);

  const Semester({
    required this.short,
    required this.label,
    required this.regular,
  });

  final String short;
  final String label;
  final bool regular;
}

enum Weekday {
  mon('월'),
  tue('화'),
  wed('수'),
  thu('목'),
  fri('금');

  const Weekday(this.label);
  final String label;
}

/// 24시간 분 단위 시각 — 그리드 배치 계산용.
class HMTime {
  const HMTime(this.hour, this.minute);
  final int hour;
  final int minute;

  /// 09:00 기준 분 단위 오프셋.
  int minutesFrom(int baseHour) => (hour - baseHour) * 60 + minute;
  int get totalMinutes => hour * 60 + minute;

  String format() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class CourseTime {
  const CourseTime({
    required this.weekday,
    required this.start,
    required this.end,
  });

  final Weekday weekday;
  final HMTime start;
  final HMTime end;

  int get durationMinutes => end.totalMinutes - start.totalMinutes;
}

/// 강의 카드 색상 팔레트 — 헥스 색을 직접 들고 다닌다.
/// 글래스 카드 위에서 12% fill + 40% border + 본문 텍스트는 진한 톤으로.
enum CoursePalette {
  crimson(Color(0xFF9E001F)),
  amber(Color(0xFFD97706)),
  sky(Color(0xFF0284C7)),
  emerald(Color(0xFF059669)),
  violet(Color(0xFF7C3AED)),
  rose(Color(0xFFE11D48)),
  indigo(Color(0xFF4F46E5)),
  teal(Color(0xFF0D9488));

  const CoursePalette(this.color);
  final Color color;
}

class Course {
  const Course({
    required this.id,
    required this.code,
    required this.name,
    required this.professor,
    required this.location,
    required this.times,
    required this.palette,
    this.credits = 3,
  });

  final String id;
  final String code;
  final String name;
  final String professor;
  final String location;
  final List<CourseTime> times;
  final CoursePalette palette;
  final int credits;
}

/// 학기별 시간표 묶음 — 학기 변경 시 통째로 교체된다.
class Timetable {
  const Timetable({required this.semester, required this.courses});

  final Semester semester;
  final List<Course> courses;

  int get totalCredits => courses.fold(0, (sum, c) => sum + c.credits);
}

/// 친구 패널 상태.
enum FriendStatus {
  inClass('수업 중', Color(0xFF9E001F)),
  studying('도서관/스터디', Color(0xFF0284C7)),
  free('공강', Color(0xFF059669)),
  offline('학교 밖', Color(0xFF9CA3AF));

  const FriendStatus(this.label, this.color);
  final String label;
  final Color color;
}

class Friend {
  const Friend({
    required this.id,
    required this.name,
    required this.major,
    required this.status,
    this.currentActivity,
    this.nextSlot,
    this.avatarSeed = 0,
  });

  final String id;
  final String name;
  final String major;
  final FriendStatus status;

  /// 현재 진행 중인 활동 — 수업명 또는 장소.
  final String? currentActivity;

  /// 다음 일정 — "다음: 15:00 데이터구조".
  final String? nextSlot;
  final int avatarSeed;
}

/// 친구 초대 검색 결과의 종류.
///
/// `registered`: 우리 앱 가입자 — 인앱 알림으로 친구 요청을 보낸다.
/// `unregistered`: 세종 학적은 일치하지만 미가입 — 외부(카톡/문자)로
/// 1회용 초대 링크를 보낸다.
enum InviteCandidateKind {
  registered(
    sectionLabel: '세종앱 사용자',
    actionLabel: '친구 요청',
    help: '인앱 알림으로 친구 요청을 보냅니다',
  ),
  unregistered(
    sectionLabel: '세종 학생 · 미가입',
    actionLabel: '초대 링크',
    help: '카카오톡/문자로 1회용 초대 링크를 보냅니다',
  );

  const InviteCandidateKind({
    required this.sectionLabel,
    required this.actionLabel,
    required this.help,
  });

  final String sectionLabel;
  final String actionLabel;
  final String help;
}

/// 검색 결과 한 건. 학번은 반드시 마스킹된 형태로만 보유한다.
/// (예: "20193456" → "2019****6"). 원본은 서버 응답에서도 내려오지 않는다.
class InviteCandidate {
  const InviteCandidate({
    required this.id,
    required this.name,
    required this.studentIdMasked,
    required this.major,
    required this.kind,
    this.avatarSeed = 0,
  });

  final String id;
  final String name;
  final String studentIdMasked;
  final String major;
  final InviteCandidateKind kind;
  final int avatarSeed;
}
