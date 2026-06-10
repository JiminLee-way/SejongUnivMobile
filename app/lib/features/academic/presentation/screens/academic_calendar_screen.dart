import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/academic_providers.dart';
import 'package:sejong_smart_campus/features/academic/presentation/widgets/day_detail_panel.dart';
import 'package:sejong_smart_campus/features/academic/presentation/widgets/month_grid.dart';
import 'package:sejong_smart_campus/features/academic/presentation/widgets/org_filter_sheet.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

/// 학사 캘린더 — 1:1 분할. 위: month grid (dot 표시), 아래: 선택일 detail.
class AcademicCalendarScreen extends ConsumerStatefulWidget {
  const AcademicCalendarScreen({super.key});
  @override
  ConsumerState<AcademicCalendarScreen> createState() =>
      _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState
    extends ConsumerState<AcademicCalendarScreen> {
  void _goToday() {
    final n = DateTime.now();
    ref.read(calendarMonthProvider.notifier).value = n;
    ref.read(calendarDateProvider.notifier).value = n;
  }

  void _onMonthShift(int delta) {
    ref.read(calendarMonthProvider.notifier).shift(delta);
    final newMonth = ref.read(calendarMonthProvider);
    final cur = ref.read(calendarDateProvider);
    final lastDay = DateTime(newMonth.year, newMonth.month + 1, 0).day;
    final targetDay = cur.day > lastDay ? lastDay : cur.day;
    ref.read(calendarDateProvider.notifier).value = DateTime(
      newMonth.year,
      newMonth.month,
      targetDay,
    );
  }

  void _onCellSelect(DateTime d) {
    final month = ref.read(calendarMonthProvider);
    ref.read(calendarDateProvider.notifier).value = d;
    if (d.month != month.month || d.year != month.year) {
      ref.read(calendarMonthProvider.notifier).value = d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(calendarMonthProvider);
    final selected = ref.watch(calendarDateProvider);
    final orgFilter = ref.watch(orgFilterProvider);
    final marks = ref.watch(
      monthlyMarksProvider((year: month.year, month: month.month)),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  top: SejongSubAppBar.heightFor(context) + 8,
                  left: AppSpacing.marginMobile / 1.5,
                  right: AppSpacing.marginMobile / 1.5,
                  bottom: MediaQuery.paddingOf(context).bottom + 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MonthHeader(
                      month: month,
                      onPrev: () => _onMonthShift(-1),
                      onNext: () => _onMonthShift(1),
                      onToday: _goToday,
                    ),
                    if (orgFilter.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _ActiveFilterChips(names: orgFilter.toList()),
                    ],
                    const SizedBox(height: 6),
                    // 1:1 분할 — 위 캘린더, 아래 detail.
                    Expanded(
                      flex: 1,
                      child: MonthGrid(
                        month: month,
                        selected: selected,
                        markedDays: marks.maybeWhen(
                          data: (m) => m.scheduleDays,
                          orElse: () => null,
                        ),
                        onSelect: _onCellSelect,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      color: AppColors.outline.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 12),
                    Expanded(flex: 1, child: _DetailPane(date: selected)),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SejongSubAppBar(
                title: '학사 캘린더',
                actions: [
                  IconButton(
                    tooltip: '학과 필터',
                    icon: Icon(
                      Symbols.filter_alt,
                      fill: orgFilter.isEmpty ? 0 : 1,
                      color: orgFilter.isEmpty
                          ? AppColors.onSurface
                          : AppColors.primary,
                    ),
                    onPressed: () => showOrgFilterSheet(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.date});
  final DateTime date;

  static const _weekKor = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final isToday = _sameDay(date, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              isToday ? Symbols.today : Symbols.event_note,
              size: 18,
              color: AppColors.primary,
              fill: 1,
            ),
            const SizedBox(width: 8),
            Text(
              '${date.month}월 ${date.day}일 (${_weekKor[date.weekday - 1]})',
              style: AppTypography.headlineMd.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                height: 1.0,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '오늘',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            child: DayDetailPanel(date: date),
          ),
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    return Row(
      children: [
        IconButton(
          icon: const Icon(
            Symbols.chevron_left,
            color: AppColors.onSurface,
            size: 26,
          ),
          onPressed: onPrev,
          splashRadius: 20,
        ),
        Expanded(
          child: Center(
            child: Text(
              '${month.year}년 ${month.month}월',
              style: AppTypography.headlineMd.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(
            Symbols.chevron_right,
            color: AppColors.onSurface,
            size: 26,
          ),
          onPressed: onNext,
          splashRadius: 20,
        ),
        // 현재 월일 땐 layout space까지 0 — "2026년 5월"이 화살표 사이 진짜
        // 가운데로 오도록. AnimatedSize로 폭 변화는 부드럽게.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.centerRight,
          child: isCurrentMonth
              ? const SizedBox.shrink()
              : TextButton.icon(
                  onPressed: onToday,
                  icon: Icon(
                    Symbols.today,
                    size: 16,
                    color: AppColors.primary,
                    fill: 1,
                  ),
                  label: Text(
                    '오늘',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ActiveFilterChips extends ConsumerWidget {
  const _ActiveFilterChips({required this.names});
  final List<String> names;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: names.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          if (i == names.length) {
            return GestureDetector(
              onTap: () => ref.read(orgFilterProvider.notifier).clear(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: AppColors.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Symbols.close,
                      size: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '전체 해제',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final n = names[i];
          return GestureDetector(
            onTap: () => ref.read(orgFilterProvider.notifier).toggle(n),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    n,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Symbols.close, size: 12, color: AppColors.onPrimary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
