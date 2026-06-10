import 'package:flutter/material.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';

/// Fake glass card — BackdropFilter 없이 그라데이션 + white hairline + 부드러운
/// 그림자로만 글래스 톤. 진짜 blur는 비용이 매우 커서(saveLayer per frame)
/// 60Hz 유지를 위해 제거. 베이크된 mesh 배경이 부드러워서 시각 차이는 작음.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.gutterMobile),
    this.borderRadius = AppRadius.xl,
    this.fillOpacity = 0.7,
    @Deprecated('No-op; kept for API compatibility') this.blurSigma = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// 상단 모서리 기준 fill 알파. 하단은 자동으로 ×0.45 — 광원 효과.
  final double fillOpacity;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final hiAlpha = (fillOpacity + 0.1).clamp(0.0, 1.0);
    final loAlpha = (fillOpacity * 0.45).clamp(0.0, 1.0);
    // RepaintBoundary로 raster cache 격리 — scroll 시 카드 위치만 변하고
    // 콘텐츠가 그대로면 paint를 재실행하지 않고 cached layer를 재사용.
    // ServicesScreen처럼 10+ 카드가 동시 mount된 화면의 scroll FPS 결정적.
    //
    // boxShadow blurRadius 24 → 12: Skia의 Gaussian blur mask는 blurRadius
    // 제곱에 비례하는 비용. 시각적으로는 그림자가 살짝 줄어드는 정도라 화면
    // 톤은 거의 그대로지만 paint 비용이 1/4로 떨어진다.
    //
    // Clip.antiAlias → Clip.hardEdge: border가 이미 동일 radius를 그려
    // antialiased clipping의 saveLayer 비용은 거의 무의미한데 매 paint마다
    // GPU 부담.
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: hiAlpha),
              Colors.white.withValues(alpha: loAlpha),
            ],
          ),
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ambientShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// 작은 중첩 글래스 surface (SeatCard 안의 이용중 패널 등).
class InnerGlassPanel extends StatelessWidget {
  const InnerGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = AppRadius.md,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0.22),
          ],
        ),
        borderRadius: radius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      padding: padding,
      child: child,
    );
  }
}
