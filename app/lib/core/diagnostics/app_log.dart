import 'dart:collection';

import 'package:flutter/foundation.dart';

/// 앱 진단용 **인메모리 링 버퍼**.
///
/// 최근 [_maxAge](3분) 또는 [_maxLines](600줄) 중 먼저 도달하는 한도까지의 로그를
/// 들고 있다가, 사용자가 1:1 문의에 첨부하거나 크래시 발생 시 디스크로 덤프된다.
/// **외부 전송 없음(로컬)** — Sentry 자동 수집과 별개로, "사용자가 직접 첨부해
/// 보내는 최근 로그"의 출처다.
///
/// PII가 섞일 수 있으므로 화면 노출/전송은 **사용자 동의**(문의 첨부 토글, 크래시
/// 프롬프트) 시에만. 버퍼 자체는 메모리에만 있고 앱 종료 시 사라진다(크래시 덤프
/// 파일만 다음 실행까지 남음 — [CrashReport] 참고).
class AppLog {
  AppLog._();
  static final AppLog instance = AppLog._();

  static const int _maxLines = 600;
  static const Duration _maxAge = Duration(minutes: 3);

  final Queue<_LogLine> _buf = Queue<_LogLine>();

  /// 한 줄 기록. [level]은 단일 문자 태그(I/W/E/F).
  void add(String message, {String level = 'I'}) {
    if (message.isEmpty) return;
    final now = DateTime.now();
    _buf.addLast(_LogLine(now, level, message));
    _trim(now);
  }

  void _trim(DateTime now) {
    final cutoff = now.subtract(_maxAge);
    while (_buf.isNotEmpty &&
        (_buf.length > _maxLines || _buf.first.at.isBefore(cutoff))) {
      _buf.removeFirst();
    }
  }

  /// 사람이 읽는 텍스트 덤프(오래된 → 최신). 첨부/저장용. 버퍼가 비면 빈 문자열.
  String dump() {
    final b = StringBuffer();
    for (final l in _buf) {
      b.writeln('${l.at.toIso8601String()} ${l.level} ${l.message}');
    }
    return b.toString();
  }

  bool get isEmpty => _buf.isEmpty;

  void clear() => _buf.clear();

  /// 앱 전역 [debugPrint]를 가로채 버퍼에도 적재한다. main()에서 1회 호출.
  /// 원래 출력(콘솔/logcat)은 그대로 유지 — 체이닝.
  void installDebugPrintHook() {
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) add(message);
      original(message, wrapWidth: wrapWidth);
    };
  }
}

class _LogLine {
  _LogLine(this.at, this.level, this.message);
  final DateTime at;
  final String level;
  final String message;
}
