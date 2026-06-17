import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/app_update/presentation/providers/app_update_providers.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/home/domain/entities/event_card.dart';
import 'package:sejong_smart_campus/features/home/presentation/providers/home_events_providers.dart';
import 'package:sejong_smart_campus/features/home/presentation/providers/quick_actions_providers.dart';
import 'package:sejong_smart_campus/features/home/presentation/screens/home_screen.dart';
import 'package:sejong_smart_campus/features/home_widgets/presentation/providers/home_widgets_providers.dart';
import 'package:sejong_smart_campus/features/home_widgets/domain/entities/home_widget_models.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart'
    as libseat;
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';
import 'package:sejong_smart_campus/features/notices/presentation/providers/notice_providers.dart';
import 'package:sejong_smart_campus/features/notices/presentation/screens/notices_screen.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sejong_smart_campus/features/shell/presentation/screens/app_shell.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/providers/timetable_providers.dart';

void main() {
  testWidgets('공지 탭은 mock CommunityScreen이 아니라 실 공지 화면을 연다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          appUpdateStatusProvider.overrideWith(
            (ref) async => AppUpdateStatus.none,
          ),
          homeEventsProvider.overrideWith(_EmptyHomeEvents.new),
          homeBannersProvider.overrideWith((ref) async => const <HomeBanner>[]),
          quickActionsProvider.overrideWith(_EmptyQuickActions.new),
          libseatSyncProvider.overrideWithValue(_FakeLibseatSync()),
          mySeatProvider.overrideWith((ref) async => null),
          activeSeatReservationProvider.overrideWith((ref) => null),
          roomListProvider.overrideWith(
            (ref) async => const <libseat.ReadingRoom>[],
          ),
          homeNoticePreviewProvider.overrideWith(
            (ref) async => const <SejongNoticeItem>[],
          ),
          sejongNewsProvider.overrideWith(
            (ref) async => const <SejongNoticeItem>[],
          ),
          noticesByCategoryProvider.overrideWith((ref, category) async {
            return [
              SejongNoticeItem(
                id: 'notice-1',
                title: '실 API 공지 화면 항목',
                categoryCode: category.type,
                categoryName: category.label,
                categoryType: category.type,
                writerName: '세종대학교',
                writtenAt: DateTime(2026, 6, 17),
                viewCount: 1,
                isNew: false,
                hasAttachment: false,
              ),
            ];
          }),
          unreadCountProvider.overrideWith((ref) async => 0),
          combinedUnreadCountProvider.overrideWith((ref) => 0),
          timetableForSemesterProvider.overrideWith(
            (ref, semester) async =>
                Timetable(semester: semester, courses: const []),
          ),
          availableSemestersProvider.overrideWith(
            (ref) async => const <Semester>[],
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );

    await tester.pump();
    expect(find.text('커뮤니티'), findsNothing);
    expect(find.text('공지'), findsOneWidget);

    await tester.tap(find.text('공지'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(NoticesScreen), findsOneWidget);
    expect(find.text('공지'), findsWidgets);
    expect(find.byIcon(Symbols.campaign), findsOneWidget);
    expect(find.byIcon(Symbols.arrow_back), findsNothing);
    expect(find.text('실 API 공지 화면 항목'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NoticesScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

class _EmptyHomeEvents extends HomeEventsNotifier {
  @override
  Future<List<EventCard>> build() async => const [];
}

class _EmptyQuickActions extends QuickActionsNotifier {
  @override
  Future<List<String>> build() async => const [];
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
