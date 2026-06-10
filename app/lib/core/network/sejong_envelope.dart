/// 세종 통합앱 응답 envelope.
///
/// 모든 응답은 다음 모양으로 옴:
/// ```json
/// { "status": "success", "code": "SUCCESS", "message": "성공",
///   "data": ..., "timestamp": "...", "httpStatus": "OK", "success": true }
/// ```
/// 클라이언트는 [SejongEnvelope.fromJson]으로 한 번 감싼 뒤 `.data`만
/// 도메인으로 매핑한다. 실패는 HTTP status + [SejongEnvelope.code]로 분기.
class SejongEnvelope<T> {
  const SejongEnvelope({
    required this.status,
    required this.code,
    required this.message,
    required this.data,
    required this.success,
    this.httpStatus,
    this.timestamp,
  });

  final String status;
  final String code;
  final String message;
  final T data;
  final bool success;
  final String? httpStatus;
  final String? timestamp;

  factory SejongEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? raw) decodeData,
  ) {
    return SejongEnvelope<T>(
      status: json['status'] as String? ?? 'unknown',
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? '',
      data: decodeData(json['data']),
      success: json['success'] as bool? ?? false,
      httpStatus: json['httpStatus'] as String?,
      timestamp: json['timestamp'] as String?,
    );
  }
}
