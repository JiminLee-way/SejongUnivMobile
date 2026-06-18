import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target refresh screens do not use fixed 400ms refresh completion', () {
    const targetScreens = [
      'lib/features/cafeteria/presentation/screens/cafeteria_screen.dart',
      'lib/features/sjpt/presentation/screens/sjpt_screen.dart',
      'lib/features/support/presentation/screens/support_screen.dart',
      'lib/features/notifications/presentation/screens/notifications_screen.dart',
      'lib/features/study_room/presentation/screens/study_room_screen.dart',
      'lib/features/finance/presentation/screens/finance_screen.dart',
      'lib/features/academic/presentation/screens/grades_screen.dart',
      'lib/features/menu/presentation/screens/services_screen.dart',
    ];

    for (final path in targetScreens) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('milliseconds: 400')),
        reason: '$path should await provider futures, not a fixed delay',
      );
    }
  });

  test('list and card loading targets use shimmer skeletons', () {
    const targetScreens = [
      'lib/features/cafeteria/presentation/screens/cafeteria_screen.dart',
      'lib/features/sjpt/presentation/screens/sjpt_screen.dart',
      'lib/features/support/presentation/screens/support_screen.dart',
      'lib/features/notifications/presentation/screens/notifications_screen.dart',
      'lib/features/study_room/presentation/screens/study_room_screen.dart',
      'lib/features/finance/presentation/screens/finance_screen.dart',
      'lib/features/academic/presentation/screens/grades_screen.dart',
      'lib/features/menu/presentation/screens/services_screen.dart',
    ];

    for (final path in targetScreens) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('Shimmer'),
        reason: '$path should expose skeleton loading for list/card states',
      );
    }
  });
}
