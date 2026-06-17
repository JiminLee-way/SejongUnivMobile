import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/app_update/data/datasources/app_update_recommendation_dismiss_local.dart';
import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_config.dart';
import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_recommendation.dart';

void main() {
  group('app update verdict', () {
    test('currentBuild < latestBuildNumber이면 recommended', () {
      const config = AppUpdateConfig(
        minBuildNumber: 5,
        latestBuildNumber: 10,
        storeUrl: '',
      );

      expect(config.verdictFor(9), AppUpdateVerdict.recommended);
    });

    test('currentBuild >= latestBuildNumber이면 none', () {
      const config = AppUpdateConfig(
        minBuildNumber: 5,
        latestBuildNumber: 10,
        storeUrl: '',
      );

      expect(config.verdictFor(10), AppUpdateVerdict.none);
    });

    test('currentBuild < minBuildNumber이면 forced가 recommended보다 우선', () {
      const config = AppUpdateConfig(
        minBuildNumber: 10,
        latestBuildNumber: 20,
        storeUrl: '',
      );

      expect(config.verdictFor(9), AppUpdateVerdict.forced);
    });
  });

  group('AppUpdateRecommendationDismissLocal', () {
    late Directory tempDir;
    late AppUpdateRecommendationDismissLocal local;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'app_update_dismiss_test_',
      );
      local = AppUpdateRecommendationDismissLocal(
        fileForTesting: File('${tempDir.path}/dismiss.json'),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('같은 latestBuildNumber에서 하루 동안 숨김 상태를 유지한다', () async {
      final now = DateTime(2026, 6, 17, 12);

      await local.snoozeForOneDay(latestBuildNumber: 10, now: now);

      expect(
        await local.isDismissed(
          latestBuildNumber: 10,
          now: now.add(const Duration(hours: 23, minutes: 59)),
        ),
        isTrue,
      );
    });

    test('24시간 후에는 다시 표시된다', () async {
      final now = DateTime(2026, 6, 17, 12);

      await local.snoozeForOneDay(latestBuildNumber: 10, now: now);

      expect(
        await local.isDismissed(
          latestBuildNumber: 10,
          now: now.add(const Duration(hours: 24, minutes: 1)),
        ),
        isFalse,
      );
    });

    test('latestBuildNumber가 증가하면 기존 숨김을 무시한다', () async {
      final now = DateTime(2026, 6, 17, 12);

      await local.snoozeForOneDay(latestBuildNumber: 10, now: now);

      expect(
        await local.isDismissed(
          latestBuildNumber: 11,
          now: now.add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    });
  });

  test('shouldShowRecommendedUpdate handles null and expired state', () {
    final now = DateTime(2026, 6, 17, 12);
    final dismissState = AppUpdateRecommendationDismissState(
      latestBuildNumber: 10,
      dismissedUntil: now.subtract(const Duration(minutes: 1)),
    );

    expect(
      shouldShowRecommendedUpdate(
        latestBuildNumber: 10,
        dismissState: dismissState,
        now: now,
      ),
      isTrue,
    );
  });
}
