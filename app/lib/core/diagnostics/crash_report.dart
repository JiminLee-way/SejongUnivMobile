import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sejong_smart_campus/core/diagnostics/app_log.dart';

/// 앱의 **비정상 종료(크래시) 판별 + 진단 컨텍스트 영속화**.
///
/// 비정상 vs 정상 종료 구분은 오직 **세션 sentinel**([_dirtyPath])로 한다:
///  - [init]에서 `session.dirty` 파일을 동기 생성(= "세션 진행 중") 하고,
///  - 앱이 **정상적으로 백그라운드로 전환**(`paused`/`hidden`)될 때
///    [markSessionClean]이 그 파일을 지운다(= "깨끗이 끝남").
///  - 다음 실행의 [init]에서 그 파일이 **아직 남아 있으면** → 직전 세션이 포그라운드
///    도중 죽은 것 = **비정상 종료**([previousSessionUnclean]=true).
///
/// 왜 이 방식인가: 과거엔 [PlatformDispatcher.onError]가 한 번이라도 불리면 크래시로
/// 간주해 다음 실행에 프롬프트를 띄웠다. 그러나 그 핸들러는 **앱이 살아남는 비동기
/// 에러**(플러그인 PlatformException·네트워크 예외 등)에도 불리므로, 정상적으로 쓰고
/// 닫아도 "예기치 않게 종료됐어요"가 뜨는 오탐의 근본 원인이었다. sentinel은 "프로세스가
/// 포그라운드에서 죽었는가"라는 **진짜 종료 신호**만 본다. 스와이프로 앱을 닫아도 그 전에
/// `paused`를 거치므로 정상 종료로 분류된다. 보너스: 네이티브 크래시(SIGSEGV/OOM/강제
/// 종료)는 Dart 핸들러에 안 오지만 sentinel은 남으므로, 과거 방식이 못 잡던 것도 잡는다.
///
/// [persistSync]가 디스크에 남기는 에러 덤프([_path])는 이제 **트리거가 아니라 첨부용
/// 컨텍스트**다 — 비정상 종료가 확정됐을 때 리포트에 붙인다(있으면). 인메모리 [AppLog]는
/// 프로세스가 죽으면 사라지므로 핸들러는 **동기 write**만 한다(path_provider await 불가 대비).
class CrashReport {
  CrashReport._();
  static final CrashReport instance = CrashReport._();

  String? _path;
  String? _dirtyPath;
  bool _previousSessionUnclean = false;

  /// 직전 실행이 **깨끗하게(=백그라운드 진입) 끝나지 않았는지**. true면 비정상 종료
  /// (포그라운드 도중 프로세스 사망: 네이티브 크래시/OOM/강제 종료/Dart 치명 에러).
  /// [init]에서 1회 확정된다. release 빌드에서만 의미 있다(디버그 IDE-stop 오탐 회피).
  bool get previousSessionUnclean => _previousSessionUnclean;

  /// 부트스트랩에서 1회 — 덤프/sentinel 경로 확보 + **직전 세션 비정상 종료 판별** +
  /// 이번 세션 dirty 마킹. 판별은 dirty 마킹보다 **먼저** 해야 한다(이번 마킹이
  /// 직전 흔적을 덮어쓰기 전에 읽는다).
  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _path = '${dir.path}/pending_crash.log';
      _dirtyPath = '${dir.path}/session.dirty';
      if (kReleaseMode) {
        _previousSessionUnclean = File(_dirtyPath!).existsSync();
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

  void _markDirtySync() {
    final p = _dirtyPath;
    if (p == null) return;
    try {
      File(p).writeAsStringSync(DateTime.now().toIso8601String(), flush: true);
    } catch (_) {}
  }

  /// 정상 백그라운드 전환(`paused`/`hidden`) → 이 세션은 깨끗이 끝났다고 마킹.
  /// 누적된 에러 덤프도 함께 비워, 다음에 첨부될 컨텍스트가 **이 세션 것만** 되게 한다.
  void markSessionClean() {
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

/// 세션 sentinel을 라이프사이클에 묶는다 — paused/hidden(정상 백그라운드)에 clean,
/// resumed(포그라운드 복귀)에 다시 dirty. AppShell의 옵저버와 별개로 전역에 등록돼
/// 로그인 전 화면을 포함한 앱 수명 전체를 커버한다.
class _SessionLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      CrashReport.instance.markSessionClean();
    } else if (state == AppLifecycleState.resumed) {
      CrashReport.instance.markSessionActive();
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
