import 'package:sejong_smart_campus/core/ble/ble_scanner.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/attendance_outcome.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/lecture_with_attendance.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_data.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_mobile_info.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_objection.dart';

/// UCheck 도메인 진입점. 구현은 `UCheckRepositoryImpl`.
///
/// **인증 모델**: UCheck는 sjapp과 다른 자체 token을 발급한다. 사용자 입장에선
/// 한 번만 로그인하면 되도록 `AuthStateNotifier.login(...)`이 sjapp 로그인
/// 직후 [loginWithCredentials]를 fire-and-forget으로 호출해 secure storage에
/// raw 비밀번호를 보관한다. 부팅 시 (rememberMe) [bootstrapFromStoredCredentials]
/// 가 토큰을 재발급한다.
abstract class UCheckRepository {
  /// 신규 로그인 — sjapp 로그인 직후 동일 자격증명으로 UCheck 토큰 발급 +
  /// secure storage 저장. 실패해도 sjapp 인증을 막지 않는다 (호출자가 try/catch).
  ///
  /// Returns `true`면 성공, `false`면 서버가 거절 (잘못된 비밀번호 등 — 드물게
  /// sjapp/UCheck 비밀번호가 다른 경우. 이때 UCheck 탭은 fallback 모달 노출).
  Future<bool> loginWithCredentials({
    required String username,
    required String password,
  });

  /// 부팅/세션 복원 경로 — secure storage의 자격증명을 읽어 토큰 재발급.
  /// 자격증명이 없으면 false 반환 (호출자는 안전하게 무시).
  Future<bool> bootstrapFromStoredCredentials();

  /// **앱 진입/foreground 복귀마다 호출**되는 전체 세션 갱신.
  ///
  /// 앱 진입 시 세션 상태를 점검하고, 필요하면 단말 등록 후 새 token을 발급한다.
  ///
  /// 잠자기/절전모드 복귀 후 token이 stale되어 초기화가 거절되는 케이스를 방지한다.
  ///
  /// Returns true if 새 token 확보 OK, false면 자격증명 부재/서버 거절.
  Future<bool> refreshSession();

  /// 강의 목록 + 출결 요약 + 비콘 화이트리스트.
  ///
  /// 자격증명이 없으면 [UCheckUnauthenticatedException] throw — UCheckScreen은
  /// 이를 잡아 fallback 로그인 모달을 띄운다.
  Future<UCheckData> initialize();

  /// 출석/지각/결석 상태만 빠르게 동기화 — 출석 성공 직후 호출.
  /// 토큰이 없거나 만료면 자동 재발급 후 재시도.
  Future<UCheckData> refreshAttendanceOnly();

  /// BLE 매칭 결과를 받아 `attendCheck.do` POST → 결과 [AttendanceOutcome].
  Future<AttendanceOutcome> performAttendCheck({
    required LectureWithAttendance lecture,
    required BleMatchResult beacon,
    int attendRequestType = 1, // 1=입실 (V1은 입실만)
  });

  /// 강의별 전체 출결 이력 — `attendList.do`. DetailScreen 진입 시 호출.
  /// 응답은 모바일 형식 (`UCheckMobileAttend`) 리스트.
  Future<List<UCheckMobileAttend>> getAttendanceHistory(int lectureNo);

  /// 결석 cell 탭 시 — 사유 dropdown 채우는 데이터.
  Future<ObjectionDetailResponse> getObjectionDetail({
    required int lectureNo,
    required int lectureWeek,
    required int classNo,
  });

  /// 이의신청 제출. 첨부는 V2 — 지금은 빈 배열 문자열.
  /// 성공 시 true.
  Future<bool> submitObjection({
    required int lectureNo,
    required int lectureWeek,
    required int classNo,
    required String attendType,
    required String objectionCd,
    required String objectionDetail,
  });

  /// 로그아웃 — credentials + token + cookie 모두 제거.
  Future<void> logout();
}
