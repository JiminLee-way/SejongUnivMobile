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

/// 시설 그룹의 룸×시간 grid 화면.
///
/// 컬럼 = 룸, 행 = 시간 (09:00~22:00). 셀은 예약가능(primary tint) /
/// 예약불가(gray). tap → 예약 confirm dialog → reserveFacilitySlot.
class FacilityMapScreen extends ConsumerWidget {
  const FacilityMapScreen({super.key, required this.group});
  final FacilityGroup group;

  Future<void> _onSlotTap(
    BuildContext context,
    WidgetRef ref,
    FacilitySlot slot,
  ) async {
    if (!slot.isReservable) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('예약할 수 없는 시간이에요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('예약하시겠어요?'),
        content: Text('${group.title}\n${slot.roomLabel} · ${slot.time}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('예약', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // 이 화면은 legacy 진입 경로 — 본인 1인 1시간 예약 기본.
    // 동반자/장시간 예약은 새 LibseatScreen 사용. sroomNo는 FacilitySlot에서.
    final r = await reserveFacilitySlot(
      ref,
      group: group,
      sroomNo: slot.sroomNo,
      roomLabel: slot.roomLabel,
      time: slot.time,
      durationHours: 1,
      companions: const [],
      date: DateTime.now(),
    );
    if (!context.mounted) return;
    await showLibseatResultDialog(context, r);
    if (!context.mounted) return;
    if (r.success) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final mapAsync = ref.watch(facilityMapProvider((group, DateTime.now())));
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: SejongRefresh(
                onRefresh: () async {
                  ref.invalidate(facilityMapProvider((group, DateTime.now())));
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                },
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
                    if (group.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          group.subtitle,
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    mapAsync.when(
                      loading: () => const _Loader(),
                      error: (_, _) => _ErrorBox(
                        message: '예약 현황을 불러오지 못했어요',
                        onRetry: () => ref.invalidate(
                          facilityMapProvider((group, DateTime.now())),
                        ),
                      ),
                      data: (m) => m.rooms.isEmpty
                          ? _Empty(category: group.category)
                          : _Grid(
                              map: m,
                              onTap: (s) => _onSlotTap(context, ref, s),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: _AppBar(group: group),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.group});
  final FacilityGroup group;
  @override
  Widget build(BuildContext context) {
    return SejongSubAppBar(
      title: group.title,
      titleSize: 17,
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '${group.seatCnt}인',
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.map, required this.onTap});
  final FacilityMap map;
  final ValueChanged<FacilitySlot> onTap;

  @override
  Widget build(BuildContext context) {
    final rooms = map.rooms;
    final times = map.times;
    if (rooms.isEmpty || times.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            '예약 정보가 없어요',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    // (roomLabel, time) → slot lookup
    final byKey = <String, FacilitySlot>{
      for (final s in map.slots) '${s.roomLabel}|${s.time}': s,
    };
    return GlassCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 — 시간 | 룸1 | 룸2 ...
          Row(
            children: [
              const SizedBox(
                width: 56,
                height: 32,
                child: Center(
                  child: Text(
                    '시간',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              for (final r in rooms)
                Expanded(
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    child: Text(
                      r,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 4, color: Color(0x11000000)),
          // 행 = 시간
          for (final t in times)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 30,
                    child: Center(
                      child: Text(
                        t,
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                  for (final r in rooms)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _Cell(
                          slot:
                              byKey['$r|$t'] ??
                              FacilitySlot(
                                roomLabel: r,
                                sroomNo: 0,
                                time: t,
                                status: SlotStatus.disabled,
                              ),
                          onTap: onTap,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.slot, required this.onTap});
  final FacilitySlot slot;
  final ValueChanged<FacilitySlot> onTap;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (slot.status) {
      SlotStatus.available => (
        const Color(0xFFE6F4EE),
        const Color(0xFF065F46),
      ),
      SlotStatus.reserved => (
        AppColors.outline.withValues(alpha: 0.18),
        AppColors.onSurfaceVariant,
      ),
      SlotStatus.disabled => (
        AppColors.outline.withValues(alpha: 0.08),
        AppColors.outline,
      ),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(slot),
        child: SizedBox(
          height: 30,
          child: Center(
            child: Text(
              slot.isReservable ? '○' : '·',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.category});
  final FacilityCategory category;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          '${category.label} 예약 정보가 없어요',
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
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
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Row(
        children: [
          const Icon(Symbols.error, fill: 1, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
