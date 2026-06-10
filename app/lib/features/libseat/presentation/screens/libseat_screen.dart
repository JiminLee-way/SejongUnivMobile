import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/facility_models.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/holidays/presentation/providers/holiday_providers.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/screens/facility_reservation_history_screen.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/screens/libseat_info_screen.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/widgets/reservation_confirm_sheet.dart'
    show showReservationConfirmSheet;
import 'package:sejong_smart_campus/features/shell/presentation/widgets/bottom_nav_insets.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

/// 시설 예약 (스터디룸 / 시네마룸 / S-Lounge) 3 탭 화면.
///
/// 한 카테고리의 모든 룸을 한 list로 펼쳐 보여주고, 룸별 시간 grid 막대에서
/// 1~2시간 slot 선택 → 하단 selection bar → 예약 확인 sheet → reserveSlot.
class LibseatScreen extends ConsumerStatefulWidget {
  const LibseatScreen({super.key});

  @override
  ConsumerState<LibseatScreen> createState() => _LibseatScreenState();
}

class _LibseatScreenState extends ConsumerState<LibseatScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  // 오늘이 일요일/휴일이면 다음 영업일로 자동 점프 — 휴일에 default가 박혀
  // 모든 슬롯이 회색으로만 보이는 사용성 문제 방지.
  DateTime _selectedDate = _nextBusinessDay(DateTime.now());
  _SlotSelection? _selection;
  // 정원 필터 — null이면 전체. 카테고리 변경 시 reset.
  int? _capacityFilter;

  static const _maxDuration = 2;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: FacilityCategory.values.length, vsync: this)
      ..addListener(() {
        if (_tabs.indexIsChanging) return;
        setState(() {
          _selection = null;
          _capacityFilter = null;
        });
      });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refreshCurrent() async {
    // 모든 family 전체 invalidate — facilityRoomsForDateProvider만 invalidate
    // 하면 의존하는 facilityMapProvider/facilityGroupsProvider의 cache는
    // 그대로라 새로 fetch되지 않음. 시설 예약 관련 모든 cache를 비워야
    // 사용자 명시 새로고침이 실제 효과를 가짐.
    ref.invalidate(facilityRoomsForDateProvider);
    ref.invalidate(facilityMapProvider);
    ref.invalidate(facilityGroupsProvider);
    ref.invalidate(myFacilityReservationsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  void _onPickDate(DateTime d) {
    setState(() {
      _selectedDate = _dateOnly(d);
      _selection = null;
    });
  }

  void _onTapSlot(RoomSchedule room, int hour) {
    if (!room.slots.firstWhere((s) => s.hour == hour).isReservable) return;
    setState(() {
      final cur = _selection;
      final key = room.roomLabel;
      if (cur == null || cur.roomKey != key) {
        _selection = _SlotSelection(roomKey: key, startHour: hour, duration: 1);
        return;
      }
      // 동일 룸 — 인접/해제 처리.
      if (cur.duration == 1) {
        if (hour == cur.startHour) {
          _selection = null;
        } else if (hour == cur.startHour + 1) {
          _selection = cur.copyWith(duration: 2);
        } else if (hour == cur.startHour - 1) {
          _selection = _SlotSelection(
            roomKey: key,
            startHour: hour,
            duration: 2,
          );
        } else {
          _selection = _SlotSelection(
            roomKey: key,
            startHour: hour,
            duration: 1,
          );
        }
      } else {
        // duration == 2 — 2시간 선택 중. 영역 내 탭은 해제(축소), 영역 밖은 새 선택.
        if (hour >= cur.startHour && hour < cur.startHour + _maxDuration) {
          _selection = null;
        } else {
          _selection = _SlotSelection(
            roomKey: key,
            startHour: hour,
            duration: 1,
          );
        }
      }
    });
  }

  Future<void> _openReserveSheet(RoomSchedule room) async {
    final sel = _selection;
    if (sel == null || sel.roomKey != room.roomLabel) return;
    await showReservationConfirmSheet(
      context,
      room: room,
      startHour: sel.startHour,
      durationHours: sel.duration,
      onConfirm: (companions) async {
        final time = '${sel.startHour.toString().padLeft(2, '0')}:00';
        // 본인은 reserveFacilitySlot 내부에서 자동 prepend. 동반자만 전달.
        // 학번이 있는 인원만 (친구 목록에서 학번 unknown인 경우 자동 제외).
        final companionTuples = <({String studentId, String name})>[
          for (final c in companions)
            if (!c.isSelf && (c.studentId ?? '').isNotEmpty)
              (studentId: c.studentId!, name: c.name),
        ];
        final r = await reserveFacilitySlot(
          ref,
          group: room.group,
          sroomNo: room.sroomNo,
          roomLabel: room.roomLabel,
          time: time,
          durationHours: sel.duration,
          companions: companionTuples,
          date: _selectedDate,
        );
        if (!mounted) return false;
        // ignore: use_build_context_synchronously
        await showLibseatResultDialog(context, r);
        return r.success;
      },
    );
    if (mounted) setState(() => _selection = null);
  }

  void _openInfo() {
    final initial = FacilityCategory.values[_tabs.index];
    Navigator.of(context).push(slideRoute(LibseatInfoScreen(initial: initial)));
  }

  void _openHistory() {
    Navigator.of(
      context,
    ).push(slideRoute(const FacilityReservationHistoryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // 휴일 lookup이 로딩 완료된 시점에 _selectedDate가 휴일이면 다음 영업일로
    // 자동 이동. initState에서는 일요일만 알 수 있어서 부처님오신날 같은 공휴일은
    // 여기서 보정. 무한 setState 회피를 위해 변경 필요 시에만 이동.
    final holidayName = ref.watch(holidayLookupProvider(_selectedDate.year));
    final selKey = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (_selectedDate.weekday == DateTime.sunday ||
        holidayName.containsKey(selKey)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final fixed = _nextBusinessDayWithHolidays(_selectedDate, holidayName);
        if (!_sameDay(fixed, _selectedDate)) {
          setState(() {
            _selectedDate = fixed;
            _selection = null;
          });
        }
      });
    }
    // 자체 AppBar(56dp) + TabBar(44dp) — 시간표/열람실/학식과 동일 패턴.
    final headerOffset = mq.padding.top + 56 + 44;
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(top: headerOffset),
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    for (final c in FacilityCategory.values)
                      _CategoryTab(
                        category: c,
                        date: _selectedDate,
                        selection: _selection,
                        capacityFilter: _capacityFilter,
                        onCapacityChange: (cap) =>
                            setState(() => _capacityFilter = cap),
                        onTapSlot: _onTapSlot,
                        onReserve: _openReserveSheet,
                        onRefresh: _refreshCurrent,
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SejongSubAppBar(
                title: '시설 예약',
                actions: [
                  _HistoryChip(onTap: _openHistory),
                  IconButton(
                    icon: const Icon(
                      Symbols.refresh,
                      color: AppColors.onSurface,
                      size: 22,
                    ),
                    onPressed: () => _refreshCurrent(),
                    splashRadius: 22,
                  ),
                  IconButton(
                    icon: const Icon(
                      Symbols.info,
                      color: AppColors.onSurface,
                      size: 22,
                    ),
                    onPressed: _openInfo,
                    splashRadius: 22,
                  ),
                ],
                bottomHeight: 44,
                bottom: TabBar(
                  controller: _tabs,
                  isScrollable: false,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  dividerColor: AppColors.outline.withValues(alpha: 0.25),
                  dividerHeight: 1,
                  labelStyle: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: [
                    for (final c in FacilityCategory.values) Tab(text: c.label),
                  ],
                ),
              ),
            ),
            if (_selection != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _SelectionBar(
                  selection: _selection!,
                  date: _selectedDate,
                  category: FacilityCategory.values[_tabs.index],
                  onDismiss: () => setState(() => _selection = null),
                  onReserve: (room) => _openReserveSheet(room),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotSelection {
  const _SlotSelection({
    required this.roomKey,
    required this.startHour,
    required this.duration,
  });
  final String roomKey;
  final int startHour;
  final int duration;

  _SlotSelection copyWith({int? startHour, int? duration}) => _SlotSelection(
    roomKey: roomKey,
    startHour: startHour ?? this.startHour,
    duration: duration ?? this.duration,
  );

  int get endHour => startHour + duration;
  bool contains(int hour) => hour >= startHour && hour < endHour;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 오늘이 영업일(월~토 + 공휴일 아님)이면 오늘, 아니면 다음 영업일.
/// initState 단계에서는 [holidays]가 없으므로 일요일만 skip — build 시점에
/// [_nextBusinessDayWithHolidays]로 추가 보정.
DateTime _nextBusinessDay(DateTime from) {
  var d = _dateOnly(from);
  while (d.weekday == DateTime.sunday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// 일요일 + 한국 법정 공휴일을 모두 건너뛰는 영업일 계산. 최대 14일 탐색
/// (연휴 1주 + 안전마진).
DateTime _nextBusinessDayWithHolidays(
  DateTime from,
  Map<DateTime, String> holidays,
) {
  var d = _dateOnly(from);
  for (var i = 0; i < 14; i++) {
    final key = DateTime(d.year, d.month, d.day);
    final isHoliday = holidays.containsKey(key);
    final isSunday = d.weekday == DateTime.sunday;
    if (!isHoliday && !isSunday) return d;
    d = d.add(const Duration(days: 1));
  }
  return d;
}

// ─── 시설 예약 액션 영역 ────────────────────────────────────────────────────

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.receipt_long,
                size: 14,
                fill: 1,
                color: AppColors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                '예약 내역',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 카테고리 본문 ────────────────────────────────────────────────────────

class _CategoryTab extends ConsumerWidget {
  const _CategoryTab({
    required this.category,
    required this.date,
    required this.selection,
    required this.capacityFilter,
    required this.onCapacityChange,
    required this.onTapSlot,
    required this.onReserve,
    required this.onRefresh,
  });

  final FacilityCategory category;
  final DateTime date;
  final _SlotSelection? selection;
  final int? capacityFilter;
  final ValueChanged<int?> onCapacityChange;
  final void Function(RoomSchedule, int) onTapSlot;
  final void Function(RoomSchedule) onReserve;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(facilityRoomsForDateProvider((category, date)));
    final navHeight = BottomNavInsets.of(context);
    final mq = MediaQuery.of(context);
    return SejongRefresh(
      onRefresh: onRefresh,
      topInset: 0,
      child: ListView(
        padding: EdgeInsets.only(
          top: 4,
          left: AppSpacing.marginMobile,
          right: AppSpacing.marginMobile,
          // 콘텐츠가 selection bar(약 64dp) + nav/safe 뒤로 안 가려지도록.
          bottom: navHeight + mq.padding.bottom + 80,
        ),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          _DateStrip(
            selected: date,
            onSelected: (d) {
              final state = context
                  .findAncestorStateOfType<_LibseatScreenState>();
              state?._onPickDate(d);
            },
          ),
          const SizedBox(height: 14),
          async.when(
            loading: () => const _RoomsSkeleton(),
            error: (_, _) => _ErrorBox(
              message: '${category.label} 정보를 불러오지 못했어요',
              onRetry: () => ref.invalidate(
                facilityRoomsForDateProvider((category, date)),
              ),
            ),
            data: (rooms) {
              // 카테고리 내 등장하는 정원 종류(2~3개) 추출 — 필터 chip 라벨.
              final capacities =
                  rooms.map((r) => r.maxCapacity).toSet().toList()..sort();
              final filtered = capacityFilter == null
                  ? rooms
                  : rooms
                        .where((r) => r.maxCapacity == capacityFilter)
                        .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CountAndLegend(
                    count: filtered.length,
                    capacities: capacities,
                    selectedCapacity: capacityFilter,
                    onSelect: onCapacityChange,
                  ),
                  const SizedBox(height: 18),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          '${category.label} 정보가 없어요',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final room in filtered) ...[
                      _RoomCard(
                        room: room,
                        selection: selection?.roomKey == room.roomLabel
                            ? selection
                            : null,
                        onTapSlot: (h) => onTapSlot(room, h),
                      ),
                      const SizedBox(height: 18),
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

// ─── 날짜 carousel ─────────────────────────────────────────────────────────

class _DateStrip extends ConsumerWidget {
  const _DateStrip({required this.selected, required this.onSelected});
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _dateOnly(DateTime.now());
    final dates = [for (var i = 0; i < 7; i++) today.add(Duration(days: i))];
    // 7일 윈도우가 연도를 넘을 수 있어 두 해 모두 lookup.
    final years = dates.map((d) => d.year).toSet();
    final holidayName = <DateTime, String>{};
    for (final y in years) {
      holidayName.addAll(ref.watch(holidayLookupProvider(y)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                '예약일자',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '${selected.year}년 ${selected.month}월',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            for (final d in dates)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _DateCell(
                    date: d,
                    selected: _sameDay(d, selected),
                    holidayName: holidayName[DateTime(d.year, d.month, d.day)],
                    onTap: () => onSelected(d),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.selected,
    required this.onTap,
    this.holidayName,
  });
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  /// data.go.kr 기준 휴일이면 이름 (예: "어린이날"). null이면 평일/토.
  final String? holidayName;

  @override
  Widget build(BuildContext context) {
    final isSunday = date.weekday == DateTime.sunday;
    final weekdayLabel = _weekdayLabels[date.weekday - 1];
    // 일요일 또는 법정 공휴일은 휴무.
    final disabled = isSunday || holidayName != null;
    final Color bg;
    final Color fg;
    if (selected) {
      bg = AppColors.primary;
      fg = Colors.white;
    } else if (disabled) {
      // 휴무는 채도 낮은 회색 — 활성 셀(흰색)과 명확히 구분.
      bg = AppColors.outline.withValues(alpha: 0.12);
      fg = AppColors.onSurfaceVariant.withValues(alpha: 0.55);
    } else {
      // 활성 셀 — 흰색 + 옅은 그림자로 "선택 가능" 강조.
      bg = Colors.white;
      fg = AppColors.onSurface;
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (disabled) {
            final msg = holidayName != null
                ? '$holidayName은(는) 휴무라 예약할 수 없어요'
                : '일요일은 휴무라 예약할 수 없어요';
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(msg),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: selected
                ? null
                : Border.all(
                    color: disabled
                        ? Colors.transparent
                        : AppColors.outline.withValues(alpha: 0.25),
                    width: 1,
                  ),
            boxShadow: (selected || disabled)
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekdayLabel,
                style: AppTypography.labelSm.copyWith(
                  fontSize: 11,
                  color: fg.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date.day.toString(),
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  color: fg,
                  decoration: disabled ? TextDecoration.lineThrough : null,
                  decorationColor: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
}

// ─── 건수 + 범례 ───────────────────────────────────────────────────────────

class _CountAndLegend extends StatelessWidget {
  const _CountAndLegend({
    required this.count,
    required this.capacities,
    required this.selectedCapacity,
    required this.onSelect,
  });
  final int count;
  final List<int> capacities;
  final int? selectedCapacity;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: AppTypography.headlineMd.copyWith(
                fontSize: 24,
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '건',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            const Spacer(),
            // 카테고리 내 정원 종류가 2개 이상이면 필터 chips 노출.
            // 종류가 1개뿐이면(시네마룸 등) 필터링 의미 없어 숨김.
            if (capacities.length >= 2) ...[
              _CapChip(
                label: '전체',
                selected: selectedCapacity == null,
                onTap: () => onSelect(null),
              ),
              for (final c in capacities) ...[
                const SizedBox(width: 6),
                _CapChip(
                  label: '$c인실',
                  selected: selectedCapacity == c,
                  onTap: () => onSelect(c),
                ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 6,
            children: const [
              _LegendDot(color: Color(0xFFFCA5A5), label: '이용가능'),
              _LegendDot(color: Color(0xFFCBD5E1), label: '이용불가'),
            ],
          ),
        ),
      ],
    );
  }
}

class _CapChip extends StatelessWidget {
  const _CapChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.surfaceContainerHigh.withValues(alpha: 0.7),
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
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontSize: 11.5,
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── 룸 카드 ──────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.selection,
    required this.onTapSlot,
  });
  final RoomSchedule room;
  final _SlotSelection? selection;
  final void Function(int hour) onTapSlot;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  room.roomIndex.toString(),
                  style: AppTypography.headlineMd.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${room.roomLabel} (${room.maxCapacity}인실)',
                      style: AppTypography.headlineMd.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.capacityLabel,
                      style: AppTypography.labelMd.copyWith(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TimeBarsRow(
            hours: LibseatHours.firstRow,
            slots: room.slots,
            selection: selection,
            onTap: onTapSlot,
          ),
          const SizedBox(height: 8),
          _TimeBarsRow(
            hours: LibseatHours.secondRow,
            slots: room.slots,
            selection: selection,
            onTap: onTapSlot,
          ),
        ],
      ),
    );
  }
}

class _TimeBarsRow extends StatelessWidget {
  const _TimeBarsRow({
    required this.hours,
    required this.slots,
    required this.selection,
    required this.onTap,
  });
  final List<int> hours;
  final List<RoomTimeSlot> slots;
  final _SlotSelection? selection;
  final void Function(int hour) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final h in hours)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    h.toString(),
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 10.5,
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final h in hours)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: _TimeBar(
                    slot: slots.firstWhere(
                      (s) => s.hour == h,
                      orElse: () =>
                          RoomTimeSlot(hour: h, status: SlotStatus.disabled),
                    ),
                    isSelected: selection?.contains(h) ?? false,
                    onTap: () => onTap(h),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TimeBar extends StatelessWidget {
  const _TimeBar({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });
  final RoomTimeSlot slot;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final Color color;
    if (isSelected) {
      color = AppColors.primary;
    } else {
      switch (slot.status) {
        case SlotStatus.available:
          color = const Color(0xFFFCA5A5);
          break;
        case SlotStatus.reserved:
          color = const Color(0xFFCBD5E1);
          break;
        case SlotStatus.disabled:
          color = const Color(0xFFE5E7EB);
          break;
      }
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: slot.isReservable ? onTap : null,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

// ─── Selection bar ─────────────────────────────────────────────────────────

class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({
    required this.selection,
    required this.date,
    required this.category,
    required this.onDismiss,
    required this.onReserve,
  });

  final _SlotSelection selection;
  final DateTime date;
  final FacilityCategory category;
  final VoidCallback onDismiss;
  final void Function(RoomSchedule room) onReserve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms =
        ref.watch(facilityRoomsForDateProvider((category, date))).value ??
        const <RoomSchedule>[];
    final room = rooms.firstWhere(
      (r) => r.roomLabel == selection.roomKey,
      orElse: () => RoomSchedule(
        group: rooms.isEmpty
            ? FacilityGroup(
                category: category,
                seq: 0,
                title: '',
                subtitle: '',
                seatCnt: 0,
              )
            : rooms.first.group,
        roomLabel: selection.roomKey,
        sroomNo: 0,
        roomIndex: 0,
        minCapacity: 1,
        maxCapacity: 1,
        slots: const [],
      ),
    );
    final start = selection.startHour;
    final end = selection.endHour;
    // AppShell이 GlobalKey로 실측한 nav 높이. rootNavigator로 push된 경우
    // (LibseatScreen이 메인 패턴) AppShell tree 밖이라 0 — 그땐 gesture
    // bar 위로 safe area만큼만 띄움.
    final navHeight = BottomNavInsets.of(context);
    final bottomSafe = navHeight > 0
        ? 0.0
        : MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: EdgeInsets.only(bottom: navHeight + bottomSafe),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${room.roomLabel} (${room.maxCapacity}인실)',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${start.toString().padLeft(2, '0')}:00 ~ '
                  '${end.toString().padLeft(2, '0')}:00 '
                  '(${selection.duration}시간)',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 11.5,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => onReserve(room),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            child: const Text('예약하기'),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(
              Symbols.close,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

// ─── 보조 위젯 ────────────────────────────────────────────────────────────

class _RoomsSkeleton extends StatelessWidget {
  const _RoomsSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Padding(
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

// ─── 좌석 grid 화면 (도서관 좌석맵, 기존 동작 보존) ────────────────────────

/// 도서관 좌석 grid 화면 — `LibraryListScreen`에서 push.
///
/// 시설 예약(스터디룸/시네마룸/S-Lounge)과 별도. 이 화면은 열람실 좌석맵 전담.
class SeatMapScreen extends ConsumerWidget {
  const SeatMapScreen({super.key, required this.room});
  final ReadingRoom room;

  Future<void> _onSeatTap(
    BuildContext context,
    WidgetRef ref,
    Seat seat,
  ) async {
    if (!seat.isReservable) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            seat.status == SeatStatus.used
                ? '이미 사용 중인 좌석이에요'
                : '선택할 수 없는 좌석이에요',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('좌석을 예약하시겠어요?'),
        content: Text('${room.name} · ${seat.seatNo}번'),
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
    final r = await reserveLibseat(
      ref,
      roomNo: room.roomNo,
      seatNo: seat.seatNo,
    );
    if (!context.mounted) return;
    await showLibseatResultDialog(context, r);
    if (!context.mounted) return;
    if (r.success) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final seatsAsync = ref.watch(seatMapProvider(room.roomNo));
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
                  ref.invalidate(seatMapProvider(room.roomNo));
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
                    _SeatLegend(),
                    const SizedBox(height: 16),
                    seatsAsync.when(
                      loading: () => const _SeatLoader(),
                      error: (_, _) => _SeatError(
                        message: '좌석을 불러오지 못했어요',
                        onRetry: () =>
                            ref.invalidate(seatMapProvider(room.roomNo)),
                      ),
                      data: (seats) => _SeatGrid(
                        seats: seats,
                        onTap: (s) => _onSeatTap(context, ref, s),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: _SeatMapAppBar(room: room),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatMapAppBar extends ConsumerWidget {
  const _SeatMapAppBar({required this.room});
  final ReadingRoom room;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final rooms = ref.watch(roomListProvider).value;
    final live =
        rooms?.firstWhere((r) => r.roomNo == room.roomNo, orElse: () => room) ??
        room;
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
          Expanded(
            child: Text(
              live.name,
              style: AppTypography.headlineMd.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '${live.free}/${live.total}',
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _SeatLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: const [
        _SeatLegendChip(color: Color(0xFF059669), label: '사용 가능'),
        _SeatLegendChip(color: AppColors.primary, label: '사용 중'),
        _SeatLegendChip(color: Color(0xFFD97706), label: '고정석'),
        _SeatLegendChip(color: Color(0xFF6B7280), label: '사용 불가'),
      ],
    );
  }
}

class _SeatLegendChip extends StatelessWidget {
  const _SeatLegendChip({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SeatGrid extends StatelessWidget {
  const _SeatGrid({required this.seats, required this.onTap});
  final List<Seat> seats;
  final ValueChanged<Seat> onTap;
  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            '좌석 정보가 없어요',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: seats.length,
      itemBuilder: (context, i) => _SeatCell(seat: seats[i], onTap: onTap),
    );
  }
}

class _SeatCell extends StatelessWidget {
  const _SeatCell({required this.seat, required this.onTap});
  final Seat seat;
  final ValueChanged<Seat> onTap;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (seat.status) {
      SeatStatus.available => (
        const Color(0xFFE6F4EE),
        const Color(0xFF065F46),
      ),
      SeatStatus.used => (
        AppColors.primary.withValues(alpha: 0.15),
        AppColors.primary,
      ),
      SeatStatus.fixed => (const Color(0xFFFFEFD5), const Color(0xFFB45309)),
      SeatStatus.disabled => (
        AppColors.outline.withValues(alpha: 0.15),
        AppColors.onSurfaceVariant,
      ),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(seat),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Text(
            seat.seatNo,
            style: AppTypography.labelMd.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatLoader extends StatelessWidget {
  const _SeatLoader();
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

class _SeatError extends StatelessWidget {
  const _SeatError({required this.message, required this.onRetry});
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
