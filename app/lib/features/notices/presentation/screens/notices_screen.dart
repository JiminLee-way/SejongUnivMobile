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

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key, this.initial = NoticeCategory.general});
  final NoticeCategory initial;

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  late NoticeCategory _category = widget.initial;

  Future<void> _onRefresh() async {
    ref.invalidate(noticesByCategoryProvider(_category));
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  void _openNotice(SejongNoticeItem item) {
    final cat = NoticeCategory.fromType(item.categoryType) ?? _category;
    Navigator.of(context).push(
      slideRoute(
        NoticeDetailScreen(
          arg: NoticeDetailArg.notice(category: cat, id: item.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final async = ref.watch(noticesByCategoryProvider(_category));
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
                topInset: mq.padding.top + 64 + 48,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(height: mq.padding.top + 64 + 8),
                    ),
                    SliverToBoxAdapter(
                      child: _CategoryStrip(
                        selected: _category,
                        onSelected: (c) => setState(() => _category = c),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    async.when(
                      loading: () =>
                          const SliverToBoxAdapter(child: _CenterSpinner()),
                      error: (_, _) => SliverToBoxAdapter(
                        child: _ErrorBox(onRetry: _onRefresh),
                      ),
                      data: (items) {
                        if (items.isEmpty) {
                          return const SliverToBoxAdapter(child: _EmptyBox());
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.marginMobile,
                            8,
                            AppSpacing.marginMobile,
                            0,
                          ),
                          sliver: SliverList.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) => _NoticeRow(
                              item: items[i],
                              onTap: () => _openNotice(items[i]),
                            ),
                          ),
                        );
                      },
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: 120 + mq.padding.bottom),
                    ),
                  ],
                ),
              ),
            ),
            const Align(alignment: Alignment.topCenter, child: _NoticeAppBar()),
          ],
        ),
      ),
    );
  }
}

class _NoticeAppBar extends StatelessWidget {
  const _NoticeAppBar();
  @override
  Widget build(BuildContext context) => const SejongSubAppBar(title: '대학 공지');
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selected, required this.onSelected});
  final NoticeCategory selected;
  final ValueChanged<NoticeCategory> onSelected;
  @override
  Widget build(BuildContext context) {
    // 칩 — Pretendard ascent가 약간 위로 쏠려있어 vertical padding 대신
    // 고정 height + alignment.center + Text height 1.0으로 정확히 중앙 정렬.
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
        ),
        itemCount: NoticeCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = NoticeCategory.values[i];
          final active = c == selected;
          return Center(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => onSelected(c),
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
                    c.label,
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

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.item, required this.onTap});
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                        borderRadius: BorderRadius.circular(AppRadius.full),
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
                        borderRadius: BorderRadius.circular(AppRadius.full),
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
                  if (item.hasAttachment) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Symbols.attach_file,
                      size: 14,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (item.writerName.isNotEmpty) ...[
                    Icon(
                      Symbols.account_circle,
                      size: 13,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.writerName,
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (item.writtenAt != null)
                    Text(
                      _formatDate(item.writtenAt!),
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  if (item.viewCount > 0) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Symbols.visibility,
                      size: 12,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
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
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays < 1) return '오늘';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${d.year % 100}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
}

class _CenterSpinner extends StatelessWidget {
  const _CenterSpinner();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 64),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Text(
          '공지가 없어요',
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Row(
        children: [
          const Icon(Symbols.error, fill: 1, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '공지를 불러오지 못했어요',
              style: AppTypography.labelMd.copyWith(color: AppColors.onSurface),
            ),
          ),
          TextButton(onPressed: () => onRetry(), child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
