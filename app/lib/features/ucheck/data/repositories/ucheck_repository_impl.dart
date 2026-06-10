import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:sejong_smart_campus/core/ble/ble_scanner.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_aes_cipher.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_api_client.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_credentials_local.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/attendance_outcome.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/lecture_with_attendance.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_data.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_lecture.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_mobile_info.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_objection.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/repositories/ucheck_repository.dart';

class UCheckRepositoryImpl implements UCheckRepository {
  UCheckRepositoryImpl({
    required this.client,
    required this.credentials,
    required this.cipher,
  });

  final UCheckApiClient client;
  final UCheckCredentialsLocal credentials;
  final UCheckAesCipher cipher;

  static const String _deviceModel = String.fromEnvironment(
    'UCHECK_DEVICE_MODEL',
    defaultValue: 'Android',
  );
  static const String _clientVersion = String.fromEnvironment(
    'UCHECK_CLIENT_VERSION',
    defaultValue: '1',
  );

  // ─── Device 메타 ─────────────────────────────────────────────────────
  // 서버는 dedup/로깅용으로만 사용 — 실제 값 검증 X. V2에서 device_info_plus
  // 도입 시 native 값으로 교체.

  /// `mosTriple` = `"$os;$model;$version"`.
  String _mosTriple() {
    final osMajor = _androidMajor();
    return '$osMajor;$_deviceModel;$_clientVersion';
  }

  /// `Platform.operatingSystemVersion`에서 major 추출.
  /// "Android 16 (API 36)" → "16"
  String _androidMajor() {
    try {
      final v = Platform.operatingSystemVersion;
      final m = RegExp(r'\d+').firstMatch(v);
      return m?.group(0) ?? '16';
    } catch (_) {
      return '16';
    }
  }

  /// `model_name` Base64.
  String _modelNameB64() => base64.encode(utf8.encode(_deviceModel));

  /// `device_id` — ANDROID_ID 형식 (16 hex char) per-install stable.
  ///
  /// Flutter에서 native 호출 없이 가져올 수 없으니 username 기반 stable
  /// 16-hex로 대체.
  Future<String> _deviceId() async {
    final u = await credentials.readUsername();
    final seed = (u == null || u.isEmpty) ? 'flutter-device' : u;
    return _toHex16('$seed-sjapp-ucheck-device-v1');
  }

  /// 16-hex char (= ANDROID_ID 같은 형식) deterministic hash.
  String _toHex16(String input) {
    var h1 = 0x12345678;
    var h2 = 0x87654321;
    for (final c in input.codeUnits) {
      h1 = ((h1 << 5) + h1 + c) & 0xffffffff;
      h2 = ((h2 << 3) + h2 ^ c) & 0xffffffff;
    }
    return h1.toRadixString(16).padLeft(8, '0').substring(0, 8) +
        h2.toRadixString(16).padLeft(8, '0').substring(0, 8);
  }

  // ─── Auth ────────────────────────────────────────────────────────────

