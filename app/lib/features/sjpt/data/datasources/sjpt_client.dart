import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'package:sejong_smart_campus/core/network/service_urls.dart';

/// 강의실·시설물 예약 시스템 클라이언트.
///
/// 인증 흐름:
/// 1. GET  `/main/view/Login/doSsoLogin.do` — ssotoken 쿠키로 SSO 수립
/// 2. POST `/main/sys/UserInfo/initUserInfo.do` (빈 addParam) → RUNNING_SEJONG UUID
/// 3. 이후 모든 POST는 addParam 안에 RUNNING_SEJONG 포함
///
/// addParam 인코딩: base64( Uri.encodeComponent(jsonEncode(map)) )
class SjptClient {
  SjptClient({required CookieJar cookieJar}) {
    final baseUrl = ServiceUrls.sjpt;
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=UTF-8',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14; Sejong Smart Campus) AppleWebKit/537.36',
          if (baseUrl.isNotEmpty) 'Origin': baseUrl,
          if (baseUrl.isNotEmpty) 'Referer': ServiceUrls.join(baseUrl, '/'),
        },
      ),
    );
    _dio.interceptors.add(CookieManager(cookieJar));
  }

  late final Dio _dio;

  String? _runningSejong;
  String? _intgUsrNo;
  String? _loginDt;
  String? _userName;
  String? _phone1;
  String? _phone2;
  String? _phone3;
  String? _deptNo;
  String? _deptNm;

  bool get isInitialized => _runningSejong != null;

  String get phone1 => _phone1 ?? '';
  String get phone2 => _phone2 ?? '';
  String get phone3 => _phone3 ?? '';
  String get deptNm => _deptNm ?? '';

  /// Step 1+2: SSO 수립 후 RUNNING_SEJONG 획득.
  /// 반환값 = RUNNING_SEJONG (null이면 실패).
  Future<String?> initialize() async {
    // Step 1 — SSO 쿠키로 sjpt 세션 수립. 200 HTML 응답은 무시.
    try {
      await _dio.get(
        '/main/view/Login/doSsoLogin.do',
        queryParameters: {'p': ''},
        options: Options(responseType: ResponseType.plain),
      );
    } catch (_) {
      // Set-Cookie 세팅 목적이므로 body는 불필요
    }

    // Step 2 — 빈 addParam으로 initUserInfo → RUNNING_SEJONG
    final resp = await _dio.post<Map<String, dynamic>>(
      '/main/sys/UserInfo/initUserInfo.do',
      queryParameters: {
        'addParam': _encodeAddParam({
          '_runIntgUsrNo': '',
          '_runPgLoginDt': '',
          '_runningSejong': '',
        }),
      },
    );

    final body = resp.data ?? {};
    final userInfo = body['dm_UserInfo'] as Map<String, dynamic>?;
    final userInfoGam = body['dm_UserInfoGam'] as Map<String, dynamic>?;

    _runningSejong = userInfo?['RUNNING_SEJONG'] as String?;
    _intgUsrNo = userInfo?['INTG_USR_NO'] as String?;
    _userName = userInfo?['INTG_USR_NM'] as String?;
    // "2026-05-26 18:06:02" → "20260526180602"
    _loginDt = (userInfoGam?['LOGIN_TIME'] as String?)
        ?.replaceAll('-', '')
        .replaceAll(' ', '')
        .replaceAll(':', '');
    _phone1 = userInfoGam?['USER_PHONE_NO1'] as String?;
    _phone2 = userInfoGam?['USER_PHONE_NO2'] as String?;
    _phone3 = userInfoGam?['USER_PHONE_NO3'] as String?;
    // 학과 코드/명 — 필드명은 dm_UserInfoGam 실 응답 기준.
    _deptNo = (userInfoGam?['PSTN_DEPT_NO'] ?? userInfoGam?['DEPT_NO'])
        ?.toString();
    _deptNm = (userInfoGam?['PSTN_DEPT_NM'] ?? userInfoGam?['DEPT_NM'])
        ?.toString();

    return _runningSejong;
  }

  /// 세션 유지 (30분 주기 keepalive).
  Future<void> resetSessionTime() async {
    if (!isInitialized) return;
    await _dio.post<void>(
      '/main/view/Main/doResetSessionTime.do',
      queryParameters: {'addParam': _apiParam('doResetSessionTime')},
      data: {'processMessage': ''},
    );
  }

  // ── 시설물 목록 API ──────────────────────────────────────

  /// 전체 시설물 목록 (강의실 + 기타). [instTpCd] 비우면 전체.
  Future<List<Map<String, dynamic>>> listFacilities({
    String placeDivCd = 'GAB002001',
    String instTpCd = '',
  }) async {
    _assertInitialized();

    final now = DateTime.now();
    final nowDt = _formatDt(now);
    final popupTs = _formatPopupTs(now);

    await _dio.post<void>(
      '/main/sys/UserRole/initUserRole.do',
      queryParameters: {
        'addParam': _encodeAddParam({
          'pbForceLog': 'false',
          '_runPgmKey': 'PSTD00201',
          '_runSysKey': 'GAM',
          '_runIntgUsrNo': _intgUsrNo ?? '',
          '_runPgLoginDt': nowDt,
          '_runningSejong': _runningSejong ?? '',
          '_runPgPopupUrl': '/gam/gai/GaiFacilityQryPop.xml',
        }),
      },
    );

    final sid =
        'mf_tabMainCon_contents_PSTD00201_body_GaiFacilityQryPop${popupTs}_wframe_sub_search';
    final resp = await _dio.post<Map<String, dynamic>>(
      '/gam/gam/gai/GaiPopuFqp/doListFacilityMst.do',
      queryParameters: {
        'addParam': _encodeAddParam({
          '_runPgmKey': 'PSTD00201',
          '_runSysKey': 'GAM',
          '_runIntgUsrNo': _intgUsrNo ?? '',
          '_runPgLoginDt': nowDt,
          '_runningSejong': _runningSejong ?? '',
          '_runPgPopupUrl': '/gam/gai/GaiFacilityQryPop.xml',
        }),
      },
      options: Options(headers: {'submissionid': sid}),
      data: {
        'dm_sch': {
          'ROOM_ABBT': '',
          'ROOM_NM': instTpCd,
          'PLACE_DIV_CD': placeDivCd,
          'BLD_NM': '',
        },
      },
    );
    return _asList(resp.data?['dl_mainList']);
  }

  /// 특정 시설물의 날짜별 시간표 (강의실·비강의실 공통).
  Future<List<Map<String, dynamic>>> listRoomTimeTable({
    required String roomAbbt,
    required String useDate,
  }) async {
    _assertInitialized();
    final resp = await _dio.post<Map<String, dynamic>>(
      '/gam/gam/gai/GaiPopuInst/doListInstTimeTable.do',
      queryParameters: {'addParam': _apiParam('PSTD00202')},
      options: Options(
        headers: {
          'submissionid': 'mf_tabMainCon_contents_PSTD00202_body_sub_search',
        },
      ),
      data: {
        'dm_search': {
          'PLACE_DIV_CD': 'GAB002001',
          'STATUS_DIV_CD': 'COA008001',
          'ROOM_ABBT': roomAbbt,
          'INST_TP_CD': '',
          'DIRECT_YN': '',
          'USE_DT_S': useDate,
          'USE_DT_E': useDate,
        },
      },
    );
    return _asList(resp.data?['dl_main']);
  }

  /// 내 시설물 신청 내역.
  Future<List<Map<String, dynamic>>> listMyApplications({
    required String startDate,
    required String endDate,
  }) async {
    _assertInitialized();
    final resp = await _dio.post<Map<String, dynamic>>(
      '/gam/gam/gai/GaiUsmnIua/doListInstUseAply.do',
      queryParameters: {'addParam': _apiParam('PSTD00201')},
      data: {
        'dm_search': {
          'INST_DIV_CD': '',
          'FACILITY_NM': '',
          'PLACE_DIV_CD': 'GAB002001',
          'USE_BGN_DT': startDate,
          'USE_END_DT': endDate,
          'OBJ_FLAG': 'STU',
          'USE_BGN_TIME_1': '',
          'USE_BGN_TIME_2': '',
          'USE_FSHTM_1': '',
          'USE_FSHTM_2': '',
        },
      },
    );
    return _asList(resp.data?['dl_main']);
  }

  // ── 예약 가능 인스턴스 조회 ──────────────────────────────

  /// 특정 시설물의 예약 가능 인스턴스 조회 (FACILITY_MNGT_NO 포함).
  /// 해당 날짜에 예약 불가이면 null 반환.
  Future<Map<String, dynamic>?> getFacilityInstance({
    required String roomAbbt,
    required String useDate,
    String endDate = '',
  }) async {
    _assertInitialized();
    await _dio.post<void>(
      '/main/sys/UserRole/initUserRole.do',
      queryParameters: {
        'addParam': _encodeAddParam({
          'pbForceLog': 'false',
          '_runPgmKey': 'PSTD00201',
          '_runSysKey': 'GAM',
          '_runIntgUsrNo': _intgUsrNo ?? '',
          '_runPgLoginDt': _loginDt ?? '',
          '_runningSejong': _runningSejong ?? '',
          '_runPgPopupUrl': '/gam/gai/GaiInstQryPop.xml',
        }),
      },
    );
    final resp = await _dio.post<Map<String, dynamic>>(
      '/gam/gam/gai/GaiPopuInst/doListInst.do',
      queryParameters: {
        'addParam': _encodeAddParam({
          '_runPgmKey': 'PSTD00201',
          '_runSysKey': 'GAM',
          '_runIntgUsrNo': _intgUsrNo ?? '',
          '_runPgLoginDt': _loginDt ?? '',
          '_runningSejong': _runningSejong ?? '',
          '_runPgPopupUrl': '/gam/gai/GaiInstQryPop.xml',
        }),
      },
      data: {
        'dm_search': {
          'PLACE_DIV_CD': 'GAB002001',
          'STATUS_DIV_CD': 'COA008001',
          'INST_TP_CD': '',
          'ROOM_ABBT': roomAbbt,
          'DIRECT_YN': '',
          'FACILITY_NM': '',
          'USE_DT_S': useDate,
          'USE_DT_E': endDate.isEmpty ? useDate : endDate,
          'BGN_TIME_HOUR': '09',
          'BGN_TIME_MIN': '00',
          'FSHTM_HOUR': '22',
          'FSHTM_MIN': '00',
          'BLD_NO': '',
          'ROOM_NO': '',
          'BLD_NM': '',
          'ROOM_NM': '',
          'TIME_FROM': '',
          'TIME_TO': '',
          'USE_TIME_1': '',
          'USE_TIME_2': '',
          'TAB_IDX': '',
          'USE_DAY': '',
        },
      },
    );
    final list = _asList(resp.data?['dl_main']);
    return list.isNotEmpty ? list.first : null;
  }

  // ── 예약 신청 흐름 ────────────────────────────────────────

  /// 시간 중복 여부 확인. RETN_CNT=0 → 예약 가능.
  Future<bool> checkTimeConflict({
    required String bldNo,
    required String roomNo,
    required String startDate,
    required String endDate,
    required String bgnHour,
    required String bgnMin,
    required String endHour,
    required String endMin,
    String useApplyNo = '',
  }) async {
    _assertInitialized();
    final resp = await _dio.post<Map<String, dynamic>>(
      '/gam/gam/gai/GaiUsmnIua/doListUseTimeCheck.do',
      queryParameters: {'addParam': _apiParam('PSTD00201')},
      data: {
        'dm_searchTime': {
          'USE_BGN_DT': startDate,
          'USE_END_DT': endDate,
          'USE_BGN_TIME_1': bgnHour,
          'USE_BGN_TIME_2': bgnMin,
          'USE_FSHTM_1': endHour,
          'USE_FSHTM_2': endMin,
          'PLACE_DIV_CD': 'GAB002001',
          'BLD_NO': bldNo,
          'ROOM_NO': roomNo,
          'USE_DAY': '',
          'USE_APPLY_NO': useApplyNo,
        },
      },
    );
    final chk = _asList(resp.data?['dl_useTimeChk']);
    if (chk.isEmpty) return false;
    final cnt = (chk.first['RETN_CNT'] as num?)?.toInt() ?? 1;
    return cnt == 0; // 0 = 중복 없음 = 신청 가능
  }

  /// 유의사항 내용 조회.
  Future<List<Map<String, dynamic>>> getNotices() async {
    _assertInitialized();
    final resp = await _dio.post<Map<String, dynamic>>(
      '/gam/gam/gai/GaiUsmnNtc/doListNotice.do',
      queryParameters: {'addParam': _apiParam('PSTD00201')},
      data: {
        'dm_search': {
          'PGM_NM': 'GaiNoticePop',
          'MATDT_NM': '',
          'USE_FLAG': 'Y',
        },
      },
    );
    return _asList(resp.data?['dl_main']);
  }

  /// 시설물 사용신청 제출. 반환값 = USE_APPLY_NO (신청번호).
  ///
  /// 서버가 요구하는 전체 필드를 포함한다.
  Future<String> saveReservation({
    required String facilityMngtNo,
    required String bldNo,
    required String bldNm,
    required String roomNo,
    required String roomNm,
    required String roomAbbt,
    required String instTpCd,
    required String useDate,
    required String endDate,
    required String bgnHour,
    required String bgnMin,
    required String endHour,
    required String endMin,
    required int usePeople,
    required String purpose,
    required String notes,
    required bool notesConfirmed,
    String orgName = '',
    String advisorName = '',
    String outlndAtndncFlag = 'N',
    String cdysmFlag = 'N',
    String lghtFlag = 'N',
    String bmprjtYn = 'N',
    String elecTblUseFlag = 'N',
    String otsdEqmUseFlag = 'N',
    int cbleMicQty = 0,
    int wrlessMicQty = 0,
    String etc = '',
    int maxCapacity = 0,
    int minPeople = 1,
    String elecAprvYn = 'Y',
  }) async {
    _assertInitialized();
    final resp = await _dio.post<Map<String, dynamic>>(
      '/gam/gam/gai/GaiUsmnIua/doSaveInstUseAply.do',
      queryParameters: {'addParam': _apiParam('PSTD00201')},
      data: {
        'dl_main': [
          {
            'rowStatus': 'C',
            'CHECK_ROW': '1',
            'UPD_FLAG': '1',
            'HAK_LINK_YN': 'N',
            'NO': '',
            'PLACE_DIV_CD': 'GAB002001',
            'USE_APPLY_NO': '',
            'FACILITY_NM': '',
            'FACILITY_MNGT_NO': facilityMngtNo,
            'USE_BGN_DT': useDate,
            'USE_END_DT': endDate,
            'USE_BGN_TIME': '',
            'USE_BGN_TIME_1': bgnHour,
            'USE_BGN_TIME_2': bgnMin,
            'USE_FSHTM': '',
            'USE_FSHTM_1': endHour,
            'USE_FSHTM_2': endMin,
            'APPLCNT_DIV_CD': 'COA008001',
            'APPLCNT': _intgUsrNo ?? '',
            'APPLCNT_NM': _userName ?? '',
            'PHONE_1': _phone1 ?? '',
            'PHONE_2': _phone2 ?? '',
            'PHONE_3': _phone3 ?? '',
            'PHONE_NO': '',
            'USE_NMPR': usePeople.toString(),
            'USE_PURP': purpose,
            'PSTN_ASO_NM': orgName,
            'CDYSM_FLAG': cdysmFlag,
            'LGHT_FLAG': lghtFlag,
            'BMPRJT_YN': bmprjtYn,
            'ELEC_TBL_USE_FLAG': elecTblUseFlag,
            'ELEC_TBL_FLAG': '',
            'CBLE_MIC_QTY': cbleMicQty.toString(),
            'WRLESS_MIC_QTY': wrlessMicQty.toString(),
            'CBLE_MIC_QNT': cbleMicQty.toString(),
            'WRLESS_MIC_QNT': wrlessMicQty.toString(),
            'OTSD_EQM_USE_FLAG': otsdEqmUseFlag,
            'ETC': etc,
            'USE_FEE': '0',
            // 강의실 자동승인(ELEC_APRV_YN=Y) 시 GAI041010, 아니면 GAI041001
            'TREAT_STATUS_CD': elecAprvYn == 'Y' ? 'GAI041010' : 'GAI041001',
            'TREAT_STATUS_NM': '',
            'TREAT_STATUS': 'GAI042002',
            'RECA_CAUSE': '',
            'REG_DTTM': '',
            'REG_ID': _intgUsrNo ?? '',
            'CHG_DTTM': '',
            'CHG_ID': _intgUsrNo ?? '',
            'FILE_DETAIL_NO': '',
            'ATTACH_FILE_NO': '',
            'ELEC_DOC_REL_NO': '',
            'OUTLND_ATNDNC_FLAG': outlndAtndncFlag,
            'MATDT_CONF_FLAG': notesConfirmed ? 'Y' : 'N',
            'MATDT': notes,
            'MAP_PROF_NM': advisorName,
            'ELEC_APRV_YN': elecAprvYn,
            'DIRECT_APRV_YN': '',
            'SCH_PROF_OBJ_FLAG': '',
            'USE_DAY': '',
            'BLD_NO': bldNo,
            'BLD_NM': bldNm,
            'ROOM_NM': roomNm,
            'ROOM_ABBT': roomAbbt,
            'ROOM_NO': roomNo,
            'ROOM': '',
            'INST_TP_CD': instTpCd,
            'MAX_ADMT_NMPR': maxCapacity,
            'MIN_USE_NMPR': minPeople,
            'PSTN_DEPT_NO': _deptNo ?? '',
            'PSTN_DEPT_NM': _deptNm ?? '',
          },
        ],
      },
    );

    final error = resp.data?['_SUBMIT_ERROR_'];
    if (error != null) {
      throw Exception(
        (error as Map<String, dynamic>)['ERRMSG']?.toString() ?? '예약 실패',
      );
    }

    final key = resp.data?['dl_main_KEY'] as Map<String, dynamic>?;
    final applyNo = key?['USE_APPLY_NO'] as String?;
    if (applyNo == null || applyNo.isEmpty) {
      throw Exception('신청번호를 받지 못했습니다. 포털에서 확인해주세요.');
    }
    return applyNo;
  }

  /// 예약 취소.
  Future<void> cancelReservation(String useApplyNo) async {
    _assertInitialized();
    final resp = await _dio.post<Map<String, dynamic>>(
      '/gam/gam/gai/GaiUsmnIua/doSaveInstUseAplyCancel.do',
      queryParameters: {'addParam': _apiParam('PSTD00201')},
      data: {
        'dl_main': [
          {'USE_APPLY_NO': useApplyNo, 'RECA_CAUSE': ''},
        ],
      },
    );
    final error = resp.data?['_SUBMIT_ERROR_'];
    if (error != null) {
      throw Exception(
        (error as Map<String, dynamic>)['ERRMSG']?.toString() ?? '취소 실패',
      );
    }
  }

  // ── 점유 슬롯 예약 상세 (신청번호 조회) ────────────────────

  /// 특정 방·날짜의 예약 목록 (doListUseInst.do).
  /// 점유 슬롯 탭 시 신청번호 표시에 사용.
  Future<List<Map<String, dynamic>>> listSlotReservations({
    required String placeDivCd,
    required String bldNo,
    required String roomNo,
    required String bldNm,
    required String roomAbbt,
    required String useDate,
  }) async {
    _assertInitialized();
    final resp = await _dio.post<Map<String, dynamic>>(
      '/gam/gam/gai/GaiPopuInst/doListUseInst.do',
      queryParameters: {'addParam': _apiParam('PSTD00201')},
      data: {
        'dm_search_3': {
          'PLACE_DIV_CD': placeDivCd,
          'BLD_NO': bldNo,
          'ROOM_NO': roomNo,
          'USE_DT_S': useDate,
          'USE_DT_E': useDate,
          'USE_DAY': '',
          'BGN_TIME_HOUR': '09',
          'BGN_TIME_MIN': '00',
          'FSHTM_HOUR': '22',
          'FSHTM_MIN': '00',
          'BLD_NM': bldNm,
          'ROOM_NM': roomAbbt,
          'INST_TP_CD': '',
          'STATUS_DIV_CD': '',
        },
      },
    );
    return _asList(resp.data?['dl_main']);
  }

  // ── 수강내역 (SCH 서브시스템) ─────────────────────────────

  /// 특정 학기 수강내역 — **온라인(e-러닝)·수업일 미등록(봉사 등) 강의까지 전부**
  /// 포함. 시간표 그리드(sjapp `/class-schedule`)는 수업시간 있는 강의만 보여줘
  /// 학점이 누락되므로, 정확한 전체 학점 산정·시간표 외 강의 목록의 출처.
  ///
  /// `/sch/sch/sue/SueReqLesnQ/doList.do` (SCH). 시설예약(GAM)과 달리
  /// `_runSysKey:'SCH'` + 메뉴 pgmKey가 필요하고, 호출 전 **같은 pgmKey로
  /// initUserRole 선행이 필수**(WebSquare 메뉴 권한 init).
  ///
  /// [year] "2025", [smtCd] "10"(1학기)/"20"(2학기)/"11"(여름)/"21"(겨울).
  /// 응답 `dl_main` raw 반환 — 도메인 매핑은 상위 레이어.
  Future<List<Map<String, dynamic>>> listEnrolledCourses({
    required String year,
    required String smtCd,
  }) async {
    _assertInitialized();
    const pgmKey = 'SELF_STUDSELF_SUB_30SELF_MENU_10SueReqLesnQ';
    final nowDt = _formatDt(DateTime.now());
    final stdNo = _intgUsrNo ?? '';

    // 선행: 메뉴 권한 init (GAM listFacilities의 initUserRole과 동형, SCH 버전).
    await _dio.post<void>(
      '/main/sys/UserRole/initUserRole.do',
      queryParameters: {
        'addParam': _encodeAddParam({
          'pbForceLog': 'false',
          '_runPgmKey': pgmKey,
          '_runSysKey': 'SCH',
          '_runIntgUsrNo': stdNo,
          '_runPgLoginDt': nowDt,
          '_runningSejong': _runningSejong ?? '',
          '_runPgPopupUrl': '/cmn/com/comReport.xml',
        }),
      },
    );

    final resp = await _dio.post<Map<String, dynamic>>(
      '/sch/sch/sue/SueReqLesnQ/doList.do',
      queryParameters: {
        'addParam': _encodeAddParam({
          '_runPgmKey': pgmKey,
          '_runSysKey': 'SCH',
          '_runIntgUsrNo': stdNo,
          '_runPgLoginDt': nowDt,
          '_runningSejong': _runningSejong ?? '',
        }),
      },
      options: Options(
        headers: {
          'submissionid': 'mf_tabMainCon_contents_${pgmKey}_body_sub_search',
        },
      ),
      data: {
        'dm_search': {
          'ORGN_CLSF_CD': '20', // 학부
          'STUDENT_NO': stdNo,
          'YEAR_SMT': '$year$smtCd',
          'REQ_LOG_CD': '',
          'CDT': '',
          'CNT': '',
          'YEAR': year,
          'SMT_CD': smtCd,
          'SMT_CD_NM': _smtCdNm(smtCd),
        },
      },
    );
    final data = resp.data ?? const {};
    final list = _asList(data['dl_main']);
    // ignore: avoid_print
    print(
      '[ENROLL] doList std=$stdNo $year$smtCd '
      'status=${resp.statusCode} keys=${data.keys.toList()} '
      'dl_main=${list.length} err=${data['_SUBMIT_ERROR_']}',
    );
    return list;
  }

  static String _smtCdNm(String smtCd) => switch (smtCd) {
    '10' => '1학기',
    '11' => '여름학기',
    '20' => '2학기',
    '21' => '겨울학기',
    _ => '',
  };

  // ── 내부 헬퍼 ────────────────────────────────────────────

  static String _encodeAddParam(Map<String, dynamic> data) {
    final jsonStr = jsonEncode(data);
    final urlEncoded = Uri.encodeComponent(jsonStr);
    return base64.encode(utf8.encode(urlEncoded));
  }

  String _apiParam(String pgmKey) => _encodeAddParam({
    '_runPgmKey': pgmKey,
    '_runSysKey': 'GAM',
    '_runIntgUsrNo': _intgUsrNo ?? '',
    '_runPgLoginDt': _loginDt ?? '',
    '_runningSejong': _runningSejong ?? '',
  });

  void _assertInitialized() {
    if (!isInitialized) throw StateError('SjptClient.initialize() 미호출');
  }

  static String _formatDt(DateTime t) =>
      '${t.year}${_p2(t.month)}${_p2(t.day)}'
      '${_p2(t.hour)}${_p2(t.minute)}${_p2(t.second)}';

  static String _formatPopupTs(DateTime t) =>
      '${_p2(t.hour)}${_p2(t.minute)}${_p2(t.second)}'
      '${t.millisecond.toString().padLeft(3, '0')}';

  static String _p2(int v) => v.toString().padLeft(2, '0');

  List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.cast<Map<String, dynamic>>();
  }
}
