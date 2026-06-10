import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';

/// 시간표 화면 / 친구 시간표 뷰어 / 공강 비교 화면이 공유하는 공용 위젯.
///
/// 가로축 = 요일 5열(`Weekday.values`), 세로축 = `startHour`~`endHour` 분 단위.
/// `Positioned`로 강의를 절대 좌표 배치. 디자인 토큰은 `[[design-system]]` 참조.

const int kTimetableDefaultStartHour = 9;
const int kTimetableDefaultEndHour = 19;
const double kTimetableHourHeight = 64;
const double kTimetableTimeAxisWidth = 32;
const double kTimetableHeaderHeight = 36;

// ─────────────────────────────────────────────────────────────────────────
// 학기 셀렉터 (가로 스크롤 글래스 칩)
// ─────────────────────────────────────────────────────────────────────────

class SemesterStrip extends StatelessWidget {
  const SemesterStrip({
    super.key,
    required this.selected,
    required this.onSelected,
    this.available,
  });

  final Semester selected;
  final ValueChanged<Semester> onSelected;

  /// 표시할 학기 집합. null이면 [Semester.values] 전체.
  /// 친구 시간표 뷰어에서 친구가 공개한 학기만 보여주는 용도.
  final Set<Semester>? available;

  @override
  Widget build(BuildContext context) {
    // 최신순 정렬 — spring2026 → winter2025 → fall2025 → … 사용자는 가장
    // 최근 학기를 먼저 보길 원함. Semester enum 순서는 시간순(과거→최신)이라
    // reverse 적용.
    final list =
        (available == null
                ? Semester.values.toList()
                : Semester.values.where(available!.contains).toList())
            .reversed
            .toList();
    return SizedBox(
      height: 64,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
        ),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = list[i];
          return Center(
            widthFactor: 1.0,
            child: SemesterChip(
              semester: s,
              selected: s == selected,
              onTap: () => onSelected(s),
            ),
          );
        },
      ),
    );
  }
}

class SemesterChip extends StatelessWidget {
  const SemesterChip({
    super.key,
    required this.semester,
    required this.selected,
    required this.onTap,
  });

