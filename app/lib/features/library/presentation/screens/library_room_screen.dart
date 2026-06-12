import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart'
    as libseat;
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/shell/presentation/screens/app_shell.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/features/library/presentation/widgets/seat_map.dart';

/// 단일 열람실 좌석 현황 화면.
///
/// **레이아웃(좌표 + 배경)** = asset (`assets/library/room_NN_seats.json` +
/// `map_NN.jpg`). 사용자가 직접 픽셀 단위로 정렬해 만든 자산을 그대로 사용.
/// **상태(available/used/fixed/disabled)** = libseat 실 API (`seatMapProvider`).
/// 두 데이터를 seat id 기준으로 merge.
///
/// 사용자는 InteractiveViewer로 핀치줌 / 팬해서 좌석을 탭 → 하단 글래스
/// 시트에 좌석 정보 + "예약하기" CTA. 예약은 `reserveLibseat` 호출.
class LibraryRoomScreen extends ConsumerStatefulWidget {
  const LibraryRoomScreen({super.key, required this.room});
  final LibraryRoom room;

  @override
  ConsumerState<LibraryRoomScreen> createState() => _LibraryRoomScreenState();
}

class _LibraryRoomScreenState extends ConsumerState<LibraryRoomScreen> {
  late Future<RoomData> _roomFuture;
  int? _selectedSeatId;
  bool _busy = false;

  /// 새로고침 진행 중 — 앱바 아이콘을 스피너로 바꿔 "진짜 갱신 중"임을 보여줌.
  bool _refreshing = false;

  /// 좌석 id → wing(A/B). 통합 열람실(1112/1516)에서 예약 시 실 room_no를
  /// 복원하기 위해 asset 로드 직후 채운다. 단일 열람실은 값이 모두 null.
  Map<int, String?> _wingById = const {};

