import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/friends/presentation/providers/friend_timetable_providers.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/core/theme/app_subject_palette.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/widgets/timetable_grid.dart';

/// 본인 + 선택한 친구들의 시간표를 비교해 "전원 공강 시간"을 찾는 화면.
///
/// 구조:
/// ```
/// ─ AppBar (← 공강 찾기 · N명)
/// ─ 선택된 친구 칩 (가로 스크롤)
/// ─ "함께 비는 시간" 카드 (긴 슬롯 우선 list)
/// ─ 주간 가용성 그리드 (09–19시 × 월–금, 셀당 가용 인원 색상)
/// ```
class CommonFreeTimeScreen extends ConsumerStatefulWidget {
  const CommonFreeTimeScreen({
    super.key,
    required this.ownTimetable,
    required this.selectedFriends,
  });

  final Timetable ownTimetable;
  final List<Friend> selectedFriends;

  @override
  ConsumerState<CommonFreeTimeScreen> createState() =>
      _CommonFreeTimeScreenState();
}

class _CommonFreeTimeScreenState extends ConsumerState<CommonFreeTimeScreen> {
  late final List<Friend> _friends;
  bool _includeMe = true;

  @override
  void initState() {
    super.initState();
    _friends = List.of(widget.selectedFriends);
  }

  void _removeFriend(Friend f) {
    setState(() => _friends.removeWhere((x) => x.id == f.id));
  }

  _FriendScheduleResolution _resolveFriendSchedules() {
    var loading = false;
    final included = <_ResolvedFriendSchedule>[];
    final excluded = <Friend>[];

    for (final friend in _friends) {
      final async = ref.watch(
        friendTimetableProvider((
          friendId: friend.id,
          semester: widget.ownTimetable.semester,
        )),
      );
      final timetable = async.value;
      if (timetable != null) {
        if (timetable.courses.isEmpty) {
          excluded.add(friend);
        } else {
          included.add(_ResolvedFriendSchedule(courses: timetable.courses));
        }
        continue;
      }
      if (async.isLoading) {
        loading = true;
      } else {
        excluded.add(friend);
      }
    }

    return _FriendScheduleResolution(
      loading: loading,
      included: included,
      excluded: excluded,
    );
  }

  /// 비교 대상 N명(본인 포함 옵션)의 강의 시간 일괄 — 알고리즘 입력.
  List<List<CourseTime>> _buildSchedules(
    List<_ResolvedFriendSchedule> included,
  ) {
    final list = <List<CourseTime>>[];
    if (_includeMe) {
      list.add(
        widget.ownTimetable.courses
            .expand((c) => c.times)
            .toList(growable: false),
      );
    }
    for (final friend in included) {
      list.add(friend.courses.expand((c) => c.times).toList(growable: false));
    }
    return list;
  }

  int _peopleCount(List<_ResolvedFriendSchedule> included) =>
      (_includeMe ? 1 : 0) + included.length;

  int get _selectedPeopleCount => (_includeMe ? 1 : 0) + _friends.length;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final resolution = _resolveFriendSchedules();
    final schedules = _buildSchedules(resolution.included);
    final people = _peopleCount(resolution.included);
    final count = resolution.loading ? _selectedPeopleCount : people;
    final slots = resolution.loading
        ? const <_FreeSlot>[]
        : _findCommonFreeSlots(schedules);
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: mq.padding.top + 64 + 8),
                ),
                SliverToBoxAdapter(
                  child: _SelectedPeopleStrip(
                    includeMe: _includeMe,
                    friends: _friends,
                    onToggleMe: () => setState(() => _includeMe = !_includeMe),
                    onRemoveFriend: _removeFriend,
                  ),
                ),
                if (!resolution.loading && resolution.excluded.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _ExcludedFriendsNotice(
                        count: resolution.excluded.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (resolution.loading)
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _CommonFreeTimeLoadingCards(),
                    ),
                  )
                else if (people == 0)
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _NoComparablePeopleCard(),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _FreeSlotList(slots: slots, people: people),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _AvailabilityGrid(
                        schedules: schedules,
                        people: people,
                      ),
                    ),
                  ),
                ],
                SliverPadding(
                  padding: EdgeInsets.only(bottom: 24 + mq.padding.bottom),
                ),
              ],
            ),
            _CommonFreeTimeAppBar(count: count),
          ],
        ),
      ),
    );
  }
}

class _ResolvedFriendSchedule {
  const _ResolvedFriendSchedule({required this.courses});

