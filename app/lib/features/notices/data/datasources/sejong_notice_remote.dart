import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';

class SejongNoticeRemote {
  SejongNoticeRemote({required this.client});
  final SejongApiClient client;

  // ─────────────────────────── list ───────────────────────────

  /// `/publicapi/university-notice/latest?type={type}&size={n}`.
  ///
  /// **size 상한 10**: sjapp 백엔드는 size>10 요청에 대해 모든 type에서
  /// 500 INTERNAL_SERVER_ERROR를 반환한다(2026-05-23 라이브 확인). 호출자가
  /// 더 큰 값을 주더라도 안전하게 10으로 clamp한다.
  Future<List<SejongNoticeItem>> fetchLatest({
    required NoticeCategory category,
    int size = 10,
  }) async {
    final safeSize = size > 10 ? 10 : size;
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.universityNoticeLatest,
      queryParameters: {'type': category.type, 'size': safeSize},
    );
    return client.unwrap<List<SejongNoticeItem>>(res, (raw) {
      return (raw as List)
          .cast<Map<String, dynamic>>()
          .map(SejongNoticeItem.fromJson)
          .toList();
    });
  }

  /// `/publicapi/sejong-news/news?size={n}` — Spring Pageable. 기본 호환용.
  Future<List<SejongNoticeItem>> fetchNews({int size = 10}) =>
      fetchNewsList(category: NewsCategory.news, size: size);

  /// `/publicapi/sejong-news/{slug}?page=0&size={n}` — Pageable.
  /// content[] 또는 평면 list 모두 처리.
  Future<List<SejongNoticeItem>> fetchNewsList({
    required NewsCategory category,
    int page = 0,
    int size = 10,
  }) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.sejongNewsList(category.slug),
      queryParameters: {'page': page, 'size': size},
    );
    return client.unwrap<List<SejongNoticeItem>>(res, (raw) {
      final m = raw is Map<String, dynamic> ? raw : null;
      final content =
          (m?['content'] as List?) ?? (raw is List ? raw : const []);
      return content
          .cast<Map<String, dynamic>>()
          .map(SejongNoticeItem.fromJson)
          .toList();
    });
  }

  // ─────────────────────────── detail ───────────────────────────

  /// 대학공지 상세 — `/university-notice/{type}/{id}`.
  Future<SejongNoticeDetail> fetchNoticeDetail({
    required NoticeCategory category,
    required String id,
  }) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.universityNoticeDetail(category.type, id),
    );
    return client.unwrap<SejongNoticeDetail>(
      res,
      (raw) => SejongNoticeDetail.fromJson(raw as Map<String, dynamic>),
    );
  }

  /// 세종뉴스 계열 상세 — `/sejong-news/{slug}/{id}`.
  Future<SejongNoticeDetail> fetchNewsDetail({
    required NewsCategory category,
    required String id,
  }) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.sejongNewsDetail(category.slug, id),
    );
    return client.unwrap<SejongNoticeDetail>(
      res,
      (raw) => SejongNoticeDetail.fromJson(raw as Map<String, dynamic>),
    );
  }
}
