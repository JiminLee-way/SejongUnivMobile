import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friend_timetable_providers.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/screens/common_free_time_screen.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/widgets/timetable_grid.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

void main() {
  testWidgets('실제 친구 시간표 provider 결과만 공강 계산에 반영한다', (tester) async {
    final own = _timetable('own', Weekday.mon, 9, 10);
    final friends = [_friend('friend-1', '민수'), _friend('friend-2', '지윤')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendTimetableProvider.overrideWith((ref, args) async {
            if (args.friendId == 'friend-1') {
              return _timetable('friend-1', Weekday.tue, 11, 12);
            }
            return Timetable(semester: args.semester, courses: const []);
          }),
        ],
        child: MaterialApp(
          home: CommonFreeTimeScreen(
            ownTimetable: own,
            selectedFriends: friends,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('시간표가 없는 친구 1명은 제외됐어요'), findsOneWidget);
    expect(find.text('함께 비는 시간'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('주간 가용성'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('주간 가용성'), findsOneWidget);
    expect(find.text('2명'), findsOneWidget);
  });

  testWidgets('친구 시간표 로딩 중에는 계산 그리드 대신 skeleton을 보여준다', (tester) async {
    final pending = Completer<Timetable>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendTimetableProvider.overrideWith((ref, args) => pending.future),
        ],
        child: MaterialApp(
          home: CommonFreeTimeScreen(
            ownTimetable: _timetable('own', Weekday.mon, 9, 10),
            selectedFriends: [_friend('friend-1', '민수')],
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byType(TimetableGridSkeleton), findsOneWidget);
    expect(find.text('함께 비는 시간'), findsNothing);

    pending.complete(_timetable('friend-1', Weekday.tue, 11, 12));
    await tester.pump();
    await tester.pump();
  });

  testWidgets('친구 시간표 조회 오류는 해당 친구 제외 안내로 처리한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendTimetableProvider.overrideWith((ref, args) async {
            throw StateError('network');
          }),
        ],
        child: MaterialApp(
          home: CommonFreeTimeScreen(
            ownTimetable: _timetable('own', Weekday.mon, 9, 10),
            selectedFriends: [_friend('friend-1', '민수')],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('시간표가 없는 친구 1명은 제외됐어요'), findsOneWidget);
    expect(find.text('함께 비는 시간'), findsOneWidget);
  });
}

Friend _friend(String id, String name) {
  return Friend(id: id, name: name, major: '컴퓨터공학과', status: FriendStatus.free);
}

Timetable _timetable(String id, Weekday weekday, int startHour, int endHour) {
  return Timetable(
    semester: Semester.spring2026,
    courses: [
      Course(
        id: id,
        code: id,
        name: '테스트 강의',
        professor: '교수',
        location: '대양AI센터',
        palette: CoursePalette.crimson,
        times: [
          CourseTime(
            weekday: weekday,
            start: HMTime(startHour, 0),
            end: HMTime(endHour, 0),
          ),
        ],
      ),
    ],
  );
}
