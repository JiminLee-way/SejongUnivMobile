import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sejong_smart_campus/core/routing/menu_route_helper.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/academic_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

class AcademicCalendarScreen extends ConsumerStatefulWidget {
  const AcademicCalendarScreen({super.key});

  @override
  ConsumerState<AcademicCalendarScreen> createState() =>
      _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState
    extends ConsumerState<AcademicCalendarScreen> {
  DateTime _selectedDay = DateTime.now();

  Future<void> _onRefresh() async {
    final query = _query();
    ref.invalidate(officialAcademicCalendarProvider(query));
    await ref
        .read(officialAcademicCalendarProvider(query).future)
        .catchError((_) => const <AcademicCalendarEvent>[]);
  }

  OfficialCalendarQuery _query() {
    final mode = ref.read(officialCalendarModeProvider);
    final category = ref.read(officialCalendarCategoryProvider);
    final month = ref.read(officialCalendarMonthProvider);
    final year = ref.read(officialCalendarYearProvider);
    return (
      mode: mode,
      year: mode == AcademicCalendarMode.month ? month.year : year,
      month: mode == AcademicCalendarMode.month ? month.month : 1,
      categoryCode: category.code,
    );
  }

  void _goToday() {
    final now = DateTime.now();
    ref.read(officialCalendarMonthProvider.notifier).select(now);
    ref.read(officialCalendarYearProvider.notifier).select(now.year);
    setState(() => _selectedDay = DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    final topInset = SejongSubAppBar.heightFor(context);
    final mode = ref.watch(officialCalendarModeProvider);
    final category = ref.watch(officialCalendarCategoryProvider);
    final month = ref.watch(officialCalendarMonthProvider);
    final year = ref.watch(officialCalendarYearProvider);
    final query = (
      mode: mode,
      year: mode == AcademicCalendarMode.month ? month.year : year,
      month: mode == AcademicCalendarMode.month ? month.month : 1,
      categoryCode: category.code,
    );
    final eventsAsync = ref.watch(officialAcademicCalendarProvider(query));

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: SejongRefresh(
                onRefresh: _onRefresh,
                topInset: topInset,
                child: ListView(
                  padding: EdgeInsets.only(
                    top: topInset + 12,
                    left: AppSpacing.marginMobile,
                    right: AppSpacing.marginMobile,
                    bottom: 40 + MediaQuery.paddingOf(context).bottom,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    _Controls(
                      mode: mode,
                      category: category,
                      month: month,
                      year: year,
                      onToday: _goToday,
                    ),
                    const SizedBox(height: 14),
                    eventsAsync.when(
                      skipLoadingOnRefresh: false,
                      loading: () => _CalendarSkeleton(mode: mode),
                      error: (error, _) => _CalendarError(
                        onRetry: () => unawaited(_onRefresh()),
                      ),
                      data: (events) {
                        if (mode == AcademicCalendarMode.month) {
                          return _MonthCalendarBody(
                            month: month,
                            selectedDay: _selectedDay,
                            events: events,
                            onSelectDay: (day) {
                              setState(() => _selectedDay = day);
                              if (day.year != month.year ||
                                  day.month != month.month) {
                                ref
                                    .read(
                                      officialCalendarMonthProvider.notifier,
                                    )
                                    .select(day);
                              }
                            },
                          );
                        }
                        return _YearCalendarBody(year: year, events: events);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: SejongSubAppBar(title: '학사 캘린더'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({
    required this.mode,
    required this.category,
    required this.month,
    required this.year,
    required this.onToday,
  });

  final AcademicCalendarMode mode;
  final AcademicCalendarCategory category;
  final DateTime month;
  final int year;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeSwitch(
            selected: mode,
            onSelect: (next) =>
                ref.read(officialCalendarModeProvider.notifier).select(next),
          ),
          const SizedBox(height: 12),
          _CategoryDropdown(
            selected: category,
            onSelected: (next) => ref
                .read(officialCalendarCategoryProvider.notifier)
                .select(next),
          ),
          const SizedBox(height: 12),
          if (mode == AcademicCalendarMode.month)
            _MonthPicker(month: month, onToday: onToday)
          else
            _YearPicker(year: year),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.selected, required this.onSelect});

  final AcademicCalendarMode selected;
  final ValueChanged<AcademicCalendarMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: '월간일정',
            icon: Symbols.calendar_month,
            selected: selected == AcademicCalendarMode.month,
            onTap: () => onSelect(AcademicCalendarMode.month),
          ),
          _ModeButton(
            label: '연간일정',
            icon: Symbols.list_alt,
            selected: selected == AcademicCalendarMode.year,
            onTap: () => onSelect(AcademicCalendarMode.year),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                fill: selected ? 1 : 0,
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.selected, required this.onSelected});

  final AcademicCalendarCategory selected;
  final ValueChanged<AcademicCalendarCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AcademicCalendarCategory>(
          value: selected,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          isExpanded: true,
          icon: const Icon(Symbols.keyboard_arrow_down, size: 20),
          items: [
            for (final category in AcademicCalendarCategory.values)
              DropdownMenuItem<AcademicCalendarCategory>(
                value: category,
                child: Text(
                  category.label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
        ),
      ),
    );
  }
}

class _MonthPicker extends ConsumerWidget {
  const _MonthPicker({required this.month, required this.onToday});

  final DateTime month;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = _yearOptions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '이전 달',
              onPressed: () =>
                  ref.read(officialCalendarMonthProvider.notifier).shift(-1),
              icon: const Icon(Symbols.chevron_left),
            ),
            Expanded(
              flex: 5,
              child: _CompactDropdown<int>(
                value: month.year,
                items: years,
                labelOf: (year) => '$year년',
                onChanged: (year) => ref
                    .read(officialCalendarMonthProvider.notifier)
                    .selectYear(year),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: _CompactDropdown<int>(
                value: month.month,
                items: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                labelOf: (month) => '$month월',
                onChanged: (month) => ref
                    .read(officialCalendarMonthProvider.notifier)
                    .selectMonth(month),
              ),
            ),
            IconButton(
              tooltip: '다음 달',
              onPressed: () =>
                  ref.read(officialCalendarMonthProvider.notifier).shift(1),
              icon: const Icon(Symbols.chevron_right),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onToday,
            icon: const Icon(Symbols.today, size: 16, fill: 1),
            label: const Text('오늘'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _YearPicker extends ConsumerWidget {
  const _YearPicker({required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(
          tooltip: '이전 해',
          onPressed: () =>
              ref.read(officialCalendarYearProvider.notifier).shift(-1),
          icon: const Icon(Symbols.chevron_left),
        ),
        Expanded(
          child: _CompactDropdown<int>(
            value: year,
            items: _yearOptions(),
            labelOf: (year) => '$year년',
            onChanged: (year) =>
                ref.read(officialCalendarYearProvider.notifier).select(year),
          ),
        ),
        IconButton(
          tooltip: '다음 해',
          onPressed: () =>
              ref.read(officialCalendarYearProvider.notifier).shift(1),
          icon: const Icon(Symbols.chevron_right),
        ),
      ],
    );
  }
}

class _CompactDropdown<T> extends StatelessWidget {
  const _CompactDropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          icon: const Icon(Symbols.keyboard_arrow_down, size: 18),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(
                  labelOf(item),
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _MonthCalendarBody extends StatelessWidget {
  const _MonthCalendarBody({
    required this.month,
    required this.selectedDay,
    required this.events,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime selectedDay;
  final List<AcademicCalendarEvent> events;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final sorted = sortAcademicCalendarEvents(events);
    final selectedEvents = sorted
        .where((event) => event.occursOn(selectedDay))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: _MonthGrid(
            month: month,
            selectedDay: selectedDay,
            events: sorted,
            onSelectDay: onSelectDay,
          ),
        ),
        const SizedBox(height: 14),
        _EventListCard(
          title: '${selectedDay.month}월 ${selectedDay.day}일 일정',
          events: selectedEvents,
          emptyText: '선택한 날짜에 등록된 일정이 없어요',
          compactEmpty: true,
        ),
        const SizedBox(height: 14),
        _EventListCard(
          title: '${month.year}년 ${month.month}월 학사일정',
          events: sorted,
          emptyText: '이 기간에 등록된 학사일정이 없어요',
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.events,
    required this.onSelectDay,
  });

  final DateTime month;
  final DateTime selectedDay;
  final List<AcademicCalendarEvent> events;
  final ValueChanged<DateTime> onSelectDay;

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final days = academicCalendarMonthGridDays(month.year, month.month);
    final weeks = [
      for (var week = 0; week < 6; week++) days.sublist(week * 7, week * 7 + 7),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < _weekdays.length; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _weekdays[i],
                    style: AppTypography.labelSm.copyWith(
                      color: i == 0
                          ? AppColors.primary
                          : i == 6
                          ? const Color(0xFF2E70D8)
                          : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < weeks.length; i++) ...[
          _WeekRow(
            days: weeks[i],
            month: month,
            selectedDay: selectedDay,
            events: events,
            onSelectDay: onSelectDay,
          ),
          if (i < weeks.length - 1) const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.days,
    required this.month,
    required this.events,
    required this.selectedDay,
    required this.onSelectDay,
  });

  final List<DateTime> days;
  final DateTime month;
  final List<AcademicCalendarEvent> events;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;

  static const _dayHeaderHeight = 42.0;
  static const _laneHeight = 28.0;
  static const _laneGap = 4.0;
  static const _rowBottomPadding = 8.0;
  static const _overflowHeight = 18.0;
  static const _maxVisibleLanes = 4;

  @override
  Widget build(BuildContext context) {
    final weekStart = days.first;
    final weekEnd = days.last;
    final segments = _buildWeekSegments(weekStart, weekEnd, events);
    final visibleSegments = segments
        .where((segment) => segment.lane < _maxVisibleLanes)
        .toList(growable: false);
    final hiddenCount = segments.length - visibleSegments.length;
    final selectedIndex = days.indexWhere((day) => _sameDate(day, selectedDay));
    final laneCount = visibleSegments.isEmpty
        ? 1
        : visibleSegments.map((segment) => segment.lane).reduce((a, b) {
                return a > b ? a : b;
              }) +
              1;
    final rowHeight =
        _dayHeaderHeight +
        laneCount * _laneHeight +
        (laneCount - 1) * _laneGap +
        _rowBottomPadding +
        (hiddenCount > 0 ? _overflowHeight : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth / 7;
        return SizedBox(
          height: rowHeight,
          child: Stack(
            key: ValueKey(
              'academic-calendar-week-row:${weekStart.year}-${weekStart.month}-${weekStart.day}',
            ),
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    for (final day in days)
                      Expanded(
                        child: _WeekDayCell(
                          day: day,
                          month: month,
                          onTap: () => onSelectDay(day),
                        ),
                      ),
                  ],
                ),
              ),
              for (final segment in visibleSegments)
                Positioned(
                  key: ValueKey(
                    'academic-calendar-week-bar-positioned:${segment.keySuffix}',
                  ),
                  top:
                      _dayHeaderHeight +
                      segment.lane * (_laneHeight + _laneGap),
                  left: segment.startIndex * columnWidth + 2,
                  width:
                      (segment.endIndex - segment.startIndex + 1) *
                          columnWidth -
                      4,
                  height: _laneHeight,
                  child: IgnorePointer(
                    child: _WeekEventBar(
                      event: segment.event,
                      startsBeforeWeek: segment.startsBeforeWeek,
                      endsAfterWeek: segment.endsAfterWeek,
                      startIndex: segment.startIndex,
                      endIndex: segment.endIndex,
                      showTitle: segment.visibleDayCount >= 3,
                    ),
                  ),
                ),
              if (hiddenCount > 0)
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: 0,
                  height: _overflowHeight,
                  child: Text(
                    '+$hiddenCount 일정',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (selectedIndex >= 0)
                Positioned(
                  key: const ValueKey(
                    'academic-calendar-selected-day-overlay-positioned',
                  ),
                  top: 0,
                  left: selectedIndex * columnWidth,
                  width: columnWidth,
                  height: rowHeight,
                  child: const IgnorePointer(child: _SelectedDayOverlay()),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_WeekSegment> _buildWeekSegments(
    DateTime weekStart,
    DateTime weekEnd,
    List<AcademicCalendarEvent> events,
  ) {
    final segments = <_WeekSegment>[];
    final lanes = <List<_WeekSegment>>[];
    for (final event in sortAcademicCalendarEvents(events)) {
      if (!event.overlaps(weekStart, weekEnd)) continue;

      final startsBeforeWeek = event.startDate.isBefore(weekStart);
      final endsAfterWeek = event.endDate.isAfter(weekEnd);
      final startIndex = startsBeforeWeek
          ? 0
          : event.startDate.difference(weekStart).inDays.clamp(0, 6);
      final endIndex = endsAfterWeek
          ? 6
          : event.endDate.difference(weekStart).inDays.clamp(0, 6);
      var lane = 0;
      while (true) {
        if (lane == lanes.length) lanes.add(<_WeekSegment>[]);
        final hasCollision = lanes[lane].any(
          (segment) =>
              !(endIndex < segment.startIndex || startIndex > segment.endIndex),
        );
        if (!hasCollision) break;
        lane++;
      }

      final segment = _WeekSegment(
        event: event,
        startIndex: startIndex,
        endIndex: endIndex,
        lane: lane,
        visibleDayCount: endIndex - startIndex + 1,
        startsBeforeWeek: startsBeforeWeek,
        endsAfterWeek: endsAfterWeek,
      );
      lanes[lane].add(segment);
      segments.add(segment);
    }
    return segments;
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.day,
    required this.month,
    required this.onTap,
  });

  final DateTime day;
  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inMonth = day.year == month.year && day.month == month.month;
    final isToday = _sameDate(day, DateTime.now());
    final isSunday = day.weekday == DateTime.sunday;
    final isSaturday = day.weekday == DateTime.saturday;
    final textColor = !inMonth
        ? AppColors.onSurfaceVariant.withValues(alpha: 0.36)
        : isSunday
        ? AppColors.primary
        : isSaturday
        ? const Color(0xFF2E70D8)
        : AppColors.onSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(5, 6, 5, 0),
        decoration: BoxDecoration(
          color: inMonth
              ? Colors.white.withValues(alpha: 0.50)
              : Colors.white.withValues(alpha: 0.25),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.42),
            width: 0.7,
          ),
        ),
        child: Align(
          alignment: Alignment.topRight,
          child: _DateNumber(day: day.day, isToday: isToday, color: textColor),
        ),
      ),
    );
  }
}

class _SelectedDayOverlay extends StatelessWidget {
  const _SelectedDayOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('academic-calendar-selected-day-overlay'),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.045),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    );
  }
}

class _DateNumber extends StatelessWidget {
  const _DateNumber({
    required this.day,
    required this.isToday,
    required this.color,
  });

  final int day;
  final bool isToday;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!isToday) {
      return Text(
        '$day',
        style: AppTypography.labelMd.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.0,
        ),
      );
    }
    return Container(
      width: 25,
      height: 25,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$day',
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

class _WeekEventBar extends StatelessWidget {
  const _WeekEventBar({
    required this.event,
    required this.startsBeforeWeek,
    required this.endsAfterWeek,
    required this.startIndex,
    required this.endIndex,
    required this.showTitle,
  });

  final AcademicCalendarEvent event;
  final bool startsBeforeWeek;
  final bool endsAfterWeek;
  final int startIndex;
  final int endIndex;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    const barColor = Color(0xFFE9F0F6);
    const foreground = Color(0xFF203E58);
    final keySuffix = '${event.title}:$startIndex-$endIndex';
    return Semantics(
      label: event.title,
      child: Container(
        key: ValueKey('academic-calendar-week-bar:$keySuffix'),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: showTitle ? 8 : 0),
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(startsBeforeWeek ? 2 : 6),
            right: Radius.circular(endsAfterWeek ? 2 : 6),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
        ),
        child: showTitle
            ? Text(
                event.title,
                key: ValueKey('academic-calendar-week-bar-title:$keySuffix'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSm.copyWith(
                  color: foreground,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _WeekSegment {
  const _WeekSegment({
    required this.event,
    required this.startIndex,
    required this.endIndex,
    required this.lane,
    required this.visibleDayCount,
    required this.startsBeforeWeek,
    required this.endsAfterWeek,
  });

  final AcademicCalendarEvent event;
  final int startIndex;
  final int endIndex;
  final int lane;
  final int visibleDayCount;
  final bool startsBeforeWeek;
  final bool endsAfterWeek;

  String get keySuffix => '${event.title}:$startIndex-$endIndex';
}

class _YearCalendarBody extends StatelessWidget {
  const _YearCalendarBody({required this.year, required this.events});

  final int year;
  final List<AcademicCalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final grouped = groupAcademicEventsByStartMonth(events);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var month = 1; month <= 12; month++) ...[
          _EventListCard(
            title: '$year년 $month월',
            events: grouped[month] ?? const <AcademicCalendarEvent>[],
            emptyText: '등록된 일정이 없어요',
            compactEmpty: true,
          ),
          if (month < 12) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _EventListCard extends StatelessWidget {
  const _EventListCard({
    required this.title,
    required this.events,
    required this.emptyText,
    this.compactEmpty = false,
  });

  final String title;
  final List<AcademicCalendarEvent> events;
  final String emptyText;
  final bool compactEmpty;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              if (events.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '${events.length}건',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          if (events.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: compactEmpty ? 8 : 22),
              child: Text(
                emptyText,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            for (var i = 0; i < events.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 16,
                  thickness: 0.6,
                  color: AppColors.outlineVariant.withValues(alpha: 0.42),
                ),
              _EventRow(event: events[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final AcademicCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 7),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: AppTypography.labelMd.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                event.dateLabel,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      child: Column(
        children: [
          Icon(
            Symbols.wifi_off,
            size: 32,
            color: AppColors.onSurfaceVariant,
            fill: 1,
          ),
          const SizedBox(height: 10),
          Text(
            '학사일정을 불러오지 못했어요',
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '네트워크 상태를 확인한 뒤 다시 시도해주세요.',
            textAlign: TextAlign.center,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Symbols.refresh, size: 17),
                  label: const Text('다시 시도'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(kAcademicCalendarUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Symbols.open_in_new, size: 17),
                  label: const Text('공식 페이지'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton({required this.mode});

  final AcademicCalendarMode mode;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == AcademicCalendarMode.month) ...[
            GlassCard(
              borderRadius: AppRadius.xl,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Expanded(child: ShimmerBox(height: 13)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 13)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 13)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 13)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 13)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 13)),
                      SizedBox(width: 8),
                      Expanded(child: ShimmerBox(height: 13)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 42,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 0.72,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemBuilder: (_, _) =>
                        const ShimmerBox(height: 64, radius: AppRadius.md),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (var i = 0; i < (mode == AcademicCalendarMode.month ? 1 : 5); i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == 4 ? 0 : 10),
              child: const _ListCardSkeleton(),
            ),
        ],
      ),
    );
  }
}

class _ListCardSkeleton extends StatelessWidget {
  const _ListCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerBox(width: 130, height: 16),
          SizedBox(height: 16),
          ShimmerBox(width: double.infinity, height: 13),
          SizedBox(height: 8),
          ShimmerBox(width: 190, height: 12),
          SizedBox(height: 14),
          ShimmerBox(width: double.infinity, height: 13),
          SizedBox(height: 8),
          ShimmerBox(width: 160, height: 12),
        ],
      ),
    );
  }
}

List<int> _yearOptions() {
  final current = DateTime.now().year;
  return [for (var year = current + 1; year >= current - 3; year--) year];
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
