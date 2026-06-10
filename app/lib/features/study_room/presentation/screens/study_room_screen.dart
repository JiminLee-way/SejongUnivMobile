import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/study_room/presentation/providers/study_room_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';

enum StudyRoomTab { status, reservations }

class StudyRoomScreen extends ConsumerStatefulWidget {
  const StudyRoomScreen({super.key, this.initial = StudyRoomTab.status});
  final StudyRoomTab initial;
  @override
  ConsumerState<StudyRoomScreen> createState() => _StudyRoomScreenState();
}

class _StudyRoomScreenState extends ConsumerState<StudyRoomScreen> {
  late StudyRoomTab _tab = widget.initial;

  Future<void> _onRefresh() async {
    if (_tab == StudyRoomTab.status) {
      ref.invalidate(studyRoomStatusProvider);
    } else {
      ref.invalidate(myStudyRoomReservationsProvider);
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
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
                    top: mq.padding.top + 64 + 16,
                    left: AppSpacing.marginMobile,
                    right: AppSpacing.marginMobile,
                    bottom: 120 + mq.padding.bottom,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    _TabStrip(
                      selected: _tab,
                      onSelected: (t) => setState(() => _tab = t),
                    ),
                    const SizedBox(height: 12),
                    if (_tab == StudyRoomTab.status)
                      const _StatusBody()
                    else
                      const _ReservationsBody(),
                  ],
                ),
              ),
            ),
            const Align(alignment: Alignment.topCenter, child: _AppBar()),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar();
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: top + 64,
      padding: EdgeInsets.only(top: top, left: 8, right: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Symbols.arrow_back, color: AppColors.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            '스터디룸',
            style: AppTypography.headlineMd.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selected, required this.onSelected});
  final StudyRoomTab selected;
  final ValueChanged<StudyRoomTab> onSelected;
  @override
  Widget build(BuildContext context) {
    String labelOf(StudyRoomTab t) => t == StudyRoomTab.status ? '현황' : '내 예약';
    return Row(
      children: [
        for (final t in StudyRoomTab.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => onSelected(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: t == selected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: t == selected
                          ? AppColors.primary
                          : AppColors.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    labelOf(t),
                    style: AppTypography.labelMd.copyWith(
                      color: t == selected
                          ? AppColors.onPrimary
                          : AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusBody extends ConsumerWidget {
  const _StatusBody();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studyRoomStatusProvider);
    return async.when(
      loading: () => const _CenterSpinner(),
      error: (_, _) => const _EmptyBox(text: '스터디룸 현황을 불러오지 못했어요'),
      data: (rooms) {
        if (rooms.isEmpty) {
          return const _EmptyBox(text: '운영 중인 스터디룸이 없어요');
        }
        final available = rooms.where((r) => !r.isFull).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              borderRadius: AppRadius.xl,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(
                children: [
                  const Icon(
                    Symbols.door_open,
                    size: 22,
                    color: AppColors.primary,
                    fill: 1,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '예약 가능 ',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$available',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    ' / ${rooms.length} 룸',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final r in rooms) ...[
              GlassCard(
                borderRadius: AppRadius.lg,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: r.isFull
                            ? AppColors.outline.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        r.isFull ? Symbols.lock : Symbols.event_available,
                        size: 18,
                        color: r.isFull ? AppColors.outline : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.roomName,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Stack(
                            children: [
                              Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh
                                      .withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(2.5),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: r.availabilityRatio,
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: r.isFull
                                        ? AppColors.outline
                                        : AppColors.primary,
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          r.isFull ? '만실' : '${r.remainingTime}분',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w800,
                            color: r.isFull
                                ? AppColors.outline
                                : AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '총 ${r.total}',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _ReservationsBody extends ConsumerWidget {
  const _ReservationsBody();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myStudyRoomReservationsProvider);
    return async.when(
      loading: () => const _CenterSpinner(),
      error: (_, _) => const _EmptyBox(text: '예약 내역을 불러오지 못했어요'),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyBox(text: '예약 내역이 없어요');
        }
        return Column(
          children: [
            for (final r in list) ...[
              GlassCard(
                borderRadius: AppRadius.lg,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.roomName,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.prettyDate,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _colorFor(r.status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        r.status,
                        style: AppTypography.labelSm.copyWith(
                          color: _colorFor(r.status),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  Color _colorFor(String status) {
    if (status.contains('취소')) return AppColors.outline;
    if (status.contains('만료')) return AppColors.outline;
    if (status.contains('승인') || status.contains('완료')) {
      return AppColors.primary;
    }
    return AppColors.onSurfaceVariant;
  }
}

class _CenterSpinner extends StatelessWidget {
  const _CenterSpinner();
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

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Text(
        text,
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
