/// 홈 위젯 도메인 — 날씨 / 배너 / 피드.
library;

class Weather {
  const Weather({
    required this.temperature,
    required this.weatherCondition,
    required this.regionName,
  });
  final String temperature;
  final String weatherCondition;
  final String regionName;

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      temperature: (json['temperature'] ?? '—').toString(),
      weatherCondition: (json['weatherCondition'] ?? '').toString(),
      regionName: (json['regionName'] ?? '').toString(),
    );
  }
}

class HomeBanner {
  const HomeBanner({
    required this.bannerId,
    required this.imageUrl,
    required this.altText,
    required this.titleHtml,
    required this.linkUrl,
  });
  final String bannerId;
  final String imageUrl;
  final String altText;
  final String titleHtml;
  final String linkUrl;

  /// HTML 태그 제거한 평문 (`<br>` → 줄바꿈, `<span>` 등 제거).
  String get plainTitle => titleHtml
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return HomeBanner(
      bannerId: (json['bannerId'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      altText: (json['altText'] ?? '').toString(),
      titleHtml: (json['titleName'] ?? '').toString(),
      linkUrl: (json['linkUrl'] ?? '').toString(),
    );
  }
}

enum FeedSource { blog, youtube, unknown }

class FeedItem {
  const FeedItem({
    required this.id,
    required this.source,
    required this.sourceName,
    required this.title,
    required this.link,
    this.thumbnailUrl,
    this.publishedAt,
  });
  final int id;
  final FeedSource source;
  final String sourceName;
  final String title;
  final String link;
  final String? thumbnailUrl;
  final DateTime? publishedAt;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final src = (json['source'] ?? '').toString().toUpperCase();
    return FeedItem(
      id: ((json['id'] as num?) ?? 0).toInt(),
      source: src == 'BLOG'
          ? FeedSource.blog
          : src == 'YOUTUBE'
          ? FeedSource.youtube
          : FeedSource.unknown,
      sourceName: (json['sourceName'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      link: (json['link'] ?? '').toString(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      publishedAt: DateTime.tryParse((json['publishedAt'] ?? '').toString()),
    );
  }
}
