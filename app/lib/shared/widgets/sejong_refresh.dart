import 'package:flutter/material.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';

/// Brand-themed pull-to-refresh wrapper.
///
/// 모든 스크롤 가능한 화면은 이 위젯으로 감싼다. 시각 동작은 표준 Material
/// 패턴 — 위에서 아래로 끌면 회전하는 인디케이터가 나오고, 놓으면 감겨
/// 올라가며 `onRefresh` future가 끝날 때까지 회전한다.
///
/// 사용 예:
/// ```dart
/// SejongRefresh(
///   onRefresh: () => ref.refresh(timetableProvider.future),
///   topInset: kAppBarTotalHeight(context),
///   child: ListView(...),
/// )
/// ```
class SejongRefresh extends StatelessWidget {
  const SejongRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.topInset = 0,
  });

  final Widget child;
  final Future<void> Function() onRefresh;

  /// 화면 상단에 고정 앱바 등이 떠 있을 때, 인디케이터가 그 아래에서
  /// 나타나도록 보정하는 픽셀 값.
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceContainerLowest,
      strokeWidth: 2.4,
      displacement: 32,
      edgeOffset: topInset,
      child: child,
    );
  }
}

/// 홈/일반 화면에서 SejongAppBar 아래에 인디케이터가 떨어지도록 하는 보정값.
double kSejongAppBarInset(BuildContext context) {
  return MediaQuery.paddingOf(context).top + 64;
}
