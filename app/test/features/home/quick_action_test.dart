import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/home/domain/entities/quick_action.dart';

void main() {
  group('home quick actions', () {
    test('default shortcuts match the requested home order', () {
      expect(kDefaultQuickActionKeys, [
        'inf.scheduleManagement',
        'aca.classSchedule',
        'client.libraryFloors',
        'client.libseat',
        'inf.universityLife.schoolCafeteria',
        'client.sjpt',
        'client.jiphyunCampus',
        'client.studentIdTab',
        'inf.notice.general',
        'inf.notice.academic',
      ]);
    });

    test('new shortcuts have stable labels and tab routing metadata', () {
      final academicCalendar = resolveQuickActionInfo(
        'inf.scheduleManagement',
        const [],
      );
      final studentId = resolveQuickActionInfo('client.studentIdTab', const []);
      final generalNotice = resolveQuickActionInfo(
        'inf.notice.general',
        const [],
      );
      final academicNotice = resolveQuickActionInfo(
        'inf.notice.academic',
        const [],
      );
      final facilityRental = resolveQuickActionInfo('client.sjpt', const []);

      expect(academicCalendar.label, '학사캘린더');
      expect(studentId.label, '학생증');
      expect(studentId.tabIndex, 1);
      expect(generalNotice.label, '일반공지');
      expect(academicNotice.label, '학사공지');
      expect(facilityRental.label, '학교시설대여');
    });

    test('saved club shortcut is migrated to school facility rental', () {
      final normalized = normalizeQuickActionKeys([
        'aca.classSchedule',
        'client.club',
        'client.sjpt',
        'client.jiphyunCampus',
      ]);

      expect(normalized, [
        'aca.classSchedule',
        'client.sjpt',
        'client.jiphyunCampus',
      ]);
    });

    test('saved legacy default shortcuts migrate to the new default order', () {
      final migrated = migrateSavedQuickActionKeys(
        kLegacyDefaultQuickActionKeys,
      );

      expect(migrated, kDefaultQuickActionKeys);
    });

    test('custom shortcut order is preserved when loading saved shortcuts', () {
      const saved = [
        'client.jiphyunCampus',
        'client.sjpt',
        'aca.classSchedule',
      ];

      expect(migrateSavedQuickActionKeys(saved), saved);
    });
  });
}
