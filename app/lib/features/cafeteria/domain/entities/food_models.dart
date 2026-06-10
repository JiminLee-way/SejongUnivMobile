/// 학식 도메인 응답 매핑.
library;

import 'package:sejong_smart_campus/core/network/service_urls.dart';

class CafeteriaBuilding {
  const CafeteriaBuilding({
    required this.id,
    required this.name,
    required this.location,
    this.fileId,
  });
  final int id;
  final String name;
  final String location;
  final String? fileId;

  /// 식당 이미지 URL.
  String? get imageUrl => fileId == null
      ? null
      : ServiceUrls.join(
          ServiceUrls.sejongApi,
          '/filesv/api/files/$fileId/view?tenantId=SEJONG',
        );

  factory CafeteriaBuilding.fromJson(Map<String, dynamic> json) =>
      CafeteriaBuilding(
        id: (json['buildingId'] as num).toInt(),
        name: (json['buildingName'] ?? '').toString(),
        location: (json['location'] ?? '').toString(),
        fileId: json['fileId'] as String?,
      );
}

enum PlaceOperation {
  /// 일자별 schedule (중·석식) — `/food/schedules/date/...` + `/schedules/{id}/detail`.
  mealTime,

  /// 고정 메뉴판 — `/food/menus/places/{placeId}` 한 번 호출.
  staticMenu;

  factory PlaceOperation.fromCode(String code) => switch (code) {
    'MEAL_TIME' => PlaceOperation.mealTime,
    'STATIC_MENU' => PlaceOperation.staticMenu,
    _ => PlaceOperation.mealTime,
  };
}

class CafeteriaPlace {
  const CafeteriaPlace({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.operation,
  });
  final int id;
  final int buildingId;
  final String name;
  final PlaceOperation operation;

  factory CafeteriaPlace.fromJson(Map<String, dynamic> json) => CafeteriaPlace(
    id: (json['placeId'] as num).toInt(),
    buildingId: (json['buildingId'] as num).toInt(),
    name: (json['placeName'] ?? '').toString(),
    operation: PlaceOperation.fromCode(
      (json['operationType'] ?? '').toString(),
    ),
  );
}

class MealType {
  const MealType({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.sortOrder,
  });
  final int id;
  final String name;
  final int basePrice;
  final int sortOrder;

  factory MealType.fromJson(Map<String, dynamic> json) => MealType(
    id: (json['mealTypeId'] as num).toInt(),
    name: (json['mealName'] ?? '').toString(),
    basePrice: ((json['basePrice'] as num?) ?? 0).toInt(),
    sortOrder: ((json['sortOrder'] as num?) ?? 0).toInt(),
  );
}

/// 일자별 schedule 요약 — 메뉴 list는 별도 `/schedules/{id}/detail` 호출로.
class MealScheduleSummary {
  const MealScheduleSummary({
    required this.scheduleId,
    required this.placeId,
    required this.placeName,
    required this.mealTypeId,
    required this.mealTypeName,
    required this.menuDate,
    required this.totalPrice,
    required this.totalPriceVisible,
    required this.menuCount,
  });
  final int scheduleId;
  final int placeId;
  final String placeName;
  final int mealTypeId;
  final String mealTypeName;
  final String menuDate;
  final int totalPrice;
  final bool totalPriceVisible;
  final int menuCount;

  factory MealScheduleSummary.fromJson(Map<String, dynamic> json) =>
      MealScheduleSummary(
        scheduleId: (json['scheduleId'] as num).toInt(),
        placeId: (json['placeId'] as num).toInt(),
        placeName: (json['placeName'] ?? '').toString(),
        mealTypeId: ((json['mealTypeId'] as num?) ?? 0).toInt(),
        mealTypeName: (json['mealTypeName'] ?? '').toString(),
        menuDate: (json['menuDate'] ?? '').toString(),
        totalPrice: ((json['totalPrice'] as num?) ?? 0).toInt(),
        totalPriceVisible: json['totalPriceVisible'] == true,
        menuCount: ((json['menuCount'] as num?) ?? 0).toInt(),
      );
}

/// schedule 상세 — `{schedule, menus[]}`.
class MealScheduleDetail {
  const MealScheduleDetail({required this.summary, required this.menus});
  final MealScheduleSummary summary;
  final List<MealScheduleMenu> menus;

  factory MealScheduleDetail.fromJson(Map<String, dynamic> json) {
    final s = (json['schedule'] as Map).cast<String, dynamic>();
    final menus =
        ((json['menus'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(MealScheduleMenu.fromJson)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return MealScheduleDetail(
      summary: MealScheduleSummary.fromJson(s),
      menus: menus,
    );
  }
}

class MealScheduleMenu {
  const MealScheduleMenu({
    required this.scheduleMenuId,
    required this.menuName,
    required this.sortOrder,
    required this.menuPrice,
    required this.priceVisible,
    this.remark,
    this.calories,
    this.menuImageUrl,
  });
  final int scheduleMenuId;
  final String menuName;
  final int sortOrder;
  final int menuPrice;
  final bool priceVisible;
  final String? remark;
  final int? calories;
  final String? menuImageUrl;

  factory MealScheduleMenu.fromJson(Map<String, dynamic> json) =>
      MealScheduleMenu(
        scheduleMenuId: (json['scheduleMenuId'] as num).toInt(),
        menuName: (json['menuName'] ?? '').toString(),
        sortOrder: ((json['sortOrder'] as num?) ?? 0).toInt(),
        menuPrice: ((json['menuPrice'] as num?) ?? 0).toInt(),
        priceVisible: json['priceVisible'] == true,
        remark: json['remark'] as String?,
        calories: (json['calories'] as num?)?.toInt(),
        menuImageUrl: (json['menuImageUrl'] as String?)?.trim().isEmpty == true
            ? null
            : json['menuImageUrl'] as String?,
      );
}

/// 고정 메뉴 한 항목 (STATIC_MENU).
class StaticMenuItem {
  const StaticMenuItem({
    required this.menuId,
    required this.placeId,
    required this.menuName,
    required this.defaultPrice,
    this.calories,
    this.allergyInfo,
    this.menuImageUrl,
  });
  final int menuId;
  final int placeId;
  final String menuName;
  final int defaultPrice;
  final int? calories;
  final String? allergyInfo;
  final String? menuImageUrl;

  factory StaticMenuItem.fromJson(Map<String, dynamic> json) => StaticMenuItem(
    menuId: (json['menuId'] as num).toInt(),
    placeId: (json['placeId'] as num).toInt(),
    menuName: (json['menuName'] ?? '').toString(),
    defaultPrice: ((json['defaultPrice'] as num?) ?? 0).toInt(),
    calories: (json['calories'] as num?)?.toInt(),
    allergyInfo: (json['allergyInfo'] as String?)?.trim().isEmpty == true
        ? null
        : json['allergyInfo'] as String?,
    menuImageUrl: (json['menuImageUrl'] as String?)?.trim().isEmpty == true
        ? null
        : json['menuImageUrl'] as String?,
  );
}
