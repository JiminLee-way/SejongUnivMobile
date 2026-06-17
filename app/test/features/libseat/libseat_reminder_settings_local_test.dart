import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_reminder_settings_local.dart';

void main() {
  group('LibseatReminderSettingsLocal', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('libseat_settings_test_');
    });

    tearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('저장값이 없으면 현재 동작과 같은 기본 알림 설정을 반환', () async {
      final local = LibseatReminderSettingsLocal(
        fileForTesting: File('${dir.path}/settings.json'),
      );

      final settings = await local.read();

      expect(settings.enabled, isTrue);
      expect(settings.enabledMinutesBefore, {5, 15, 30, 60, 120});
    });

    test('master와 개별 알림 시점 저장값을 JSON으로 왕복', () async {
      final local = LibseatReminderSettingsLocal(
        fileForTesting: File('${dir.path}/settings.json'),
      );
      const custom = LibseatReminderSettings(
        enabled: false,
        enabledMinutesBefore: {10, 45},
      );

      await local.write(custom);
      final restored = await local.read();

      expect(restored.enabled, isFalse);
      expect(restored.enabledMinutesBefore, {10, 45});
    });

    test('지원하지 않는 알림 시점은 무시', () {
      final settings = LibseatReminderSettings.fromJson({
        'enabled': true,
        'enabledMinutesBefore': [1, 5, 45, 999],
      });

      expect(settings.enabledMinutesBefore, {5, 45});
    });
  });
}
