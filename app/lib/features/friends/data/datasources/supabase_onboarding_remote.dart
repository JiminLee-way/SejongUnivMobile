import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sejong_smart_campus/core/network/supabase_config.dart';

/// sjapp 로그인 직후 Supabase 측 onboarding을 수행.
///
/// 흐름:
///   1. supabase.auth.signInAnonymously() — 익명 user JWT 발급
///   2. POST Supabase Edge Function
///      body: { sjapp_access_token, [timetable], [semester] }
///   3. Edge Function이 sjapp `/api/secureapi/auth/me`로 학번/이름/학과/학부
///      재검증 후 서버 함수로 envelope encrypt 저장
///
/// **학번 위조 방지의 핵심**: 클라가 임의 학번을 보내도 sjapp 서버가 토큰을
/// 검증하므로 위조된 user.userId가 안 나옴. Supabase는 sjapp 응답만 신뢰.
class SupabaseOnboardingResult {
  const SupabaseOnboardingResult({
    required this.profileId,
    required this.studentId,
    required this.name,
    required this.department,
    required this.college,
    required this.timetableSaved,
    this.timetableError,
  });

  final String profileId;
  final String studentId;
  final String name;
  final String? department;
  final String? college;
  final bool timetableSaved;
  final String? timetableError;
}

class SupabaseOnboardingException implements Exception {
  const SupabaseOnboardingException(this.message);
  final String message;
  @override
  String toString() => 'SupabaseOnboardingException: $message';
}

class SupabaseOnboardingRemote {
  SupabaseOnboardingRemote(this._client);
  final SupabaseClient _client;

  /// 익명 sign-in을 멱등으로 보장 — 이미 session 있으면 그대로 사용.
  Future<void> ensureAnonymousSession() async {
    if (_client.auth.currentSession != null) return;
    await _client.auth.signInAnonymously();
  }

  /// 로그인 성공 = sjapp이 이미 학번·이름을 검증해준 상태. 그 신원으로 본인
  /// 프로필을 직접 upsert한다. 서버 함수는 auth.uid() 기준으로 본인 행만 다룬다.
  ///
  /// Edge Function 경로가 일부 레거시 TLS 환경과 맞지 않아, 앱 로그인 성공 시점의
  /// 검증된 신원을 기준으로 직접 서버 함수를 호출한다.
  Future<void> upsertProfile({
    required String studentId,
    required String name,
    String? department,
    String? college,
  }) async {
    if (studentId.isEmpty || name.isEmpty) return;
    await ensureAnonymousSession();
    String? nz(String? s) => (s == null || s.isEmpty) ? null : s;
    await _client.rpc<dynamic>(
      SupabaseConfig.rpcUpsertUserFromSjapp,
      params: {
        'p_student_id': studentId,
        'p_name': name,
        'p_department': nz(department),
        'p_college': nz(college),
      },
    );
  }

  /// sjapp 토큰을 Edge Function으로 보내 server-side로 학번 검증 + 암호화 저장.
  /// 시간표는 선택. Onboard 실패 시 [SupabaseOnboardingException] 던짐.
  ///
  /// 현재 프로필 생성 경로에서는 쓰지 않는다. Edge 환경 호환성이 필요한 경로를
  /// 별도로 살릴 때를 위해 남겨둔다.
  Future<SupabaseOnboardingResult> onboard({
    required String sjappAccessToken,
    Map<String, dynamic>? timetable,
    String? semester,
  }) async {
    await ensureAnonymousSession();
    final body = <String, dynamic>{'sjapp_access_token': sjappAccessToken};
    if (timetable != null && semester != null) {
      body['timetable'] = timetable;
      body['semester'] = semester;
    }
    final res = await _client.functions.invoke(
      SupabaseConfig.functionOnboard,
      body: body,
    );
    if (res.status != 200) {
      final detail = res.data is Map<String, dynamic>
          ? (res.data as Map<String, dynamic>)['error']?.toString()
          : res.data?.toString();
      throw SupabaseOnboardingException(
        'onboard ${res.status}: ${detail ?? "unknown"}',
      );
    }
    final m = (res.data as Map).cast<String, dynamic>();
    return SupabaseOnboardingResult(
      profileId: m['profile_id'] as String,
      studentId: m['student_id'] as String,
      name: m['name'] as String,
      department: m['department'] as String?,
      college: m['college'] as String?,
      timetableSaved: (m['timetable_saved'] as bool?) ?? false,
      timetableError: m['timetable_error'] as String?,
    );
  }

  /// 로그아웃 시 익명 user 자체는 server에 남지만, 클라이언트의 PII cache는
  /// session 종료로 더 이상 복호화 불가 (auth.uid()가 사라짐). 명시적으로
  /// signOut.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// 본인 users.last_seen_at = now() 갱신.
  /// 처리방침 §보유기간 ④ — 마지막 접속으로부터 3개월 경과 시 휴면 자동 삭제.
  /// 익명 세션이 없으면 silent skip(비로그인 상태에는 갱신할 행이 없음).
  Future<void> updateLastSeen() async {
    if (_client.auth.currentSession == null) return;
    await _client.rpc<dynamic>(SupabaseConfig.rpcUpdateLastSeen);
  }

  /// 친구·시간표 공유 사용 중지(탈퇴).
  /// 자체서버 저장 데이터(친구·시간표·시설예약 캐시·디바이스 토큰·users 행)를
  /// **즉시 영구 삭제**한다. 호출 직후 [signOut]도 함께 호출하여 익명 세션 종료.
  Future<void> withdraw() async {
    await _client.rpc<dynamic>(SupabaseConfig.rpcWithdrawUser);
    await signOut();
  }
}
