import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// UCheck 서버 통신용 AES-CBC-PKCS5 헬퍼.
/// 실제 호환 IV/salt는 내부 빌드에서 dart-define으로 주입한다.
///
/// ## 두 가지 키
///
/// 1. **로그인용 (daily key)** — [encryptDaily] / [decryptDaily]
///    - Key  = SHA-256(`yyyyMMdd`(KST) + salt)
///    - **KST 자정마다 회전**. 디바이스 시계가 틀리면 로그인 실패.
///
/// 2. **출석 memo용 (서버 발급 key)** — [encryptWithServerKey]
///    - Key  = 서버 응답의 version key.
///    - 매 요청마다 새로 받는다.
///
/// ## 공통
///
/// - IV = 내부 빌드 define으로 주입되는 ASCII 16 bytes.
/// - 모드 = AES/CBC/PKCS5Padding (= PKCS7).
/// - 출력 = **Base16 대문자** (`"%02X"`).
///
/// 보안 주의: 평문(학번/비밀번호/출석시각) 자체는 secure storage 또는 메모리
/// 만에. 로그 출력 금지.
class UCheckAesCipher {
  UCheckAesCipher();

  static const String _ivAscii = String.fromEnvironment(
    'UCHECK_AES_IV',
    defaultValue: '0000000000000000',
  );

  static const String _dailyKeySalt = String.fromEnvironment(
    'UCHECK_DAILY_KEY_SALT',
    defaultValue: 'CHANGE_ME',
  );

  IV get _iv => IV(Uint8List.fromList(utf8.encode(_ivAscii)));

  // ─── Daily key (로그인용) ──────────────────────────────────────────────

  /// KST 기준 오늘 날짜의 SHA-256 키 32 bytes.
  /// `DateTime.now().toUtc().add(Duration(hours: 9))`로 KST 자정 경계 확정.
  Key _dailyKey() {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final yyyymmdd =
        '${kst.year.toString().padLeft(4, '0')}'
        '${kst.month.toString().padLeft(2, '0')}'
        '${kst.day.toString().padLeft(2, '0')}';
    final digest = sha256.convert(utf8.encode(yyyymmdd + _dailyKeySalt));
    return Key(Uint8List.fromList(digest.bytes));
  }

  /// 학번/비밀번호 같은 평문을 AES-CBC-PKCS7 → Base16 대문자.
  String encryptDaily(String plain) {
    final encrypter = Encrypter(AES(_dailyKey(), mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: _iv);
    return _toHexUpper(encrypted.bytes);
  }

  /// (디버그/테스트용) Base16 대문자 → 평문.
  String decryptDaily(String cipherHex) {
    final encrypter = Encrypter(AES(_dailyKey(), mode: AESMode.cbc));
    final encrypted = Encrypted(Uint8List.fromList(_fromHex(cipherHex)));
    return encrypter.decrypt(encrypted, iv: _iv);
  }

  // ─── Server-issued key (출석 memo용) ────────────────────────────────────

  /// 서버가 `getInfo.do` 응답의 `version.key`로 내려준 String을 키로 사용.
  ///
  /// 입력 [serverKey]는 ASCII/UTF-8 문자열로 가정 — bytes로 변환 후 32 bytes로
  /// 맞춤 (부족하면 0 padding, 넘치면 truncate).
  String encryptWithServerKey(String plain, String serverKey) {
    final raw = utf8.encode(serverKey);
    final key32 = Uint8List(32);
    final copyLen = raw.length < 32 ? raw.length : 32;
    for (var i = 0; i < copyLen; i++) {
      key32[i] = raw[i];
    }
    final encrypter = Encrypter(AES(Key(key32), mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: _iv);
    return _toHexUpper(encrypted.bytes);
  }

  // ─── Hex helpers ───────────────────────────────────────────────────────

  static String _toHexUpper(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return sb.toString();
  }

  static List<int> _fromHex(String hex) {
    final out = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }
}
