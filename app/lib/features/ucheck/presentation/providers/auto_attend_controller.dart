import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/core/ble/ble_scanner.dart';
import 'package:sejong_smart_campus/features/holidays/presentation/providers/holiday_providers.dart';
import 'package:sejong_smart_campus/features/ucheck/data/datasources/ucheck_notifications.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/attendance_outcome.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/lecture_with_attendance.dart';
import 'package:sejong_smart_campus/features/ucheck/domain/entities/ucheck_data.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/auto_attend_settings_provider.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/ucheck_providers.dart';

/// V2 자동출석 결과 — UI overlay/snackbar가 watch.
sealed class AutoAttendStatus {
  const AutoAttendStatus();
}

class AutoAttendIdle extends AutoAttendStatus {
  const AutoAttendIdle();
}

class AutoAttendDisabled extends AutoAttendStatus {
  const AutoAttendDisabled();
}

class AutoAttendNoEligible extends AutoAttendStatus {
  const AutoAttendNoEligible();
}

class AutoAttendSkipDebounce extends AutoAttendStatus {
  const AutoAttendSkipDebounce();
}

class AutoAttendAlreadyAttended extends AutoAttendStatus {
  const AutoAttendAlreadyAttended(this.lectureName);
  final String lectureName;
}

class AutoAttendScanning extends AutoAttendStatus {
  const AutoAttendScanning(this.lectureName);
  final String lectureName;
}

class AutoAttendDone extends AutoAttendStatus {
  const AutoAttendDone(this.outcome);
  final AttendanceOutcome outcome;
}

class AutoAttendError extends AutoAttendStatus {
  const AutoAttendError(this.message);
  final String message;
}

/// V2 자동출석 진입점 — 사용자가 앱을 켜는 모든 순간 호출되는 단일 funnel.
///
/// 호출 위치:
/// 1. `AuthGate` 인증 성공 직후 (콜드부트)
/// 2. `AppShell.didChangeAppLifecycleState(resumed)` (background→foreground)
/// 3. notification 탭으로 launch된 경우 (deeplink)
/// 4. 사용자가 UCheck 탭 우상단 "지금 출석" 버튼 누름
///
/// ## 알고리즘
///
/// ```
/// 1. autoAttendEnabled? false면 idle 종료
/// 2. lastTriggeredAt 30초 이내면 silent skip
/// 3. ucheckDataProvider 강제 invalidate + 새 data fetch (refreshSession 자동 호출)
/// 4. data.lectures 중 (now ∈ [start-Smin, start+Emin+laterMin] && stateCdAttend == 0)
/// 5. 매칭 0개 → 종료
/// 6. 매칭 ≥1개 → 가장 가까운 시작 시각 1개 = primary
///    나머지 → reminder notification ("자료구조도 출석체크 시간이에요")
/// 7. lastAttendedLectureNo == primary.lectureNo면 already-handled silent skip
/// 8. BLE 스캔 (첫 매칭 시 즉시 중단) — V1 BleScanner 그대로
/// 9. 비콘 매칭 → repo.performAttendCheck(primary, beacon)
///    - 성공 → showResult notification + ucheckDataProvider invalidate + lastAttendedLectureNo 저장
///    - 실패/타임아웃 → showReminder + 인앱 안내
/// ```
class AutoAttendController extends Notifier<AutoAttendStatus> {
  static const Duration debounceWindow = Duration(seconds: 30);
  static const Duration scanTimeout = Duration(seconds: 10);

  Completer<void>? _inFlight;

  @override
  AutoAttendStatus build() => const AutoAttendIdle();

  /// 외부 트리거 진입점. 동시에 여러 곳에서 호출돼도 in-flight 1회만 실행.
  Future<void> checkAndTrigger({String reason = 'unknown'}) async {
    if (_inFlight != null) {
      dev.log('[AutoAttend] checkAndTrigger($reason): 진행 중 — skip');
      return _inFlight!.future;
    }
    final c = Completer<void>();
    _inFlight = c;
    try {
      await _run(reason: reason);
    } finally {
      _inFlight = null;
      c.complete();
    }
  }

