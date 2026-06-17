import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/app_update/data/datasources/app_update_recommendation_dismiss_local.dart';
import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_config.dart';
import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_recommendation.dart';
import 'package:sejong_smart_campus/features/app_update/presentation/providers/app_update_providers.dart';
import 'package:sejong_smart_campus/features/app_update/presentation/widgets/recommended_update_home_prompt.dart';

void main() {
  group('RecommendedUpdateHomePrompt', () {
    late _FakeAppUpdateRecommendationDismissLocal local;
    late List<String> launchedUrls;

    setUp(() async {
      local = _FakeAppUpdateRecommendationDismissLocal();
      launchedUrls = <String>[];
    });

    testWidgets('Home 진입 후 권고 상태면 커스텀 팝업이 표시된다', (tester) async {
      await tester.pumpWidget(_app(local: local));

      await tester.pumpRecommendedPrompt();

      expect(find.text('새로운 버전이 출시되었어요.'), findsOneWidget);
      expect(find.text('업데이트하러가기'), findsOneWidget);
      expect(find.text('하루 동안 보지 않기'), findsOneWidget);
      expect(find.byTooltip('닫기'), findsOneWidget);
    });

    testWidgets('업데이트하러가기는 storeUrl을 launcher로 전달한다', (tester) async {
      await tester.pumpWidget(
        _app(
          local: local,
          launcher: (url) async {
            launchedUrls.add(url);
            return true;
          },
        ),
      );
      await tester.pumpRecommendedPrompt();

      await tester.tap(find.text('업데이트하러가기'));
      await tester.pumpAndSettle();

      expect(launchedUrls, [_storeUrl]);
    });

    testWidgets('하루 동안 보지 않기는 local dismiss 상태를 저장한다', (tester) async {
      await tester.pumpWidget(_app(local: local));
      await tester.pumpRecommendedPrompt();

      await tester.tap(find.text('하루 동안 보지 않기'));
      await tester.pumpAndSettle();

      final state = await local.read();
      expect(state?.latestBuildNumber, 10);
      expect(await local.isDismissed(latestBuildNumber: 10), isTrue);
      expect(find.text('새로운 버전이 출시되었어요.'), findsNothing);
    });

    testWidgets('X 닫기는 현재 세션만 닫고 local dismiss는 저장하지 않는다', (tester) async {
      await tester.pumpWidget(_app(local: local));
      await tester.pumpRecommendedPrompt();

      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();

      expect(await local.read(), isNull);
      expect(find.text('새로운 버전이 출시되었어요.'), findsNothing);
    });

    testWidgets('forced 상태에서는 권고 팝업을 표시하지 않는다', (tester) async {
      await tester.pumpWidget(
        _app(
          local: local,
          status: AppUpdateStatus(AppUpdateVerdict.forced, _config()),
        ),
      );

      await tester.pumpRecommendedPrompt();

      expect(find.text('새로운 버전이 출시되었어요.'), findsNothing);
    });

    testWidgets('local dismiss가 유효하면 팝업을 표시하지 않는다', (tester) async {
      await local.snoozeForOneDay(latestBuildNumber: 10);

      await tester.pumpWidget(_app(local: local));
      await tester.pumpRecommendedPrompt();

      expect(find.text('새로운 버전이 출시되었어요.'), findsNothing);
    });
  });
}

const _storeUrl =
    'https://play.google.com/store/apps/details?id=sejong.sejong_univ_station';

Widget _app({
  required AppUpdateRecommendationDismissLocal local,
  AppUpdateStatus? status,
  Future<bool> Function(String url)? launcher,
}) {
  return ProviderScope(
    overrides: [
      appUpdateStatusProvider.overrideWith(
        (ref) async =>
            status ?? AppUpdateStatus(AppUpdateVerdict.recommended, _config()),
      ),
      appUpdateRecommendationDismissLocalProvider.overrideWithValue(local),
      appUpdateStoreLauncherProvider.overrideWithValue(
        launcher ?? ((_) async => true),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: RecommendedUpdateHomePrompt()),
    ),
  );
}

AppUpdateConfig _config() {
  return const AppUpdateConfig(
    minBuildNumber: 5,
    latestBuildNumber: 10,
    storeUrl: _storeUrl,
  );
}

class _FakeAppUpdateRecommendationDismissLocal
    extends AppUpdateRecommendationDismissLocal {
  _FakeAppUpdateRecommendationDismissLocal();

  AppUpdateRecommendationDismissState? _state;

  @override
  Future<AppUpdateRecommendationDismissState?> read() async => _state;

  @override
  Future<bool> isDismissed({
    required int latestBuildNumber,
    DateTime? now,
  }) async {
    return !shouldShowRecommendedUpdate(
      latestBuildNumber: latestBuildNumber,
      dismissState: _state,
      now: now ?? DateTime.now(),
    );
  }

  @override
  Future<void> snoozeForOneDay({
    required int latestBuildNumber,
    DateTime? now,
  }) async {
    final base = now ?? DateTime.now();
    _state = AppUpdateRecommendationDismissState(
      latestBuildNumber: latestBuildNumber,
      dismissedUntil: base.add(const Duration(hours: 24)),
    );
  }
}

extension on WidgetTester {
  Future<void> pumpRecommendedPrompt() async {
    for (var i = 0; i < 8; i += 1) {
      await pump(const Duration(milliseconds: 100));
    }
  }
}
