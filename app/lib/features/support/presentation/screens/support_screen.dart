import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/support/presentation/providers/support_providers.dart';
import 'package:sejong_smart_campus/features/support/presentation/screens/qna_compose_dialog.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

enum SupportTab { faq, qna }

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key, this.initial = SupportTab.faq});
  final SupportTab initial;
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  late SupportTab _tab = widget.initial;
  String? _faqCategory;

  Future<void> _onRefresh() async {
    try {
      if (_tab == SupportTab.faq) {
        final category = _faqCategory;
        ref.invalidate(faqsProvider(category));
        ref.invalidate(faqCategoriesProvider);
        await Future.wait([
          Future<void>.delayed(const Duration(milliseconds: 300)),
          ref.read(faqCategoriesProvider.future).then((_) {}),
          ref.read(faqsProvider(category).future).then((_) {}),
        ]);
      } else {
        ref.invalidate(myQnaProvider);
        await Future.wait([
          Future<void>.delayed(const Duration(milliseconds: 300)),
          ref.read(myQnaProvider.future).then((_) {}),
        ]);
      }
    } catch (_) {
      // 실패는 현재 탭 provider error UI가 처리한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
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
                child: ListView(
                  padding: EdgeInsets.only(
                    top: mq.padding.top + 64 + 16,
                    left: AppSpacing.marginMobile,
                    right: AppSpacing.marginMobile,
                    bottom: 120 + mq.padding.bottom,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    _TabStrip(
                      selected: _tab,
                      onSelected: (t) => setState(() => _tab = t),
                    ),
                    const SizedBox(height: 12),
                    if (_tab == SupportTab.faq) ...[
                      _FaqCategoryChips(
                        selected: _faqCategory,
                        onSelected: (id) => setState(() => _faqCategory = id),
                      ),
                      const SizedBox(height: 8),
                      _FaqList(categoryId: _faqCategory),
                    ] else
                      const _QnaList(),
                  ],
                ),
              ),
            ),
            const Align(alignment: Alignment.topCenter, child: _AppBar()),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends ConsumerWidget {
  const _AppBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: top + 64,
      padding: EdgeInsets.only(top: top, left: 8, right: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Symbols.arrow_back, color: AppColors.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            '도움말',
            style: AppTypography.headlineMd.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '1:1 문의 작성',
            icon: const Icon(Symbols.edit_note, color: AppColors.primary),
            onPressed: () => showQnaComposeDialog(context),
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selected, required this.onSelected});
  final SupportTab selected;
  final ValueChanged<SupportTab> onSelected;
  @override
  Widget build(BuildContext context) {
    String labelOf(SupportTab t) => t == SupportTab.faq ? '자주 묻는 질문' : '1:1 문의';
    return Row(
      children: [
        for (final t in SupportTab.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => onSelected(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: t == selected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: t == selected
                          ? AppColors.primary
                          : AppColors.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    labelOf(t),
                    style: AppTypography.labelMd.copyWith(
                      color: t == selected
                          ? AppColors.onPrimary
                          : AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FaqCategoryChips extends ConsumerWidget {
  const _FaqCategoryChips({required this.selected, required this.onSelected});
  final String? selected;
  final ValueChanged<String?> onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(faqCategoriesProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (cats) {
        if (cats.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cats.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                return _Chip(
                  label: '전체',
                  active: selected == null,
                  onTap: () => onSelected(null),
                );
              }
              final c = cats[i - 1];
              return _Chip(
                label: c.categoryName,
                active: c.categoryId == selected,
                onTap: () => onSelected(c.categoryId),
              );
            },
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          // 가로 ListView가 칩 높이를 40으로 tight하게 강제 → alignment 없으면
          // 텍스트가 위로 붙어 세로 중앙이 안 맞는다. 명시적 center로 고정.
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : AppColors.outline.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: active ? AppColors.primary : AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqList extends ConsumerWidget {
  const _FaqList({required this.categoryId});
  final String? categoryId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(faqsProvider(categoryId));
    return async.when(
      loading: () => const _SupportListSkeleton(),
      error: (_, _) => const _EmptyBox(text: '자주 묻는 질문을 불러오지 못했어요'),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyBox(text: '등록된 FAQ가 없어요');
        }
        return Column(
          children: [
            for (final f in items) ...[
              GlassCard(
                borderRadius: AppRadius.lg,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'Q',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.question,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    if (f.answer != null && f.answer!.isNotEmpty)
                      Text(
                        f.answer!,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      )
                    else
                      Text(
                        '답변이 등록되지 않았어요',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _QnaList extends ConsumerWidget {
  const _QnaList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myQnaProvider);
    return async.when(
      loading: () => const _SupportListSkeleton(),
      error: (_, _) => const _EmptyBox(text: '문의 내역을 불러오지 못했어요'),
      data: (items) {
        if (items.isEmpty) {
          return Column(
            children: [
              const _EmptyBox(text: '문의 내역이 없어요'),
              const SizedBox(height: 12),
              Text(
                '앱 사용 중 불편한 점이나 버그가 있으면\n오른쪽 위 ✎ 버튼으로 문의를 남겨주세요.',
                textAlign: TextAlign.center,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            for (final q in items) ...[
              GlassCard(
                borderRadius: AppRadius.lg,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (q.status != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              q.status!,
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 10.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (q.createdAt != null)
                          Text(
                            '${q.createdAt!.year}.${q.createdAt!.month}.${q.createdAt!.day}',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q.title,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (q.answer != null && q.answer!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest.withValues(
                            alpha: 0.7,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          q.answer!,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _SupportListSkeleton extends StatelessWidget {
  const _SupportListSkeleton();

  @override
  Widget build(BuildContext context) => const Shimmer(
    child: Column(
      children: [
        _SupportSkeletonCard(),
        SizedBox(height: 8),
        _SupportSkeletonCard(),
        SizedBox(height: 8),
        _SupportSkeletonCard(),
        SizedBox(height: 8),
        _SupportSkeletonCard(),
      ],
    ),
  );
}

class _SupportSkeletonCard extends StatelessWidget {
  const _SupportSkeletonCard();

  @override
  Widget build(BuildContext context) => const GlassCard(
    borderRadius: AppRadius.lg,
    padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: double.infinity, height: 15, radius: AppRadius.sm),
        SizedBox(height: 10),
        ShimmerBox(width: 220, height: 12, radius: AppRadius.sm),
        SizedBox(height: 8),
        ShimmerBox(width: 140, height: 12, radius: AppRadius.sm),
      ],
    ),
  );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Text(
        text,
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
