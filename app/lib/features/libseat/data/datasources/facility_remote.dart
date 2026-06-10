import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' as xml;

import 'package:sejong_smart_campus/core/network/service_urls.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_remote.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/facility_models.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';

/// 스터디룸/시네마룸/S-Lounge 시설 예약 (libseat 시간 grid).
class FacilityRemote {
  FacilityRemote({required this.tokenSource})
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

  /// `*List.php`에서 그룹 카드 추출 — 두 줄 텍스트("큰 라벨\n작은 라벨")와
  /// query string의 seq/seatCnt 사용.
  Future<List<FacilityGroup>> fetchGroups(FacilityCategory cat) async {
    final token = await tokenSource.getToken();
    final res = await _dio.get<String>(
      cat.listPath,
      queryParameters: {'token': token},
    );
    final doc = html_parser.parse(res.data ?? '');
    final mapFile = cat.mapPath.split('/').last; // sroomMap.php 등
    final links = doc.querySelectorAll('a[href*="$mapFile"]');
    final out = <FacilityGroup>[];
    for (final a in links) {
      final href = a.attributes['href'] ?? '';
      final uri = Uri.tryParse(href);
      if (uri == null) continue;
      final seq = int.tryParse(uri.queryParameters['seq'] ?? '');
      final seatCnt = int.tryParse(uri.queryParameters['seatCnt'] ?? '');
      if (seq == null || seatCnt == null) continue;
      final raw = a.text.trim();
      final lines = raw
          .split(RegExp(r'\s*\n\s*'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      final title = lines.isNotEmpty ? lines.first.trim() : cat.label;
      final subtitle = lines.length > 1
          ? lines.sublist(1).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim()
          : '';
      out.add(
        FacilityGroup(
          category: cat,
          seq: seq,
          title: title,
          subtitle: subtitle,
          seatCnt: seatCnt,
        ),
      );
    }
    return out;
  }

  /// `*Map.php`에서 룸×시간 grid 추출.
  ///
  /// HTML 구조:
  /// ```
  /// <div class="avl-slot">
  ///   <div class="at-head"><span>시간</span></div>
  ///   <div class="at-title"><span>02스터디룸</span></div>
  ///   <div class="at-title"><span>03스터디룸</span></div>
  /// </div>
  /// <div class="avl-data-slot">
  ///   <div class="avl-time">09:00</div>
  ///   <div class="avl-button">예약불가</div>          ← 운영 외/마감
  ///   <div class="avl-button"><a href="...">예약가능</a></div>
  /// </div>
  /// ```
  ///
  /// 핵심 규칙:
  ///  - 룸명: `.avl-slot .at-title span` 텍스트
  ///  - 시간 row: `.avl-data-slot`, 첫 자식 `.avl-time` 텍스트가 시작 시각
  ///  - 슬롯 상태:
  ///    - `.avl-button > a` 존재 + 텍스트 "예약가능" → [SlotStatus.available]
  ///    - 그 외("예약불가" 등) → [SlotStatus.reserved]
  ///
  /// [date]가 주어지면 `reserveDate=YYYYMMDD` 쿼리로 해당 날짜를 fetch.
  /// 없으면 백엔드 디폴트(오늘).
  Future<FacilityMap> fetchMap(FacilityGroup g, {DateTime? date}) async {
    final token = await tokenSource.getToken();
    final res = await _dio.get<String>(
      g.category.mapPath,
      queryParameters: {
        'token': token,
        'roomGB': g.category.roomGB,
        'seq': g.seq,
        'seatCnt': g.seatCnt,
        'sroomTitle': g.title,
        if (date != null) 'reserveDate': _yyyymmdd(date),
        // userId가 비어도 응답 옴 — 본인 예약 marking 용도.
        'userId': '',
      },
    );
    final doc = html_parser.parse(res.data ?? '');

    final roomHeaders = doc.querySelectorAll('.avl-slot .at-title');
    final rooms = roomHeaders
        .map((e) => e.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final times = <String>[];
    final slots = <FacilitySlot>[];

    // 룸명 → sroomNo 매핑. 첫 등장 a href에서 추출.
    // 운영시간 외 row는 모두 div(no anchor)라 매핑이 안 잡힐 수 있으니
    // 다음 row에서 보강.
    final sroomNoByRoom = <String, int>{};

    final rows = doc.querySelectorAll('.avl-data-slot');
    for (final row in rows) {
      final timeEl = row.querySelector('.avl-time');
      final time = timeEl?.text.trim() ?? '';
      if (time.isEmpty) continue;
      times.add(time);
      final buttons = row.querySelectorAll('.avl-button');
      for (var c = 0; c < buttons.length; c++) {
        if (c >= rooms.length) break;
        final btn = buttons[c];
        final anchor = btn.querySelector('a');
        final hasAnchor = anchor != null;
        final text = btn.text.trim();
        final isAvailable = hasAnchor && text.contains('예약가능');
        if (hasAnchor && !sroomNoByRoom.containsKey(rooms[c])) {
          final href = anchor.attributes['href'] ?? '';
          final n = _parseSroomNoFromHref(href);
          if (n != null) sroomNoByRoom[rooms[c]] = n;
        }
        slots.add(
          FacilitySlot(
            roomLabel: rooms[c],
            // 매핑 못 잡은 룸은 fallback 0 — reserveSlot에서 skip 처리.
            sroomNo: sroomNoByRoom[rooms[c]] ?? 0,
            time: time,
            status: isAvailable ? SlotStatus.available : SlotStatus.reserved,
          ),
        );
      }
    }

    // 후처리 — 첫 발견 후 추가된 sroomNo로 이미 만든 슬롯 보강.
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s.sroomNo == 0) {
        final n = sroomNoByRoom[s.roomLabel];
        if (n != null) {
          slots[i] = FacilitySlot(
            roomLabel: s.roomLabel,
            sroomNo: n,
            time: s.time,
            status: s.status,
          );
        }
      }
    }

    final label = date != null
        ? '${date.month}.${date.day}'
        : (rows.isNotEmpty ? '오늘' : '');
    return FacilityMap(
      dateLabel: label,
      rooms: rooms,
      times: times,
      slots: slots,
    );
  }

  String _yyyymmdd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y$m$dd';
  }

