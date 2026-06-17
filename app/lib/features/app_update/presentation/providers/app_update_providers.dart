import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sejong_smart_campus/features/app_update/data/datasources/app_update_recommendation_dismiss_local.dart';
import 'package:sejong_smart_campus/features/app_update/data/datasources/supabase_app_config_remote.dart';
import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_config.dart';

final _appConfigRemoteProvider = Provider<SupabaseAppConfigRemote>(
  (ref) => SupabaseAppConfigRemote(Supabase.instance.client),
);

final appUpdateRecommendationDismissLocalProvider =
    Provider<AppUpdateRecommendationDismissLocal>(
      (ref) => AppUpdateRecommendationDismissLocal(),
    );

typedef AppUpdateStoreLauncher = Future<bool> Function(String storeUrl);

final appUpdateStoreLauncherProvider = Provider<AppUpdateStoreLauncher>((ref) {
  return (storeUrl) async {
    if (storeUrl.trim().isEmpty) return false;
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  };
});

class AppUpdateSessionDismissedBuilds extends Notifier<Set<int>> {
  @override
  Set<int> build() => <int>{};

  bool contains(int latestBuildNumber) => state.contains(latestBuildNumber);

  void dismiss(int latestBuildNumber) {
    state = {...state, latestBuildNumber};
  }
}

final appUpdateSessionDismissedBuildsProvider =
    NotifierProvider<AppUpdateSessionDismissedBuilds, Set<int>>(
      AppUpdateSessionDismissedBuilds.new,
    );

/// 업데이트 판정 결과 — 판정 + (권장/강제 시) 문구·스토어URL 동봉.
class AppUpdateStatus {
  const AppUpdateStatus(this.verdict, this.config);
  final AppUpdateVerdict verdict;
  final AppUpdateConfig? config;

  static const none = AppUpdateStatus(AppUpdateVerdict.none, null);
}

/// 부트 시 1회 평가.
///
/// **fail-open** — 네트워크/서버 오류·설정 부재·파싱 실패면 항상
/// [AppUpdateStatus.none]을 돌려 절대 앱을 막지 않는다. config 조회 실패로
/// 사용자를 브릭시키는 것이 가장 큰 위험이므로 모든 예외를 흡수한다.
final appUpdateStatusProvider = FutureProvider<AppUpdateStatus>((ref) async {
  try {
    final config = await ref.watch(_appConfigRemoteProvider).fetch();
    if (config == null) return AppUpdateStatus.none;
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    return AppUpdateStatus(config.verdictFor(build), config);
  } catch (_) {
    return AppUpdateStatus.none;
  }
});
