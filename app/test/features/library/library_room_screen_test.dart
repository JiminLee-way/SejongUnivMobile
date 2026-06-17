import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';
import 'package:sejong_smart_campus/features/library/presentation/screens/library_room_screen.dart';
import 'package:sejong_smart_campus/features/library/presentation/widgets/seat_map.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart'
    as libseat;
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';

void main() {
  const room = LibraryRoom(
    roomNo: 13,
    name: '학술정보원 1F 제2열람실',
    shortLabel: '제2열람실',
    hasSeatMap: true,
  );

  testWidgets('SeatMap loading 모드는 좌석 번호 대신 skeleton tile을 렌더', (tester) async {
    const layout = RoomLayout(
      roomNo: 13,
      name: '제2열람실',
      canvasWidth: 320,
      canvasHeight: 480,
      backgroundAsset: 'assets/library/map_13.jpg',
      bbox: Rect.fromLTWH(40, 40, 160, 260),
      seats: [
        SeatPosition(id: 1, x: 80, y: 100, w: 35, h: 41),
        SeatPosition(id: 2, x: 120, y: 100, w: 35, h: 41),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: SeatMap(
              layout: layout,
              statuses: {1: SeatStatus.available, 2: SeatStatus.occupied},
              loading: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('seat-skeleton-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('seat-skeleton-2')), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('LibraryRoomScreen 최초 live 완료 전 stale 좌석값 대신 skeleton 표시', (
    tester,
  ) async {
    final seats = Completer<List<libseat.Seat>>();
    final rooms = Completer<List<libseat.ReadingRoom>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mySeatProvider.overrideWith((ref) async => null),
          seatMapForRoomProvider.overrideWith((ref, roomNo) => seats.future),
          roomListProvider.overrideWith((ref) => rooms.future),
        ],
        child: const MaterialApp(home: LibraryRoomScreen(room: room)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      find.byKey(const ValueKey('room-header-count-skeleton')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('seat-skeleton-1')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('seat-skeleton-1')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.text('1번 좌석'), findsNothing);

    seats.complete(const [
      libseat.Seat(
        roomNo: 13,
        seatNo: '1',
        status: libseat.SeatStatus.available,
      ),
      libseat.Seat(roomNo: 13, seatNo: '2', status: libseat.SeatStatus.used),
    ]);
    rooms.complete(const [
      libseat.ReadingRoom(roomNo: 13, name: '제2열람실', used: 10, total: 111),
    ]);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('room-header-count-skeleton')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('seat-skeleton-1')), findsNothing);
    expect(find.text('10 / 111'), findsOneWidget);
  });
}
