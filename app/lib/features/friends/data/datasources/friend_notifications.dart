import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:sejong_smart_campus/core/notifications/notification_tap_bus.dart';

/// 친구 관련 OS 로컬 알림(헤드업).
///
/// 새 친구요청이 감지되면(앱 열림/복귀/30초 폴링) 상단에 채팅처럼 헤드업으로
/// 띄운다. FCM 없이 **앱이 떠 있는 동안** 동작 — 완전 종료 상태 푸시는 FCM 도입
/// 시 별도.
///
/// ucheck/libseat과 동일하게 자체 plugin 인스턴스를 쓰되 **탭 콜백은 등록하지
/// 않는다**(ucheck의 자동출석 탭 라우팅을 덮어쓰지 않기 위함). 탭하면 앱만 열리고,
/// 사용자는 알림함/친구 화면에서 확인한다.
class FriendNotifications {
  FriendNotifications._();
  static final FriendNotifications instance = FriendNotifications._();

  static const String channelId = 'friends';
  static const int _notificationId = 9100001; // 고정 — 새 요청이 이전 알림 갱신

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// main.dart에서 한 번 호출. 채널 등록 + 네이티브 plugin 보장.
  Future<void> init() async {
    if (_initialized) return;
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
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          '친구 알림',
          description: '친구 요청 등 친구 관련 알림',
          importance: Importance.high,
          enableVibration: true,
        ),
      );
    }
    _initialized = true;
    dev.log('[FriendNotifications] init 완료');
  }

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

  /// 새 친구요청 헤드업. [count]가 1이면 보낸 사람 이름, 여러 건이면 N건으로.
  Future<void> showFriendRequest({required int count, String? fromName}) async {
    await init();
    await _ensurePermission();
    final body = count <= 1
        ? '${fromName ?? '누군가'}님이 친구 요청을 보냈어요'
        : '친구 요청 $count건이 도착했어요';
    await _plugin.show(
      _notificationId,
      '친구 요청',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          '친구 알림',
          channelDescription: '친구 요청 등 친구 관련 알림',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.social,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
        ),
      ),
    );
  }
}
