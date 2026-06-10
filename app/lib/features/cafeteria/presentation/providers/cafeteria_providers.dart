import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/cafeteria/data/datasources/cafeteria_settings_storage.dart';
import 'package:sejong_smart_campus/features/cafeteria/data/datasources/happydorm_food_remote.dart';
import 'package:sejong_smart_campus/features/cafeteria/data/datasources/sejong_food_remote.dart';
import 'package:sejong_smart_campus/features/cafeteria/domain/entities/food_models.dart';
import 'package:sejong_smart_campus/features/cafeteria/domain/entities/happydorm_models.dart';

final _foodRemoteProvider = FutureProvider<SejongFoodRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongFoodRemote(client: client);
});

final buildingsProvider = FutureProvider<List<CafeteriaBuilding>>((ref) async {
  final remote = await ref.watch(_foodRemoteProvider.future);
  return remote.fetchBuildings();
});

/// 사용자가 현재 보고 있는 건물 id. 기본값은 null — 첫 로딩 후 첫 건물로 셋업.
class SelectedBuildingIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  set value(int? id) => state = id;
}

final selectedBuildingIdProvider =
    NotifierProvider<SelectedBuildingIdNotifier, int?>(
      SelectedBuildingIdNotifier.new,
    );

/// 사용자가 보고 있는 날짜 (오늘 기본).
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  set value(DateTime d) => state = d;
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

String formatDateKey(DateTime d) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${pad(d.month)}-${pad(d.day)}';
}

// autoDispose 없음 — 건물 전환 시 (예: 군자관 → 행복기숙사 → 군자관) 매번
// 재호출되지 않도록 세션 동안 캐시 유지. 데이터는 작은 JSON 이라 메모리 부담
// 적음. 새로고침은 사용자가 명시적으로 pull-to-refresh로 invalidate.

final placesForBuildingProvider =
    FutureProvider.family<List<CafeteriaPlace>, int>((ref, buildingId) async {
      final remote = await ref.watch(_foodRemoteProvider.future);
      return remote.fetchPlaces(buildingId);
    });

final mealTypesForPlaceProvider = FutureProvider.family<List<MealType>, int>((
  ref,
  placeId,
) async {
  final remote = await ref.watch(_foodRemoteProvider.future);
  return remote.fetchMealTypes(placeId);
});

typedef SchedulesKey = ({int placeId, String date});

/// 일자별 schedule 요약 — 끼니별 카드 한 줄. 메뉴 자체는 별도 detail 호출.
final schedulesForPlaceDateProvider =
    FutureProvider.family<List<MealScheduleSummary>, SchedulesKey>((
      ref,
      key,
    ) async {
      final remote = await ref.watch(_foodRemoteProvider.future);
      return remote.fetchSchedulesForDate(
        yyyyMmDd: key.date,
        placeId: key.placeId,
      );
    });

/// 개별 schedule의 메뉴 list — 사용자가 카드 expand할 때만 호출.
final scheduleDetailProvider = FutureProvider.family<MealScheduleDetail, int>((
  ref,
  scheduleId,
) async {
  final remote = await ref.watch(_foodRemoteProvider.future);
  return remote.fetchScheduleDetail(scheduleId);
});

/// STATIC_MENU 식당 고정 메뉴 (캐시처럼 한 번만 fetch).
final staticMenusForPlaceProvider =
    FutureProvider.family<List<StaticMenuItem>, int>((ref, placeId) async {
      final remote = await ref.watch(_foodRemoteProvider.future);
      return remote.fetchStaticMenus(placeId);
    });

// ─── 행복기숙사 ─────────────────────────────────────────────────────────────
//
// 별도 식단 소스를 클라이언트에서 "가상 건물" 한 칸으로 합성한다.
// [happydormVirtualBuildingId] 가 그 가상 id (음수 — 서버 id 와 충돌 회피).

const int happydormVirtualBuildingId = -1000001;
const String happydormBuildingName = '행복기숙사';

final _happydormRemoteProvider = Provider<HappydormFoodRemote>(
  (ref) => HappydormFoodRemote(),
);

/// 해당 날짜가 속한 "주(월~일)" 의 식단. 같은 주의 서로 다른 날짜로 호출돼도
/// 같은 응답을 받으므로 family key 는 그 주의 월요일로 normalize.
///
/// **autoDispose 미사용** — 행복기숙사 응답(WEEKLYMENU 5~7일치)은 작은 JSON 이고
/// 같은 주에 화면을 떠났다 다시 들어와도 새 fetch 불필요. 캐시를 유지해 두 번째
/// 진입부터는 0ms 표시.
final happydormWeeklyMenuProvider =
    FutureProvider.family<HappydormWeeklyMenu, String>((
      ref,
      mondayYyyyMmDd,
    ) async {
      final remote = ref.watch(_happydormRemoteProvider);
      return remote.fetchWeeklyMenu(yyyyMmDd: mondayYyyyMmDd);
    });

/// [date] 가 속한 주의 월요일 — 행복기숙사 weekly cache key.
String mondayOfWeek(DateTime date) {
  final mon = date.subtract(Duration(days: date.weekday - 1));
  return formatDateKey(DateTime(mon.year, mon.month, mon.day));
}

/// 토/일 → true. 계절밥상 등 주말 미운영 식당이 비어있는 시간대.
bool isWeekend(DateTime d) =>
    d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

// ─── 설정 (기본 건물) ────────────────────────────────────────────────────────

final _settingsStorageProvider = Provider<CafeteriaSettingsStorage>(
  (_) => CafeteriaSettingsStorage(),
);

/// 사용자가 설정한 기본 건물. null = 아직 미설정(첫 진입) → 온보딩 다이얼로그
/// 표시. 한 번 저장되면 다음 진입부터는 그 값으로 자동선택.
class CafeteriaPreferenceNotifier extends AsyncNotifier<CafeteriaPreference?> {
  CafeteriaSettingsStorage get _storage => ref.read(_settingsStorageProvider);

  @override
  Future<CafeteriaPreference?> build() async {
    return _storage.loadDefaultBuilding();
  }

  Future<void> set(CafeteriaPreference pref) async {
    state = AsyncData(pref);
    await _storage.saveDefaultBuilding(pref);
  }
}

final cafeteriaPreferenceProvider =
    AsyncNotifierProvider<CafeteriaPreferenceNotifier, CafeteriaPreference?>(
      CafeteriaPreferenceNotifier.new,
    );
