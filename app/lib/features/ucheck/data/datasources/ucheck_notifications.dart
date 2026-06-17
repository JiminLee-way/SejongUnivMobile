import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:sejong_smart_campus/core/notifications/notification_tap_bus.dart';

/// UCheck V2 자동출석 OS 알림 wrapper.
///
/// **3 채널**:
/// - `ucheck_pre_class` (HIGH) — 강의 시작 10분 전 "강의 시작 10분 전 UCheck!"
///   사용자 탭하면 앱 열리면서 자동출석 트리거.
/// - `ucheck_result` (HIGH) — 출석 처리 결과 ("자료구조 출석 완료!" 등).
/// - `ucheck_reminder` (HIGH) — 강의실에 못 들어가서 자동출석 실패한 경우
///   사용자에게 수동 출석 안내.
///
/// **timezone**: KST(Asia/Seoul) 고정. flutter_timezone 패키지 사용 없이
/// 직접 setLocalLocation. zonedSchedule이 tz.TZDateTime을 요구하므로 필수.
class UCheckNotifications {
  UCheckNotifications._();
  static final UCheckNotifications instance = UCheckNotifications._();

  static const String channelPreClass = 'ucheck_pre_class';
  static const String channelResult = 'ucheck_result';
  static const String channelReminder = 'ucheck_reminder';

  /// 출석 가능 시간이 시작될 때 (= 강의 시작 - attendSmin) 발화.
  /// 자동출석과 무관하게 동작 — 토글로 별도 ON/OFF.
  static const String channelAttendOpen = 'ucheck_attend_open';

  /// 강의 시작 정각에 발화. attend_open 채널과 별개 — 사용자가 OS 설정에서
  /// 개별 ON/OFF 가능하도록 분리.
  static const String channelClassStart = 'ucheck_class_start';

  /// payload format: `"lectureNo:<int>"` — notification 탭 시 어느 강의 자동출석을
  /// 시도해야 하는지 식별. 다른 prefix가 추가될 경우 확장.
  static String payloadForPreClass(int lectureNo) => 'preclass:$lectureNo';
  static String payloadForResult(int lectureNo) => 'result:$lectureNo';

