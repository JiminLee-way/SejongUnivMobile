import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'package:sejong_smart_campus/core/network/sejong_api_exception.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/core/network/service_urls.dart';
import 'package:sejong_smart_campus/features/auth/data/datasources/token_storage.dart';

typedef SejongRefreshHook = Future<bool> Function();

/// 통합 서비스 API 호출의 단일 진입점.
///
/// 책임:
/// 1. baseUrl + 공통 헤더 부착
/// 2. cookie jar 자동 첨부/저장
/// 3. 인증이 필요한 요청에 access token 부착
/// 4. 401 발생 시 단일 refresh 작업을 공유하고 큐된 요청 재시도
///
/// [refreshHook]은 외부에 위임해 인증 상태 갱신을 한 곳에서 처리한다.
class SejongApiClient {
  SejongApiClient({
    required CookieJar cookieJar,
    required TokenStorage tokenStorage,
  }) : _cookieJar = cookieJar,
       _tokenStorage = tokenStorage {
    dio = _buildDio(withAuthInterceptor: true);
    _bareDio = _buildDio(withAuthInterceptor: false);
  }

  static const String baseUrl = ServiceUrls.sejongApi;

  final CookieJar _cookieJar;
  final TokenStorage _tokenStorage;

  /// 도메인 호출용 — auth interceptor 포함.
  late final Dio dio;

  /// `/auth/refresh` 같은 토큰 갱신 자체 호출용. interceptor 재진입 회피.
  late final Dio _bareDio;

  /// 외부에서 주입하는 refresh 구현. null이면 401 시 그대로 throw.
  SejongRefreshHook? _refreshHook;

  /// 동시 401에서 refresh는 한 번만 호출되도록 share.
  Future<bool>? _refreshFuture;

  /// [AuthRepository.refresh]를 가리키도록 외부에서 주입. 생성 순서상 ApiClient가
  /// 먼저 만들어지고 Repository가 뒤에 생기므로 setter로 분리.
  set refreshHook(SejongRefreshHook? hook) => _refreshHook = hook;

  /// refresh-only path (interceptor 우회용).
  Dio get bareDio => _bareDio;

  Dio _buildDio({required bool withAuthInterceptor}) {
    final d = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        headers: const {
          'X-Tenant-Id': 'SEJONG',
          'Accept-Language': 'ko',
          'Accept': 'application/json, text/plain, */*',
        },
        // 401·400 등 비-2xx도 onResponse로 받아 interceptor에서 분기.
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    d.interceptors.add(CookieManager(_cookieJar));
    if (withAuthInterceptor) {
      d.interceptors.add(_AuthInterceptor(client: this));
    }
    return d;
  }

  // ─── 도우미: envelope 검증 + 도메인 매핑 ────────────────────────────────

  /// 응답 body에서 `data`만 꺼내 디코더에 전달. 실패 시 [SejongApiException].
  T unwrap<T>(Response<dynamic> res, T Function(Object? raw) decode) {
    final body = res.data;
    if (body is! Map<String, dynamic>) {
      throw SejongApiException(
        message: '서버 응답 형식이 올바르지 않아요.',
        statusCode: res.statusCode,
      );
    }
    final success = body['success'] == true;
    if (!success || res.statusCode != null && res.statusCode! >= 400) {
      throw SejongApiException(
        message: (body['message'] as String?)?.trim().isNotEmpty == true
            ? body['message'] as String
            : _httpFallbackMessage(res.statusCode),
        statusCode: res.statusCode,
        code: body['code'] as String?,
      );
    }
    return decode(body['data']);
  }

  String _httpFallbackMessage(int? status) {
    if (status == 401) return '로그인이 필요해요. 다시 시도해주세요.';
    if (status == 403) return '접근 권한이 없어요.';
    if (status == 404) return '요청한 정보를 찾을 수 없어요.';
    if (status != null && status >= 500) {
      return '학교 서버에 일시적인 문제가 있어요. 잠시 후 다시 시도해주세요.';
    }
    return '요청을 처리하지 못했어요.';
  }

  // ─── 401 single-flight refresh ─────────────────────────────────────────

  /// AuthInterceptor에서 호출. 이미 진행 중인 refresh가 있으면 그것을 await.
  Future<bool> ensureFreshTokenForRetry() {
    final hook = _refreshHook;
    if (hook == null) return Future.value(false);
    return _refreshFuture ??= () async {
      try {
        return await hook();
      } finally {
        _refreshFuture = null;
      }
    }();
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor({required this.client});
  final SejongApiClient client;

  // refresh/login 자체 호출에는 Authorization을 안 붙인다.
  static const _skipAuthPaths = {
    SejongEndpoints.login,
    SejongEndpoints.refresh,
  };

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_skipAuthPaths.contains(options.path)) {
      final token = await client._tokenStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    // 200/뉴 처럼 validateStatus가 통과시킨 401을 여기서 잡는다.
    if (response.statusCode == 401 &&
        !_skipAuthPaths.contains(response.requestOptions.path)) {
      final retried = await _attemptRefreshAndRetry(response.requestOptions);
      if (retried != null) {
        handler.resolve(retried);
        return;
      }
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 &&
        !_skipAuthPaths.contains(err.requestOptions.path)) {
      final retried = await _attemptRefreshAndRetry(err.requestOptions);
      if (retried != null) {
        handler.resolve(retried);
        return;
      }
    }
    handler.next(err);
  }

  /// refresh 시도 → 성공 시 원 요청을 새 토큰으로 재호출하고 그 응답을 반환.
  /// 실패면 null.
  Future<Response?> _attemptRefreshAndRetry(RequestOptions original) async {
    final ok = await client.ensureFreshTokenForRetry();
    if (!ok) return null;
    final newToken = await client._tokenStorage.readAccessToken();
    if (newToken == null) return null;
    final retryOpts = Options(
      method: original.method,
      headers: {...original.headers, 'Authorization': 'Bearer $newToken'},
      responseType: original.responseType,
      contentType: original.contentType,
      validateStatus: original.validateStatus,
    );
    try {
      return await client.dio.request<dynamic>(
        original.path,
        data: original.data,
        queryParameters: original.queryParameters,
        options: retryOpts,
        cancelToken: original.cancelToken,
      );
    } catch (_) {
      return null;
    }
  }
}
