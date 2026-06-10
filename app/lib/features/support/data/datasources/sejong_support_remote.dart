import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/support/domain/entities/support_models.dart';

class SejongSupportRemote {
  SejongSupportRemote({required this.client});
  final SejongApiClient client;

  // NOTE: 1:1 문의(QnA)는 앱 자체 문의로 처리한다. 여기 남은 건 학교 FAQ 조회뿐.

  Future<List<FaqCategory>> fetchFaqCategories() async {
    final res = await client.dio.get<dynamic>(
      '${SejongPrefix.publicApi}/faq/categories',
    );
    return client.unwrap<List<FaqCategory>>(res, (raw) {
      return (raw as List)
          .cast<Map<String, dynamic>>()
          .map(FaqCategory.fromJson)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    });
  }

  Future<List<FaqItem>> fetchFaqs({String? categoryId, int size = 30}) async {
    final res = await client.dio.get<dynamic>(
      '${SejongPrefix.publicApi}/faq',
      queryParameters: <String, dynamic>{
        'page': 0,
        'size': size,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );
    return client.unwrap<List<FaqItem>>(res, (raw) {
      final m = raw is Map<String, dynamic> ? raw : null;
      final list = (m?['content'] as List?) ?? (raw is List ? raw : const []);
      return list.cast<Map<String, dynamic>>().map(FaqItem.fromJson).toList();
    });
  }
}
