import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';

/// 세종 공식 API + 디스크 캐시로 [Timetable]을 제공.
///
/// `cache-first`: 첫 호출은 디스크에 있으면 즉시 반환, 없거나 `forceRefresh=true`
/// 면 네트워크 fetch + 캐시 덮어쓰기. UI는 `SejongRefresh` 당김 때만 강제 갱신.
abstract class SejongTimetableRepository {
  /// 가용 학기 목록 — `/available-semesters`.
  Future<List<Semester>> fetchAvailableSemesters();

  /// 학기별 시간표. [forceRefresh]=true면 네트워크에서 새로 받아 캐시 갱신.
  Future<Timetable> loadTimetable({
    required Semester semester,
    bool forceRefresh = false,
  });
}
