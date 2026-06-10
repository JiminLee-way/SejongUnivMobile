import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// access token + 자동 로그인 플래그 + 마지막 학번을 OS 보안 저장소에 보관.
///
/// **refresh token은 여기 안 둔다** — sjapp이 HttpOnly cookie로만 발급하므로
/// `PersistCookieJar`가 디스크 보관 담당. 우리가 손댈 일 없음.
///
/// JWT payload에 학번·이름·생년월일·학과가 평문으로 박혀있어 access token
/// 자체가 PII. SharedPreferences/Hive에 절대 두지 않는다.
class TokenStorage {
  TokenStorage()
    : _storage = const FlutterSecureStorage(
        // Android: EncryptedSharedPreferences 강제 (기본 KeyStore 대비
        // 키 회전·백업 안전성 향상).
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        // iOS: first_unlock_this_device — 백업되지 않고, 첫 잠금 해제 후만 접근.
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'sejong.access_token';
  static const _kAccessExp = 'sejong.access_token_exp';
  static const _kRememberMe = 'sejong.remember_me';
  static const _kLastUserId = 'sejong.last_user_id';

  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);

  /// access token + 만료 epoch (ms)를 함께 보관.
  Future<void> writeAccessToken(
    String token, {
    required int expiresAtMs,
  }) async {
    await _storage.write(key: _kAccessToken, value: token);
    await _storage.write(key: _kAccessExp, value: expiresAtMs.toString());
  }

  /// 만료 시각 (ms). 없으면 null.
  Future<int?> readAccessExpiresAtMs() async {
    final raw = await _storage.read(key: _kAccessExp);
    return raw == null ? null : int.tryParse(raw);
  }

  /// access token이 현재 유효한가? (1분 여유 두고 보수적으로 판정)
  Future<bool> isAccessTokenLikelyValid() async {
    final exp = await readAccessExpiresAtMs();
    if (exp == null) return false;
    return DateTime.now().millisecondsSinceEpoch + 60 * 1000 < exp;
  }

  Future<bool> readRememberMe() async {
    final v = await _storage.read(key: _kRememberMe);
    return v == 'true';
  }

  Future<void> writeRememberMe(bool value) =>
      _storage.write(key: _kRememberMe, value: value ? 'true' : 'false');

  Future<String?> readLastUserId() => _storage.read(key: _kLastUserId);

  Future<void> writeLastUserId(String userId) =>
      _storage.write(key: _kLastUserId, value: userId);

  /// 로그아웃 — 보안 토큰 + 학번 프리필 모두 제거. rememberMe는 별도 정책에
  /// 따라 호출자가 결정해서 지운다 (예: 사용자 명시 로그아웃 시만).
  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kAccessExp);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kAccessExp);
    await _storage.delete(key: _kRememberMe);
    await _storage.delete(key: _kLastUserId);
  }
}
