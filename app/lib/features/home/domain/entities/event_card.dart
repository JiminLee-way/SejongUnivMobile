/// Hero 캐러셀의 이벤트 카드 한 장. Supabase `home_events` 행과 1:1.
///
/// 정적 데이터가 아니라 서버측에서 유동적으로 관리 — 관리자가 행만 추가/수정하면
/// 앱이 자동 반영한다. 부트스트랩(로그인 진입 전) 때 prefetch.
class EventCard {
  const EventCard({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.action = EventCardAction.viewer,
    this.bodyHtml,
    this.source,
    this.linkUrl,
    this.categoryLabel,
    this.publishedAt,
    this.showText = true,
  });

  final String id;
  final String title;
  final String? subtitle;

  /// 카드 이미지 위 제목/부제 오버레이 노출 여부. 이미지에 글자가 이미 박혀 있으면
  /// 관리자가 끈다(DB `show_text`). 인디케이터/일시정지 버튼은 영향 없음.
  final bool showText;

  /// 16:9 이미지 URL — Supabase Storage(우리 배너) 또는 외부 CDN(YouTube 썸네일 등).
  final String imageUrl;

  /// 탭 동작 — 내부 뷰어 / 외부 링크.
  final EventCardAction action;

  /// [action]이 viewer일 때 공지 뷰어(NoticeHtmlView)로 렌더할 본문 HTML.
  final String? bodyHtml;

  /// 출처/작성자 — 뷰어 헤더의 writerName.
  final String? source;

  /// [action]이 link일 때 url_launcher로 열 외부 URL.
  final String? linkUrl;

  /// 뷰어 상단 카테고리 라벨(앱바 제목 + 배지).
  final String? categoryLabel;

  final DateTime? publishedAt;

  factory EventCard.fromJson(Map<String, dynamic> json) {
    return EventCard(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: json['subtitle'] as String?,
      imageUrl: (json['image_url'] ?? '').toString(),
      action: EventCardAction.fromCode(json['action_type'] as String?),
      bodyHtml: json['body_html'] as String?,
      source: json['source'] as String?,
      linkUrl: json['link_url'] as String?,
      categoryLabel: json['category_label'] as String?,
      publishedAt: DateTime.tryParse((json['published_at'] ?? '').toString()),
      showText: (json['show_text'] as bool?) ?? true,
    );
  }

  /// 로컬 캐시 직렬화 — DB 컬럼명과 동일 키라 [fromJson]으로 그대로 복원된다.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'image_url': imageUrl,
    'action_type': action.name,
    'body_html': bodyHtml,
    'source': source,
    'link_url': linkUrl,
    'category_label': categoryLabel,
    'published_at': publishedAt?.toIso8601String(),
    'show_text': showText,
  };
}

/// 카드 탭 동작. DB `action_type` 컬럼('viewer'|'link')과 매핑.
enum EventCardAction {
  viewer,
  link;

  static EventCardAction fromCode(String? code) =>
      code == 'link' ? EventCardAction.link : EventCardAction.viewer;
}
