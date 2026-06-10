import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 알림함 로컬 상태 보관.
///
/// **읽음 오버레이**: sjapp UMS의 읽음 API(`/inbox/{id}/read`)가 추정 엔드포인트라
/// 실제로 동작하지 않아(읽어도 isRead=false로 재조회됨), 읽은 알림 id를 로컬에
/// 저장해 표시 단계에서 읽음으로 덮어쓴다. sjapp·친구 알림 모두 동일 적용.
/// 무한 증가 방지로 최근 [_readCap]개만 유지.
///
/// **친구요청 헤드업 중복 방지**: 이미 알림을 띄운 friendship id를 저장해, 폴링/
/// 복귀마다 같은 요청으로 다시 띄우지 않는다.
class NotificationsLocal {
  NotificationsLocal()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _storage;

  static const _kReadIds = 'notif.read_ids';
  static const _kSeenFriendReqIds = 'notif.seen_friend_req_ids';
  static const _readCap = 500;

  Future<List<String>> _readList(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  Future<void> _writeList(String key, List<String> ids) =>
      _storage.write(key: key, value: jsonEncode(ids));

  /// 읽음 처리된 알림 id 집합.
  Future<Set<String>> readIds() async => (await _readList(_kReadIds)).toSet();

  /// id들을 읽음 집합에 추가(최근 [_readCap]개 유지).
  Future<void> addReadIds(Iterable<String> ids) async {
    final cur = await _readList(_kReadIds);
    // 새 id를 뒤에 붙이고(최신), 중복 제거 후 cap 초과분은 앞(오래된 것)부터 버림.
    final merged = <String>[...cur, ...ids];
    final seen = <String>{};
    final deduped = <String>[];
    for (final id in merged) {
      if (seen.add(id)) deduped.add(id);
    }
    final capped = deduped.length > _readCap
        ? deduped.sublist(deduped.length - _readCap)
        : deduped;
    await _writeList(_kReadIds, capped);
  }

  /// 헤드업을 이미 띄운 친구요청(friendship) id 집합.
  Future<Set<String>> seenFriendRequestIds() async =>
      (await _readList(_kSeenFriendReqIds)).toSet();

  /// 현재 받은신청 id 집합으로 교체(처리되어 사라진 건 자연히 빠진다).
  Future<void> setSeenFriendRequestIds(Iterable<String> ids) =>
      _writeList(_kSeenFriendReqIds, ids.toList());
}
