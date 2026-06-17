import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/core/diagnostics/crash_report.dart';

void main() {
  CrashEvidence evidence(
    String reasonName, {
    int reason = 4,
    int timestampMillis = 1000,
    String processName = 'sejong.sejong_univ_station',
  }) {
    return CrashEvidence(
      reason: reason,
      reasonName: reasonName,
      timestampMillis: timestampMillis,
      processName: processName,
    );
  }

  group('CrashReport.selectReportableEvidence', () {
    test('ignores normal app exits and package updates', () {
      final selected = CrashReport.selectReportableEvidence([
        evidence('REASON_USER_REQUESTED', reason: 10, timestampMillis: 4000),
        evidence('REASON_USER_STOPPED', reason: 11, timestampMillis: 3000),
        evidence('REASON_PACKAGE_UPDATED', reason: 16, timestampMillis: 2000),
        evidence(
          'REASON_PACKAGE_STATE_CHANGE',
          reason: 15,
          timestampMillis: 1000,
        ),
      ]);

      expect(selected, isNull);
    });

    test('ignores low-memory, signaled, other, and unknown exits', () {
      final selected = CrashReport.selectReportableEvidence([
        evidence('REASON_LOW_MEMORY', reason: 3, timestampMillis: 4000),
        evidence('REASON_SIGNALED', reason: 2, timestampMillis: 3000),
        evidence('REASON_OTHER', reason: 13, timestampMillis: 2000),
        evidence('REASON_UNKNOWN', reason: 0, timestampMillis: 1000),
      ]);

      expect(selected, isNull);
    });

    test('reports crash, native crash, anr, and initialization failure', () {
      for (final reasonName in [
        'REASON_CRASH',
        'REASON_CRASH_NATIVE',
        'REASON_ANR',
        'REASON_INITIALIZATION_FAILURE',
      ]) {
        final selected = CrashReport.selectReportableEvidence([
          evidence(reasonName),
        ]);

        expect(selected?.reasonName, reasonName);
      }
    });

    test(
      'selects newest reportable exit when mixed with non-reportable exits',
      () {
        final selected = CrashReport.selectReportableEvidence([
          evidence('REASON_CRASH', timestampMillis: 1000),
          evidence('REASON_USER_REQUESTED', reason: 10, timestampMillis: 3000),
          evidence('REASON_ANR', reason: 6, timestampMillis: 2000),
        ]);

        expect(selected?.reasonName, 'REASON_ANR');
        expect(selected?.timestampMillis, 2000);
      },
    );

    test('does not return an acknowledged crash evidence again', () {
      final crash = evidence('REASON_CRASH', timestampMillis: 1000);

      final selected = CrashReport.selectReportableEvidence([
        crash,
      ], acknowledgedUntilMillis: crash.timestampMillis);

      expect(selected, isNull);
    });

    test('does not fall back to older acknowledged reportable evidence', () {
      final newerCrash = evidence('REASON_CRASH', timestampMillis: 2000);
      final olderCrash = evidence(
        'REASON_ANR',
        reason: 6,
        timestampMillis: 1000,
      );

      final selected = CrashReport.selectReportableEvidence([
        newerCrash,
        olderCrash,
      ], acknowledgedUntilMillis: newerCrash.timestampMillis);

      expect(selected, isNull);
    });

    test('reports newer evidence after an older acknowledgement', () {
      final newerCrash = evidence('REASON_CRASH', timestampMillis: 3000);
      final olderCrash = evidence(
        'REASON_ANR',
        reason: 6,
        timestampMillis: 1000,
      );

      final selected = CrashReport.selectReportableEvidence([
        newerCrash,
        olderCrash,
      ], acknowledgedUntilMillis: 2000);

      expect(selected?.reasonName, 'REASON_CRASH');
      expect(selected?.timestampMillis, 3000);
    });
  });

  group('CrashEvidence.fromNativeMap', () {
    test('parses native exit info map', () {
      final parsed = CrashEvidence.fromNativeMap({
        'reason': 4,
        'reasonName': 'REASON_CRASH',
        'timestamp': 1710000000000,
        'description': 'Process crashed',
        'importance': 100,
        'status': 0,
        'processName': 'sejong.sejong_univ_station',
      });

      expect(parsed, isNotNull);
      expect(parsed!.reasonName, 'REASON_CRASH');
      expect(parsed.timestampMillis, 1710000000000);
      expect(parsed.isReportable, isTrue);
      expect(parsed.toReportLog(), contains('REASON_CRASH'));
    });

    test('skips broken native rows', () {
      expect(
        CrashEvidence.fromNativeMap({
          'reasonName': 'REASON_CRASH',
          'timestamp': 1710000000000,
        }),
        isNull,
      );
      expect(
        CrashEvidence.fromNativeMap({
          'reason': 4,
          'reasonName': 'REASON_CRASH',
        }),
        isNull,
      );
    });
  });
}
