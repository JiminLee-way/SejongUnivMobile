import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/ucheck/data/repositories/ucheck_repository_impl.dart';

void main() {
  group('ucheck attendance error messages', () {
    test('attendance_not_time server code is shown as Korean user copy', () {
      expect(
        ucheckFailureReasonForServerCode('error.api.attendance_not_time'),
        '출석 체크 시간이 아닙니다.',
      );
    });

    test('unknown server codes keep diagnostic code', () {
      expect(
        ucheckFailureReasonForServerCode('error.api.unknown'),
        '서버 거절: error.api.unknown',
      );
    });
  });
}
