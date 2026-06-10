import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';

/// 친구 시간표 열람 providers.
///
/// 데이터는 친구 본인이 로그인할 때 백업한 슬롯을 서버가 친구 관계 검증 후
/// 복호화해 내려준 jsonb다. 즉 mock이
/// 아니라 친구의 실제 수강 시간표. 별도 공개/비공개 토글은 없고, 노출을 원치
/// 않으면 검색 비노출(searchable=false)이나 친구 미수락으로 통제한다.

/// 친구가 업로드한 학기 목록(최신순). 친구 시간표 뷰어의 학기 칩을 이걸로 제한.
final friendSharedSemestersProvider = FutureProvider.autoDispose
    .family<List<Semester>, String>((ref, friendId) async {
      final remote = ref.watch(supabaseFriendsRemoteProvider);
      final names = await remote.getFriendTimetableSemesters(friendId);
      final sems = [for (final n in names) ?_semesterByName(n)];
      // DB의 `order by semester desc`는 enum name 문자열 알파벳순이라 시간순이 아님.
      // enum index(과거→최신)로 최신순 정렬.
      sems.sort((a, b) => b.index.compareTo(a.index));
      return sems;
    });

/// 친구의 특정 학기 시간표. 데이터 없으면 빈 Timetable.
final friendTimetableProvider = FutureProvider.autoDispose
    .family<Timetable, ({String friendId, Semester semester})>((
      ref,
      args,
    ) async {
      final remote = ref.watch(supabaseFriendsRemoteProvider);
      final slots = await remote.getFriendTimetable(
        args.friendId,
        args.semester.name,
      );
      if (slots == null) {
        return Timetable(semester: args.semester, courses: const []);
      }
      return timetableFromSlots(args.semester, slots);
    });

// ─── 역직렬화 — 서버 백업 slots jsonb → Timetable ───────────────────────────
// 직렬화 포맷(timetable_sync_provider._serialize):
//   {courses:[{id,code,name,professor,location,credits,palette,
//              times:[{weekday, start:"H:M", end:"H:M"}]}]}

Timetable timetableFromSlots(Semester semester, Map<String, dynamic> slots) {
  final rawCourses = (slots['courses'] as List?) ?? const [];
  final courses = <Course>[];
  for (final rc in rawCourses) {
    if (rc is! Map) continue;
    final times = <CourseTime>[];
    for (final rt in (rc['times'] as List?) ?? const []) {
      if (rt is! Map) continue;
      final wd = _weekdayByName(rt['weekday']?.toString());
      final start = _hm(rt['start']?.toString());
      final end = _hm(rt['end']?.toString());
      if (wd == null || start == null || end == null) continue;
      times.add(CourseTime(weekday: wd, start: start, end: end));
    }
    courses.add(
      Course(
        id: (rc['id'] ?? '').toString(),
        code: (rc['code'] ?? '').toString(),
        name: (rc['name'] ?? '강의').toString(),
        professor: (rc['professor'] ?? '').toString(),
        location: (rc['location'] ?? '').toString(),
        credits: (rc['credits'] as num?)?.toInt() ?? 3,
        palette: _paletteByName(rc['palette']?.toString()),
        times: times,
      ),
    );
  }
  return Timetable(semester: semester, courses: courses);
}

Semester? _semesterByName(String name) {
  for (final s in Semester.values) {
    if (s.name == name) return s;
  }
  return null;
}

Weekday? _weekdayByName(String? name) {
  if (name == null) return null;
  for (final w in Weekday.values) {
    if (w.name == name) return w;
  }
  return null;
}

CoursePalette _paletteByName(String? name) {
  for (final p in CoursePalette.values) {
    if (p.name == name) return p;
  }
  return CoursePalette.crimson;
}

/// "H:M" → HMTime. 잘못된 형식이면 null.
HMTime? _hm(String? s) {
  if (s == null) return null;
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return HMTime(h, m);
}
