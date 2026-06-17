import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/features/app_update/domain/entities/app_update_config.dart';
import 'package:sejong_smart_campus/features/app_update/presentation/providers/app_update_providers.dart';
import 'package:sejong_smart_campus/features/app_update/presentation/screens/force_update_screen.dart';

/// 앱 전체를 감싸는 업데이트 게이트 (`main.dart`의 `home`에서 AuthGate를 감쌈).
///
/// 부트 직후 [appUpdateStatusProvider]를 백그라운드로 평가하고:
///  - `forced`      → 루트 네비게이터에 [ForceUpdateScreen]을 `pushAndRemoveUntil`
///                    (스택 전체 제거 → 닫기 불가). 앱은 멈추지 않고 평소처럼 떴다가
///                    판정이 도착하면 덮인다. fail-open: 오류/오프라인이면 그냥 통과.
///  - `recommended` → 홈 화면의 권고 업데이트 프롬프트가 처리.
///  - `none`        → 아무것도 안 함.
///
/// 인증 상태와 무관하게(로그인 화면 위에서도) 동작 — 강제 업데이트는 미로그인
/// 사용자도 막아야 하기 때문.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  bool _handledForced = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(appUpdateStatusProvider, (_, next) {
      next.whenData(_react);
    });
    return widget.child;
  }

  void _react(AppUpdateStatus status) {
    final config = status.config;
    switch (status.verdict) {
      case AppUpdateVerdict.forced:
        if (_handledForced || config == null) return;
        _handledForced = true;
        rootNavigatorKey.currentState?.pushAndRemoveUntil(
          instantRoute(
            ForceUpdateScreen(
              storeUrl: config.storeUrl,
              title: config.forceTitle,
              message: config.forceMessage,
            ),
          ),
          (_) => false,
        );
      case AppUpdateVerdict.recommended:
        break;
      case AppUpdateVerdict.none:
        break;
    }
  }
}
