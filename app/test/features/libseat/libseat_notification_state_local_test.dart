import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_notification_state_local.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';

void main() {
  group('LibseatNotificationStateLocal', () {
    late Directory tempDir;
    late LibseatNotificationStateLocal local;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('libseat_state_test_');
      local = LibseatNotificationStateLocal(
        fileForTesting: File('${tempDir.path}/state.json'),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('활성 좌석 snapshot을 저장하고 다시 읽는다', () async {
      final snapshot = LibseatReservationSnapshot.fromMySeat(
        MySeat(
          roomNo: 16,
          roomName: '제4열람실B',
          seatNo: '174',
          startTime: '10:00',
          endTime: '16:00',
          extensionsUsed: 0,
          issuedDate: DateTime(2026, 6, 17),
        ),
      );

      await local.saveSnapshot(snapshot);

      final state = await local.read();
      expect(state.current?.key, snapshot.key);
      expect(state.current?.startedAt, DateTime(2026, 6, 17, 10));
      expect(state.current?.expiresAt, DateTime(2026, 6, 17, 16));
      expect(state.acknowledgedReturnKeys, isEmpty);
    });

    test('snapshot clear는 반납 확인 ack 목록을 유지한다', () async {
      final snapshot = LibseatReservationSnapshot(
        key: 'reservation-a',
        roomNo: 16,
        seatNo: '174',
        roomName: '제4열람실B',
        startedAt: DateTime(2026, 6, 17, 10),
        expiresAt: DateTime(2026, 6, 17, 16),
      );

      await local.saveSnapshot(snapshot);
      await local.acknowledgeReturn(snapshot.key);
      await local.clearSnapshot();

      final state = await local.read();
      expect(state.current, isNull);
      expect(state.acknowledgedReturnKeys, contains(snapshot.key));
      expect(await local.hasAcknowledgedReturn(snapshot.key), isTrue);
    });

    test('ack는 한 번 저장되면 같은 reservationKey 팝업을 막는다', () async {
      expect(await local.hasAcknowledgedReturn('reservation-b'), isFalse);

      await local.acknowledgeReturn('reservation-b');
      await local.acknowledgeReturn('reservation-b');

      final state = await local.read();
      expect(await local.hasAcknowledgedReturn('reservation-b'), isTrue);
      expect(
        state.acknowledgedReturnKeys.where((k) => k == 'reservation-b').length,
        1,
      );
    });
  });
}
