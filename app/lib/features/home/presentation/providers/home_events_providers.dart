import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/features/home/data/datasources/home_events_cache.dart';
import 'package:sejong_smart_campus/features/home/data/datasources/supabase_home_events_remote.dart';
import 'package:sejong_smart_campus/features/home/domain/entities/event_card.dart';

final _homeEventsRemoteProvider = Provider<SupabaseHomeEventsRemote>((ref) {
  return SupabaseHomeEventsRemote(Supabase.instance.client);
});

final _homeEventsCacheProvider = Provider<HomeEventsCache>(
  (ref) => HomeEventsCache(),
);

/// 홈 Hero 이벤트 카드 — Supabase `home_events` 공개 읽기.
///
/// **로컬 캐시 우선 + 버전 패리티 체크(stale-while-revalidate)** — 시설 사진과 동일:
///  1. 로컬 파일 캐시가 있으면 **즉시 반환** → 콜드스타트에도 네트워크 대기 없이 카드
///     노출(이미지 바이트는 cached_network_image가 디스크 캐시 → 즉시 렌더).
///  2. 백그라운드로 DB **버전 시그니처만**(updated_at) 조회 → 캐시와 같으면 아무것도
///     안 함(전체 재요청 X), 다르면 전체를 받아 캐시·state 갱신.
///  3. 캐시가 없으면(첫 실행) 전체를 받아 캐시에 저장.
///
/// non-autoDispose 세션 캐시 — pull-to-refresh/resume 시 invalidate하면 캐시 즉시
/// 노출 + 재검증(스켈레톤이 다시 뜨지 않는다). 부트스트랩(auth_gate)에서 prefetch.
class HomeEventsNotifier extends AsyncNotifier<List<EventCard>> {
  @override
  Future<List<EventCard>> build() async {
    final cache = ref.watch(_homeEventsCacheProvider);
    final cached = await cache.load();
    if (cached != null) {
      unawaited(_revalidate(cached.version));
      return cached.events;
    }
    final fresh = await ref.watch(_homeEventsRemoteProvider).fetchActive();
    await cache.save(fresh.version, fresh.events);
    return fresh.events;
  }

  Future<void> _revalidate(String knownVersion) async {
    try {
      final remote = ref.read(_homeEventsRemoteProvider);
      final remoteVersion = await remote.fetchVersion();
      if (remoteVersion == knownVersion) return; // 변경 없음 → 캐시 그대로.
      final fresh = await remote.fetchActive();
      await ref
          .read(_homeEventsCacheProvider)
          .save(fresh.version, fresh.events);
      state = AsyncData(fresh.events);
    } catch (_) {
      // 네트워크 실패 → 캐시 유지(state 미변경).
    }
  }
}

final homeEventsProvider =
    AsyncNotifierProvider<HomeEventsNotifier, List<EventCard>>(
      HomeEventsNotifier.new,
    );
