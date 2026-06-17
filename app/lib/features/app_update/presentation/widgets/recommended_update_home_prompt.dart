import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_config.dart';
import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_recommendation.dart';
import 'package:sejong_smart_campus/features/app_update/presentation/providers/app_update_providers.dart';
import 'package:sejong_smart_campus/features/app_update/presentation/widgets/recommended_update_dialog.dart';

class RecommendedUpdateHomePrompt extends ConsumerStatefulWidget {
  const RecommendedUpdateHomePrompt({super.key});

  @override
  ConsumerState<RecommendedUpdateHomePrompt> createState() =>
      _RecommendedUpdateHomePromptState();
}

class _RecommendedUpdateHomePromptState
    extends ConsumerState<RecommendedUpdateHomePrompt> {
  ProviderSubscription<AsyncValue<AppUpdateStatus>>? _subscription;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<AsyncValue<AppUpdateStatus>>(
      appUpdateStatusProvider,
      (_, next) => next.whenData(_maybeShow),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  void _maybeShow(AppUpdateStatus status) {
    final config = status.config;
    if (_showing ||
        status.verdict != AppUpdateVerdict.recommended ||
        config == null) {
      return;
    }
    final latestBuildNumber = config.latestBuildNumber;
    if (latestBuildNumber <= 0) return;
    if (ref
        .read(appUpdateSessionDismissedBuildsProvider.notifier)
        .contains(latestBuildNumber)) {
      return;
    }

    _showing = true;
    Future<void>.microtask(() {
      unawaited(_showAfterFrame(config));
    });
  }

  Future<void> _showAfterFrame(AppUpdateConfig config) async {
    final latestBuildNumber = config.latestBuildNumber;
    try {
      if (!mounted) return;
      final local = ref.read(appUpdateRecommendationDismissLocalProvider);
      if (await local.isDismissed(latestBuildNumber: latestBuildNumber)) {
        return;
      }
      if (!mounted) return;
      final sessionDismiss = ref.read(
        appUpdateSessionDismissedBuildsProvider.notifier,
      );
      if (sessionDismiss.contains(latestBuildNumber)) return;

      final action = await showRecommendedUpdateDialog(context, config: config);
      if (!mounted) return;
      switch (action) {
        case RecommendedUpdateDialogAction.update:
          sessionDismiss.dismiss(latestBuildNumber);
          await ref.read(appUpdateStoreLauncherProvider)(config.storeUrl);
        case RecommendedUpdateDialogAction.snoozeDay:
          await local.snoozeForOneDay(latestBuildNumber: latestBuildNumber);
          sessionDismiss.dismiss(latestBuildNumber);
        case RecommendedUpdateDialogAction.close:
        case null:
          sessionDismiss.dismiss(latestBuildNumber);
      }
    } catch (error, stackTrace) {
      // 권고 업데이트 UI는 fail-open: 로컬 저장/스토어 실행 실패가 앱 사용을
      // 막으면 안 된다.
      assert(() {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'app update',
            context: ErrorDescription('showing recommended update prompt'),
          ),
        );
        return true;
      }());
    } finally {
      _showing = false;
    }
  }
}
