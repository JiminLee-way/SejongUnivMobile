import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:sejong_smart_campus/core/notifications/notification_tap_bus.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_notification_state_local.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_reminder_settings_local.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';

enum LibseatNotificationKind {
  extend('extend', 120),
  oneHour('60m', 60),
  fortyFive('45m', 45),
  thirty('30m', 30),
  twentyFive('25m', 25),
  twenty('20m', 20),
  fifteen('15m', 15),
  ten('10m', 10),
  five('5m', 5);

  const LibseatNotificationKind(this.wireName, this.minutesBefore);

  final String wireName;
  final int minutesBefore;

  static LibseatNotificationKind? parse(String raw) {
    if (raw == '120m') return LibseatNotificationKind.extend;
    for (final kind in values) {
      if (kind.wireName == raw) return kind;
    }
    return null;
  }
}

class LibseatNotificationPayload {
  const LibseatNotificationPayload({
    required this.kind,
    required this.reservationKey,
  });

  final LibseatNotificationKind kind;
  final String reservationKey;

  static LibseatNotificationPayload? parse(String? payload) {
    if (payload == null || !payload.startsWith('libseat:')) return null;
    final parts = payload.split(':');
    if (parts.length < 3) return null;
    final kind = LibseatNotificationKind.parse(parts[1]);
    if (kind == null) return null;
    return LibseatNotificationPayload(
      kind: kind,
      reservationKey: parts.sublist(2).join(':'),
    );
  }
}

class LibseatScheduledNotification {
  const LibseatScheduledNotification({
    required this.kind,
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    required this.payload,
  });

  final LibseatNotificationKind kind;
  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String payload;
}

/// 열람실 좌석 예약 종료 전 OS 알림.
///
/// 예약/동기화 성공 시 서버가 알려준 활성 좌석 기준으로 연장 가능, 반납 60/30/15/5분
/// 전 알림을 예약한다. 연장 성공/키오스크 변경 시 새 종료시간으로 재예약, 반납 확인 시
/// 모두 취소한다.
///
/// **정확도**: 좌석 예약은 수 시간 뒤 만료라 그 사이 단말이 Doze에 들어갈 수
/// 있다. inexact 알람은 Doze에서 수분 지연될 수 있어 "5분 전" 알림이 만료 후에
/// 뜰 위험이 있으므로, Android에서 `SCHEDULE_EXACT_ALARM`이 허용된 경우
/// `exactAllowWhileIdle`을 쓴다. 권한이 거부되면 알림 자체를 잃지 않도록
/// `inexactAllowWhileIdle`로 fallback한다. 출결(ucheck)은 10분 윈도라 inexact로
/// 충분했지만 여기선 deadline 정렬이 중요.
///
/// timezone(KST)은 [UCheckNotifications]가 앱 시작 시 init하지만, 단독 호출에도
/// 안전하도록 [init]에서 한 번 더 보장한다(중복 호출 무해).
class LibseatNotifications {
  LibseatNotifications._();
  static final LibseatNotifications instance = LibseatNotifications._();

  static const String channelReminder = 'libseat_reminder';

