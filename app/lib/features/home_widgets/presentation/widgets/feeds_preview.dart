import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sejong_smart_campus/core/network/service_urls.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/home_widgets/domain/entities/home_widget_models.dart';
import 'package:sejong_smart_campus/features/home_widgets/presentation/providers/home_widgets_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';

/// 블로그 + 유튜브 통합 피드 가로 스크롤 미리보기 (홈용).
class FeedsPreview extends ConsumerWidget {
  const FeedsPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feedsLatestProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (feeds) {
        if (feeds.isEmpty) return const SizedBox.shrink();
        return GlassCard(
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Symbols.rss_feed,
                    size: 18,
                    color: AppColors.primary,
                    fill: 1,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '세종 피드',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 156,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: feeds.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _FeedCard(item: feeds[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});
  final FeedItem item;

  Future<void> _open() async {
    if (item.link.isEmpty) return;
    try {
      await launchUrl(
        Uri.parse(item.link),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  String _resolveThumb() {
    final t = item.thumbnailUrl;
    if (t == null || t.isEmpty) return '';
    // sjapp의 `/api/publicapi/proxy/image?url=...` 패턴은 그대로 base prefix.
    if (t.startsWith('/')) return ServiceUrls.join(ServiceUrls.sejongApi, t);
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final thumb = _resolveThumb();
    return SizedBox(
      width: 160,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: thumb.isEmpty
                      ? Container(
                          color: AppColors.surfaceContainerHigh,
                          alignment: Alignment.center,
                          child: Icon(
                            item.source == FeedSource.youtube
                                ? Symbols.play_circle
                                : Symbols.article,
                            size: 28,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        )
                      : Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.surfaceContainerHigh,
                            alignment: Alignment.center,
                            child: Icon(
                              Symbols.image_not_supported,
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.source == FeedSource.youtube
                                ? Symbols.play_circle
                                : Symbols.article,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.sourceName,
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 10.5,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
