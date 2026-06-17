import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/core/diagnostics/crash_report.dart';
import 'package:sejong_smart_campus/core/lifecycle/app_resume_handler.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friend_request_watcher.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_notifications.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/library/presentation/screens/library_list_screen.dart';
import 'package:sejong_smart_campus/features/support/presentation/screens/qna_compose_dialog.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/auto_attend_permissions.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_notifications.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/auto_attend_controller.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/auto_attend_settings_provider.dart';
import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_dialog.dart';
import 'package:sejong_smart_campus/features/shell/presentation/widgets/bottom_nav_insets.dart';
import 'package:sejong_smart_campus/features/shell/presentation/widgets/sejong_bottom_nav.dart';
import 'package:sejong_smart_campus/features/community/presentation/screens/community_screen.dart';
import 'package:sejong_smart_campus/features/home/presentation/screens/home_screen.dart';
import 'package:sejong_smart_campus/features/menu/presentation/screens/services_screen.dart';
import 'package:sejong_smart_campus/features/student_id/presentation/screens/student_id_screen.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/screens/ucheck_screen.dart';

/// 앱 루트 셸.
///
/// ┌─────────────────────────────┐
/// │  MeshBackground             │
/// │  ┌───────────────────────┐  │
/// │  │  Navigator (content)  │  │  ← 화면 전환이 일어나는 영역
/// │  └───────────────────────┘  │
/// │  SejongBottomNav ────────── │  ← 항상 Navigator 위 z-order에 고정
/// └─────────────────────────────┘
///
/// 바텀 네비가 Navigator Stack보다 높은 레이어에 있으므로
/// 어떤 화면 전환 중에도 덮이지 않는다.
/// 탭 전환 API — 외부에서 AppShell.of(context).switchTab(i) 호출.
abstract class AppShellController {
  void switchTab(int i);
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  /// 하위 트리에서 탭을 전환할 때 사용 (예: 홈 퀵액션 → U-Check).
  static AppShellController of(BuildContext context) =>
      context.findAncestorStateOfType<_AppShellState>()!;

