import 'package:flutter/widgets.dart';

/// AppShell이 측정한 실 바텀 nav 시각 높이를 sub-tree에 노출.
///
/// LibseatScreen 같은 sub-screen이 selection bar / FAB 등을 nav 위에 정확히
/// 띄울 때 사용. 상수 `approxHeight`로 추정하면 device safe area + 동적 layout
/// 차이 때문에 빈 공간 또는 overlap이 발생 — 이 widget을 통해 실 높이를
/// reactive하게 받는다.
class BottomNavInsets extends InheritedWidget {
  const BottomNavInsets({
    super.key,
    required this.height,
    required super.child,
  });

  /// AppShell이 GlobalKey로 측정한 SejongBottomNav의 정확한 시각 높이(px).
  /// safe-area를 모두 포함한 값 — sub-screen은 이 값을 그대로 마진/패딩에
  /// 더하면 nav 위 0px에 정확히 정렬된다.
  final double height;

  /// 가장 가까운 [BottomNavInsets]의 높이. AppShell 외부에서 호출되면 0.
  /// (안전한 fallback — 화면이 깨지지 않게 함.)
  static double of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<BottomNavInsets>();
    return w?.height ?? 0;
  }

  /// listen 없이 한 번만 읽기 — 변경 시 rebuild 불필요한 곳에서 사용.
  static double readNotListen(BuildContext context) {
    final w = context.getInheritedWidgetOfExactType<BottomNavInsets>();
    return w?.height ?? 0;
  }

  @override
  bool updateShouldNotify(BottomNavInsets old) => old.height != height;
}
