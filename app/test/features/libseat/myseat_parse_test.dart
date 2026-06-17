import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_remote.dart';

/// `LibseatRemote.parseMySeat` 회귀.
///
/// mySeat.php엔 시설 미예약 카드의 "발권·예약 내용이 없습니다."가 열람실 좌석이
/// 있어도 항상 들어있어, 그걸로 null 판정하면 모든 발권이 false null이 되던
/// 버그(홈 카드/이용내역 안 뜸)를 막는다.
const _activeHtml = '''
<html><body>
<!-- White Card 01: 활성 열람실 좌석 -->
<section class="main-lib"><div class="white-card-container">
  <div class="top-card"><h6>열람실</h6><h6>2026.05.30</h6></div>
  <div class="middle-card"><h3>제4열람실A</h3></div>
  <div class="bottom-card">
    <div class="bc-data"><h6>좌석번호</h6><h4>61번</h4></div>
    <div class="bc-data"><h6>사용시간</h6><h4>15:40 ~ 21:40</h4></div>
    <div class="bc-data"><h6>연장 횟 수</h6><p><span>0회 (2회 남음)</span></p></div>
  </div>
</div></section>
<!-- White Card 03: 시설 미예약 (decoy) -->
<section class="main-lib"><div class="white-card-container">
  <div class="middle-alert"><h4>발권·예약 내용이 없습니다.</h4></div>
</div></section>
</body></html>
''';

const _noSeatHtml = '''
<html><body>
<section class="main-lib"><div class="white-card-container">
  <div class="middle-alert"><h4>발권·예약 내용이 없습니다.</h4></div>
</div></section>
</body></html>
''';

const _crossMidnightHtml = '''
<html><body>
<section class="main-lib"><div class="white-card-container">
  <div class="top-card"><h6>열람실</h6><h6>2026.03.27</h6></div>
  <div class="middle-card"><h3>제4열람실B</h3></div>
  <div class="bottom-card">
    <div class="bc-data"><h6>좌석번호</h6><h4>174번</h4></div>
    <div class="bc-data"><h6>사용시간</h6><h4>20:55 ~ 02:56</h4></div>
    <div class="bc-data"><h6>연장 횟 수</h6><p><span>1회 (1회 남음)</span></p></div>
  </div>
</div></section>
</body></html>
''';

void main() {
  group('LibseatRemote.parseMySeat', () {
    test('decoy "없습니다"가 있어도 활성 열람실 좌석을 정확히 파싱', () {
      final s = LibseatRemote.parseMySeat(_activeHtml);
      expect(s, isNotNull);
      expect(s!.roomName, '제4열람실A');
      expect(s.roomNo, 15); // 제4열람실A → 실 room_no
      expect(s.seatNo, '61'); // "61번" → 숫자만
      expect(s.startTime, '15:40');
      expect(s.endTime, '21:40');
      expect(s.extensionsUsed, 0);
      expect(s.issuedDate, DateTime(2026, 5, 30));
    });

    test('startedAt/expiresAt가 서버 카드 날짜 기준으로 계산', () {
      final s = LibseatRemote.parseMySeat(_activeHtml)!;
      expect(s.startedAt, DateTime(2026, 5, 30, 15, 40));
      expect(s.expiresAt, DateTime(2026, 5, 30, 21, 40));
    });

    test('자정 넘김 사용시간은 종료일을 다음날로 계산', () {
      final s = LibseatRemote.parseMySeat(_crossMidnightHtml);
      expect(s, isNotNull);
      expect(s!.roomName, '제4열람실B');
      expect(s.roomNo, 16);
      expect(s.seatNo, '174');
      expect(s.startedAt, DateTime(2026, 3, 27, 20, 55));
      expect(s.expiresAt, DateTime(2026, 3, 28, 2, 56));
    });

    test('활성 좌석 없으면(빈 카드만) null', () {
      expect(LibseatRemote.parseMySeat(_noSeatHtml), isNull);
      expect(LibseatRemote.parseMySeat(''), isNull);
    });
  });
}
