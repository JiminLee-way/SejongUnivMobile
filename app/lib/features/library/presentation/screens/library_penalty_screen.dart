import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';
import 'package:sejong_smart_campus/features/library/presentation/screens/library_list_screen.dart'
    show UsageHistoryRow;

const int kPenaltyDaysPerUnreturned = 1;

/// 미반납 누적 + 제재 정책 + 미반납 이력만 모아 보여주는 화면.
class LibraryPenaltyScreen extends ConsumerStatefulWidget {
  const LibraryPenaltyScreen({super.key});

  @override
  ConsumerState<LibraryPenaltyScreen> createState() =>
      _LibraryPenaltyScreenState();
}

class _LibraryPenaltyScreenState extends ConsumerState<LibraryPenaltyScreen> {
  Future<void> _onRefresh() async {
    try {
      await Future.wait<void>([
        Future<void>.delayed(const Duration(milliseconds: 300)),
        ref.refresh(seatUsageHistoryProvider.future),
      ]);
    } catch (_) {
      // Provider가 에러 상태를 화면에 렌더링한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final historyAsync = ref.watch(seatUsageHistoryProvider);
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
                children: _buildContent(historyAsync),
              ),
            ),
            const _PenaltyAppBar(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(
    AsyncValue<List<LibraryUsageRecord>> historyAsync,
  ) {
    if (historyAsync.isLoading && !historyAsync.hasValue) {
      return const [_PenaltySkeleton()];
    }

    if (historyAsync.hasError && !historyAsync.hasValue) {
      return [
        _PenaltyErrorCard(onRetry: _onRefresh),
        const SizedBox(height: 16),
        const _PolicyCard(),
      ];
    }

    final records = historyAsync.value ?? const <LibraryUsageRecord>[];
    final unreturned = records
        .where((r) => r.status == LibraryUsageStatus.unreturned)
        .toList();
    final days = unreturned.length * kPenaltyDaysPerUnreturned;

    return [
      _PenaltySummaryCard(
        unreturnedCount: unreturned.length,
        penaltyDays: days,
      ),
      const SizedBox(height: 16),
      const _PolicyCard(),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Row(
          children: [
            const Icon(
              Symbols.assignment_late,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '미반납 내역 ${unreturned.length}건',
              style: AppTypography.headlineMd.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      if (unreturned.isEmpty)
        const _PenaltyEmptyCard()
      else
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          borderRadius: AppRadius.lg,
          child: Column(
            children: [
              for (int i = 0; i < unreturned.length; i++) ...[
                UsageHistoryRow(record: unreturned[i]),
                if (i != unreturned.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      height: 1,
                      color: AppColors.onSurface.withValues(alpha: 0.06),
                    ),
                  ),
              ],
            ],
          ),
        ),
    ];
  }
}

class _PenaltySummaryCard extends StatelessWidget {
  const _PenaltySummaryCard({
    required this.unreturnedCount,
    required this.penaltyDays,
  });
  final int unreturnedCount;
  final int penaltyDays;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      borderRadius: AppRadius.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.surfaceTint],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Symbols.gavel, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '이용 정지',
                      style: AppTypography.headlineMd.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '학기 누적 미반납 기준',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _MetricColumn(
                  label: '미반납',
                  value: '$unreturnedCount',
                  unit: '건',
                  color: AppColors.primary,
                ),
              ),
              Container(
                width: 1,
                height: 56,
                color: AppColors.onSurface.withValues(alpha: 0.08),
              ),
              Expanded(
                child: _MetricColumn(
                  label: '누적 정지',
                  value: '$penaltyDays',
                  unit: '일',
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  final String label;
  final String value;
  final String unit;
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
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 30,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: unit,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard();

  @override
  Widget build(BuildContext context) {
    final policies = [
      ('이용 시간 종료 후 반납하지 않으면 미반납 1건이 누적됩니다.', Symbols.timer_off),
      ('미반납 1건당 24시간 좌석 예약이 정지됩니다.', Symbols.no_accounts),
      ('정지 기간 종료 후 자동 해제됩니다. 별도 신청은 필요 없습니다.', Symbols.history_toggle_off),
      ('연속 3회 미반납 시 학기 단위 이용 제한이 적용될 수 있습니다.', Symbols.warning),
    ];
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.policy, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '제재 정책',
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < policies.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  policies[i].$2,
                  size: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    policies[i].$1,
                    style: AppTypography.labelMd.copyWith(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (i != policies.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PenaltySkeleton extends StatelessWidget {
  const _PenaltySkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: const [
          _PenaltySummarySkeleton(),
          SizedBox(height: 16),
          _PenaltyPolicySkeleton(),
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: ShimmerBox(width: 120, height: 18, radius: 8),
          ),
          SizedBox(height: 8),
          _PenaltyListSkeleton(),
        ],
      ),
    );
  }
}

class _PenaltySummarySkeleton extends StatelessWidget {
  const _PenaltySummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      borderRadius: AppRadius.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              ShimmerBox(width: 44, height: 44, radius: AppRadius.md),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 100, height: 18, radius: 8),
                    SizedBox(height: 8),
                    ShimmerBox(width: 150, height: 12, radius: 6),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: ShimmerBox(height: 52, radius: AppRadius.md)),
              SizedBox(width: 14),
              Expanded(child: ShimmerBox(height: 52, radius: AppRadius.md)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PenaltyPolicySkeleton extends StatelessWidget {
  const _PenaltyPolicySkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerBox(width: 90, height: 18, radius: 8),
          SizedBox(height: 14),
          ShimmerBox(width: double.infinity, height: 14, radius: 7),
          SizedBox(height: 10),
          ShimmerBox(width: double.infinity, height: 14, radius: 7),
          SizedBox(height: 10),
          ShimmerBox(width: 260, height: 14, radius: 7),
        ],
      ),
    );
  }
}

