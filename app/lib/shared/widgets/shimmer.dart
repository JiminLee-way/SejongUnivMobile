import 'package:flutter/material.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';

/// 쿠팡 스타일 스켈레톤 로딩.
///
/// [child] 의 불투명한 픽셀 위로 회색→밝은회색 그라데이션이 1.6초 주기로
/// 좌→우 sweep. 자식이 여러 placeholder block 일 때 한 번의 [AnimationController]
/// 로 동시 페이팅되어 60Hz 부담이 없도록 [ShaderMask] 한 겹만 사용.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _base = Color(0xFFE6E8EB);
  static const _highlight = Color(0xFFF5F6F7);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // -1 → 2 로 sweep해 child 폭의 1.5배만큼 좌→우 통과.
        final dx = -1.0 + 3.0 * t;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(dx - 0.6, 0),
            end: Alignment(dx + 0.6, 0),
            colors: const [_base, _highlight, _base],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(rect),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 한 개의 회색 placeholder block. [Shimmer] 의 자손으로 쓰면 sweep 받음.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height = 12, this.radius = 6});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // ShaderMask 가 색을 덮어쓰기 때문에 base 색은 중요하지 않지만
        // 셰이더가 적용되기 전 한 프레임 동안 깜빡임을 줄이려고 동일 톤 사용.
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