  final List<Course> courses;
}

class _FriendScheduleResolution {
  const _FriendScheduleResolution({
    required this.loading,
    required this.included,
    required this.excluded,
  });

  final bool loading;
  final List<_ResolvedFriendSchedule> included;
  final List<Friend> excluded;
}

// ═════════════════════════════════════════════════════════════════════════
// AppBar
// ═════════════════════════════════════════════════════════════════════════

class _CommonFreeTimeAppBar extends StatelessWidget {
  const _CommonFreeTimeAppBar({required this.count});
  final int count;

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
              const SizedBox(width: 4),
              Text(
                '공강 찾기',
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$count명',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 11.5,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// 선택된 사람 칩
// ═════════════════════════════════════════════════════════════════════════

class _SelectedPeopleStrip extends StatelessWidget {
  const _SelectedPeopleStrip({
    required this.includeMe,
    required this.friends,
    required this.onToggleMe,
    required this.onRemoveFriend,
  });

  final bool includeMe;
  final List<Friend> friends;
  final VoidCallback onToggleMe;
  final ValueChanged<Friend> onRemoveFriend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
        ),
        children: [
          _PersonChip(
            label: '나',
            isMe: true,
            active: includeMe,
            onTap: onToggleMe,
          ),
          for (final f in friends) ...[
            const SizedBox(width: 8),
            _PersonChip(
              label: f.name,
              avatarSeed: f.avatarSeed,
              active: true,
              onRemove: () => onRemoveFriend(f),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.label,
    this.avatarSeed = 0,
    this.isMe = false,
    this.active = true,
    this.onTap,
    this.onRemove,
  });

  final String label;
  final int avatarSeed;
  final bool isMe;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  static const _avatarColors = AppSubjectPalette.gradients;

  @override
  Widget build(BuildContext context) {
    final g = _avatarColors[avatarSeed % _avatarColors.length];
    final color = active ? AppColors.onSurface : AppColors.outline;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        widthFactor: 1.0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(
            color: active
                ? AppColors.surface.withValues(alpha: 0.85)
                : AppColors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppColors.outline.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: AppColors.ambientShadow,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: g,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isMe ? Symbols.face : Symbols.person,
                  size: 16,
                  fill: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.outline.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Symbols.close,
                      size: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  active
                      ? Symbols.check_circle
                      : Symbols.radio_button_unchecked,
                  size: 14,
                  fill: active ? 1 : 0,
                  color: active ? AppColors.primary : AppColors.outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExcludedFriendsNotice extends StatelessWidget {
  const _ExcludedFriendsNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderRadius: AppRadius.lg,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Symbols.info, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '시간표가 없는 친구 $count명은 제외됐어요',
              style: AppTypography.labelMd.copyWith(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommonFreeTimeLoadingCards extends StatelessWidget {
  const _CommonFreeTimeLoadingCards();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 140, height: 18, radius: 8),
                SizedBox(height: 14),
                _SkeletonLine(width: double.infinity),
                SizedBox(height: 12),
                _SkeletonLine(width: double.infinity),
                SizedBox(height: 12),
                _SkeletonLine(width: 220),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 120, height: 18, radius: 8),
                SizedBox(height: 12),
                SizedBox(
                  height: 552,
                  child: TimetableGridSkeleton(
                    startHour: 9,
                    endHour: 19,
                    hourHeight: 52,
                    timeAxisWidth: 32,
                    headerHeight: 32,
                    dayColWidth: 56,
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

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(width: width, height: 44, radius: AppRadius.md);
  }
}

class _NoComparablePeopleCard extends StatelessWidget {
  const _NoComparablePeopleCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        children: [
          Icon(
            Symbols.group_off,
            size: 34,
            color: AppColors.outline.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 10),
          Text(
            '계산할 시간표가 없어요',
            style: AppTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '나를 포함하거나 시간표를 공유한 친구를 선택해 주세요',
            textAlign: TextAlign.center,
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

// ═════════════════════════════════════════════════════════════════════════
// 공강 슬롯 리스트
// ═════════════════════════════════════════════════════════════════════════

class _FreeSlot {
  const _FreeSlot(this.weekday, this.startMin, this.endMin);
  final Weekday weekday;
  final int startMin;
  final int endMin;
  int get durationMin => endMin - startMin;
}

class _FreeSlotList extends StatelessWidget {
  const _FreeSlotList({required this.slots, required this.people});
  final List<_FreeSlot> slots;
  final int people;

  @override
  Widget build(BuildContext context) {
    if (people == 0) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Symbols.info, size: 20, color: AppColors.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '비교할 사람을 1명 이상 선택해 주세요',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final top = slots.take(6).toList();
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.auto_awesome,
                size: 18,
                fill: 1,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '함께 비는 시간',
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${slots.length}개',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (top.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(
                    Symbols.event_busy,
                    size: 32,
                    color: AppColors.outline.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '겹치는 공강이 없어요',
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '비교 대상에서 한 명 빼보면 다른 시간이 보일 수 있어요',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 11.5,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < top.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.outlineVariant.withValues(alpha: 0.4),
                ),
              _FreeSlotRow(slot: top[i], rank: i + 1),
            ],
        ],
      ),
    );
  }
}

class _FreeSlotRow extends StatelessWidget {
  const _FreeSlotRow({required this.slot, required this.rank});
  final _FreeSlot slot;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final duration = slot.durationMin;
    final isLong = duration >= 120;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isLong
                  ? const Color(0xFF059669).withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: isLong
                    ? const Color(0xFF059669).withValues(alpha: 0.35)
                    : AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: AppTypography.labelSm.copyWith(
                fontSize: 12,
                color: isLong ? const Color(0xFF059669) : AppColors.primary,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '${slot.weekday.label}요일 ${_fmtTime(slot.startMin)} – ${_fmtTime(slot.endMin)}',
                      style: AppTypography.bodyMd.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Symbols.schedule,
                      size: 12,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _fmtDuration(duration),
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 11.5,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isLong) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF059669,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '점심 가능',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 10,
                            color: const Color(0xFF059669),
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Symbols.chevron_right,
            size: 18,
            color: AppColors.outline.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

String _fmtTime(int min) {
  final h = min ~/ 60;
  final m = min % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String _fmtDuration(int min) {
  if (min < 60) return '$min분';
  final h = min ~/ 60;
  final m = min % 60;
  if (m == 0) return '$h시간';
  return '$h시간 $m분';
}

// ═════════════════════════════════════════════════════════════════════════
// 주간 가용성 그리드 — 셀 색상이 가용 인원 비율 표현
// ═════════════════════════════════════════════════════════════════════════

class _AvailabilityGrid extends StatelessWidget {
  const _AvailabilityGrid({required this.schedules, required this.people});
  final List<List<CourseTime>> schedules;
  final int people;

  static const int _startHour = 9;
  static const int _endHour = 19;
  static const int _slotMinutes = 30;
  static const double _slotHeight = 26;
  static const double _timeAxisWidth = 32;
  static const double _headerHeight = 32;

  /// 인원 N명일 때 (요일, 슬롯)별 "수업 안 듣는 인원 수"를 0..N으로 반환.
  /// 슬롯은 30분 단위. 09:00→0, 09:30→1, …
  List<List<int>> _computeFreeMatrix() {
    final slotsPerDay = (_endHour - _startHour) * (60 ~/ _slotMinutes);
    final mtx = List<List<int>>.generate(
      Weekday.values.length,
      (_) => List<int>.filled(slotsPerDay, people),
    );
    for (final schedule in schedules) {
      for (final ct in schedule) {
        final wd = ct.weekday.index;
        final s = (ct.start.totalMinutes - _startHour * 60) ~/ _slotMinutes;
        final e =
            (ct.end.totalMinutes - _startHour * 60 + _slotMinutes - 1) ~/
            _slotMinutes;
        for (var i = math.max(0, s); i < math.min(slotsPerDay, e); i++) {
          if (mtx[wd][i] > 0) mtx[wd][i] -= 1;
        }
      }
    }
    return mtx;
  }

  @override
  Widget build(BuildContext context) {
    if (people == 0) {
      return const SizedBox.shrink();
    }
    final mtx = _computeFreeMatrix();
    final slotsPerDay = (_endHour - _startHour) * (60 ~/ _slotMinutes);
    final totalHeight = _headerHeight + slotsPerDay * _slotHeight;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.calendar_view_week,
                size: 18,
                fill: 1,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '주간 가용성',
                style: AppTypography.headlineMd.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const Spacer(),
              _LegendSwatch(color: const Color(0xFF059669), label: '전원 공강'),
              const SizedBox(width: 8),
              _LegendSwatch(color: const Color(0xFFD97706), label: '일부'),
              const SizedBox(width: 8),
              _LegendSwatch(color: AppColors.primary, label: '모두 수업'),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, cs) {
              final dayColWidth =
                  (cs.maxWidth - _timeAxisWidth) / Weekday.values.length;
              return SizedBox(
                height: totalHeight,
                child: Stack(
                  children: [
                    TimetableGridSkeleton(
                      startHour: _startHour,
                      endHour: _endHour,
                      hourHeight: _slotHeight * (60 / _slotMinutes),
                      timeAxisWidth: _timeAxisWidth,
                      headerHeight: _headerHeight,
                      dayColWidth: dayColWidth,
                    ),
                    Positioned(
                      top: 0,
                      left: _timeAxisWidth,
                      right: 0,
                      height: _headerHeight,
                      child: Row(
                        children: [
                          for (final w in Weekday.values)
                            Expanded(
                              child: Center(
                                child: Text(
                                  w.label,
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (var wd = 0; wd < Weekday.values.length; wd++)
                      for (var s = 0; s < slotsPerDay; s++)
                        Positioned(
                          top: _headerHeight + s * _slotHeight + 1,
                          left: _timeAxisWidth + wd * dayColWidth + 1,
                          width: dayColWidth - 2,
                          height: _slotHeight - 2,
                          child: _AvailabilityCell(
                            freeCount: mtx[wd][s],
                            total: people,
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCell extends StatelessWidget {
  const _AvailabilityCell({required this.freeCount, required this.total});
  final int freeCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : freeCount / total;
    Color fill;
    Color border;
    if (ratio >= 1.0) {
      fill = const Color(0xFF059669).withValues(alpha: 0.20);
      border = const Color(0xFF059669).withValues(alpha: 0.45);
    } else if (ratio == 0) {
      fill = AppColors.primary.withValues(alpha: 0.10);
      border = AppColors.primary.withValues(alpha: 0.25);
    } else {
      fill = const Color(0xFFD97706).withValues(alpha: 0.13);
      border = const Color(0xFFD97706).withValues(alpha: 0.3);
    }
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.5),
      ),
      alignment: Alignment.center,
      child: ratio > 0 && ratio < 1.0
          ? Text(
              '$freeCount/$total',
              style: AppTypography.labelSm.copyWith(
                fontSize: 9,
                color: const Color(0xFFD97706),
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            )
          : null,
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label});
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
            color: color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: color.withValues(alpha: 0.55),
              width: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontSize: 10.5,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// 공통 공강 알고리즘
// ═════════════════════════════════════════════════════════════════════════

const int _dayStartMin = 9 * 60;
const int _dayEndMin = 19 * 60;
const int _minSlotDuration = 30;

/// 모든 대상이 비어있는 시간대를 요일별로 추출 → 길이 내림차순.
List<_FreeSlot> _findCommonFreeSlots(List<List<CourseTime>> peopleSchedules) {
  if (peopleSchedules.isEmpty) return const [];
  final out = <_FreeSlot>[];
  for (final wd in Weekday.values) {
    final busy = <List<int>>[];
    for (final schedule in peopleSchedules) {
      for (final ct in schedule) {
        if (ct.weekday != wd) continue;
        busy.add([ct.start.totalMinutes, ct.end.totalMinutes]);
      }
    }
    busy.sort((a, b) => a[0].compareTo(b[0]));
    // 머지
    final merged = <List<int>>[];
    for (final b in busy) {
      if (merged.isNotEmpty && b[0] <= merged.last[1]) {
        merged.last[1] = math.max(merged.last[1], b[1]);
      } else {
        merged.add([b[0], b[1]]);
      }
    }
    // 갭 → 공강 슬롯
    int cursor = _dayStartMin;
    for (final b in merged) {
      if (b[0] > cursor) {
        final s = math.max(cursor, _dayStartMin);
        final e = math.min(b[0], _dayEndMin);
        if (e - s >= _minSlotDuration) {
          out.add(_FreeSlot(wd, s, e));
        }
      }
      cursor = math.max(cursor, b[1]);
    }
    if (cursor < _dayEndMin) {
      final s = math.max(cursor, _dayStartMin);
      if (_dayEndMin - s >= _minSlotDuration) {
        out.add(_FreeSlot(wd, s, _dayEndMin));
      }
    }
  }
  out.sort((a, b) {
    final d = b.durationMin - a.durationMin;
    if (d != 0) return d;
    final w = a.weekday.index - b.weekday.index;
    if (w != 0) return w;
    return a.startMin - b.startMin;
  });
  return out;
}
