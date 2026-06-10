import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';
import 'package:sejong_smart_campus/features/notices/presentation/providers/notice_providers.dart';
import 'package:sejong_smart_campus/features/notices/presentation/screens/news_screen.dart';
import 'package:sejong_smart_campus/features/notices/presentation/screens/notice_detail_screen.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

/// 홈 화면 "세종 소식" 미리보기 — 최신 2건만 세로로.
///
/// 헤더의 "더보기 >" tap → [NewsScreen] (전체 list).
/// 카드 tap → [NoticeDetailScreen] (in-app 상세).
class SejongNewsPreview extends ConsumerWidget {
  const SejongNewsPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sejongNewsProvider);
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openList(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(
                      Symbols.newspaper,
                      size: 18,
                      fill: 1,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '세종 소식',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '더보기',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      Symbols.chevron_right,
                      size: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const _NewsSkeleton(),
            error: (_, _) => Text(
              '세종소식을 불러오지 못했어요',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  '새 소식이 없어요',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                );
              }
              final picks = items.take(2).toList();
              return Column(
                children: [
                  for (int i = 0; i < picks.length; i++) ...[
                    _NewsRow(
                      item: picks[i],
                      onTap: () => _openDetail(context, picks[i]),
                    ),
                    if (i != picks.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          height: 1,
                          color: AppColors.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _openList(BuildContext context) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(slideRoute(const NewsScreen(category: NewsCategory.news)));
  }

  void _openDetail(BuildContext context, SejongNoticeItem item) {
    Navigator.of(context, rootNavigator: true).push(
      slideRoute(
        NoticeDetailScreen(
          arg: NoticeDetailArg.news(category: NewsCategory.news, id: item.id),
        ),
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.item, required this.onTap});
  final SejongNoticeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = item.imageUrl;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 72,
                  height: 56,
                  child: (thumb == null || thumb.isEmpty)
                      ? Container(
                          color: AppColors.surfaceContainerHigh.withValues(
                            alpha: 0.65,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Symbols.newspaper,
                            size: 20,
                            color: AppColors.onSurfaceVariant,
                          ),
                        )
                      : Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.surfaceContainerHigh,
                            alignment: Alignment.center,
                            child: const Icon(
                              Symbols.image_not_supported,
                              size: 18,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.categoryName.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              item.categoryName,
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (item.writtenAt != null)
                          Text(
                            _fmtDate(item.writtenAt!),
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 10.5,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays < 1) return '오늘';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${d.year % 100}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
}

class _NewsSkeleton extends StatelessWidget {
  const _NewsSkeleton();
  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (int i = 0; i < 2; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  ShimmerBox(width: 72, height: 56, radius: AppRadius.sm),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ShimmerBox(height: 12),
                        SizedBox(height: 8),
                        ShimmerBox(width: 140, height: 12),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            ShimmerBox(
                              width: 44,
                              height: 14,
                              radius: AppRadius.full,
                            ),
                            SizedBox(width: 6),
                            ShimmerBox(width: 50, height: 10),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  height: 1,
                  color: AppColors.onSurface.withValues(alpha: 0.06),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
