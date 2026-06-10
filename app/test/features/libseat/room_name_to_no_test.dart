import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';

/// `libseatRoomNoFromName` 회귀 — mySeat.php 방 이름에서 반납/연장용 실 room_no.
///
/// 단순 숫자 추출("제4열람실A"→4)이던 버그를 막는다(반납/연장이 엉뚱한 방으로
/// 가면 실패). 매핑은 roomList 실측 고정.
void main() {
  group('libseatRoomNoFromName', () {
    test('제4열람실 A/B → 15/16 (절대 4가 아님)', () {
      expect(libseatRoomNoFromName('제4열람실A'), 15);
      expect(libseatRoomNoFromName('제4열람실B'), 16);
      expect(libseatRoomNoFromName('제4열람실A'), isNot(4));
    });

    test('층/기관 prefix + 공백이 섞인 실제 형태도 인식', () {
      expect(libseatRoomNoFromName('학술정보원 3F 제4열람실 A'), 15);
      expect(libseatRoomNoFromName('학술정보원 3F 제4열람실 B'), 16);
      expect(libseatRoomNoFromName('학술정보원 B1 제1열람실 A'), 11);
    });

    test('제1열람실 A/B → 11/12', () {
      expect(libseatRoomNoFromName('제1열람실A'), 11);
      expect(libseatRoomNoFromName('제1열람실B'), 12);
    });

    test('단일 열람실(A/B 없음) → 13/14/17/18', () {
      expect(libseatRoomNoFromName('제2열람실'), 13);
      expect(libseatRoomNoFromName('제3열람실'), 14);
      expect(libseatRoomNoFromName('제5열람실'), 17);
      expect(libseatRoomNoFromName('제6열람실'), 18);
    });

    test('인식 불가 이름은 0', () {
      expect(libseatRoomNoFromName('알 수 없음'), 0);
      expect(libseatRoomNoFromName(''), 0);
    });
  });
}
