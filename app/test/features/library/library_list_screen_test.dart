import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart'
    as libseat;
import 'package:sejong_smart_campus/features/library/presentation/screens/library_list_screen.dart';

void main() {
  testWidgets('상단 새로고침 버튼은 열람실 현황 provider를 다시 조회한다', (tester) async {
    var roomFetches = 0;
    final entryRefreshRooms = Completer<List<libseat.ReadingRoom>>();
    final manualRefreshRooms = Completer<List<libseat.ReadingRoom>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libseatSyncProvider.overrideWithValue(_FakeLibseatSync()),
          mySeatProvider.overrideWith((ref) async => null),
          seatUsageHistoryProvider.overrideWith((ref) async => const []),
          roomListProvider.overrideWith((ref) {
            roomFetches += 1;
            if (roomFetches == 1) {
              return Future.value(const [
                libseat.ReadingRoom(
                  roomNo: 11,
                  name: '제1열람실',
                  used: 10,
                  total: 100,
                ),
              ]);
            }
            if (roomFetches == 2) return entryRefreshRooms.future;
            return manualRefreshRooms.future;
          }),
        ],
        child: const MaterialApp(home: LibraryListScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byTooltip('열람실 알림 설정'), findsOneWidget);
    expect(roomFetches, 2);

    entryRefreshRooms.complete(const [
      libseat.ReadingRoom(roomNo: 11, name: '제1열람실', used: 11, total: 100),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('11 / 100'), findsOneWidget);

    await tester.tap(find.byTooltip('새로고침'));
    await tester.pump();

    expect(roomFetches, 3);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    manualRefreshRooms.complete(const [
      libseat.ReadingRoom(roomNo: 11, name: '제1열람실', used: 12, total: 100),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('12 / 100'), findsOneWidget);
  });
}

class _FakeLibseatSync implements LibseatSync {
  @override
  Future<LibseatSyncResult> sync({
    required String reason,
    String? notificationPayloadKey,
    int? visibleRoomNo,
    bool expectNoSeat = false,
  }) async {
    return LibseatSyncResult(reason: reason);
  }
}
