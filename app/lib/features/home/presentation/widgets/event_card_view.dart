import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:sejong_smart_campus/features/home/domain/entities/event_card.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';

/// 캐러셀의 한 페이지를 그리는 단일 카드.
///
/// 외곽 `GlassCard`는 부모(`EventCarousel` → `HeroSlot`)가 그리므로 여기서는
/// 내부 레이아웃만 책임진다.
class EventCardView extends StatelessWidget {
  const EventCardView({
    super.key,
    required this.event,
    required this.textPanel,
  });

  final EventCard event;

  /// 텍스트 패널 영역에 인디케이터/일시정지를 같이 올릴 수 있도록
  /// 부모가 슬롯을 직접 채운다.
  final Widget textPanel;

  @override
  Widget build(BuildContext context) {
    // 이미지 전체를 채우고, 텍스트/인디케이터/일시정지를 그 위에 오버레이.
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: event.imageUrl,
          fit: BoxFit.cover,
          memCacheWidth: 1080,
          // 디스크 캐시(flutter_cache_manager) — 콜드스타트에도 즉시 렌더. 첫 다운
          // 로드 때만 잠깐 spinner.
          placeholder: (context, _) => Container(
            color: AppColors.surfaceContainer,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.primary,
              ),
            ),
          ),
          errorWidget: (_, _, _) => Container(
            color: AppColors.surfaceContainer,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.outline,
            ),
          ),
        ),
        // 하단 어두운 그라데이션 — 흰 텍스트 가독성.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x33000000),
                  Color(0x88000000),
                ],
                stops: [0.4, 0.7, 1.0],
              ),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: textPanel),
      ],
    );
  }
}

/// `EventCarousel`이 사용할 텍스트 패널 슬롯 — 타이틀/서브타이틀 +
/// (옵션) 좌측 인디케이터 점·우측 일시정지 버튼.
class EventTextPanel extends StatelessWidget {
  const EventTextPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.indicator,
    this.trailing,
    this.showText = true,
  });

  final String title;
  final String? subtitle;
  final Widget? indicator;
  final Widget? trailing;

  /// false면 제목/부제 오버레이를 숨긴다(이미지에 글자가 박혀 있는 경우).
  /// 인디케이터 점과 일시정지 버튼은 그대로 노출.
  final bool showText;

  @override
  Widget build(BuildContext context) {
    // 이미지 위에 직접 오버레이되는 텍스트 슬롯 — 배경 fill 없음, 흰 글씨.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showText) ...[
                  Text(
                    title,
                    style: AppTypography.headlineMd.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      height: 1.2,
                      shadows: const [
                        Shadow(color: Color(0x66000000), blurRadius: 8),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.labelMd.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                        shadows: const [
                          Shadow(color: Color(0x66000000), blurRadius: 6),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
                if (indicator != null) ...[
                  if (showText) const SizedBox(height: 8),
                  indicator!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
