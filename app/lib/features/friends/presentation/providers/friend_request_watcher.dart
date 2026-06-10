import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/friends/data/datasources/friend_notifications.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/providers/notifications_providers.dart';

/// 받은 친구요청을 확인해, 직전에 헤드업을 띄우지 않은 '새' 요청이 있으면
/// OS 로컬 알림(헤드업)을 띄운다. 동시에 알림함/배지가 갱신되도록 invalidate.
///
/// 호출 시점(Realtime/FCM 없이 "앱이 떠 있는 동안" 준실시간):
///  - 앱 콜드부트(AppShell init)
///  - 백그라운드 복귀(AppShell resumed)
///  - 포그라운드 30초 폴링(AppShell Timer)
///
/// **WidgetRef가 아니라 [ProviderContainer]를 받는다** — 콜드부트의 850ms 지연
/// 콜백이 실행될 때 AppShell이 이미 비활성(로그아웃/화면전환)이면 WidgetRef.read는
/// element 조상 lookup으로 "deactivated widget's ancestor" 를 던진다. container.read는
/// element와 무관해 안전(루트 컨테이너는 앱 수명 내내 유효).
Future<void> checkFriendRequestsAndNotify(ProviderContainer container) async {
  final client = container.read(supabaseClientProvider);
  if (client.auth.currentSession == null) return;
  try {
    // invalidate 후 future를 읽어 한 번만 fetch — UI watcher와 결과 공유.
    container.invalidate(pendingFriendRequestsProvider);
    final reqs = await container.read(pendingFriendRequestsProvider.future);

    final local = container.read(notificationsLocalProvider);
    final seen = await local.seenFriendRequestIds();
    final fresh = reqs.where((r) => !seen.contains(r.friendshipId)).toList();
    if (fresh.isNotEmpty) {
      await FriendNotifications.instance.showFriendRequest(
        count: fresh.length,
        fromName: fresh.length == 1 ? fresh.first.requesterName : null,
      );
    }
    // 현재 받은신청 집합으로 갱신 — 처리되어 사라진 건 자동 제외.
    await local.setSeenFriendRequestIds(reqs.map((r) => r.friendshipId));
  } catch (_) {
    // 네트워크/세션 일시 오류 — 다음 폴링/복귀 때 재시도.
  }
}
