import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:synchronized/synchronized.dart';

import 'package:sejong_smart_campus/core/network/service_urls.dart';

/// 전자출결 모바일 API 클라이언트.
///
/// 통합 서비스 클라이언트와 인증/베이스 URL/쿠키 스코프를 분리한다.
///
/// 1. form-urlencoded 요청
/// 2. 응답 envelope 정규화
/// 3. 인메모리 cookie jar
/// 4. tokenMutex로 인증 관련 요청 직렬화
///
/// 메서드는 모두 raw `Map<String, dynamic>` 반환. DTO 변환은 Repository가 담당.
class UCheckApiClient {
  UCheckApiClient() {
    _dio = _build();
  }

  /// 서버 호환성을 위한 모바일 UA. 내부 빌드에서 실제 값을 주입한다.
  static const String _userAgent = String.fromEnvironment(
    'UCHECK_USER_AGENT',
    defaultValue: 'SejongUnivMobile',
  );
  static const String _clientVersion = String.fromEnvironment(
    'UCHECK_CLIENT_VERSION',
    defaultValue: '1',
  );

  static const String baseUrl = ServiceUrls.ucheckApi;
  static const String _mobilePrefix = '/libekasac/sacApp2';

  late final Dio _dio;
  final CookieJar _cookieJar = CookieJar();
  final Lock _tokenMutex = Lock();

  /// 디버그/테스트용 — 외부에서 cookieJar 접근.
  CookieJar get cookieJar => _cookieJar;

