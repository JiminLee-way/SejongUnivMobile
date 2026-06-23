import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/core/routing/menu_route_helper.dart';
import 'package:sejong_smart_campus/features/academic/domain/entities/academic_models.dart';
import 'package:sejong_smart_campus/features/academic/presentation/providers/academic_providers.dart';
import 'package:sejong_smart_campus/features/academic/presentation/screens/academic_calendar_screen.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

void main() {
  group('AcademicCalendarScreen', () {
    testWidgets('inf.scheduleManagement routes to native calendar screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialAcademicCalendarProvider.overrideWith(
              (ref, query) async => const <AcademicCalendarEvent>[],
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => routeByKey(context, 'inf.scheduleManagement'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('학사 캘린더'), findsOneWidget);
    });

    testWidgets('shows skeleton before loaded data', (tester) async {
      final completer = Completer<List<AcademicCalendarEvent>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialAcademicCalendarProvider.overrideWith(
              (ref, query) => completer.future,
            ),
          ],
          child: const MaterialApp(home: AcademicCalendarScreen()),
        ),
      );

      await tester.pump();
      expect(find.byType(Shimmer), findsWidgets);

      completer.complete([_event('하계 계절학기 수강신청')]);
      await tester.pumpAndSettle();

      expect(find.text('하계 계절학기 수강신청'), findsWidgets);
    });

    testWidgets('mode and category controls trigger new provider queries', (
      tester,
    ) async {
      final seen = <OfficialCalendarQuery>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialAcademicCalendarProvider.overrideWith((ref, query) async {
              seen.add(query);
              return [_event('1학기 강의평가')];
            }),
          ],
          child: const MaterialApp(home: AcademicCalendarScreen()),
        ),
      );

      await tester.pumpAndSettle();
      expect(seen.last.mode, AcademicCalendarMode.month);
      expect(seen.last.categoryCode, '0001');

      await tester.tap(find.text('연간일정'));
      await tester.pumpAndSettle();
      expect(seen.last.mode, AcademicCalendarMode.year);

      await tester.tap(find.text('대학'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('일반대학원').last);
      await tester.pumpAndSettle();
      expect(seen.last.categoryCode, '0002');
    });

    testWidgets('error state exposes retry and official page actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialAcademicCalendarProvider.overrideWith(
              (ref, query) => Future<List<AcademicCalendarEvent>>.error(
                StateError('network'),
              ),
            ),
          ],
          child: const MaterialApp(home: AcademicCalendarScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('학사일정을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.text('공식 페이지'), findsOneWidget);
    });

    testWidgets(
      'month grid draws selected overlay above bars and hides narrow split titles',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              officialCalendarMonthProvider.overrideWith(
                _June2026MonthNotifier.new,
              ),
              officialCalendarYearProvider.overrideWith(_Year2026Notifier.new),
              officialAcademicCalendarProvider.overrideWith((ref, query) async {
                return [
                  _eventRange(
                    '1학기 강의평가',
                    DateTime(2026, 6, 8),
                    DateTime(2026, 6, 29),
                  ),
                  _eventRange(
                    '1학기 기말고사 성적 열람 및 정정',
                    DateTime(2026, 6, 27),
                    DateTime(2026, 7, 1),
                  ),
                ];
              }),
            ],
            child: const MaterialApp(home: AcademicCalendarScreen()),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('14'));
        await tester.pumpAndSettle();

        const overlayKey = ValueKey(
          'academic-calendar-selected-day-overlay-positioned',
        );
        const selectedWeekKey = ValueKey(
          'academic-calendar-week-row:2026-6-14',
        );
        const selectedWeekBarKey = ValueKey(
          'academic-calendar-week-bar-positioned:1학기 강의평가:0-6',
        );
        final selectedWeek = tester.widget<Stack>(find.byKey(selectedWeekKey));
        final overlayIndex = selectedWeek.children.indexWhere(
          (child) => child.key == overlayKey,
        );
        final barIndex = selectedWeek.children.indexWhere(
          (child) => child.key == selectedWeekBarKey,
        );
        expect(barIndex, isNonNegative);
        expect(overlayIndex, greaterThan(barIndex));

        const narrowTitleKey = ValueKey(
          'academic-calendar-week-bar-title:1학기 기말고사 성적 열람 및 정정:6-6',
        );
        const narrowBarKey = ValueKey(
          'academic-calendar-week-bar:1학기 기말고사 성적 열람 및 정정:6-6',
        );
        expect(find.byKey(narrowBarKey), findsOneWidget);
        expect(find.byKey(narrowTitleKey), findsNothing);

        const wideTitleKey = ValueKey(
          'academic-calendar-week-bar-title:1학기 기말고사 성적 열람 및 정정:0-3',
        );
        expect(find.byKey(wideTitleKey), findsOneWidget);
      },
    );
  });
}

AcademicCalendarEvent _event(String title) {
  return _eventRange(title, DateTime(2026, 6, 8), DateTime(2026, 6, 29));
}

AcademicCalendarEvent _eventRange(String title, DateTime start, DateTime end) {
  return AcademicCalendarEvent(
    title: title,
    titleEng: '',
    startDate: start,
    endDate: end,
    categoryCode: '0001',
    categoryName: '학부',
    sourceYear: start.year,
    sourceMonth: start.month,
  );
}

class _June2026MonthNotifier extends OfficialCalendarMonthNotifier {
  @override
  DateTime build() => DateTime(2026, 6);
}

class _Year2026Notifier extends OfficialCalendarYearNotifier {
  @override
  int build() => 2026;
}
