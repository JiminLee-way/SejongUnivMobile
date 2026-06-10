import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_remote.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';

/// `LibseatRemote.parseSeatMap` 회귀 테스트.
///
/// 실 libseat `seatMap.php`는 모든 좌석을 `<td class="desk">`(사용가능)로 렌더한
/// 뒤, 페이지 하단 인라인 `<script>`가 브라우저에서 점유 좌석의 class를
/// `..._over`로 덮어쓴다. 정적 파서가 이 스크립트를 못 읽어 전 좌석이 available로
/// 보이던 버그(제2·3·5·6열람실)를 막는다.
const _seatMapHtml = '''
<html><body>
<table border="0">
<tr>
<td id=1 class="desk"><p class="font_align"><a href="javascript:setSeat('13','1');">1</a></p></td>
<td id=2 class="desk"><p class="font_align"><a href="javascript:setSeat('13','2');">2</a></p></td>
<td id=3 class="desk"><p class="font_align"><a href="javascript:setSeat('13','3');">3</a></p></td>
<td id=4 class="desk"><p class="font_align"><a href="javascript:setSeat('13','4');">4</a></p></td>
</tr>
</table>
<script>
if(document.getElementById('1')){
 var clsName = document.getElementById('1').className;
 document.getElementById('1').setAttribute("class",clsName+"_over");
}
if(document.getElementById('3')){
 var clsName = document.getElementById('3').className;
 document.getElementById('3').setAttribute("class",clsName+"_over");
}
</script>
</body></html>
''';

void main() {
  group('LibseatRemote.parseSeatMap', () {
    test('정적 HTML의 desk 좌석 + 인라인 _over 점유를 모두 복원', () {
      final seats = LibseatRemote.parseSeatMap(_seatMapHtml, 13);
      expect(seats.length, 4);
      final byNo = {for (final s in seats) s.seatNo: s.status};
      // 인라인 스크립트가 _over 처리한 좌석 = 사용중.
      expect(byNo['1'], SeatStatus.used);
      expect(byNo['3'], SeatStatus.used);
      // 나머지는 사용가능.
      expect(byNo['2'], SeatStatus.available);
      expect(byNo['4'], SeatStatus.available);
    });

    test('점유 좌석 수가 정적 desk 수보다 0이면(스크립트 없음) 전부 available', () {
      const noScript = '''
<table><tr>
<td id=1 class="desk"><a href="javascript:setSeat('14','1');">1</a></td>
<td id=2 class="desk"><a href="javascript:setSeat('14','2');">2</a></td>
</tr></table>''';
      final seats = LibseatRemote.parseSeatMap(noScript, 14);
      expect(seats.length, 2);
      expect(seats.every((s) => s.status == SeatStatus.available), isTrue);
    });

    test('좌석은 번호 오름차순 정렬', () {
      final seats = LibseatRemote.parseSeatMap(_seatMapHtml, 13);
      final nums = seats.map((s) => int.parse(s.seatNo)).toList();
      final sorted = [...nums]..sort();
      expect(nums, sorted);
    });

    test('빈 응답은 빈 list', () {
      expect(LibseatRemote.parseSeatMap('', 13), isEmpty);
    });
  });
}
