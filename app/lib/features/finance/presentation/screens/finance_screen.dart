import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/finance/domain/entities/finance_models.dart';
import 'package:sejong_smart_campus/features/finance/presentation/providers/finance_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';

enum FinanceTab { scholarship, tuition, discretionary }

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key, this.initial = FinanceTab.scholarship});
  final FinanceTab initial;
  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  late FinanceTab _tab = widget.initial;
  FinanceSemester? _selected;

  Future<void> _onRefresh() async {
    if (_selected == null) return;
    final key = (year: _selected!.year, smtCd: _selected!.smtCd);
    ref
      ..invalidate(scholarshipsProvider(key))
      ..invalidate(tuitionNoticeProvider(key))
      ..invalidate(discretionaryProvider(key));
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final semestersAsync = ref.watch(scholarshipSemestersProvider);
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
                    semestersAsync.when(
                      loading: () => const _CenterSpinner(),
                      error: (_, _) => const _ErrorBox(),
                      data: (sems) {
                        if (sems.isEmpty) {
                          return const _EmptyBox(text: '학기 정보가 없어요');
                        }
                        _selected ??= sems.first;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SemesterStrip(
                              semesters: sems,
                              selected: _selected!,
                              onSelected: (s) => setState(() => _selected = s),
                            ),
                            const SizedBox(height: 12),
                            _Body(
                              tab: _tab,
                              key: ValueKey(
                                '${_tab}_${_selected!.year}_${_selected!.smtCd}',
                              ),
                              year: _selected!.year,
                              smtCd: _selected!.smtCd,
                            ),
                          ],
                        );
                      },
                    ),
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
            '재정',
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

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selected, required this.onSelected});
  final FinanceTab selected;
  final ValueChanged<FinanceTab> onSelected;
  @override
  Widget build(BuildContext context) {
    String labelOf(FinanceTab t) => switch (t) {
      FinanceTab.scholarship => '장학금',
      FinanceTab.tuition => '등록금',
      FinanceTab.discretionary => '자율경비',
    };
    return Row(
      children: [
        for (final t in FinanceTab.values)
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

class _SemesterStrip extends StatelessWidget {
  const _SemesterStrip({
    required this.semesters,
    required this.selected,
    required this.onSelected,
  });
  final List<FinanceSemester> semesters;
  final FinanceSemester selected;
  final ValueChanged<FinanceSemester> onSelected;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: semesters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = semesters[i];
          final active = s.year == selected.year && s.smtCd == selected.smtCd;
          return Center(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => onSelected(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
                    s.label,
                    style: AppTypography.labelSm.copyWith(
                      color: active ? AppColors.primary : AppColors.onSurface,
                      fontWeight: FontWeight.w700,
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

class _Body extends ConsumerWidget {
  const _Body({
    super.key,
    required this.tab,
    required this.year,
    required this.smtCd,
  });
  final FinanceTab tab;
  final String year;
  final String smtCd;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (year: year, smtCd: smtCd);
    return switch (tab) {
      FinanceTab.scholarship => _ScholarshipBody(
        asyncValue: ref.watch(scholarshipsProvider(key)),
      ),
      FinanceTab.tuition => _TuitionBody(
        asyncValue: ref.watch(tuitionNoticeProvider(key)),
      ),
      FinanceTab.discretionary => _DiscretionaryBody(
        asyncValue: ref.watch(discretionaryProvider(key)),
      ),
    };
  }
}

class _ScholarshipBody extends StatelessWidget {
  const _ScholarshipBody({required this.asyncValue});
  final AsyncValue<List<ScholarshipItem>> asyncValue;
  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const _CenterSpinner(),
      error: (_, _) => const _ErrorBox(),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyBox(text: '해당 학기 장학금 수혜 내역이 없어요');
        }
        final total = items.fold<int>(0, (s, e) => s + e.totalAmount);
        return GlassCard(
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                icon: Symbols.workspace_premium,
                title: '장학금 수혜 내역',
                total: total,
              ),
              const SizedBox(height: 8),
              for (final s in items) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.scholarshipName,
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _AmountRow(label: '입학금', amount: s.admissionFee),
                      _AmountRow(label: '수업료', amount: s.tuitionFee),
                      if (s.supportFee > 0)
                        _AmountRow(label: '지원금', amount: s.supportFee),
                      const Divider(),
                      _AmountRow(label: '계', amount: s.totalAmount, bold: true),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TuitionBody extends StatelessWidget {
  const _TuitionBody({required this.asyncValue});
  final AsyncValue<List<TuitionItem>> asyncValue;
  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const _CenterSpinner(),
      error: (_, _) => const _ErrorBox(),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyBox(text: '해당 학기 등록금 내역이 없어요');
        }
        return Column(
          children: [
            for (final t in items) ...[
              GlassCard(
                borderRadius: AppRadius.xl,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      icon: Symbols.receipt_long,
                      title: t.yearSmtInfo,
                      total: t.totDemandAmt,
                    ),
                    const SizedBox(height: 8),
                    _AmountRow(label: '입학금', amount: t.rgstEntAmt),
                    _AmountRow(label: '수업료', amount: t.rgstLessAmt),
                    if (t.totSchoAmt > 0)
                      _AmountRow(label: '장학 감면', amount: -t.totSchoAmt),
                    const Divider(),
                    _AmountRow(
                      label: '고지액',
                      amount: t.totDemandAmt,
                      bold: true,
                    ),
                    if (t.resAmt > 0) ...[
                      const SizedBox(height: 2),
                      _AmountRow(label: '환불액', amount: t.resAmt),
                    ],
                    if (t.virtBankNo.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Symbols.account_balance,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '가상계좌',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            SelectableText(
                              t.virtBankNo,
                              style: AppTypography.labelMd.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _DiscretionaryBody extends StatelessWidget {
  const _DiscretionaryBody({required this.asyncValue});
  final AsyncValue<List<DiscretionaryGroup>> asyncValue;
  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const _CenterSpinner(),
      error: (_, _) => const _ErrorBox(),
      data: (groups) {
        if (groups.isEmpty) {
          return const _EmptyBox(text: '자율경비 내역이 없어요');
        }
        return Column(
          children: [
            for (final g in groups) ...[
              GlassCard(
                borderRadius: AppRadius.xl,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      icon: Symbols.wallet,
                      title: g.label,
                      total: g.totalBilled,
                    ),
                    const SizedBox(height: 8),
                    for (final it in g.items) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                it.name,
                                style: AppTypography.labelMd.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            Text(
                              '${_fmt(it.billedAmount)}원',
                              style: AppTypography.labelMd.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(),
                    Row(
                      children: [
                        Text(
                          '납부',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_fmt(g.totalPaid)} / ${_fmt(g.totalBilled)}원',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

// ─── helpers ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.icon, required this.title, required this.total});
  final IconData icon;
  final String title;
  final int total;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, fill: 1, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.labelMd.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          '${_fmt(total)}원',
          style: AppTypography.labelMd.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.bold = false,
  });
  final String label;
  final int amount;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${_fmt(amount)}원',
            style: AppTypography.labelMd.copyWith(
              color: bold ? AppColors.primary : AppColors.onSurface,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 14 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(int amount) {
  final s = amount.abs().toString();
  final buf = StringBuffer();
  if (amount < 0) buf.write('-');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _CenterSpinner extends StatelessWidget {
  const _CenterSpinner();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Text(
        '재정 정보를 불러오지 못했어요',
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
