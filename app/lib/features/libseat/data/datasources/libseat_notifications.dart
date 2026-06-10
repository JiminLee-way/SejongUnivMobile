import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 열람실 좌석 예약 종료 전 OS 알림.
///
/// 예약 성공 시 종료시간 기준 **30분 전·5분 전** 2건을 예약한다(사용자 요구
/// #2·#3). 연장 성공 시 새 종료시간으로 재예약(#5), 반납 성공 시 취소.
///
/// **정확도**: 좌석 예약은 최대 4시간 뒤 만료라 그 사이 단말이 Doze에 들어갈 수
/// 있다. inexact 알람은 Doze에서 수분 지연될 수 있어 "5분 전" 알림이 만료 후에
/// 뜰 위험이 있으므로 `exactAllowWhileIdle`을 쓴다(매니페스트에
/// `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` 필요). 출결(ucheck)은 10분 윈도라
/// inexact로 충분했지만 여기선 deadline 정렬이 중요.
///
/// timezone(KST)은 [UCheckNotifications]가 앱 시작 시 init하지만, 단독 호출에도
/// 안전하도록 [init]에서 한 번 더 보장한다(중복 호출 무해).
class LibseatNotifications {
  LibseatNotifications._();
  static final LibseatNotifications instance = LibseatNotifications._();

  static const String channelReminder = 'libseat_reminder';

  /// 활성 좌석은 동시에 1개뿐 → 고정 id 2개로 취소/재예약.
  /// ucheck는 lectureNo 기반 작은 id를 쓰므로 충돌 없게 7003x 대역 사용.
  static const int _id30 = 70030;
  static const int _id5 = 70005;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

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
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    // 채널만 등록. POST_NOTIFICATIONS 런타임 동의는 앱 시작 시 강제하지 않고
    // (ucheck와 동일 정책) 첫 예약 시점([scheduleForExpiry])에 요청.
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
  Future<void> _ensurePermission() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// 종료시간 [expiresAt] 기준 30분·5분 전 알림 재설정.
  ///
  /// 기존 예약을 먼저 취소하므로 연장 시 그대로 다시 부르면 재스케줄된다(#5).
  /// 트리거 시각이 이미 과거면 그 건은 건너뛴다.
  Future<void> scheduleForExpiry(
    DateTime expiresAt, {
    String? roomLabel,
  }) async {
    await init();
    await _ensurePermission();
    await cancelAll();
    final now = DateTime.now();
    final label = (roomLabel == null || roomLabel.trim().isEmpty)
        ? '열람실'
        : roomLabel.trim();
    await _scheduleAt(
      _id30,
      expiresAt.subtract(const Duration(minutes: 30)),
      now,
      '$label 예약 시간이 30분 남았습니다.',
    );
    await _scheduleAt(
      _id5,
      expiresAt.subtract(const Duration(minutes: 5)),
      now,
      '$label 예약 시간이 5분 남았습니다.',
    );
  }

  Future<void> _scheduleAt(
    int id,
    DateTime when,
    DateTime now,
    String body,
  ) async {
    if (!when.isAfter(now)) return;
    await _plugin.zonedSchedule(
      id,
      '열람실 예약',
      body,
      tz.TZDateTime.from(when, tz.local),
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 반납/만료 시 예약된 30분·5분 알림 모두 취소.
  Future<void> cancelAll() async {
    await _plugin.cancel(_id30);
    await _plugin.cancel(_id5);
  }
}
