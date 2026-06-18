import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/cafeteria/data/datasources/cafeteria_settings_storage.dart';
import 'package:sejong_smart_campus/features/cafeteria/domain/entities/food_models.dart';
import 'package:sejong_smart_campus/features/cafeteria/domain/entities/happydorm_models.dart';
import 'package:sejong_smart_campus/features/cafeteria/presentation/providers/cafeteria_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

/// 학식 화면.
///
/// 구조:
///   - 상단 AppBar (뒤로 + "학식")
///   - 건물 탭 (군자관/진관홀/학생회관)
///   - 날짜 셀렉터 (← 오늘 →)
///   - place별 카드 — MEAL_TIME은 끼니 탭 + 메뉴, STATIC_MENU는 안내 메시지
class CafeteriaScreen extends ConsumerStatefulWidget {
  const CafeteriaScreen({super.key});

  @override
  ConsumerState<CafeteriaScreen> createState() => _CafeteriaScreenState();
}

class _CafeteriaScreenState extends ConsumerState<CafeteriaScreen> {
  bool _onboardingShown = false;

  Future<void> _onRefresh() async {
    ref.invalidate(buildingsProvider);
    final buildingId = ref.read(selectedBuildingIdProvider);
    final futures = <Future<void>>[
      Future<void>.delayed(const Duration(milliseconds: 300)),
      ref.read(buildingsProvider.future).then((_) {}),
    ];
    if (buildingId != null && buildingId != happydormVirtualBuildingId) {
      ref.invalidate(placesForBuildingProvider(buildingId));
      futures.add(
        ref.read(placesForBuildingProvider(buildingId).future).then((_) {}),
      );
    }
    // 행복기숙사 — 현재 보고 있는 주의 식단만 새로고침.
    final date = ref.read(selectedDateProvider);
    final weekKey = mondayOfWeek(date);
    ref.invalidate(happydormWeeklyMenuProvider(weekKey));
    futures.add(
      ref.read(happydormWeeklyMenuProvider(weekKey).future).then((_) {}),
    );
    try {
      await Future.wait(futures);
    } catch (_) {
      // Refresh indicator는 실제 요청 종료 후 닫고, 오류 표시는 각 provider UI에 맡긴다.
    }
  }

  /// 첫 진입 시 preference 가 null 이면 온보딩 다이얼로그 표시 (세션당 1회).
  void _maybeShowOnboarding() {
    if (_onboardingShown) return;
    final prefAsync = ref.read(cafeteriaPreferenceProvider);
    final pref = prefAsync.value;
    // 아직 로딩 중이거나 이미 설정됨.
    if (prefAsync.isLoading || pref != null) {
      if (pref != null) _onboardingShown = true;
      return;
    }
    _onboardingShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showCafeteriaPreferenceSheet(context, ref, isOnboarding: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final buildingsAsync = ref.watch(buildingsProvider);
    // preference load 완료 후 첫 빌드에서 미설정이면 다이얼로그.
    ref.watch(cafeteriaPreferenceProvider);
    _maybeShowOnboarding();
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
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(height: mq.padding.top + 64 + 8),
                    ),
                    // buildings(sjapp) 응답이 느려도 행복기숙사 가상 탭은 즉시
                    // 표시 — 사용자가 happydorm 식단을 바로 볼 수 있도록 한다.
                    // sjapp 응답이 도착하면 빈 자리에 군자관/진관홀/학생회관이
                    // 자연스럽게 합쳐진다. error는 strip 위에 작은 retry chip.
                    SliverToBoxAdapter(
                      child: _BuildingsStrip(
                        buildings: buildingsAsync.value ?? const [],
                        loading: buildingsAsync.isLoading,
                        hasError: buildingsAsync.hasError,
                        onRetry: _onRefresh,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    const SliverToBoxAdapter(child: _DatePicker()),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.marginMobile,
                      ),
                      sliver: const SliverToBoxAdapter(child: _PlacesList()),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: 120 + mq.padding.bottom),
                    ),
                  ],
                ),
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: _CafeteriaAppBar(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AppBar ────────────────────────────────────────────────────────────────

class _CafeteriaAppBar extends ConsumerWidget {
  const _CafeteriaAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SejongSubAppBar(
      title: '학식',
      actions: [
        IconButton(
          tooltip: '기본 식당 변경',
          icon: const Icon(Symbols.tune, color: AppColors.onSurface, size: 22),
          onPressed: () => showCafeteriaPreferenceSheet(context, ref),
          splashRadius: 22,
        ),
      ],
    );
  }
}