  @override
  void initState() {
    super.initState();
    _roomFuture = RoomLayout.loadFromAsset(roomNo: widget.room.roomNo);
    _roomFuture.then((data) {
      if (!mounted) return;
      _wingById = {for (final s in data.layout.seats) s.id: s.wing};
    });
    // 진입 시점 강제 새로고침 — 사용자가 list 화면을 한참 켜놓고 들어와도
    // 좌석맵·열람실 합산 모두 latest. ref.invalidate는 InheritedWidget을
    // 건드리므로 initState 본문에서 직접 호출 시 framework 에러 발생.
    // postFrameCallback로 첫 frame 직후에 실행 → 실 HTTP fetch
    // (`GET /seatMap.php`, `GET /roomList.php`) 즉시 트리거. 첫 frame에 잠깐
    // cached value 보이지만 16ms 뒤 새 fetch 결과로 교체.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  /// 좌석맵 강제 새로고침 — 진입 시점 + 우측 상단 새로고침 버튼 공용 경로.
  ///
  /// 통합 열람실(제1=1112/제4=1516)은 가상 ID라 `seatMapProvider(1112)`가 빈
  /// 응답이므로, 실제 두 wing room_no(11·12 / 15·16)를 각각 invalidate해야
  /// 라이브 재조회가 일어난다. `seatMapForRoomProvider`가 이를 합산해 watch 중.
  ///
  /// [showToast]가 true면(버튼 탭) 실제 재조회 완료까지 기다렸다가 스낵바로
  /// "갱신됨"을 알려 — invalidate만 하면 값이 같을 때 화면 변화가 없어 사용자가
  /// 동작 여부를 알 수 없는 문제 해결.
  Future<void> _refresh({bool showToast = false}) async {
    if (_refreshing) return;
    if (showToast) {
      HapticFeedback.selectionClick();
      setState(() => _refreshing = true);
    }
    for (final rn in libseatRealRoomNos(widget.room.roomNo)) {
      ref.invalidate(seatMapProvider(rn));
    }
    ref.invalidate(roomListProvider);
    // ignore: avoid_print
    print(
      '[LIBSEAT] seatMap refresh room=${widget.room.roomNo} '
      'reals=${libseatRealRoomNos(widget.room.roomNo)}',
    );
    if (!showToast) return;
    // 실제 HTTP 재조회 완료까지 대기 → "진짜 새로고침됐다" 신호.
    try {
      await ref.read(seatMapForRoomProvider(widget.room.roomNo).future);
      await ref.read(roomListProvider.future);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _refreshing = false);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('최신 좌석 정보로 업데이트했어요'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1400),
        ),
      );
  }

  /// asset 기본 상태 + libseat 실 상태 merge.
  /// libseat이 보낸 seatNo(string) → int parse → asset id와 매핑.
  /// libseat에 없는 좌석은 asset 기본 상태 유지(거의 unavailable일 것).
  /// live 데이터가 신뢰할 수 없을 때(CSS 파싱 깨짐) base asset으로 fallback.
  ///
  /// libseat이 occupied seat class를 변경하면 fetchSeatMap이 전 좌석을
  /// available로 반환한다. [expectedAvailable]은 roomListProvider의 합산값으로,
  /// live의 available 비율이 expected 대비 30%p 이상 높으면 파싱이 깨진 것으로
  /// 판단해 base를 그대로 반환.
  SeatStatusMap _mergeStatuses(
    SeatStatusMap base,
    List<libseat.Seat> live, {
    int? expectedAvailable,
  }) {
    if (live.isEmpty) return base;
    if (expectedAvailable != null && base.isNotEmpty) {
      final liveAvailable = live
          .where((s) => s.status == libseat.SeatStatus.available)
          .length;
      final liveRatio = liveAvailable / base.length;
      final expectedRatio = expectedAvailable / base.length;
      if (liveRatio - expectedRatio > 0.30) return base;
    }
    final m = Map<int, SeatStatus>.from(base);
    for (final s in live) {
      final id = int.tryParse(s.seatNo);
      if (id == null) continue;
      m[id] = switch (s.status) {
        libseat.SeatStatus.available => SeatStatus.available,
        libseat.SeatStatus.used => SeatStatus.occupied,
        libseat.SeatStatus.fixed => SeatStatus.fixed,
        libseat.SeatStatus.disabled => SeatStatus.unavailable,
      };
    }
    return m;
  }

  int _occupiedOf(SeatStatusMap m) => m.values
      .where((s) => s == SeatStatus.occupied || s == SeatStatus.fixed)
      .length;

  void _onSeatTap(int id) {
    setState(() {
      _selectedSeatId = _selectedSeatId == id ? null : id;
    });
  }

  void _dismissSheet() {
    setState(() => _selectedSeatId = null);
  }

  Future<void> _reserveSelectedSeat() async {
    final id = _selectedSeatId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    // 통합 열람실(제1=1112/제4=1516)은 가상 ID라 그대로 보내면 서버가 "자율
    // 발권으로 모바일 좌석 예약을 이용하실 수 없습니다."로 거절 → 좌석 wing으로
    // 실 room_no(11/12/15/16)를 복원해 호출. 단일 열람실은 그대로 통과.
    final realRoomNo = resolveLibseatRoomNo(widget.room.roomNo, _wingById[id]);
    final r = await reserveLibseat(
      ref,
      roomNo: realRoomNo,
      seatNo: '$id',
      roomName: widget.room.name,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.success) _selectedSeatId = null;
    });
    await showLibseatResultDialog(context, r);
    if (!mounted) return;
    if (r.success) {
      // 예약 완료 → 메인화면(홈 탭)으로 보냄. LibraryList/Room은 root navigator
      // 위에 push된 풀스크린이라 popUntil(isFirst)로 AppShell을 드러낸다. 단
      // AppShell의 inner 탭은 마지막 선택값(드로어로 비-홈 탭에서 진입 가능)이라
      // popUntil만으로는 홈이 아닐 수 있음 → switchTab(0)으로 홈 강제(홈에서
      // 왔으면 inner pop만 해 무해). 홈 열람실 카드는 seatOverride로 즉시 노출.
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
      AppShell.instance?.switchTab(0);
    }
  }

  /// libseat roomList 응답에서 shortLabel(예: "제2열람실")과 일치하는 A/B 두
  /// entry 합산 used/total. mock LibraryRoom.roomNo는 1112 같은 합산 ID라
  /// seatMapProvider가 빈 list 반환하기도 함 → 헤더 게이지는 roomList의
  /// 신뢰 가능한 값으로 직접 계산. (홈 위젯과 동일 source라 일관성 보장)
  (int used, int total)? _summaryFromRoomList(
    List<libseat.ReadingRoom> rooms,
    String shortLabel,
  ) {
    for (final room in libseat.mergeReadingRoomsByBase(rooms)) {
      if (room.name == shortLabel) return (room.used, room.total);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    // libseat 실시간 좌석 상태 — asset 기본값과 merge.
    final liveAsync = ref.watch(seatMapForRoomProvider(widget.room.roomNo));
    // 헤더 게이지/숫자는 roomList의 합산 값 사용 (mock의 합산 roomNo는
    // seatMapProvider가 빈 list 반환할 수 있어 occupied=0으로 표시되는 버그
    // 회피). roomList loading/error 시는 좌석맵 occupied로 fallback.
    final roomListAsync = ref.watch(roomListProvider);
    final summary = roomListAsync.value == null
        ? null
        : _summaryFromRoomList(roomListAsync.value!, widget.room.shortLabel);
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: FutureBuilder<RoomData>(
          future: _roomFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: snapshot.hasError
                    ? _ErrorState(error: snapshot.error)
                    : const CircularProgressIndicator(color: AppColors.primary),
              );
            }
            final layout = snapshot.data!.layout;
            final base = snapshot.data!.statuses;
            final expectedAvailable = summary != null
                ? summary.$2 - summary.$1
                : null;
            final statuses = _mergeStatuses(
              base,
              liveAsync.value ?? const [],
              expectedAvailable: expectedAvailable,
            );
            // 헤더 표시: roomList 합산값 우선 (정확). 없으면 좌석맵 fallback.
            final headerTotal = summary?.$2 ?? layout.seats.length;
            final headerOccupied = summary?.$1 ?? _occupiedOf(statuses);
            final selectedSeat = _selectedSeatId == null
                ? null
                : layout.seats.firstWhere(
                    (s) => s.id == _selectedSeatId,
                    orElse: () => layout.seats.first,
                  );
            final selectedStatus = _selectedSeatId == null
                ? null
                : (statuses[_selectedSeatId] ?? SeatStatus.unavailable);
            return Stack(
              children: [
                Column(
                  children: [
                    // ↓ 글래스 앱바 자리.
                    SizedBox(height: topPad + 64),
                    // ↓ 헤더 카드.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.marginMobile,
                        8,
                        AppSpacing.marginMobile,
                        12,
                      ),
                      child: GlassCard(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        borderRadius: AppRadius.lg,
                        child: RoomHeader(
                          name: widget.room.name,
                          occupied: headerOccupied,
                          total: headerTotal,
                        ),
                      ),
                    ),
                    // ↓ 좌석맵 (남는 영역 전부).
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: AppSpacing.gutterMobile,
                          right: AppSpacing.gutterMobile,
                          bottom: bottomPad + 16,
                        ),
                        child: GlassCard(
                          padding: EdgeInsets.zero,
                          borderRadius: AppRadius.lg,
                          child: SeatMap(
                            layout: layout,
                            statuses: statuses,
                            selectedSeatId: _selectedSeatId,
                            onSeatTap: _onSeatTap,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                _LibraryAppBar(
                  title: '열람실',
                  refreshing: _refreshing,
                  onRefresh: () => _refresh(showToast: true),
                ),
                if (selectedSeat != null && selectedStatus != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _SelectedSeatSheet(
                      seatId: selectedSeat.id,
                      status: selectedStatus,
                      roomLabel: widget.room.name,
                      onDismiss: _dismissSheet,
                      onReserve: _reserveSelectedSeat,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LibraryAppBar extends StatelessWidget {
  const _LibraryAppBar({
    required this.title,
    this.onRefresh,
    this.refreshing = false,
  });
  final String title;
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 64 + topPad,
        padding: EdgeInsets.only(top: topPad),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ambientShadow,
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutterMobile,
          ),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Symbols.arrow_back,
                      size: 24,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: refreshing ? null : onRefresh,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: refreshing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: Padding(
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : const Icon(
                            Symbols.refresh,
                            size: 22,
                            color: AppColors.secondary,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedSeatSheet extends StatelessWidget {
  const _SelectedSeatSheet({
    required this.seatId,
    required this.status,
    required this.roomLabel,
    required this.onDismiss,
    required this.onReserve,
  });

  final int seatId;
  final SeatStatus status;
  final String roomLabel;
  final VoidCallback onDismiss;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutterMobile,
        0,
        AppSpacing.gutterMobile,
        bottomPad + 16,
      ),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        borderRadius: AppRadius.lg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: status.color,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: status.color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$seatId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$seatId번 좌석',
                        style: AppTypography.headlineMd.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _SheetStatusChip(status: status),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              roomLabel,
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(
                    Symbols.close,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                  tooltip: '닫기',
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: status.isReservable ? onReserve : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.surfaceContainerHigh,
                  disabledForegroundColor: AppColors.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  textStyle: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                child: Text(status.isReservable ? '이 좌석 예약하기' : '예약 불가'),
              ),
            ),
            if (status.isReservable) ...[
              const SizedBox(height: 6),
              Text(
                '최대 4시간 이용 가능 · 자리 비움 30분 시 자동 반납',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetStatusChip extends StatelessWidget {
  const _SheetStatusChip({required this.status});
  final SeatStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: status.color.withValues(alpha: 0.35),
          width: 0.6,
        ),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: status.color,
          height: 1.0,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.warning, size: 32, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            '좌석맵을 불러올 수 없습니다',
            style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '$error',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
