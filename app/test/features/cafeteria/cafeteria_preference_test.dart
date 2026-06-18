import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sejong_smart_campus/features/cafeteria/data/datasources/cafeteria_settings_storage.dart';
import 'package:sejong_smart_campus/features/cafeteria/domain/entities/food_models.dart';
import 'package:sejong_smart_campus/features/cafeteria/domain/entities/happydorm_models.dart';
import 'package:sejong_smart_campus/features/cafeteria/presentation/providers/cafeteria_providers.dart';
import 'package:sejong_smart_campus/features/cafeteria/presentation/screens/cafeteria_screen.dart';

void main() {
  testWidgets('군자관 기본 식당은 건물 목록이 늦게 도착해도 다시 반영된다', (tester) async {
    final buildings = Completer<List<CafeteriaBuilding>>();
    final container = ProviderContainer(
      overrides: [
        cafeteriaPreferenceProvider.overrideWith(_GunjaPreference.new),
        buildingsProvider.overrideWith((ref) => buildings.future),
        placesForBuildingProvider.overrideWith((ref, buildingId) async {
          return const <CafeteriaPlace>[];
        }),
        happydormWeeklyMenuProvider.overrideWith((ref, monday) async {
          return HappydormWeeklyMenu.empty;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CafeteriaScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(
      container.read(selectedBuildingIdProvider),
      happydormVirtualBuildingId,
    );

    buildings.complete([
      const CafeteriaBuilding(id: 10, name: '군자관', location: ''),
      const CafeteriaBuilding(id: 20, name: '학생회관', location: ''),
    ]);

    await tester.pump();
    await tester.pump();

    expect(container.read(selectedBuildingIdProvider), 10);
  });
}

class _GunjaPreference extends CafeteriaPreferenceNotifier {
  @override
  Future<CafeteriaPreference?> build() async => CafeteriaPreference.gunja;
}
