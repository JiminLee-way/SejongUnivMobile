import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';
import 'package:sejong_smart_campus/features/phone_directory/domain/entities/phone_directory_models.dart';

/// 학과사무실 목록 read-only adapter.
class SupabaseDeptOfficeRemote {
  SupabaseDeptOfficeRemote(this._client);

  final SupabaseClient _client;

  /// 활성 사무실을 `sort_order`(단과대학별로 연속되게 시드됨) 순서로 가져온다.
  Future<List<DeptOffice>> fetchAll() async {
    final rows = await _client
        .from(SupabaseConfig.tableDeptOffices)
        .select('college,department,sub_major,phone,is_special,sort_order')
        .eq('is_active', true)
        // supabase-dart의 .order()는 SQL과 달리 기본이 내림차순 → 명시적 오름차순.
        // (안 하면 단과대학·학과가 역순으로 뒤집혀 보임.)
        .order('sort_order', ascending: true);
    return [
      for (final r in rows as List<dynamic>)
        DeptOffice.fromJson(r as Map<String, dynamic>),
    ];
  }
}
