import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Sub-screen의 자체 AppBar Container를 받아 SejongAppBar와 동일한 glass
/// morphism(`BackdropFilter blur sigma 18`)을 입힌다.
///
/// 사용 패턴:
/// ```
/// Align(
///   alignment: Alignment.topCenter,
///   child: GlassAppBarShell(
///     child: Container(
///       padding: EdgeInsets.only(top: top, ...),
///       decoration: BoxDecoration(
///         color: AppColors.surface.withValues(alpha: 0.82),
///         border: ...,
///       ),
///       child: Column(...),
///     ),
///   ),
/// )
/// ```
///
/// Container의 색은 0.6~0.85 alpha로 두는 게 mesh 배경이 살짝 비쳐 자연.
class GlassAppBarShell extends StatelessWidget {
  const GlassAppBarShell({super.key, required this.child, this.sigma = 18});

  final Widget child;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}
