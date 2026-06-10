import 'package:sejong_smart_campus/features/community/domain/entities/community_models.dart';

/// 커뮤니티 도메인 진입점. 구현(데이터 소스)이 무엇이든 — mock·REST·GraphQL·로컬 캐시 —
/// presentation 레이어는 오직 이 인터페이스에만 의존한다.
abstract class CommunityRepository {
  Future<List<NoticeItem>> fetchNotices({NoticeCategory? category});

  Future<List<NewsItem>> fetchNews();

  Future<List<BoardPost>> fetchBoardPosts({Board? board});
}