class _PenaltyListSkeleton extends StatelessWidget {
  const _PenaltyListSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: AppRadius.lg,
      child: Column(
        children: const [
          _PenaltyHistorySkeletonRow(),
          SizedBox(height: 16),
          _PenaltyHistorySkeletonRow(),
          SizedBox(height: 16),
          _PenaltyHistorySkeletonRow(),
        ],
      ),
    );
  }
}

class _PenaltyHistorySkeletonRow extends StatelessWidget {
  const _PenaltyHistorySkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        ShimmerBox(width: 40, height: 40, radius: AppRadius.md),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerBox(width: 140, height: 16, radius: 8),
              SizedBox(height: 8),
              ShimmerBox(width: 210, height: 12, radius: 6),
            ],
          ),
        ),
        SizedBox(width: 12),
        ShimmerBox(width: 54, height: 24, radius: AppRadius.full),
      ],
    );
  }
}

class _PenaltyErrorCard extends StatelessWidget {
  const _PenaltyErrorCard({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      borderRadius: AppRadius.xl,
      child: Column(
        children: [
          Icon(
            Symbols.error,
            size: 34,
            color: AppColors.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 10),
          Text(
            '미반납 내역을 불러오지 못했어요',
            style: AppTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '네트워크 상태를 확인한 뒤 다시 시도해 주세요',
            textAlign: TextAlign.center,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Symbols.refresh, size: 18),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

class _PenaltyEmptyCard extends StatelessWidget {
  const _PenaltyEmptyCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      borderRadius: AppRadius.lg,
      child: Column(
        children: [
          Icon(
            Symbols.check_circle,
            size: 36,
            fill: 1,
            color: AppColors.secondary.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 10),
          Text(
            '미반납 내역이 없어요',
            style: AppTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '현재 열람실 이용 제재 대상이 아닙니다',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PenaltyAppBar extends StatelessWidget {
  const _PenaltyAppBar();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SejongSubAppBar(title: '미반납 제재'),
    );
  }
}
