import 'dart:convert';

/// 세종 통합앱 메뉴 시스템 한 항목.
///
/// `/api/publicapi/menus/{menuId}/authorized/tree` 응답의 트리 노드 한 개.
/// `callType` × `callParams` 디스패처 규약은 라우팅 계층에서 해석한다.
class SejongMenuItem {
  const SejongMenuItem({
    required this.itemId,
    required this.menuId,
    required this.itemName,
    required this.itemType,
    required this.parentItemId,
    required this.itemLevel,
    required this.displayOrder,
    required this.url,
    required this.webUrl,
    required this.target,
    required this.iconClass,
    required this.callType,
    required this.callParams,
    required this.appScheme,
    required this.active,
    required this.visible,
    required this.allowedRoles,
    required this.itemKey,
    required this.children,
  });

  final String itemId;
  final String menuId;
  final String itemName;

  /// GROUP | PAGE | LINK
  final String itemType;
  final String? parentItemId;
  final int itemLevel;
  final int displayOrder;

  /// 내부 라우트 키 ("aca.classSchedule") 또는 절대 URL.
  final String url;
  final String webUrl;
  final String target;

  /// Lucide 아이콘 이름 (Clock, Armchair, Newspaper...). Material Symbols
  /// 매핑은 [iconResolverProvider]에서 처리.
  final String iconClass;

  /// NONE | WEBVIEW | EXTERNAL_BROWSER | INAPP_BROWSER | APPLINK
  final String callType;

  /// JSON-encoded string — `{queryParams: [...]}` / `{ssoRedirect: true}` 등.
  /// 디스패처가 파싱.
  final String? callParams;

  /// APPLINK용 JSON — `{packageName, appStoreId, fallbackUrl}`.
  final String? appScheme;

  final bool active;
  final bool visible;
  final List<String>? allowedRoles;
  final String? itemKey;
  final List<SejongMenuItem>? children;

  bool get isGroup => itemType == 'GROUP';
  bool get isLeaf => itemType == 'PAGE' || itemType == 'LINK';

  factory SejongMenuItem.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    return SejongMenuItem(
      itemId: (json['itemId'] ?? '').toString(),
      menuId: (json['menuId'] ?? '').toString(),
      itemName: (json['itemName'] ?? '').toString(),
      itemType: (json['itemType'] ?? '').toString(),
      parentItemId: json['parentItemId'] as String?,
      itemLevel: ((json['itemLevel'] as num?) ?? 0).toInt(),
      displayOrder: ((json['displayOrder'] as num?) ?? 0).toInt(),
      url: (json['url'] ?? '').toString(),
      webUrl: (json['webUrl'] ?? '').toString(),
      target: (json['target'] ?? '_self').toString(),
      iconClass: (json['iconClass'] ?? '').toString(),
      callType: (json['callType'] ?? 'NONE').toString(),
      callParams: _decodeIfHtmlEscaped(json['callParams']),
      appScheme: _decodeIfHtmlEscaped(json['appScheme']),
      active: json['active'] == true,
      visible: json['visible'] == true,
      allowedRoles: (json['allowedRoles'] as List?)?.cast<String>(),
      itemKey: json['itemKey'] as String?,
      children: rawChildren is List
          ? rawChildren
                .cast<Map<String, dynamic>>()
                .map(SejongMenuItem.fromJson)
                .toList()
          : null,
    );
  }

  /// sjapp이 일부 callParams를 HTML-escape 한 채로 내려보내는 경우가 있다
  /// (`&quot;` 등). 그대로 jsonDecode 하면 실패하므로 잠깐 unescape.
  static String? _decodeIfHtmlEscaped(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty) return null;
    return s
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&apos;', "'");
  }

  /// callParams를 JSON으로 안전하게 파싱. 실패 시 null.
  Map<String, dynamic>? parsedCallParams() {
    final raw = callParams;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? parsedAppScheme() {
    final raw = appScheme;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// 메뉴 순서 편집기에서 leaf 순서 교체 시 사용. 현재 필요한 필드만 노출.
  SejongMenuItem copyWith({String? itemName, List<SejongMenuItem>? children}) {
    return SejongMenuItem(
      itemId: itemId,
      menuId: menuId,
      itemName: itemName ?? this.itemName,
      itemType: itemType,
      parentItemId: parentItemId,
      itemLevel: itemLevel,
      displayOrder: displayOrder,
      url: url,
      webUrl: webUrl,
      target: target,
      iconClass: iconClass,
      callType: callType,
      callParams: callParams,
      appScheme: appScheme,
      active: active,
      visible: visible,
      allowedRoles: allowedRoles,
      itemKey: itemKey,
      children: children ?? this.children,
    );
  }
}
