import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_remote.dart';

/// `LibseatRemote.parseRoomListXml` 회귀 — 공개 PA 엔드포인트
/// (`seatRoomStatusListXML.php`)의 jqGrid XML 파싱.
///
/// 실제 응답 선두엔 UTF-8 BOM(U+FEFF)이 붙어 오므로 그 제거 + CDATA 값 추출 +
/// 잘못된 row 스킵을 확인한다.
void main() {
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
}
