import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';

/// 푸시 디바이스 등록 — JS 정적 분석으로 발견된 endpoint.
///
/// - `POST /api/publicapi/mobile/devices/register`
///   body 추정: `{deviceId, platform, model?, osVersion?, appVersion?}`
/// - `PUT /api/publicapi/mobile/devices/{deviceId}/push-token`
///   body 추정: `{pushToken}`
///
/// **현재 상태**: FCM/APNs 인프라가 도입되지 않아 push token이 null.
/// 디바이스 등록까지만 한 번 호출 (token 없이도 sjapp이 받아주는지 확인용).
/// 실제 토큰은 FCM 도입 후 [updatePushToken]으로 별도 호출 예정.
class SejongPushRemote {
  SejongPushRemote({required this.client});
  final SejongApiClient client;

  Future<void> register({
    required String deviceId,
    required String platform,
    String? model,
    String? osVersion,
    String? appVersion,
  }) async {
    try {
      // ignore: use_null_aware_elements — map key는 string 리터럴이라 ?key 불가.
      await client.dio.post<dynamic>(
        '${SejongPrefix.publicApi}/mobile/devices/register',
        data: <String, dynamic>{
          'deviceId': deviceId,
          'platform': platform,
          if (model != null) 'model': model,
          if (osVersion != null) 'osVersion': osVersion,
          if (appVersion != null) 'appVersion': appVersion,
        },
      );
    } catch (_) {
      // best-effort — 등록 실패해도 앱 사용엔 영향 없음.
    }
  }

  Future<void> updatePushToken({
    required String deviceId,
    required String pushToken,
  }) async {
    try {
      await client.dio.put<dynamic>(
        '${SejongPrefix.publicApi}/mobile/devices/$deviceId/push-token',
        data: {'pushToken': pushToken},
      );
    } catch (_) {}
  }
}

/// 디바이스 ID 관리 — secure_storage에 1회 생성 후 영구 보관.
class DeviceIdProvider {
  DeviceIdProvider()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
  final FlutterSecureStorage _storage;
  static const _key = 'sejong.device_id';

  Future<String> ensure() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _generateDeviceId();
    await _storage.write(key: _key, value: id);
    return id;
  }

  /// 24자 base36 — 충분히 unique, secure storage에 저장되므로 회전 불필요.
  String _generateDeviceId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'dev_$hex';
  }

  String currentPlatform() {
    if (Platform.isAndroid) return 'ANDROID';
    if (Platform.isIOS) return 'IOS';
    return 'OTHER';
  }
}
