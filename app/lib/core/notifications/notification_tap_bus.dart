import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notification tap events shared by feature-specific notification
/// wrappers.
///
/// flutter_local_notifications keeps a single platform response callback.
/// Registering callbacks from multiple wrappers can make the last initializer
/// win, so every wrapper forwards responses here and features filter by
/// payload prefix.
class NotificationTapBus {
  NotificationTapBus._();

  static final NotificationTapBus instance = NotificationTapBus._();

  final StreamController<NotificationResponse> _responses =
      StreamController<NotificationResponse>.broadcast();

  Stream<NotificationResponse> get responses => _responses.stream;

  void add(NotificationResponse response) {
    _responses.add(response);
  }
}
