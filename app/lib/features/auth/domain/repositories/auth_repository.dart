import 'package:sejong_smart_campus/features/auth/domain/entities/sejong_user.dart';

/// 인증 도메인 진입점. 구현은 [AuthRepositoryImpl] (Dio + secure storage + cookie).
///
/// UI 레이어는 이 abstract만 watch — 추후 mock으로 갈아끼우거나 다른 백엔드
/// 어댑터를 붙일 때 호출지를 안 건드린다.
abstract class AuthRepository {
  /// 학번 + 포털 비밀번호로 로그인. 성공 시 access token을 secure storage에
  /// 저장하고 [SejongUser]를 반환. 실패 시 [SejongApiException] throw.
  ///
  /// [rememberMe]가 true면 cookie jar의 refresh token이 7일간 유지돼 다음
  /// 앱 시작 시 자동 로그인 가능.
  Future<SejongUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  });

  /// HttpOnly cookie의 refresh token으로 새 access token 발급.
  /// 성공 시 secure storage 갱신. 실패면 throw — 호출자가 unauthenticated
  /// 전이 처리.
  Future<void> refresh();

  /// 현재 access token으로 `/auth/me` 호출. 부트스트랩 흐름에서 사용.
  Future<SejongUser> fetchMe();

  /// 로그아웃 — 토큰 + 쿠키 + (선택적) rememberMe 삭제. 서버 측 세션 무효화
  /// endpoint는 아직 호출하지 않는다.
  Future<void> logout({bool clearRememberMe = true});
}
