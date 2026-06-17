import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/library/data/datasources/mock_library.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart'
    as libseat;
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';
import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';
import 'package:sejong_smart_campus/features/library/presentation/widgets/seat_card.dart';
import 'package:sejong_smart_campus/features/library/presentation/screens/library_room_screen.dart';
import 'package:sejong_smart_campus/features/library/presentation/screens/library_usage_history_screen.dart';

/// 학술정보원 열람실 진입 화면.
///
/// 구조:
///   - 글래스 앱바
///   - 활성 예약 카드 (홈의 SeatCard와 동일 디자인, 예약 있을 때만)
///   - 미반납 제재 배너 (미반납 N건 → LibraryPenaltyScreen)
///   - "열람실 선택" 섹션 + 6개 룸 카드
///   - "이용 내역" 섹션 + 최근 5건 + 전체 보기
class LibraryListScreen extends ConsumerStatefulWidget {
  const LibraryListScreen({super.key});

  @override
  ConsumerState<LibraryListScreen> createState() => _LibraryListScreenState();
}

class _LibraryListScreenState extends ConsumerState<LibraryListScreen> {
  // mock 제거 — libseat 실시간 (activeSeatReservationProvider) watch.
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_onRefresh(includeHistory: false));
    });
  }

  Future<void> _openRoom(BuildContext context, LibraryRoom room) async {
    // asset 좌표 + 배경 이미지 + libseat 실시간 상태 merge 화면으로 진입.
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(slideRoute(LibraryRoomScreen(room: room)));
    if (!mounted) return;
    unawaited(_onRefresh(includeHistory: false));
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(slideRoute(const LibraryUsageHistoryScreen()));
  }

  Future<void> _onRefresh({bool includeHistory = true}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    ref.invalidate(mySeatProvider);
    ref.invalidate(roomListProvider);
    if (includeHistory) ref.invalidate(seatUsageHistoryProvider);
    try {
      await Future.wait<void>([
        ref
            .read(libseatSyncProvider)
            .sync(
              reason: includeHistory
                  ? 'libraryListRefresh'
                  : 'libraryListEnter',
            )
            .then<void>((_) {}),
        ref.read(mySeatProvider.future).then<void>((_) {}),
        ref.read(roomListProvider.future).then<void>((_) {}),
        if (includeHistory)
          ref.read(seatUsageHistoryProvider.future).then<void>((_) {}),
      ]);
      if (!includeHistory) {
        ref.invalidate(seatUsageHistoryProvider);
        unawaited(
          ref
              .read(seatUsageHistoryProvider.future)
              .then<void>((_) {})
              .catchError((_) {}),
        );
      }
    } catch (_) {
      // Provider error state is rendered by each dependent widget.
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final history =
        ref.watch(seatUsageHistoryProvider).value ??
        const <LibraryUsageRecord>[];
    final unreturned = history
        .where((r) => r.status == LibraryUsageStatus.unreturned)
        .length;
    final activeReservation = ref.watch(activeSeatReservationProvider);
    final roomsAsync = ref.watch(roomListProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SejongRefresh(
              onRefresh: () => _onRefresh(),
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
                  if (activeReservation case final r?) ...[
                    SeatCard(
                      reservation: r,
                      onReturn: () => handleLibseatReturn(context, ref, r),
                      onExtend: () => handleLibseatExtend(context, ref, r),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _UsageHistoryEntryCard(
                    // 실 usageHistoryProvider (로컬 timeline) 카운트 사용.
                    // 이전에는 mock data(43건)로 표시되어 진입 화면(0건)과
                    // 불일치 — 사용자는 같은 source에서 같은 값을 봐야 함.
                    totalCount: history.length,
                    unreturnedCount: unreturned,
                    onTap: () => _openHistory(context),
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader(title: '열람실 선택', icon: Symbols.local_library),
                  const SizedBox(height: 10),
                  ..._roomCards(context, roomsAsync),
                  // 상단 _UsageHistoryEntryCard 하나로 진입 충분 — 하단
                  // 중복 "이용 내역" 섹션 제거. 전체 이력은 카드 탭 →
                  // _openHistory → LibraryUsageHistoryScreen.
                ],
              ),
            ),
            _LibraryListAppBar(
              title: '열람실',
              refreshing: _refreshing,
              onRefresh: () => _onRefresh(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _roomCards(
    BuildContext context,
    AsyncValue<List<libseat.ReadingRoom>> roomsAsync,
  ) {
    return roomsAsync.when(
      loading: () => [
        for (final room in libraryRooms) ...[
          _RoomCard(
            room: room,
            loading: true,
            onTap: () => _openRoom(context, room),
          ),
          const SizedBox(height: 12),
        ],
      ],
      error: (_, _) => [
        for (final room in libraryRooms) ...[
          _RoomCard(
            room: room,
            hasError: true,
            onTap: () => _openRoom(context, room),
          ),
          const SizedBox(height: 12),
        ],
      ],
      data: (rooms) {
        final summaries = {
          for (final room in libseat.mergeReadingRoomsByBase(rooms))
            room.name: room,
        };
        return [
          for (final room in libraryRooms) ...[
            _RoomCard(
              room: room,
              summary: summaries[room.shortLabel],
              onTap: () => _openRoom(context, room),
            ),
            const SizedBox(height: 12),
          ],
        ];
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;
  final Widget? trailing = null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: AppTypography.headlineMd.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _UsageHistoryEntryCard extends StatelessWidget {
  const _UsageHistoryEntryCard({
    required this.totalCount,
    required this.unreturnedCount,
    required this.onTap,
  });
  final int totalCount;
  final int unreturnedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          borderRadius: AppRadius.lg,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Symbols.history,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: AppTypography.headlineMd.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                        children: [
                          const TextSpan(text: '이용 내역 '),
                          TextSpan(
                            text: '$totalCount건',
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unreturnedCount > 0
                          ? '미반납 $unreturnedCount건 — 항목 탭으로 제재 사항 확인'
                          : '최근 이용 내역을 확인하세요',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Symbols.chevron_right,
                size: 22,
                color: AppColors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 한 줄짜리 이용 내역 row — 리스트 화면과 전체보기 화면 둘 다에서 사용.
class UsageHistoryRow extends StatelessWidget {
  const UsageHistoryRow({super.key, required this.record, this.onTap});
  final LibraryUsageRecord record;
  final VoidCallback? onTap;

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isPenalty = record.status.isPenalty;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 날짜 / 시간 column
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDate(record.startedAt),
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatTime(record.startedAt)}~${_formatTime(record.endedAt)}',
                  style: AppTypography.labelMd.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              record.roomLabel,
              style: AppTypography.labelMd.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: record.status.color.withValues(
                alpha: isPenalty ? 0.14 : 0.1,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: record.status.color.withValues(alpha: 0.3),
                width: 0.6,
              ),
            ),
            child: Text(
              record.status.label,
              style: TextStyle(
                color: record.status.color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(
              Symbols.chevron_right,
              size: 16,
              color: AppColors.outline.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: content,
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.onTap,
    this.summary,
    this.loading = false,
    this.hasError = false,
  });

  final LibraryRoom room;
  final VoidCallback onTap;
  final libseat.ReadingRoom? summary;
  final bool loading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final occupied = summary?.used;
    final total = summary?.total;
    final available = summary?.free;
    final ratio = summary?.usageRatio ?? 0.0;
    final unavailable = !loading && summary == null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          borderRadius: AppRadius.lg,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Symbols.local_library,
                          size: 22,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            room.name,
                            style: AppTypography.headlineMd.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (loading)
                          const Shimmer(
                            child: ShimmerBox(width: 118, height: 24),
                          )
                        else if (unavailable)
                          Text(
                            hasError ? '현황을 불러오지 못했어요' : '현황 준비 중',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          RichText(
                            text: TextSpan(
                              style: AppTypography.headlineMd.copyWith(
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: '$available',
                                  style: TextStyle(
                                    color: SeatStatus.available.color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 24,
                                  ),
                                ),
                                TextSpan(
                                  text: ' 자리 비어있음',
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        if (loading)
                          const Shimmer(
                            child: ShimmerBox(width: 54, height: 12),
                          )
                        else if (occupied != null && total != null)
                          Text(
                            '$occupied / $total',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: SizedBox(
                        height: 8,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                color: AppColors.surfaceContainerHigh,
                              ),
                            ),
                            if (loading)
                              const Positioned.fill(
                                child: Shimmer(
                                  child: ShimmerBox(radius: AppRadius.full),
                                ),
                              )
                            else
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: ratio.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.surfaceTint,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!room.hasSeatMap) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Symbols.info,
                            size: 14,
                            color: AppColors.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '좌석맵 준비 중 — 시연 모드',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.outline,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Symbols.chevron_right,
                  size: 22,
                  color: AppColors.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryListAppBar extends StatelessWidget {
  const _LibraryListAppBar({
    required this.title,
    required this.onRefresh,
    required this.refreshing,
  });

  final String title;
  final Future<void> Function() onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SejongSubAppBar(
        title: title,
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: refreshing
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: AppColors.secondary,
                    ),
                  )
                : const Icon(
                    Symbols.refresh,
                    color: AppColors.secondary,
                    size: 22,
                  ),
            onPressed: refreshing ? null : () => onRefresh(),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}