  /// 활성 좌석은 동시에 1개뿐 → 고정 id들로 취소/재예약.
  /// ucheck는 lectureNo 기반 작은 id를 쓰므로 충돌 없게 7003x 대역 사용.
  static const int _idExtend = 70020;
  static const int _id60 = 70060;
  static const int _id45 = 70045;
  static const int _id30 = 70030;
  static const int _id25 = 70025;
  static const int _id20 = 70022;
  static const int _id15 = 70015;
  static const int _id10 = 70010;
  static const int _id5 = 70005;
  static const List<int> _allNotificationIds = [
    _idExtend,
    _id60,
    _id45,
    _id30,
    _id25,
    _id20,
    _id15,
    _id10,
    _id5,
  ];
  static const MethodChannel _nativeChannel = MethodChannel(
    'ac.sejong/libseat_alarms',
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Stream<NotificationResponse> get onTap =>
      NotificationTapBus.instance.responses.where(
        (response) =>
            LibseatNotificationPayload.parse(response.payload) != null,
      );

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (e) {
      dev.log(
        '[LibseatNotifications] tz setLocalLocation 실패(UTC fallback): $e',
      );
    }
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_app');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: NotificationTapBus.instance.add,
    );
    // 채널만 등록. POST_NOTIFICATIONS 런타임 동의는 앱 시작 시 강제하지 않고
    // (ucheck와 동일 정책) 첫 예약/동기화 시점에 요청.
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelReminder,
          '열람실 예약 알림',
          description: '열람실 좌석 예약 종료 전 안내',
          importance: Importance.high,
          enableVibration: true,
        ),
      );
    }
    _initialized = true;
    dev.log('[LibseatNotifications] init 완료');
  }

  /// POST_NOTIFICATIONS / iOS 알림 런타임 동의. 첫 예약 직전에 한 번 호출.
  ///
  /// Android exact alarm은 별도 special access라, 사용자 액션 중일 때만 설정 화면으로
  /// 유도한다. 홈 polling/resume 같은 자동 sync에서 설정 화면이 뜨면 흐름을 끊으므로
  /// 조용히 inexact fallback을 쓴다.
  Future<bool> _ensurePermission({bool promptExactAlarm = false}) async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      return _ensureAndroidExactAlarmPermission(
        android,
        prompt: promptExactAlarm,
      );
    } else if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
    return true;
  }

  Future<bool> _ensureAndroidExactAlarmPermission(
    AndroidFlutterLocalNotificationsPlugin? android, {
    required bool prompt,
  }) async {
    if (android == null) return false;
    final alreadyAllowed = await android.canScheduleExactNotifications();
    if (alreadyAllowed == true) return true;
    if (!prompt) return false;
    final requested = await android.requestExactAlarmsPermission();
    return requested == true;
  }

  Future<void> scheduleForSeat(
    MySeat seat, {
    bool promptExactAlarm = false,
    LibseatReminderSettings settings = LibseatReminderSettings.defaults,
  }) async {
    if (!settings.hasAnyEnabled) {
      await cancelAll();
      return;
    }
    final snapshot = LibseatReservationSnapshot.fromMySeat(seat);
    await init();
    final canScheduleExact = await _ensurePermission(
      promptExactAlarm: promptExactAlarm,
    );
    if (Platform.isAndroid) {
      await _cancelPluginNotifications();
      await _scheduleNativeForSeat(
        seat,
        snapshot: snapshot,
        canScheduleExact: canScheduleExact,
        settings: settings,
      );
      return;
    }

    await cancelAll();
    final now = DateTime.now();
    for (final notification in buildLibseatNotificationPlan(
      seat,
      now,
      reservationKey: snapshot.key,
      settings: settings,
    )) {
      await _schedule(notification, canScheduleExact: canScheduleExact);
    }
  }

  /// 종료시간 [expiresAt] 기준 30분·5분 전 알림 재설정.
  ///
  /// 기존 예약을 먼저 취소하므로 연장 시 그대로 다시 부르면 재스케줄된다(#5).
  /// 트리거 시각이 이미 과거면 그 건은 건너뛴다.
  Future<void> scheduleForExpiry(
    DateTime expiresAt, {
    String? roomLabel,
    bool promptExactAlarm = false,
  }) async {
    await init();
    final canScheduleExact = await _ensurePermission(
      promptExactAlarm: promptExactAlarm,
    );
    await cancelAll();
    final now = DateTime.now();
    final label = (roomLabel == null || roomLabel.trim().isEmpty)
        ? '열람실'
        : roomLabel.trim();
    for (final notification in _buildFallbackExpiryPlan(
      expiresAt,
      now,
      roomLabel: label,
    )) {
      await _schedule(notification, canScheduleExact: canScheduleExact);
    }
  }

  Future<void> _schedule(
    LibseatScheduledNotification notification, {
    required bool canScheduleExact,
  }) async {
    final scheduleMode = Platform.isAndroid && canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    await _plugin.zonedSchedule(
      notification.id,
      notification.title,
      notification.body,
      tz.TZDateTime.from(notification.when, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelReminder,
          '열람실 예약 알림',
          channelDescription: '열람실 좌석 예약 종료 전 안내',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: notification.payload,
    );
  }

  Future<String?> launchPayload() async {
    final nativePayload = await _nativeLaunchPayload();
    if (LibseatNotificationPayload.parse(nativePayload) != null) {
      return nativePayload;
    }

    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      final payload = details?.notificationResponse?.payload;
      return LibseatNotificationPayload.parse(payload) == null ? null : payload;
    }
    return null;
  }

  Future<String?> takeNativeLaunchPayload() async {
    final payload = await _nativeLaunchPayload();
    return LibseatNotificationPayload.parse(payload) == null ? null : payload;
  }

  Future<bool> hasAllPendingForSeat(
    MySeat seat, {
    LibseatReminderSettings settings = LibseatReminderSettings.defaults,
  }) async {
    if (!settings.hasAnyEnabled) return true;
    if (Platform.isAndroid) {
      try {
        final result = await _nativeChannel.invokeMethod<bool>(
          'hasLibseatAlarms',
          _nativeSnapshotArgs(
            seat,
            LibseatReservationSnapshot.fromMySeat(seat),
            settings: settings,
          ),
        );
        return result == true;
      } catch (e) {
        dev.log('[LibseatNotifications] native pending 확인 실패: $e');
        return false;
      }
    }

    await init();
    final pending = await _plugin.pendingNotificationRequests();
    return libseatPendingIdsCoverPlan(
      seat,
      DateTime.now(),
      pending.map((request) => request.id),
      settings: settings,
    );
  }

  /// 반납/만료 시 예약된 열람실 알림 모두 취소.
  Future<void> cancelAll() async {
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod<void>('cancelLibseatAlarms');
      } catch (e) {
        dev.log('[LibseatNotifications] native cancel 실패: $e');
      }
    }
    await _cancelPluginNotifications();
  }

  Future<void> _cancelPluginNotifications() async {
    for (final id in _allNotificationIds) {
      await _plugin.cancel(id);
    }
  }

  Future<void> _scheduleNativeForSeat(
    MySeat seat, {
    required LibseatReservationSnapshot snapshot,
    required bool canScheduleExact,
    required LibseatReminderSettings settings,
  }) async {
    try {
      await _nativeChannel.invokeMethod<void>(
        'scheduleLibseatAlarms',
        _nativeSnapshotArgs(seat, snapshot, settings: settings),
      );
    } catch (e) {
      dev.log('[LibseatNotifications] native schedule 실패, plugin fallback: $e');
      final now = DateTime.now();
      for (final notification in buildLibseatNotificationPlan(
        seat,
        now,
        reservationKey: snapshot.key,
        settings: settings,
      )) {
        await _schedule(notification, canScheduleExact: canScheduleExact);
      }
    }
  }

  Map<String, Object> _nativeSnapshotArgs(
    MySeat seat,
    LibseatReservationSnapshot snapshot, {
    required LibseatReminderSettings settings,
  }) {
    return {
      'roomName': seat.roomName,
      'roomNo': seat.roomNo,
      'seatNo': seat.seatNo,
      'startedAtMillis': seat.startedAt.millisecondsSinceEpoch,
      'expiresAtMillis': seat.expiresAt.millisecondsSinceEpoch,
      'reservationKey': snapshot.key,
      'remindersEnabled': settings.enabled,
      'enabledMinutesBefore': settings.sortedEnabledMinutesBefore,
    };
  }

  Future<String?> _nativeLaunchPayload() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _nativeChannel.invokeMethod<String>(
        'getInitialLibseatPayload',
      );
    } catch (e) {
      dev.log('[LibseatNotifications] native launch payload 확인 실패: $e');
      return null;
    }
  }
}

