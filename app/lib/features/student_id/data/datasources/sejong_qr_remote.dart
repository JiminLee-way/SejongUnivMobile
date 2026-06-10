import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';

/// `/api/secureapi/qr/generate` 호출 — 학생증 게이트/도서대출 인증용 QR을
/// **서버에서** 받아온다.
///
/// 서버가 보유한 키로 QR payload를 생성하므로 클라이언트가 로컬 렌더링으로
/// 동일 토큰을 만들 수 없다.
class SejongQrRemote {
  SejongQrRemote({required this.client});
  final SejongApiClient client;

  /// [data](평문 JSON 문자열)를 서버에 보내 암호화된 QR PNG bytes를 받는다.
  /// size/margin/errorCorrectionLevel 기본값은 공식 웹과 동일.
  Future<Uint8List> generateQr({
    required String data,
    int size = 200,
    int margin = 1,
    String errorCorrectionLevel = 'M',
  }) async {
    final res = await client.dio.post<dynamic>(
      SejongEndpoints.qrGenerate,
      data: {
        'data': data,
        'size': size,
        'margin': margin,
        'errorCorrectionLevel': errorCorrectionLevel,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    return client.unwrap<Uint8List>(res, (raw) {
      final m = (raw as Map).cast<String, dynamic>();
      final b64 = (m['qrCodeImage'] as String?)?.trim();
      if (b64 == null || b64.isEmpty) {
        throw const FormatException('qr/generate: qrCodeImage 비어있음');
      }
      return base64Decode(b64);
    });
  }
}
