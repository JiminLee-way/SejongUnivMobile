import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';

/// Supabase-backed facility image read-only adapter.
///
/// 두 가지 읽기 모드:
/// - [fetchVersion] — 패리티 체크용 경량 시그니처(`활성행수:max(updated_at)`).
///   updated_at 한 컬럼만 받아 "변경 여부"만 판별 → 매 실행 전체 재요청을 막는다.
/// - [fetchActive] — 활성 시설의 room_abbt→image_url 전체 맵 + 동일 시그니처.
///
/// 신규/수정/노출토글(트리거가 updated_at 갱신)·하드삭제 모두 시그니처를 바꾸므로
/// 버전만 비교해도 갱신 필요 여부를 정확히 알 수 있다.
class SupabaseFacilityImagesRemote {
  SupabaseFacilityImagesRemote(this._client);
  final SupabaseClient _client;

  /// 경량 시그니처. 활성 행의 updated_at만 조회 → '갯수:최신updated_at'.
  Future<String> fetchVersion() async {
    final rows = await _client
        .from(SupabaseConfig.tableFacilityImages)
        .select('updated_at')
        .eq('is_active', true)
        .order('updated_at', ascending: false);
    return _signature(rows as List<dynamic>);
  }

  /// 전체 활성 맵 + 시그니처(같은 응답에서 계산 — 버전/데이터 레이스 없음).
  Future<({String version, Map<String, String> map})> fetchActive() async {
    final rows = await _client
        .from(SupabaseConfig.tableFacilityImages)
        .select('room_abbt, image_url, updated_at')
        .eq('is_active', true)
        .order('updated_at', ascending: false);
    final list = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    final map = <String, String>{
      for (final r in list)
        (r['room_abbt'] ?? '').toString(): (r['image_url'] ?? '').toString(),
    };
    return (version: _signatureOf(list), map: map);
  }

  String _signature(List<dynamic> rows) =>
      _signatureOf(rows.cast<Map<String, dynamic>>());

  String _signatureOf(List<Map<String, dynamic>> list) {
    final latest = list.isEmpty
        ? ''
        : (list.first['updated_at'] ?? '').toString();
    return '${list.length}:$latest';
  }
}
