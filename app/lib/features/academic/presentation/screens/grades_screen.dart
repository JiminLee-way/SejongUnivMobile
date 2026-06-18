import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/academic_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    try {
      ref.invalidate(gradesProvider);
      final grades = await ref.read(gradesProvider.future);
      final selected = ref.read(selectedGradeSemesterProvider);
      final defaultKey = grades.selectedSemester == null
          ? null
          : (
              year: grades.selectedSemester!.year,
              smtCd: grades.selectedSemester!.smtCd,
            );
      final activeKey = selected ?? defaultKey;
      if (activeKey == null) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return;
      }
      ref.invalidate(gradeSemesterProvider(activeKey));
      await Future.wait([
        Future<void>.delayed(const Duration(milliseconds: 300)),
        ref.read(gradeSemesterProvider(activeKey).future).then((_) {}),
      ]);
    } catch (_) {
      // 실패는 성적 목록/detail provider error UI가 렌더한다.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final async = ref.watch(gradesProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: SejongRefresh(
                onRefresh: () => _onRefresh(ref),
                topInset: mq.padding.top + 64,
                child: async.when(
                  loading: () => _GradesPageSkeleton(
                    topPadding: mq.padding.top + 64 + 16,
                    bottomPadding: 120 + mq.padding.bottom,
                  ),
                  error: (_, _) => Center(
                    child: Text(
                      '성적을 불러오지 못했어요',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  data: (g) {
                    final selKey = ref.watch(selectedGradeSemesterProvider);
                    final defaultKey = g.selectedSemester == null
                        ? null
                        : (
                            year: g.selectedSemester!.year,
                            smtCd: g.selectedSemester!.smtCd,
                          );
                    final activeKey = selKey ?? defaultKey;
                    return ListView(
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
                        _OverallCard(s: g.overallSummary),
                        const SizedBox(height: 16),
                        _SectionTitle(
                          icon: Symbols.filter_alt,
                          title: '학기 선택',
                          trailing: selKey != null
                              ? _ResetChip(
                                  onTap: () => ref
                                      .read(
                                        selectedGradeSemesterProvider.notifier,
                                      )
                                      .reset(),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        _SemestersStrip(
                          items: g.semesters,
                          active: activeKey,
                          onSelected: (s) => ref
                              .read(selectedGradeSemesterProvider.notifier)
                              .select(s.year, s.smtCd),
                        ),
                        const SizedBox(height: 16),
                        if (activeKey != null)
                          _SemesterDetail(
                            activeKey: activeKey,
                            defaultDetail:
                                defaultKey != null && activeKey == defaultKey
                                ? g.selectedSemester
                                : null,
                          )
                        else
                          const _EmptyDetail(),
                      ],
                    );
                  },
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

class _AppBar extends StatelessWidget {
  const _AppBar();
  @override
  Widget build(BuildContext context) {
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
            '성적',
            style: AppTypography.headlineMd.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Overall summary
// ═══════════════════════════════════════════════════════════════════════

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.s});
  final GradeOverallSummary s;
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.trending_up,
                size: 22,
                fill: 1,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '전체 학기 요약',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(
                label: '평균 평점',
                value: s.avgMrks.toStringAsFixed(2),
                big: true,
              ),
              const SizedBox(width: 8),
              _Stat(label: '환산 점수', value: '${s.sco}', big: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: '신청 학점', value: '${s.reqCdt}'),
              const SizedBox(width: 8),
              _Stat(label: '취득 학점', value: '${s.appCdt}'),
              const SizedBox(width: 8),
              _Stat(label: '졸업 인정', value: '${s.gruCdt}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.big = false});
  final String label;
  final String value;
  final bool big;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: big ? 14 : 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.labelMd.copyWith(
                fontSize: big ? 22 : 16,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Section title / reset chip
// ═══════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary, fill: 1),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTypography.labelMd.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _ResetChip extends StatelessWidget {
  const _ResetChip({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.refresh, size: 13, color: AppColors.primary),
              const SizedBox(width: 3),
              Text(
                '기본 학기',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Semester selector strip (interactive)
// ═══════════════════════════════════════════════════════════════════════

class _SemestersStrip extends StatelessWidget {
  const _SemestersStrip({
    required this.items,
    required this.active,
    required this.onSelected,
  });
  final List<GradeSemesterSummary> items;
  final ({String year, String smtCd})? active;
  final ValueChanged<GradeSemesterSummary> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.2)),
        ),
        child: Text(
          '학기 기록이 없어요',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = items[i];
          final isActive =
              active != null &&
              s.year == active!.year &&
              s.smtCd == active!.smtCd;
          return _SemesterCard(
            s: s,
            active: isActive,
            onTap: () => onSelected(s),
          );
        },
      ),
    );
  }
}

class _SemesterCard extends StatelessWidget {
  const _SemesterCard({
    required this.s,
    required this.active,
    required this.onTap,
  });
  final GradeSemesterSummary s;
  final bool active;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 152,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : AppColors.outline.withValues(alpha: 0.28),
              width: active ? 1.4 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      s.yearSmtNm,
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: active ? AppColors.onPrimary : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    s.avgMrks.toStringAsFixed(2),
                    style: AppTypography.labelMd.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ 4.5',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Symbols.menu_book,
                    size: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${s.appCdt}/${s.reqCdt}학점',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '·',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${s.sco}점',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Semester detail (selected semester)
// ═══════════════════════════════════════════════════════════════════════

class _SemesterDetail extends ConsumerWidget {
  const _SemesterDetail({required this.activeKey, required this.defaultDetail});
  final ({String year, String smtCd}) activeKey;

  /// `/all` 응답에 포함된 default selectedSemester. activeKey 와 동일할 때
  /// 별도 fetch 없이 바로 그릴 수 있음 — 첫 로딩 깜빡임을 줄이려는 최적화.
  final GradeSelectedSemester? defaultDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (defaultDetail != null) {
      return _SelectedSemesterCard(sel: defaultDetail!);
    }
    final async = ref.watch(gradeSemesterProvider(activeKey));
    return async.when(
      loading: () => const _DetailSkeleton(),
      error: (_, _) => GlassCard(
        borderRadius: AppRadius.xl,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: [
            const Icon(
              Symbols.error,
              size: 18,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${activeKey.year}년 학기 성적을 불러오지 못했어요',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      data: (sel) => _SelectedSemesterCard(sel: sel),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) => const _GradeDetailSkeletonCard();
}

class _GradesPageSkeleton extends StatelessWidget {
  const _GradesPageSkeleton({
    required this.topPadding,
    required this.bottomPadding,
  });

  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.only(
      top: topPadding,
      left: AppSpacing.marginMobile,
      right: AppSpacing.marginMobile,
      bottom: bottomPadding,
    ),
    physics: const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    ),
    children: const [
      Shimmer(
        child: GlassCard(
          borderRadius: AppRadius.xl,
          padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ShimmerBox(width: 22, height: 22, radius: AppRadius.full),
                  SizedBox(width: 8),
                  ShimmerBox(width: 130, height: 16, radius: AppRadius.sm),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: ShimmerBox(height: 54, radius: AppRadius.md)),
                  SizedBox(width: 8),
                  Expanded(child: ShimmerBox(height: 54, radius: AppRadius.md)),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ShimmerBox(height: 44, radius: AppRadius.md)),
                  SizedBox(width: 8),
                  Expanded(child: ShimmerBox(height: 44, radius: AppRadius.md)),
                  SizedBox(width: 8),
                  Expanded(child: ShimmerBox(height: 44, radius: AppRadius.md)),
                ],
              ),
            ],
          ),
        ),
      ),
      SizedBox(height: 16),
      Shimmer(
        child: Row(
          children: [
            ShimmerBox(width: 84, height: 34, radius: AppRadius.full),
            SizedBox(width: 8),
            ShimmerBox(width: 84, height: 34, radius: AppRadius.full),
            SizedBox(width: 8),
            ShimmerBox(width: 84, height: 34, radius: AppRadius.full),
          ],
        ),
      ),
      SizedBox(height: 16),
      _GradeDetailSkeletonCard(),
    ],
  );
}

