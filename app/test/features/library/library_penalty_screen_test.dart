import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';
import 'package:sejong_smart_campus/features/library/presentation/screens/library_penalty_screen.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

void main() {
  testWidgets('실제 이용내역 provider에서 미반납 상태만 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seatUsageHistoryProvider.overrideWith(
            (ref) async => [
              _record('제1열람실', LibraryUsageStatus.unreturned),
              _record('제2열람실', LibraryUsageStatus.completed),
              _record('제4열람실', LibraryUsageStatus.unreturned),
            ],
          ),
        ],
        child: const MaterialApp(home: LibraryPenaltyScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('미반납 내역 2건'), findsOneWidget);
    expect(find.text('제1열람실'), findsOneWidget);
    expect(find.text('제4열람실'), findsOneWidget);
    expect(find.text('제2열람실'), findsNothing);
  });

  testWidgets('이용내역 로딩 중에는 skeleton을 표시한다', (tester) async {
    final pending = Completer<List<LibraryUsageRecord>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seatUsageHistoryProvider.overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(home: LibraryPenaltyScreen()),
      ),
    );

    await tester.pump();

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.text('미반납 내역 0건'), findsNothing);

    pending.complete(const []);
    await tester.pump();
    await tester.pump();
  });

  testWidgets('pull refresh는 이용내역 provider를 실제 재호출한다', (tester) async {
    var calls = 0;
    final refreshed = Completer<List<LibraryUsageRecord>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seatUsageHistoryProvider.overrideWith((ref) {
            calls += 1;
            if (calls == 1) return Future.value(const []);
            return refreshed.future;
          }),
        ],
        child: const MaterialApp(home: LibraryPenaltyScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(calls, 1);
    expect(find.text('미반납 내역이 없어요'), findsOneWidget);

    final refresh = tester.widget<SejongRefresh>(find.byType(SejongRefresh));
    final refreshFuture = refresh.onRefresh();
    await tester.pump();

    expect(calls, 2);

    refreshed.complete([_record('제4열람실', LibraryUsageStatus.unreturned)]);
    await tester.pump(const Duration(milliseconds: 300));
    await refreshFuture;
    await tester.pump();
    await tester.pump();

    expect(find.text('미반납 내역 1건'), findsOneWidget);
    expect(find.text('제4열람실'), findsOneWidget);
  });

  testWidgets('미반납이 없으면 0건 요약과 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seatUsageHistoryProvider.overrideWith(
            (ref) async => [_record('제1열람실', LibraryUsageStatus.completed)],
          ),
        ],
        child: const MaterialApp(home: LibraryPenaltyScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('미반납 내역 0건'), findsOneWidget);
    expect(find.text('미반납 내역이 없어요'), findsOneWidget);
    expect(find.text('제1열람실'), findsNothing);
  });
}

LibraryUsageRecord _record(String room, LibraryUsageStatus status) {
  return LibraryUsageRecord(
    startedAt: DateTime(2026, 6, 17, 9),
    endedAt: DateTime(2026, 6, 17, 12),
    roomLabel: room,
    status: status,
  );
}
