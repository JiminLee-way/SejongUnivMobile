import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 스크린샷/화면 녹화/최근 앱 미리보기 방지 토글.
///
/// Android: `WindowManager.LayoutParams.FLAG_SECURE` on/off via MethodChannel.
/// iOS: 별도 처리 필요 (현재는 no-op). iOS 도입 시 `UIScreen.capturedDidChange`
/// 옵저버로 추가 보호 가능.
class SecureScreen {
  SecureScreen._();

  static const _channel = MethodChannel('ac.sejong/secure_screen');

  static Future<void> enable() async {
    if (!defaultTargetPlatform.supportsFlagSecure) return;
    try {
      await _channel.invokeMethod<void>('enable');
    } on PlatformException {
      // 호스트 측 핸들러 미설치/실패 — 방어적으로 무시.
    }
  }

  static Future<void> disable() async {
    if (!defaultTargetPlatform.supportsFlagSecure) return;
    try {
      await _channel.invokeMethod<void>('disable');
    } on PlatformException {
      // ignore
    }
  }
}

extension on TargetPlatform {
  bool get supportsFlagSecure => this == TargetPlatform.android;
}