  @override
  Future<bool> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    try {
      await credentials.saveCredentials(username: username, password: password);
      final ok = await _acquireToken(username: username, password: password);
      return ok;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> bootstrapFromStoredCredentials() async {
    final u = await credentials.readUsername();
    final p = await credentials.readPassword();
    if (u == null || u.isEmpty || p == null || p.isEmpty) {
      return false;
    }
    // 토큰이 있으면 일단 유지 — initialize에서 만료 시 재발급.
    final existing = await credentials.readToken();
    if (existing != null && existing.isNotEmpty) return true;
    return await _acquireToken(username: u, password: p);
  }

  @override
  Future<bool> refreshSession() async {
    final u = await credentials.readUsername();
    final p = await credentials.readPassword();
    if (u == null || u.isEmpty || p == null || p.isEmpty) {
      dev.log('[UCheck] refreshSession: credentials 없음 → skip');
      return false;
    }

    final existing = await credentials.readToken();

    // Step 1: 기존 token이 있으면 refreshToken.do 먼저 시도 (서버 사이드 fast path).
    if (existing != null && existing.isNotEmpty) {
      try {
        final body = await client.refreshMobileToken(token: existing);
        final result = (body['result'] as num?)?.toInt() ?? 0;
        if (result == 1) {
          final value = body['value'];
          if (value is Map<String, dynamic>) {
            final newToken = value['token'] as String?;
            if (newToken != null && newToken.isNotEmpty) {
              await credentials.saveToken(newToken);
              dev.log('[UCheck] refreshSession: refreshToken OK');
              return true;
            }
          }
        }
        // result=0 (tokeninvalid) → 아래 phoneInit + getToken fallback
        dev.log(
          '[UCheck] refreshSession: refreshToken 실패 → phoneInit fallback',
        );
      } catch (e) {
        dev.log(
          '[UCheck] refreshSession: refreshToken exception → phoneInit fallback: $e',
        );
      }
    }

    // Step 2 + 3: phoneInit + getToken.
    return await _acquireToken(username: u, password: p);
  }

  /// phoneInit + getToken을 페어로 호출.
  ///
  /// 1. `phoneInit.do` — 단말 등록 (idempotent)
  /// 2. `getToken.do` → 새 token
  ///
  /// 매 호출이 깨끗한 session_id (새 JSESSIONID)로 진행되며 서버는 phoneInit를
  /// 호출 횟수에 관계없이 멱등으로 처리한다. 첫 로그인이든, 매번 진입이든,
  /// 잠자기 복귀든 모두 동일.
  Future<bool> _acquireToken({
    required String username,
    required String password,
  }) async {
    final idHex = cipher.encryptDaily(username);
    final pwdHex = cipher.encryptDaily(password);
    final maddr = await _deviceId();

    // Step 1: phoneInit.do — 단말 등록 (필수)
    try {
      final phoneInitResp = await client.phoneInit(
        idHex: idHex,
        pwdHex: pwdHex,
        maddr: maddr,
      );
      final phoneInitResult = (phoneInitResp['result'] as num?)?.toInt() ?? 0;
      if (phoneInitResult != 1) {
        dev.log(
          '[UCheck] _acquireToken: phoneInit 비정상 응답 (result=$phoneInitResult), getToken 진행',
        );
      }
    } catch (e) {
      dev.log('[UCheck] _acquireToken: phoneInit 예외 → getToken 진행: $e');
    }

    // Step 2: getToken.do — 토큰 발급
    final body = await client.acquireMobileToken(
      idHex: idHex,
      pwdHex: pwdHex,
      maddr: maddr,
      mos: _mosTriple(),
    );

    final result = (body['result'] as num?)?.toInt() ?? 0;
    if (result == 1) {
      final value = body['value'];
      if (value is Map<String, dynamic>) {
        final token = value['token'] as String?;
        if (token != null && token.isNotEmpty) {
          await credentials.saveToken(token);
          dev.log('[UCheck] _acquireToken: 새 token 저장 성공');
          return true;
        }
      }
      dev.log('[UCheck] _acquireToken: getToken result=1이지만 token 추출 실패');
      return false;
    }

    final code = body['value']?.toString() ?? '';
    dev.log('[UCheck] _acquireToken: getToken 실패 — value=$code');
    return false;
  }

  // ─── Data load ───────────────────────────────────────────────────────

  @override
  Future<UCheckData> initialize() async {
    // 매번 진입마다 refreshSession (사용자 요구) — phoneInit + getToken으로
    // 토큰 재발급. 잠자기/절전 복귀에도 동일한 흐름.
    final refreshed = await refreshSession();
    if (!refreshed) {
      throw const UCheckUnauthenticatedException();
    }
    final token = await credentials.readToken();
    if (token == null || token.isEmpty) {
      throw const UCheckUnauthenticatedException();
    }

    final body = await client.getMobileInfo(
      token: token,
      deviceId: await _deviceId(),
      modelNameB64: _modelNameB64(),
      mobileOs: _androidMajor(),
    );
    return _parseMobileInfo(body);
  }

  @override
  Future<UCheckData> refreshAttendanceOnly() async {
    // V1 단순화: initialize와 동일 — last_update_date 기반 incremental은 V1.1.
    return initialize();
  }

  /// 토큰 확보. credentials 있으면 reuse, 없으면 throw.
  Future<String> _ensureToken() async {
    final existing = await credentials.readToken();
    if (existing != null && existing.isNotEmpty) return existing;
    // 토큰이 없으면 stored credentials로 재발급 시도.
    final ok = await bootstrapFromStoredCredentials();
    if (!ok) {
      throw const UCheckUnauthenticatedException();
    }
    final fresh = await credentials.readToken();
    if (fresh == null || fresh.isEmpty) {
      throw const UCheckUnauthenticatedException();
    }
    return fresh;
  }

  /// `getMobileInfo.do` 응답 → [UCheckData].
  ///
  /// 토큰 만료 (`tokeninvalid`/`incorrect_phone`) 시 1회 재발급 후 재시도.
  Future<UCheckData> _parseMobileInfo(Map<String, dynamic> body) async {
    final result = (body['result'] as num?)?.toInt() ?? 0;
    if (result != 1) {
      final code = body['value']?.toString() ?? '';
      if (code.contains('tokeninvalid')) {
        await credentials.clearToken();
        throw const UCheckUnauthenticatedException();
      }
      throw UCheckApiException('getInfo 실패: $code');
    }

    // version.key 저장 — attendCheck memo 암호화에 사용.
    final info = UCheckMobileInfo.fromJson(body);
    final versionKey = info.version?.key;
    if (versionKey != null && versionKey.isNotEmpty) {
      await credentials.saveIntroImage2(versionKey);
    }

    // 모바일 강의 → LectureWithAttendance 머지. attendCheck.do payload에
    // 필요한 모든 mobile context를 보존한다.
    final lectures = info.allLectures
        .map(
          (m) => LectureWithAttendance(
            lecture: _mobileToLecture(m),
            records: const [],
            beaconAddresses: _dedup(m.beaconMacAddresses),
            beaconLocalNames: _dedup(m.localName),
            apType: m.apType,
            attendSmin: m.attendSmin,
            attendEmin: m.attendEmin,
            laterMin: m.laterMin,
            classNo: m.classNo,
            roomCd: m.roomCd,
            roomNm: m.roomNm,
            curWeek: m.curWeek,
            totalWeek: m.totalWeek,
            startTime: m.startTime,
            endTime: m.endTime,
            dayWeek: m.dayWeek,
            stateCdAttend: m.stateCdAttend,
            lectureType: m.lectureType,
            outCheckYn: m.outCheckYn,
            attendUseYn: m.attendUseYn,
          ),
        )
        .toList();

    final currentWeek = info.weekdownyn.isNotEmpty
        ? info.weekdownyn.first.curWeek
        : (info.allLectures.isNotEmpty ? info.allLectures.first.curWeek : 0);
    final totalWeeks = info.weekdownyn.isNotEmpty
        ? info.weekdownyn.first.totalWeek
        : (info.allLectures.isNotEmpty ? info.allLectures.first.totalWeek : 16);

    return UCheckData(
      studentName: '', // V1: currentUserProvider에서 표시
      currentWeek: currentWeek,
      totalWeeks: totalWeeks,
      lectures: lectures,
    );
  }

  /// `UCheckMobileLecture` → `UCheckLecture` (UI에서 일관된 단위 사용).
  UCheckLecture _mobileToLecture(UCheckMobileLecture m) {
    return UCheckLecture(
      lectureNo: m.lectureNo,
      curriculumCd: m.curriculumCd,
      curriculumNm: m.curriculumNm,
      teacherNm: m.teacherNm,
    );
  }

  /// 중복된 비콘 힌트를 dedup해서 화이트리스트 효율화.
  List<String> _dedup(List<String> input) {
    final seen = <String>{};
    final out = <String>[];
    for (final s in input) {
      if (s.isEmpty) continue;
      if (seen.add(s)) out.add(s);
    }
    return out;
  }

  // ─── attendCheck ─────────────────────────────────────────────────────

  @override
  Future<AttendanceOutcome> performAttendCheck({
    required LectureWithAttendance lecture,
    required BleMatchResult beacon,
    int attendRequestType = 1,
  }) async {
    final token = await _ensureToken();

    // memo: 출석 시각 평문 → AES(version.key)
    final introImage2 = await credentials.readIntroImage2() ?? '';
    final now = DateTime.now();
    final memoPlain =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final memoHex = introImage2.isEmpty
        ? '' // intro_image2가 없으면 빈 memo — 서버가 거절할 수 있음 (강제 재초기화 필요)
        : cipher.encryptWithServerKey(memoPlain, introImage2);

    // is_correct_mac 판정:
    // - 비콘 MAC이 화이트리스트에 있으면 'Y'
    // - localName이 'P_' 시작이면 'Y'
    // - 그 외 'N', 화이트리스트가 비었으면 'U'
    String isCorrectMac;
    if (lecture.beaconAddresses.isEmpty && lecture.beaconLocalNames.isEmpty) {
      isCorrectMac = 'U';
    } else {
      final normalized = beacon.macAddress.replaceAll('-', ':').toUpperCase();
      final whitelist = lecture.beaconAddresses
          .map((m) => m.replaceAll('-', ':').toUpperCase())
          .toSet();
      isCorrectMac =
          whitelist.contains(normalized) || beacon.localName.startsWith('P_')
          ? 'Y'
          : 'N';
    }

    // 서버가 기대하는 정규화 형식에 맞춰 BLE/강의 필드를 전달한다.
    final body = await client.attendCheck(
      token: token,
      lectureNo: lecture.lecture.lectureNo,
      classNo: lecture.classNo,
      roomCd: lecture.roomCd,
      lectureWeek: lecture.curWeek,
      lectureType: lecture.lectureType,
      attendRequestType: attendRequestType,
      apType: lecture.apType.isEmpty ? 'B' : lecture.apType,
      localName: beacon.localName,
      bcMaddr40: beacon.macAddress.replaceAll('-', ':').toUpperCase(),
      rssi: beacon.rssi,
      bcUuid40: beacon.iBeacon?.uuid.toUpperCase(),
      bcMajor40: beacon.iBeacon?.major,
      bcMinor40: beacon.iBeacon?.minor,
      txPower: beacon.iBeacon?.txPower ?? -16,
      memoCipherHex: memoHex,
      isCorrectMac: isCorrectMac,
    );

    return _mapAttendResult(body, lecture.lecture.curriculumNm);
  }

  AttendanceOutcome _mapAttendResult(Map<String, dynamic> body, String name) {
    final result = (body['result'] as num?)?.toInt() ?? 0;
    final attendType = body['attend_type'];
    switch (result) {
      case 1:
        // attendType 1=출석/4=인증=출석, 2=지각.
        final isLate = attendType is num && attendType.toInt() == 2;
        return AttendedOutcome(lectureName: name, isLate: isLate);
      case 2:
        return AlreadyAttendedOutcome(lectureName: name);
      case 3:
        return OutOfWindowOutcome(
          lectureName: name,
          classNo: 0,
          startEpochMillis: 0,
          endEpochMillis: 0,
          reasonKor: '아직 출석 가능 시간이 아니에요',
          nowEpochMillis: DateTime.now().millisecondsSinceEpoch,
        );
      default:
        final code = body['value']?.toString() ?? '';
        if (code.contains('tokeninvalid')) {
          // 호출자가 재시도하도록 throw — UI는 자동 재로그인 후 retry
          throw const UCheckUnauthenticatedException();
        }
        return FailedOutcome(
          lectureName: name,
          reason: code.isEmpty ? '서버 응답 오류' : '서버 거절: $code',
        );
    }
  }

  @override
  Future<List<UCheckMobileAttend>> getAttendanceHistory(int lectureNo) async {
    final token = await _ensureToken();
    final body = await client.getMobileAttendList(
      token: token,
      lectureNo: lectureNo,
    );
    final list = UCheckMobileAttendList.fromJson(body);
    return list.value;
  }

  // ─── Objection ───────────────────────────────────────────────────────

  @override
  Future<ObjectionDetailResponse> getObjectionDetail({
    required int lectureNo,
    required int lectureWeek,
    required int classNo,
  }) async {
    final token = await _ensureToken();
    final body = await client.getObjectionDetail(
      token: token,
      lectureNo: lectureNo,
      lectureWeek: lectureWeek,
      classNo: classNo,
    );
    return ObjectionDetailResponse.fromJson(body);
  }

  @override
  Future<bool> submitObjection({
    required int lectureNo,
    required int lectureWeek,
    required int classNo,
    required String attendType,
    required String objectionCd,
    required String objectionDetail,
  }) async {
    final token = await _ensureToken();
    final body = await client.submitObjection(
      token: token,
      lectureNo: lectureNo,
      lectureWeek: lectureWeek,
      classNo: classNo,
      attendType: attendType,
      objectionCd: objectionCd,
      objectionDetail: objectionDetail,
    );
    final result = (body['result'] as num?)?.toInt() ?? 0;
    return result == 1;
  }

  // ─── Logout ──────────────────────────────────────────────────────────

  @override
  Future<void> logout() async {
    await credentials.clear();
    await client.clearSession();
  }
}
