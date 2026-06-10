import 'package:dio/dio.dart';

import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/core/network/sejong_api_exception.dart';
import 'package:sejong_smart_campus/core/network/sejong_endpoints.dart';
import 'package:sejong_smart_campus/features/auth/data/datasources/token_storage.dart';
import 'package:sejong_smart_campus/features/auth/data/models/sejong_user_dto.dart';
import 'package:sejong_smart_campus/features/auth/domain/entities/sejong_user.dart';
import 'package:sejong_smart_campus/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.client, required this.storage});

  final SejongApiClient client;
  final TokenStorage storage;

  @override
  Future<SejongUser> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final Response<dynamic> res;
    try {
      res = await client.dio.post<dynamic>(
        SejongEndpoints.login,
        data: {
          'username': username,
          'password': password,
          'rememberMe': rememberMe,
        },
      );
    } on DioException catch (e) {
      throw SejongApiException(
        message: _loginFailureMessage(e),
        statusCode: e.response?.statusCode,
        code: _bodyCode(e.response?.data),
        cause: e,
      );
    }

    final dto = client.unwrap<AuthLoginResponseDto>(
      res,
      (raw) => AuthLoginResponseDto.fromJson(raw as Map<String, dynamic>),
    );

    await storage.writeAccessToken(
      dto.accessToken,
      expiresAtMs: dto.expiresAtMs,
    );
    await storage.writeRememberMe(rememberMe);
    await storage.writeLastUserId(dto.user.userId);
    return dto.user;
  }

  @override
  Future<void> refresh() async {
    final Response<dynamic> res;
    try {
      // bareDio: AuthInterceptor 우회 — refresh 안에서 또 refresh 트리거되는
      // 재귀를 차단.
      res = await client.bareDio.post<dynamic>(SejongEndpoints.refresh);
    } on DioException catch (e) {
      throw SejongApiException(
        message: '자동 로그인 세션이 만료되었어요.',
        statusCode: e.response?.statusCode,
        code: _bodyCode(e.response?.data),
        cause: e,
      );
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      await storage.clearTokens();
      throw const SejongApiException(
        message: '자동 로그인 세션이 만료되었어요.',
        statusCode: 401,
        code: 'AUTH_REFRESH_EXPIRED',
      );
    }

    final dto = client.unwrap<AuthLoginResponseDto>(
      res,
      (raw) => AuthLoginResponseDto.fromJson(raw as Map<String, dynamic>),
    );
    await storage.writeAccessToken(
      dto.accessToken,
      expiresAtMs: dto.expiresAtMs,
    );
    await storage.writeLastUserId(dto.user.userId);
  }

  @override
  Future<SejongUser> fetchMe() async {
    final res = await client.dio.get<dynamic>(SejongEndpoints.me);
    return client.unwrap<SejongUser>(
      res,
      (raw) => SejongUserDto.fromJson(raw as Map<String, dynamic>),
    );
  }

  @override
  Future<void> logout({bool clearRememberMe = true}) async {
    // 서버 측 무효화 endpoint는 아직 호출하지 않는다. 클라이언트는 토큰만 비움.
    if (clearRememberMe) {
      await storage.clearAll();
    } else {
      await storage.clearTokens();
    }
  }

  // ─── helpers ──

  String? _bodyCode(Object? data) {
    if (data is Map<String, dynamic>) return data['code'] as String?;
    return null;
  }

  String _loginFailureMessage(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    if (body is Map<String, dynamic>) {
      final msg = (body['message'] as String?)?.trim();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    if (status == 401 || status == 400) {
      return '학번 또는 비밀번호가 올바르지 않아요.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '학교 서버 응답이 늦어요. 잠시 후 다시 시도해주세요.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '인터넷 연결을 확인해주세요.';
    }
    return '로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
  }
}
