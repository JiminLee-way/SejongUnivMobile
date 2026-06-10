import 'package:flutter/services.dart';

/// `ac.sejong/s1pass` MethodChannel — Android Kotlin native (S1PassManager)
/// 1:1 wrapper.
///
/// 모든 메서드 idempotent + 실패 silent (Future가 success/null로 끝남).
/// 비-안드로이드 플랫폼은 무조건 false/no-op.
class S1PassNative {
  S1PassNative._();
  static const _channel = MethodChannel('ac.sejong/s1pass');

  /// 학번에 매핑된 cardNo (sjapp `/auth/me` 응답의 `cardNo`) 저장.
  /// EncryptedSharedPreferences에 즉시 sync. 이후 NFC 리더가 SELECT APDU
  /// 보내면 HCE service가 이 값으로 응답.
  static Future<void> setCardNo(String cardNo) async {
    if (cardNo.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('setCardNo', {'cardNo': cardNo});
    } on PlatformException catch (_) {
      // iOS / unsupported — silent skip.
    }
  }

  /// 로그아웃 시 cardNo + token + service 모두 정리.
  static Future<void> clearCardNo() async {
    try {
      await _channel.invokeMethod<void>('clearCardNo');
    } on PlatformException catch (_) {}
  }

  /// S1PassForegroundService 시작. cardNo가 저장돼있고 POST_NOTIFICATIONS
  /// 권한이 있을 때만 native 측에서 실행 (없으면 silent skip).
  /// 반환: 실제 실행 중이면 true, 아니면 false.
  static Future<bool> startService() async {
    try {
      final running = await _channel.invokeMethod<bool>('startService');
      return running ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> stopService() async {
    try {
      await _channel.invokeMethod<void>('stopService');
    } on PlatformException catch (_) {}
  }

  /// 디바이스에 NFC 하드웨어 있는지 (대부분 단말 yes).
  static Future<bool> isNfcSupported() async {
    try {
      return (await _channel.invokeMethod<bool>('isNfcSupported')) ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// 사용자가 NFC 토글을 켜놓았는지.
  static Future<bool> isNfcEnabled() async {
    try {
      return (await _channel.invokeMethod<bool>('isNfcEnabled')) ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// ForegroundService 실행 중 여부 — UI indicator용.
  static Future<bool> isServiceRunning() async {
    try {
      return (await _channel.invokeMethod<bool>('isServiceRunning')) ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// cardNo가 secure storage에 저장돼있는지 — 부팅 직후 service 시작 가능
  /// 여부 판단용.
  static Future<bool> hasCardNo() async {
    try {
      return (await _channel.invokeMethod<bool>('hasCardNo')) ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
