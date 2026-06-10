import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/community/data/repositories/community_repository_impl.dart';
import 'package:sejong_smart_campus/features/community/domain/entities/community_models.dart';
import 'package:sejong_smart_campus/features/community/domain/repositories/community_repository.dart';

/// 다른 feature·테스트에서 override 할 수 있도록 Provider로 노출.
final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => const CommunityRepositoryImpl(),
);

/// 공지 카테고리 필터 — null 이면 전체.
final noticeFilterProvider = NotifierProvider<NoticeFilter, NoticeCategory?>(
  NoticeFilter.new,
);

class NoticeFilter extends Notifier<NoticeCategory?> {
  @override
  NoticeCategory? build() => null;

  void select(NoticeCategory? category) => state = category;
}

/// 필터가 바뀌면 자동으로 다시 fetch. `AsyncValue<List<NoticeItem>>` 를 노출.
final noticesProvider = FutureProvider.autoDispose<List<NoticeItem>>((ref) {
  final repo = ref.watch(communityRepositoryProvider);
  final category = ref.watch(noticeFilterProvider);
  return repo.fetchNotices(category: category);
});

final newsProvider = FutureProvider.autoDispose<List<NewsItem>>((ref) {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.fetchNews();
});

/// 게시판 필터 — null 이면 전체.
final boardFilterProvider = NotifierProvider<BoardFilter, Board?>(
  BoardFilter.new,
);

class BoardFilter extends Notifier<Board?> {
  @override
  Board? build() => null;

  void select(Board? board) => state = board;
}

final boardPostsProvider = FutureProvider.autoDispose<List<BoardPost>>((ref) {
  final repo = ref.watch(communityRepositoryProvider);
  final board = ref.watch(boardFilterProvider);
  return repo.fetchBoardPosts(board: board);
});