// ─── 건물 strip ─────────────────────────────────────────────────────────────

class _BuildingsStrip extends ConsumerStatefulWidget {
  const _BuildingsStrip({
    required this.buildings,
    this.loading = false,
    this.hasError = false,
    this.onRetry,
  });
  final List<CafeteriaBuilding> buildings;
  final bool loading;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  ConsumerState<_BuildingsStrip> createState() => _BuildingsStripState();
}

class _BuildingsStripState extends ConsumerState<_BuildingsStrip> {
  bool _userSelectedBuilding = false;
  CafeteriaPreference? _lastSeenPreference;

  /// 군자관 → 행복기숙사 → 진관홀 → 학생회관 순서.
  /// sjapp이 주는 building 목록(보통 군자관·진관홀·학생회관)에 행복기숙사를
  /// 가상 항목으로 끼워넣되, "군자관" 바로 뒤에 위치하도록 정렬한다.
  /// 일치하는 군자관 이름이 없으면(이름 변경 등 예외)/아직 buildings 응답이
  /// 안 왔으면 맨 앞에 추가.
  List<CafeteriaBuilding> _withHappydorm(List<CafeteriaBuilding> raw) {
    const happydorm = CafeteriaBuilding(
      id: happydormVirtualBuildingId,
      name: happydormBuildingName,
      location: '',
    );
    final list = [...raw];
    final gunjaIdx = list.indexWhere((b) => b.name.contains('군자관'));
    if (gunjaIdx == -1) {
      list.insert(0, happydorm);
    } else {
      list.insert(gunjaIdx + 1, happydorm);
    }
    return list;
  }

  /// 첫 진입 자동 선택. 우선순위:
  ///   1) 사용자 preference (`cafeteriaPreferenceProvider`) — 한 번 설정하면 항상
  ///   2) 아직 buildings 없음 → 행복기숙사 (sjapp 무관, 즉시 조회 가능)
  ///   3) 주말 → 행복기숙사
  ///   4) 평일 + buildings 도착 → 첫 sjapp 건물 (보통 군자관)
  void _autoSelectIfNeeded() {
    final cur = ref.read(selectedBuildingIdProvider);
    final merged = _withHappydorm(widget.buildings);
    if (merged.isEmpty) return;

    // preference 가 아직 로딩 중이면 대기 — build watch 가 도착 시 재호출.
    final prefAsync = ref.read(cafeteriaPreferenceProvider);
    if (prefAsync.isLoading) return;

    // (1) preference 우선.
    final pref = prefAsync.value;
    if (pref != _lastSeenPreference) {
      _lastSeenPreference = pref;
      _userSelectedBuilding = false;
    }
    if (pref != null) {
      if (_userSelectedBuilding) return;
      final desiredId = _preferredBuildingId(pref);
      if (cur != desiredId) {
        ref.read(selectedBuildingIdProvider.notifier).value = desiredId;
      }
      return;
    }

    if (cur != null) return;

    // (2~4) preference 없음 → 기존 휴리스틱.
    final today = ref.read(selectedDateProvider);
    final hasRealBuilding = widget.buildings.isNotEmpty;
    final pickHappydorm =
        !hasRealBuilding ||
        (isWeekend(today) &&
            merged.any((b) => b.id == happydormVirtualBuildingId));
    ref.read(selectedBuildingIdProvider.notifier).value = pickHappydorm
        ? happydormVirtualBuildingId
        : merged.first.id;
  }

