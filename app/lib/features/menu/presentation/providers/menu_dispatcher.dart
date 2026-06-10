import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/shared/widgets/app_toast.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/menu/data/datasources/sejong_menu_remote.dart';
import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';
import 'package:sejong_smart_campus/features/shell/presentation/screens/app_shell.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/screens/ucheck_screen.dart';

final menuRemoteProvider = FutureProvider<SejongMenuRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongMenuRemote(client: client);
});

/// 토큰 (endpoint, staleTimeSec) → 메모리 캐시. 같은 외부 메뉴 재진입 시
/// 만료 전이면 캐시 재사용 — sjapp의 `staleTimeSec` 정책을 그대로 따른다.
class _TokenCache {
  final Map<String, _CachedToken> _byEndpoint = {};
  String? get(String endpoint) {
    final c = _byEndpoint[endpoint];
    if (c == null) return null;
    if (DateTime.now().isAfter(c.expiresAt)) {
      _byEndpoint.remove(endpoint);
      return null;
    }
    return c.token;
  }

  void put(String endpoint, String token, int staleTimeSec) {
    _byEndpoint[endpoint] = _CachedToken(
      token: token,
      expiresAt: DateTime.now().add(Duration(seconds: staleTimeSec)),
    );
  }
}

class _CachedToken {
  _CachedToken({required this.token, required this.expiresAt});
  final String token;
  final DateTime expiresAt;
}

final _tokenCacheProvider = Provider<_TokenCache>((ref) {
  // 계정 격리 — 사용자가 바뀌면 이전 사용자의 메뉴 SSO/handoff 토큰 캐시를 폐기.
  ref.watch(currentUserProvider.select((u) => u?.userId));
  return _TokenCache();
});

/// sjapp 공식 메뉴 dispatcher.
///
/// [item.callType] × [item.callParams]에 따라 URL 합성·토큰 부착 후 외부 브라우저
/// (또는 in-app fallback)로 위임. 알려진 분기:
///   - `EXTERNAL_BROWSER` / `INAPP_BROWSER` (+ queryParams 토큰) → url_launcher
///   - `APPLINK` → packageName 시도 → 실패 시 fallbackUrl (스토어)
///   - `WEBVIEW` → 현재는 in-app browser로 fallback (네이티브 화면 도입 시 분기)
///   - `NONE` → 그룹 헤더, 호출 안 됨
class MenuDispatcher {
  MenuDispatcher(this.ref);
  final Ref ref;

  Future<DispatchResult> dispatch(SejongMenuItem item) async {
    if (!item.active || !item.visible) {
      return const DispatchResult.skipped('비활성 메뉴');
    }
    switch (item.callType) {
      case 'NONE':
        return const DispatchResult.skipped('그룹 헤더');
      case 'WEBVIEW':
        // 우리 앱 안에서 처리해야 할 sjapp 내부 라우트. 네이티브 매핑 전까지는
        // webUrl이 절대 URL이면 외부 in-app browser로, 아니면 안내 메시지.
        if (item.webUrl.startsWith('http')) {
          return _launchUrl(item.webUrl, externalApplication: false);
        }
        return DispatchResult.skipped('아직 준비 중인 화면이에요 (${item.itemName})');
      case 'INAPP_BROWSER':
        final url = await _composeUrlWithTokens(item);
        if (url == null) return const DispatchResult.failed('URL 합성 실패');
        return _launchUrl(url, externalApplication: false);
      case 'EXTERNAL_BROWSER':
        final url = await _composeUrlWithTokens(item);
        if (url == null) return const DispatchResult.failed('URL 합성 실패');
        return _launchUrl(url, externalApplication: true);
      case 'APPLINK':
        return _launchAppLink(item);
      default:
        return DispatchResult.skipped('지원하지 않는 메뉴 유형 (${item.callType})');
    }
  }

  Future<String?> _composeUrlWithTokens(SejongMenuItem item) async {
    var url = item.url.isNotEmpty ? item.url : item.webUrl;
    if (url.isEmpty) return null;
    final params = item.parsedCallParams();
    final queryParams = (params?['queryParams'] as List?)?.cast<dynamic>();
    if (queryParams == null || queryParams.isEmpty) return url;

    final cache = ref.read(_tokenCacheProvider);
    final remote = await ref.read(menuRemoteProvider.future);

    final pairs = <MapEntry<String, String>>[];
    for (final entry in queryParams) {
      if (entry is! Map) continue;
      final key = entry['key']?.toString();
      final resolve = entry['resolve']?.toString();
      final endpoint = entry['endpoint']?.toString();
      final staleTimeSec = (entry['staleTimeSec'] as num?)?.toInt() ?? 60;
      if (key == null || resolve != 'api' || endpoint == null) continue;

      var token = cache.get(endpoint);
      if (token == null) {
        try {
          token = await remote.resolveTokenFromEndpoint(endpoint);
        } catch (_) {
          token = null;
        }
        if (token != null) cache.put(endpoint, token, staleTimeSec);
      }
      if (token != null) {
        pairs.add(MapEntry(key, token));
      }
    }
    if (pairs.isEmpty) return url;
    final uri = Uri.parse(url);
    final merged = {
      ...uri.queryParameters,
      for (final p in pairs) p.key: p.value,
    };
    return uri.replace(queryParameters: merged).toString();
  }

