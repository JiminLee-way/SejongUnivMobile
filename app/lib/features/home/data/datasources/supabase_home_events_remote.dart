import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';
import 'package:sejong_smart_campus/features/home/domain/entities/event_card.dart';

/// Supabase-backed home event read-only adapter.
///
/// 정렬: sort_order ASC(관리자 지정 우선) → published_at DESC(최신순). 최대 10장.
class SupabaseHomeEventsRemote {
  SupabaseHomeEventsRemote(this._client);
  final SupabaseClient _client;

  static const int maxCards = 10;

  /// 경량 시그니처 — 활성 행의 updated_at만 조회 → '활성행수:max(updated_at)'.
  /// 캐시 버전과 비교해 "변경 여부"만 판별 → 매 실행 전체 재요청을 막는다.
  Future<String> fetchVersion() async {
    final rows = await _client
        .from(SupabaseConfig.tableHomeEvents)
        .select('updated_at')
        .eq('is_active', true)
        .order('updated_at', ascending: false);
    final list = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    final latest = list.isEmpty
        ? ''
        : (list.first['updated_at'] ?? '').toString();
    return '${list.length}:$latest';
  }

  /// 활성 카드 전체(sort_order 정렬, 최대 [maxCards]) + 동일 시그니처.
  /// 시그니처는 받은 행에서 계산 — 활성 행이 maxCards를 넘으면 [fetchVersion]과
  /// 어긋나 매번 재요청될 수 있으나(드문 케이스), 결과는 항상 정확하다.
  Future<({String version, List<EventCard> events})> fetchActive() async {
    final rows = await _client
        .from(SupabaseConfig.tableHomeEvents)
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .order('published_at', ascending: false)
        .limit(maxCards);
    final list = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    var maxU = '';
    for (final r in list) {
      final u = (r['updated_at'] ?? '').toString();
      if (u.compareTo(maxU) > 0) maxU = u;
    }
    final events = [for (final r in list) EventCard.fromJson(r)];
    return (version: '${list.length}:$maxU', events: events);
  }
}