List<LibseatScheduledNotification> buildLibseatNotificationPlan(
  MySeat seat,
  DateTime now, {
  String? reservationKey,
  LibseatReminderSettings settings = LibseatReminderSettings.defaults,
}) {
  if (!settings.hasAnyEnabled) return const [];
  final key = reservationKey ?? LibseatReservationSnapshot.fromMySeat(seat).key;
  final roomLabel = seat.roomName.trim().isEmpty ? '열람실' : seat.roomName.trim();
  final expiresAt = seat.expiresAt;
  final candidates = [
    for (final minutes in settings.sortedEnabledMinutesBefore.reversed.toList())
      if (_kindForMinutesBefore(minutes) case final kind?)
        (
          kind: kind,
          when: expiresAt.subtract(Duration(minutes: minutes)),
          body: kind == LibseatNotificationKind.extend
              ? '$roomLabel 연장 가능 시각입니다.'
              : '$roomLabel 반납 ${libseatRemainingLabel(minutes)} 남았습니다.',
        ),
  ];
  return [
    for (final candidate in candidates)
      if (candidate.when.isAfter(now))
        LibseatScheduledNotification(
          kind: candidate.kind,
          id: _idForKind(candidate.kind),
          title: candidate.kind == LibseatNotificationKind.extend
              ? '열람실 연장 가능 시각입니다'
              : '열람실 반납 알림',
          body: candidate.body,
          when: candidate.when,
          payload: 'libseat:${candidate.kind.wireName}:$key',
        ),
  ];
}

