import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:sejong_smart_campus/features/home/domain/entities/event_card.dart';

/// 홈 Hero 이벤트 카드 목록 + 버전 시그니처를 로컬 파일에 영속화.
///
/// 다음 앱 실행 때 네트워크 없이 즉시 이전 목록을 그려주고(stale-while-revalidate),
/// DB에선 버전만 확인해 바뀐 경우에만 새로 받는다. 이미지 바이트는
/// cached_network_image(flutter_cache_manager)가 디스크에 캐시한다.
/// 저장 형식: `{ "version": "2:2026-...Z", "events": [ {EventCard.toJson}, ... ] }`.
/// [FacilityImagesCache]와 동일한 path_provider JSON 패턴.
class HomeEventsCache {
  static const _filename = 'home_events_cache.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  /// null이면 캐시 없음(첫 실행) → 호출자가 전체 fetch.
  Future<({String version, List<EventCard> events})?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final txt = await f.readAsString();
      if (txt.isEmpty) return null;
      final j = jsonDecode(txt) as Map<String, dynamic>;
      final version = (j['version'] ?? '').toString();
      final raw = (j['events'] as List?) ?? const [];
      if (version.isEmpty || raw.isEmpty) return null;
      final events = [
        for (final e in raw)
          if (e is Map<String, dynamic>) EventCard.fromJson(e),
      ];
      if (events.isEmpty) return null;
      return (version: version, events: events);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String version, List<EventCard> events) async {
    try {
      final f = await _file();
      await f.writeAsString(
        jsonEncode({
          'version': version,
          'events': [for (final e in events) e.toJson()],
        }),
      );
    } catch (_) {}
  }
}