  Dio _build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
        headers: const {
          'User-Agent': _userAgent,
          'Accept': '*/*',
          'Accept-Language': 'ko-KR,ko;q=0.9',
        },
        // 200+ envelope에 result=0 (비-2xx 아님) 분기를 onResponse에서 처리.
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    dio.interceptors.add(CookieManager(_cookieJar));
    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      // 일부 네트워크 환경의 인증서 체인 이슈를 완화한다.
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
    dio.httpClientAdapter = adapter;
    return dio;
  }

  // ─── Mobile API ──────────────────────────────────────────────────────

  /// 로그인 — id/pwd는 AES 암호화된 hex 문자열을 받음 (cipher 호출은 Repository).
  Future<Map<String, dynamic>> acquireMobileToken({
    required String idHex,
    required String pwdHex,
    required String maddr,
    required String mos,
    bool isRooted = false,
  }) {
    return _tokenMutex.synchronized(
      () => _postMobile('/getToken.do', {
        'id': idHex,
        'pwd': pwdHex,
        'maddr': maddr,
        'apptype': 'as2',
        'mos': mos,
        'is_rooted': isRooted ? 'Y' : 'N',
        'locale': 'ko',
      }),
    );
  }

  /// 기기 변경 신청 — `incorrect_phone` 에러 후 호출.
  Future<Map<String, dynamic>> phoneInit({
    required String idHex,
    required String pwdHex,
    required String maddr,
  }) {
    return _tokenMutex.synchronized(
      () => _postMobile('/phoneInit.do', {
        'id': idHex,
        'pwd': pwdHex,
        'maddr': maddr,
        'locale': 'ko',
      }),
    );
  }

  /// 토큰 만료 시 갱신.
  Future<Map<String, dynamic>> refreshMobileToken({required String token}) {
    return _tokenMutex.synchronized(
      () => _postMobile('/refreshToken.do', {
        'token': token,
        'is_rooted': 'N',
        'locale': 'ko',
      }),
    );
  }

  /// 학기/시간표/오늘 강의/비콘 화이트리스트 — 홈 진입 시 매번.
  /// `lastUpdateDate=""`면 풀 fetch, 값이 있으면 변경분만.
  Future<Map<String, dynamic>> getMobileInfo({
    required String token,
    required String deviceId,
    required String modelNameB64,
    required String mobileOs,
    String lastUpdateDate = '',
    String lectureYear = '',
    String lectureTerm = '',
  }) {
    return _tokenMutex.synchronized(
      () => _postMobile('/getInfo.do', {
        'token': token,
        'device_id': deviceId,
        'model_name': modelNameB64,
        'mobile_os': mobileOs,
        'version_code': _clientVersion,
        'last_update_date': lastUpdateDate,
        'lecture_year': lectureYear,
        'lecture_term': lectureTerm,
        'locale': 'ko',
      }),
    );
  }

  /// 강의별 출석 이력.
  Future<Map<String, dynamic>> getMobileAttendList({
    required String token,
    required int lectureNo,
  }) {
    return _postMobile('/attendList.do', {
      'token': token,
      'lno': lectureNo.toString(),
      'locale': 'ko',
    });
  }

  /// 이의신청 상세 (목록 + 이미 제출한 내용).
  Future<Map<String, dynamic>> getObjectionDetail({
    required String token,
    required int lectureNo,
    required int lectureWeek,
    required int classNo,
    String objectionStatus = '1',
  }) {
    return _tokenMutex.synchronized(
      () => _postMobile('/objectionDetail.do', {
        'token': token,
        'user_type': 'S',
        'lecture_week': lectureWeek.toString(),
        'cno': classNo.toString(),
        'objection_status': objectionStatus,
        'lno': lectureNo.toString(),
        'locale': 'ko',
      }),
    );
  }

  /// 이의신청 제출. 첨부는 V2 — 지금은 `'[]'` (빈 JSON 문자열).
  Future<Map<String, dynamic>> submitObjection({
    required String token,
    required int lectureNo,
    required int lectureWeek,
    required int classNo,
    required String attendType,
    required String objectionCd,
    required String objectionDetail,
    String objectionAttach = '[]',
  }) {
    return _tokenMutex.synchronized(
      () => _postMobile('/objection.do', {
        'token': token,
        'is_cascade_yn': 'N',
        'user_type': 'S',
        'lecture_week': lectureWeek.toString(),
        'attend_type': attendType,
        'cno': classNo.toString(),
        'objection_cd': objectionCd,
        'objection_detail': objectionDetail,
        'lno': lectureNo.toString(),
        'locale': 'ko',
        'objection_attach': objectionAttach,
      }),
    );
  }

  /// 출석 체크 — **BLE 매칭 결과를 그대로 동봉**. ap_type/local_name/MAC/RSSI
  /// 누락 시 서버가 거절. 강의별 동시성이라 mutex 우회.
  Future<Map<String, dynamic>> attendCheck({
    required String token,
    required int lectureNo,
    required int classNo,
    required String roomCd,
    required int lectureWeek,
    required int lectureType,
    required int attendRequestType, // 1=입실 2=중간 3=퇴실 4=인증코드
    required String apType, // B / D / S / P
    required String localName,
    required String bcMaddr40,
    required int rssi,
    String? bcUuid40,
    int? bcMajor40,
    int? bcMinor40,
    int txPower = -16,
    required String memoCipherHex,
    required String isCorrectMac, // Y / N / U
    String networkInfo = 'WIFI',
  }) {
    final form = <String, String>{
      'token': token,
      'lno': lectureNo.toString(),
      'cno': classNo.toString(),
      'room_cd': roomCd,
      'lecture_week': lectureWeek.toString(),
      'lecture_type': lectureType.toString(),
      'attend_request_type': attendRequestType.toString(),
      'ap_type': apType,
      'local_name': localName,
      'bc_maddr40': bcMaddr40,
      'rssi': rssi.toString(),
      'tx_power': txPower.toString(),
      'bc_battery_life': '-1',
      'is_correct_mac': isCorrectMac,
      'is_rooted': 'N',
      'locale': 'ko',
      'network_info': networkInfo,
      'memo': memoCipherHex,
      'auth_code': '',
      'err_date': '',
    };
    if (bcUuid40 != null) form['bc_uuid40'] = bcUuid40;
    if (bcMajor40 != null) form['bc_major40'] = bcMajor40.toString();
    if (bcMinor40 != null) form['bc_minor40'] = bcMinor40.toString();
    return _postMobile('/attendCheck.do', form);
  }

  // ─── 공통 POST ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _postMobile(
    String path,
    Map<String, dynamic> form,
  ) async {
    final res = await _dio.post<dynamic>(
      '$_mobilePrefix$path',
      data: form,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return _normalizeResponse(res);
  }

  Map<String, dynamic> _normalizeResponse(Response<dynamic> res) {
    final body = res.data;
    // dio가 application/x-www-form-urlencoded 응답을 String으로 줄 때도 있음.
    if (body is String) {
      final trimmed = body.trim();
      if (trimmed.startsWith('<')) {
        // HTML 응답 = 세션 만료 또는 비정상.
        throw const UCheckHttpException('서버가 HTML로 응답했어요. 세션이 끊긴 듯해요.');
      }
      try {
        return jsonDecode(trimmed) as Map<String, dynamic>;
      } catch (_) {
        throw UCheckHttpException(
          'JSON 디코드 실패: ${trimmed.substring(0, trimmed.length.clamp(0, 80))}',
        );
      }
    }
    if (body is Map<String, dynamic>) return body;
    throw UCheckHttpException('알 수 없는 응답 타입: ${body.runtimeType}');
  }

  /// 자격증명 초기화 (로그아웃) — cookieJar도 비움.
  Future<void> clearSession() async {
    await _cookieJar.deleteAll();
  }
}

// ─── 예외 계층 ──────────────────────────────────────────────────────────

/// UCheck 응답에서 result=0/2이거나 비-2xx HTTP일 때.
class UCheckApiException implements Exception {
  const UCheckApiException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => 'UCheckApiException($code): $message';
}

/// 인증 실패 — `value=="error.api.tokeninvalid"` 또는 자격증명 없음.
class UCheckUnauthenticatedException extends UCheckApiException {
  const UCheckUnauthenticatedException([super.message = '인증이 필요해요'])
    : super(code: 'tokeninvalid');
}

/// 단말 변경 — `value=="error.api.incorrect_phone"`. phoneInit 후 재시도.
class UCheckIncorrectPhoneException extends UCheckApiException {
  const UCheckIncorrectPhoneException()
    : super('등록되지 않은 단말이에요', code: 'incorrect_phone');
}

/// HTTP 자체 오류 (cleartext, HTML 응답, JSON 디코드 실패).
class UCheckHttpException implements Exception {
  const UCheckHttpException(this.message);
  final String message;
  @override
  String toString() => 'UCheckHttpException: $message';
}
