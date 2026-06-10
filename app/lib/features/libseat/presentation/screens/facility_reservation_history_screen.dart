import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/facility_models.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

/// 내 시설 예약 내역 — mySeat.php의 스터디룸/시네마룸/S-Lounge 탭만.
///
/// 카테고리 필터 chips + 카드 list. 활성 예약은 우측에 취소 버튼.
class FacilityReservationHistoryScreen extends ConsumerStatefulWidget {
  const FacilityReservationHistoryScreen({super.key});

  @override
  ConsumerState<FacilityReservationHistoryScreen> createState() =>
      _FacilityReservationHistoryScreenState();
}

class _FacilityReservationHistoryScreenState
    extends ConsumerState<FacilityReservationHistoryScreen> {
  FacilityCategory? _filter;

  Future<void> _onRefresh() async {
    ref.invalidate(myFacilityReservationsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _cancel(FacilityReservation r) async {
    final no = r.reserveNo;
    if (no == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('예약번호를 확인할 수 없어요. 학술정보원 홈페이지에서 취소해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('예약을 취소하시겠어요?'),
        content: Text(
          '${r.roomLabel}\n${r.date.year}.${r.date.month.toString().padLeft(2, '0')}.${r.date.day.toString().padLeft(2, '0')} ${r.timeLabel}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('취소', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await cancelMyFacilityReservation(ref, reserveNo: no);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message.isEmpty
              ? (result.success ? '취소되었어요' : '취소하지 못했어요')
              : result.message,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final async = ref.watch(myFacilityReservationsProvider);
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
                    top: mq.padding.top + 64 + 12,
                    left: AppSpacing.marginMobile,
                    right: AppSpacing.marginMobile,
                    bottom: 120 + mq.padding.bottom,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    _FilterChips(
                      current: _filter,
                      onChanged: (c) => setState(() => _filter = c),
                    ),
                    const SizedBox(height: 14),
                    async.when(
                      loading: () => const _Loader(),
                      error: (_, _) => _ErrorBox(
                        message: '예약 내역을 불러오지 못했어요',
                        onRetry: () =>
                            ref.invalidate(myFacilityReservationsProvider),
                      ),
                      data: (list) {
                        final filtered = _filter == null
                            ? list
                            : list.where((r) => r.category == _filter).toList();
                        if (filtered.isEmpty) {
                          return _Empty(category: _filter);
                        }
                        return Column(
                          children: [
                            for (final r in filtered) ...[
                              _ReservationCard(
                                reservation: r,
                                onCancel: () => _cancel(r),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: _HistoryAppBar(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryAppBar extends StatelessWidget {
  const _HistoryAppBar();
  @override
  Widget build(BuildContext context) {
    return const SejongSubAppBar(title: '시설 예약 내역');
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.current, required this.onChanged});
  final FacilityCategory? current;
  final ValueChanged<FacilityCategory?> onChanged;
  @override
  Widget build(BuildContext context) {
    final items = <(FacilityCategory?, String)>[
      (null, '전체'),
      (FacilityCategory.studyRoom, '스터디룸'),
      (FacilityCategory.cinema, '시네마룸'),
      (FacilityCategory.sLounge, 'S-Lounge'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (cat, label) in items)
          _chip(
            label: label,
            selected: current == cat,
            onTap: () => onChanged(cat),
          ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: selected ? Colors.white : AppColors.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation, required this.onCancel});
  final FacilityReservation reservation;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return GlassCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _CategoryBadge(category: r.category),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.roomLabel,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              _StatusBadge(kind: r.statusKind, label: r.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Symbols.calendar_today,
                size: 14,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '${r.date.year}.${r.date.month.toString().padLeft(2, '0')}.${r.date.day.toString().padLeft(2, '0')}',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Symbols.schedule,
                size: 14,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                r.timeLabel,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (r.isActive && r.reserveNo != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  textStyle: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                child: const Text('예약 취소'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final FacilityCategory category;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        category.label,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.kind, required this.label});
  final FacilityReservationStatusKind kind;
  final String label;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      FacilityReservationStatusKind.upcoming => (
        AppColors.primary.withValues(alpha: 0.12),
        AppColors.primary,
      ),
      FacilityReservationStatusKind.inUse => (
        const Color(0xFFFFEFD5),
        const Color(0xFFB45309),
      ),
      FacilityReservationStatusKind.completed => (
        const Color(0xFFE6F4EE),
        const Color(0xFF065F46),
      ),
      FacilityReservationStatusKind.cancelled => (
        AppColors.outline.withValues(alpha: 0.18),
        AppColors.onSurfaceVariant,
      ),
      FacilityReservationStatusKind.noShow => (
        const Color(0xFFFCA5A5).withValues(alpha: 0.35),
        const Color(0xFFB91C1C),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.category});
  final FacilityCategory? category;
  @override
  Widget build(BuildContext context) {
    final label = category == null ? '' : '${category!.label} ';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Symbols.event_busy,
              size: 32,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              '${label}예약 내역이 없어요',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(
            Symbols.error,
            fill: 1,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
