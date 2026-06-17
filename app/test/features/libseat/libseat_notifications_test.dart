import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_notifications.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_reminder_settings_local.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';

void main() {
  group('buildLibseatNotificationPlan', () {
    final seat = MySeat(
      roomNo: 16,
      roomName: '학술정보원 3F 제4열람실',
      seatNo: '174',
      startTime: '10:00',
      endTime: '16:00',
      extensionsUsed: 0,
      issuedDate: DateTime(2026, 6, 17),
    );

    test('서버 expiresAt 기준 연장 가능/반납 경고를 모두 계산', () {
      final plan = buildLibseatNotificationPlan(
        seat,
        DateTime(2026, 6, 17, 11),
      );

      expect(plan.map((n) => n.kind), [
        LibseatNotificationKind.extend,
        LibseatNotificationKind.oneHour,
        LibseatNotificationKind.thirty,
        LibseatNotificationKind.fifteen,
        LibseatNotificationKind.five,
      ]);
      expect(plan[0].when, DateTime(2026, 6, 17, 14));
      expect(plan[1].when, DateTime(2026, 6, 17, 15));
      expect(plan[2].when, DateTime(2026, 6, 17, 15, 30));
      expect(plan[3].when, DateTime(2026, 6, 17, 15, 45));
      expect(plan[4].when, DateTime(2026, 6, 17, 15, 55));
      expect(plan[0].title, '열람실 연장 가능 시각입니다');
      expect(plan[1].title, '열람실 반납 알림');
      expect(plan[0].payload, startsWith('libseat:extend:'));
    });

    test('이미 지난 알림 시각은 제외하고 미래 알림만 반환', () {
      final plan = buildLibseatNotificationPlan(
        seat,
        DateTime(2026, 6, 17, 15, 40),
      );

      expect(plan.map((n) => n.kind), [
        LibseatNotificationKind.fifteen,
        LibseatNotificationKind.five,
      ]);
      expect(plan.map((n) => n.when), [
        DateTime(2026, 6, 17, 15, 45),
        DateTime(2026, 6, 17, 15, 55),
      ]);
    });

    test('남은 시간이 1시간 5분이면 60/30/15/5분 알림을 예약 대상으로 유지', () {
      final plan = buildLibseatNotificationPlan(
        seat,
        DateTime(2026, 6, 17, 14, 55),
      );

      expect(plan.map((n) => n.kind), [
        LibseatNotificationKind.oneHour,
        LibseatNotificationKind.thirty,
        LibseatNotificationKind.fifteen,
        LibseatNotificationKind.five,
      ]);
    });

    test('master OFF면 알림 계획을 만들지 않는다', () {
      final plan = buildLibseatNotificationPlan(
        seat,
        DateTime(2026, 6, 17, 11),
        settings: const LibseatReminderSettings(
          enabled: false,
          enabledMinutesBefore: {5, 15, 30, 60, 120},
        ),
      );

      expect(plan, isEmpty);
    });

    test('개별 시점 ON/OFF에 따라 선택된 알림만 계산', () {
      final plan = buildLibseatNotificationPlan(
        seat,
        DateTime(2026, 6, 17, 11),
        settings: const LibseatReminderSettings(
          enabled: true,
          enabledMinutesBefore: {15, 45},
        ),
      );

      expect(plan.map((n) => n.kind), [
        LibseatNotificationKind.fortyFive,
        LibseatNotificationKind.fifteen,
      ]);
      expect(plan.map((n) => n.when), [
        DateTime(2026, 6, 17, 15, 15),
        DateTime(2026, 6, 17, 15, 45),
      ]);
    });

    test('pending ids가 미래 알림 계획을 모두 포함하는지 판단', () {
      final now = DateTime(2026, 6, 17, 14, 55);
      final allIds = expectedLibseatNotificationIds(seat, now);
      final missingOne = allIds.where((id) => id != allIds.first);

      expect(libseatPendingIdsCoverPlan(seat, now, allIds), isTrue);
      expect(libseatPendingIdsCoverPlan(seat, now, missingOne), isFalse);
    });

    test('pending ids 비교도 설정값을 반영한다', () {
      final now = DateTime(2026, 6, 17, 14, 55);
      const settings = LibseatReminderSettings(
        enabled: true,
        enabledMinutesBefore: {15},
      );
      final ids = expectedLibseatNotificationIds(seat, now, settings: settings);

      expect(ids, {70015});
      expect(
        libseatPendingIdsCoverPlan(seat, now, {70015}, settings: settings),
        isTrue,
      );
      expect(
        libseatPendingIdsCoverPlan(seat, now, {70030}, settings: settings),
        isFalse,
      );
    });

    test('payload parser는 libseat prefix와 reservationKey를 보존', () {
      final parsed = LibseatNotificationPayload.parse(
        'libseat:5m:16|174|2026-06-17T10:00:00.000|2026-06-17T16:00:00.000',
      );

      expect(parsed, isNotNull);
      expect(parsed!.kind, LibseatNotificationKind.five);
      expect(
        parsed.reservationKey,
        '16|174|2026-06-17T10:00:00.000|2026-06-17T16:00:00.000',
      );
      expect(LibseatNotificationPayload.parse('preclass:1'), isNull);
    });
  });
}
