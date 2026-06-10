import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/home_widgets/presentation/providers/home_widgets_providers.dart';

/// 작은 날씨 chip — 홈 상단 어디든 배치 가능. 실패/로딩 시 빈 칸.
class WeatherChip extends ConsumerWidget {
  const WeatherChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weatherProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (w) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(w.weatherCondition),
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '${w.temperature} · ${w.weatherCondition}',
              style: AppTypography.labelSm.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String condition) {
    if (condition.contains('맑음')) return Symbols.wb_sunny;
    if (condition.contains('비')) return Symbols.umbrella;
    if (condition.contains('눈')) return Symbols.ac_unit;
    if (condition.contains('흐림') || condition.contains('구름')) {
      return Symbols.cloud;
    }
    return Symbols.partly_cloudy_day;
  }
}