List<LibseatScheduledNotification> _buildFallbackExpiryPlan(
  DateTime expiresAt,
  DateTime now, {
  required String roomLabel,
}) {
  final key = 'expiry|${expiresAt.toIso8601String()}';
  return [
    for (final notification in <LibseatScheduledNotification>[
      LibseatScheduledNotification(
        kind: LibseatNotificationKind.thirty,
        id: _idForKind(LibseatNotificationKind.thirty),
        title: '열람실 반납 알림',
        body: '$roomLabel 반납 30분 남았습니다.',
        when: expiresAt.subtract(const Duration(minutes: 30)),
        payload: 'libseat:${LibseatNotificationKind.thirty.wireName}:$key',
      ),
      LibseatScheduledNotification(
        kind: LibseatNotificationKind.five,
        id: _idForKind(LibseatNotificationKind.five),
        title: '열람실 반납 알림',
        body: '$roomLabel 반납 5분 남았습니다.',
        when: expiresAt.subtract(const Duration(minutes: 5)),
        payload: 'libseat:${LibseatNotificationKind.five.wireName}:$key',
      ),
    ])
      if (notification.when.isAfter(now)) notification,
  ];
}

int _idForKind(LibseatNotificationKind kind) => switch (kind) {
  LibseatNotificationKind.extend => LibseatNotifications._idExtend,
  LibseatNotificationKind.oneHour => LibseatNotifications._id60,
  LibseatNotificationKind.fortyFive => LibseatNotifications._id45,
  LibseatNotificationKind.thirty => LibseatNotifications._id30,
  LibseatNotificationKind.twentyFive => LibseatNotifications._id25,
  LibseatNotificationKind.twenty => LibseatNotifications._id20,
  LibseatNotificationKind.fifteen => LibseatNotifications._id15,
  LibseatNotificationKind.ten => LibseatNotifications._id10,
  LibseatNotificationKind.five => LibseatNotifications._id5,
};

LibseatNotificationKind? _kindForMinutesBefore(int minutesBefore) {
  for (final kind in LibseatNotificationKind.values) {
    if (kind.minutesBefore == minutesBefore) return kind;
  }
  return null;
}

Set<int> expectedLibseatNotificationIds(
  MySeat seat,
  DateTime now, {
  LibseatReminderSettings settings = LibseatReminderSettings.defaults,
}) => buildLibseatNotificationPlan(
  seat,
  now,
  settings: settings,
).map((n) => n.id).toSet();

bool libseatPendingIdsCoverPlan(
  MySeat seat,
  DateTime now,
  Iterable<int> pendingIds, {
  LibseatReminderSettings settings = LibseatReminderSettings.defaults,
}) {
  final expected = expectedLibseatNotificationIds(
    seat,
    now,
    settings: settings,
  );
  final pending = pendingIds.toSet();
  return expected.every(pending.contains);
}
