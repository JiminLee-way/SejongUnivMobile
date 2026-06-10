import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_app_bar_shell.dart';

/// Sub-screen 공통 AppBar — `SejongAppBar`(메인 톱바)와 동일한 glass
/// morphism(BackdropFilter blur)을 항상 적용. 모든 sub-screen이 이 위젯
/// 하나를 사용하도록 통일하면, 추후 색감·blur·border 등 글로벌 톤 변경 시
/// **이 파일 한 곳만 수정**하면 일괄 적용된다.
///
/// 사용 예 (시간표):
/// ```dart
/// SejongSubAppBar(
///   title: '시간표',
///   actions: [
///     IconButton(icon: Icon(Symbols.search), onPressed: () {}),
///     IconButton(icon: Icon(Symbols.more_horiz), onPressed: () {}),
///   ],
/// )
/// ```
///
/// TabBar가 필요한 경우 (시설예약):
/// ```dart
/// SejongSubAppBar(
///   title: '시설 예약',
///   actions: [...],
///   bottom: TabBar(...),
///   bottomHeight: 44,
/// )
/// ```
class SejongSubAppBar extends StatelessWidget {
  const SejongSubAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.bottom,
    this.bottomHeight = 0,
    this.titleStyle,
    this.showBack = true,
    this.titleSize = 18,
  });

  final String title;

  /// null이면 `Navigator.of(context).maybePop()` 자동 호출.
  final VoidCallback? onBack;

  final List<Widget>? actions;

  /// AppBar 본체 아래에 붙는 영역 (TabBar 등).
  final Widget? bottom;

  /// [bottom] 영역의 높이 — 본체와 함께 정확한 콘텐츠 offset 계산용.
  final double bottomHeight;

  final TextStyle? titleStyle;
  final bool showBack;
  final double titleSize;

  /// 본체 row 높이.
  static const double appBarHeight = 56;

  /// `Padding(top: heightFor(ctx))` 같이 화면 콘텐츠 시작점 계산용.
  /// `bottomHeight`까지 포함한 전체 시각 높이.
  static double heightFor(BuildContext context, {double bottomHeight = 0}) {
    return MediaQuery.paddingOf(context).top + appBarHeight + bottomHeight;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return GlassAppBarShell(
      child: Container(
        padding: EdgeInsets.only(top: top),
        decoration: BoxDecoration(
          // SejongAppBar와 동일 gradient — blur 위에 mesh 톤이 살짝 비침.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surface.withValues(alpha: 0.82),
              AppColors.surface.withValues(alpha: 0.62),
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.45),
              width: 0.5,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ambientShadow,
              blurRadius: 22,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: appBarHeight,
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      icon: const Icon(
                        Symbols.arrow_back,
                        color: AppColors.onSurface,
                        size: 24,
                      ),
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                      splashRadius: 22,
                    )
                  else
                    const SizedBox(width: 12),
                  Text(
                    title,
                    style:
                        titleStyle ??
                        AppTypography.headlineMd.copyWith(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                  ),
                  const Spacer(),
                  if (actions != null) ...actions!,
                  const SizedBox(width: 4),
                ],
              ),
            ),
            if (bottom != null) SizedBox(height: bottomHeight, child: bottom!),
          ],
        ),
      ),
    );
  }
}