  /// root navigator 위에 push된 화면(라이브러리 등)에서 탭 전환용.
  ///
  /// 그 화면들은 AppShell 과 **형제 route**(root navigator 의 다른 overlay
  /// 엔트리)라 `findAncestorStateOfType` 으로 AppShell 을 못 찾는다([of] 가 null!
  /// → crash). 단일 AppShell 전역 참조로 우회. 예약 완료 후 홈 탭 강제 전환 등.
  static AppShellController? get instance => _AppShellState._current;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver
    implements AppShellController {
  /// 단일 AppShell 전역 참조 ([AppShell.instance]). root 위에 push된 화면에서
  /// 탭 전환에 사용.
  static _AppShellState? _current;

  int _navIndex = 0;
  final _navKey = GlobalKey<NavigatorState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // 바텀 nav 실측을 위한 key. didChangeMetrics(회전/safe-area 변화) +
  // didChangeDependencies(테마/패딩 변화) 마다 다시 측정한다.
  final _bottomNavMeasureKey = GlobalKey();
  // 초기값은 안전한 추정 — 측정되기 전 한 프레임 동안만 사용.
  double _measuredBottomNavHeight = 92;

  /// 직전 paused/hidden 시각 — resume 시 [handleAppResume]에 elapsed로 넘긴다.
  /// 짧은 일시정지(앱 전환 알림 확인 등)와 장기 sleep을 구분해 일괄 invalidate
  /// 강도를 조절하기 위함.
  DateTime? _pausedAt;
  StreamSubscription<dynamic>? _notifTapSub;
  StreamSubscription<dynamic>? _libseatNotifTapSub;
  // 받은 친구요청 포그라운드 폴링(30초). resume에서 시작, pause에서 정지.
  Timer? _friendPoll;

  /// 루트 ProviderContainer — initState에서 **즉시** 확보(element가 활성일 때).
  /// 콜드부트 850ms 지연 콜백/폴링/알림 콜백 등 **비동기 경로의 provider 접근은 전부
  /// 이걸로** 한다. ref.read는 element 조상 lookup이라, 콜백 실행 시점에 AppShell이
  /// 비활성(로그아웃/전환)이면 "deactivated widget's ancestor" 로 throw → 우리 크래시
  /// 시스템이 이를 잡아 리포트로 띄우던 문제의 근본 원인. container.read는 안전.
  /// (lazy late 초기화면 deactivation window에 평가될 수 있어 initState에서 즉시 대입.)
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _current = this;
    _container = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomNav());
    // login → shell 시그니처 트랜지션(750ms)이 진행되는 동안 무거운 부트스트랩
    // 작업(자동출석 controller + secure storage 읽기 + 알림 예약 + native bridge)이
    // 같이 실행되면 첫 프레임이 늘어져 트랜지션이 끊긴다. 트랜지션 종료 직후로
    // 미뤄 jank 회피 — 사용자 체감 지연은 없다(자동출석은 어차피 사용자 액션
    // 없이 백그라운드 트리거이고, notification launch payload 처리는 1초 정도
    // 늦어도 무방).
    Future<void>.delayed(const Duration(milliseconds: 850), () async {
      if (!mounted) return;
      // 자동출석이 ON(기본값)이면 필요한 권한(BLE/위치/알림)을 콜드부트마다 요청 —
      // 미허용이면 매 실행 다시 뜬다. 권한이 먼저 잡혀야 아래 coldboot 스캔이 동작.
      await _ensureAutoAttendPermissions();
      if (!mounted) return;
      final controller = _container.read(autoAttendControllerProvider.notifier);
      controller.checkAndTrigger(reason: 'coldboot');
      controller.scheduleNotificationsForToday();
      // 자동출석과 무관한 두 알림(출석 시간 시작 / 수업 정각) 7일치 예약 —
      // 공휴일 자동 제외. 토글 OFF면 단순 cancel-only로 종료.
      controller.scheduleClassReminders();

      final launchPayload = await UCheckNotifications.instance.launchPayload();
      if (launchPayload != null && mounted) {
        _handleNotificationPayload(launchPayload);
      }
      final libseatLaunchPayload = await LibseatNotifications.instance
          .launchPayload();
      if (libseatLaunchPayload != null && mounted) {
        unawaited(_handleLibseatNotificationPayload(libseatLaunchPayload));
      }
      _notifTapSub = UCheckNotifications.instance.onTap.listen((response) {
        final p = response.payload;
        if (p != null) _handleNotificationPayload(p);
      });
      _libseatNotifTapSub = LibseatNotifications.instance.onTap.listen((
        response,
      ) {
        final p = response.payload;
        if (p != null) unawaited(_handleLibseatNotificationPayload(p));
      });
      // 콜드부트 시 받은 친구요청 확인 + 폴링 시작.
      _startFriendPoll();
      // 직전 실행에서 실제 crash/anr evidence가 있으면 리포트 프롬프트.
      unawaited(_checkPendingCrash());
    });
  }

  /// 자동출석 권한 보장 — 토글 ON(기본값)인데 권한이 빠져 있으면 요청한다.
  /// 콜드부트마다 호출되므로 "안 켜면 실행 때마다" 요건을 충족. 일반 거부는 다음
  /// 실행에 시스템 dialog가 다시 뜨고, 영구 거부(시스템 dialog 미표시)면 "설정 열기"
  /// 안내 다이얼로그로 우회한다. 토글 OFF면 아무것도 하지 않는다.
  Future<void> _ensureAutoAttendPermissions() async {
    final settings = _container.read(ucheckSettingsLocalProvider);
    final enabled = await settings.readAutoAttendEnabled();
    if (!enabled) return;
    const perms = AutoAttendPermissions();
    if (await perms.allGranted()) return;
    final result = await perms.request();
    if (result.granted || !result.permanentlyDenied) return;
    // 영구 거부 → 시스템 dialog가 안 뜸. 우리 안내로 설정 유도(매 실행 노출).
    if (!mounted) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final open = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('자동출석 권한이 필요해요'),
        content: const Text(
          '자동출석을 사용하려면 블루투스·위치·알림 권한이 필요해요.\n'
          '설정에서 권한을 허용해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
    if (open == true) await perms.openSettings();
  }

  /// Android가 기록한 실제 crash/anr 종료 사유가 있을 때만 리포트 전송을 제안한다.
  /// `session.dirty` sentinel이나 Dart 에러 덤프 단독으로는 prompt를 띄우지 않는다.
  Future<void> _checkPendingCrash() async {
    if (!kReleaseMode) return;
    final evidence = CrashReport.instance.previousCrashEvidence;
    // 덤프는 트리거가 아니라 첨부용 — 정상 종료여도 항상 회수해 stale을 제거한다.
    final dump = await CrashReport.instance.takePending();
    if (evidence == null) return;
    // 다이얼로그는 AppShell의 context가 아니라 **루트 네비게이터의 안정적인
    // context**로 띄운다. AppShell은 AuthGate의 AnimatedSwitcher가 로그인↔셸을
    // swap할 때 비활성화될 수 있어(콜드부트 850ms 지연 + 디스크 읽기 await 사이),
    // 그 context로 showDialog하면 "This BuildContext is no longer valid"로
    // 크래시났다(실측 리포트 b5dcc7f1). 루트 네비게이터는 swap에 안정적이다.
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    final send = await showDialog<bool>(
      context: navContext,
      builder: (ctx) => AlertDialog(
        title: const Text('오류가 발생했어요'),
        content: const Text(
          '직전에 앱이 예기치 않게 종료됐어요.\n'
          '개발자에게 진단 로그를 보내 문제 해결을 도와주시겠어요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('리포트 보내기'),
          ),
        ],
      ),
    );
    await CrashReport.instance.acknowledgePreviousCrash();
    if (send != true) return;
    final composeContext = rootNavigatorKey.currentContext;
    if (composeContext == null || !composeContext.mounted) return;
    await showQnaComposeDialog(
      composeContext,
      initialCategoryId: 'bug',
      initialTitle: '앱 비정상 종료 리포트',
      initialContent: '앱이 예기치 않게 종료되었습니다.\n(진단 로그가 자동 첨부됩니다.)',
      attachedLog: _composeCrashAttachment(dump, evidence),
      isCrashReport: true,
    );
  }

  String _composeCrashAttachment(String? dump, CrashEvidence evidence) {
    final exitInfo = evidence.toReportLog();
    if (dump == null || dump.trim().isEmpty) return exitInfo;
    return '${CrashReport.clamp(dump)}\n\n$exitInfo';
  }

  /// 받은 친구요청 폴링 — 즉시 1회 + 30초 주기. 포그라운드에서만 동작.
  /// 새 요청이 감지되면 [checkFriendRequestsAndNotify]가 헤드업을 띄운다.
  void _startFriendPoll() {
    unawaited(checkFriendRequestsAndNotify(_container));
    _friendPoll ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) unawaited(checkFriendRequestsAndNotify(_container));
    });
  }

  void _stopFriendPoll() {
    _friendPoll?.cancel();
    _friendPoll = null;
  }

  void _handleNotificationPayload(String payload) {
    // payload format: "preclass:<lectureNo>" or "result:<lectureNo>"
    // UCheck가 메인 탭에서 빠지고 sub-screen이 됐으므로 root navigator에
    // push. 동시에 자동출석 트리거. context 대신 rootNavigatorKey를 써서
    // (알림 콜백/지연 콜백이 AppShell 비활성 시점에 와도) 안정적으로 push.
    rootNavigatorKey.currentState?.push(slideRoute(const UCheckScreen()));
    _container
        .read(autoAttendControllerProvider.notifier)
        .checkAndTrigger(reason: 'notif_tap:$payload');
  }

  Future<void> _handleLibseatNotificationPayload(String payload) async {
    final parsed = LibseatNotificationPayload.parse(payload);
    if (parsed == null) return;
    rootNavigatorKey.currentState?.push(slideRoute(const LibraryListScreen()));
    final result = await _container
        .read(libseatSyncProvider)
        .sync(
          reason: 'notif_tap:${parsed.kind.wireName}',
          notificationPayloadKey: parsed.reservationKey,
        );
    if (!result.returnAcknowledgementDue) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await showSejongResultDialog(
      ctx,
      success: true,
      title: '좌석 반납 확인',
      message: '좌석 반납이 확인되어 모든 알림이 종료됐어요.',
    );
  }

  @override
  void dispose() {
    if (identical(_current, this)) _current = null;
    _notifTapSub?.cancel();
    _libseatNotifTapSub?.cancel();
    _stopFriendPoll();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 화면 회전·safe-area 변경(예: 제스처 바 모드 토글) → 다음 프레임에 재측정.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomNav());
  }

  void _measureBottomNav() {
    final ctx = _bottomNavMeasureKey.currentContext;
    final size = ctx?.size;
    if (size == null) return;
    if ((size.height - _measuredBottomNavHeight).abs() < 0.5) return;
    setState(() => _measuredBottomNavHeight = size.height);
  }

  /// 앱 전체 라이프사이클 — 어떤 sub-screen에 있어도 resume 시 토큰 갱신과
  /// 핵심 provider invalidate가 한 번에 일어나도록 AppShell이 일괄 처리한다.
  /// (HomeScreen의 자체 옵저버는 좌석 polling 타이머 관리용으로 별도 유지.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      final pauseDuration = pausedAt == null
          ? Duration.zero
          : DateTime.now().difference(pausedAt);
      _pausedAt = null;
      // 비동기 경로의 provider 접근은 deactivation-safe한 _container로 — 위 initState
      // 주석 참조(로그아웃/계정전환 중 ref는 "deactivated ancestor"로 throw 가능).
      unawaited(handleAppResume(_container, pauseDuration: pauseDuration));
      // 복귀 시 받은 친구요청 확인 + 폴링 재개.
      _startFriendPoll();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
      _stopFriendPoll();
    }
  }

  /// 외부에서 탭 전환 요청 (AppShell.of(context).switchTab(i)).
  @override
  void switchTab(int i) {
    // 전체 서비스(endDrawer) 안의 '커뮤니티' 항목처럼 드로어에서 탭 전환을
    // 요청하는 경우, 열린 endDrawer를 먼저 닫는다. 홈 바로가기 등 드로어가
    // 닫힌 상태에서 호출되면 no-op.
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isEndDrawerOpen ?? false) scaffold!.closeEndDrawer();
    _onNavTap(i);
  }

  @override
  Widget build(BuildContext context) {
    // 다음 프레임에 측정 재시도 — 초기 빌드/리빌드 시점 일관성 확보.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomNav());
    return BottomNavInsets(
      height: _measuredBottomNavHeight,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          // 1순위: 현재 탭의 inner Navigator에 서브 페이지가 있으면 pop
          final popped = await _navKey.currentState?.maybePop() ?? false;
          if (popped) return;
          // 2순위: 톱탭 + 비-홈 → 홈으로 이동 (Model A: 평행 탭)
          if (_navIndex != 0) {
            _onNavTap(0);
            return;
          }
          // 3순위: 홈 톱탭 → 시스템 종료 (Android 백키 기본 동작)
          await SystemNavigator.pop();
        },
        child: Scaffold(
          key: _scaffoldKey,
          extendBodyBehindAppBar: true,
          backgroundColor: AppColors.surface,
          // 5번째 nav 'index 4 (전체)' 클릭 시 우측 슬라이드 드로어로 노출.
          // 탭 자체는 전환되지 않음 (drawer만 토글).
          endDrawer: Drawer(
            width: MediaQuery.sizeOf(context).width * 0.88,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
            ),
            // drawer에서 띄울 때는 외부 Scaffold key로 close 콜백을 주입.
            // ServicesScreen 자체가 Scaffold를 가지므로 Scaffold.of(context)가
            // 내부 scaffold를 잡아 closeEndDrawer가 무동작인 문제를 우회.
            child: ServicesScreen(
              asDrawer: true,
              onClose: () => _scaffoldKey.currentState?.closeEndDrawer(),
            ),
          ),
          body: MeshBackground(
            child: Stack(
              children: [
                // ── 콘텐츠 Navigator ─────────────────────────────────────────
                Positioned.fill(
                  child: Navigator(
                    key: _navKey,
                    onGenerateRoute: (_) => instantRoute(const HomeScreen()),
                  ),
                ),
                // ── 항상 최상단에 고정된 바텀 네비 ────────────────────────────
                Align(
                  alignment: Alignment.bottomCenter,
                  child: KeyedSubtree(
                    key: _bottomNavMeasureKey,
                    child: SejongBottomNav(
                      currentIndex: _navIndex,
                      onTap: _onNavTap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onNavTap(int i) {
    // SejongBottomNav._items 4개로 축소:
    //   0: 메인 / 1: 학생증 / 2: 커뮤니티 / 3: 전체(endDrawer 토글).
    // U-Check는 nav 탭이 아니라 push되는 sub-screen.
    if (i == 3) {
      final scaffold = _scaffoldKey.currentState;
      if (scaffold?.isEndDrawerOpen ?? false) {
        scaffold!.closeEndDrawer();
      } else {
        scaffold?.openEndDrawer();
      }
      return;
    }
    if (i == _navIndex) {
      // 같은 탭 재탭: 서브 페이지가 있으면 루트로 복귀
      _navKey.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _navIndex = i);
    final page = switch (i) {
      0 => const HomeScreen(),
      1 => const StudentIdScreen(),
      2 => const CommunityScreen(),
      _ => const HomeScreen(),
    };
    // 기존 스택을 모두 비우고 새 탭 루트를 즉시 교체
    _navKey.currentState?.pushAndRemoveUntil(instantRoute(page), (_) => false);
  }
}