  Future<DispatchResult> _launchUrl(
    String url, {
    required bool externalApplication,
  }) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(
        uri,
        mode: externalApplication
            ? LaunchMode.externalApplication
            : LaunchMode.inAppBrowserView,
      );
      return ok
          ? DispatchResult.opened(url)
          : DispatchResult.failed('브라우저를 열지 못했어요');
    } catch (e) {
      return DispatchResult.failed('URL이 올바르지 않아요: $url');
    }
  }

  Future<DispatchResult> _launchAppLink(SejongMenuItem item) async {
    final scheme = item.parsedAppScheme();
    final packageName = (scheme?['packageName'] ?? '').toString();
    // UCheck Plus는 우리 앱에 내장 — 외부 앱 대신 내장 U-Check 화면으로 리다이렉트.
    // 예전엔 nav 탭(index 1)이었으나 지금은 sub-screen push이고 index 1은 학생증이
    // 됐다. 그래서 switchToTab(1)은 학생증을 여는 버그였음. 홈 바로가기
    // (client.uCheckTab)와 동일하게 UCheckScreen을 push하도록 위임.
    if (packageName == 'com.libeka.attendance.ucheckplusstud') {
      return const DispatchResult._(
        kind: DispatchKind.pushUCheck,
        message: 'U-Check로 이동했어요',
      );
    }
    final fallback = (scheme?['fallbackUrl'] ?? item.url).toString();
    // 그 외 packageName으로 직접 deep link 시도는 추후 platform channel로 구현.
    // 지금은 fallbackUrl(스토어)로 바로 위임.
    if (fallback.startsWith('http')) {
      return _launchUrl(fallback, externalApplication: true);
    }
    return DispatchResult.failed('앱 fallback URL이 비어있어요');
  }
}

final menuDispatcherProvider = Provider<MenuDispatcher>(
  (ref) => MenuDispatcher(ref),
);

/// dispatch 결과 — UI는 toast로 사용자에게 안내.
///
/// `switchToTab`은 외부 앱 대신 우리 앱 안의 특정 탭으로 이동을 의미한다 —
/// UCheck Plus APPLINK 같은 케이스. caller가 `AppShell.of(context).switchTab`
/// 을 호출해야 한다 ([showDispatchResult]가 자동 처리).
class DispatchResult {
  const DispatchResult._({
    required this.kind,
    required this.message,
    this.url,
    this.switchToTabIndex,
  });
  const DispatchResult.opened(String url)
    : this._(kind: DispatchKind.opened, message: '브라우저로 이동했어요', url: url);
  const DispatchResult.skipped(String message)
    : this._(kind: DispatchKind.skipped, message: message);
  const DispatchResult.failed(String message)
    : this._(kind: DispatchKind.failed, message: message);

  final DispatchKind kind;
  final String message;
  final String? url;
  final int? switchToTabIndex;
}

enum DispatchKind { opened, skipped, failed, switchToTab, pushUCheck }

/// UI 헬퍼 — dispatch 결과를 SnackBar로 노출 + 필요시 탭 전환.
void showDispatchResult(BuildContext context, DispatchResult r) {
  if (r.kind == DispatchKind.pushUCheck) {
    // 홈 바로가기와 동일 패턴 — root navigator에 UCheckScreen push.
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(slideRoute(const UCheckScreen()));
    return;
  }
  if (r.kind == DispatchKind.switchToTab) {
    final idx = r.switchToTabIndex;
    if (idx != null) {
      try {
        AppShell.of(context).switchTab(idx);
      } catch (_) {
        // AppShell ancestor 아닌 컨텍스트 (모달 등) — 무시.
      }
    }
    return;
  }
  if (r.kind == DispatchKind.opened) return; // 외부로 이동했으므로 메시지 불필요
  // 전체서비스 드로어에서 호출되는 경로라 SnackBar는 드로어/바텀 네비 뒤로
  // 가려진다. 루트 Overlay 토스트로 그 위에 띄운다. [showAppToast] 참고.
  showAppToast(context, r.message);
}
