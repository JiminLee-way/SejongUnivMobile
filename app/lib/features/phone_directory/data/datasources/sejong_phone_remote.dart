import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/phone_directory/domain/entities/phone_directory_models.dart';

/// 교직원 전화번호 검색 — sjapp `/api/publicapi/phone-number`(공개).
///
/// 에러 처리는 [SejongApiClient.unwrap](envelope 검증 + [SejongApiException])과
/// Dio 인터셉터(401 refresh)에 위임 — datasource는 try/catch 하지 않는다(앱 관례).
/// 파싱은 네트워크와 분리된 순수·정적 [parsePage]로 빼 단위 테스트가 가능하다.
class SejongPhoneRemote {
  SejongPhoneRemote({required this.client});

  final SejongApiClient client;

  /// [keyword]로 교직원을 검색한다. [type]이 전체가 아니면 `searchType` 파라미터 부착.
  /// 한 번에 [size]건(기본 100)만 받는다 — 흔한 이름/학과 검색은 그 안에 다 들어온다.
  Future<StaffSearchResult> search({
    required String keyword,
    PhoneSearchType type = PhoneSearchType.all,
    int page = 0,
    int size = 100,
  }) async {
    final res = await client.dio.get<dynamic>(
      SejongEndpoints.phoneDirectory,
      queryParameters: {
        'page': page,
        'size': size,
        'keyword': keyword,
        if (type.apiValue != null) 'searchType': type.apiValue,
      },
    );
    return client.unwrap<StaffSearchResult>(res, parsePage);
  }

  /// 응답 `data`(Spring Pageable Map)에서 교직원 목록 + 페이지 메타를 뽑는다.
  /// 빈/깨진 입력에도 throw 없이 빈 결과를 돌려준다(이름 없는 행은 스킵).
  static StaffSearchResult parsePage(Object? raw) {
    final map = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final content = (map['content'] as List?) ?? const <dynamic>[];
    final contacts = <StaffContact>[];
    for (final row in content) {
      if (row is Map<String, dynamic>) {
        final c = StaffContact.fromJson(row);
        if (c.name.isNotEmpty) contacts.add(c);
      }
    }
    final total = (map['totalElements'] as num?)?.toInt() ?? contacts.length;
    final last = map['last'] == true;
    return StaffSearchResult(contacts: contacts, total: total, hasMore: !last);
  }
}
