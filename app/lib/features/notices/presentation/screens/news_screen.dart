import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';
import 'package:sejong_smart_campus/features/notices/presentation/providers/notice_providers.dart';
import 'package:sejong_smart_campus/features/notices/presentation/screens/notice_detail_screen.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

/// 세종뉴스 계열 5 type (news/media/press/sejong-webzine/engineering-webzine)
/// 통합 list 화면.
///
/// [category]로 어느 type을 보여줄지 지정. 기본 [NewsCategory.news] —
/// 홈에서 그냥 NewsScreen()으로 push해도 동작.
class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key, this.category = NewsCategory.news});
  final NewsCategory category;

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  String? _filterCategoryName;

  Future<void> _onRefresh() async {
    ref.invalidate(newsListByCategoryProvider(widget.category));
    if (widget.category == NewsCategory.news) {
      // 홈 위젯이 sejongNewsProvider를 watch — 같이 새로고침.
      ref.invalidate(sejongNewsProvider);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  void _open(SejongNoticeItem item) {
    Navigator.of(context).push(
      slideRoute(
        NoticeDetailScreen(
          arg: NoticeDetailArg.news(category: widget.category, id: item.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final async = ref.watch(newsListByCategoryProvider(widget.category));
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: SejongRefresh(
                onRefresh: _onRefresh,
                topInset: mq.padding.top + 64,
                child: async.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  error: (e, _) => _ErrorView(error: e),
                  data: (all) {
                    // categoryName으로 sub-filter (news 안에서만 의미있음).
                    final showSubFilter =
                        widget.category == NewsCategory.news && all.isNotEmpty;
                    final categoryNames = showSubFilter
                        ? (<String>{
                            for (final it in all)
                              if (it.categoryName.isNotEmpty) it.categoryName,
                          }.toList()..sort())
                        : const <String>[];
                    final visible = _filterCategoryName == null
                        ? all
                        : all
                              .where(
                                (e) => e.categoryName == _filterCategoryName,
                              )
                              .toList();
                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(height: mq.padding.top + 64 + 8),
                        ),
                        if (showSubFilter)
                          SliverToBoxAdapter(
                            child: _CategoryChips(
                              categories: categoryNames,
                              selected: _filterCategoryName,
                              onSelected: (c) =>
                                  setState(() => _filterCategoryName = c),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        if (visible.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 64),
                              child: Center(child: Text('표시할 소식이 없어요')),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.marginMobile,
                              4,
                              AppSpacing.marginMobile,
                              0,
                            ),
                            sliver: SliverList.separated(
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) => _NewsCard(
                                item: visible[i],
                                onTap: () => _open(visible[i]),
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: 120 + mq.padding.bottom),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SejongSubAppBar(title: widget.category.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  @override
  Widget build(BuildContext context) {
    final all = ['전체', ...categories];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
        ),
        itemCount: all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = all[i];
          final active =
              (i == 0 && selected == null) || (i > 0 && label == selected);
          return Center(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => onSelected(i == 0 ? null : label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: active
                          ? AppColors.primary
                          : AppColors.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMd.copyWith(
                      color: active ? AppColors.onPrimary : AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.onTap});
  final SejongNoticeItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: GlassCard(
          borderRadius: AppRadius.lg,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.surfaceContainerHigh,
                        alignment: Alignment.center,
                        child: const Icon(
                          Symbols.image_not_supported,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.categoryName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
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
                                fontSize: 10.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (item.isNew) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              'NEW',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 9.5,
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        height: 1.35,
                      ),
                    ),
                    if (item.summary != null && item.summary!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (item.writtenAt != null)
                          Text(
                            _fmtDate(item.writtenAt!),
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        const Spacer(),
                        if (item.viewCount > 0) ...[
                          Icon(
                            Symbols.visibility,
                            size: 12,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${item.viewCount}',
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Symbols.error,
            fill: 1,
            size: 36,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '소식을 불러오지 못했어요',
            style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '$error',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
