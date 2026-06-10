import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';
import 'package:sejong_smart_campus/features/friends/domain/entities/friend_models.dart';

/// Supabase 친구 RPC 호출 wrapper.
///
/// 모든 RPC는 SECURITY DEFINER + 내부 `auth.uid()` 검증이라 클라가 다른 사용자
/// 정보를 함부로 조작 불가. 학번 검색은 HMAC blind index 매칭으로 평문 학번이
/// 서버 어디에도 저장되지 않음.
class SupabaseFriendsRemote {
  SupabaseFriendsRemote(this._client);
  final SupabaseClient _client;

  /// 학번으로 1명 검색. 이름은 "이*민" 형태로 마스킹되어 옴.
  Future<FriendSearchHit?> findByStudentId(String studentId) async {
    final res = await _client.rpc<dynamic>(
      SupabaseConfig.rpcFindUserByStudentId,
      params: {'p_student_id': studentId},
    );
    if (res is! List || res.isEmpty) return null;
    final row = res.first as Map<String, dynamic>;
    return FriendSearchHit(
      userId: row['user_id'] as String,
      maskedName: (row['masked_name'] as String?) ?? '',
    );
  }

  /// 이름(정확한 전체 일치)으로 검색. PII가 암호화 저장돼 부분/초성 검색은
  /// 불가 — 서버의 블라인드 인덱스 정확 매칭만. 동명이인은 여러 명
  /// 올 수 있고 이름은 마스킹("이*민"), 학과는 구분용 평문으로 온다.
  Future<List<FriendSearchHit>> findByName(String name) async {
    final res = await _client.rpc<dynamic>(
      SupabaseConfig.rpcFindUserByName,
      params: {'p_name': name},
    );
    if (res is! List) return const [];
    return [
      for (final raw in res)
        if (raw is Map<String, dynamic>)
          FriendSearchHit(
            userId: raw['user_id'] as String,
            maskedName: (raw['masked_name'] as String?) ?? '',
            department: raw['department'] as String?,
          ),
    ];
  }

  Future<String> sendFriendRequest(String addresseeId) async {
    final res = await _client.rpc<dynamic>(
      SupabaseConfig.rpcSendFriendRequest,
      params: {'p_addressee_id': addresseeId},
    );
    return res as String;
  }

  Future<void> respondFriendRequest({
    required String friendshipId,
    required bool accept,
  }) async {
    await _client.rpc<dynamic>(
      SupabaseConfig.rpcRespondFriendRequest,
      params: {'p_friendship_id': friendshipId, 'p_accept': accept},
    );
  }

  Future<List<SupabaseFriend>> listMyFriends() async {
    final res = await _client.rpc<dynamic>(SupabaseConfig.rpcListMyFriends);
    if (res is! List) return const [];
    return [
      for (final raw in res)
        if (raw is Map<String, dynamic>)
          SupabaseFriend(
            friendshipId: raw['friendship_id'] as String,
            friendId: raw['friend_id'] as String,
            name: (raw['friend_name'] as String?) ?? '',
            department: raw['friend_dept'] as String?,
            since: DateTime.parse(raw['since'] as String),
            studentId: raw['friend_student_id'] as String?,
          ),
    ];
  }

  Future<List<SupabaseFriendRequest>> listPendingRequests() async {
    final res = await _client.rpc<dynamic>(
      SupabaseConfig.rpcListPendingFriendRequests,
    );
    if (res is! List) return const [];
    return [
      for (final raw in res)
        if (raw is Map<String, dynamic>)
          SupabaseFriendRequest(
            friendshipId: raw['friendship_id'] as String,
            requesterId: raw['requester_id'] as String,
            requesterName: (raw['requester_name'] as String?) ?? '',
            requesterDepartment: raw['requester_dept'] as String?,
            requestedAt: DateTime.parse(raw['requested_at'] as String),
          ),
    ];
  }

  /// 24시간 만료 8자리 초대 코드 발급.
  Future<String> issueInviteCode() async {
    final res = await _client.rpc<dynamic>(
      SupabaseConfig.rpcIssueFriendInviteCode,
    );
    return res as String;
  }

  /// 친구가 공유한 코드로 양측 즉시 친구 등록.
  Future<String> redeemInviteCode(String code) async {
    final res = await _client.rpc<dynamic>(
      SupabaseConfig.rpcRedeemFriendInviteCode,
      params: {'p_code': code},
    );
    return res as String;
  }

  /// 본인이 학번·이름 검색에 노출되는지 조회. 프로필 행이 없으면 서버가
  /// 기본 true(노출)를 반환한다.
  Future<bool> getSearchVisible() async {
    final res = await _client.rpc<dynamic>(SupabaseConfig.rpcGetSearchVisible);
    return res as bool? ?? true;
  }

  /// 본인 검색 노출 on/off 설정. 서버가 적용된 새 값을 반환.
  Future<bool> setSearchVisible(bool on) async {
    final res = await _client.rpc<dynamic>(
      SupabaseConfig.rpcSetSearchVisible,
      params: {'p_on': on},
    );
    return res as bool? ?? on;
  }

  /// 친구가 업로드한 학기 목록(semester enum name 문자열). 친구 관계가 아니면
  /// 서버가 `not_friends`로 거절한다. setof text라 [{"...": "spring2026"}, ...]
  /// 또는 ["spring2026", ...] 형태로 올 수 있어 둘 다 흡수.
  Future<List<String>> getFriendTimetableSemesters(String friendId) async {
    final res = await _client.rpc<dynamic>(
      SupabaseConfig.rpcGetFriendTimetableSemesters,
      params: {'p_friend_id': friendId},
    );
    if (res is! List) return const [];
    return [
      for (final r in res)
        if (r is Map && r.isNotEmpty)
          r.values.first.toString()
        else if (r != null)
          r.toString(),
    ];
  }

  /// 친구의 특정 학기 시간표(서버에서 복호화된 slots jsonb). 데이터 없으면 null,
  /// 친구 관계가 아니면 서버가 예외를 던진다.
  Future<Map<String, dynamic>?> getFriendTimetable(
    String friendId,
    String semesterName,
  ) async {
    final res = await _client.rpc<dynamic>(
      SupabaseConfig.rpcGetFriendTimetable,
      params: {'p_friend_id': friendId, 'p_semester': semesterName},
    );
    if (res is Map) return res.cast<String, dynamic>();
    return null;
  }
}
