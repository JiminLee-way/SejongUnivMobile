import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart';

/// 통합 열람실(제1=1112, 제4=1516) 가상 ID → 실 libseat room_no 복원 검증.
///
/// 회귀 방지: 가상 ID(1112/1516)를 그대로 setSeat.php에 보내면 서버가 "자율
/// 발권으로 모바일 좌석 예약을 이용하실 수 없습니다."로 거절한다(2026-05-30 버그).
void main() {
  group('resolveLibseatRoomNo', () {
    test('단일 열람실(2자리 실 room_no)은 그대로 반환', () {
      expect(resolveLibseatRoomNo(13, null), 13); // 제2열람실
      expect(resolveLibseatRoomNo(14, null), 14); // 제3열람실
      expect(resolveLibseatRoomNo(17, null), 17); // 제5열람실
      expect(resolveLibseatRoomNo(18, null), 18); // 제6열람실
      // wing 값이 있어도 2자리면 무시.
      expect(resolveLibseatRoomNo(13, 'A'), 13);
    });

    test('제1열람실(1112): A→11, B→12', () {
      expect(resolveLibseatRoomNo(1112, 'A'), 11);
      expect(resolveLibseatRoomNo(1112, 'B'), 12);
    });

    test('제4열람실(1516): A→15, B→16', () {
      expect(resolveLibseatRoomNo(1516, 'A'), 15);
      expect(resolveLibseatRoomNo(1516, 'B'), 16);
    });

    test('통합석인데 wing이 null이면 안전하게 A(앞 2자리)', () {
      expect(resolveLibseatRoomNo(1112, null), 11);
      expect(resolveLibseatRoomNo(1516, null), 15);
    });

    test('스크린샷 재현: 제4열람실 119번(wing A) → room_no 15', () {
      // 119 <= 146 이므로 asset상 wing A. 공식 사이트도 room_no=15로 발권.
      expect(resolveLibseatRoomNo(1516, 'A'), 15);
    });
  });
}
