/// 지원 도메인 — FAQ + 1:1 문의(QnA).
library;

class FaqCategory {
  const FaqCategory({
    required this.categoryId,
    required this.categoryName,
    required this.displayOrder,
  });
  final String categoryId;
  final String categoryName;
  final int displayOrder;

  factory FaqCategory.fromJson(Map<String, dynamic> json) => FaqCategory(
    categoryId: (json['categoryId'] ?? '').toString(),
    categoryName: (json['categoryName'] ?? '').toString(),
    displayOrder: ((json['displayOrder'] as num?) ?? 0).toInt(),
  );
}

/// QnA 카테고리 — `/api/publicapi/qna/categories`.
/// active=false인 카테고리는 fetch 단계에서 거른다.
class QnaCategory {
  const QnaCategory({
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.displayOrder,
  });
  final String categoryId;
  final String categoryName;
  final String description;
  final int displayOrder;

  factory QnaCategory.fromJson(Map<String, dynamic> json) => QnaCategory(
    categoryId: (json['categoryId'] ?? '').toString(),
    categoryName: (json['categoryName'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    displayOrder: ((json['displayOrder'] as num?) ?? 0).toInt(),
  );
}

class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    this.answer,
    this.categoryId,
    this.categoryName,
  });
  final String id;
  final String question;
  final String? answer;
  final String? categoryId;
  final String? categoryName;

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    String first(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    return FaqItem(
      id: first(['id', 'faqId']),
      question: first(['question', 'title', 'q']),
      answer: first(['answer', 'content', 'a']).isEmpty
          ? null
          : first(['answer', 'content', 'a']),
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
    );
  }
}

class QnaItem {
  const QnaItem({
    required this.id,
    required this.title,
    this.status,
    this.createdAt,
    this.answer,
    this.isCrashReport = false,
  });
  final String id;
  final String title;
  final String? status;
  final DateTime? createdAt;
  final String? answer;
  final bool isCrashReport;

  factory QnaItem.fromJson(Map<String, dynamic> json) {
    String first(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    return QnaItem(
      id: first(['id', 'qnaId', 'inquiryId']),
      title: first(['title', 'subject', 'question']),
      status: json['status'] as String?,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      answer: json['answer'] as String?,
    );
  }

  /// Supabase `app_inquiries` 한 행 → QnaItem. status 코드를 한글 라벨로 매핑.
  factory QnaItem.fromInquiryRow(Map<String, dynamic> row) {
    const statusLabel = {'open': '접수됨', 'answered': '답변 완료', 'closed': '종료'};
    final code = (row['status'] ?? 'open').toString();
    return QnaItem(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? '').toString(),
      status: statusLabel[code] ?? code,
      createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()),
      answer: row['answer'] as String?,
      isCrashReport: row['is_crash_report'] == true,
    );
  }
}

/// 앱 1:1 문의 분류 — **이 앱 자체**에 대한 것이라 sjapp이 아니라 클라가 정의한
/// 고정값. id는 DB `app_inquiries.category`에 그대로 저장된다.
class AppInquiryCategory {
  const AppInquiryCategory(this.id, this.label);
  final String id;
  final String label;
}

const List<AppInquiryCategory> appInquiryCategories = [
  AppInquiryCategory('bug', '버그 신고'),
  AppInquiryCategory('feature', '기능 제안'),
  AppInquiryCategory('usage', '사용 문의'),
  AppInquiryCategory('account', '계정·로그인'),
  AppInquiryCategory('etc', '기타'),
];
