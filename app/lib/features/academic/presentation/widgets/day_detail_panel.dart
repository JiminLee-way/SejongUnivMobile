import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/academic_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';

/// 선택된 날짜의 일정 detail — 공식 학사일정 + 학생 일정 두 섹션.
/// dedup된 [CalendarItemGroup]을 카드로 렌더, divisions는 chip strip.
///
/// 날짜 header는 외부(시트 sticky header)에서 그리므로 여기서는 섹션만.
class DayDetailPanel extends ConsumerWidget {
  const DayDetailPanel({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final official = ref.watch(filteredDailyCalendarProvider(date));
    final student = ref.watch(filteredStudentDailyProvider(date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(icon: Symbols.event, title: '학교 학사일정', async: official),
        const SizedBox(height: 12),
        _Section(icon: Symbols.school, title: '내 일정', async: student),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.async,
  });
  final IconData icon;
  final String title;
  final AsyncValue<List<CalendarItemGroup>> async;

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
              Icon(icon, size: 18, color: AppColors.primary, fill: 1),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              async.maybeWhen(
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${items.length}건',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const _Loading(),
            error: (_, _) => const _Empty(text: '불러오지 못했어요'),
            data: (items) {
              if (items.isEmpty) {
                return const _Empty(text: '해당 날짜에 일정이 없어요');
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 14,
                        thickness: 0.5,
                        color: AppColors.outlineVariant.withValues(alpha: 0.35),
                      ),
                    _GroupRow(group: items[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group});
  final CalendarItemGroup group;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 6,
          height: 6,
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
                group.subject,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.35,
                  color: AppColors.onSurface,
                ),
              ),
              if (group.dateLabel.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  group.dateLabel,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (group.tms != null && group.tms!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  group.tms!,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
              if (group.divisions.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DivisionChips(divisions: group.divisions),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DivisionChips extends StatelessWidget {
  const _DivisionChips({required this.divisions});
  final List<String> divisions;

  static const int _visibleMax = 3;

  @override
  Widget build(BuildContext context) {
    final visible = divisions.take(_visibleMax).toList();
    final overflow = divisions.length - visible.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in visible) _Chip(text: d),
        if (overflow > 0) _Chip(text: '+$overflow', subtle: true),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.subtle = false});
  final String text;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: subtle
            ? AppColors.surfaceContainerHigh
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: subtle
              ? AppColors.outline.withValues(alpha: 0.18)
              : AppColors.primary.withValues(alpha: 0.30),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: AppTypography.labelSm.copyWith(
          color: subtle ? AppColors.onSurfaceVariant : AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          text,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
