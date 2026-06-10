import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// UCheck 전용 자격증명 보관소. **sjapp 토큰과 완전 분리** — 다른 시스템.
///
/// UCheck 서버는 ID/PW를 받아 자체 `token` 문자열을 발급한다 (JWT/Bearer 아님,
/// form param). 이 토큰은 refresh 가능하지만 만료시 raw 비밀번호로 재발급해야
/// 하므로 raw 비밀번호도 secure storage에 보관해야 한다 (sjapp은 refresh
/// cookie로 충분해서 raw PW 안 두지만 UCheck는 다름).
///
/// 보안:
/// - Android: EncryptedSharedPreferences + Keystore
/// - iOS: Keychain (first_unlock_this_device, 백업 X)
/// - 평문 로그/SharedPreferences 절대 X
///
/// ## Keys
///
/// - `ucheck.username` — 학번 (UI 자동 채움용 — currentUserProvider와 정합 확인)
/// - `ucheck.password` — raw 비밀번호. 토큰 만료 시 재로그인 (acquireMobileToken).
/// - `ucheck.token`    — 서버 발급 세션 토큰 (form param `token=`).
/// - `ucheck.intro_image2` — 서버가 `getInfo.do` 응답으로 내려준 memo AES 키.
///   `attendCheck.do` 페이로드의 `memo` 필드 암호화에 쓰임.
class UCheckCredentialsLocal {
  UCheckCredentialsLocal()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _storage;

  static const _kUsername = 'ucheck.username';
  static const _kPassword = 'ucheck.password';
  static const _kToken = 'ucheck.token';
  static const _kIntroImage2 = 'ucheck.intro_image2';

  Future<String?> readUsername() => _storage.read(key: _kUsername);
  Future<String?> readPassword() => _storage.read(key: _kPassword);
  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<String?> readIntroImage2() => _storage.read(key: _kIntroImage2);

  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kPassword, value: password);
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);

  Future<void> saveIntroImage2(String key) =>
      _storage.write(key: _kIntroImage2, value: key);

  /// 로그아웃 — 모든 자격증명 제거. 다음 진입 시 LoginScreen 자동 노출.
  Future<void> clear() async {
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kPassword);
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kIntroImage2);
  }

  /// 토큰만 제거 (강제 재로그인 트리거용 — username/password는 유지).
  Future<void> clearToken() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kIntroImage2);
  }

  /// 자격증명 (username+password) 보관 여부.
  Future<bool> hasCredentials() async {
    final u = await readUsername();
    final p = await readPassword();
    return u != null && u.isNotEmpty && p != null && p.isNotEmpty;
  }
}