  int _preferredBuildingId(CafeteriaPreference pref) {
    switch (pref) {
      case CafeteriaPreference.happydorm:
        return happydormVirtualBuildingId;
      case CafeteriaPreference.gunja:
        // 군자관 — sjapp buildings 도착 전이면 happydorm fallback을 임시 표시.
        // 이후 buildings가 도착하면 _userSelectedBuilding=false 상태에서 다시
        // 호출되어 군자관 id로 교체된다.
        if (widget.buildings.isEmpty) return happydormVirtualBuildingId;
        final gunja = widget.buildings.firstWhere(
          (b) => b.name.contains('군자관'),
          orElse: () => widget.buildings.first,
        );
        return gunja.id;
    }
  }

  void _selectBuilding(int id) {
    _userSelectedBuilding = true;
    ref.read(selectedBuildingIdProvider.notifier).value = id;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectIfNeeded());
  }

  @override
  void didUpdateWidget(covariant _BuildingsStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // buildings 응답이 늦게 도착하면 저장 선호 기준으로 다시 선택한다.
    // 사용자가 직접 칩을 누른 경우에는 _autoSelectIfNeeded가 건드리지 않는다.
    if (oldWidget.buildings.length != widget.buildings.length) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _autoSelectIfNeeded(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedBuildingIdProvider);
    // preference 가 늦게 도착할 수 있어 build 마다 watch + auto-select 재시도.
    // 사용자가 직접 칩을 누르기 전까지는 저장 선호가 우선한다.
    ref.watch(cafeteriaPreferenceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectIfNeeded());
    final merged = _withHappydorm(widget.buildings);
    // buildings 아직 로딩 중이면 끝에 shimmer placeholder 3개로 자리를 잡아둠.
    final placeholderCount = widget.loading && widget.buildings.isEmpty ? 3 : 0;
    final total = merged.length + placeholderCount;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
        ),
        itemCount: total,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i >= merged.length) {
            return const Shimmer(
              child: ShimmerBox(width: 96, height: 36, radius: AppRadius.full),
            );
          }
          final b = merged[i];
          final selected = b.id == selectedId;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: () => _selectBuilding(b.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors.outline.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.name,
                      style: AppTypography.labelMd.copyWith(
                        color: selected
                            ? AppColors.onPrimary
                            : AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (b.location.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        b.location,
                        style: AppTypography.labelSm.copyWith(
                          color: selected
                              ? AppColors.onPrimary.withValues(alpha: 0.85)
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── 날짜 셀렉터 ────────────────────────────────────────────────────────────

class _DatePicker extends ConsumerWidget {
  const _DatePicker();

  static const _weekKor = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final today = DateTime.now();
    final isToday = _sameDay(date, today);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Row(
        children: [
          _ArrowButton(
            icon: Symbols.chevron_left,
            onTap: () => ref.read(selectedDateProvider.notifier).value = date
                .subtract(const Duration(days: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isToday
                    ? null
                    : () => ref.read(selectedDateProvider.notifier).value =
                          DateTime.now(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.month}월 ${date.day}일 (${_weekKor[date.weekday - 1]})',
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '오늘',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onPrimary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ArrowButton(
            icon: Symbols.chevron_right,
            onTap: () => ref.read(selectedDateProvider.notifier).value = date
                .add(const Duration(days: 1)),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 22, color: AppColors.onSurface),
        ),
      ),
    );
  }
}

// ─── place + 메뉴 리스트 ────────────────────────────────────────────────────

class _PlacesList extends ConsumerWidget {
  const _PlacesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildingId = ref.watch(selectedBuildingIdProvider);
    // 첫 진입 — 아직 건물 선택 전 → 메뉴 카드 자리를 스켈레톤으로 채움.
    if (buildingId == null) return const _PlacesSkeleton();
    // 행복기숙사 — sjapp 트리에 없는 가상 건물. 별도 본문.
    if (buildingId == happydormVirtualBuildingId) {
      return const _HappydormBody();
    }
    final placesAsync = ref.watch(placesForBuildingProvider(buildingId));
    return placesAsync.when(
      loading: () => const _PlacesSkeleton(),
      error: (_, _) => _ErrorCard(
        message: '식당 목록을 불러오지 못했어요',
        onRetry: () => ref.invalidate(placesForBuildingProvider(buildingId)),
      ),
      data: (places) {
        if (places.isEmpty) {
          return const _EmptyCard(message: '운영 중인 식당이 없어요');
        }
        return Column(
          children: [
            for (final p in places) ...[
              _PlaceCard(place: p),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({required this.place});
  final CafeteriaPlace place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.restaurant,
                fill: 1,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  place.name,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  place.operation == PlaceOperation.mealTime
                      ? '일자별 운영'
                      : '고정 메뉴',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (place.operation == PlaceOperation.mealTime)
            _MealTimeBody(place: place)
          else
            _StaticMenuBody(placeId: place.id),
        ],
      ),
    );
  }
}

class _MealTimeBody extends ConsumerWidget {
  const _MealTimeBody({required this.place});
  final CafeteriaPlace place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final schedulesAsync = ref.watch(
      schedulesForPlaceDateProvider((
        placeId: place.id,
        date: formatDateKey(date),
      )),
    );
    return schedulesAsync.when(
      loading: () => const _MealTimeSkeleton(),
      error: (_, _) => Text(
        '메뉴를 불러오지 못했어요',
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      data: (schedules) {
        if (schedules.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                '이 날의 메뉴가 없어요',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final s in schedules) _ScheduleCard(summary: s)],
        );
      },
    );
  }
}

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({required this.summary});
  final MealScheduleSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(scheduleDetailProvider(summary.scheduleId));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 헤더 — 끼니 + 가격 + 메뉴 개수
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    summary.mealTypeName,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${summary.menuCount}품',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (summary.totalPriceVisible && summary.totalPrice > 0)
                  Text(
                    '${summary.totalPrice}원',
                    style: AppTypography.labelMd.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          // 메뉴 list — 단순 텍스트 ("- 아이템\n- 아이템…")
          detailAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _MenuLinesSkeleton(),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                '상세 메뉴를 불러오지 못했어요',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            data: (d) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  d.menus.map((m) => '- ${m.menuName}').join('\n'),
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                    color: AppColors.onSurface,
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

class _StaticMenuBody extends ConsumerWidget {
  const _StaticMenuBody({required this.placeId});
  final int placeId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staticMenusForPlaceProvider(placeId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: _StaticMenuSkeleton(),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          '메뉴를 불러오지 못했어요',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '등록된 메뉴가 없어요',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final m in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        m.menuName,
                        style: AppTypography.labelMd.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${m.defaultPrice}원',
                      style: AppTypography.labelMd.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── 행복기숙사 ─────────────────────────────────────────────────────────────
//
// 서버 트리에 없는 건물. 별도 provider로 받아오되 카드 모양은 다른 식당과
// 동일하게 [GlassCard] + 끼니별 sub-card 로 통일.

class _HappydormBody extends ConsumerWidget {
  const _HappydormBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final weekly = ref.watch(happydormWeeklyMenuProvider(mondayOfWeek(date)));
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Symbols.restaurant,
                fill: 1,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '행복기숙사',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '주간 식단',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          weekly.when(
            loading: () => const _MealTimeSkeleton(),
            error: (_, _) => Text(
              '메뉴를 불러오지 못했어요',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            data: (data) =>
                _HappydormDay(menu: data.forDate(formatDateKey(date))),
          ),
        ],
      ),
    );
  }
}

class _HappydormDay extends StatelessWidget {
  const _HappydormDay({required this.menu});
  final HappydormDayMenu? menu;

  @override
  Widget build(BuildContext context) {
    if (menu == null || !menu!.hasAnyMeal) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            '아직 기숙사에서 식단을 업로드하지 않았습니다',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final m = menu!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HappydormMeal(label: '조식', body: m.breakfast),
        _HappydormMeal(label: '중식', body: m.lunch),
        _HappydormMeal(label: '석식', body: m.dinner),
      ],
    );
  }
}

class _HappydormMeal extends StatelessWidget {
  const _HappydormMeal({required this.label, required this.body});
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = HappydormDayMenu.tokenize(body);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    label,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (tokens.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${tokens.length}품',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tokens.isEmpty
                    ? '식단이 등록되지 않았어요'
                    : tokens.map((t) => '- $t').join('\n'),
                style: AppTypography.labelSm.copyWith(
                  fontSize: 13,
                  fontWeight: tokens.isEmpty
                      ? FontWeight.w500
                      : FontWeight.w600,
                  height: 1.55,
                  color: tokens.isEmpty
                      ? AppColors.onSurfaceVariant
                      : AppColors.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 스켈레톤 ───────────────────────────────────────────────────────────────
//
// 모든 로딩 상태는 동일한 시각 언어로: layout-우선 + 회색 placeholder +
// shimmer sweep. 첫 진입에 spinner 없이 바로 [_PlacesSkeleton] 카드들이
// 뜨고, 데이터가 도착하면 그 자리에서 실제 컴포넌트로 자연스럽게 교체된다.
// (건물 strip은 행복기숙사 가상 탭을 즉시 보여주므로 별도 스켈레톤 X —
// [_BuildingsStrip] 내부에서 sjapp 응답 대기 중에는 끝에 shimmer chip을 채움.)

class _PlacesSkeleton extends StatelessWidget {
  const _PlacesSkeleton();
  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: const [
          _PlaceCardSkeleton(),
          SizedBox(height: 12),
          _PlaceCardSkeleton(),
        ],
      ),
    );
  }
}

class _PlaceCardSkeleton extends StatelessWidget {
  const _PlaceCardSkeleton();
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Row(
            children: [
              ShimmerBox(width: 20, height: 20, radius: 4),
              SizedBox(width: 8),
              ShimmerBox(width: 90, height: 14),
              Spacer(),
              ShimmerBox(width: 70, height: 22, radius: AppRadius.full),
            ],
          ),
          SizedBox(height: 14),
          _ScheduleCardSkeleton(),
          SizedBox(height: 10),
          _ScheduleCardSkeleton(),
        ],
      ),
    );
  }
}

