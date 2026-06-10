import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/features/auth/data/datasources/token_storage.dart';
import 'package:sejong_smart_campus/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sejong_smart_campus/features/auth/domain/entities/sejong_user.dart';
import 'package:sejong_smart_campus/features/auth/domain/repositories/auth_repository.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/timetable_sync_provider.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/library/presentation/providers/usage_history_providers.dart';
import 'package:sejong_smart_campus/features/student_id/presentation/providers/s1pass_providers.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/auto_attend_settings_provider.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/ucheck_providers.dart';

/// 보안 토큰 저장소 (Android EncryptedSharedPreferences / iOS Keychain).
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// 인증 cookie를 디스크에 영속.
///
/// **이 jar에는 refresh token + SSO cookie가 들어간다.**
/// - refresh token: refresh 호출에 자동 부착
/// - SSO cookie: 연동 서비스 진입 시 사용
final cookieJarProvider = FutureProvider<CookieJar>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final storage = FileStorage('${dir.path}/.sejong_cookies/');
  return PersistCookieJar(storage: storage, ignoreExpires: false);
});

/// Dio + interceptors + bareDio 묶음. refreshHook은 [authStateProvider] 생성
/// 직후 주입한다 (순환 의존 회피).
final sejongApiClientProvider = FutureProvider<SejongApiClient>((ref) async {
  final jar = await ref.watch(cookieJarProvider.future);
  final storage = ref.watch(tokenStorageProvider);
  return SejongApiClient(cookieJar: jar, tokenStorage: storage);
});

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  final storage = ref.watch(tokenStorageProvider);
  final repo = AuthRepositoryImpl(client: client, storage: storage);
  // 401 single-flight refresh가 이 repo의 refresh를 사용하도록 연결.
  client.refreshHook = () async {
    try {
      await repo.refresh();
      return true;
    } catch (_) {
      return false;
    }
  };
  return repo;
});

