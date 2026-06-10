// UCheck 로그인 응답 DTO.
//
// 원본: `UCheckDtos.kt`의 `UCheckLoginResponse`/`UCheckLoginData`
// /`RefreshTokenResponse`. 모바일·웹 양쪽 모두 동일 envelope이라 한 파일에 모아둠.

import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_mobile_info.dart';

/// 웹 API 로그인 응답.
class UCheckLoginResponse {
  const UCheckLoginResponse({
    this.resultCode = '',
    this.message = '',
    this.content,
  });

  /// 결과 코드.
  final String resultCode;

  /// 사람이 읽는 메시지.
  final String message;

  /// 성공 시 사용자/학기 정보.
  final UCheckLoginData? content;

  factory UCheckLoginResponse.fromJson(Map<String, dynamic> json) {
    // 원본 Kotlin은 `data` 필드, spec은 `content` — 둘 다 받음.
    final raw = json['data'] ?? json['content'];
    return UCheckLoginResponse(
      resultCode: json['result_code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      content: raw is Map<String, dynamic>
          ? UCheckLoginData.fromJson(raw)
          : null,
    );
  }
}

/// 로그인 성공 시의 사용자 + 학기 컨텍스트.
class UCheckLoginData {
  const UCheckLoginData({
    this.accountNo = '',
    this.accountId = '',
    this.accountRole = '',
    this.name = '',
    this.studentNo = '',
    this.targetYearterm,
    this.yearterms = const <UCheckYearterm>[],
  });

  /// 계정 PK.
  final String accountNo;

  /// 로그인 ID(보통 학번).
  final String accountId;

  /// 역할 (`"STUDENT"`/`"PROFESSOR"` 등).
  final String accountRole;

  /// 학생 이름.
  final String name;

  /// 학번.
  final String studentNo;

  /// 현재 활성화된 학기.
  final UCheckYearterm? targetYearterm;

  /// 조회 가능한 학기 목록.
  final List<UCheckYearterm> yearterms;

  factory UCheckLoginData.fromJson(Map<String, dynamic> json) {
    return UCheckLoginData(
      accountNo: json['account_no'] as String? ?? '',
      accountId: json['account_id'] as String? ?? '',
      accountRole: json['account_role'] as String? ?? '',
      name: json['name'] as String? ?? '',
      studentNo: json['student_no'] as String? ?? '',
      targetYearterm: json['target_yearterm'] == null
          ? null
          : UCheckYearterm.fromJson(
              json['target_yearterm'] as Map<String, dynamic>,
            ),
      yearterms: ((json['yearterms'] as List?) ?? const <dynamic>[])
          .map((e) => UCheckYearterm.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 모바일 API 토큰 갱신 응답.
class RefreshTokenResponse {
  const RefreshTokenResponse({this.result = 0, this.value});

  final int result;
  final RefreshTokenValue? value;

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      result: (json['result'] as num?)?.toInt() ?? 0,
      value: json['value'] == null
          ? null
          : RefreshTokenValue.fromJson(json['value'] as Map<String, dynamic>),
    );
  }
}

/// 토큰 갱신 페이로드.
class RefreshTokenValue {
  const RefreshTokenValue({
    this.attendPopupYn = '',
    this.role = '',
    this.userId = '',
    this.carrierCheck = '',
    this.userNm = '',
    this.userNo = '',
    this.token = '',
  });

  final String attendPopupYn;
  final String role;
  final String userId;
  final String carrierCheck;
  final String userNm;
  final String userNo;
  final String token;

  factory RefreshTokenValue.fromJson(Map<String, dynamic> json) {
    return RefreshTokenValue(
      attendPopupYn: json['attend_popup_yn'] as String? ?? '',
      role: json['role'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      carrierCheck: json['carrier_check'] as String? ?? '',
      userNm: json['user_nm'] as String? ?? '',
      userNo: json['user_no'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }
}
