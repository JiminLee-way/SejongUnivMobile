import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/core/ble/ble_scanner.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_aes_cipher.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_api_client.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_credentials_local.dart';
import 'package:sejong_smart_campus/features/ucheck/data/repositories/ucheck_repository_impl.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/attendance_outcome.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/lecture_with_attendance.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_data.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_mobile_info.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_objection.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/repositories/ucheck_repository.dart';
import 'package:sejong_smart_campus/core/demo/demo.dart';

// ─── DI ────────────────────────────────────────────────────────────────

final ucheckApiClientProvider = Provider<UCheckApiClient>(
  (ref) => UCheckApiClient(),
);

final ucheckCredentialsProvider = Provider<UCheckCredentialsLocal>(
  (ref) => UCheckCredentialsLocal(),
);

final ucheckAesCipherProvider = Provider<UCheckAesCipher>(
  (ref) => UCheckAesCipher(),
);

final ucheckRepositoryProvider = Provider<UCheckRepository>((ref) {
  return UCheckRepositoryImpl(
    client: ref.watch(ucheckApiClientProvider),
    credentials: ref.watch(ucheckCredentialsProvider),
    cipher: ref.watch(ucheckAesCipherProvider),
  );
});

final bleScannerProvider = Provider<BleScanner>((ref) => BleScanner());

/// 1초 간격 현재 시각 틱 — 출석 버튼이 윈도우 경계(예: 09:50 열림 / 10:15 마감)를
/// 화면을 띄워둔 채로도 실시간 반영하도록 한다. autoDispose라 U-Check 화면을
/// 벗어나면 타이머가 멈춘다.
final nowTickerProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});

// ─── Data ──────────────────────────────────────────────────────────────

/// UCheck 메인 데이터 — 강의/출결/비콘 화이트리스트.
///
/// `initialize()`가 [UCheckUnauthenticatedException]을 throw하면 UI 측에서
/// AsyncValue.error 분기로 자동 처리 → fallback 로그인 모달.
///
/// **autoDispose 제거**: V2 자동출석이 lifecycle resumed 시 data를 invalidate
/// 후 watch하므로 keep-alive 필요. UCheck 탭 떠나도 메모리 유지 (작은 비용).
final ucheckDataProvider = FutureProvider<UCheckData>((ref) {
  if (ref.watch(demoModeProvider)) return Future.value(demoUCheckData());
  final repo = ref.watch(ucheckRepositoryProvider);
  return repo.initialize();
});

/// 강의별 출결 이력 — DetailScreen 진입 시 fetch (`attendList.do`).
/// family key = lectureNo. autoDispose라 detail 떠나면 메모리 해제.
final ucheckLectureRecordsProvider = FutureProvider.autoDispose
    .family<List<UCheckMobileAttend>, int>((ref, lectureNo) {
      final repo = ref.watch(ucheckRepositoryProvider);
      return repo.getAttendanceHistory(lectureNo);
    });

/// 결석 cell 탭 시 ObjectionSheet 진입에서 watch.
///
/// family key = `(lectureNo, lectureWeek, classNo)` record. autoDispose라 시트
/// 닫히면 메모리 해제.
final ucheckObjectionDetailProvider = FutureProvider.autoDispose
    .family<ObjectionDetailResponse, ObjectionTarget>((ref, target) {
      final repo = ref.watch(ucheckRepositoryProvider);
      return repo.getObjectionDetail(
        lectureNo: target.lectureNo,
        lectureWeek: target.lectureWeek,
        classNo: target.classNo,
      );
    });

/// 이의신청 family key.
class ObjectionTarget {
  const ObjectionTarget({
    required this.lectureNo,
    required this.lectureWeek,
    required this.classNo,
  });

  final int lectureNo;
  final int lectureWeek;
  final int classNo;

  @override
  bool operator ==(Object other) =>
      other is ObjectionTarget &&
      other.lectureNo == lectureNo &&
      other.lectureWeek == lectureWeek &&
      other.classNo == classNo;

  @override
  int get hashCode => Object.hash(lectureNo, lectureWeek, classNo);
}

// ─── AttendCheck command ───────────────────────────────────────────────

/// 출석 체크 흐름 상태 — UI progress bar/결과 UI가 watch.
sealed class AttendCheckState {
  const AttendCheckState();
}

class AttendCheckIdle extends AttendCheckState {
  const AttendCheckIdle();
}

class AttendCheckScanning extends AttendCheckState {
  const AttendCheckScanning({
    required this.startedAtMs,
    required this.timeoutMs,
  });
  final int startedAtMs;
  final int timeoutMs;
}

class AttendCheckResult extends AttendCheckState {
  const AttendCheckResult(this.outcome);
  final AttendanceOutcome outcome;
}

class AttendCheckErrorState extends AttendCheckState {
  const AttendCheckErrorState(this.message);
  final String message;
}

