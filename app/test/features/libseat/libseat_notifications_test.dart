import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_notifications.dart';
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
