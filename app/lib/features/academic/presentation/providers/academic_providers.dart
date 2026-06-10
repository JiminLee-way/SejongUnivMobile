import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/academic/data/datasources/sejong_academic_remote.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';

final _academicRemoteProvider = FutureProvider<SejongAcademicRemote>((
  ref,
) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongAcademicRemote(client: client);
});

String _yyyymmdd(DateTime d) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${d.year}${pad(d.month)}${pad(d.day)}';
}

/// 학사 캘린더 화면이 현재 보고 있는 날짜.
class CalendarDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  set value(DateTime d) => state = d;
}

final calendarDateProvider = NotifierProvider<CalendarDateNotifier, DateTime>(
  CalendarDateNotifier.new,
);

/// 현재 보고 있는 월 (1일로 normalize). 그리드/marks fetch에 사용.
class CalendarMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  set value(DateTime d) => state = DateTime(d.year, d.month, 1);

  void shift(int months) {
    final cur = state;
    final nm = cur.month + months;
    final y = cur.year + ((nm - 1) ~/ 12);
    final m = ((nm - 1) % 12 + 12) % 12 + 1;
    state = DateTime(y, m, 1);
  }
}

final calendarMonthProvider = NotifierProvider<CalendarMonthNotifier, DateTime>(
  CalendarMonthNotifier.new,
);

final dailyCalendarProvider = FutureProvider.autoDispose
    .family<List<CalendarItem>, DateTime>((ref, date) async {
      final remote = await ref.watch(_academicRemoteProvider.future);
      return remote.fetchDailyCalendar(_yyyymmdd(date));
    });

final studentDailyAllProvider = FutureProvider.autoDispose
    .family<List<CalendarItem>, DateTime>((ref, date) async {
      final remote = await ref.watch(_academicRemoteProvider.future);
      return remote.fetchStudentDailyAll(_yyyymmdd(date));
    });

final gradesProvider = FutureProvider<GradeInquiry>((ref) async {
  ref.watch(currentUserProvider);
  final remote = await ref.watch(_academicRemoteProvider.future);
  return remote.fetchGrades();
});

/// 성적 화면에서 사용자가 선택한 학기 키. `null` = `/grade-inquiry/all`의
/// 서버 기본 selectedSemester (보통 최근 학기) 사용.
class SelectedGradeSemesterNotifier
    extends Notifier<({String year, String smtCd})?> {
  @override
  ({String year, String smtCd})? build() => null;

  void select(String year, String smtCd) => state = (year: year, smtCd: smtCd);
  void reset() => state = null;
}

final selectedGradeSemesterProvider =
    NotifierProvider<
      SelectedGradeSemesterNotifier,
      ({String year, String smtCd})?
    >(SelectedGradeSemesterNotifier.new);

/// 특정 학기 detail. `/all` 의 기본 selectedSemester 와 동일하면 굳이 새로
/// 호출하지 않아도 되지만, 위젯에서 그 분기를 처리하므로 여기서는 항상 fetch.
final gradeSemesterProvider = FutureProvider.autoDispose
    .family<GradeSelectedSemester, ({String year, String smtCd})>((
      ref,
      key,
    ) async {
      ref.watch(currentUserProvider);
      final remote = await ref.watch(_academicRemoteProvider.future);
      return remote.fetchGradeSemester(key.year, key.smtCd);
    });

// ─── 월 grid 데이터 ────────────────────────────────────────────────────────

/// 월간 marks — `(year, month)` family. 응답이 가볍고 month 전환마다 재호출
/// 되므로 autoDispose.
final monthlyMarksProvider = FutureProvider.autoDispose
    .family<MonthlyMarks, ({int year, int month})>((ref, key) async {
      final remote = await ref.watch(_academicRemoteProvider.future);
      try {
        return await remote.fetchMonthlyMarks(key.year, key.month);
      } catch (_) {
        return MonthlyMarks.empty(key.year, key.month);
      }
    });

final organizationTypesProvider = FutureProvider<List<OrganizationType>>((
  ref,
) async {
  final remote = await ref.watch(_academicRemoteProvider.future);
  try {
    return await remote.fetchOrganizationTypes();
  } catch (_) {
    return const <OrganizationType>[];
  }
});

/// 사용자가 선택한 학과 필터(이름 set). 빈 set = 전체.
class OrgFilterNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String name) {
    final next = Set<String>.from(state);
    if (!next.add(name)) next.remove(name);
    state = next;
  }

  void clear() => state = <String>{};
  void set(Set<String> names) => state = Set<String>.from(names);
}

final orgFilterProvider = NotifierProvider<OrgFilterNotifier, Set<String>>(
  OrgFilterNotifier.new,
);

/// 공식 학사일정 (날짜별) + 학과 필터 적용 + dedup.
final filteredDailyCalendarProvider = Provider.autoDispose
    .family<AsyncValue<List<CalendarItemGroup>>, DateTime>((ref, date) {
      final async = ref.watch(dailyCalendarProvider(date));
      final filter = ref.watch(orgFilterProvider);
      return async.whenData((items) {
        final src = filter.isEmpty
            ? items
            : items.where((i) {
                final n = i.divisionName;
                return n != null && filter.contains(n);
              }).toList();
        return CalendarItemGroup.groupItems(src);
      });
    });

/// 학생 일정 (날짜별) + 학과 필터 적용 + dedup.
final filteredStudentDailyProvider = Provider.autoDispose
    .family<AsyncValue<List<CalendarItemGroup>>, DateTime>((ref, date) {
      final async = ref.watch(studentDailyAllProvider(date));
      final filter = ref.watch(orgFilterProvider);
      return async.whenData((items) {
        final src = filter.isEmpty
            ? items
            : items.where((i) {
                final n = i.divisionName;
                return n != null && filter.contains(n);
              }).toList();
        return CalendarItemGroup.groupItems(src);
      });
    });
