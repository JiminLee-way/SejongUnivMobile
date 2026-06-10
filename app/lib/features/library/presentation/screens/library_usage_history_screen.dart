import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';
import 'package:sejong_smart_campus/features/library/presentation/screens/library_list_screen.dart'
    show UsageHistoryRow;
import 'package:sejong_smart_campus/features/library/presentation/screens/library_penalty_screen.dart';

/// 전체 이용 내역 — 월 단위로 그룹핑. 로컬 timeline 기반(usageHistoryProvider).
class LibraryUsageHistoryScreen extends ConsumerStatefulWidget {
  const LibraryUsageHistoryScreen({super.key});

  @override
  ConsumerState<LibraryUsageHistoryScreen> createState() =>
      _LibraryUsageHistoryScreenState();
}

class _LibraryUsageHistoryScreenState
    extends ConsumerState<LibraryUsageHistoryScreen> {
  Future<void> _onRefresh() async {
    ref.invalidate(seatUsageHistoryProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final historyAsync = ref.watch(seatUsageHistoryProvider);
    final records = historyAsync.value ?? const <LibraryUsageRecord>[];
    // 월별 그룹핑 (최신순 그대로).
    final groups = <String, List<LibraryUsageRecord>>{};
    for (final r in records) {
      final key =
          '${r.startedAt.year}.${r.startedAt.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(r);
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SejongRefresh(
              onRefresh: _onRefresh,
              topInset: topPad + 64,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.marginMobile,
                  topPad + 64 + 8,
                  AppSpacing.marginMobile,
                  bottomPad + 24,
                ),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  _StatsCard(records: records),
                  const SizedBox(height: 16),
                  if (records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          '이용 내역이 없어요',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 2,
                        top: 4,
                        bottom: 6,
                      ),
                      child: Row(
                        children: [
                          Text(
                            entry.key,
                            style: AppTypography.headlineMd.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${entry.value.length}건',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      borderRadius: AppRadius.lg,
                      child: Column(
                        children: [
                          for (int i = 0; i < entry.value.length; i++) ...[
                            UsageHistoryRow(
                              record: entry.value[i],
                              onTap: entry.value[i].status.isPenalty
                                  ? () => Navigator.of(context).push(
                                      slideRoute(const LibraryPenaltyScreen()),
                                    )
                                  : null,
                            ),
                            if (i != entry.value.length - 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Container(
                                  height: 1,
                                  color: AppColors.onSurface.withValues(
                                    alpha: 0.06,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const _HistoryAppBar(),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.records});
  final List<LibraryUsageRecord> records;

  @override
  Widget build(BuildContext context) {
    final completed = records
        .where((r) => r.status == LibraryUsageStatus.completed)
        .length;
    final unreturned = records
        .where((r) => r.status == LibraryUsageStatus.unreturned)
        .length;
    final total = records.length;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      borderRadius: AppRadius.lg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _StatCol(
              label: '전체',
              value: '$total',
              color: AppColors.onSurface,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.onSurface.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _StatCol(
              label: '사용완료',
              value: '$completed',
              color: AppColors.secondary,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.onSurface.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _StatCol(
              label: '미반납',
              value: '$unreturned',
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _HistoryAppBar extends StatelessWidget {
  const _HistoryAppBar();
  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SejongSubAppBar(title: '이용 내역'),
    );
  }
}
