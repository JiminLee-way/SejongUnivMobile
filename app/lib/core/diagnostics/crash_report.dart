import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sejong_smart_campus/core/diagnostics/app_log.dart';

/// 앱의 **비정상 종료(크래시) 판별 + 진단 컨텍스트 영속화**.
///
/// 사용자에게 "직전 비정상 종료" 프롬프트를 띄우는 기준은 **Android가 기록한 실제
/// 종료 사유**([ApplicationExitInfo])다. 예전처럼 `session.dirty` 파일만 보고
/// 판단하면 정상 앱 종료, 최근 앱 제거, 앱 업데이트, `adb install -r` 같은 케이스도
/// 크래시로 오탐된다.
///
/// [persistSync]가 디스크에 남기는 에러 덤프([_path])와 `session.dirty`는
/// **첨부/보조 컨텍스트**다. 프롬프트 트리거가 아니다.
class CrashReport {
  CrashReport._();
  static final CrashReport instance = CrashReport._();

  static const MethodChannel _diagnosticsChannel = MethodChannel(
    'ac.sejong/diagnostics',
  );

  String? _path;
  String? _dirtyPath;
  String? _ackPath;
  CrashEvidence? _previousCrashEvidence;

  /// 직전 실행에서 사용자에게 알릴 만한 실제 crash/anr 증거. 없으면 프롬프트 금지.
  CrashEvidence? get previousCrashEvidence => _previousCrashEvidence;

  /// 호환용 getter. 새 코드는 [previousCrashEvidence]를 사용한다.
  @Deprecated('Use previousCrashEvidence instead.')
  bool get previousSessionUnclean => _previousCrashEvidence != null;