class _GradeDetailSkeletonCard extends StatelessWidget {
  const _GradeDetailSkeletonCard();

  @override
  Widget build(BuildContext context) => const Shimmer(
    child: GlassCard(
      borderRadius: AppRadius.xl,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ShimmerBox(width: 120, height: 18, radius: AppRadius.sm),
              Spacer(),
              ShimmerBox(width: 56, height: 28, radius: AppRadius.full),
            ],
          ),
          SizedBox(height: 14),
          ShimmerBox(height: 44, radius: AppRadius.md),
          SizedBox(height: 8),
          ShimmerBox(height: 44, radius: AppRadius.md),
          SizedBox(height: 8),
          ShimmerBox(height: 44, radius: AppRadius.md),
        ],
      ),
    ),
  );
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Symbols.school,
            size: 28,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            '학기를 선택하면 강의별 성적이 보여요',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSemesterCard extends StatelessWidget {
  const _SelectedSemesterCard({required this.sel});
  final GradeSelectedSemester sel;

  @override
  Widget build(BuildContext context) {
    final totalCdt = sel.courses.fold<int>(0, (a, c) => a + c.cdt);
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                sel.smtCdNm,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Symbols.star,
                      size: 13,
                      color: AppColors.onPrimary,
                      fill: 1,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '평점 ${sel.summary.avgMrks.toStringAsFixed(2)}',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '신청 ${sel.summary.reqCdt}학점 · 취득 ${sel.summary.appCdt}학점 · 합계 $totalCdt학점',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          if (sel.courses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  '해당 학기 강의 내역이 없어요',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < sel.courses.length; i++) ...[
              _CourseRow(c: sel.courses[i]),
              if (i != sel.courses.length - 1)
                Divider(
                  height: 1,
                  color: AppColors.outline.withValues(alpha: 0.2),
                ),
            ],
        ],
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.c});
  final GradeCourseRecord c;
  @override
  Widget build(BuildContext context) {
    final palette = _gradePalette(c.grade);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: palette.fg.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Text(
              c.grade,
              style: AppTypography.labelMd.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: palette.fg,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.curiNm,
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (c.reInfo != null && c.reInfo!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '재수강',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9.5,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${c.curiTypeCdNm} · ${c.cdt}학점',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            c.grade == 'P' || c.grade == 'NP' ? '—' : c.mrks.toStringAsFixed(1),
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Grade color palette — A/B/C/D/F/P 별 다른 색.
// ═══════════════════════════════════════════════════════════════════════

class _GradePalette {
  const _GradePalette(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

_GradePalette _gradePalette(String grade) {
  final letter = grade.isEmpty ? '' : grade[0].toUpperCase();
  switch (letter) {
    case 'A':
      return _GradePalette(const Color(0xFFE7F7EC), const Color(0xFF1F8A4C));
    case 'B':
      return _GradePalette(const Color(0xFFE6F1FD), const Color(0xFF1F5FB1));
    case 'C':
      return _GradePalette(const Color(0xFFFFF6E0), const Color(0xFFB6781E));
    case 'D':
      return _GradePalette(const Color(0xFFFFEBE3), const Color(0xFFC25115));
    case 'F':
      return _GradePalette(const Color(0xFFFDE6E6), const Color(0xFFB5252A));
    case 'P':
      return _GradePalette(
        AppColors.primary.withValues(alpha: 0.10),
        AppColors.primary,
      );
    case 'N':
      return _GradePalette(const Color(0xFFEFEFEF), const Color(0xFF6B6B6B));
    default:
      return _GradePalette(const Color(0xFFEFEFEF), const Color(0xFF6B6B6B));
  }
}
