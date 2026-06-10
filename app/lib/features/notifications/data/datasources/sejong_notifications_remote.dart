import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/notifications/domain/entities/notification_models.dart';

class SejongNotificationsRemote {
  SejongNotificationsRemote({required this.client});
  final SejongApiClient client;

  /// `/api/v1/ums/inbox?page=0&size=N` — Spring Pageable 응답 추정.
  Future<({List<SejongNotificationItem> items, int totalElements})> fetchInbox({
    int page = 0,
    int size = 20,
  }) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.umsInbox,
      queryParameters: {'category': 'all', 'page': page, 'size': size},
    );
    return client.unwrap(res, (raw) {
      // 가능한 모양:
      //  1) Spring Pageable: { content: [...], totalElements: N, ... }
      //  2) 단순 배열: [...]
      List<dynamic> entries;
      int total = 0;
      if (raw is Map<String, dynamic>) {
        entries = (raw['content'] as List?) ?? const [];
        total = ((raw['totalElements'] as num?) ?? entries.length).toInt();
      } else if (raw is List) {
        entries = raw;
        total = raw.length;
      } else {
        entries = const [];
      }
      return (
        items: entries
            .cast<Map<String, dynamic>>()
            .map(SejongNotificationItem.fromJson)
            .toList(),
        totalElements: total,
      );
    });
  }

  /// `/api/v1/ums/inbox/unread-count`.
  /// 실 응답: `{unreadCount: N, unreadByCategory: {...}}`.
  Future<int> fetchUnreadCount() async {
    try {
      final res = await client.dio.get<dynamic>(
        '${SejongEndpoints.umsInbox}/unread-count',
      );
      return client.unwrap<int>(res, (raw) {
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
        if (raw is Map<String, dynamic>) {
          final v = raw['unreadCount'] ?? raw['count'] ?? raw['value'];
          if (v is num) return v.toInt();
        }
        if (raw is String) return int.tryParse(raw) ?? 0;
        return 0;
      });
    } catch (_) {
      return 0;
    }
  }

  /// `GET /api/v1/ums/notification-settings`.
  /// 응답: `{masterEnabled, settings: [{categoryId, categoryName,
  ///   categoryCode, isEnabled, masterEnabled, iconType, iconColor,
  ///   mandatoryFlag}]}` (19 카테고리).
  Future<NotificationSettings> fetchNotificationSettings() async {
    final res = await client.dio.get<dynamic>(
      '/api/v1/ums/notification-settings',
    );
    return client.unwrap<NotificationSettings>(res, (raw) {
      final m = (raw as Map).cast<String, dynamic>();
      return NotificationSettings(
        masterEnabled: m['masterEnabled'] == true,
        settings: ((m['settings'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(NotificationCategorySetting.fromJson)
            .toList(),
      );
    });
  }

  /// 카테고리 단건 토글 — `PUT /api/v1/ums/notification-settings`.
  /// body는 `{categoryId, isEnabled}` 추정. 실패 silent.
  Future<void> updateCategoryEnabled(String categoryId, bool enabled) async {
    try {
      await client.dio.put<dynamic>(
        '/api/v1/ums/notification-settings',
        data: {'categoryId': categoryId, 'isEnabled': enabled},
      );
    } catch (_) {}
  }

  /// 마스터 스위치 — `PUT /api/v1/ums/notification-settings/master`.
  Future<void> updateMasterEnabled(bool enabled) async {
    try {
      await client.dio.put<dynamic>(
        '/api/v1/ums/notification-settings/master',
        data: {'masterEnabled': enabled},
      );
    } catch (_) {}
  }

  /// 단건 읽음 처리. 실패해도 silent(로컬 오버레이가 즉시 반영).
  Future<void> markRead(String id) async {
    try {
      await client.dio.patch<dynamic>('${SejongEndpoints.umsInbox}/$id/read');
    } catch (_) {}
  }

  /// 전체 읽음 — 주어진 id들을 순회하며 PATCH한다. 실패한 건은 건너뛴다.
  Future<void> markAllRead(Iterable<String> ids) async {
    for (final id in ids) {
      try {
        await client.dio.patch<dynamic>('${SejongEndpoints.umsInbox}/$id/read');
      } catch (_) {}
    }
  }
}

/// 알림 설정 전체 묶음.
class NotificationSettings {
  const NotificationSettings({
    required this.masterEnabled,
    required this.settings,
  });
  final bool masterEnabled;
  final List<NotificationCategorySetting> settings;
}

class NotificationCategorySetting {
  const NotificationCategorySetting({
    required this.categoryId,
    required this.categoryName,
    required this.categoryCode,
    required this.isEnabled,
    required this.masterEnabled,
    required this.mandatoryFlag,
    this.iconColor,
  });
  final String categoryId;
  final String categoryName;
  final String categoryCode;
  final bool isEnabled;
  final bool masterEnabled;
  final bool mandatoryFlag;
  final String? iconColor;

  factory NotificationCategorySetting.fromJson(Map<String, dynamic> json) {
    return NotificationCategorySetting(
      categoryId: (json['categoryId'] ?? '').toString(),
      categoryName: (json['categoryName'] ?? '').toString(),
      categoryCode: (json['categoryCode'] ?? '').toString(),
      isEnabled: json['isEnabled'] == true,
      masterEnabled: json['masterEnabled'] == true,
      mandatoryFlag: json['mandatoryFlag'] == true,
      iconColor: json['iconColor'] as String?,
    );
  }
}
