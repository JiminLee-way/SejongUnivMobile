import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:sejong_smart_campus/core/diagnostics/crash_report.dart';

/// 앱/기기 진단 컨텍스트 — 1:1 문의·크래시 리포트에 자동 첨부. lazy(처음 watch 시
/// 1회) 로딩이라 부트스트랩 부담 없음. 실패한 필드는 빈 문자열로 둔다(전송 자체를
/// 막지 않는다).
final diagnosticsContextProvider = FutureProvider<DiagnosticsContext>((
  ref,
) async {
  var appVersion = '';
  try {
    final info = await PackageInfo.fromPlatform();
    appVersion = '${info.version}+${info.buildNumber}';
  } catch (_) {}

  var platform = 'unknown';
  var osVersion = '';
  var deviceModel = '';
  try {
    final di = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await di.androidInfo;
      platform = 'android';
      osVersion = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
      deviceModel = '${a.manufacturer} ${a.model}';
    } else if (Platform.isIOS) {
      final i = await di.iosInfo;
      platform = 'ios';
      osVersion = '${i.systemName} ${i.systemVersion}';
      deviceModel = i.utsname.machine;
    }
  } catch (_) {}

  return DiagnosticsContext(
    appVersion: appVersion,
    platform: platform,
    osVersion: osVersion,
    deviceModel: deviceModel,
  );
});
