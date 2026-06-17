import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';
import 'package:sejong_smart_campus/features/notices/presentation/providers/notice_providers.dart';
import 'package:sejong_smart_campus/features/notices/presentation/screens/notice_detail_screen.dart';
import 'package:sejong_smart_campus/features/notices/presentation/screens/notices_screen.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

void main() {
  testWidgets('push 진입 공지 목록은 Topbar 뒤로가기 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticesByCategoryProvider.overrideWith(
            (ref, category) async => const <SejongNoticeItem>[],
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NoticesScreen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('공지'), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(NoticesScreen), findsNothing);
  });

  testWidgets('공지 목록 로딩은 spinner 대신 skeleton을 표시한다', (tester) async {
    final completer = Completer<List<SejongNoticeItem>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticesByCategoryProvider.overrideWith(
            (ref, category) => completer.future,
          ),
        ],
        child: const MaterialApp(home: NoticesScreen()),
      ),
    );

    await tester.pump();

    expect(find.byType(Shimmer), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    completer.complete([_item('서버 공지')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('서버 공지'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('공지 목록 새로고침은 provider를 실제 재호출해 새 목록을 표시한다', (tester) async {
    var calls = 0;
    final refreshCompleter = Completer<List<SejongNoticeItem>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticesByCategoryProvider.overrideWith((ref, category) {
            calls += 1;
            if (calls == 1) return Future.value([_item('이전 공지')]);
            return refreshCompleter.future;
          }),
        ],
        child: const MaterialApp(home: NoticesScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('이전 공지'), findsOneWidget);

    final refresh = tester.widget<SejongRefresh>(find.byType(SejongRefresh));
    final refreshFuture = refresh.onRefresh();
    await tester.pump();

    expect(calls, 2);

    refreshCompleter.complete([_item('새 공지')]);
    await tester.pump(const Duration(milliseconds: 300));
    await refreshFuture;
    await tester.pump();

    expect(find.text('새 공지'), findsOneWidget);
  });

  testWidgets('공지 상세 로딩은 spinner 대신 skeleton을 표시한다', (tester) async {
    final completer = Completer<SejongNoticeDetail>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticeDetailProvider.overrideWith((ref, arg) => completer.future),
        ],
        child: MaterialApp(home: NoticeDetailScreen(arg: _detailArg)),
      ),
    );

    await tester.pump();

    expect(find.byType(Shimmer), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    completer.complete(_detail('상세 제목', '<p>상세 본문</p>'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('상세 제목'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('공지 상세 새로고침은 provider를 실제 재호출해 새 본문을 표시한다', (tester) async {
    var calls = 0;
    final refreshCompleter = Completer<SejongNoticeDetail>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticeDetailProvider.overrideWith((ref, arg) {
            calls += 1;
            if (calls == 1) {
              return Future.value(_detail('이전 제목', '<p>이전 본문</p>'));
            }
            return refreshCompleter.future;
          }),
        ],
        child: MaterialApp(home: NoticeDetailScreen(arg: _detailArg)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('이전 제목'), findsOneWidget);

    final refresh = tester.widget<SejongRefresh>(find.byType(SejongRefresh));
    final refreshFuture = refresh.onRefresh();
    await tester.pump();

    expect(calls, 2);

    refreshCompleter.complete(_detail('새 제목', '<p>새 본문</p>'));
    await tester.pump(const Duration(milliseconds: 300));
    await refreshFuture;
    await tester.pump();

    expect(find.text('새 제목'), findsOneWidget);
  });
}

final _detailArg = NoticeDetailArg.notice(
  category: NoticeCategory.general,
  id: 'notice-1',
);

SejongNoticeItem _item(String title) {
  return SejongNoticeItem(
    id: 'notice-1',
    title: title,
    categoryCode: NoticeCategory.general.type,
    categoryName: NoticeCategory.general.label,
    categoryType: NoticeCategory.general.type,
    writerName: '세종대학교',
    writtenAt: DateTime(2026, 6, 17),
    viewCount: 1,
    isNew: false,
    hasAttachment: false,
  );
}

SejongNoticeDetail _detail(String title, String content) {
  return SejongNoticeDetail(
    id: 'notice-1',
    title: title,
    categoryCode: NoticeCategory.general.type,
    categoryName: NoticeCategory.general.label,
    categoryType: NoticeCategory.general.type,
    content: content,
    writerName: '세종대학교',
    writtenAt: DateTime(2026, 6, 17),
    viewCount: 1,
    attachments: const [],
  );
}
