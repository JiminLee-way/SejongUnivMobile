import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sejong_smart_campus/core/ble/ibeacon_parser.dart';

/// BLE 스캔 한 번에 매칭되는 결과 — `attendCheck.do` 페이로드 구성에 필요한
/// 모든 raw 정보를 그대로 담는다.
class BleMatchResult {
  const BleMatchResult({
    required this.macAddress,
    required this.localName,
    required this.rssi,
    this.iBeacon,
  });

  /// `device.remoteId.str` — Android는 `AA:BB:CC:DD:EE:FF` 콜론 대문자, iOS는
  /// UUID 형식. 서버는 colon 형식만 받으므로 호출자가 정규화.
  final String macAddress;

  /// `advertisementData.advName`. 빈 문자열일 수 있음.
  final String localName;

  final int rssi;

  /// 0x004C manufacturerData 파싱 결과. iBeacon이 아니면 null.
  final IBeacon? iBeacon;

  @override
  String toString() =>
      'BleMatchResult(mac=$macAddress, name=$localName, rssi=$rssi, iBeacon=$iBeacon)';
}

/// BLE 스캔 진행 상태 — UI progress bar용.
sealed class BleScanState {
  const BleScanState();
}

class BleScanIdle extends BleScanState {
  const BleScanIdle();
}

class BleScanRunning extends BleScanState {
  const BleScanRunning({required this.startedAtMs, required this.timeoutMs});
  final int startedAtMs;
  final int timeoutMs;
}

class BleScanMatched extends BleScanState {
  const BleScanMatched(this.result);
  final BleMatchResult result;
}

class BleScanTimeout extends BleScanState {
  const BleScanTimeout();
}

class BleScanError extends BleScanState {
  const BleScanError(this.message);
  final String message;
}

class BleScanPermissionDenied extends BleScanState {
  const BleScanPermissionDenied(this.deniedPermissions);
  final List<String> deniedPermissions;
}

class BleScanBluetoothOff extends BleScanState {
  const BleScanBluetoothOff();
}

/// Foreground BLE 스캔 wrapper. **앱이 포어그라운드에 있을 때만** 동작.
///
/// V1은 사용자가 강의실에서 UCheck 화면을 열고 "출석 체크" 버튼을 눌렀을 때
/// 10초 안에 매칭 비콘 1개를 찾으면 OK. 백그라운드/앱 종료 상태 스캔은 V2에서
/// Kotlin native (`AutoAttendService` + `FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE`)
/// 로 보강 예정.
///
/// ## 매칭 룰
///
/// 서버 `getInfo.do` 응답의 `b_maddr[]` (MAC 화이트리스트) 또는 `local_name[]`
/// (advertised name 화이트리스트) 중 하나라도 매칭되면 즉시 stop + return.
/// RSSI 임계값 없음 — 강의실 근접만 가정.
///
/// ## ScanFilter
///
/// iBeacon manufacturerData (Apple 0x004C `[0x02, 0x15, ...]`) OS-레벨 필터.
/// 안 걸면 모든 BLE 광고가 콜백으로 들어와 JVM 부하 큼. 삼성 One UI screen-off
/// 신뢰성도 OS 필터 있을 때 더 안정적이다.
class BleScanner {
  BleScanner();

  /// 매칭 비콘을 찾으면 [BleMatchResult] 반환, 타임아웃이면 null.
  /// 권한/블루투스 OFF 같은 사전 조건 실패는 [BleScanState] stream에만 발행
  /// (caller가 다른 처리를 해야 함).
  Stream<BleScanState> scan({
    required List<String> targetMacs,
    required List<String> targetLocalNames,
    Duration timeout = const Duration(seconds: 10),
  }) async* {
    // 1) 권한 확인 + 요청
    final deniedPerms = await _ensurePermissions();
    if (deniedPerms.isNotEmpty) {
      yield BleScanPermissionDenied(deniedPerms);
      return;
    }

    // 2) Bluetooth ON 확인.
    // adapterStateNow는 스트림 첫 이벤트 전까지 unknown이라 신뢰 불가.
    // adapterState 스트림은 구독 즉시 현재 상태를 emit하므로 first로 읽는다.
    BluetoothAdapterState adapterState;
    try {
      adapterState = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      adapterState = FlutterBluePlus.adapterStateNow;
    }
    if (adapterState != BluetoothAdapterState.on) {
      yield const BleScanBluetoothOff();
      return;
    }

    // 3) 정규화된 화이트리스트
    final macSet = targetMacs
        .map((m) => m.trim().replaceAll('-', ':').toUpperCase())
        .where((m) => m.isNotEmpty)
        .toSet();
    final nameSet = targetLocalNames
        .map((n) => n.trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet();

    // 4) 스캔 시작
    final start = DateTime.now().millisecondsSinceEpoch;
    yield BleScanRunning(startedAtMs: start, timeoutMs: timeout.inMilliseconds);

    StreamSubscription<List<ScanResult>>? sub;
    BleMatchResult? matched;
    final completer = Completer<void>();
    Timer? timeoutTimer;

    try {
      sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final mac = r.device.remoteId.str.toUpperCase();
          final name = (r.advertisementData.advName).toLowerCase();
          // 예약/출결과 무관한 prefix는 매칭 제외.
          if (name.startsWith('sitin') || name.startsWith('libeka')) continue;

          final macHit = macSet.contains(mac);
          final nameHit = name.isNotEmpty && nameSet.contains(name);
          if (!macHit && !nameHit) continue;

          final msd =
              r.advertisementData.manufacturerData[kIBeaconManufacturerId];
          matched = BleMatchResult(
            macAddress: mac,
            localName: r.advertisementData.advName,
            rssi: r.rssi,
            iBeacon: msd == null ? null : parseIBeacon(msd),
          );
          if (!completer.isCompleted) completer.complete();
          return;
        }
      });

      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete();
      });

      await FlutterBluePlus.startScan(
        withMsd: [
          MsdFilter(
            kIBeaconManufacturerId,
            data: [0x02, 0x15],
            mask: [0xFF, 0xFF],
          ),
        ],
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
      );

      await completer.future;
    } catch (e) {
      yield BleScanError('스캔 실패: $e');
      return;
    } finally {
      timeoutTimer?.cancel();
      await sub?.cancel();
      // stopScan은 idempotent — 이미 timeout으로 중단됐어도 안전
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }

    if (matched != null) {
      yield BleScanMatched(matched!);
    } else {
      yield const BleScanTimeout();
    }
  }

  /// 진행 중인 스캔 강제 중단 (사용자 cancel).
  Future<void> cancel() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  /// 필요한 권한을 모두 요청 후, 여전히 denied 인 권한 이름 반환.
  /// Android만 의미 있음 (iOS는 NSBluetoothAlwaysUsageDescription Info.plist).
  Future<List<String>> _ensurePermissions() async {
    if (!Platform.isAndroid) return const [];
    final perms = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final denied = <String>[];
    perms.forEach((p, status) {
      if (!status.isGranted) {
        denied.add(_permLabel(p));
      }
    });
    return denied;
  }

  String _permLabel(Permission p) {
    if (p == Permission.bluetoothScan) return '블루투스 스캔';
    if (p == Permission.bluetoothConnect) return '블루투스 연결';
    if (p == Permission.locationWhenInUse) return '위치';
    return p.toString();
  }
}
