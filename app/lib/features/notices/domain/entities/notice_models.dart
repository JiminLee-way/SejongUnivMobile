/// 대학 공지·세종소식 도메인.
///
/// **List**:
/// - `/api/publicapi/university-notice/latest?type={notice-type}&size={n}` — 대학공지 6 type
/// - `/api/publicapi/sejong-news/{news-type}?page=&size=` — 세종뉴스 계열 5 type
///
/// **Detail** (모두 같은 응답 schema, 경로만 다름):
/// - `/api/publicapi/university-notice/{notice-type}/{id}`
/// - `/api/publicapi/sejong-news/{news-type}/{id}`
library;

class SejongNoticeItem {
  const SejongNoticeItem({
    required this.id,
    required this.title,
    this.summary,
    required this.categoryCode,
    required this.categoryName,
    required this.categoryType,
    required this.writerName,
    required this.writtenAt,
    required this.viewCount,
    required this.isNew,
    required this.hasAttachment,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? summary;
  final String categoryCode;
  final String categoryName;
  final String categoryType;
  final String writerName;
  final DateTime? writtenAt;
  final int viewCount;
  final bool isNew;
  final bool hasAttachment;
  final String? imageUrl;

  factory SejongNoticeItem.fromJson(Map<String, dynamic> json) {
    return SejongNoticeItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      summary: json['summary'] as String?,
      categoryCode: (json['categoryCode'] ?? '').toString(),
      categoryName: (json['categoryName'] ?? '').toString(),
      categoryType: (json['categoryType'] ?? '').toString(),
      writerName: (json['writerName'] ?? '').toString(),
      writtenAt: DateTime.tryParse((json['writtenAt'] ?? '').toString()),
      viewCount: ((json['viewCount'] as num?) ?? 0).toInt(),
      isNew: json['isNew'] == true,
      hasAttachment: json['hasAttachment'] == true,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

/// 단일 게시물 상세. list item보다 [content]·[attachments] 가 추가.
class SejongNoticeDetail {
  const SejongNoticeDetail({
    required this.id,
    required this.title,
    required this.categoryCode,
    required this.categoryName,
    required this.categoryType,
    required this.content,
    this.imageUrl,
    this.writerName,
    this.writtenAt,
    required this.viewCount,
    required this.attachments,
  });

  final String id;
  final String title;
  final String categoryCode;
  final String categoryName;
  final String categoryType;

  /// Froala가 출력한 HTML. `<div class="fr-view">` 래핑 안에
  /// `<p>`·`<span style=...>`·`<img src=...>`·`<br>`·`<ul>`/`<li>` 중심.
  /// 이미지 src가 상대 경로면 설정된 웹 base URL로 보정.
  final String content;

  /// 리스트에서 보이는 cover image. 본문 안 이미지와 별도일 수 있음.
  final String? imageUrl;
  final String? writerName;
  final DateTime? writtenAt;
  final int viewCount;
  final List<NoticeAttachment> attachments;

  factory SejongNoticeDetail.fromJson(Map<String, dynamic> json) {
    return SejongNoticeDetail(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      categoryCode: (json['categoryCode'] ?? '').toString(),
      categoryName: (json['categoryName'] ?? '').toString(),
      categoryType: (json['categoryType'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      imageUrl: json['imageUrl'] as String?,
      writerName: json['writerName'] as String?,
      writtenAt: DateTime.tryParse((json['writtenAt'] ?? '').toString()),
      viewCount: ((json['viewCount'] as num?) ?? 0).toInt(),
      attachments: ((json['attachments'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(NoticeAttachment.fromJson)
          .toList(),
    );
  }
}

class NoticeAttachment {
  const NoticeAttachment({
    this.fileId,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
  });

  final String? fileId;
  final String fileName;
  final String fileUrl;

  /// bytes. 응답이 null이면 0.
  final int fileSize;

  factory NoticeAttachment.fromJson(Map<String, dynamic> json) {
    return NoticeAttachment(
      fileId: json['fileId']?.toString(),
      fileName: (json['fileName'] ?? '').toString(),
      fileUrl: (json['fileUrl'] ?? '').toString(),
      fileSize: ((json['fileSize'] as num?) ?? 0).toInt(),
    );
  }

  /// "1.2MB", "230KB", "512B" 사람 친화 포맷.
  String get prettySize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(0)}KB';
    }
    return '${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  /// 확장자 (소문자, '.' 제외). 추출 실패 시 빈 문자열.
  String get extension {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot >= fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }
}

/// sjapp 공식 메뉴 트리에 나오는 8개 공지 카테고리.
///
/// list endpoint는 `/publicapi/university-notice/latest?type={type}` 한 곳으로 통일.
/// detail endpoint는 `/publicapi/university-notice/{type}/{id}`.
enum NoticeCategory {
  general('general', '일반', '/inf/notice/general'),
  academic('academic', '학사', '/inf/notice/academic'),
  scholarship('scholarship', '장학', '/inf/notice/scholarship'),
  employment('employment', '취업·창업', '/inf/notice/employment'),
  engineering('engineering', '공학', '/inf/notice/engineering'),
  library('library', '도서관', '/inf/notice/library'),
  international('international', '국제교류', '/inf/notice/international'),
  recruitment('recruitment', '교내모집', '/inf/notice/recruitment');

  const NoticeCategory(this.type, this.label, this.webPath);
  final String type;
  final String label;
  final String? webPath;

  /// `/publicapi/university-notice/{type}/{id}` 상세 경로.
  String detailPath(String id) => '/api/publicapi/university-notice/$type/$id';

  static NoticeCategory? fromType(String type) {
    for (final c in values) {
      if (c.type == type) return c;
    }
    return null;
  }
}

/// `/api/publicapi/sejong-news/{slug}` 계열 5 type.
///
/// 대학공지와 구조가 같지만 endpoint base가 다름.
enum NewsCategory {
  news('news', '세종뉴스', 'news'),
  media('media', '언론속세종', 'media'),
  press('press', '보도자료', 'press'),
  sejongWebzine('sejong-webzine', '세종소식웹진', 'sejong-webzine'),
  engineeringWebzine('engineering-webzine', '세종공대웹진', 'engineering-webzine');

  const NewsCategory(this.type, this.label, this.slug);

  /// dispatcher에서 menu params로 들어오는 `categoryType` 값.
  final String type;
  final String label;

  /// URL path segment (`/sejong-news/{slug}`). type과 같지만 의미 분리.
  final String slug;

  String get listPath => '/api/publicapi/sejong-news/$slug';
  String detailPath(String id) => '/api/publicapi/sejong-news/$slug/$id';

  /// menu callParams.type 으로부터 enum 매핑. 매칭 실패 시 null.
  static NewsCategory? fromType(String type) {
    for (final c in values) {
      if (c.type == type) return c;
    }
    return null;
  }
}
