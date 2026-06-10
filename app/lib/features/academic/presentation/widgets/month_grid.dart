import 'package:flutter/material.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';

/// 6주 × 7일 월간 그리드. 셀에 날짜 숫자 + 일정 있는 날 dot 하나.
///
/// 셀 높이는 parent의 폭/높이에서 자동 계산. (1:1 분할 화면에서 캘린더가
/// 위 절반을 차지하므로 cellH = (사용 가능 H - header) / 6.)
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.markedDays,
    required this.onSelect,
  });

  /// 1일로 normalize된 month.
  final DateTime month;
  final DateTime selected;

  /// 일정 있는 day-of-month(1~31). null이면 로딩 중(셀에 dot 안 그림).
  final Set<int>? markedDays;
  final ValueChanged<DateTime> onSelect;

  static const _weekKor = ['일', '월', '화', '수', '목', '금', '토'];
  static const _headerH = 28.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / 7;
        final cellH = ((constraints.maxHeight - _headerH - 4) / 6).clamp(
          48.0,
          96.0,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _headerH,
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    SizedBox(
                      width: cellW,
                      child: Center(
                        child: Text(
                          _weekKor[i],
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: i == 0
                                ? AppColors.primary
                                : i == 6
                                ? const Color(0xFF2E70D8)
                                : AppColors.onSurfaceVariant,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (var w = 0; w < 6; w++)
              SizedBox(
                height: cellH,
                child: Row(
                  children: [
                    for (var d = 0; d < 7; d++)
                      _DayCell(
                        date: _dayAt(week: w, weekday: d),
                        currentMonth: month.month,
                        selected: _sameDay(
                          _dayAt(week: w, weekday: d),
                          selected,
                        ),
                        hasMark:
                            markedDays != null &&
                            _dayAt(week: w, weekday: d).month == month.month &&
                            markedDays!.contains(
                              _dayAt(week: w, weekday: d).day,
                            ),
                        weekday: d,
                        width: cellW,
                        onTap: () => onSelect(_dayAt(week: w, weekday: d)),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// (week, weekday) → DateTime. weekday 0=일~6=토.
  DateTime _dayAt({required int week, required int weekday}) {
    final firstWeekday = month.weekday % 7;
    final offset = -firstWeekday + (week * 7) + weekday;
    return DateTime(month.year, month.month, 1 + offset);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.currentMonth,
    required this.selected,
    required this.hasMark,
    required this.weekday,
    required this.width,
    required this.onTap,
  });

  final DateTime date;
  final int currentMonth;
  final bool selected;
  final bool hasMark;
  final int weekday;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final inMonth = date.month == currentMonth;

    final Color textColor;
    if (!inMonth) {
      textColor = AppColors.onSurfaceVariant.withValues(alpha: 0.35);
    } else if (weekday == 0) {
      textColor = AppColors.primary;
    } else if (weekday == 6) {
      textColor = const Color(0xFF2E70D8);
    } else {
      textColor = AppColors.onSurface;
    }

    return SizedBox(
      width: width,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : null,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: selected
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.55),
                        width: 1.2,
                      )
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _DayNumber(
                    day: date.day,
                    textColor: textColor,
                    isToday: isToday && inMonth,
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 5,
                    child: hasMark
                        ? Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(
                                alpha: inMonth ? 0.95 : 0.35,
                              ),
                              shape: BoxShape.circle,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({
    required this.day,
    required this.textColor,
    required this.isToday,
  });
  final int day;
  final Color textColor;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    if (isToday) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: AppTypography.labelMd.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.onPrimary,
            height: 1.0,
          ),
        ),
      );
    }
    return Text(
      '$day',
      style: AppTypography.labelMd.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.0,
      ),
    );
  }
}