  Future<void> _run({required String reason}) async {
    dev.log('[AutoAttend] _run start reason=$reason');

    // 1. 자동출석 토글 확인
    final settings = ref.read(ucheckSettingsLocalProvider);
    final enabled = await settings.readAutoAttendEnabled();
    if (!enabled) {
      dev.log('[AutoAttend] disabled — skip');
      state = const AutoAttendDisabled();
      return;
    }

    // 2. debounce
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = await settings.readLastTriggeredAtMs();
    final elapsed = nowMs - lastMs;
    if (elapsed < debounceWindow.inMilliseconds) {
      dev.log(
        '[AutoAttend] debounce skip (elapsed ${elapsed}ms < ${debounceWindow.inMilliseconds}ms)',
      );
      state = const AutoAttendSkipDebounce();
      return;
    }
    await settings.writeLastTriggeredAtMs(nowMs);

    // 3. UCheck data 강제 refresh (refreshSession + getInfo 자동)
    UCheckData data;
    try {
      ref.invalidate(ucheckDataProvider);
      data = await ref.read(ucheckDataProvider.future);
    } catch (e) {
      dev.log('[AutoAttend] data fetch 실패: $e');
      state = AutoAttendError('출결 정보 조회 실패: $e');
      return;
    }

    // 4-6. eligible 강의 매칭
    final now = DateTime.now();
    final eligible = _findEligible(data.lectures, now);
    if (eligible.isEmpty) {
      dev.log('[AutoAttend] eligible 강의 0 — skip');
      state = const AutoAttendNoEligible();
      return;
    }

    final primary = eligible.first;
    final secondary = eligible.skip(1).toList();

    // 보조 강의는 reminder notification만 (사용자가 직접 시도)
    for (final s in secondary) {
      unawaited(
        UCheckNotifications.instance.showReminder(
          lectureNo: s.lecture.lectureNo,
          title: '출석 시간이에요: ${s.lecture.curriculumNm}',
          body: '앱에서 수동으로 출석 체크를 진행해주세요',
        ),
      );
    }

    // 7. 이미 출석 처리됨?
    if (primary.stateCdAttend != 0) {
      dev.log(
        '[AutoAttend] primary 이미 출석됨 (stateCdAttend=${primary.stateCdAttend})',
      );
      state = AutoAttendAlreadyAttended(primary.lecture.curriculumNm);
      return;
    }
    final lastAttended = await settings.readLastAttendedLectureNo();
    if (lastAttended == primary.lecture.lectureNo) {
      // 같은 강의 같은 trigger window 안에서 이미 우리 코드가 출석 처리한 경우
      dev.log('[AutoAttend] primary 같은 lecture 이미 처리됨');
      state = AutoAttendAlreadyAttended(primary.lecture.curriculumNm);
      return;
    }

    // 비콘 정보 없으면 자동출석 불가
    if (primary.beaconAddresses.isEmpty && primary.beaconLocalNames.isEmpty) {
      unawaited(
        UCheckNotifications.instance.showReminder(
          lectureNo: primary.lecture.lectureNo,
          title: '비콘 정보 없음: ${primary.lecture.curriculumNm}',
          body: '이 강의는 자동출석이 어려워요. 수동으로 시도해주세요',
        ),
      );
      state = AutoAttendError('비콘 정보 없음');
      return;
    }

    // 8. BLE 스캔 — 첫 매칭 시 즉시 중단 (V1 BleScanner 그대로)
    state = AutoAttendScanning(primary.lecture.curriculumNm);
    final scanner = ref.read(bleScannerProvider);
    BleMatchResult? matched;
    final completer = Completer<void>();
    StreamSubscription<BleScanState>? sub;
    sub = scanner
        .scan(
          targetMacs: primary.beaconAddresses,
          targetLocalNames: primary.beaconLocalNames,
          timeout: scanTimeout,
        )
        .listen((s) {
          switch (s) {
            case BleScanMatched(:final result):
              matched = result;
              if (!completer.isCompleted) completer.complete();
            case BleScanTimeout():
              if (!completer.isCompleted) completer.complete();
            case BleScanPermissionDenied(:final deniedPermissions):
              dev.log('[AutoAttend] BLE 권한 거부: $deniedPermissions');
              if (!completer.isCompleted) completer.complete();
            case BleScanBluetoothOff():
              dev.log('[AutoAttend] Bluetooth OFF');
              if (!completer.isCompleted) completer.complete();
            case BleScanError(:final message):
              dev.log('[AutoAttend] BLE 에러: $message');
              if (!completer.isCompleted) completer.complete();
            case BleScanRunning():
            case BleScanIdle():
              break;
          }
        });
    await completer.future;
    await sub.cancel();

    if (matched == null) {
      dev.log('[AutoAttend] 비콘 매칭 실패');
      unawaited(
        UCheckNotifications.instance.showReminder(
          lectureNo: primary.lecture.lectureNo,
          title: '강의실 비콘을 찾지 못했어요',
          body: '${primary.lecture.curriculumNm} — 강의실 안에서 다시 시도해주세요',
        ),
      );
      state = AutoAttendDone(
        FailedOutcome(
          lectureName: primary.lecture.curriculumNm,
          reason: '비콘 매칭 실패',
        ),
      );
      return;
    }

    // 9. attendCheck.do 호출
    final repo = ref.read(ucheckRepositoryProvider);
    AttendanceOutcome outcome;
    try {
      outcome = await repo.performAttendCheck(
        lecture: primary,
        beacon: matched!,
      );
    } catch (e) {
      dev.log('[AutoAttend] attendCheck 예외: $e');
      state = AutoAttendError('출석 처리 실패: $e');
      return;
    }

    // 결과별 notification + state
    switch (outcome) {
      case AttendedOutcome(:final isLate):
        await settings.writeLastAttendedLectureNo(primary.lecture.lectureNo);
        unawaited(
          UCheckNotifications.instance.showResult(
            lectureNo: primary.lecture.lectureNo,
            title: isLate ? '지각 처리됨' : '출석 완료!',
            body: primary.lecture.curriculumNm,
          ),
        );
        // 출석부 즉시 새로고침 (사용자 요구)
        ref.invalidate(ucheckDataProvider);
      case AlreadyAttendedOutcome():
        await settings.writeLastAttendedLectureNo(primary.lecture.lectureNo);
      // silent — 이미 출석된 거니 알림 안 띄움
      case OutOfWindowOutcome(:final reasonKor):
        unawaited(
          UCheckNotifications.instance.showReminder(
            lectureNo: primary.lecture.lectureNo,
            title: '출석 시간 외',
            body: '${primary.lecture.curriculumNm} — $reasonKor',
          ),
        );
      case FailedOutcome(:final reason):
        unawaited(
          UCheckNotifications.instance.showReminder(
            lectureNo: primary.lecture.lectureNo,
            title: '자동출석 실패',
            body: '${primary.lecture.curriculumNm} — $reason',
          ),
        );
      case CooldownOutcome():
      case NoEligibleLectureOutcome():
        break;
    }
    state = AutoAttendDone(outcome);
  }

