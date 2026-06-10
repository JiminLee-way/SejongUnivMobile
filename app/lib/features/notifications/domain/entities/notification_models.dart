/// 알림함 (UMS — User Message System) 도메인.
///
/// best-effort 필드 매핑 — 실 응답이 다른 키를 쓰면
/// [SejongNotificationItem.fromJson] 안의 후보 키들을 늘리면 된다.
library;

/// 알림 출처 — sjapp UMS 알림과 우리 앱(친구요청 등) 알림을 한 리스트에서 구분.
enum NotificationKind { sejong, friendRequest }

class SejongNotificationItem {
  const SejongNotificationItem({
    required this.id,
    required this.title,
    this.body,
    this.category,
    this.link,
    this.sentAt,
    this.isRead = false,
    this.kind = NotificationKind.sejong,
    this.routeId,
  });

  final String id;
  final String title;
  final String? body;
  final String? category;
  final String? link;
  final DateTime? sentAt;
  final bool isRead;

  /// 출처 구분 — 탭 동작 분기에 사용(친구요청이면 친구 화면으로 이동).
  final NotificationKind kind;

  /// kind가 friendRequest일 때 원본 friendship id 등 — 향후 인라인 액션용.
  final String? routeId;

  SejongNotificationItem copyWith({bool? isRead}) => SejongNotificationItem(
    id: id,
    title: title,
    body: body,
    category: category,
    link: link,
    sentAt: sentAt,
    isRead: isRead ?? this.isRead,
    kind: kind,
    routeId: routeId,
  );

  factory SejongNotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    String first(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    return SejongNotificationItem(
      id: first(['id', 'messageId', 'inboxId']),
      title: first(['title', 'subject', 'name']),
      body: first(['body', 'content', 'message', 'description']).isEmpty
          ? null
          : first(['body', 'content', 'message', 'description']),
      category: first(['category', 'categoryName', 'type']).isEmpty
          ? null
          : first(['category', 'categoryName', 'type']),
      link: first(['link', 'url', 'targetUrl']).isEmpty
          ? null
          : first(['link', 'url', 'targetUrl']),
      sentAt: parseDate(
        json['sentAt'] ??
            json['createdAt'] ??
            json['receivedAt'] ??
            json['writtenAt'],
      ),
      isRead:
          json['isRead'] == true ||
          json['read'] == true ||
          json['status']?.toString() == 'READ',
    );
  }
}
