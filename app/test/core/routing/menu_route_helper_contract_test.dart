import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('routeByKey contracts', () {
    late String routeHelper;

    setUpAll(() {
      routeHelper = File(
        'lib/core/routing/menu_route_helper.dart',
      ).readAsStringSync();
    });

    test('home and service keys resolve to the canonical native screens', () {
      final expectations = <({String marker, String screen})>[
        (
          marker: "case 'inf.scheduleManagement':",
          screen: 'AcademicCalendarScreen',
        ),
        (marker: "case 'aca.classSchedule':", screen: 'TimetableScreen'),
        (marker: "case 'client.libraryFloors':", screen: 'LibraryListScreen'),
        (marker: "case 'client.libseat':", screen: 'LibseatScreen'),
        (marker: "key == 'client.sjpt'", screen: 'SjptScreen'),
        (marker: "case 'client.uCheckTab':", screen: 'UCheckScreen'),
        (marker: "case 'inf.notice.general':", screen: 'NoticesScreen'),
        (
          marker: "case 'inf.universityLife.schoolCafeteria':",
          screen: 'CafeteriaScreen',
        ),
      ];

      for (final entry in expectations) {
        expect(
          routeHelper,
          allOf(contains(entry.marker), contains(entry.screen)),
          reason: '${entry.marker} must keep using ${entry.screen}',
        );
      }
    });

    test(
      'notice shortcuts and notice leaves share NoticesScreen push path',
      () {
        expect(routeHelper, contains("case 'inf.notice.general':"));
        expect(routeHelper, contains("case 'inf.notice.academic':"));
        expect(
          routeHelper,
          contains(
            'push(const NoticesScreen(initial: NoticeCategory.general))',
          ),
        );
        expect(
          routeHelper,
          contains(
            'push(const NoticesScreen(initial: NoticeCategory.academic))',
          ),
        );
      },
    );

    test(
      'student id shortcut remains a tab switch instead of a duplicate screen',
      () {
        expect(routeHelper, contains("case 'client.studentIdTab':"));
        expect(routeHelper, contains('_switchTab(context, 1);'));
      },
    );
  });
}
