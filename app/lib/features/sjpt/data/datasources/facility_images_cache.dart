import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 시설 사진 매핑(room_abbt→URL) + 버전 시그니처를 로컬 파일에 영속화.
///
/// 다음 앱 실행 때 네트워크 없이 즉시 이전 매핑을 그려주고(stale-while-revalidate),
/// DB에선 버전만 확인해 바뀐 경우에만 새로 받기 위함. 이미지 바이트 자체는
/// cached_network_image(flutter_cache_manager)가 디스크에 캐시한다.
/// 저장 형식: `{ "version": "9:2026-...Z", "map": { "광106": "https://..." } }`.
/// [QuickActionsStorage]·[MenuOrderStorage] 와 동일한 path_provider JSON 패턴.
class FacilityImagesCache {
  static const _filename = 'facility_images_cache.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  /// null이면 캐시 없음(첫 실행) → 호출자가 전체 fetch.
  Future<({String version, Map<String, String> map})?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final txt = await f.readAsString();
      if (txt.isEmpty) return null;
      final j = jsonDecode(txt) as Map<String, dynamic>;
      final version = (j['version'] ?? '').toString();
      final raw = (j['map'] as Map?) ?? const <dynamic, dynamic>{};
      final map = <String, String>{
        for (final e in raw.entries) e.key.toString(): e.value.toString(),
      };
      if (version.isEmpty || map.isEmpty) return null;
      return (version: version, map: map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String version, Map<String, String> map) async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'version': version, 'map': map}));
    } catch (_) {}
  }
}