/// 현재 인증 상태 — null이면 unauthenticated.
///
/// build() 부트스트랩: rememberMe가 true이고 cookie jar에 refresh token이
/// 살아있으면 `/auth/refresh` → `/auth/me`로 사용자 복원. 실패하면 null
/// (AuthGate가 LoginScreen으로 라우팅).
///
/// sjapp 인증이 살아있는 모든 경로(부트스트랩 refresh + 신규 login)는
/// 직후 [_runSupabaseOnboarding]을 트리거해 Supabase 측 envelope encryption
/// row를 멱등으로 upsert. 학번/이름/학과/학부는 RPC가 SECURITY DEFINER로
/// 암호화 저장 — 친구 시스템 + 시간표 공유의 토대.
class AuthStateNotifier extends AsyncNotifier<SejongUser?> {
  @override
  Future<SejongUser?> build() async {
    final storage = ref.read(tokenStorageProvider);
    final repo = await ref.watch(authRepositoryProvider.future);
    final remember = await storage.readRememberMe();
    if (!remember) return null;
    try {
      await repo.refresh();
      final user = await repo.fetchMe();
      unawaited(_runSupabaseOnboarding(user));
      // UCheck도 같이 복원 — 자격증명이 storage에 있다면 토큰 재발급. 실패해도
      // sjapp 인증은 무관 (사용자가 UCheck 탭 들어갈 때 fallback 모달이 뜸).
      unawaited(bootstrapUCheckFromStorage(ref));
      // S1Pass NFC HCE — sjapp /auth/me 응답에 cardNo가 같이 옴. cardNo를
      // EncryptedSharedPreferences에 저장하고 ForegroundService 시작 →
      // 앱 종료/잠금 화면에서도 NFC 출입 게이트 태깅 가능.
      unawaited(activateS1Pass(user.cardNo));
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<SejongUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final repo = await ref.read(authRepositoryProvider.future);
    // 계정 격리 — 로그아웃을 건너뛴 재로그인(세션 만료 후 다른 계정 로그인 등)에도
    // 이전 사용자의 per-user 캐시(쿠키·디스크·전역 provider)가 남지 않도록 인증 전에
    // 정리한다. 쿠키 jar는 repo.login()이 새 세션 쿠키를 채우기 전에 비워야 안 섞인다.
    await _clearPerUserState();
    state = const AsyncLoading();
    try {
      final user = await repo.login(
        username: username,
        password: password,
        rememberMe: rememberMe,
      );
      state = AsyncData(user);
      unawaited(_runSupabaseOnboarding(user));
      // sjapp 로그인 직후 같은 ID/PW로 UCheck도 함께 인증 — 사용자는 로그인을
      // 한 번만 한다. 세종대 통합 계정이라 ID/PW 동일.  실패해도 sjapp 인증은
      // 막지 않음 (UCheck 탭에서 fallback 모달이 뜸).
      unawaited(
        bootstrapUCheckWithSjappCredentials(
          ref,
          username: username,
          password: password,
        ),
      );
      // S1Pass NFC — 새 cardNo 도착 즉시 native에 저장 + service 시작.
      // 명시적 로그인이므로 배터리 최적화 제외 다이얼로그도 함께 요청.
      unawaited(activateS1Pass(user.cardNo, promptPermissions: true));
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    final repo = await ref.read(authRepositoryProvider.future);
    await repo.logout();
    // Supabase 익명 session도 함께 종료 — 클라 측 cache의 auth.uid()가 사라져
    // 더 이상 본인 row 복호화 불가. 다음 로그인 시 새 익명 sign-in.
    try {
      await ref.read(supabaseOnboardingProvider).signOut();
    } catch (_) {}
    // UCheck 자격증명/토큰/쿠키 일괄 정리 — 다음 로그인 때 재발급.
    try {
      await ref.read(ucheckRepositoryProvider).logout();
    } catch (_) {}
    // S1Pass NFC — cardNo 삭제 + ForegroundService 정지.
    try {
      await deactivateS1Pass();
    } catch (_) {}
    // 계정 격리 — per-user 캐시(쿠키·디스크·전역 provider) 일괄 정리.
    await _clearPerUserState();
    state = const AsyncData(null);
  }

  /// 계정 전환 시 이전 사용자의 per-user 상태를 정리한다. **로그아웃과 (로그아웃을
  /// 건너뛴) 재로그인 양쪽**에서 호출해 다른 계정 데이터 잔존을 차단한다.
  ///
  /// in-memory 전역 캐시 중 `sjptClientProvider`·`libseatTokenSourceProvider`·메뉴
  /// `_tokenCacheProvider`는 `currentUserProvider(userId)` 의존으로 자동 폐기되지만,
  /// (a) 즉시성을 위해 명시 invalidate 하고, (b) `ucheckDataProvider`처럼 userId 의존이
  /// 없는 것과 (c) provider 무효화로는 안 지워지는 **디스크 캐시/영속 쿠키**는 여기서
  /// 직접 정리한다.
  Future<void> _clearPerUserState() async {
    // 영속 쿠키(refresh token + ssotoken) — 안 지우면 다음 앱 시작 시 이전 사용자로
    // silent refresh 되거나 SSO 세션이 남는다. (로그인 시엔 인증 전에 호출되어야 새
    // 세션 쿠키와 섞이지 않는다.)
    try {
      final jar = await ref.read(cookieJarProvider.future);
      await jar.deleteAll();
    } catch (_) {}
    // 디스크 per-user 캐시 — provider 무효화로는 파일이 안 지워진다.
    try {
      await ref.read(usageHistoryLocalProvider).clear();
    } catch (_) {}
    try {
      await ref.read(ucheckSettingsLocalProvider).clearTriggerState();
    } catch (_) {}
    // 전역 in-memory per-user 캐시 즉시 폐기. (sjptClient·menu tokenCache는 userId
    // 의존으로 state 변경 시 자동 폐기되므로 여기선 import 비순환을 위해 생략.)
    try {
      ref.invalidate(libseatTokenSourceProvider);
      ref.invalidate(mySeatProvider);
      ref.invalidate(ucheckDataProvider);
    } catch (_) {}
    // 전 학기 시간표 백업 가드 해제 — 다음 로그인(같은 계정 재로그인 포함)에서
    // 모든 학기를 다시 백업하도록. Supabase 익명 세션이 재발급되므로 sjapp userId
    // 키 가드와 desync되는 걸 막는다.
    resetAllSemestersBackupGuard();
  }

  /// 로그인/부트스트랩 성공 직후, sjapp이 검증해준 본인 신원으로 Supabase
  /// 프로필을 멱등 upsert (친구 시스템 + 시간표 공유의 토대).
  ///
  /// Edge Function 경로가 일부 레거시 TLS 환경과 맞지 않아, 로그인 성공 시점의
  /// 검증된 `user`로 직접 서버 함수를 호출한다. 자세한 맥락은
  /// [SupabaseOnboardingRemote.upsertProfile].
  ///
  /// 실패해도 sjapp 인증은 막지 않음(친구 기능만 일시 비활성, 다음 로그인 시 재시도).
  Future<void> _runSupabaseOnboarding(SejongUser user) async {
    try {
      final onboarding = ref.read(supabaseOnboardingProvider);
      await onboarding.upsertProfile(
        studentId: user.userId,
        name: user.username,
        department: user.departmentName,
        college: user.organizationClassName,
      );
      // 처리방침 §보유기간 ④ — 기존 사용자 재로그인 시 last_seen_at 갱신.
      try {
        await onboarding.updateLastSeen();
      } catch (_) {}
    } catch (e, st) {
      // 다음 로그인 시 재시도. 단, TLS 실패처럼 조용히 묻혀 디버깅을 막던 전철을
      // 밟지 않도록 debug 빌드에서는 원인을 남긴다.
      assert(() {
        // ignore: avoid_print
        print('[onboarding] upsertProfile failed: $e\n$st');
        return true;
      }());
    }
  }
}

/// 비동기 task를 await 없이 실행할 때 dart analyzer가 unawaited_futures를
/// 경고. 의도된 fire-and-forget임을 명시.
void unawaited(Future<void> _) {}

final authStateProvider = AsyncNotifierProvider<AuthStateNotifier, SejongUser?>(
  AuthStateNotifier.new,
);

/// UI가 watch하는 단일 진입점 — 인증된 사용자가 없으면 null.
final currentUserProvider = Provider<SejongUser?>(
  (ref) => ref.watch(authStateProvider).value,
);
