import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/home/domain/entities/event_card.dart';
import 'package:sejong_smart_campus/features/home/presentation/providers/home_events_providers.dart';
import 'package:sejong_smart_campus/features/home_widgets/presentation/providers/home_widgets_providers.dart';
import 'package:sejong_smart_campus/features/app_update/presentation/widgets/recommended_update_home_prompt.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/library/presentation/widgets/seat_card.dart';
import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/features/home/presentation/providers/quick_actions_providers.dart';
import 'package:sejong_smart_campus/features/home/presentation/widgets/hero_slot.dart';
import 'package:sejong_smart_campus/features/home/presentation/widgets/lecture_context_row.dart';
import 'package:sejong_smart_campus/features/home/presentation/widgets/library_status_strip.dart';
import 'package:sejong_smart_campus/features/home/presentation/widgets/quick_actions_grid.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_app_bar.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/features/timetable/domain/next_lecture.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/providers/timetable_providers.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/timetable_sync_provider.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/screens/timetable_screen.dart';
import 'package:sejong_smart_campus/features/home_widgets/presentation/widgets/sejong_news_preview.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';
import 'package:sejong_smart_campus/features/notices/presentation/providers/notice_providers.dart';
import 'package:sejong_smart_campus/features/notices/presentation/screens/notices_screen.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/screens/notifications_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  /// 좌석 발권 상태를 주기적으로 다시 확인하는 폴링 — 사용자가 다른 위치(웹/
  /// 다른 단말)에서 발권/반납해도 30초 안에 홈 카드가 반영. OneUI 표준
  /// 위젯들(날씨/캘린더)도 30s~60s polling이라 배터리/네트워크 부담 적정.
  /// foreground 상태일 때만 동작 — [didChangeAppLifecycleState]가 paused에서
  /// 정지하고 resumed에서 재개.
  static const _mySeatPollInterval = Duration(seconds: 30);
  Timer? _mySeatPoll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMySeatPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_onRefresh());
    });
  }

  @override
  void dispose() {
    _stopMySeatPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱이 백그라운드/잠자기에서 돌아올 때 모든 source 새로고침.
  /// OneUI 사용자는 멀티태스킹/홈버튼/잠자기 후 복귀 시 데이터가 최신화돼
  /// 있을 거라 기대 — 삼성 자체 앱(인터넷·캘린더·날씨)이 모두 이 패턴.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onRefresh();
      _startMySeatPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stopMySeatPolling();
    }
  }

  void _startMySeatPolling() {
    _mySeatPoll?.cancel();
    _mySeatPoll = Timer.periodic(_mySeatPollInterval, (_) {
      if (!mounted) return;
      unawaited(ref.read(libseatSyncProvider).sync(reason: 'homePoll'));
    });
  }

  void _stopMySeatPolling() {
    _mySeatPoll?.cancel();
    _mySeatPoll = null;
  }

  Future<void> _onRefresh() async {
    // 홈에 표시되는 모든 source 강제 새로고침 — pull-to-refresh의 계약이자
    // lifecycle resumed 시 자동 호출 경로. 위에서 아래 순서대로:
    // AppBar 알림 → Hero(이벤트/좌석) → 다음 강의 → 실시간 열람실 →
    // 대학 공지 → 세종 소식.
    final semester = _currentSemester(DateTime.now());
    ref.invalidate(unreadCountProvider);
    ref.invalidate(mySeatProvider);
    // 이벤트 카드(Supabase home_events) — 관리자가 서버에서 바꾸면 새로고침에 반영.
    // SWR 캐시라 build()는 캐시를 즉시 반환하고 버전 체크는 백그라운드(_revalidate)에서
    // 돈다 — 그래서 .future를 기다려도 버전 확인까지 막지는 않는다(내용 바뀌었으면 곧 반영).
    ref.invalidate(homeEventsProvider);
    // 홈 위젯 배너(sjapp 미러)도 함께 갱신.
    ref.invalidate(homeBannersProvider);
    ref.invalidate(timetableForSemesterProvider(semester));
    ref.invalidate(roomListProvider);
    ref.invalidate(homeNoticePreviewProvider);
    ref.invalidate(sejongNewsProvider);

    // 스피너를 "고정 지연"이 아니라 **실제 네트워크 응답이 올 때까지** 유지한다.
    // 예전엔 invalidate만 하고 0.4초 뒤 무조건 스피너를 닫아서, 응답이 그보다
    // 느리면 "당겨도 애니메이션만 돌고 안 바뀐다"는 인상을 줬다. 이제 각 source의
    // 재요청 future를 직접 기다린다 — 하나가 느리거나 실패해도 8초 타임아웃으로
    // 끊고, 최소 300ms는 노출해 짧은 응답에서 스피너가 깜빡이지 않게 한다.
    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: 300)),
      ref
          .read(libseatSyncProvider)
          .sync(reason: 'homeRefresh')
          .then<void>((_) {}),
      _refetch(ref.read(homeEventsProvider.future)),
      _refetch(ref.read(roomListProvider.future)),
      _refetch(ref.read(homeNoticePreviewProvider.future)),
      _refetch(ref.read(sejongNewsProvider.future)),
      _refetch(ref.read(mySeatProvider.future)),
      _refetch(ref.read(timetableForSemesterProvider(semester).future)),
    ]);
  }

  /// 개별 source의 재요청을 기다리되 실패/타임아웃은 삼킨다 — 한 source가
  /// 죽어도 나머지 새로고침과 스피너 종료가 막히지 않도록.
  Future<void> _refetch(Future<Object?> future) async {
    try {
      await future.timeout(const Duration(seconds: 8));
    } catch (_) {
      // 개별 실패/타임아웃 무시 — 해당 위젯은 자체 error 상태를 그린다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final semester = _currentSemester(now);
    // 현재 학기 시간표가 fetch될 때마다 Supabase에 자동 백업.
    // 친구가 내 시간표를 공유받기 위한 토대.
    useTimetableSync(ref, semester);
    // 로그인/재시작 후 1회 — 모든 가용 학기 시간표를 한 번에 백업해 친구가 어떤
    // 학기든 열람할 수 있게 한다(현재 학기만 올리는 위 sync 보완).
    useAllSemestersBackup(ref);
    final tt = ref.watch(timetableForSemesterProvider(semester));
    final courses = tt.value?.courses ?? const <Course>[];
    final next = findNextLectureToday(courses, now);
    final remaining = remainingLecturesToday(courses, now);
    final lectureState = _deriveLectureState(tt, courses, now, next);

    // 이벤트 카드 — 부트스트랩에서 prefetch됨. 좌석(front)도 같은 Hero 슬롯 공유.
    final eventsAsync = ref.watch(homeEventsProvider);
    final events = eventsAsync.value ?? const <EventCard>[];
    final heroFront = _buildHeroFront(lectureState, next);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: SejongRefresh(
              onRefresh: _onRefresh,
              topInset: kSejongAppBarInset(context),
              child: ListView(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + 64 + 24,
                  left: AppSpacing.marginMobile,
                  right: AppSpacing.marginMobile,
                  bottom: 120 + MediaQuery.paddingOf(context).bottom,
                ),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                // 각 큰 카드/그리드는 RepaintBoundary로 래스터 격리 — 스크롤
                // 중 gradient + shadow가 매 프레임 다시 그려지는 비용을 GPU
                // 합성(이미 캐시된 레이어 단순 translate)으로 대체. 디버그 빌드
                // + 에뮬레이터에서 가장 체감 큰 최적화.
                children: [
                  // Hero: 이벤트/좌석 있으면 카드, 아직 로딩(캐시 없음)이면 스켈레톤.
                  // 로딩 끝났는데 이벤트 0개 + 좌석 없음이면 슬롯 자체를 숨김.
                  if (events.isNotEmpty || heroFront != null) ...[
                    RepaintBoundary(
                      child: HeroSlot(events: events, frontBuilder: heroFront),
                    ),
                    // EventCard ↔ "바로가기 메뉴" 헤더 간격(A)을 헤더 ↔ 아이콘 간격(B,
                    // ~37dp)과 맞춰 헤더가 위로 쏠리지 않게 한다. (헤더 행이 편집칩
                    // 때문에 글자보다 커서 A=SizedBox+~10dp로 들어옴 → 27로 A≈37.)
                    const SizedBox(height: 30),
                  ] else if (eventsAsync.isLoading) ...[
                    const RepaintBoundary(child: _HeroSkeleton()),
                    const SizedBox(height: 30),
                  ],
                  const _QuickActionsHeader(),
                  const SizedBox(height: 4),
                  const RepaintBoundary(child: QuickActionsGrid()),
                  const SizedBox(height: AppSpacing.stackSm),
                  const RepaintBoundary(child: LibraryStatusStrip()),
                  const SizedBox(height: AppSpacing.stackMd),
                  const RepaintBoundary(child: _HomeNoticesPreview()),
                  const SizedBox(height: AppSpacing.stackMd),
                  const RepaintBoundary(child: SejongNewsPreview()),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SejongAppBar(
              remainingLectures: remaining,
              onLecturesTap: () => Navigator.of(
                context,
                rootNavigator: true,
              ).push(slideRoute(const TimetableScreen())),
              hasNotification: ref.watch(combinedUnreadCountProvider) > 0,
              onNotificationTap: () => Navigator.of(
                context,
                rootNavigator: true,
              ).push(slideRoute(const NotificationsScreen())),
            ),
          ),
          const RecommendedUpdateHomePrompt(),
        ],
      ),
    );
  }

  /// front 빌더 — 좌석 발권이 있으면 SeatCard, 없으면 null(EventCarousel만).
  ///
  /// libseat의 loading/error 상태도 좌석 없음으로 취급 — 잠깐 EventCarousel을
  /// 보여주는 게 빈 SeatCard보다 자연스러움.
  WidgetBuilder? _buildHeroFront(
    LectureContextState lectureState,
    ({Course course, HMTime startsAt})? next,
  ) {
    final seat = ref.watch(activeSeatReservationProvider);
    if (seat == null) return null;
    final seatActionBusy = ref.watch(libseatSeatActionStateProvider).busy;
    return (ctx) => SeatCard(
      reservation: seat,
      header: LectureContextRow(state: lectureState, next: next),
      busy: seatActionBusy,
      onReturn: () => handleLibseatReturn(ctx, ref, seat),
      onExtend: () => handleLibseatExtend(ctx, ref, seat),
    );
  }
}

