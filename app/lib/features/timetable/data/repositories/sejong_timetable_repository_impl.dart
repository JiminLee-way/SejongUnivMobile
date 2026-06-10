import 'package:sejong_smart_campus/features/timetable/data/datasources/sejong_timetable_cache.dart';
import 'package:sejong_smart_campus/features/timetable/data/datasources/sejong_timetable_mapper.dart';
import 'package:sejong_smart_campus/features/timetable/data/datasources/sejong_timetable_remote.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/features/timetable/domain/repositories/sejong_timetable_repository.dart';

class SejongTimetableRepositoryImpl implements SejongTimetableRepository {
  SejongTimetableRepositoryImpl({
    required this.remote,
    required this.cache,
    required this.userId,
  });

  final SejongTimetableRemote remote;
  final SejongTimetableCache cache;
  final String userId;

  @override
  Future<List<Semester>> fetchAvailableSemesters() async {
    final raw = await remote.fetchAvailableSemesters();
    final mapped = <Semester>{};
    for (final e in raw) {
      final year = (e['year'] ?? '').toString();
      final smt = (e['smtCd'] ?? '').toString();
      final s = SejongTimetableMapper.toSemester(year, smt);
      if (s != null) mapped.add(s);
    }
    // 표시 순서: 최신 학기가 앞.
    final list = mapped.toList()..sort((a, b) => b.short.compareTo(a.short));
    return list;
  }

  @override
  Future<Timetable> loadTimetable({
    required Semester semester,
    bool forceRefresh = false,
  }) async {
    final key = SejongTimetableMapper.toSejongKey(semester);
    if (key == null) {
      // 매핑 안 되는 학기 — 빈 시간표.
      return Timetable(semester: semester, courses: const []);
    }
    final (year, smtCd) = key;

    if (!forceRefresh) {
      final cached = await cache.read(userId: userId, year: year, smtCd: smtCd);
      if (cached != null) {
        return _mapFromRaw(semester, cached.timetable, cached.enrolled);
      }
    }

    // 네트워크 — timetable + enrolled 병렬.
    final results = await Future.wait([
      remote.fetchTimetable(year: year, smtCd: smtCd),
      remote.fetchEnrolledCourses(year: year, smtCd: smtCd),
    ]);
    final timetableRaw = results[0];
    final enrolledRaw = results[1];

    // 캐시 fire-and-forget — 실패해도 시간표 표시엔 영향 없음.
    unawaited(
      cache.write(
        userId: userId,
        year: year,
        smtCd: smtCd,
        timetable: timetableRaw,
        enrolled: enrolledRaw,
      ),
    );

    return _mapFromRaw(semester, timetableRaw, enrolledRaw);
  }

  Timetable _mapFromRaw(
    Semester semester,
    Map<String, dynamic> timetableRaw,
    Map<String, dynamic> enrolledRaw,
  ) {
    final cells = ((timetableRaw['courses'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final cyberLectures = ((timetableRaw['cyberLectures'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final enrolled = ((enrolledRaw['courses'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    return SejongTimetableMapper.buildTimetable(
      semester: semester,
      enrolled: enrolled,
      cells: cells,
      cyberLectures: cyberLectures,
    );
  }
}

/// dart:async의 `unawaited`를 별도 import 없이 사용하기 위한 작은 helper.
void unawaited(Future<void> f) {}
