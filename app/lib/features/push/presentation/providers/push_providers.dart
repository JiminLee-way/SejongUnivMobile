import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/push/data/datasources/sejong_push_remote.dart';

final _pushRemoteProvider = FutureProvider<SejongPushRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongPushRemote(client: client);
});

final _deviceIdProvider = Provider<DeviceIdProvider>(
  (ref) => DeviceIdProvider(),
);

/// 사용자가 로그인되면 한 번 디바이스 등록. FCM 인프라 도입 시 push token도
/// 함께 전달하도록 확장.
final pushDeviceBootstrapProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  final remote = await ref.watch(_pushRemoteProvider.future);
  final dev = ref.watch(_deviceIdProvider);
  final id = await dev.ensure();
  await remote.register(
    deviceId: id,
    platform: dev.currentPlatform(),
    appVersion: '1.0.0',
  );
});
