import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// V2 자동출석 사용자 설정 + 트리거 debounce 보관.
///
/// **분리한 이유**: `UCheckCredentialsLocal`(학번/비밀번호/토큰)과 다른 lifecycle.
/// 자격증명은 로그아웃 시 같이 삭제하지만, 자동출석 토글은 다음 로그인까지
/// 사용자 의도가 유지되어야 자연스럽다.
///
/// ## Keys
///
/// - `ucheck.auto_attend_enabled` — bool, 자동출석 ON/OFF
/// - `ucheck.last_auto_triggered_at_ms` — 마지막 자동출석 시도 epoch ms.
///   30초 cooldown으로 중복 트리거 차단 (앱 빠르게 닫았다 다시 열기 등).
/// - `ucheck.last_attended_lecture_no` — 마지막 출석 성공한 lecture_no.
///   같은 강의 시간대 안에서 다시 트리거되어도 silent skip.
class UCheckSettingsLocal {
  UCheckSettingsLocal()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _storage;

  static const _kAutoAttendEnabled = 'ucheck.auto_attend_enabled';
  static const _kLastTriggeredAt = 'ucheck.last_auto_triggered_at_ms';
  static const _kLastAttendedLecture = 'ucheck.last_attended_lecture_no';
  // 신규 알림 토글 — 자동출석과 독립. 기본값:
  //  attend_open ON (학생이 가장 자주 원하는 알림)
  //  class_start OFF (10분 차이로 attend_open과 둘 다 켜면 시끄러움)
  static const _kNotifyAttendOpen = 'ucheck.notify_attend_open_enabled';
  static const _kNotifyClassStart = 'ucheck.notify_class_start_enabled';

  /// 기본값 **true** — 첫 실행부터 자동출석 ON. 사용자가 명시적으로 끄지
  /// 않는 한 동작한다. 미설정(null)=ON, 'false'만 OFF (attend_open 알림과 동일
  /// 패턴). 필요한 BLE/위치/알림 권한은 AppShell 콜드부트에서 매 실행 요청.
  Future<bool> readAutoAttendEnabled() async {
    final v = await _storage.read(key: _kAutoAttendEnabled);
    return v != 'false';
  }

  Future<void> writeAutoAttendEnabled(bool value) =>
      _storage.write(key: _kAutoAttendEnabled, value: value ? 'true' : 'false');

  /// 마지막 자동출석 시도 epoch ms. 없으면 0.
  Future<int> readLastTriggeredAtMs() async {
    final raw = await _storage.read(key: _kLastTriggeredAt);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> writeLastTriggeredAtMs(int ms) =>
      _storage.write(key: _kLastTriggeredAt, value: ms.toString());

  /// 마지막 출석 성공한 lecture_no (같은 강의 시간대 silent skip용).
  Future<int> readLastAttendedLectureNo() async {
    final raw = await _storage.read(key: _kLastAttendedLecture);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> writeLastAttendedLectureNo(int lectureNo) =>
      _storage.write(key: _kLastAttendedLecture, value: lectureNo.toString());

  /// 로그아웃 시 호출 — 자동출석 토글은 보존, debounce/last-attended는 초기화.
  Future<void> clearTriggerState() async {
    await _storage.delete(key: _kLastTriggeredAt);
    await _storage.delete(key: _kLastAttendedLecture);
  }

  /// 출석 시간 시작 알림 ON/OFF — 기본 true.
  Future<bool> readAttendOpenNotifEnabled() async {
    final v = await _storage.read(key: _kNotifyAttendOpen);
    // 미설정(null) 기본값 = true
    return v != 'false';
  }

  Future<void> writeAttendOpenNotifEnabled(bool value) =>
      _storage.write(key: _kNotifyAttendOpen, value: value ? 'true' : 'false');

  /// 수업 시작 정각 알림 ON/OFF — 기본 false.
  Future<bool> readClassStartNotifEnabled() async {
    final v = await _storage.read(key: _kNotifyClassStart);
    return v == 'true';
  }

  Future<void> writeClassStartNotifEnabled(bool value) =>
      _storage.write(key: _kNotifyClassStart, value: value ? 'true' : 'false');
}
