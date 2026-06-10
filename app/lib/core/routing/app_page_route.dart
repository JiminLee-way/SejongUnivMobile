import 'package:flutter/material.dart';

/// 루트 네비게이터(=MaterialApp Navigator) 전역 키.
///
/// AuthGate의 `AnimatedSwitcher`가 로그인↔셸을 swap할 때 AppShell의 element는
/// 일시적으로 비활성화된다. 콜드부트 850ms 지연 콜백/알림 콜백처럼 **async 갭을
/// 건너온 코드가 AppShell의 context로 `showDialog`/`Navigator.of`를 호출하면**
/// 그 사이 비활성화된 context를 ancestor lookup해 "This BuildContext is no longer
/// valid" 로 크래시했다(실측 리포트). 루트 네비게이터는 AuthGate **위**에 있어
/// swap에도 안정적이므로, 그런 경로는 이 키의 context/state를 쓴다.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 앱 전체 화면 전환 표준 — 오른쪽에서 밀려들어오는 수평 슬라이드.
///
/// 사용:
/// ```dart
/// Navigator.of(context).push(slideRoute(const FooScreen()));
/// ```
///
/// 뒤로가기(pop)는 자동으로 반대 방향(오른쪽으로 빠져나감)으로 처리된다.
/// 자세한 컨벤션은 feature navigation notes를 참조.
/// 탭 전환용 — 애니메이션 없이 즉시 교체.
Route<T> instantRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
  );
}

Route<T> slideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 260),
  );
}
