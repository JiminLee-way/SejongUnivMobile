import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';

/// `/api/secureapi/photos/me` 호출 — Bearer 헤더로 image/jpeg 바이너리 받기.
///
/// 응답은 envelope가 아니라 raw jpeg(약 12KB)이므로 envelope unwrapping 우회.
/// 메모리 캐시는 호출자(provider)가 담당 — 여기는 fetch만.
class SejongPhotoRemote {
  SejongPhotoRemote({required this.client});
  final SejongApiClient client;

  Future<Uint8List> fetchMyPhoto() async {
    final res = await client.dio.get<List<int>>(
      SejongEndpoints.photosMe,
      options: Options(
        responseType: ResponseType.bytes,
        // 이 endpoint는 application/json 대신 image/jpeg을 반환 — accept를 풀어둔다.
        headers: const {'Accept': 'image/jpeg,image/*;q=0.9,*/*;q=0.5'},
      ),
    );
    final body = res.data;
    if (body == null || body.isEmpty) {
      throw Exception('photos/me empty body');
    }
    return Uint8List.fromList(body);
  }
}
