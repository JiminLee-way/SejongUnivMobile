import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/notifications/data/datasources/notifications_local.dart';
import 'package:sejong_smart_campus/features/notifications/data/datasources/sejong_notifications_remote.dart';
import 'package:sejong_smart_campus/features/notifications/domain/entities/notification_models.dart';

final _notificationsRemoteProvider = FutureProvider<SejongNotificationsRemote>((
  ref,
) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongNotificationsRemote(client: client);
});

typedef InboxPage = ({List<SejongNotificationItem> items, int totalElements});

final inboxProvider = FutureProvider.autoDispose<InboxPage>((ref) async {
  final remote = await ref.watch(_notificationsRemoteProvider.future);
  return remote.fetchInbox(page: 0, size: 30);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  // 로그인 여부 변경 시 재계산. 다른 화면에서 invalidate해서 즉시 갱신.
  ref.watch(currentUserProvider);
  final remote = await ref.watch(_notificationsRemoteProvider.future);
  return remote.fetchUnreadCount();
});

// ─── 친구 알림 통합 + 로컬 읽음 오버레이 ────────────────────────────────────

final notificationsLocalProvider = Provider<NotificationsLocal>(
  (ref) => NotificationsLocal(),
);

/// 읽은 알림 id 오버레이 — sjapp 읽음 API가 동작하지 않아(읽어도 isRead=false)
/// 읽음 상태를 로컬에 저장해 표시 단계에서 덮어쓴다. sjapp·친구 알림 공통.
class ReadNotificationIds extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async =>
      ref.read(notificationsLocalProvider).readIds();

  Future<void> add(Iterable<String> ids) async {
    final next = {...(state.value ?? const <String>{}), ...ids};
    state = AsyncData(next);
    await ref.read(notificationsLocalProvider).addReadIds(ids);
  }
}

final readNotificationIdsProvider =
    AsyncNotifierProvider<ReadNotificationIds, Set<String>>(
      ReadNotificationIds.new,
    );

/// 받은 친구요청 → 알림 아이템. 마스킹 이름 + 학과(있으면).
final friendInboxItemsProvider =
    FutureProvider.autoDispose<List<SejongNotificationItem>>((ref) async {
      final reqs = await ref.watch(pendingFriendRequestsProvider.future);
      return [
        for (final r in reqs)
          SejongNotificationItem(
            id: 'friend_req:${r.friendshipId}',
            title: '${r.requesterName}님이 친구 요청을 보냈어요',
            body: r.requesterDepartment,
            category: '친구',
            sentAt: r.requestedAt,
            kind: NotificationKind.friendRequest,
            routeId: r.friendshipId,
          ),
      ];
    });

/// sjapp 알림 + 친구 알림 병합(시간순) + 로컬 읽음 오버레이 적용.
/// 한쪽이 실패해도 다른 쪽은 보이도록 개별 try.
final combinedInboxProvider =
    FutureProvider.autoDispose<List<SejongNotificationItem>>((ref) async {
      final readIds =
          ref.watch(readNotificationIdsProvider).value ?? const <String>{};
      var sjapp = const <SejongNotificationItem>[];
      try {
        sjapp = (await ref.watch(inboxProvider.future)).items;
      } catch (_) {}
      var friends = const <SejongNotificationItem>[];
      try {
        friends = await ref.watch(friendInboxItemsProvider.future);
      } catch (_) {}
      return <SejongNotificationItem>[...sjapp, ...friends]
          .map((it) => readIds.contains(it.id) ? it.copyWith(isRead: true) : it)
          .toList()
        ..sort(
          (a, b) =>
              (b.sentAt ?? DateTime(0)).compareTo(a.sentAt ?? DateTime(0)),
        );
    });

/// 병합 목록 기준 미읽음 수 — 종 배지 표시에 사용(sjapp + 친구요청 모두 반영).
final combinedUnreadCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(combinedInboxProvider).value ?? const [];
  return items.where((i) => !i.isRead).length;
});

/// 알림 설정 전체 — 19 카테고리 toggle UI에서 watch.
final notificationSettingsProvider = FutureProvider<NotificationSettings>((
  ref,
) async {
  ref.watch(currentUserProvider);
  final remote = await ref.watch(_notificationsRemoteProvider.future);
  return remote.fetchNotificationSettings();
});

Future<void> toggleNotificationCategory(
  WidgetRef ref,
  String categoryId,
  bool enabled,
) async {
  final remote = await ref.read(_notificationsRemoteProvider.future);
  await remote.updateCategoryEnabled(categoryId, enabled);
  ref.invalidate(notificationSettingsProvider);
}

Future<void> toggleMasterNotifications(WidgetRef ref, bool enabled) async {
  final remote = await ref.read(_notificationsRemoteProvider.future);
  await remote.updateMasterEnabled(enabled);
  ref.invalidate(notificationSettingsProvider);
}

/// 단건 읽음 처리 — 로컬 오버레이에 추가(즉시 반영). sjapp 알림은 서버 읽음도
/// best-effort로 시도(친구 알림은 로컬만).
Future<void> markNotificationRead(WidgetRef ref, String id) async {
  await ref.read(readNotificationIdsProvider.notifier).add([id]);
  if (!id.startsWith('friend_req:')) {
    final remote = await ref.read(_notificationsRemoteProvider.future);
    unawaited(remote.markRead(id));
  }
}

/// 전체 읽음 — 병합 목록 모든 id를 로컬 오버레이에 추가(즉시 반영) + sjapp 알림은
/// 서버에도 개별 PATCH(친구 알림 제외).
Future<void> markAllNotificationsRead(WidgetRef ref) async {
  final items = ref.read(combinedInboxProvider).value ?? const [];
  await ref
      .read(readNotificationIdsProvider.notifier)
      .add(items.map((e) => e.id));
  final sjappIds = items
      .where((e) => e.kind != NotificationKind.friendRequest && !e.isRead)
      .map((e) => e.id)
      .toList();
  if (sjappIds.isNotEmpty) {
    final remote = await ref.read(_notificationsRemoteProvider.future);
    unawaited(remote.markAllRead(sjappIds));
  }
}
