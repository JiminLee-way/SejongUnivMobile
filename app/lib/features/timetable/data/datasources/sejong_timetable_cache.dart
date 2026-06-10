import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 시간표 디스크 캐시 (JSON file).
///
/// 수강정정 종료 후 학기 끝까지 변경이 거의 없으므로 fetch 한 번 → 디스크 보관,
/// 사용자가 새로고침을 명시할 때만 재요청. 학기별로 독립된 파일이라 과거 학기
/// 조회는 즉시.
///
/// 파일 경로: `[appDocuments]/timetable_cache/[userId]_[year]_[smtCd].json`
/// 직렬화 포맷: `{ "timetable": [timetable raw], "enrolled": [enrolled raw],
///                "savedAt": "[iso8601]" }`
class SejongTimetableCache {
  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/timetable_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File _fileFor(Directory dir, String userId, String year, String smtCd) {
    final safeUid = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${dir.path}/${safeUid}_${year}_$smtCd.json');
  }

  Future<CachedTimetable?> read({
    required String userId,
    required String year,
    required String smtCd,
  }) async {
    try {
      final dir = await _dir();
      final f = _fileFor(dir, userId, year, smtCd);
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CachedTimetable(
        timetable: (json['timetable'] as Map).cast<String, dynamic>(),
        enrolled: (json['enrolled'] as Map).cast<String, dynamic>(),
        savedAt:
            DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (_) {
      // 캐시 손상 — 무시. 다음 fetch가 새로 적재.
      return null;
    }
  }

  Future<void> write({
    required String userId,
    required String year,
    required String smtCd,
    required Map<String, dynamic> timetable,
    required Map<String, dynamic> enrolled,
  }) async {
    final dir = await _dir();
    final f = _fileFor(dir, userId, year, smtCd);
    await f.writeAsString(
      jsonEncode({
        'timetable': timetable,
        'enrolled': enrolled,
        'savedAt': DateTime.now().toIso8601String(),
      }),
      flush: true,
    );
  }

  /// 로그아웃 시 호출 — 사용자별 캐시 일괄 삭제.
  Future<void> clearForUser(String userId) async {
    try {
      final dir = await _dir();
      final safeUid = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      await for (final f in dir.list()) {
        if (f is File && f.path.contains('/${safeUid}_')) {
          await f.delete();
        }
      }
    } catch (_) {}
  }
}

class CachedTimetable {
  CachedTimetable({
    required this.timetable,
    required this.enrolled,
    required this.savedAt,
  });
  final Map<String, dynamic> timetable;
  final Map<String, dynamic> enrolled;
  final DateTime savedAt;
}