/// Hero 영역 스켈레톤 — 이벤트(Supabase home_events)가 아직 로딩 중일 때 **16:9**
/// 레이아웃을 미리 잡고 그라데이션 sweep. 로드된 HeroSlot(좌석 없을 때 16:9)과 같은
/// 비율이라 배너가 도착해도 레이아웃 점프가 없다. 공지/세종뉴스/학식 프리뷰와 같은 패턴.
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ShimmerBox(
          width: double.infinity,
          height: double.infinity,
          radius: AppRadius.xl,
        ),
      ),
    );
  }
}

// ─── 시간표 상태 유틸 ───────────────────────────────────────────────────────

/// 오늘 날짜에 해당하는 학기를 단순 매핑.
///
/// 휴학/예외 케이스 보완은 v2 (`availableSemestersProvider`와 교차 검증) TODO.
Semester _currentSemester(DateTime now) {
  final y = now.year;
  final m = now.month;
  if (y == 2025) {
    if (m >= 9) return Semester.fall2025;
    if (m == 7 || m == 8) return Semester.summer2025;
    return Semester.spring2025;
  }
  if (y == 2026) {
    return Semester.spring2026;
  }
  // fallback — 가장 최근 정규 학기.
  return Semester.spring2026;
}

bool _isWeekend(DateTime now) =>
    now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