  /// 부트스트랩에서 1회 — 덤프/sentinel 경로 확보 + Android 종료 사유 조회 +
  /// 이번 세션 dirty 마킹. dirty 파일은 보조 컨텍스트이며 prompt 조건이 아니다.
  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _path = '${dir.path}/pending_crash.log';
      _dirtyPath = '${dir.path}/session.dirty';
      _ackPath = '${dir.path}/last_crash_evidence_ack.txt';
      if (kReleaseMode) {
        _previousCrashEvidence = await _loadPreviousCrashEvidence();
        if (_previousCrashEvidence == null) {
          _clearStaleCrashContextSync();
        }
        _markDirtySync(); // 이번 세션 시작 — paused에서 markSessionClean()이 지운다.
      }
    } catch (_) {
      // 경로 확보 실패 시 크래시 영속화/판별 비활성(앱 동작엔 영향 없음).
    }
  }

  /// 앱 라이프사이클 옵저버 설치 — main()에서 release 빌드에 1회. **로그인 전
  /// 화면에서도** dirty 해제가 동작해야 하므로 AppShell이 아니라 전역에 단다.
  void installLifecycleObserver() {
    WidgetsBinding.instance.addObserver(_SessionLifecycleObserver());
  }

  Future<CrashEvidence?> _loadPreviousCrashEvidence() async {
    final acknowledgedUntilMillis = _readAcknowledgedUntilMillisSync();
    final exits = await fetchRecentExitInfo();
    return selectReportableEvidence(
      exits,
      acknowledgedUntilMillis: acknowledgedUntilMillis,
    );
  }

  /// Android가 기록한 최근 process exit 이력을 가져온다. MethodChannel 실패는
  /// prompt 비활성으로 처리해 오탐보다 누락을 선택한다.
  Future<List<CrashEvidence>> fetchRecentExitInfo() async {
    try {
      final raw = await _diagnosticsChannel.invokeMethod<List<dynamic>>(
        'getRecentExitInfo',
      );
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(CrashEvidence.fromNativeMap)
          .where((e) => e != null)
          .cast<CrashEvidence>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @visibleForTesting
  static CrashEvidence? selectReportableEvidence(
    Iterable<CrashEvidence> exits, {
    int? acknowledgedUntilMillis,
  }) {
    final sorted = exits.toList()
      ..sort((a, b) => b.timestampMillis.compareTo(a.timestampMillis));
    for (final exit in sorted) {
      if (!exit.isReportable) continue;
      if (acknowledgedUntilMillis != null &&
          exit.timestampMillis <= acknowledgedUntilMillis) {
        continue;
      }
      return exit;
    }
    return null;
  }

  int? _readAcknowledgedUntilMillisSync() {
    final p = _ackPath;
    if (p == null) return null;
    try {
      final f = File(p);
      if (!f.existsSync()) return null;
      return int.tryParse(f.readAsStringSync().trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> acknowledgePreviousCrash() async {
    final evidence = _previousCrashEvidence;
    if (evidence == null) return;
    _previousCrashEvidence = null;
    final p = _ackPath;
    if (p == null) return;
    try {
      final ackFile = File(p);
      await ackFile.writeAsString(
        evidence.timestampMillis.toString(),
        flush: true,
      );
    } catch (_) {}
  }

  void _markDirtySync() {
    final p = _dirtyPath;
    if (p == null) return;
    try {
      File(p).writeAsStringSync(DateTime.now().toIso8601String(), flush: true);
    } catch (_) {}
  }

  void _clearStaleCrashContextSync() {
    try {
      final d = _dirtyPath;
      if (d != null) {
        final f = File(d);
        if (f.existsSync()) f.deleteSync();
      }
      final c = _path;
      if (c != null) {
        final f = File(c);
        if (f.existsSync()) f.deleteSync();
      }
    } catch (_) {}
  }

  /// 정상 백그라운드 전환 → 이 세션은 깨끗이 끝났다고 마킹.
  /// 누적된 에러 덤프도 함께 비워, 다음에 첨부될 컨텍스트가 **이 세션 것만** 되게 한다.
  void markSessionClean() => _clearStaleCrashContextSync();

  /// 포그라운드 복귀(`resumed`) → 이 세션 동안 다시 크래시 가능하므로 dirty 재마킹.
  void markSessionActive() => _markDirtySync();

  /// 에러 핸들러 안에서 호출 — **동기**로 덤프. 실패해도 조용히 무시(핸들러를
  /// 다시 throw로 오염시키지 않는다).
  void persistSync(Object error, StackTrace stack) {
    final p = _path;
    if (p == null) return;
    try {
      final content = StringBuffer()
        ..writeln('time=${DateTime.now().toIso8601String()}')
        ..writeln('error=$error')
        ..writeln('--- stack ---')
        ..writeln(stack.toString())
        ..writeln('--- recent log (≤3min) ---')
        ..write(AppLog.instance.dump());
      File(p).writeAsStringSync(content.toString(), flush: true);
    } catch (_) {
      // 디스크 write 실패 무시.
    }
  }

  /// 직전 실행에서 남긴 크래시 덤프가 있으면 내용을 반환하고 파일을 삭제(1회성).
  /// 없으면 null.
  Future<String?> takePending() async {
    final p = _path;
    if (p == null) return null;
    try {
      final f = File(p);
      if (!await f.exists()) return null;
      final s = await f.readAsString();
      await f.delete();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  /// 80KB 상한으로 자른 로그(app_inquiries.log_excerpt 컬럼 제약과 일치).
  static String clamp(String log, {int max = 80000}) {
    if (log.length <= max) return log;
    // 최신 부분이 더 유용하므로 뒤쪽을 남긴다.
    return '…(앞부분 생략)\n${log.substring(log.length - max)}';
  }
}

@immutable
class CrashEvidence {
  const CrashEvidence({
    required this.reason,
    required this.reasonName,
    required this.timestampMillis,
    this.description,
    this.importance,
    this.status,
    this.processName,
  });

  final int reason;
  final String reasonName;
  final int timestampMillis;
  final String? description;
  final int? importance;
  final int? status;
  final String? processName;

  static CrashEvidence? fromNativeMap(Map<dynamic, dynamic> raw) {
    final reason = _asInt(raw['reason']);
    final timestamp = _asInt(raw['timestamp']);
    if (reason == null || timestamp == null) return null;
    return CrashEvidence(
      reason: reason,
      reasonName: raw['reasonName']?.toString() ?? 'REASON_$reason',
      timestampMillis: timestamp,
      description: raw['description']?.toString(),
      importance: _asInt(raw['importance']),
      status: _asInt(raw['status']),
      processName: raw['processName']?.toString(),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String get id => '$timestampMillis:$reason:${processName ?? ''}';

  bool get isReportable => switch (reasonName) {
    'REASON_CRASH' ||
    'REASON_CRASH_NATIVE' ||
    'REASON_ANR' ||
    'REASON_INITIALIZATION_FAILURE' => true,
    _ => false,
  };

  String toReportLog() {
    final at = DateTime.fromMillisecondsSinceEpoch(timestampMillis).toLocal();
    final buffer = StringBuffer()
      ..writeln('--- Android process exit info ---')
      ..writeln('time=$at')
      ..writeln('reason=$reasonName ($reason)');
    final p = processName;
    if (p != null && p.isNotEmpty) buffer.writeln('process=$p');
    final d = description;
    if (d != null && d.isNotEmpty) buffer.writeln('description=$d');
    final i = importance;
    if (i != null) buffer.writeln('importance=$i');
    final s = status;
    if (s != null) buffer.writeln('status=$s');
    return buffer.toString().trimRight();
  }
}

/// 세션 sentinel을 라이프사이클에 묶는다. sentinel은 prompt 조건이 아니라,
/// 실제 crash/anr evidence가 있을 때 첨부할 보조 컨텍스트를 남기기 위한 장치다.
class _SessionLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        CrashReport.instance.markSessionActive();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        CrashReport.instance.markSessionClean();
    }
  }
}

/// 진단 컨텍스트 — 문의에 자동 첨부할 앱/기기 정보. [load]는 package_info_plus +
/// device_info_plus를 lazy 호출(부트스트랩 부담 X, compose 시점에 1회).
@immutable
class DiagnosticsContext {
  const DiagnosticsContext({
    required this.appVersion,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
  });

  final String appVersion;
  final String platform;
  final String osVersion;
  final String deviceModel;
}