class _MealTimeSkeleton extends StatelessWidget {
  const _MealTimeSkeleton();
  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _ScheduleCardSkeleton(),
          SizedBox(height: 10),
          _ScheduleCardSkeleton(),
        ],
      ),
    );
  }
}

class _ScheduleCardSkeleton extends StatelessWidget {
  const _ScheduleCardSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Row(
            children: [
              ShimmerBox(width: 44, height: 20, radius: AppRadius.full),
              SizedBox(width: 8),
              ShimmerBox(width: 32, height: 12),
              Spacer(),
              ShimmerBox(width: 56, height: 14),
            ],
          ),
          SizedBox(height: 12),
          _MenuLinesSkeleton(),
        ],
      ),
    );
  }
}

/// "- 아이템" 4줄짜리 회색 라인. 폭은 진짜 메뉴명처럼 들쭉날쭉.
class _MenuLinesSkeleton extends StatelessWidget {
  const _MenuLinesSkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        ShimmerBox(width: 160, height: 12),
        SizedBox(height: 8),
        ShimmerBox(width: 200, height: 12),
        SizedBox(height: 8),
        ShimmerBox(width: 140, height: 12),
        SizedBox(height: 8),
        ShimmerBox(width: 180, height: 12),
      ],
    );
  }
}

class _StaticMenuSkeleton extends StatelessWidget {
  const _StaticMenuSkeleton();
  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: const [
          _StaticRowSkeleton(),
          SizedBox(height: 10),
          _StaticRowSkeleton(),
          SizedBox(height: 10),
          _StaticRowSkeleton(),
        ],
      ),
    );
  }
}