  /// 현재 시각이 강의 출석 윈도우 안에 들어가는 강의들 — 가까운 시작 순 정렬.
  /// 윈도우 판단은 출석 버튼과 동일한 SSOT([AttendWindowX])를 사용한다 —
  /// 두 경로가 절대 어긋나지 않게.
  List<LectureWithAttendance> _findEligible(
    List<LectureWithAttendance> lectures,
    DateTime now,
  ) {
    final results = <(int diff, LectureWithAttendance lec)>[];
    for (final l in lectures) {
      if (!l.isAttendOpenAt(now)) continue; // 오늘 요일 + 윈도우 안 모두 포함
      final start = l.startDateTimeOn(now);
      if (start == null) continue; // isAttendOpenAt가 이미 걸러내지만 방어적.
      final diff = now.difference(start).inMinutes.abs();
      results.add((diff, l));
    }
    results.sort((a, b) => a.$1.compareTo(b.$1));
    return results.map((r) => r.$2).toList();
  }

  void dismiss() {
    state = const AutoAttendIdle();
  }

  /// 오늘 강의 모두에 대해 "강의 시작 10분 전 UCheck!" notification 예약.
  ///
  /// 호출 시점:
  /// - 자동출석 토글 ON 직후
  /// - lifecycle resumed 후 ucheck data 갱신 직후
  /// - 콜드부트 후 첫 진입 직후
  ///
  /// **idempotent** — 같은 lectureNo 기반 id로 zonedSchedule 재호출 시 덮어쓰기.
  /// 자동출석 OFF면 기존 예약 모두 cancel.
  Future<void> scheduleNotificationsForToday() async {
    final settings = ref.read(ucheckSettingsLocalProvider);
    final enabled = await settings.readAutoAttendEnabled();
    final notif = UCheckNotifications.instance;

    UCheckData data;
    try {
      data = await ref.read(ucheckDataProvider.future);
    } catch (_) {
      return;
    }

    if (!enabled) {
      await notif.cancelAllPreClass(
        data.lectures.map((l) => l.lecture.lectureNo).toList(),
      );
      return;
    }

    final now = DateTime.now();
    final todayDayWeek = ucheckDayWeek(now);
    for (final l in data.lectures) {
      if (l.dayWeek.isNotEmpty && l.dayWeek != todayDayWeek) continue;
      if (l.stateCdAttend != 0) continue;
      final start = l.startDateTimeOn(now);
      if (start == null) continue;
      final fireAt = start.subtract(const Duration(minutes: 10));
      if (fireAt.isBefore(now)) continue;
      await notif.schedulePreClass(
        lectureNo: l.lecture.lectureNo,
        lectureName: l.lecture.curriculumNm,
        whenKst: fireAt,
      );
    }
  }

