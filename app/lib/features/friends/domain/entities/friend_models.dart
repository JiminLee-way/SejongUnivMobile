/// Supabase에 저장된 친구 관계의 도메인 표현.
///
/// PII(이름·학과)는 server-side에서 복호화 후 들어오며, 클라이언트는 plain text만
/// 본다. 서버 round-trip마다 RPC가 KEK→DEK→AES-GCM 복호화를 거치므로 cache는
/// short-lived (autoDispose provider).
class SupabaseFriend {
  const SupabaseFriend({
    required this.friendshipId,
    required this.friendId,
    required this.name,
    required this.department,
    required this.since,
    this.studentId,
  });

  /// `friendships.id` — accept/cancel 등 행위 키.
  final String friendshipId;

  /// `users.id` — 친구의 프로필 식별자(UUID). 학번이 아님.
  final String friendId;

  final String name;
  final String? department;
  final DateTime since;

  /// 친구의 학번(평문). **확정 친구 한정**으로 서버가 복호화해 내려준다
  /// — 시설 예약 동반이용자 자동입력용. (사용자 정책: 확정 친구에게 학번 공개.)
  final String? studentId;
}

/// 받은 친구 신청.
class SupabaseFriendRequest {
  const SupabaseFriendRequest({
    required this.friendshipId,
    required this.requesterId,
    required this.requesterName,
    required this.requesterDepartment,
    required this.requestedAt,
  });

  final String friendshipId;
  final String requesterId;
  final String requesterName;
  final String? requesterDepartment;
  final DateTime requestedAt;
}

/// 학번·이름 검색 결과 — 본인 동의(신청 수락) 전엔 이름이 마스킹된 형태("이*민").
///
/// 이름 검색은 동명이인이 여러 명 나올 수 있어 [department]로 구분한다(학번
/// 검색은 1명 확정이라 보통 null).
class FriendSearchHit {
  const FriendSearchHit({
    required this.userId,
    required this.maskedName,
    this.department,
  });

  final String userId;
  final String maskedName;

  /// 동명이인 구분용 학과(평문). 학번 검색에선 null.
  final String? department;
}