  /// 탭 콜백 broadcast — AutoAttendController가 subscribe.
  Stream<NotificationResponse> get onTap => NotificationTapBus
      .instance
      .responses
      .where((response) => _isUCheckPayload(response.payload));

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 앱 시작 시 한 번 호출 (main.dart 또는 첫 사용 직전).
  Future<void> init() async {
    if (_initialized) return;

    // 1) timezone init (zonedSchedule 필수)
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (e) {
      dev.log(
        '[UCheckNotifications] timezone setLocalLocation 실패 (UTC fallback): $e',
      );
    }

    // 2) plugin init — Android + iOS
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_app');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        NotificationTapBus.instance.add(response);
      },
    );

    // 3) Android 채널 등록 (idempotent — 같은 id면 덮어쓰지 않음)
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelPreClass,
          '강의 시작 알림',
          description: '강의 시작 10분 전 자동출석 안내',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelResult,
          '출석 결과',
          description: '출석 처리 결과 알림',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelReminder,
          '출석 리마인더',
          description: '자동출석 실패 시 수동 안내',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelAttendOpen,
          '출석 시간 시작 알림',
          description: '강의의 출석 가능 시간이 시작될 때 알림',
          importance: Importance.high,
          enableVibration: true,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelClassStart,
          '수업 시작 알림',
          description: '강의가 정각에 시작될 때 알림',
          importance: Importance.high,
          enableVibration: true,
        ),
      );
    }

    _initialized = true;
    dev.log('[UCheckNotifications] init 완료');
  }

  /// Android 13+ POST_NOTIFICATIONS 런타임 권한.
  /// 결과: true=허용, false=거부.
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// 강의 시작 X분 전 "강의 시작 10분 전 UCheck!" notification 예약.
  ///
  /// [whenKst]는 KST 기준 강의 시작 시각 - 10분으로 caller가 계산해서 넘김.
  /// 과거 시각이면 즉시 fires (사용자가 강의 시간 이후에 자동출석 ON한 케이스).
  Future<void> schedulePreClass({
    required int lectureNo,
    required String lectureName,
    required DateTime whenKst,
  }) async {
    final when = tz.TZDateTime.from(whenKst, tz.local);
    final id = _idForPreClass(lectureNo);

    await _plugin.zonedSchedule(
      id,
      '강의 시작 10분 전 UCheck!',
      '$lectureName 출석을 위해 앱을 열어주세요',
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelPreClass,
          '강의 시작 알림',
          channelDescription: '강의 시작 10분 전 자동출석 안내',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      ),
      // inexact OK — 10분 윈도우라 정확도 무관. SCHEDULE_EXACT_ALARM 권한 불필요.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payloadForPreClass(lectureNo),
    );
    dev.log(
      '[UCheckNotifications] preClass scheduled: id=$id at $when ($lectureName)',
    );
  }

  /// 출석 결과 즉시 표시. 인앱 SnackBar와 별개로 OS notification도 띄움 —
  /// 사용자가 다른 앱으로 전환하기 직전 결과를 놓치지 않도록.
  Future<void> showResult({
    required int lectureNo,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      _idForResult(lectureNo),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelResult,
          '출석 결과',
          channelDescription: '출석 처리 결과 알림',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.status,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payloadForResult(lectureNo),
    );
  }

  /// 자동출석 실패 시 사용자가 직접 시도하라는 안내.
  Future<void> showReminder({
    required int lectureNo,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      _idForReminder(lectureNo),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelReminder,
          '출석 리마인더',
          channelDescription: '자동출석 실패 시 수동 안내',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payloadForPreClass(lectureNo),
    );
  }

  /// 강의별 예약된 preClass notification 모두 취소 (시간표 변경 / 토글 OFF).
  Future<void> cancelAllPreClass(List<int> lectureNos) async {
    for (final l in lectureNos) {
      await _plugin.cancel(_idForPreClass(l));
    }
  }

  // ─── 신규: 출석 시간 시작 알림 ────────────────────────────────────────────
  //
  // 자동출석 채널(`ucheck_pre_class`)과 분리한 이유:
  // 1) 자동출석 OFF여도 단순 알림 모드로 동작해야 함
  // 2) OS 채널 단위 ON/OFF가 자동출석과 독립적이어야 함

  Future<void> scheduleAttendOpen({
    required int lectureNo,
    required String lectureName,
    required int dayOffset,
    required DateTime whenKst,
  }) async {
    final when = tz.TZDateTime.from(whenKst, tz.local);
    final id = _idForAttendOpen(lectureNo, dayOffset);
    await _plugin.zonedSchedule(
      id,
      '출석 시간이 시작됐어요',
      '$lectureName — 지금 체크하러 가세요',
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelAttendOpen,
          '출석 시간 시작 알림',
          channelDescription: '강의의 출석 가능 시간이 시작될 때 알림',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payloadForPreClass(lectureNo),
    );
    dev.log(
      '[UCheckNotifications] attendOpen scheduled: id=$id at $when ($lectureName)',
    );
  }

  Future<void> scheduleClassStart({
    required int lectureNo,
    required String lectureName,
    required int dayOffset,
    required DateTime whenKst,
  }) async {
    final when = tz.TZDateTime.from(whenKst, tz.local);
    final id = _idForClassStart(lectureNo, dayOffset);
    await _plugin.zonedSchedule(
      id,
      '수업이 시작됐어요',
      '$lectureName — 강의 시작 시각이에요',
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelClassStart,
          '수업 시작 알림',
          channelDescription: '강의가 정각에 시작될 때 알림',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payloadForPreClass(lectureNo),
    );
    dev.log(
      '[UCheckNotifications] classStart scheduled: id=$id at $when ($lectureName)',
    );
  }

  /// 7일치 강의별 attendOpen/classStart 예약을 한 번에 취소.
  /// 매 부트 시 reschedule 전 호출 — idempotent 보장.
  Future<void> cancelAttendOpenRange(List<int> lectureNos, int days) async {
    for (final l in lectureNos) {
      for (var d = 0; d < days; d++) {
        await _plugin.cancel(_idForAttendOpen(l, d));
      }
    }
  }

  Future<void> cancelClassStartRange(List<int> lectureNos, int days) async {
    for (final l in lectureNos) {
      for (var d = 0; d < days; d++) {
        await _plugin.cancel(_idForClassStart(l, d));
      }
    }
  }

  /// 모든 예약/표시된 알림 취소.
  Future<void> cancelAll() => _plugin.cancelAll();

  /// **앱이 종료된 상태에서 notification 탭으로 launch된 경우** 페이로드 반환.
  /// AppShell init에서 한 번 호출해 보고, payload 있으면 자동출석 트리거.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      final payload = details?.notificationResponse?.payload;
      return _isUCheckPayload(payload) ? payload : null;
    }
    return null;
  }

  bool _isUCheckPayload(String? payload) =>
      payload != null &&
      (payload.startsWith('preclass:') || payload.startsWith('result:'));

  // ID 충돌 방지: prefix별 base + lectureNo 작은 정수.
  // Android notification id는 int (32-bit).
  // lectureNo는 보통 5~6자리 (< 100,000) — dayOffset×100,000으로 7일치 분리.
  int _idForPreClass(int lectureNo) => 1000000 + lectureNo;
  int _idForResult(int lectureNo) => 2000000 + lectureNo;
  int _idForReminder(int lectureNo) => 3000000 + lectureNo;
  int _idForAttendOpen(int lectureNo, int dayOffset) =>
      4000000 + dayOffset * 100000 + lectureNo;
  int _idForClassStart(int lectureNo, int dayOffset) =>
      5000000 + dayOffset * 100000 + lectureNo;
}
