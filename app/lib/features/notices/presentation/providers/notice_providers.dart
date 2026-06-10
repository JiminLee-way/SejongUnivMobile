import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/notices/data/datasources/sejong_notice_remote.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';

final _noticeRemoteProvider = FutureProvider<SejongNoticeRemote>((ref) async {
  final client = await ref.watch(sejongApiClientProvider.future);
  return SejongNoticeRemote(client: client);
});

// ─────────────────────────── list ───────────────────────────

/// 카테고리별 최신 공지 — 카테고리 탭 변경 시 자동 fetch.
/// size는 10이 sjapp 백엔드 상한. 더 보고 싶다면 sjapp 웹뷰로 위임.
final noticesByCategoryProvider = FutureProvider.autoDispose
    .family<List<SejongNoticeItem>, NoticeCategory>((ref, category) async {
      final remote = await ref.watch(_noticeRemoteProvider.future);
      return remote.fetchLatest(category: category, size: 10);
    });

/// 홈 위젯 미리보기 — 일반 공지 5개.
final homeNoticePreviewProvider = FutureProvider<List<SejongNoticeItem>>((
  ref,
) async {
  final remote = await ref.watch(_noticeRemoteProvider.future);
  return remote.fetchLatest(category: NoticeCategory.general, size: 5);
});

/// 세종소식 — 홈 위젯 미리보기 + NewsScreen 호환.
final sejongNewsProvider = FutureProvider<List<SejongNoticeItem>>((ref) async {
  final remote = await ref.watch(_noticeRemoteProvider.future);
  return remote.fetchNews(size: 10);
});

/// `/sejong-news/{slug}` 계열 5 type — NewsListScreen이 사용.
final newsListByCategoryProvider = FutureProvider.autoDispose
    .family<List<SejongNoticeItem>, NewsCategory>((ref, category) async {
      final remote = await ref.watch(_noticeRemoteProvider.future);
      return remote.fetchNewsList(category: category, size: 10);
    });

// ─────────────────────────── detail ───────────────────────────

/// detail provider의 family key — Notice와 News를 한 family로 묶기 위한 union.
///
/// Detail screen은 categoryType 한 글자 보고 router가 ProviderArg를 만든다.
/// equality 보장을 위해 [hashCode]/[==] override.
class NoticeDetailArg {
  const NoticeDetailArg._({
    required this.id,
    this.noticeCategory,
    this.newsCategory,
  }) : assert(
         (noticeCategory != null) != (newsCategory != null),
         'exactly one of notice/news must be set',
       );

  factory NoticeDetailArg.notice({
    required NoticeCategory category,
    required String id,
  }) => NoticeDetailArg._(id: id, noticeCategory: category);

  factory NoticeDetailArg.news({
    required NewsCategory category,
    required String id,
  }) => NoticeDetailArg._(id: id, newsCategory: category);

  final String id;
  final NoticeCategory? noticeCategory;
  final NewsCategory? newsCategory;

  /// 화면 표시용 카테고리 라벨.
  String get categoryLabel =>
      noticeCategory?.label ?? newsCategory?.label ?? '공지';

  @override
  bool operator ==(Object other) =>
      other is NoticeDetailArg &&
      other.id == id &&
      other.noticeCategory == noticeCategory &&
      other.newsCategory == newsCategory;

  @override
  int get hashCode => Object.hash(id, noticeCategory, newsCategory);
}

final noticeDetailProvider = FutureProvider.autoDispose
    .family<SejongNoticeDetail, NoticeDetailArg>((ref, arg) async {
      final remote = await ref.watch(_noticeRemoteProvider.future);
      if (arg.noticeCategory != null) {
        return remote.fetchNoticeDetail(
          category: arg.noticeCategory!,
          id: arg.id,
        );
      }
      return remote.fetchNewsDetail(category: arg.newsCategory!, id: arg.id);
    });