class _StaticRowSkeleton extends StatelessWidget {
  const _StaticRowSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: ShimmerBox(height: 13)),
        SizedBox(width: 12),
        ShimmerBox(width: 50, height: 13),
      ],
    );
  }
}

// ─── 공통 ───────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
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

// ─── 기본 식당 설정 시트 ─────────────────────────────────────────────────────

/// 최초 진입 온보딩 + 우측 상단 설정 버튼이 모두 호출하는 시트.
/// [isOnboarding] = true 면 "처음 환영" 카피로 한정, 다이얼로그 dismiss 막음.
Future<void> showCafeteriaPreferenceSheet(
  BuildContext context,
  WidgetRef ref, {
  bool isOnboarding = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: !isOnboarding,
    enableDrag: !isOnboarding,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CafeteriaPreferenceSheet(isOnboarding: isOnboarding),
  );
}

class _CafeteriaPreferenceSheet extends ConsumerWidget {
  const _CafeteriaPreferenceSheet({required this.isOnboarding});
  final bool isOnboarding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final currentPref = ref.watch(cafeteriaPreferenceProvider).value;
    return PopScope(
      canPop: !isOnboarding,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 20 + mq.padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Symbols.restaurant_menu,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isOnboarding ? '기본 식당을 골라주세요' : '기본 식당 변경',
                    style: AppTypography.headlineMd.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isOnboarding
                  ? '학식 화면을 열 때마다 자동으로 보여줄 식당이에요.\n나중에 우측 상단에서 다시 바꿀 수 있어요.'
                  : '학식 화면을 열 때마다 자동으로 보여줄 식당이에요.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _PrefOption(
              icon: Symbols.school,
              label: '군자관 위주로',
              subtitle: '평일 강의 시간에 주로 이용해요',
              selected: currentPref == CafeteriaPreference.gunja,
              onTap: () async {
                await ref
                    .read(cafeteriaPreferenceProvider.notifier)
                    .set(CafeteriaPreference.gunja);
                await _applyImmediately(ref, CafeteriaPreference.gunja);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
            _PrefOption(
              icon: Symbols.bed,
              label: '행복기숙사 위주로',
              subtitle: '기숙사 거주자, 주말에도 운영',
              selected: currentPref == CafeteriaPreference.happydorm,
              onTap: () async {
                await ref
                    .read(cafeteriaPreferenceProvider.notifier)
                    .set(CafeteriaPreference.happydorm);
                await _applyImmediately(ref, CafeteriaPreference.happydorm);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 선택 직후 selectedBuildingId 즉시 갱신 — 사용자가 시트 닫자마자 새 건물
  /// 화면 진입.
  Future<void> _applyImmediately(
    WidgetRef ref,
    CafeteriaPreference pref,
  ) async {
    if (pref == CafeteriaPreference.happydorm) {
      ref.read(selectedBuildingIdProvider.notifier).value =
          happydormVirtualBuildingId;
      return;
    }
    // 군자관 — sjapp buildings 가 아직 없으면 happydorm fallback (응답 도착 후
    // _autoSelectIfNeeded 가 다시 군자관으로 잡지 못하므로 직접 전환 유도).
    final buildingsAsync = ref.read(buildingsProvider);
    final buildings = buildingsAsync.value ?? const [];
    if (buildings.isEmpty) {
      ref.read(selectedBuildingIdProvider.notifier).value =
          happydormVirtualBuildingId;
      // buildings 응답 도착 후 군자관으로 옮기는 건 사용자가 직접.
      return;
    }
    final gunja = buildings.firstWhere(
      (b) => b.name.contains('군자관'),
      orElse: () => buildings.first,
    );
    ref.read(selectedBuildingIdProvider.notifier).value = gunja.id;
  }
}

class _PrefOption extends StatelessWidget {
  const _PrefOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.outline.withValues(alpha: 0.3),
              width: selected ? 1.6 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                fill: 1,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primary
                            : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Symbols.check_circle,
                  size: 22,
                  color: AppColors.primary,
                  fill: 1,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
