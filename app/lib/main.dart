import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/features/app_update/presentation/widgets/app_update_gate.dart';
import 'package:sejong_smart_campus/features/auth/presentation/screens/auth_gate.dart';
import 'package:sejong_smart_campus/core/diagnostics/app_log.dart';
import 'package:sejong_smart_campus/core/diagnostics/crash_report.dart';
import 'package:sejong_smart_campus/core/diagnostics/diagnostics_config.dart';
import 'package:sejong_smart_campus/core/network/supabase_config.dart';
import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/core/theme/app_theme.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_notifications.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_notifications.dart';
import 'package:sejong_smart_campus/features/friends/data/datasources/friend_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 가능한 한 일찍 debugPrint를 가로채 부트스트랩 로그까지 진단 버퍼에 담는다.
  AppLog.instance.installDebugPrintHook();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  // Supabase-backed optional features are enabled only for internal builds that
  // pass SUPABASE_URL and SUPABASE_ANON_KEY through dart-define.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: false,
    );
  } else {
    debugPrint(
      'Supabase is not configured; optional server-backed features are disabled.',
    );
  }

  // V2 UCheck 자동출석 알림 인프라 — timezone + 채널 등록. 권한 요청은 사용자가
  // 자동출석 토글 ON 시점에 한 번만 (Settings 모달에서). main에서 강제 요청 X.
  await UCheckNotifications.instance.init();
  // 열람실 예약 종료 30분·5분 전 알림 채널 등록. 실제 예약 스케줄은
  // reserveLibseat/extendLibseat 성공 시점에 잡힌다.
  await LibseatNotifications.instance.init();
  // 친구 알림(헤드업) 채널 등록. 탭 콜백은 공용 NotificationTapBus로만 전달해
  // ucheck/libseat 라우팅을 덮어쓰지 않는다.
  await FriendNotifications.instance.init();
  // 크래시 덤프 경로 확보 + Android 종료 사유 조회 + 이번 세션 dirty 마킹.
  await CrashReport.instance.init();
  // 세션 보조 컨텍스트를 라이프사이클에 연결(로그인 전 화면 포함 전역).
  // 사용자-facing crash 판단은 Android ApplicationExitInfo evidence가 전담한다.
  if (kReleaseMode) CrashReport.instance.installLifecycleObserver();

  // Sentry로 자동 크래시/에러 수집(네이티브 포함). DSN이 비어 있으면 SDK는
  // 비활성이지만 appRunner는 정상 실행 — 로컬 버퍼/덤프/프롬프트는 DSN 없이도 작동.
  await SentryFlutter.init(
    (options) {
      options.dsn = AppDiagnosticsConfig.sentryDsn;
      options.tracesSampleRate = 0.0; // 성능 트레이싱 off — 크래시/에러만.
      options.attachStacktrace = true;
      options.environment = kReleaseMode ? 'release' : 'debug';
    },
    appRunner: () {
      // Sentry가 init에서 건 에러 핸들러 **위에** 우리 로컬 버퍼/덤프를 체이닝.
      _chainDiagnosticsHandlers();
      runApp(const ProviderScope(child: SejongApp()));
    },
  );
}

/// Sentry의 핸들러를 보존한 채 [AppLog]/[CrashReport]를 얹는다.
/// 순서: 우리 버퍼 기록 → (덤프) → Sentry 위임. Sentry 자동 수집을 깨지 않는다.
void _chainDiagnosticsHandlers() {
  final sentryFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.instance.add(
      'FlutterError: ${details.exceptionAsString()}',
      level: 'E',
    );
    sentryFlutterOnError?.call(details);
  };

  final sentryPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.instance.add('Uncaught: $error', level: 'F');
    // 에러 덤프는 **트리거가 아니라 첨부용 컨텍스트**다. 사용자-facing 비정상 종료
    // 판별은 Android ApplicationExitInfo evidence가 전담한다.
    // release 전용: 디버그 프레임워크 assert를 디스크에 적재할 이유가 없다.
    if (kReleaseMode) {
      // 인메모리 버퍼는 프로세스 종료로 사라지므로, 마지막 에러 컨텍스트를 디스크에
      // 즉시 덤프 → 비정상 종료가 확정되면 리포트에 첨부.
      CrashReport.instance.persistSync(error, stack);
    }
    return sentryPlatformOnError?.call(error, stack) ?? false;
  };
}

class SejongApp extends StatelessWidget {
  const SejongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sejong Univ Station',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.light(),
      home: const AppUpdateGate(child: AuthGate()),
      builder: (context, child) {
        // 반응형 텍스트 스케일링.
        // - 기준 폭 360dp 이상: 1.0× (디자인 시안 그대로)
        // - 320~360dp: 360 대비 비례로 0.85까지 점진 축소
        // - 320dp 미만: 0.85× 고정
        // 사용자의 시스템 폰트 스케일러는 그대로 곱셈으로 결합 — 접근성 보존.
        final media = MediaQuery.of(context);
        final w = media.size.width;
        // 디자인 시안 기준 폭 411dp(=Pixel 7). 좁아질수록 비례 다운스케일.
        const baseline = 411.0;
        const minScale = 0.75;
        final responsive = w >= baseline
            ? 1.0
            : (w / baseline).clamp(minScale, 1.0).toDouble();
        final userScale = media.textScaler.scale(1.0);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(responsive * userScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