DateTime? _firstStartToday(List<Course> courses, DateTime now) {
  final wd = _weekdayOf(now);
  if (wd == null) return null;
  int? earliest;
  for (final c in courses) {
    for (final t in c.times) {
      if (t.weekday != wd) continue;
      final m = t.start.totalMinutes;
      if (earliest == null || m < earliest) earliest = m;
    }
  }
  if (earliest == null) return null;
  return DateTime(now.year, now.month, now.day, earliest ~/ 60, earliest % 60);
}

Weekday? _weekdayOf(DateTime now) {
  switch (now.weekday) {
    case DateTime.monday:
      return Weekday.mon;
    case DateTime.tuesday:
      return Weekday.tue;
    case DateTime.wednesday:
      return Weekday.wed;
    case DateTime.thursday:
      return Weekday.thu;
    case DateTime.friday:
      return Weekday.fri;
    default:
      return null;
  }
}

LectureContextState _deriveLectureState(
  AsyncValue<Timetable> tt,
  List<Course> courses,
  DateTime now,
  ({Course course, HMTime startsAt})? next,
) {
  if (tt.isLoading && !tt.hasValue) return LectureContextState.loading;
  if (tt.hasError) return LectureContextState.error;
  if (courses.isEmpty) return LectureContextState.noTimetable;
  if (_isWeekend(now)) return LectureContextState.weekendOrEmpty;
  // 평일 — 오늘 강의가 하나도 없으면 weekendOrEmpty와 동급("오늘은 수업 없음").
  final firstStart = _firstStartToday(courses, now);
  if (firstStart == null) return LectureContextState.weekendOrEmpty;
  if (next == null) return LectureContextState.allDone;
  if (now.isBefore(firstStart)) return LectureContextState.beforeFirst;
  return LectureContextState.between;
}

