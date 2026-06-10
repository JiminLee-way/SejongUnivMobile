import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/phone_directory/data/datasources/sejong_phone_remote.dart';
import 'package:sejong_smart_campus/features/phone_directory/data/datasources/supabase_dept_office_remote.dart';
import 'package:sejong_smart_campus/features/phone_directory/domain/entities/phone_directory_models.dart';

// ─── 학과사무실 (Supabase 공개 read-only) ───────────────────────────────────

final _deptOfficeRemoteProvider = Provider<SupabaseDeptOfficeRemote>((ref) {
  return SupabaseDeptOfficeRemote(Supabase.instance.client);
});

/// 학과사무실 전체. 거의 안 바뀌는 소량 데이터 → 세션 캐시(non-autoDispose).
/// 새로고침은 화면의 pull-to-refresh가 `ref.invalidate`로 처리.
final deptOfficesProvider = FutureProvider<List<DeptOffice>>((ref) async {
  final remote = ref.watch(_deptOfficeRemoteProvider);
  return remote.fetchAll();
});

// ─── 교직원 검색 (sjapp publicapi) ──────────────────────────────────────────

/// SejongApiClient는 FutureProvider라 await가 필요.
final _phoneRemoteProvider = FutureProvider<SejongPhoneRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongPhoneRemote(client: client);
});

/// 검색 질의 — keyword + type. record라 값 동등성으로 family 키가 안정적
/// (같은 (keyword,type)면 캐시 재사용, 바뀌면 자동 재조회).
typedef StaffQuery = ({String keyword, PhoneSearchType type});

/// 교직원 검색 결과. keyword가 비면 네트워크 호출 없이 빈 결과(브라우즈 모드 유지).
final staffSearchProvider = FutureProvider.autoDispose
    .family<StaffSearchResult, StaffQuery>((ref, query) async {
      final keyword = query.keyword.trim();
      if (keyword.isEmpty) return StaffSearchResult.empty;
      final remote = await ref.watch(_phoneRemoteProvider.future);
      return remote.search(keyword: keyword, type: query.type);
    });