  final Semester semester;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.full);
    final shadows = selected
        ? <BoxShadow>[
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.20),
              blurRadius: 10,
              spreadRadius: -1,
              offset: const Offset(0, 2),
            ),
          ]
        : const <BoxShadow>[
            BoxShadow(
              color: Color(0x142D3133),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color(0x0A2D3133),
              blurRadius: 6,
              spreadRadius: -1,
              offset: Offset(0, 2),
            ),
          ];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(borderRadius: radius, boxShadow: shadows),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.surface.withValues(alpha: 0.85),
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!semester.regular) ...[
                Icon(
                  Symbols.wb_sunny,
                  size: 14,
                  fill: 1,
                  color: selected ? AppColors.onPrimary : AppColors.outline,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                semester.label,
                style: AppTypography.labelMd.copyWith(
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 시간표 그리드
// ─────────────────────────────────────────────────────────────────────────

class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.timetable,
    this.startHour = kTimetableDefaultStartHour,
    this.endHour = kTimetableDefaultEndHour,
    this.hourHeight = kTimetableHourHeight,
    this.timeAxisWidth = kTimetableTimeAxisWidth,
    this.headerHeight = kTimetableHeaderHeight,
    this.onCourseTap,

    /// 강조 표시할 강의 코드(예: 내가 같이 듣는 강의) — 좌상단 ⭐ 배지가 붙는다.
    this.highlightCourseCodes,
  });

  final Timetable timetable;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double timeAxisWidth;
  final double headerHeight;
  final void Function(Course course)? onCourseTap;
  final Set<String>? highlightCourseCodes;

  @override
  Widget build(BuildContext context) {
    final totalHours = endHour - startHour;
    final totalHeight = headerHeight + hourHeight * totalHours;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dayColWidth =
              (constraints.maxWidth - timeAxisWidth) / Weekday.values.length;
          return SizedBox(
            height: totalHeight,
            child: Stack(
              children: [
                TimetableGridSkeleton(
                  startHour: startHour,
                  endHour: endHour,
                  hourHeight: hourHeight,
                  timeAxisWidth: timeAxisWidth,
                  headerHeight: headerHeight,
                  dayColWidth: dayColWidth,
                ),
                Positioned(
                  top: 0,
                  left: timeAxisWidth,
                  right: 0,
                  height: headerHeight,
                  child: Row(
                    children: [
                      for (final w in Weekday.values)
                        Expanded(child: _DayHeaderCell(weekday: w)),
                    ],
                  ),
                ),
                for (final course in timetable.courses)
                  for (final t in course.times)
                    CourseBlock(
                      course: course,
                      time: t,
                      startHour: startHour,
                      hourHeight: hourHeight,
                      headerHeight: headerHeight,
                      timeAxisWidth: timeAxisWidth,
                      dayColWidth: dayColWidth,
                      highlighted:
                          highlightCourseCodes?.contains(course.code) ?? false,
                      onTap: onCourseTap == null
                          ? null
                          : () => onCourseTap!(course),
                    ),
                if (timetable.courses.isEmpty)
                  Positioned.fill(
                    top: headerHeight,
                    child: TimetableEmptyState(semester: timetable.semester),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class TimetableGridSkeleton extends StatelessWidget {
  const TimetableGridSkeleton({
    super.key,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.timeAxisWidth,
    required this.headerHeight,
    required this.dayColWidth,
  });

  final int startHour;
  final int endHour;
  final double hourHeight;
  final double timeAxisWidth;
  final double headerHeight;
  final double dayColWidth;

  @override
  Widget build(BuildContext context) {
    final totalHours = endHour - startHour;
    final divider = AppColors.outlineVariant.withValues(alpha: 0.4);
    return Stack(
      children: [
        for (var i = 0; i <= totalHours; i++)
          Positioned(
            left: 0,
            top: headerHeight + i * hourHeight - 8,
            width: timeAxisWidth - 4,
            child: Text(
              (startHour + i).toString().padLeft(2, '0'),
              textAlign: TextAlign.right,
              style: AppTypography.labelSm.copyWith(
                fontSize: 10,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        for (var i = 0; i <= totalHours; i++)
          Positioned(
            left: timeAxisWidth,
            right: 0,
            top: headerHeight + i * hourHeight,
            height: 1,
            child: Container(color: divider),
          ),
        for (var i = 1; i < Weekday.values.length; i++)
          Positioned(
            top: headerHeight,
            bottom: 0,
            left: timeAxisWidth + dayColWidth * i,
            width: 1,
            child: Container(color: divider),
          ),
        Positioned(
          left: timeAxisWidth,
          right: 0,
          top: headerHeight - 1,
          height: 1,
          child: Container(
            color: AppColors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _DayHeaderCell extends StatelessWidget {
  const _DayHeaderCell({required this.weekday});
  final Weekday weekday;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        weekday.label,
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

class CourseBlock extends StatelessWidget {
  const CourseBlock({
    super.key,
    required this.course,
    required this.time,
    required this.startHour,
    required this.hourHeight,
    required this.headerHeight,
    required this.timeAxisWidth,
    required this.dayColWidth,
    this.onTap,
    this.highlighted = false,
  });

  final Course course;
  final CourseTime time;
  final int startHour;
  final double hourHeight;
  final double headerHeight;
  final double timeAxisWidth;
  final double dayColWidth;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final top =
        headerHeight + time.start.minutesFrom(startHour) / 60.0 * hourHeight;
    final height = time.durationMinutes / 60.0 * hourHeight;
    final left = timeAxisWidth + dayColWidth * time.weekday.index;
    final color = course.palette.color;

    final showLocation = height >= 48;
    final showProfessor = height >= 92;
    final nameMaxLines = height >= 72 ? 2 : 1;

    return Positioned(
      top: top + 2,
      left: left + 1,
      width: dayColWidth - 2,
      height: height - 4,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: color.withValues(alpha: 0.40),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 3, color: color),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.name,
                              maxLines: nameMaxLines,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              style: AppTypography.labelMd.copyWith(
                                fontSize: 11.5,
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                                letterSpacing: -0.1,
                              ),
                            ),
                            if (showLocation) ...[
                              const SizedBox(height: 3),
                              Text(
                                course.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 10,
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                  height: 1.1,
                                ),
                              ),
                            ],
                            if (showProfessor) ...[
                              const Spacer(),
                              Text(
                                course.professor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 10,
                                  color: AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (highlighted)
                  Positioned(
                    right: 3,
                    top: 5,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Symbols.star,
                        size: 10,
                        fill: 1,
                        color: Colors.white,
                      ),
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

class TimetableEmptyState extends StatelessWidget {
  const TimetableEmptyState({super.key, required this.semester});
  final Semester semester;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.event_busy,
            size: 36,
            color: AppColors.outline.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(
            '${semester.label} 시간표가 비어 있어요',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '수강신청 후 자동으로 동기화돼요',
            style: AppTypography.labelSm.copyWith(
              fontSize: 11,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
