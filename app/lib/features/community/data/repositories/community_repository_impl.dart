import 'package:sejong_smart_campus/features/community/data/datasources/mock_community.dart';
import 'package:sejong_smart_campus/features/community/domain/entities/community_models.dart';
import 'package:sejong_smart_campus/features/community/domain/repositories/community_repository.dart';

/// Mock 기반 구현. 실제 백엔드 연결 시 RemoteCommunityDataSource를 만들어
/// 이 클래스의 생성자 주입으로 교체한다.
class CommunityRepositoryImpl implements CommunityRepository {
  const CommunityRepositoryImpl();

  static const _latency = Duration(milliseconds: 120);

  @override
  Future<List<NoticeItem>> fetchNotices({NoticeCategory? category}) async {
    await Future<void>.delayed(_latency);
    if (category == null) return List.unmodifiable(mockNotices);
    return List.unmodifiable(mockNotices.where((n) => n.category == category));
  }

  @override
  Future<List<NewsItem>> fetchNews() async {
    await Future<void>.delayed(_latency);
    return List.unmodifiable(mockNews);
  }

  @override
  Future<List<BoardPost>> fetchBoardPosts({Board? board}) async {
    await Future<void>.delayed(_latency);
    if (board == null) return List.unmodifiable(mockBoardPosts);
    return List.unmodifiable(mockBoardPosts.where((p) => p.board == board));
  }
}
