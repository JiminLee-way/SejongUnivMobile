import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/auth/presentation/screens/login_screen.dart';
import 'package:sejong_smart_campus/features/home/presentation/providers/home_events_providers.dart';
import 'package:sejong_smart_campus/features/push/presentation/providers/push_providers.dart';
import 'package:sejong_smart_campus/features/shell/presentation/screens/app_shell.dart';
import 'package:sejong_smart_campus/shared/widgets/official_brand_logo.dart';

/// 앱 부트 직후 인증 상태에 따라 분기.
///
/// - 로딩 중: 흰 배경 + 중앙 세종대 로고만 (system splash와 1:1 매칭)
/// - 인증됨: [AppShell]
/// - 미인증/실패: [LoginScreen]
///
/// 로그인 → 홈 전환 시 "카메라 줌인" 형태의 시그니처 reveal:
///   • LoginScreen: scale 1.0 → 1.08 + fade-out (앞쪽 55% 동안)
///   • AppShell:    scale 0.94 → 1.0 + fade-in  (뒤쪽 70%, 30% 지연)
/// cross-dissolve 영역(33–55%)이 화면이 빨려들어가는 인상을 만든다.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (authState.value != null) {
      ref.watch(pushDeviceBootstrapProvider);
    }

    // 부트스트랩(로그인 화면 진입 전 로딩) 동안 홈 Hero 이벤트 카드를 미리 받아두고
    // 이미지까지 precache — 로그인 직후 홈 첫 진입 시 카드가 즉시 보이도록. listen이
    // provider를 초기화하므로 여기서 fetch가 시작된다. event_card_view가 쓰는
    // CachedNetworkImage와 같은 디스크 캐시를 데우려 CachedNetworkImageProvider로 precache.
    ref.listen(homeEventsProvider, (_, next) {
      next.whenData((events) {
        for (final e in events) {
          if (e.imageUrl.isEmpty) continue;
          precacheImage(CachedNetworkImageProvider(e.imageUrl), context);
        }
      });
    });

    final Widget child = authState.when(
      loading: () => const _Bootstrapping(key: ValueKey('boot')),
      error: (_, _) => const LoginScreen(key: ValueKey('login')),
      data: (user) => user == null
          ? const LoginScreen(key: ValueKey('login'))
          : const AppShell(key: ValueKey('shell')),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 750),
      reverseDuration: const Duration(milliseconds: 750),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      layoutBuilder: _stackLayout,
      transitionBuilder: _signatureReveal,
      child: child,
    );
  }
}

Widget _stackLayout(Widget? currentChild, List<Widget> previousChildren) {
  // 두 화면을 동시에 그려야 cross-fade 가능. RepaintBoundary로 paint 격리.
  return Stack(
    fit: StackFit.expand,
    alignment: Alignment.center,
    children: [
      for (final child in previousChildren) RepaintBoundary(child: child),
      if (currentChild != null) RepaintBoundary(child: currentChild),
    ],
  );
}

Widget _signatureReveal(Widget child, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final key = child.key;
      final isShell = key == const ValueKey('shell');
      final isLogin = key == const ValueKey('login');
      // forward: 들어오는 child. reverse/dismissed: 나가는 child.
      final isIncoming =
          animation.status == AnimationStatus.forward ||
          animation.status == AnimationStatus.completed;

      // ─ 들어오는 shell → 단순 fade-in.
      //   scale tween을 빼서 매 프레임 Transform.scale의 saveLayer 비용 제거.
      //   (시그니처 임팩트는 사라지는 login의 zoom-up이 책임진다.)
      if (isShell && isIncoming) {
        final t = animation.value; // 0 → 1
        final fadeT = ((t - 0.15) / 0.85).clamp(0.0, 1.0);
        return Opacity(opacity: fadeT, child: child);
      }

      // ─ 시그니처: 나가는 login → 줌업 + 빠른 fade (카메라가 안으로 빨려들어감)
      //   TickerMode(false)로 자식 트리의 ken-burns/wiggle 등 ticker 일괄 정지
      //   → 사라지는 화면에 더 이상 매 프레임 invalidate 발생 X.
      if (isLogin && !isIncoming) {
        final progress = 1.0 - animation.value; // 0 → 1 (퇴장 진행도)
        final scaleT = Curves.easeInCubic.transform(progress);
        final fadeT = (progress / 0.50).clamp(0.0, 1.0);
        return TickerMode(
          enabled: false,
          child: Transform.scale(
            scale: 1.0 + scaleT * 0.06,
            child: Opacity(opacity: 1.0 - fadeT, child: child),
          ),
        );
      }

      // 그 외 (boot→login, shell→login 로그아웃, login 첫 등장 등): 단순 fade
      return Opacity(opacity: animation.value, child: child);
    },
  );
}

class _Bootstrapping extends StatelessWidget {
  const _Bootstrapping({super.key});

  @override
  Widget build(BuildContext context) {
    // system splash (windowSplashScreenAnimatedIcon=@drawable/splash_icon,
    // background=#FFFFFF)와 정확히 같은 layout. icon 안전 영역이 60%라
    // 화면 위 실제 logo 크기 ≈ 288dp × 0.60 = 173dp. 같은 위치 같은 크기로
    // 보여서 transition 시 잔재나 점프 없음.
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: OfficialBrandLogo(width: 173, height: 173)),
    );
  }
}