/// 출석 체크 실행기.
///
/// UI 흐름:
/// 1. `start(lecture)` 호출 → BLE 스캔 시작 (`AttendCheckScanning`)
/// 2. 매칭 → `repo.performAttendCheck(lecture, beacon)` → `AttendCheckResult`
/// 3. 타임아웃 → `FailedOutcome("유효 비콘 없음")`
/// 4. 권한 거부/블루투스 off → `AttendCheckErrorState`
///
/// 한 번에 한 강의만 — 새로 호출 시 이전 스캔 자동 cancel.
class AttendCheckCommand extends Notifier<AttendCheckState> {
  StreamSubscription<BleScanState>? _sub;

  @override
  AttendCheckState build() {
    ref.onDispose(() {
      _sub?.cancel();
      ref.read(bleScannerProvider).cancel();
    });
    return const AttendCheckIdle();
  }

  Future<void> start(LectureWithAttendance lecture) async {
    await cancel();
    final scanner = ref.read(bleScannerProvider);
    final repo = ref.read(ucheckRepositoryProvider);

    _sub = scanner
        .scan(
          targetMacs: lecture.beaconAddresses,
          targetLocalNames: lecture.beaconLocalNames,
        )
        .listen((s) async {
          switch (s) {
            case BleScanRunning(:final startedAtMs, :final timeoutMs):
              state = AttendCheckScanning(
                startedAtMs: startedAtMs,
                timeoutMs: timeoutMs,
              );
            case BleScanMatched(:final result):
              try {
                final outcome = await repo.performAttendCheck(
                  lecture: lecture,
                  beacon: result,
                );
                state = AttendCheckResult(outcome);
                // 출석 성공 시 데이터 자동 갱신.
                if (outcome is AttendedOutcome) {
                  ref.invalidate(ucheckDataProvider);
                }
              } on UCheckUnauthenticatedException {
                // 토큰 만료 — 자격증명으로 재발급 후 1회 재시도.
                final ok = await repo.bootstrapFromStoredCredentials();
                if (!ok) {
                  state = const AttendCheckErrorState('인증이 필요해요. 다시 로그인해주세요.');
                  return;
                }
                try {
                  final outcome = await repo.performAttendCheck(
                    lecture: lecture,
                    beacon: result,
                  );
                  state = AttendCheckResult(outcome);
                  if (outcome is AttendedOutcome) {
                    ref.invalidate(ucheckDataProvider);
                  }
                } catch (e) {
                  state = AttendCheckErrorState('출석 처리 실패: $e');
                }
              } catch (e) {
                state = AttendCheckErrorState('출석 처리 실패: $e');
              }
            case BleScanTimeout():
              state = AttendCheckResult(
                FailedOutcome(
                  lectureName: lecture.lecture.curriculumNm,
                  reason: '유효한 비콘을 찾지 못했어요. 강의실 안에서 다시 시도해주세요.',
                ),
              );
            case BleScanPermissionDenied(:final deniedPermissions):
              state = AttendCheckErrorState(
                '권한이 필요해요: ${deniedPermissions.join(", ")}. 설정에서 허용해주세요.',
              );
            case BleScanBluetoothOff():
              state = const AttendCheckErrorState('블루투스를 켜주세요.');
            case BleScanError(:final message):
              state = AttendCheckErrorState(message);
            case BleScanIdle():
              state = const AttendCheckIdle();
          }
        });
  }

  Future<void> cancel() async {
    await _sub?.cancel();
    _sub = null;
    await ref.read(bleScannerProvider).cancel();
    state = const AttendCheckIdle();
  }

  void dismiss() {
    state = const AttendCheckIdle();
  }
}

final attendCheckCommandProvider =
    NotifierProvider<AttendCheckCommand, AttendCheckState>(
      AttendCheckCommand.new,
    );

// ─── Bootstrap (sjapp 로그인 직후 fire-and-forget) ────────────────────

/// sjapp 로그인 직후 같은 자격증명으로 UCheck 토큰까지 발급.
/// AuthStateNotifier가 호출 — 실패해도 sjapp 인증을 막지 않는다.
Future<bool> bootstrapUCheckWithSjappCredentials(
  Ref ref, {
  required String username,
  required String password,
}) async {
  final repo = ref.read(ucheckRepositoryProvider);
  try {
    return await repo.loginWithCredentials(
      username: username,
      password: password,
    );
  } catch (_) {
    return false;
  }
}

/// 부팅 시 (rememberMe + cookie refresh 성공) UCheck도 같이 복원.
Future<bool> bootstrapUCheckFromStorage(Ref ref) async {
  final repo = ref.read(ucheckRepositoryProvider);
  try {
    return await repo.bootstrapFromStoredCredentials();
  } catch (_) {
    return false;
  }
}

// V2 notification 예약은 AutoAttendController.scheduleNotificationsForToday()로
// 옮김 (WidgetRef/Ref 타입 문제 회피).
