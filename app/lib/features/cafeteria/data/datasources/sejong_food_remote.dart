import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/cafeteria/domain/entities/food_models.dart';

class SejongFoodRemote {
  SejongFoodRemote({required this.client});
  final SejongApiClient client;

  Future<List<CafeteriaBuilding>> fetchBuildings() async {
    final res = await client.dio.get<dynamic>(SejongEndpoints.foodBuildings);
    return client.unwrap<List<CafeteriaBuilding>>(res, (raw) {
      return (raw as List)
          .cast<Map<String, dynamic>>()
          .map(CafeteriaBuilding.fromJson)
          .toList();
    });
  }

  Future<List<CafeteriaPlace>> fetchPlaces(int buildingId) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.foodPlacesOfBuilding(buildingId),
    );
    return client.unwrap<List<CafeteriaPlace>>(res, (raw) {
      return (raw as List)
          .cast<Map<String, dynamic>>()
          .map(CafeteriaPlace.fromJson)
          .toList();
    });
  }

  Future<List<MealType>> fetchMealTypes(int placeId) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.foodMealTypes(placeId),
    );
    return client.unwrap<List<MealType>>(res, (raw) {
      return (raw as List)
          .cast<Map<String, dynamic>>()
          .map(MealType.fromJson)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    });
  }

  /// 일자별 schedule 요약 — MEAL_TIME 식당. 빈 배열은 "메뉴 없음".
  Future<List<MealScheduleSummary>> fetchSchedulesForDate({
    required String yyyyMmDd,
    required int placeId,
  }) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.foodSchedulesOfDate(yyyyMmDd, placeId: placeId),
    );
    return client.unwrap<List<MealScheduleSummary>>(res, (raw) {
      final list = (raw as List?) ?? const [];
      return list
          .cast<Map<String, dynamic>>()
          .map(MealScheduleSummary.fromJson)
          .toList()
        ..sort((a, b) => a.mealTypeId.compareTo(b.mealTypeId));
    });
  }

  /// schedule 한 건의 메뉴 list. summary가 menuCount > 0일 때만 호출.
  Future<MealScheduleDetail> fetchScheduleDetail(int scheduleId) async {
    final res = await client.dio.get<dynamic>(
      '${SejongPrefix.publicApi}/food/schedules/$scheduleId/detail',
    );
    return client.unwrap<MealScheduleDetail>(
      res,
      (raw) =>
          MealScheduleDetail.fromJson((raw as Map).cast<String, dynamic>()),
    );
  }

  /// STATIC_MENU 식당의 고정 메뉴판 — 한 번 호출.
  Future<List<StaticMenuItem>> fetchStaticMenus(int placeId) async {
    final res = await client.dio.get<dynamic>(
      '${SejongPrefix.publicApi}/food/menus/places/$placeId',
    );
    return client.unwrap<List<StaticMenuItem>>(res, (raw) {
      return (raw as List)
          .cast<Map<String, dynamic>>()
          .map(StaticMenuItem.fromJson)
          .toList();
    });
  }
}