  /// 자동출석과 **독립적인** 두 알림(출석 시간 시작 / 수업 정각)을 향후
  /// [scheduleHorizonDays]일치 미리 예약.
  ///
  /// 호출 시점: 앱 콜드부트, lifecycle resume, 토글 변경 시.
  /// idempotent — 매번 7일치 cancel 후 다시 schedule하므로 중복/누락 위험 X.
  ///
  /// 공휴일(`koreanHolidaysProvider`)에 해당하는 날짜는 skip. 두 토글이 모두
  /// OFF면 단지 cancel만 수행하고 종료.
  static const int scheduleHorizonDays = 7;

  Future<void> scheduleClassReminders() async {
    final notif = UCheckNotifications.instance;
    final settings = ref.read(ucheckSettingsLocalProvider);
    final attendOpenOn = await settings.readAttendOpenNotifEnabled();
    final classStartOn = await settings.readClassStartNotifEnabled();

    UCheckData data;
    try {
      data = await ref.read(ucheckDataProvider.future);
    } catch (_) {
      return;
    }
    final lectureNos = data.lectures.map((l) => l.lecture.lectureNo).toList();

    // 매번 7일치 cancel — 시간표/공휴일 변경에 대응.
    await notif.cancelAttendOpenRange(lectureNos, scheduleHorizonDays);
    await notif.cancelClassStartRange(lectureNos, scheduleHorizonDays);

    if (!attendOpenOn && !classStartOn) return;

    final now = DateTime.now();
    // 공휴일 — 같은 년도 + 다음 년도 같이 fetch (연말 7일 윈도우 대비).
    final years = <int>{
      now.year,
      now.add(Duration(days: scheduleHorizonDays)).year,
    };
    final holidaySet = <DateTime>{};
    for (final y in years) {
      try {
        final hs = await ref.read(koreanHolidaysProvider(y).future);
        for (final h in hs) {
          if (!h.isHoliday) continue;
          holidaySet.add(DateTime(h.date.year, h.date.month, h.date.day));
        }
      } catch (_) {
        // 공휴일 fetch 실패는 치명적이지 않음 — 일단 알림은 schedule (사용자가
        // 직접 보고 무시 가능). 다음 부트에서 재시도.
      }
    }

    for (var d = 0; d < scheduleHorizonDays; d++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: d));
      if (holidaySet.contains(date)) {
        dev.log('[scheduleClassReminders] $date 공휴일 skip');
        continue;
      }
      final dayWeek = ucheckDayWeek(date);
      for (final l in data.lectures) {
        if (l.dayWeek.isNotEmpty && l.dayWeek != dayWeek) continue;
        final start = l.startDateTimeOn(date);
        if (start == null) continue;

        if (attendOpenOn) {
          // 출석 가능 시작 = start - attendSmin (보통 10). 0 또는 음수면 = 정각.
          final attendSmin = l.attendSmin ?? 10;
          final openAt = start.subtract(Duration(minutes: attendSmin));
          if (openAt.isAfter(now)) {
            await notif.scheduleAttendOpen(
              lectureNo: l.lecture.lectureNo,
              lectureName: l.lecture.curriculumNm,
              dayOffset: d,
              whenKst: openAt,
            );
          }
        }

        if (classStartOn && start.isAfter(now)) {
          await notif.scheduleClassStart(
            lectureNo: l.lecture.lectureNo,
            lectureName: l.lecture.curriculumNm,
            dayOffset: d,
            whenKst: start,
          );
        }
      }
    }
  }
}

final autoAttendControllerProvider =
    NotifierProvider<AutoAttendController, AutoAttendStatus>(
      AutoAttendController.new,
    );