  /// 시설 예약.
  ///
  /// `POST /mobile/MA/sroomReserve.php` (form-urlencoded, UTF-8)
  ///   body 예시:
  ///   ```
  ///   userID=STUDENT_A|STUDENT_B|STUDENT_C
  ///   &userName=USER_A|USER_B|USER_C
  ///   &roomNo=2
  ///   &reserveDate=20260526
  ///   &startTime=1000
  ///   &useTime=120
  ///   &roomNo=2
  ///   ```
  ///
  /// 성공: HTTP 200 + **빈 body** — alert("10:00 ~ 12:00 예약이 완료되었습니다...")
  /// 가 사이트 JS에서 표시되는 형태라 응답에는 메시지가 안 옴.
  ///
  /// 실패: HTTP 200 + `<root><item><resultCode>1</resultCode><resultMsg>...
  /// </resultMsg></item></root>` — 이름·학번 불일치, 만석 등.
  ///
  /// [allUsers]는 [(학번, 이름)] tuple list. 본인이 첫 번째여야 함. 빈 학번/
  /// 이름이 포함되면 skip.
  Future<LibseatResult> reserveSlot({
    required int sroomNo, // libseat 글로벌 ID — 라벨 파싱 X
    required List<({String studentId, String name})> allUsers,
    required String time, // "10:00"
    required int durationMinutes, // 60 or 120
    DateTime? date,
  }) async {
    if (sroomNo <= 0) {
      return const LibseatResult(
        success: false,
        message: '룸 정보가 불완전해요. 다시 시도해주세요.',
      );
    }
    final startTime = _toStartTime(time);
    final dateStr = date == null ? '' : _yyyymmdd(date);

    final filtered = allUsers
        .where((u) => u.studentId.trim().isNotEmpty && u.name.trim().isNotEmpty)
        .toList();
    if (filtered.isEmpty) {
      return const LibseatResult(success: false, message: '예약자 정보가 비어 있어요.');
    }
    // 본인 학번이 동반자로 중복 입력된 경우 — 백엔드 trip 절약.
    final idSet = <String>{};
    for (final u in filtered) {
      if (!idSet.add(u.studentId)) {
        return LibseatResult(
          success: false,
          message: '중복된 학번이 있어요 (${u.studentId}). 동반이용자에서 제거해주세요.',
        );
      }
    }

    // 서버 호환을 위해 roomNo를 두 번 포함한다.
    final body = StringBuffer()
      ..write('userID=')
      ..write(
        filtered.map((u) => Uri.encodeQueryComponent(u.studentId)).join('|'),
      )
      ..write('&userName=')
      ..write(filtered.map((u) => Uri.encodeQueryComponent(u.name)).join('|'))
      ..write('&roomNo=$sroomNo')
      ..write('&reserveDate=$dateStr')
      ..write('&startTime=$startTime')
      ..write('&useTime=$durationMinutes')
      ..write('&roomNo=$sroomNo');

    try {
      final res = await _dio.post<String>(
        '/mobile/MA/sroomReserve.php',
        data: body.toString(),
        options: Options(
          contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
          headers: const {
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'application/xml, text/xml, */*; q=0.01',
          },
        ),
      );
      return _interpretReservationResponse(
        res.statusCode,
        res.data ?? '',
        time: time,
        durationMinutes: durationMinutes,
      );
    } catch (e) {
      return LibseatResult(success: false, message: '요청 실패: $e');
    }
  }

