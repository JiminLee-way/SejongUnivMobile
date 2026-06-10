import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 학사 공지 카테고리. 세종대 공지 게시판 7개 분류와 1:1로 매칭.
enum NoticeCategory {
  general('일반공지'),
  admission('입학공지'),
  academic('학사공지'),
  exchangeKr('국제교류(KR)'),
  exchangeEn('국제교류(EN)'),
  career('취업'),
  scholarship('장학');

  const NoticeCategory(this.label);
  final String label;

  Color get color {
    switch (this) {
      case NoticeCategory.general:
        return const Color(0xFF5F5E5E);
      case NoticeCategory.admission:
        return const Color(0xFF7C3AED);
      case NoticeCategory.academic:
        return const Color(0xFF9E001F);
      case NoticeCategory.exchangeKr:
        return const Color(0xFF0EA5E9);
      case NoticeCategory.exchangeEn:
        return const Color(0xFF0284C7);
      case NoticeCategory.career:
        return const Color(0xFF0CA886);
      case NoticeCategory.scholarship:
        return const Color(0xFFF59E0B);
    }
  }
}

class NoticeItem {
  const NoticeItem({
    required this.id,
    required this.category,
    required this.title,
    required this.publisher,
    required this.publishedAt,
    this.hasAttachment = false,
    this.isPinned = false,
    this.viewCount = 0,
  });

  final String id;
  final NoticeCategory category;
  final String title;
  final String publisher;
  final DateTime publishedAt;
  final bool hasAttachment;
  final bool isPinned;
  final int viewCount;
}

/// 뉴스 카드 모델.
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.publishedAt,
    required this.thumbnailSeed,
    this.tag,
  });

  final String id;
  final String title;
  final String summary;
  final DateTime publishedAt;
  final int thumbnailSeed;
  final String? tag;
}

/// 자체 커뮤니티 게시판 — 고파스/에브리타임 스타일.
enum Board {
  free('자유게시판', Symbols.chat_bubble),
  anonymous('익명', Symbols.visibility_off),
  career('취준생', Symbols.work),
  market('중고장터', Symbols.storefront),
  food('맛집', Symbols.restaurant),
  club('동아리', Symbols.groups),
  housing('자취/하숙', Symbols.house),
  qna('새내기Q&A', Symbols.help);

  const Board(this.label, this.icon);
  final String label;
  final IconData icon;
}

class BoardPost {
  const BoardPost({
    required this.id,
    required this.board,
    required this.title,
    required this.preview,
    required this.author,
    required this.postedAt,
    required this.likeCount,
    required this.commentCount,
    this.isHot = false,
    this.isAnonymous = false,
  });

  final String id;
  final Board board;
  final String title;
  final String preview;
  final String author;
  final DateTime postedAt;
  final int likeCount;
  final int commentCount;
  final bool isHot;
  final bool isAnonymous;
}
