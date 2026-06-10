import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';

/// 자동출석에 필요한 런타임 권한 묶음 — BLE 스캔/연결 + 위치(스캔 전제) + 알림.
///
/// 자동출석이 ON(기본값)인데 권한이 없으면 [AppShell] 콜드부트에서 **매 실행**
/// 요청한다("안 켜면 실행 때마다"). 영구 거부(시스템 dialog 미표시) 상태는
/// [request]가 알려주므로, 호출자가 "설정 열기" 안내로 우회한다.
///
/// 권한 목록은 [BleScanner]의 스캔 직전 요청 집합 + 알림 권한을 합친 것 — 자동
/// 출석은 BLE 스캔 결과로 출석 처리 + 결과/리마인더 알림까지 보내기 때문.
class AutoAttendPermissions {
  const AutoAttendPermissions();

  static const List<Permission> _required = <Permission>[
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
    Permission.notification,
  ];

  /// 필요한 권한이 모두 granted 인지. (Android 외 플랫폼은 true로 통과)
  Future<bool> allGranted() async {
    if (!Platform.isAndroid) return true;
    for (final p in _required) {
      if (!await p.isGranted) return false;
    }
    return true;
  }

  /// 미허용 권한을 일괄 요청. 반환:
  ///  - granted           : 요청 후 전부 허용됐는지
  ///  - permanentlyDenied : 하나라도 영구 거부(=시스템 dialog가 더는 안 뜸)인지
  Future<({bool granted, bool permanentlyDenied})> request() async {
    if (!Platform.isAndroid) {
      return (granted: true, permanentlyDenied: false);
    }
    final statuses = await _required.request();
    final granted = statuses.values.every((s) => s.isGranted);
    final permanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
    return (granted: granted, permanentlyDenied: permanentlyDenied);
  }

  /// 앱 설정 화면 열기 — 영구 거부 우회용("설정 열기" 버튼).
  Future<bool> openSettings() => openAppSettings();
}
