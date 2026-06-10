import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sejong_smart_campus/features/student_id/data/datasources/s1pass_native.dart';

/// S1Pass NFC 상태 — 학생증 화면 indicator 1개 위젯이 watch.
class S1PassStatus {
  const S1PassStatus({
    required this.nfcSupported,
    required this.nfcEnabled,
    required this.hasCardNo,
    required this.serviceRunning,
    required this.batteryUnrestricted,
  });

  /// 디바이스에 NFC 하드웨어가 있는가.
  final bool nfcSupported;

  /// 사용자가 NFC 토글을 켜놓았는가.
  final bool nfcEnabled;

  /// cardNo가 secure storage에 저장돼있는가.
  final bool hasCardNo;

  /// ForegroundService가 실행 중인가 (= 진짜 태깅 가능).
  final bool serviceRunning;

  /// 배터리 최적화 화이트리스트(제한 없음)에 등록돼있는가. false면 OS가 백그라운드/
  /// 앱 종료 상태에서 ForegroundService를 절전 종료할 수 있어 NFC 출입이 끊긴다.
  /// `ui` 상태에는 영향을 주지 않고(태깅 가능 여부는 별개), 화면에 별도 고지를 띄우는
  /// 용도. iOS 등 비-안드로이드는 항상 true(해당 개념 없음).
  final bool batteryUnrestricted;

  /// UI 한 줄 요약 —
  /// `ready` = NFC ON + 서비스 실행 중 → "NFC 출입 가능"
  /// `noNfc` = 하드웨어 없음 → "NFC 미지원"
  /// `nfcOff` = 하드웨어 있는데 사용자가 꺼둠 → "NFC 꺼짐"
  /// `noCard` = cardNo 없음 (로그인 안 된 상태)
  /// `notRunning` = 그 외 (service 시작 실패 등)
  S1PassUiState get ui {
    if (!nfcSupported) return S1PassUiState.noNfc;
    if (!nfcEnabled) return S1PassUiState.nfcOff;
    if (!hasCardNo) return S1PassUiState.noCard;
    if (!serviceRunning) return S1PassUiState.notRunning;
    return S1PassUiState.ready;
  }
}

enum S1PassUiState { ready, notRunning, nfcOff, noNfc, noCard }

/// 학생증 화면이 watch — 매번 진입/resume 시 invalidate해서 최신 native 상태.
final s1passStatusProvider = FutureProvider.autoDispose<S1PassStatus>((
  ref,
) async {
  final supported = await S1PassNative.isNfcSupported();
  // 하드웨어 없으면 나머지는 굳이 조회 X.
  if (!supported) {
    return const S1PassStatus(
      nfcSupported: false,
      nfcEnabled: false,
      hasCardNo: false,
      serviceRunning: false,
      batteryUnrestricted: true,
    );
  }
  final enabled = await S1PassNative.isNfcEnabled();
  final hasCard = await S1PassNative.hasCardNo();
  final running = await S1PassNative.isServiceRunning();
  // 배터리 최적화 예외 여부 — Android만 의미 있음.
  final batteryOk = Platform.isAndroid
      ? await Permission.ignoreBatteryOptimizations.isGranted
      : true;
  return S1PassStatus(
    nfcSupported: true,
    nfcEnabled: enabled,
    hasCardNo: hasCard,
    serviceRunning: running,
    batteryUnrestricted: batteryOk,
  );
});

/// 로그인/부팅 후 sjapp user가 도착하면 자동 활성화 — cardNo 저장 + service 시작.
/// 실패해도 silent (UI는 indicator로 확인).
///
/// Android 13+(minSdk=33)은 POST_NOTIFICATIONS 런타임 권한 없이 ForegroundService를
/// 시작하면 조용히 실패한다. 여기서 권한을 먼저 요청해야 서비스가 뜬다.
///
/// [promptPermissions] — 명시적 로그인(사용자가 직접 버튼 누름)일 때만 true.
/// 배터리 최적화 제외(`ignoreBatteryOptimizations`)는 미허용 상태에서 request()할
/// 때마다 시스템 다이얼로그를 다시 띄우므로, 앱 시작 자동복원(bootstrap)에서는
/// 띄우지 않는다 — 매 실행마다 다이얼로그가 뜨는 걸 막기 위함. 부팅/복원 경로에선
/// 학생증 화면의 고지 배너가 대신 사용자를 설정으로 안내한다.
Future<void> activateS1Pass(
  String cardNo, {
  bool promptPermissions = false,
}) async {
  if (cardNo.isEmpty) return;
  await S1PassNative.setCardNo(cardNo);
  if (Platform.isAndroid) {
    await Permission.notification.request();
    // 배터리 최적화 제한 없음 — 앱 종료/잠금/백그라운드에서도 service가 살아있어야
    // NFC 출입이 동작. 이미 허용돼있으면 request()는 다이얼로그 없이 즉시 반환.
    if (promptPermissions &&
        !await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
  await S1PassNative.startService();
}

/// 로그아웃 시 — cardNo 삭제 + service 정지.
Future<void> deactivateS1Pass() async {
  await S1PassNative.stopService();
  await S1PassNative.clearCardNo();
}
