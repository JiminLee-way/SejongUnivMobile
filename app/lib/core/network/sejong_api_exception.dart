/// 세종 API 호출 실패 표준 예외.
///
/// Dio의 DioException과 envelope `success=false`를 한 곳으로 모아 UI 측에서
/// 단순화한 try/catch가 가능하게 한다. 메시지는 한국어로 노출 — 서버
/// `message`가 있으면 그것을 그대로 쓰고, 네트워크 오류 등은 일반화.
class SejongApiException implements Exception {
  const SejongApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.cause,
  });

  /// 사용자에게 보여줄 한국어 메시지.
  final String message;

  /// HTTP 상태 (네트워크 오류는 null).
  final int? statusCode;

  /// 서버 envelope의 비즈니스 코드 (예: AUTH_INVALID_CREDENTIALS).
  final String? code;

  /// 원본 예외 — 로깅용. 화면엔 안 보여준다.
  final Object? cause;

  bool get isAuth => statusCode == 401 || code?.startsWith('AUTH_') == true;
  bool get isNetwork => statusCode == null;

  @override
  String toString() =>
      'SejongApiException(status=$statusCode, code=$code, message=$message)';
}
