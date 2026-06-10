import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';

/// libseat 예약/반납/연장/취소 timeline 로컬 저장소.
///
/// libseat 백엔드가 "내 이용 이력" endpoint를 따로 노출하는지 확정되지 않아
/// v1은 클라이언트 timeline으로 운영한다. 사용자가 앱에서 좌석을 예약/반납할
/// 때마다 [append]를 호출 → JSON 파일에 prepend. 후속 정찰에서 server 이력
/// endpoint가 발견되면 이 저장소를 fallback cache로 강등.
///
/// 파일 위치: appSupport/usage_history.json (사용자별로 별도가 아닌
/// "현재 로그인된 사용자" 가정 — 다중 사용자는 v2).
class UsageHistoryLocal {
  UsageHistoryLocal();

  static const _maxEntries = 200;
  static const _fileName = 'usage_history.json';
  File? _cachedFile;

  Future<File> _file() async {
    final cached = _cachedFile;
    if (cached != null) return cached;
    final dir = await getApplicationSupportDirectory();
    final f = File('${dir.path}/$_fileName');
    _cachedFile = f;
    return f;
  }

  Future<List<LibraryUsageRecord>> getAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return const [];
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(_fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> append(LibraryUsageRecord record) async {
    final all = await getAll();
    final next = [record, ...all].take(_maxEntries).toList();
    final f = await _file();
    await f.writeAsString(jsonEncode(next.map(_toJson).toList()));
  }

  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }

  static Map<String, dynamic> _toJson(LibraryUsageRecord r) => {
    'startedAt': r.startedAt.toIso8601String(),
    'endedAt': r.endedAt.toIso8601String(),
    'roomLabel': r.roomLabel,
    'status': r.status.name,
  };

  static LibraryUsageRecord _fromJson(Map<String, dynamic> j) =>
      LibraryUsageRecord(
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: DateTime.parse(j['endedAt'] as String),
        roomLabel: j['roomLabel'] as String,
        status: _parseStatus(j['status'] as String?),
      );

  static LibraryUsageStatus _parseStatus(String? raw) => switch (raw) {
    'completed' => LibraryUsageStatus.completed,
    'unreturned' => LibraryUsageStatus.unreturned,
    'autoReturned' => LibraryUsageStatus.autoReturned,
    _ => LibraryUsageStatus.completed,
  };
}
