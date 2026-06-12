import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;

import 'package:sejong_smart_campus/core/network/service_urls.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/facility_models.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';

/// 열람실 모바일 페이지 HTML parsing.
///
/// 백엔드가 JSON을 안 주므로 jQuery + Bootstrap 기반의 server-rendered
/// HTML을 DOM parsing해서 도메인 모델로 변환한다.
///
/// 모든 호출은 sjapp의 reading-room-token이 query param `token`으로 부착됨.
/// 토큰은 [LibseatTokenSource]가 sjapp에서 받아와 캐시.
class LibseatRemote {
  LibseatRemote({required this.tokenSource})
    : _dio = Dio(
        BaseOptions(
          baseUrl: ServiceUrls.libseat,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 12),
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Sejong Smart Campus) AppleWebKit/537.36',
          },
        ),
      );

  final LibseatTokenSource tokenSource;
  final Dio _dio;

  /// `GET /mobile/MA/roomList.php?token=` → 8개 열람실.
  ///
  /// 공개 PA XML은 `strUseSeat`가 고정석을 포함해 모바일 화면의
  /// `제1열람실A 58 / 87` 기준값과 달랐다. 사용자가 실제로 보는 모바일
  /// roomList의 `<h5>제N열람실A used / total</h5>`를 SSOT로 사용한다.
  Future<List<ReadingRoom>> fetchRoomList() async {
    final token = await tokenSource.getToken();
    final res = await _dio.get<String>(
      '/mobile/MA/roomList.php',
      queryParameters: {'token': token},
    );
    return parseRoomListHtml(res.data ?? '');
  }

  /// 모바일 roomList HTML → [ReadingRoom] 목록. 순수 함수(테스트용).
  ///
  /// 구조:
  /// `<a href="./seatMap.php?param_room_no=11&token=..."><h5>제1열람실A 59 / 87</h5>`.
  /// token 값은 읽지 않고 `param_room_no`, h5 표시 텍스트만 파싱한다.
  static List<ReadingRoom> parseRoomListHtml(String body) {
    if (body.trim().isEmpty) return const [];
    final doc = html_parser.parse(body);
    final out = <ReadingRoom>[];
    final roomRe = RegExp(r'param_room_no=(\d+)');
    final labelRe = RegExp(r'^(.+?열람실\s*[A-Za-z]?)\s+(-?\d+)\s*/\s*(-?\d+)$');

    for (final a in doc.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      final roomNo = int.tryParse(roomRe.firstMatch(href)?.group(1) ?? '');
      if (roomNo == null) continue;

      final labelText = (a.querySelector('h5')?.text ?? a.text)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final m = labelRe.firstMatch(labelText);
      if (m == null) continue;
      final name = m.group(1)!.replaceAll(RegExp(r'\s+'), '').trim();
      final used = int.tryParse(m.group(2)!);
      final total = int.tryParse(m.group(3)!);
      if (name.isEmpty || used == null || total == null || total <= 0) {
        continue;
      }
      out.add(
        ReadingRoom(roomNo: roomNo, name: name, used: used, total: total),
      );
    }
    return out;
  }

  /// jqGrid XML → [ReadingRoom] 목록. 순수 함수(테스트용).
  ///
  /// item 마다 strRoomNo·strRoomNm·strTotalSeat·strUseSeat·strRemainSeat 필드가
  /// CDATA로 담겨 온다(strUseSeat=사용, strRemainSeat=잔여=total-used). 형식:
  /// ```
  /// <root><data>…</data>
  ///   <item><strRoomNo>11</strRoomNo><strRoomNm>제1열람실A</strRoomNm>
  ///     <strTotalSeat>189</strTotalSeat><strUseSeat>120</strUseSeat></item>…
  /// </root>
  /// ```
  /// 응답 선두에 UTF-8 BOM이 붙어 와 제거 후 파싱한다.
  static List<ReadingRoom> parseRoomListXml(String body) {
    var src = body;
    // 선행 BOM(U+FEFF)/zero-width 제거 — 없으면 XmlDocument.parse가 던진다.
    while (src.isNotEmpty &&
        (src.codeUnitAt(0) == 0xFEFF || src.codeUnitAt(0) == 0x200B)) {
      src = src.substring(1);
    }
    src = src.trimLeft();
    if (src.isEmpty) return const [];
    final doc = xml.XmlDocument.parse(src);
    final out = <ReadingRoom>[];
    for (final item in doc.findAllElements('item')) {
      String t(String tag) {
        for (final e in item.findElements(tag)) {
          return e.innerText.trim();
        }
        return '';
      }

      final roomNo = int.tryParse(t('strRoomNo'));
      final total = int.tryParse(t('strTotalSeat'));
      final used = int.tryParse(t('strUseSeat'));
      final name = t('strRoomNm');
      if (roomNo == null || total == null || used == null || name.isEmpty) {
        continue;
      }
      out.add(
        ReadingRoom(roomNo: roomNo, name: name, used: used, total: total),
      );
    }
    return out;
  }

  /// `GET /mobile/MA/seatMap.php?param_room_no={}&token={}` → 좌석 list.
  ///
  /// 좌석 cell의 원본 구조는 `<div class="desk|desk_over"><p><a
  /// href="javascript:setSeat('11','189');">189</a></p></div>` 였으나, libseat가
  /// class를 자주 바꿔 셀렉터 의존이 깨지기 쉽다. 따라서 **setSeat() 호출이
  /// 들어있는 모든 a 태그**를 anchor로 잡고, 상위 4단계 ancestor의 className을
  /// 누적해 `over/fix/off` 키워드로 status를 판정 — 셀렉터 변경에 견고.
  Future<List<Seat>> fetchSeatMap(int roomNo) async {
    final token = await tokenSource.getToken();
    final res = await _dio.get<String>(
      '/mobile/MA/seatMap.php',
      queryParameters: {'param_room_no': roomNo, 'token': token},
    );
    return parseSeatMap(res.data ?? '', roomNo);
  }

  /// `seatMap.php` HTML → 좌석 list. 네트워크와 분리된 순수 파서(단위 테스트 대상).
  ///
  /// **점유 상태는 정적 HTML에 없다.** 모든 좌석 cell이 `<td class="desk">`(=사용
  /// 가능)로 렌더되고, 페이지 하단 인라인 `<script>`가 *브라우저에서*
  /// `document.getElementById('109').setAttribute("class", clsName+"_over")` 식으로
  /// 점유 좌석의 class를 덮어쓴다. html 파서는 JS를 실행하지 않으므로 그대로
  /// 긁으면 전 좌석이 available로 보였다(제2·3·5·6열람실 "전부 예약가능" 버그).
  /// → 정적 td-class 판정에 더해 인라인 스크립트의 className 변형
  /// (`_over`=사용중, `_fix`=고정석, `_off`=사용불가)을 직접 파싱해 복원한다.
  static List<Seat> parseSeatMap(String body, int roomNo) {
    final doc = html_parser.parse(body);
    // href="javascript:setSeat(...)" 또는 onclick="setSeat(...)" 둘 다 대응.
    // 따옴표 유무 (single/double/없음)도 너그럽게.
    final argRe = RegExp(
      r'''setSeat\(\s*['"]?(\d+)['"]?\s*,\s*['"]?(\d+)['"]?\s*\)''',
    );
    final statusBySeat = <String, SeatStatus>{};
    final order = <String>[];
    for (final a in doc.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      final onclick = a.attributes['onclick'] ?? '';
      final m = argRe.firstMatch('$href $onclick');
      if (m == null) continue;
      final seatNo = m.group(2)!;
      // 상위 4단계까지 className을 누적해 status 키워드 탐색(td-class fallback).
      final classes = StringBuffer(a.className);
      var p = a.parent;
      var depth = 0;
      while (p != null && depth < 4) {
        classes.write(' ${p.className}');
        p = p.parent;
        depth++;
      }
      final c = classes.toString();
      final status =
          c.contains('over') || c.contains('_use') || c.contains('chk')
          ? SeatStatus.used
          : c.contains('fix')
          ? SeatStatus.fixed
          : c.contains('off')
          ? SeatStatus.disabled
          : SeatStatus.available;
      if (!statusBySeat.containsKey(seatNo)) order.add(seatNo);
      statusBySeat[seatNo] = status;
    }
    // 인라인 스크립트 점유 오버라이드:
    //   getElementById('109').setAttribute("class", clsName+"_over")
    // (var clsName = ...getElementById('109').className; 읽기 줄은 .setAttribute가
    //  없어 매칭되지 않으므로 변형 줄만 잡힌다.)
    final occRe = RegExp(
      r'''getElementById\(\s*['"](\d+)['"]\s*\)\s*\.\s*setAttribute\(\s*['"]class['"]\s*,\s*\w+\s*\+\s*['"]_(\w+)['"]''',
    );
    for (final m in occRe.allMatches(body)) {
      final seatNo = m.group(1)!;
      final suffix = m.group(2)!.toLowerCase();
      final st =
          suffix.contains('over') ||
              suffix.contains('use') ||
              suffix.contains('chk')
          ? SeatStatus.used
          : suffix.contains('fix')
          ? SeatStatus.fixed
          : suffix.contains('off') ||
                suffix.contains('disable') ||
                suffix.contains('ban')
          ? SeatStatus.disabled
          : null;
      if (st == null) continue;
      if (!statusBySeat.containsKey(seatNo)) order.add(seatNo);
      statusBySeat[seatNo] = st;
    }
    final out = [
      for (final seatNo in order)
        Seat(roomNo: roomNo, seatNo: seatNo, status: statusBySeat[seatNo]!),
    ];
    // 좌석 번호 정렬 (숫자 기준).
    out.sort((a, b) {
      final x = int.tryParse(a.seatNo) ?? 0;
      final y = int.tryParse(b.seatNo) ?? 0;
      return x.compareTo(y);
    });
    return out;
  }

  /// `GET /mobile/MA/mySeat.php?token={}` → 현재 발권 정보.
  ///
  /// 활성 발권이 없으면 null. 파싱은 순수 함수 [parseMySeat]에 위임(테스트용).
  Future<MySeat?> fetchMySeat() async {
    final token = await tokenSource.getToken();
    final res = await _dio.get<String>(
      '/mobile/MA/mySeat.php',
      queryParameters: {'token': token},
    );
    return parseMySeat(res.data ?? '');
  }

  /// mySeat.php HTML → 활성 열람실 좌석 (네트워크 분리, 단위 테스트 대상).
  ///
  /// **null 판정 주의**: 페이지엔 시설(스터디룸/시네마룸/S-Lounge) 미예약 카드의
  /// "발권·예약 내용이 없습니다."가 *열람실 좌석이 있어도 항상* 들어있다(White
  /// Card 03 등 다른 탭). 그 문자열로 null 판정하면 모든 열람실 발권이 false
  /// null이 돼 홈 카드/이용내역이 안 뜬다(2026-05-30 버그). 활성 좌석은
  /// `.middle-card`의 룸명(제N열람실)으로 판정.
  ///
  /// 실제 카드 구조:
  /// ```
  /// <div class="top-card"><h6>열람실</h6><h6>2026.05.30</h6></div>  // 라벨/날짜
  /// <div class="middle-card"><h3>제4열람실A</h3></div>              // 룸명
  /// <div class="bottom-card">
  ///   <div class="bc-data"><h6>좌석번호</h6><h4>61번</h4></div>
  ///   <div class="bc-data"><h6>사용시간</h6><h4>15:40 ~ 21:40</h4></div>
  ///   <div class="bc-data"><h6>연장 횟 수</h6><p><span>0회 (2회 남음)</p></div>
  /// </div>
  /// ```
  /// (top-card의 '열람실'은 라벨이고 그 옆 값은 날짜라 룸명이 아니다.)
  static MySeat? parseMySeat(String body) {
    if (body.trim().isEmpty) return null;
    final doc = html_parser.parse(body);

    // 활성 좌석 룸명 = '열람실'을 포함하는 .middle-card 텍스트.
    String? roomName;
    for (final mc in doc.querySelectorAll('.middle-card')) {
      final t = mc.text.trim();
      if (t.contains('열람실')) {
        roomName = t;
        break;
      }
    }
    if (roomName == null) return null;

    // .bc-data 라벨 → 값 (h6 라벨 텍스트를 제거한 나머지).
    String bcValue(String label) {
      final wantKey = label.replaceAll(' ', '');
      for (final bc in doc.querySelectorAll('.bc-data')) {
        final h6 = bc.querySelector('h6');
        if (h6 == null) continue;
        if (h6.text.trim().replaceAll(' ', '') != wantKey) continue;
        return bc.text.trim().replaceFirst(h6.text.trim(), '').trim();
      }
      return '';
    }

    final seat = bcValue('좌석번호').replaceAll(RegExp(r'[^0-9]'), '');
    if (seat.isEmpty) return null;
    final times = bcValue('사용시간').split('~').map((s) => s.trim()).toList();
    final extMatch = RegExp(r'(\d+)').firstMatch(bcValue('연장 횟 수'));

    String? reserveNo;
    final rnMatch = RegExp(r'\b(\d{16,20})\b').firstMatch(body);
    if (rnMatch != null) reserveNo = rnMatch.group(1);

    return MySeat(
      roomNo: libseatRoomNoFromName(roomName),
      roomName: roomName,
      seatNo: seat,
      startTime: times.isNotEmpty ? times[0] : '',
      endTime: times.length > 1 ? times[1] : '',
      extensionsUsed: extMatch != null ? int.parse(extMatch.group(1)!) : 0,
      reserveNo: reserveNo,
    );
  }

  /// mySeat.php 열람실 탭(tab-content[0])의 이용 이력.
  Future<List<SeatHistoryEntry>> fetchSeatHistory() async {
    final token = await tokenSource.getToken();
    final res = await _dio.get<String>(
      '/mobile/MA/mySeat.php',
      queryParameters: {'token': token},
    );
    return parseSeatHistory(res.data ?? '');
  }

  /// mySeat.php HTML → 열람실 이용 이력 (네트워크 분리, 테스트용).
  ///
  /// 첫 번째 `.tab-content`가 열람실 탭(나머지는 스터디룸/시네마룸/S-Lounge —
  /// [fetchMyFacilityReservations]가 담당). 각 `.item` 구조:
  /// ```
  /// <div class='item'><div class='date'>2026.05.30</div>
  ///   <div class='info'><div class='time'>15:40~21:40</div>
  ///     <div class='room'>제4열람실A</div></div>
  ///   <div class='status confirm'>사용중</div></div>
  /// ```
  static List<SeatHistoryEntry> parseSeatHistory(String body) {
    if (body.trim().isEmpty) return const [];
    final doc = html_parser.parse(body);
    final tabs = doc.querySelectorAll('.tab-content');
    if (tabs.isEmpty) return const [];
    final out = <SeatHistoryEntry>[];
    for (final item in tabs.first.querySelectorAll('.item')) {
      final date = item.querySelector('.date')?.text.trim() ?? '';
      final time = item.querySelector('.info .time')?.text.trim() ?? '';
      final room = item.querySelector('.info .room')?.text.trim() ?? '';
      final status = item.querySelector('.status')?.text.trim() ?? '';
      if (date.isEmpty || time.isEmpty) continue;
      out.add(
        SeatHistoryEntry(
          date: date,
          timeRange: time,
          roomName: room,
          status: status,
        ),
      );
    }
    return out;
  }

  /// mySeat.php에서 시설 예약 내역만 추출.
  ///
  /// HTML 구조: `.tabs > .tab-btn` 4개(열람실/스터디룸/시네마룸/S-Lounge) +
  /// `.tab-wrapper > .tab-content` 4개. 첫 번째 tab-content는 열람실 좌석
  /// 이력이므로 skip — 사용자 요구상 시설(스터디룸/시네마룸/S-Lounge)만 노출.
  ///
  /// 각 .item:
  /// ```
  /// <div class='item'>
  ///   <div class='date'>2026.05.26</div>
  ///   <div class='info'>
  ///     <div class='time'>18:00 ~ 20:00</div>
  ///     <div class='room'>S1층 04스터디룸</div>
  ///   </div>
  ///   <div class='status confirm'>예약취소</div>
  /// </div>
  /// ```
  ///
  /// 카테고리는 탭 순서로 결정 — index 1=studyRoom, 2=cinema, 3=sLounge.
  /// (안전망: room 라벨의 "S1층"/"S2층"/"S3층" prefix로 cross-check.)
  ///
  /// reserveNo는 .item 내부의 `cancelSroom(...)` JS 호출 인자에서 추출.
  Future<List<FacilityReservation>> fetchMyFacilityReservations() async {
    final token = await tokenSource.getToken();
    final res = await _dio.get<String>(
      '/mobile/MA/mySeat.php',
      queryParameters: {'token': token},
    );
    final body = res.data ?? '';
    final doc = html_parser.parse(body);
    final tabContents = doc.querySelectorAll('.tab-content');
    if (tabContents.length < 2) return const [];

    final out = <FacilityReservation>[];
    // 1=스터디룸, 2=시네마룸, 3=S-Lounge.
    const tabCategoryMap = {
      1: FacilityCategory.studyRoom,
      2: FacilityCategory.cinema,
      3: FacilityCategory.sLounge,
    };
    for (var i = 1; i < tabContents.length; i++) {
      final cat = tabCategoryMap[i] ?? FacilityCategory.studyRoom;
      final items = tabContents[i].querySelectorAll('.item');
      for (final item in items) {
        final dateStr = item.querySelector('.date')?.text.trim() ?? '';
        final timeStr = item.querySelector('.info .time')?.text.trim() ?? '';
        final roomStr = item.querySelector('.info .room')?.text.trim() ?? '';
        final statusStr = item.querySelector('.status')?.text.trim() ?? '';
        if (dateStr.isEmpty || timeStr.isEmpty || roomStr.isEmpty) continue;
        final date = _parseDate(dateStr);
        if (date == null) continue;
        final (start, end) = _parseTimeRange(timeStr);
        // reserveNo는 item HTML의 cancelSroom('...') 호출에서 추출 시도.
        final outer = item.outerHtml;
        final rnMatch = RegExp(
          r'''cancelSroom\(\s*['"]?(\d+)['"]?\s*\)''',
        ).firstMatch(outer);
        final reserveNo = rnMatch?.group(1);
        out.add(
          FacilityReservation(
            category: _refineCategory(cat, roomStr),
            date: date,
            startTime: start,
            endTime: end,
            roomLabel: roomStr,
            status: statusStr,
            reserveNo: reserveNo,
          ),
        );
      }
    }
    // 최신 날짜 우선.
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  DateTime? _parseDate(String s) {
    final m = RegExp(r'^(\d{4})\.(\d{1,2})\.(\d{1,2})').firstMatch(s);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  (String, String) _parseTimeRange(String s) {
    // "18:00 ~ 20:00" or "20:55~02:56".
    final m = RegExp(r'(\d{1,2}:\d{2})\s*~\s*(\d{1,2}:\d{2})').firstMatch(s);
    if (m == null) return ('', '');
    return (m.group(1)!, m.group(2)!);
  }

  FacilityCategory _refineCategory(
    FacilityCategory fallback,
    String roomLabel,
  ) {
    if (roomLabel.startsWith('S1')) return FacilityCategory.studyRoom;
    if (roomLabel.startsWith('S2')) return FacilityCategory.cinema;
    if (roomLabel.startsWith('S3')) return FacilityCategory.sLounge;
    return fallback;
  }

  /// `POST /mobile/MA/setSeat.php` form `room_no&seat_no&token`.
  /// 응답: XML `<resultCode>` (0=fail) + `<resultMsg>`.
  Future<LibseatResult> reserveSeat({
    required int roomNo,
    required String seatNo,
  }) async {
    return _postXml(
      '/mobile/MA/setSeat.php',
      data: {'room_no': roomNo, 'seat_no': seatNo},
    );
  }

  /// `POST /mobile/MA/returnSeat.php` form `real_id&room_no&seat_no`.
  /// 좌석 반납. 응답 동일.
  Future<LibseatResult> returnSeat({
    required String userId,
    required int roomNo,
    required String seatNo,
  }) async {
    return _postXml(
      '/mobile/MA/returnSeat.php',
      data: {'real_id': userId, 'room_no': roomNo, 'seat_no': seatNo},
    );
  }

  /// 연장 — `POST /mobile/MA/extdSeat.php` form `real_id&room_no&seat_no`.
  ///
  /// 정책: "연장은 종료시간 120분전부터 가능합니다." — 너무 일찍 호출하면
  /// resultCode=1 + 안내 메시지로 거절(= success=false, 메시지 그대로 노출).
  Future<LibseatResult> extendSeat({
    required String userId,
    required int roomNo,
    required String seatNo,
  }) async {
    return _postXml(
      '/mobile/MA/extdSeat.php',
      data: {'real_id': userId, 'room_no': roomNo, 'seat_no': seatNo},
    );
  }

  Future<LibseatResult> _postXml(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    final token = await tokenSource.getToken();
    final body = {...data, 'token': token}.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value.toString())}',
        )
        .join('&');
    try {
      final res = await _dio.post<String>(
        path,
        data: body,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'application/xml, text/xml',
          },
        ),
      );
      return _parseResultXml(res.data ?? '');
    } catch (e) {
      return LibseatResult(success: false, message: '요청 실패: $e');
    }
  }

  LibseatResult _parseResultXml(String body) {
    try {
      final doc = xml.XmlDocument.parse(body);
      final code = doc.findAllElements('resultCode').first.innerText.trim();
      final msg = doc.findAllElements('resultMsg').first.innerText.trim();
      // libseat 규약은 단순하지 않음 — '0'은 명확한 실패, 그러나 '1'도 종종
      // 안내성 실패("게이트 통과 후 발권하시기 바랍니다." 등)로 사용된다.
      // 성공은 메시지에 명시 키워드(완료/되었/성공)가 포함된 경우로만 판정.
      // 그 외는 모두 사용자에게 message 그대로 노출.
      final isSuccess =
          code != '0' &&
          (msg.contains('완료') || msg.contains('되었') || msg.contains('성공'));
      return LibseatResult(success: isSuccess, message: msg);
    } catch (_) {
      return LibseatResult(success: false, message: '응답 해석 실패');
    }
  }
}

/// 열람실 토큰 발급/캐시 소스. 호출자가 만료 정책을 관리한다.
abstract class LibseatTokenSource {
  Future<String> getToken({bool forceRefresh = false});
}
