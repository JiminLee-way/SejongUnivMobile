import 'package:sejong_smart_campus/features/auth/domain/entities/sejong_user.dart';

/// `/auth/login` · `/auth/me` 응답의 `data` 객체 → [SejongUser] 매핑.
///
/// 두 endpoint의 응답은 거의 동일하지만 login은 토큰 필드가 더 있고 me는
/// `statusName`이 추가된다. 토큰은 [AuthLoginResponseDto]에서 별도로 다룬다.
class SejongUserDto {
  const SejongUserDto._();

  static SejongUser fromJson(Map<String, dynamic> json) {
    return SejongUser(
      userId: _str(json['userId']),
      username: _str(json['username']),
      email: _str(json['email']),
      roles: (json['roles'] as List?)?.cast<String>() ?? const [],
      roleName: _str(json['roleName']),
      departmentName: _str(json['departmentName']),
      organizationClassName: _str(json['organizationClassName']),
      birthDate: _str(json['birthDate']),
      studentYear: (json['studentYear'] as num?)?.toInt() ?? 0,
      cardNo: _str(json['cardNo']),
      cardNoIos: _str(json['cardNoIos']),
      cmsUserId: _str(json['cmsUserId']),
      roleCd: _str(json['roleCd']),
      statusName: json['statusName'] as String?,
    );
  }

  static String _str(Object? v) => v?.toString() ?? '';
}

/// `/auth/login` 응답의 `data` 부분 — 사용자 정보 + 토큰.
///
/// `refreshToken` 필드는 응답 body에 null로 옴 (HttpOnly cookie로만 발급).
/// `expiresIn`은 초 단위 — TokenStorage엔 epoch ms로 환산해서 저장한다.
class AuthLoginResponseDto {
  const AuthLoginResponseDto({
    required this.user,
    required this.accessToken,
    required this.expiresInSec,
  });

  final SejongUser user;
  final String accessToken;
  final int expiresInSec;

  int get expiresAtMs =>
      DateTime.now().millisecondsSinceEpoch + expiresInSec * 1000;

  factory AuthLoginResponseDto.fromJson(Map<String, dynamic> json) {
    final user = SejongUserDto.fromJson(json);
    final token = json['accessToken'] as String?;
    final exp = (json['expiresIn'] as num?)?.toInt() ?? 1800;
    if (token == null || token.isEmpty) {
      throw const FormatException('login response missing accessToken');
    }
    return AuthLoginResponseDto(
      user: user,
      accessToken: token,
      expiresInSec: exp,
    );
  }
}
