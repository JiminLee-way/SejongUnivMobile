import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active screens do not reintroduce mock-only data paths', () {
    final guardedFiles = <String, List<String>>{
      'lib/features/timetable/presentation/screens/common_free_time_screen.dart':
          ['mockFriendTimetables', 'mock_timetable.dart'],
      'lib/features/library/presentation/screens/library_penalty_screen.dart': [
        'mockLibraryUsageHistory',
        'mock_library.dart',
      ],
      'lib/features/shell/presentation/screens/app_shell.dart': [
        'CommunityScreen(',
        'features/community/presentation/screens/community_screen.dart',
      ],
    };

    for (final entry in guardedFiles.entries) {
      final source = File(entry.key).readAsStringSync();
      for (final forbidden in entry.value) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason: '${entry.key} must not depend on $forbidden',
        );
      }
    }
  });
}
