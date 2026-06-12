import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_remote.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';

/// `LibseatRemote.parseRoomListHtml` 회귀 — 모바일 MA roomList 표시값 파싱.
///
/// 공개 PA XML은 고정석을 포함한 값을 주므로, 사용자가 실제로 보는
/// `roomList.php`의 `<h5>제N열람실A used / total</h5>`를 기준으로 삼는다.
void main() {
  group('LibseatRemote.parseRoomListHtml', () {
    const sampleHtml = '''
<section class="main-lib">
  <div class="white-label">
    <a href="./seatMap.php?param_room_no=11&amp;token=redacted">
      <h5>제1열람실A 59 / 87</h5>
    </a>
  </div>
  <div class="white-label">
    <a href="./seatMap.php?param_room_no=12&amp;token=redacted">
      <h5>제1열람실B 67 / 102</h5>
    </a>
  </div>
  <div class="white-label">
    <a href="./seatMap.php?param_room_no=13&amp;token=redacted">
      <h5>제2열람실 87 / 111</h5>
    </a>
  </div>
</section>
''';

    test('모바일 roomList 표시값에서 roomNo/name/used/total을 파싱', () {
      final rooms = LibseatRemote.parseRoomListHtml(sampleHtml);
      expect(rooms.length, 3);

      expect(rooms[0].roomNo, 11);
      expect(rooms[0].name, '제1열람실A');
      expect(rooms[0].used, 59);
      expect(rooms[0].total, 87);

      expect(rooms[1].roomNo, 12);
      expect(rooms[1].name, '제1열람실B');
      expect(rooms[1].used, 67);
      expect(rooms[1].total, 102);

      expect(rooms[2].roomNo, 13);
      expect(rooms[2].name, '제2열람실');
      expect(rooms[2].used, 87);
      expect(rooms[2].total, 111);
    });

    test('used는 0..total 범위로 보정하고 total이 깨진 row는 스킵', () {
      const broken = '''
<a href="./seatMap.php?param_room_no=11"><h5>제1열람실A 999 / 87</h5></a>
<a href="./seatMap.php?param_room_no=12"><h5>제1열람실B -2 / 102</h5></a>
<a href="./seatMap.php?param_room_no=13"><h5>제2열람실 3 / 0</h5></a>
<a href="./seatMap.php?param_room_no=14"><h5>깨진 행</h5></a>
''';
      final rooms = LibseatRemote.parseRoomListHtml(broken);
      expect(rooms.length, 2);
      expect(rooms[0].used, 87);
      expect(rooms[0].free, 0);
      expect(rooms[0].usageRatio, 1);
      expect(rooms[1].used, 0);
      expect(rooms[1].free, 102);
      expect(rooms[1].usageRatio, 0);
    });

    test('A/B 열람실은 base name 기준으로 합산', () {
      final merged = mergeReadingRoomsByBase(
        LibseatRemote.parseRoomListHtml(sampleHtml),
      );

      expect(merged.length, 2);
      expect(merged[0].name, '제1열람실');
      expect(merged[0].used, 126);
      expect(merged[0].total, 189);
      expect(merged[0].free, 63);

      expect(merged[1].name, '제2열람실');
      expect(merged[1].used, 87);
      expect(merged[1].total, 111);
    });
  });

  // 실제 응답 형태(BOM 포함). 값은 CDATA.
  const sample =
      '﻿'
      "<?xml version='1.0' encoding='utf-8'?>\n"
      '<root><data><page>1</page><total></total><records></records></data>'
      '<item><strRoomNo><![CDATA[11]]></strRoomNo>'
      '<strRoomNm><![CDATA[제1열람실A]]></strRoomNm>'
      '<strTotalSeat><![CDATA[189]]></strTotalSeat>'
      '<strUseSeat><![CDATA[120]]></strUseSeat>'
      '<strFixSeat><![CDATA[102]]></strFixSeat>'
      '<strRemainSeat><![CDATA[69]]></strRemainSeat>'
      '<strMapUrl><![CDATA[../MA/seatMap.php?param_room_no=11]]></strMapUrl></item>'
      '<item><strRoomNo><![CDATA[12]]></strRoomNo>'
      '<strRoomNm><![CDATA[제1열람실B]]></strRoomNm>'
      '<strTotalSeat><![CDATA[110]]></strTotalSeat>'
      '<strUseSeat><![CDATA[26]]></strUseSeat>'
      '<strRemainSeat><![CDATA[84]]></strRemainSeat></item>'
      '<item><strRoomNo><![CDATA[13]]></strRoomNo>'
      '<strRoomNm><![CDATA[제2열람실]]></strRoomNm>'
      '<strTotalSeat><![CDATA[111]]></strTotalSeat>'
      '<strUseSeat><![CDATA[55]]></strUseSeat></item></root>';

  group('LibseatRemote.parseRoomListXml legacy', () {
    test('BOM 제거 + CDATA 값 추출 + 3개 열람실 파싱', () {
      final rooms = LibseatRemote.parseRoomListXml(sample);
      expect(rooms.length, 3);

      final r1 = rooms.first;
      expect(r1.roomNo, 11);
      expect(r1.name, '제1열람실A');
      expect(r1.used, 120);
      expect(r1.total, 189);
      // free = total - used (strRemainSeat 69와 일치).
      expect(r1.free, 69);

      expect(rooms[1].name, '제1열람실B');
      expect(rooms[1].used, 26);
      expect(rooms[1].total, 110);
      expect(rooms[2].roomNo, 13);
      expect(rooms[2].name, '제2열람실');
    });

    test('빈/깨진 입력은 빈 목록(throw 없음)', () {
      expect(LibseatRemote.parseRoomListXml(''), isEmpty);
      expect(LibseatRemote.parseRoomListXml('﻿   '), isEmpty);
    });

    test('필수 필드 누락 row는 스킵', () {
      const broken =
          '<root>'
          '<item><strRoomNm><![CDATA[이름만]]></strRoomNm></item>' // 좌석 수 없음 → skip
          '<item><strRoomNo><![CDATA[18]]></strRoomNo>'
          '<strRoomNm><![CDATA[제6열람실]]></strRoomNm>'
          '<strTotalSeat><![CDATA[165]]></strTotalSeat>'
          '<strUseSeat><![CDATA[39]]></strUseSeat></item></root>';
      final rooms = LibseatRemote.parseRoomListXml(broken);
      expect(rooms.length, 1);
      expect(rooms.single.roomNo, 18);
    });
  });
}
