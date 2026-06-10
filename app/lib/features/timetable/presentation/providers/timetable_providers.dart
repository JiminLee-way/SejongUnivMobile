import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/core/demo/demo.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/timetable/data/datasources/sejong_timetable_cache.dart';
import 'package:sejong_smart_campus/features/timetable/data/datasources/sejong_timetable_remote.dart';
import 'package:sejong_smart_campus/features/timetable/data/repositories/sejong_timetable_repository_impl.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/features/timetable/domain/repositories/sejong_timetable_repository.dart';

final _remoteProvider = FutureProvider<SejongTimetableRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongTimetableRemote(client: client);
});

final _cacheProvider = Provider<SejongTimetableCache>(
  (ref) => SejongTimetableCache(),
);

/// 시간표 repository — 인증된 사용자 학번에 묶여있다.
final sejongTimetableRepositoryProvider =
    FutureProvider<SejongTimetableRepository?>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return null;
      final remote = await ref.watch(_remoteProvider.future);
      final cache = ref.watch(_cacheProvider);
      return SejongTimetableRepositoryImpl(
        remote: remote,
        cache: cache,
        userId: user.userId,
      );
    });

/// 가용 학기 목록 — `/available-semesters`.
final availableSemestersProvider = FutureProvider<List<Semester>>((ref) async {
  final repo = await ref.watch(sejongTimetableRepositoryProvider.future);
  if (repo == null) return const [];
  return repo.fetchAvailableSemesters();
});

/// 학기별 시간표 — 첫 진입 시 디스크 캐시 우선 (cache-first), 없으면 네트워크.
///
/// pull-to-refresh는 [refreshTimetableForSemester]를 호출해 강제 재요청 + provider
/// invalidate.
final timetableForSemesterProvider = FutureProvider.autoDispose
    .family<Timetable, Semester>((ref, semester) async {
      if (ref.watch(demoModeProvider)) return demoTimetable(semester);
      final repo = await ref.watch(sejongTimetableRepositoryProvider.future);
      if (repo == null) {
        return Timetable(semester: semester, courses: const []);
      }
      return repo.loadTimetable(semester: semester);
    });

/// `SejongRefresh`의 onRefresh에서 호출. 네트워크 강제 + 캐시 덮어쓰기 후
/// 동일 학기 provider invalidate → 다음 build가 새 캐시를 즉시 읽음.
///
/// Widget 측에서 호출하므로 [WidgetRef]를 받는다.
Future<void> refreshTimetableForSemester(
  WidgetRef ref,
  Semester semester,
) async {
  final repo = await ref.read(sejongTimetableRepositoryProvider.future);
  if (repo == null) return;
  await repo.loadTimetable(semester: semester, forceRefresh: true);
  ref.invalidate(timetableForSemesterProvider(semester));
}
