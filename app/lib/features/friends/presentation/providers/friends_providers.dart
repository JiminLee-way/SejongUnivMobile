import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/features/friends/data/datasources/supabase_friends_remote.dart';
import 'package:sejong_smart_campus/features/friends/data/datasources/supabase_onboarding_remote.dart';
import 'package:sejong_smart_campus/features/friends/domain/entities/friend_models.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart'
    as tt;
import 'package:sejong_smart_campus/core/demo/demo.dart';

/// 전역 Supabase 클라이언트 — main.dart의 Supabase.initialize 이후 사용 가능.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseOnboardingProvider = Provider<SupabaseOnboardingRemote>((ref) {
  return SupabaseOnboardingRemote(ref.watch(supabaseClientProvider));
});

final supabaseFriendsRemoteProvider = Provider<SupabaseFriendsRemote>((ref) {
  return SupabaseFriendsRemote(ref.watch(supabaseClientProvider));
});

/// 현재 Supabase session — auth state stream을 watch해 로그인/아웃에 반응.
final supabaseAuthStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// session이 살아있을 때만 친구 list fetch. 그 외엔 빈 list.
final myFriendsProvider = FutureProvider.autoDispose<List<SupabaseFriend>>((
  ref,
) async {
  ref.watch(supabaseAuthStateProvider);
  final client = ref.watch(supabaseClientProvider);
  if (client.auth.currentSession == null) return const [];
  final remote = ref.watch(supabaseFriendsRemoteProvider);
  return remote.listMyFriends();
});

final pendingFriendRequestsProvider =
    FutureProvider.autoDispose<List<SupabaseFriendRequest>>((ref) async {
      ref.watch(supabaseAuthStateProvider);
      final client = ref.watch(supabaseClientProvider);
      if (client.auth.currentSession == null) return const [];
      final remote = ref.watch(supabaseFriendsRemoteProvider);
      return remote.listPendingRequests();
    });

/// 친구 액션 후 invalidate helper — UI 측 button onTap에서 호출.
Future<void> refreshFriends(WidgetRef ref) async {
  ref.invalidate(myFriendsProvider);
  ref.invalidate(pendingFriendRequestsProvider);
}

/// 본인 "친구 검색 허용" 토글 상태. build()에서 서버값을 로드하고, [set]으로
/// 낙관적 갱신(실패 시 롤백 + rethrow)한다. session 없으면 기본 true(노출).
///
/// 기본 노출(opt-out): 가입 즉시 검색되며 MY 세종에서 끌 수 있다. 서버 컬럼
/// `users.searchable` 기본값 true와 일치.
class SearchVisibilityNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    ref.watch(supabaseAuthStateProvider);
    final client = ref.watch(supabaseClientProvider);
    if (client.auth.currentSession == null) return true;
    final remote = ref.watch(supabaseFriendsRemoteProvider);
    return remote.getSearchVisible();
  }

  /// 낙관적 토글 — 즉시 UI 반영 후 서버 반영. 실패 시 이전 값으로 롤백하고
  /// 예외를 다시 던져 호출부(스낵바 등)가 알 수 있게 한다.
  Future<void> set(bool on) async {
    final prev = state.value ?? true;
    state = AsyncData(on);
    try {
      final remote = ref.read(supabaseFriendsRemoteProvider);
      final saved = await remote.setSearchVisible(on);
      state = AsyncData(saved);
    } catch (e, st) {
      state = AsyncData(prev);
      Error.throwWithStackTrace(e, st);
    }
  }
}

final searchVisibilityProvider =
    AsyncNotifierProvider<SearchVisibilityNotifier, bool>(
      SearchVisibilityNotifier.new,
    );

// ─── 기존 timetable UI(Friend 모델) 호환 어댑터 ───────────────────────────
//
// timetable_screen / common_free_time_screen이 [tt.Friend] 모델로 작성돼있어
// SupabaseFriend → tt.Friend 변환을 거쳐 그대로 주입한다. 실시간 status
// (수업 중/공강/...)는 친구 시간표 공유 RPC가 도입되면 클라이언트 측 derive
// 로 채울 예정 — 현재는 [tt.FriendStatus.offline]로 통일.

tt.Friend supabaseFriendToFriend(SupabaseFriend s) {
  return tt.Friend(
    id: s.friendId,
    name: s.name,
    major: s.department ?? '',
    status: tt.FriendStatus.offline,
    currentActivity: null,
    nextSlot: null,
    avatarSeed: s.friendId.hashCode.abs() % 1000,
  );
}

/// UI 호환 — timetable_screen에서 mockFriends 자리에 바로 꽂아 쓸 list.
final myFriendsAsLegacyProvider = Provider.autoDispose<List<tt.Friend>>((ref) {
  if (ref.watch(demoModeProvider)) return demoFriends();
  final async = ref.watch(myFriendsProvider);
  return [for (final f in async.value ?? const []) supabaseFriendToFriend(f)];
});