  /// 예약/취소 응답 해석 — 빈 body=success, resultMsg 있으면 그대로 노출.
  LibseatResult _interpretReservationResponse(
    int? status,
    String body, {
    String? time,
    int? durationMinutes,
  }) {
    if (status != 200) {
      return LibseatResult(
        success: false,
        message: '서버 응답 오류 (${status ?? "-"})',
      );
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      // 성공 — libseat가 alert로 보여주는 메시지를 우리 다이얼로그에서 노출.
      final timeLabel = (time != null && durationMinutes != null)
          ? '${_endTimeOf(time, durationMinutes)} 예약이 완료되었어요.\n'
          : '예약이 완료되었어요.\n';
      return LibseatResult(
        success: true,
        message: '$timeLabel이용 당일 이용자 전원이 게이트를 통과해야 예약이 확정됩니다.',
      );
    }
    // XML 응답 — resultMsg 있으면 그대로 사용자에게.
    try {
      final doc = xml.XmlDocument.parse(trimmed);
      final msgEl = doc.findAllElements('resultMsg');
      if (msgEl.isNotEmpty) {
        return LibseatResult(
          success: false,
          message: msgEl.first.innerText.trim(),
        );
      }
    } catch (_) {
      /* fallthrough */
    }
    return LibseatResult(success: false, message: '응답을 해석할 수 없어요.');
  }

  /// "10:00" + 120분 → "10:00 ~ 12:00".
  String _endTimeOf(String startHHMM, int minutes) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(startHHMM);
    if (m == null) return startHHMM;
    final h = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    final total = h * 60 + mm + minutes;
    final eh = (total ~/ 60) % 24;
    final em = total % 60;
    return '$startHHMM ~ ${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
  }

  /// 시설 예약 취소 — `POST /mobile/MA/cancelSroom.php`
  /// body: `userID={학번}&reserveNo={예약번호}`.
  /// 성공 = HTTP 200 + 빈 body. 실패 = XML resultMsg.
  Future<LibseatResult> cancelReservation({
    required String userId,
    required String reserveNo,
  }) async {
    try {
      final res = await _dio.post<String>(
        '/mobile/MA/cancelSroom.php',
        data: _formBody({'userID': userId, 'reserveNo': reserveNo}),
        options: _formOptions(),
      );
      final body = res.data ?? '';
      final result = _interpretReservationResponse(res.statusCode, body);
      if (result.success) {
        return const LibseatResult(success: true, message: '예약이 취소되었어요.');
      }
      return result;
    } catch (e) {
      return LibseatResult(success: false, message: '요청 실패: $e');
    }
  }

  // ─── 내부 helper ─────────────────────────────────────────────────────────

  /// `./sroomReserveMain.php?...&sroomNo=14&sroomName=...` → 14.
  int? _parseSroomNoFromHref(String href) {
    final m = RegExp(r'[?&]sroomNo=(\d+)').firstMatch(href);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  /// "10:00" → "1000". 운영시간 외/형식 깨짐은 빈 문자열.
  String _toStartTime(String hhmm) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm);
    if (m == null) return '';
    return m.group(1)!.padLeft(2, '0') + m.group(2)!;
  }

  String _formBody(Map<String, String> data) => data.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');

  Options _formOptions() => Options(
    contentType: 'application/x-www-form-urlencoded',
    headers: const {
      'X-Requested-With': 'XMLHttpRequest',
      'Accept': 'application/xml, text/xml, text/html',
    },
  );

  // ignore: unused_element
  LibseatResult? _tryParseXml(String body) {
    try {
      final doc = xml.XmlDocument.parse(body);
      final code = doc.findAllElements('resultCode').first.innerText.trim();
      final msg = doc.findAllElements('resultMsg').first.innerText.trim();
      final isSuccess =
          code != '0' &&
          (msg.contains('완료') || msg.contains('되었') || msg.contains('성공'));
      return LibseatResult(success: isSuccess, message: msg);
    } catch (_) {
      return null;
    }
  }
}