class _QuickActionsHeader extends ConsumerWidget {
  const _QuickActionsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(quickActionsEditModeProvider);
    return Padding(
      // 좌우 8dp 살짝 들여쓰기 — 카드 외곽선과 콘텐츠 라인의 중간.
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 좌측 크림슨 vertical bar accent — 텍스트에 시각적 무게감.
          Container(
            width: 3.5,
            height: 16,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.surfaceTint],
              ),
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '바로가기 메뉴',
            style: AppTypography.headlineMd.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const Spacer(),
          // 편집 / 완료 토글.
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  ref.read(quickActionsEditModeProvider.notifier).toggle(),
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: editMode
                        ? [
                            AppColors.primary.withValues(alpha: 0.92),
                            AppColors.primary.withValues(alpha: 0.70),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0.4),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: editMode
                        ? AppColors.primary.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.75),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      editMode ? Symbols.check : Symbols.tune,
                      size: 14,
                      color: editMode ? Colors.white : AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      editMode ? '완료' : '편집',
                      style: AppTypography.labelSm.copyWith(
                        color: editMode ? Colors.white : AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 바로가기 그리드 + 타일은
// lib/features/home/presentation/widgets/quick_actions_grid.dart 로 이관.
// 일반/편집 모드 분기와 드래그-드롭(`ReorderableBuilder`)을 처리하고 외곽을
// `AnimatedSize`로 래핑해 줄 수 변화 시 LibraryStatusStrip이 부드럽게 미끄러져
// 오도록 한다.

// ─── 홈 공지 미리보기 카드 ─────────────────────────────────────────────────

class _HomeNoticesPreview extends ConsumerWidget {
  const _HomeNoticesPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeNoticePreviewProvider);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          slideRoute(const NoticesScreen(initial: NoticeCategory.general)),
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: GlassCard(
          borderRadius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Symbols.campaign,
                    size: 18,
                    fill: 1,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '대학 공지',
                    style: AppTypography.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '더보기',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Symbols.chevron_right,
                    size: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              async.when(
                loading: () => const _PreviewSkeleton(),
                error: (_, _) => Text(
                  '공지를 불러오지 못했어요',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Text(
                      '새 공지가 없어요',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final n in items.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              if (n.isNew)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  n.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSm.copyWith(
                                    fontSize: 12.5,
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton();
  // 데이터 도착 시 노출되는 3줄 공지(title 한 줄)와 동일 layout — 각 12px line +
  // 4px*2 vertical padding × 3 ≈ 60px. 폭은 진짜 title 처럼 들쭉날쭉.
  static const _widths = [220.0, double.infinity, 180.0];
  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _widths.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ShimmerBox(
                width: _widths[i].isFinite ? _widths[i] : null,
                height: 12,
              ),
            ),
        ],
      ),
    );
  }
}
