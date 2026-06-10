import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/timetable/data/datasources/mock_timetable.dart'
    show mockInviteCandidates;
import 'package:sejong_smart_campus/features/timetable/domain/entities/enrolled_course.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/providers/enrolled_courses_providers.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/providers/timetable_providers.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/timetable_sync_provider.dart';
import 'package:sejong_smart_campus/features/friends/presentation/screens/friend_add_screen.dart';
import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_subject_palette.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/shell/presentation/widgets/bottom_nav_insets.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/widgets/timetable_grid.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/screens/common_free_time_screen.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/screens/friend_timetable_screen.dart';

/// 시간표 화면 (글래스모피즘).
///
/// 구조:
/// ```
/// ─ TimetableAppBar (← 시간표 [학기칩] 🔍)
/// ─ 학기 셀렉터 (가로 스크롤 글래스 칩 5개)
/// ─ 학점 요약 줄 (총 N학점 · M과목)
/// ─ 시간표 그리드 09:00–19:00 × 월~금
/// ─ 친구 패널 (드래그업 바텀시트, 핸들+헤더만 peek)
/// ```
class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  Semester _semester = Semester.spring2026;

  /// 친구 시트 최대 비율. 최소(peek)는 dynamic — system gesture bar + AppShell
  /// bottom nav 영역까지 visible peek content가 침범하지 않도록 화면 높이 기반
  /// 비율을 build 안에서 계산.
  static const double _sheetMax = 0.85;
  static const double _sheetPeekContentH = 64.0;

  /// 친구 시트가 화면 진입 시 처음 열려 있는 비율(~30%). peek만 보이면 친구
  /// 패널 발견성이 떨어져, 진입하자마자 살짝 펼쳐 둔다(사용자가 아래로 끌어
  /// 시간표 전체를 볼 수 있음). 중간 snap 지점도 이 값으로 통일.
  static const double _sheetInitial = 0.3;

  // 다중 선택(공강 비교) 모드
  bool _selectionMode = false;
  final Set<String> _selectedFriendIds = {};

  /// 화면에 현재 표시되는 시간표 — 로딩/에러 중에는 빈 시간표(graceful fallback).
  Timetable _currentTimetable(AsyncValue<Timetable> tt) =>
      tt.value ?? Timetable(semester: _semester, courses: const []);

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedFriendIds.contains(id)) {
        _selectedFriendIds.remove(id);
      } else {
        _selectedFriendIds.add(id);
      }
    });
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedFriendIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedFriendIds.clear();
    });
  }

  void _openFriendTimetable(Friend friend) {
    Navigator.of(
      context,
    ).push(slideRoute(FriendTimetableScreen(friend: friend)));
  }

  void _openCommonFreeTime(Timetable own, List<Friend> friends) {
    final selected = friends
        .where((f) => _selectedFriendIds.contains(f.id))
        .toList();
    Navigator.of(context).push(
      slideRoute(
        CommonFreeTimeScreen(ownTimetable: own, selectedFriends: selected),
      ),
    );
    _exitSelectionMode();
  }

  void _openFriendAdd() {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(slideRoute(const FriendAddScreen()));
  }

  Future<void> _onRefresh() async {
    await refreshTimetableForSemester(ref, _semester);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // 현재 선택된 학기 시간표를 Supabase에 자동 백업.
    useTimetableSync(ref, _semester);
    final ttAsync = ref.watch(timetableForSemesterProvider(_semester));
    final timetable = _currentTimetable(ttAsync);
    final isLoading = ttAsync.isLoading && !ttAsync.hasValue;
    final friends = ref.watch(myFriendsAsLegacyProvider);
    // 받은 친구 신청 수 — 친구 추가 화면 진입 버튼에 배지로 노출(미수락 신청
    // 발견성). 신청을 수락할 UI는 FriendAddScreen 상단 "받은 친구 신청" 섹션.
    final pendingReqCount =
        ref.watch(pendingFriendRequestsProvider).value?.length ?? 0;
    // SJPT 수강내역 — 온라인·수업일 미등록 강의까지 포함한 정확한 총학점 +
    // 시간표 외 강의 목록. 로딩/실패 시 null → 그리드 기반 학점으로 폴백
    // (시간표 자체엔 영향 없음).
    final enrolled = ref.watch(enrolledSummaryProvider(_semester)).value;
    // peek 영역(핸들+헤더 64) + system gesture bar(viewPadding.bottom) +
    // AppShell bottom nav(BottomNavInsets)를 모두 더한 절대 px → 화면 비율.
    // 이 값이 DraggableScrollableSheet의 minSize로 들어가 system bar 영역에
    // 시트 visible content가 잘리지 않게 한다.
    final navInset = BottomNavInsets.of(context);
    final peekPx = _sheetPeekContentH + mq.padding.bottom + navInset;
    final sheetMin = (peekPx / mq.size.height).clamp(0.05, 0.4);
    // 초기 오픈 비율(~30%)은 항상 peek(min)보다 크게 유지 — 작은 화면에서 peek이
    // 0.3을 넘더라도 DraggableScrollableSheet의 snapSizes 오름차순 +
    // initialChildSize>=minChildSize 단언이 깨지지 않도록 방어.
    final sheetInitial = sheetMin < _sheetInitial
        ? _sheetInitial
        : sheetMin + 0.02;
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            // ── 콘텐츠 영역 ────────────────────────────────────────────────
            Padding(
              // 친구 시트 peek 만큼 여유 — 콘텐츠가 시트에 가려지지 않도록
              padding: EdgeInsets.only(bottom: peekPx),
              child: SejongRefresh(
                onRefresh: _onRefresh,
                topInset: mq.padding.top + 64,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // 시각 gap 통일 — 모두 26dp. 각 컴포넌트의 inner padding을
                    // 고려해서 SizedBox 값을 다르게 계산:
                    //   AppBar ↔ chips: SizedBox(10) + SemesterStrip 내부 위 16 = 26
                    //   chips ↔ stats : SemesterStrip 내부 아래 16 + SizedBox(10) = 26
                    //   stats ↔ grid  : _CreditSummary 아래 0 + SizedBox(16) + GlassCard 위 10 = 26
                    SliverToBoxAdapter(
                      child: SizedBox(height: mq.padding.top + 64 + 10),
                    ),
                    SliverToBoxAdapter(
                      child: SemesterStrip(
                        selected: _semester,
                        onSelected: (s) => setState(() => _semester = s),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverToBoxAdapter(
                      child: _CreditSummary(
                        timetable: timetable,
                        enrolled: enrolled,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (isLoading)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.marginMobile,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: TimetableGrid(timetable: timetable),
                        ),
                      ),
                    // 시간표 외(온라인·수업일 미등록) 강의 — SJPT 수강내역 기반.
                    // 그리드엔 안 뜨지만 학점에 포함되는 강의를 명시한다.
                    if (!isLoading && enrolled != null && enrolled.hasOffGrid)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.marginMobile,
                          16,
                          AppSpacing.marginMobile,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _OffGridSection(summary: enrolled),
                        ),
                      ),
                    if (ttAsync.hasError && !ttAsync.isLoading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.marginMobile,
                          vertical: 12,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _ErrorBanner(
                            message: ttAsync.error.toString(),
                            onRetry: _onRefresh,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
            // ── 상단 글래스 앱바 ───────────────────────────────────────────
            const _TimetableAppBar(),
            // ── 친구 드래그업 시트 ─────────────────────────────────────────
            _FriendsSheet(
              minSize: sheetMin,
              initialSize: sheetInitial,
              maxSize: _sheetMax,
              friends: friends,
              selectionMode: _selectionMode,
              selectedIds: _selectedFriendIds,
              onCompareTap: _enterSelectionMode,
              onToggle: _toggleSelection,
              onFriendTap: _openFriendTimetable,
              onCancel: _exitSelectionMode,
              onAddFriend: _openFriendAdd,
              pendingCount: pendingReqCount,
            ),
            // ── 다중 선택 시 하단 액션 바 ──────────────────────────────────
            if (_selectionMode)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _CompareActionBar(
                  count: _selectedFriendIds.length,
                  onCancel: _exitSelectionMode,
                  onCompare: _selectedFriendIds.isEmpty
                      ? null
                      : () => _openCommonFreeTime(timetable, friends),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// AppBar
// ═════════════════════════════════════════════════════════════════════════

/// 모든 sub-screen이 공통으로 사용하는 [SejongSubAppBar]를 그대로 사용.
/// 자체 박스/blur/border 코드를 두지 않음 — 글로벌 톤 변경은
/// `sejong_sub_app_bar.dart` 한 곳에서만 일어남.
class _TimetableAppBar extends StatelessWidget {
  const _TimetableAppBar();

  @override
  Widget build(BuildContext context) {
    // 우측 검색/더보기 버튼은 동작이 없어 제거 — 제목만.
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SejongSubAppBar(title: '시간표'),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// 학점 요약
// ═════════════════════════════════════════════════════════════════════════

class _CreditSummary extends StatelessWidget {
  const _CreditSummary({required this.timetable, this.enrolled});
  final Timetable timetable;

  /// SJPT 수강내역 요약(온라인·무수업일 포함). null이면 그리드 기반으로 폴백.
  final EnrolledSummary? enrolled;

  @override
  Widget build(BuildContext context) {
    // 수강내역이 **과목을 실제로 담고 있을 때만** 그것으로 표기(온라인·무수업일
    // 포함 정확값). 비었거나(SSO 실패·빈 응답·로딩) null이면 그리드(수업시간 있는
    // 강의)만 합산한 값으로 폴백 — 빈 수강내역이 그리드의 실제 과목수를 0으로
    // 덮어쓰지 않도록.
    final e = enrolled;
    final hasEnrolled = e != null && e.courseCount > 0;
    final count = hasEnrolled ? e.courseCount : timetable.courses.length;
    final creditsLabel = hasEnrolled
        ? e.totalCreditsLabel
        : '${timetable.totalCredits}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Row(
        children: [
          _SummaryBadge(icon: Symbols.menu_book, label: '$count과목'),
          const SizedBox(width: 8),
          _SummaryBadge(
            icon: Symbols.workspace_premium,
            label: '$creditsLabel학점',
          ),
          const Spacer(),
          Text(
            timetable.semester.label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              fontSize: 12,
              color: AppColors.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// 시간표 외 강의 (온라인·수업일 미등록) — SJPT 수강내역 기반
// ═════════════════════════════════════════════════════════════════════════

/// 그리드엔 안 뜨지만 학점에 포함되는 강의를 명시. 사용자가 "왜 시간표엔 5개인데
/// 학점은 더 많지?"를 한눈에 이해하도록 학점과 함께 나열.
class _OffGridSection extends StatelessWidget {
  const _OffGridSection({required this.summary});
  final EnrolledSummary summary;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '시간표 외 강의',
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '학점 합계 포함',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 10.5,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (summary.online.isNotEmpty)
            _OffGridGroup(
              label: '온라인 강좌',
              icon: Symbols.computer,
              courses: summary.online,
            ),
          if (summary.offlineNoSchedule.isNotEmpty) ...[
            if (summary.online.isNotEmpty) const SizedBox(height: 10),
            _OffGridGroup(
              label: '수업일 미지정',
              icon: Symbols.event_busy,
              courses: summary.offlineNoSchedule,
            ),
          ],
        ],
      ),
    );
  }
}

class _OffGridGroup extends StatelessWidget {
  const _OffGridGroup({
    required this.label,
    required this.icon,
    required this.courses,
  });
  final String label;
  final IconData icon;
  final List<EnrolledCourse> courses;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, fill: 1, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final c in courses)
          Padding(
            padding: const EdgeInsets.only(left: 19, bottom: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  c.creditsLabel,
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// 에러 배너 — 네트워크/캐시 실패 시 사용자에게 재시도 유도
// ═════════════════════════════════════════════════════════════════════════

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Symbols.error,
            fill: 1,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '시간표를 불러오지 못했어요. 잠시 후 다시 시도해주세요.',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => onRetry(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '다시 시도',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// 친구 바텀시트 — DraggableScrollableSheet 기반
// ═════════════════════════════════════════════════════════════════════════

class _FriendsSheet extends StatelessWidget {
  const _FriendsSheet({
    required this.minSize,
    required this.initialSize,
    required this.maxSize,
    required this.friends,
    required this.selectionMode,
    required this.selectedIds,
    required this.onCompareTap,
    required this.onToggle,
    required this.onFriendTap,
    required this.onCancel,
    required this.onAddFriend,
    this.pendingCount = 0,
  });

  final double minSize;
  final double initialSize;
  final double maxSize;
  final List<Friend> friends;
  final bool selectionMode;
  final Set<String> selectedIds;
  final VoidCallback onCompareTap;
  final ValueChanged<String> onToggle;
  final ValueChanged<Friend> onFriendTap;
  final VoidCallback onCancel;
  final VoidCallback onAddFriend;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      snap: true,
      snapSizes: [minSize, initialSize, maxSize],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.92),
              border: Border(
                top: BorderSide(
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
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                // peek 영역 — 핸들 + 헤더 (항상 보임)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _FriendsHeaderDelegate(
                    count: friends.length,
                    selectionMode: selectionMode,
                    selectedCount: selectedIds.length,
                    onCancel: onCancel,
                    onAddFriend: onAddFriend,
                    pendingCount: pendingCount,
                  ),
                ),
                // 공강 찾기 진입 타일 — 선택 모드 아닐 때만
                if (!selectionMode)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: _CompareEntryTile(onTap: onCompareTap),
                    ),
                  ),
                // 친구 리스트
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    // 선택 모드 action bar(48dp) + AppShell bottom nav 위에 여유
                    selectionMode ? 96 + BottomNavInsets.of(context) : 16,
                  ),
                  sliver: SliverList.separated(
                    itemCount: friends.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _FriendTile(
                      friend: friends[i],
                      selectionMode: selectionMode,
                      selected: selectedIds.contains(friends[i].id),
                      onTap: () => selectionMode
                          ? onToggle(friends[i].id)
                          : onFriendTap(friends[i]),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    // 마지막 friend tile이 AppShell bottom nav + system gesture
                    // bar 뒤로 숨지 않도록 두 인셋 모두 더함.
                    bottom:
                        12 +
                        MediaQuery.paddingOf(context).bottom +
                        BottomNavInsets.of(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 친구 리스트 상단에 항상 보이는 "공강 찾기" 글래스 타일.
class _CompareEntryTile extends StatelessWidget {
  const _CompareEntryTile({required this.onTap});
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
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.10),
                AppColors.primary.withValues(alpha: 0.04),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Symbols.auto_awesome,
                  size: 18,
                  fill: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '함께 비는 시간 찾기',
                      style: AppTypography.bodyMd.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '친구 여러 명 선택 → 공통 공강 한눈에',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 11.5,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right,
                size: 20,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 화면 하단에 떠 있는 다중 선택 액션 바.
class _CompareActionBar extends StatelessWidget {
  const _CompareActionBar({
    required this.count,
    required this.onCancel,
    required this.onCompare,
  });

  final int count;
  final VoidCallback onCancel;

  /// null이면 비활성 (선택 0명).
  final VoidCallback? onCompare;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.marginMobile,
        12,
        AppSpacing.marginMobile,
        12 + mq.padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
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
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: AppColors.outline.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Symbols.close,
                      size: 16,
                      color: AppColors.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '취소',
                      style: AppTypography.labelMd.copyWith(
                        fontSize: 13,
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onCompare,
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: onCompare == null
                        ? AppColors.outline.withValues(alpha: 0.5)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: onCompare == null
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.32),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.auto_awesome,
                        size: 16,
                        fill: 1,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        count == 0 ? '친구를 선택해 주세요' : '$count명 공강 찾기',
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FriendsHeaderDelegate({
    required this.count,
    required this.selectionMode,
    required this.selectedCount,
    required this.onCancel,
    required this.onAddFriend,
    this.pendingCount = 0,
  });
  final int count;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onAddFriend;
  final int pendingCount;

  static const double _h = 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: _h,
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: selectionMode
                ? Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onCancel,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Symbols.close,
                              size: 20,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '친구 선택',
                        style: AppTypography.headlineMd.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '$selectedCount명',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Symbols.group,
                        size: 18,
                        fill: 1,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '친구',
                        style: AppTypography.headlineMd.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '$count',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _InviteButton(
                        onTap: onAddFriend,
                        pendingCount: pendingCount,
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Symbols.keyboard_arrow_up,
                        size: 20,
                        color: AppColors.outline,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => _h;

  @override
  double get minExtent => _h;

  @override
  bool shouldRebuild(_FriendsHeaderDelegate oldDelegate) =>
      oldDelegate.count != count ||
      oldDelegate.selectionMode != selectionMode ||
      oldDelegate.selectedCount != selectedCount ||
      oldDelegate.pendingCount != pendingCount;
}

// 외부 초대 sheet (mockInviteCandidates 기반 카톡/문자 1회용 링크) 진입점.
// FriendAddScreen 도입으로 현재 미사용이지만, 외부(카톡/문자) 초대 흐름이
// 추후 살아날 때 재활용. 함수는 deliberate keep.
// ignore: unused_element
void _openInviteSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    useRootNavigator: true,
    builder: (_) => const _InviteSheet(),
  );
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({required this.onTap, this.pendingCount = 0});
  final VoidCallback onTap;

  /// 받은 친구 신청 수 — >0이면 버튼 우상단에 빨간 배지로 발견성 부여.
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingCount > 0;
    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(
              alpha: hasPending ? 0.12 : 0.08,
            ),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: AppColors.primary.withValues(
                alpha: hasPending ? 0.5 : 0.35,
              ),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Symbols.person_add,
                size: 14,
                fill: 1,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                hasPending ? '친구 추가' : '초대',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 11.5,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!hasPending) return button;
    // 우상단 배지 — 받은 신청 건수.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: -5,
          right: -5,
          child: Container(
            constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              pendingCount > 9 ? '9+' : '$pendingCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
  });

  final Friend friend;
  final bool selectionMode;
  final bool selected;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.surfaceContainerLowest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.5),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              if (selectionMode) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.outline.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? const Icon(Symbols.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
              ],
              _Avatar(seed: friend.avatarSeed, status: friend.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          friend.name,
                          style: AppTypography.bodyMd.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          friend.major,
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant.withValues(
                              alpha: 0.75,
                            ),
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: friend.status.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: friend.status.color.withValues(
                                alpha: 0.35,
                              ),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            friend.status.label,
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 10,
                              color: friend.status.color,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                        if (friend.currentActivity != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              friend.currentActivity!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (friend.nextSlot != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        friend.nextSlot!,
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10.5,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                selectionMode ? Symbols.chevron_right : Symbols.chevron_right,
                size: 18,
                color: AppColors.outline.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.seed, required this.status});
  final int seed;
  final FriendStatus status;

  static const _gradients = AppSubjectPalette.gradients;

  @override
  Widget build(BuildContext context) {
    final g = _gradients[seed % _gradients.length];
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: g,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Symbols.person,
              size: 22,
              fill: 1,
              color: Colors.white,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// 친구 초대 모달 시트
// ═════════════════════════════════════════════════════════════════════════

class _InviteSheet extends StatefulWidget {
  const _InviteSheet();

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<InviteCandidate> _results = const [];
  final Set<String> _sentTo = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _query = q;
        _searching = false;
        _results = const [];
      });
      return;
    }
    setState(() {
      _query = q;
      _searching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 320), () {
      final low = q.toLowerCase();
      final hits = mockInviteCandidates.where((c) {
        return c.name.toLowerCase().contains(low) ||
            c.studentIdMasked.contains(low);
      }).toList();
      if (!mounted) return;
      setState(() {
        _results = hits;
        _searching = false;
      });
    });
  }

  void _handleAction(InviteCandidate c) {
    HapticFeedback.lightImpact();
    setState(() => _sentTo.add(c.id));
    final messenger = ScaffoldMessenger.maybeOf(context);
    final msg = c.kind == InviteCandidateKind.registered
        ? '${c.name}님에게 친구 요청을 보냈어요'
        : '${c.name}님 초대 링크가 공유 시트에 열렸어요';
    messenger?.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final registered = _results
            .where((c) => c.kind == InviteCandidateKind.registered)
            .toList();
        final unregistered = _results
            .where((c) => c.kind == InviteCandidateKind.unregistered)
            .toList();

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.92),
              border: Border(
                top: BorderSide(
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
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: _InviteHeader(
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _InviteSearchField(
                      controller: _controller,
                      onChanged: _onChanged,
                    ),
                  ),
                ),
                if (_query.length < 2)
                  SliverToBoxAdapter(child: _InviteHint())
                else if (_searching)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_results.isEmpty)
                  const SliverToBoxAdapter(child: _InviteEmpty())
                else ...[
                  if (registered.isNotEmpty)
                    _InviteSectionSliver(
                      kind: InviteCandidateKind.registered,
                      candidates: registered,
                      sentTo: _sentTo,
                      onAction: _handleAction,
                    ),
                  if (unregistered.isNotEmpty)
                    _InviteSectionSliver(
                      kind: InviteCandidateKind.unregistered,
                      candidates: unregistered,
                      sentTo: _sentTo,
                      onAction: _handleAction,
                    ),
                ],
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    24 + mq.viewInsets.bottom + mq.padding.bottom,
                  ),
                  sliver: const SliverToBoxAdapter(child: _InvitePolicy()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InviteHeader extends StatelessWidget {
  const _InviteHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.outline.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            children: [
              const Icon(
                Symbols.person_add,
                size: 22,
                fill: 1,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '친구 초대',
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
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Symbols.close,
                      size: 22,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Text(
            '이름 또는 학번으로 검색하면 가입자에겐 인앱 요청을,\n'
            '미가입 학생에겐 외부로 초대 링크를 보낼 수 있어요.',
            style: AppTypography.labelSm.copyWith(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              height: 1.45,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _InviteSearchField extends StatelessWidget {
  const _InviteSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ambientShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Symbols.search, size: 20, color: AppColors.outline),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: AppTypography.bodyMd.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: '이름 또는 학번',
                hintStyle: AppTypography.bodyMd.copyWith(
                  fontSize: 15,
                  color: AppColors.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Symbols.cancel,
                  size: 18,
                  fill: 1,
                  color: AppColors.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InviteHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final examples = ['김민지', '2021', '윤지아', '소프트웨어'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Symbols.lightbulb,
                size: 14,
                fill: 1,
                color: AppColors.primary.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 6),
              Text(
                '예시 검색어',
                style: AppTypography.labelSm.copyWith(
                  fontSize: 11.5,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final e in examples) _ExampleChip(label: e)],
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          fontSize: 11.5,
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
  }
}

class _InviteEmpty extends StatelessWidget {
  const _InviteEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(
            Symbols.search_off,
            size: 36,
            color: AppColors.outline.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(
            '검색 결과가 없어요',
            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '학번 또는 이름이 정확히 일치해야 검색됩니다.',
              textAlign: TextAlign.center,
              style: AppTypography.labelSm.copyWith(
                fontSize: 11.5,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteSectionSliver extends StatelessWidget {
  const _InviteSectionSliver({
    required this.kind,
    required this.candidates,
    required this.sentTo,
    required this.onAction,
  });

  final InviteCandidateKind kind;
  final List<InviteCandidate> candidates;
  final Set<String> sentTo;
  final ValueChanged<InviteCandidate> onAction;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                      color: kind == InviteCandidateKind.registered
                          ? AppColors.primary
                          : AppColors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    kind.sectionLabel,
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 12,
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${candidates.length}명',
                    style: AppTypography.labelSm.copyWith(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < candidates.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppColors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    _InviteRow(
                      candidate: candidates[i],
                      sent: sentTo.contains(candidates[i].id),
                      onAction: () => onAction(candidates[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.candidate,
    required this.sent,
    required this.onAction,
  });

  final InviteCandidate candidate;
  final bool sent;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          _Avatar(
            seed: candidate.avatarSeed,
            // 미가입자는 회색조 dot — 가입자는 emerald (활성)
            status: candidate.kind == InviteCandidateKind.registered
                ? FriendStatus.free
                : FriendStatus.offline,
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
                      candidate.name,
                      style: AppTypography.bodyMd.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      candidate.studentIdMasked,
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.75,
                        ),
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  candidate.major,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 11.5,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _InviteActionButton(
            kind: candidate.kind,
            sent: sent,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

class _InviteActionButton extends StatelessWidget {
  const _InviteActionButton({
    required this.kind,
    required this.sent,
    required this.onTap,
  });

  final InviteCandidateKind kind;
  final bool sent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (sent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: AppColors.outline.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.check, size: 13, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 3),
            Text(
              '보냄',
              style: AppTypography.labelSm.copyWith(
                fontSize: 11.5,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ],
        ),
      );
    }
    final isRegistered = kind == InviteCandidateKind.registered;
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
            color: isRegistered ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: AppColors.primary, width: 1),
            boxShadow: isRegistered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRegistered ? Symbols.person_add : Symbols.share,
                size: 13,
                fill: 1,
                color: isRegistered ? AppColors.onPrimary : AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                kind.actionLabel,
                style: AppTypography.labelSm.copyWith(
                  fontSize: 11.5,
                  color: isRegistered ? AppColors.onPrimary : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitePolicy extends StatelessWidget {
  const _InvitePolicy();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Symbols.shield_person,
            size: 18,
            fill: 1,
            color: AppColors.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '검색 정책',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 12,
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '• 학번/이름이 정확히 일치해야 결과가 표시돼요\n'
                  '• 학번은 항상 가운데가 마스킹된 형태로만 보여요\n'
                  '• 분당 5회까지 검색할 수 있어요',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 11.5,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    letterSpacing: 0.1,
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
