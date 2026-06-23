import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/grade_calculator_models.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/grade_calculator_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

class GradeCalculatorScreen extends ConsumerStatefulWidget {
  const GradeCalculatorScreen({super.key});

  @override
  ConsumerState<GradeCalculatorScreen> createState() =>
      _GradeCalculatorScreenState();
}

class _GradeCalculatorScreenState extends ConsumerState<GradeCalculatorScreen> {
  String? _selectedTermId;

  Future<void> _onRefresh() async {
    ref.invalidate(gradeCalculatorBaselineProvider);
    ref.invalidate(gradeCalculatorProvider);
    try {
      await Future.wait([
        Future<void>.delayed(const Duration(milliseconds: 300)),
        ref.read(gradeCalculatorProvider.future).then((_) {}),
      ]);
    } catch (_) {
      // Provider error UI가 렌더한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final async = ref.watch(gradeCalculatorProvider);
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
                  loading: () => _CalculatorSkeleton(
                    topPadding: mq.padding.top + 64 + 16,
                    bottomPadding: 120 + mq.padding.bottom,
                  ),
                  error: (_, _) => Center(
                    child: Text(
                      '학점 계산기 데이터를 불러오지 못했어요',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  data: (snapshot) {
                    final selectedTerm = _selectedTerm(snapshot);
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
                        _TermTabs(
                          terms: snapshot.terms,
                          selectedTermId: selectedTerm?.id,
                          onSelected: (term) {
                            setState(() => _selectedTermId = term.id);
                          },
                        ),
                        const SizedBox(height: 14),
                        _SummaryCard(snapshot: snapshot),
                        const SizedBox(height: 18),
                        if (selectedTerm == null)
                          const _EmptyCalculator()
                        else
                          _SelectedTermEditor(
                            snapshot: snapshot,
                            term: selectedTerm,
                          ),
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

  GradeCalculatorTerm? _selectedTerm(GradeCalculatorSnapshot snapshot) {
    if (snapshot.terms.isEmpty) return null;
    final preferred = _selectedTermId ?? snapshot.defaultTermId;
    if (preferred != null) {
      final match = snapshot.termById(preferred);
      if (match != null) return match;
    }
    return snapshot.terms.last;
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
            tooltip: '뒤로',
            icon: const Icon(Symbols.arrow_back, color: AppColors.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            '학점계산기',
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

class _TermTabs extends StatelessWidget {
  const _TermTabs({
    required this.terms,
    required this.selectedTermId,
    required this.onSelected,
  });

  final List<GradeCalculatorTerm> terms;
  final String? selectedTermId;
  final ValueChanged<GradeCalculatorTerm> onSelected;

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: terms.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final term = terms[index];
          final selected = term.id == selectedTermId;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: () => onSelected(term),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(minWidth: 108),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.onSurface
                      : Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: selected
                        ? AppColors.onSurface
                        : AppColors.outline.withValues(alpha: 0.28),
                  ),
                ),
                child: Center(
                  child: Text(
                    term.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMd.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.surface
                          : AppColors.onSurfaceVariant,
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot});

  final GradeCalculatorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.summary;
    final percent = summary.percentage;
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SummaryStat(label: '전체 평점', value: summary.gpaLabel),
              const SizedBox(width: 8),
              _SummaryStat(label: '전공 평점', value: summary.majorGpaLabel),
              const SizedBox(width: 8),
              _SummaryStat(label: '취득 학점', value: summary.earnedCreditsLabel),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            percent == null
                ? '백분율 환산 -'
                : '백분율 환산 ${percent.toStringAsFixed(1)}',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 122,
            child: CustomPaint(
              painter: _GpaTrendPainter(snapshot.terms),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 18),
          _DistributionBars(summary: summary),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionBars extends StatelessWidget {
  const _DistributionBars({required this.summary});

  final GradeCalculatorSummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final grade in GradeCalculatorGrade.values)
        if ((summary.gradeDistribution[grade] ?? 0) > 0)
          MapEntry(grade, summary.gradeDistribution[grade] ?? 0),
    ];
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    if (total == 0) {
      return Text(
        '성적 분포가 비어 있어요',
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      );
    }
    final top = entries.take(5).toList();
    return Column(
      children: [
        for (final entry in top) ...[
          _DistributionRow(
            label: entry.key.label,
            value: entry.value / total,
            color: _gradeColor(entry.key),
          ),
          if (entry != top.last) const SizedBox(height: 7),
        ],
      ],
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.outline.withValues(alpha: 0.12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: AppTypography.labelSm.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedTermEditor extends ConsumerWidget {
  const _SelectedTermEditor({required this.snapshot, required this.term});

  final GradeCalculatorSnapshot snapshot;
  final GradeCalculatorTerm term;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = term.summary;
    final notifier = ref.read(gradeCalculatorProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    term.label,
                    style: AppTypography.headlineMd.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onSurface,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '평점 ${summary.gpaLabel} · 전공 ${summary.majorGpaLabel} · 취득 ${summary.earnedCreditsLabel}',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (snapshot.shouldShowSync(term.id))
              FilledButton.icon(
                onPressed: () => _confirmSync(context, ref, term.id),
                icon: const Icon(Symbols.sync, size: 18),
                label: const Text('동기화 학기'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          borderRadius: AppRadius.xl,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const _CourseHeader(),
              if (term.courses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    '과목이 없어요',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (var i = 0; i < term.courses.length; i++) ...[
                  _CourseEditorRow(termId: term.id, course: term.courses[i]),
                  if (i != term.courses.length - 1)
                    Divider(
                      height: 1,
                      color: AppColors.outline.withValues(alpha: 0.16),
                    ),
                ],
              Divider(
                height: 1,
                color: AppColors.outline.withValues(alpha: 0.16),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => notifier.addCourse(term.id),
                      icon: const Icon(Symbols.add, size: 18),
                      label: const Text('더 입력하기'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => notifier.resetTerm(term.id),
                      icon: const Icon(Symbols.refresh, size: 18),
                      label: const Text('초기화'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSync(
    BuildContext context,
    WidgetRef ref,
    String termId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('동기화 학기'),
        content: const Text('선택한 학기를 최신 서버 성적으로 되돌리고 저장된 편집값을 정리할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('동기화'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(gradeCalculatorProvider.notifier).syncTerm(termId);
    }
  }
}

class _CourseHeader extends StatelessWidget {
  const _CourseHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.72),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 7, child: _HeaderText('과목명')),
          SizedBox(width: 64, child: Center(child: _HeaderText('학점'))),
          SizedBox(width: 72, child: Center(child: _HeaderText('성적'))),
          SizedBox(width: 48, child: Center(child: _HeaderText('전공'))),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelSm.copyWith(
        color: AppColors.onSurfaceVariant,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CourseEditorRow extends ConsumerWidget {
  const _CourseEditorRow({required this.termId, required this.course});

  final String termId;
  final GradeCalculatorCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gradeCalculatorProvider.notifier);
    final disabled = course.retakeExcluded;
    return AnimatedOpacity(
      opacity: disabled ? 0.58 : 1,
      duration: const Duration(milliseconds: 140),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 7,
              child: course.localOnly
                  ? TextFormField(
                      key: ValueKey('name-${course.id}'),
                      initialValue: course.name,
                      decoration: const InputDecoration(
                        hintText: '과목명',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: (value) =>
                          notifier.updateName(termId, course.id, value),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            decoration: disabled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (course.retakeCandidate ||
                            course.retakeExcluded ||
                            (course.category ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 4,
                            runSpacing: 3,
                            children: [
                              if ((course.category ?? '').isNotEmpty)
                                _MiniTag(course.category!),
                              if (course.retakeCandidate) _MiniTag('재수강 후보'),
                              if (course.retakeExcluded) _MiniTag('재수강 제외'),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
            SizedBox(
              width: 64,
              child: _CreditsStepper(
                value: course.credits,
                onChanged: (value) =>
                    notifier.updateCredits(termId, course.id, value),
              ),
            ),
            SizedBox(
              width: 72,
              child: Center(
                child: _GradeButton(
                  grade: course.grade,
                  onTap: () => _showGradeSheet(context, ref, termId, course.id),
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Center(
                child: Checkbox(
                  value: course.isMajor,
                  onChanged: (value) =>
                      notifier.updateMajor(termId, course.id, value == true),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: PopupMenuButton<String>(
                tooltip: '과목 옵션',
                icon: const Icon(Symbols.more_vert, size: 20),
                onSelected: (value) {
                  switch (value) {
                    case 'retake':
                      notifier.toggleRetakeExcluded(termId, course.id);
                    case 'delete':
                      notifier.deleteCourse(termId, course.id);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'retake',
                    child: Text(course.retakeExcluded ? '재수강 제외 해제' : '재수강 제외'),
                  ),
                  if (course.localOnly)
                    const PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showGradeSheet(
    BuildContext context,
    WidgetRef ref,
    String termId,
    String courseId,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final grade in GradeCalculatorGrade.values)
                ListTile(
                  title: Text(grade.label),
                  trailing: Icon(
                    grade == course.grade
                        ? Symbols.radio_button_checked
                        : Symbols.radio_button_unchecked,
                    color: grade == course.grade
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                  onTap: () {
                    ref
                        .read(gradeCalculatorProvider.notifier)
                        .updateGrade(termId, courseId, grade);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CreditsStepper extends StatelessWidget {
  const _CreditsStepper({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _StepperButton(
            icon: Symbols.remove,
            onTap: () => onChanged(math.max(0, value - 1)),
          ),
          Expanded(
            child: Text(
              _formatCredits(value),
              textAlign: TextAlign.center,
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          _StepperButton(icon: Symbols.add, onTap: () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: 20,
        height: 34,
        child: Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({required this.grade, required this.onTap});

  final GradeCalculatorGrade grade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor(grade);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: color.withValues(alpha: 0.38)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                grade.label,
                style: AppTypography.labelSm.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Symbols.keyboard_arrow_down, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCalculator extends StatelessWidget {
  const _EmptyCalculator();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        children: [
          const Icon(
            Symbols.calculate,
            size: 32,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            '계산할 학기 데이터가 없어요',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculatorSkeleton extends StatelessWidget {
  const _CalculatorSkeleton({
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
    children: const [
      Shimmer(
        child: Row(
          children: [
            ShimmerBox(width: 110, height: 40, radius: AppRadius.full),
            SizedBox(width: 8),
            ShimmerBox(width: 110, height: 40, radius: AppRadius.full),
          ],
        ),
      ),
      SizedBox(height: 14),
      Shimmer(
        child: GlassCard(
          borderRadius: AppRadius.xl,
          padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: ShimmerBox(height: 70, radius: AppRadius.lg)),
                  SizedBox(width: 8),
                  Expanded(child: ShimmerBox(height: 70, radius: AppRadius.lg)),
                  SizedBox(width: 8),
                  Expanded(child: ShimmerBox(height: 70, radius: AppRadius.lg)),
                ],
              ),
              SizedBox(height: 18),
              ShimmerBox(height: 122, radius: AppRadius.lg),
            ],
          ),
        ),
      ),
      SizedBox(height: 18),
      Shimmer(
        child: GlassCard(
          borderRadius: AppRadius.xl,
          padding: EdgeInsets.all(18),
          child: Column(
            children: [
              ShimmerBox(height: 44, radius: AppRadius.md),
              SizedBox(height: 8),
              ShimmerBox(height: 44, radius: AppRadius.md),
              SizedBox(height: 8),
              ShimmerBox(height: 44, radius: AppRadius.md),
            ],
          ),
        ),
      ),
    ],
  );
}

class _GpaTrendPainter extends CustomPainter {
  const _GpaTrendPainter(this.terms);

  final List<GradeCalculatorTerm> terms;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.20)
      ..strokeWidth = 1;
    for (final value in const [2.0, 3.0, 4.0]) {
      final y = _yFor(value, size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      _drawLabel(canvas, value.toStringAsFixed(1), Offset(0, y - 18));
    }

    final points = <Offset>[];
    final summaries = [for (final term in terms) term.summary.gpa];
    for (var i = 0; i < summaries.length; i++) {
      final gpa = summaries[i];
      if (gpa == null) continue;
      final x = terms.length <= 1
          ? size.width / 2
          : size.width * i / (terms.length - 1);
      points.add(Offset(x, _yFor(gpa, size)));
    }
    if (points.isEmpty) return;

    final linePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    for (final point in points) {
      canvas.drawCircle(point, 5, fill);
      canvas.drawCircle(point, 5, stroke);
    }
  }

  double _yFor(double gpa, Size size) {
    final clamped = gpa.clamp(0.0, 4.5);
    return size.height - (clamped / 4.5) * size.height;
  }

  void _drawLabel(Canvas canvas, String label, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.72),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GpaTrendPainter oldDelegate) =>
      oldDelegate.terms != terms;
}

Color _gradeColor(GradeCalculatorGrade grade) {
  switch (grade) {
    case GradeCalculatorGrade.aPlus:
    case GradeCalculatorGrade.a0:
      return const Color(0xFF1F8A4C);
    case GradeCalculatorGrade.bPlus:
    case GradeCalculatorGrade.b0:
      return const Color(0xFF1F5FB1);
    case GradeCalculatorGrade.cPlus:
    case GradeCalculatorGrade.c0:
      return const Color(0xFFB6781E);
    case GradeCalculatorGrade.dPlus:
    case GradeCalculatorGrade.d0:
      return const Color(0xFFC25115);
    case GradeCalculatorGrade.f:
      return const Color(0xFFB5252A);
    case GradeCalculatorGrade.p:
      return AppColors.primary;
    case GradeCalculatorGrade.np:
      return const Color(0xFF6B6B6B);
  }
}

String _formatCredits(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}
