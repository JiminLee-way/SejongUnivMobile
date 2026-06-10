import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';

class SejongMenuRemote {
  SejongMenuRemote({required this.client});
  final SejongApiClient client;

  Future<List<SejongMenuItem>> fetchTree(String menuId) async {
    final res = await client.dio.get<dynamic>(SejongEndpoints.menuTree(menuId));
    return client.unwrap<List<SejongMenuItem>>(res, (raw) {
      return (raw as List)
          .cast<Map<String, dynamic>>()
          .map(SejongMenuItem.fromJson)
          .toList();
    });
  }

  /// 토큰 핸드오프 — `callParams.queryParams[].endpoint`로 호출.
  /// 응답은 `{data: {token: "..."}}` 패턴이라고 가정. 토큰 문자열만 반환.
  Future<String?> resolveTokenFromEndpoint(String endpoint) async {
    final res = await client.dio.get<dynamic>(endpoint);
    return client.unwrap<String?>(res, (raw) {
      if (raw is Map<String, dynamic>) {
        return raw['token']?.toString();
      }
      if (raw is String) return raw;
      return null;
    });
  }
}
