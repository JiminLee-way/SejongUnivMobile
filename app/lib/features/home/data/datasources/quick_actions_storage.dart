import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 사용자가 편집한 홈 바로가기 키 순서를 로컬 파일에 영속화.
///
/// 서버 spec이 없어 디바이스 로컬에만 둔다 ([MenuOrderStorage] 와 동일 패턴).
/// 첫 실행 시 파일 없으면 호출자가 `kDefaultQuickActionKeys`로 fallback.
class QuickActionsStorage {
  static const _filename = 'shortcut_order.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  /// null이면 "저장된 게 없음" → 기본값 사용.
  Future<List<String>?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final txt = await f.readAsString();
      if (txt.isEmpty) return null;
      final j = jsonDecode(txt) as Map<String, dynamic>;
      final keys = (j['keys'] as List?)?.cast<String>();
      return keys;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(List<String> keys) async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'keys': keys}));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
