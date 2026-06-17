import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/network/sejong_api_client.dart';
import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_notification_state_local.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/facility_remote.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_notifications.dart';
import 'package:sejong_smart_campus/features/libseat/data/datasources/libseat_remote.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/facility_models.dart';
import 'package:sejong_smart_campus/features/libseat/domain/entities/libseat_models.dart';
import 'package:sejong_smart_campus/features/library/domain/entities/library_models.dart'
    show LibraryUsageRecord, LibraryUsageStatus;
import 'package:sejong_smart_campus/features/library/domain/entities/seat_reservation.dart';
import 'package:sejong_smart_campus/features/library/presentation/providers/usage_history_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_dialog.dart';

/// libseat 응답 결과를 통일된 모달(앱 디자인)로 노출.
///
/// SnackBar는 success로 잘못 판정해 즉시 화면 pop되는 경우 사용자가 메시지를
/// 못 본다. libseat의 안내성 실패(`resultCode=1` "게이트 통과 후 발권하시기
/// 바랍니다." 등)는 dialog로 명확하게 보여줘야 함.
Future<void> showLibseatResultDialog(
  BuildContext context,
  LibseatResult result, {
  String successTitle = '예약 완료',
}) async {
  if (!context.mounted) return;
  final isOk = result.success;
  final msg = result.message.trim().isEmpty
      ? (isOk ? '처리되었어요' : '처리하지 못했어요')
      : result.message.trim();
  await showSejongResultDialog(
    context,
    success: isOk,
    title: isOk ? successTitle : '알림',
    message: msg,
  );
}

/// sjapp `/api/secureapi/library/reading-room-token`을 받아 600s 캐시.
///
/// dispatcher의 `_TokenCache`와 의도 동일하지만 LibseatRemote 직접 호출용으로
/// 분리. forceRefresh=true는 만료/401 시 재시도용.
class _SjappLibseatTokenSource implements LibseatTokenSource {
  _SjappLibseatTokenSource(this._client);
  final SejongApiClient _client;
  String? _cached;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<String> getToken({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh && _cached != null && now.isBefore(_expiresAt)) {
      return _cached!;
    }
    final res = await _client.dio.get<dynamic>(
      '/api/secureapi/library/reading-room-token',
    );
    final token = _client.unwrap<String>(res, (raw) {
      if (raw is Map<String, dynamic>) {
        return (raw['token'] ?? '').toString();
      }
      return raw?.toString() ?? '';
    });
    _cached = token;
    _expiresAt = now.add(const Duration(seconds: 600));
    return token;
  }
}

/// libseat 호출에 부착하는 sjapp reading-room-token 캐시 source.
///
/// 인스턴스 내부에 10분 짜리 token cache가 있으므로, 앱이 장시간 sleep 후 깨어
/// 났을 때 외부에서 `ref.invalidate(libseatTokenSourceProvider)` 호출로 새
/// 인스턴스를 만들어 cache를 초기화한다 — `app_resume_handler`가 호출.
final libseatTokenSourceProvider = FutureProvider<LibseatTokenSource>((
  ref,
) async {
  // 계정 격리 — 사용자가 바뀌면 in-memory reading-room-token 캐시(600s)를 폐기.
  // 이 의존이 없으면 로그아웃→다른 계정 로그인 후에도 이전 사용자의 캐시 토큰으로
  // libseat을 긁어 홈 "열람실 대여 카드"에 남의 좌석이 보였다. userId만 select해
  // 토큰 refresh(같은 사용자 객체 재발행)로는 재생성되지 않게 한다.
  ref.watch(currentUserProvider.select((u) => u?.userId));
  final client = await ref.watch(sejongApiClientProvider.future);
  return _SjappLibseatTokenSource(client);
});

final _libseatRemoteProvider = FutureProvider<LibseatRemote>((ref) async {
  final src = await ref.watch(libseatTokenSourceProvider.future);
  return LibseatRemote(tokenSource: src);
});

final _facilityRemoteProvider = FutureProvider<FacilityRemote>((ref) async {
  final src = await ref.watch(libseatTokenSourceProvider.future);
  return FacilityRemote(tokenSource: src);
});

/// 카테고리별 그룹 list — list page 1회 fetch.
final facilityGroupsProvider = FutureProvider.autoDispose
    .family<List<FacilityGroup>, FacilityCategory>((ref, cat) async {
      final remote = await ref.watch(_facilityRemoteProvider.future);
      return remote.fetchGroups(cat);
    });

/// 그룹의 시간×룸 grid — [date]별 fetch.
///
/// libseat가 `reserveDate=YYYYMMDD` query param을 지원하므로 동일 그룹의
/// 다른 날짜 데이터를 각각 캐시. 사용자가 carousel에서 날짜 변경 시 새 키로
/// 자동 새 fetch.
final facilityMapProvider = FutureProvider.autoDispose
    .family<FacilityMap, (FacilityGroup, DateTime)>((ref, key) async {
      final (group, date) = key;
      final remote = await ref.watch(_facilityRemoteProvider.future);
      return remote.fetchMap(group, date: date);
    });

/// 카테고리 전체의 룸 단위 시간표 — 새 LibseatScreen이 사용.
///
/// 처리 흐름:
/// 1. `facilityGroupsProvider(cat)` 으로 카테고리의 모든 그룹 list 확보
/// 2. 각 그룹마다 [facilityMapProvider]를 `(group, date)` 키로 병렬 fetch
/// 3. 룸 단위로 평탄화 — 한 룸 × 13시간(10~22) [RoomSchedule].
///
/// 백엔드가 슬롯에 status를 두 가지(available/reserved)만 노출하므로 "이용중"
/// "이용불가"는 새 디자인의 색만 다른 상태로 매핑(현재는 reserved 동일 취급).
/// 운영시간 외 시각([LibseatHours.all]에 없거나 응답에 없음)은 disabled.
final facilityRoomsForDateProvider = FutureProvider.autoDispose
    .family<List<RoomSchedule>, (FacilityCategory, DateTime)>((ref, key) async {
      final (category, date) = key;
      final groups = await ref.watch(facilityGroupsProvider(category).future);
      if (groups.isEmpty) return const [];
      final maps = await Future.wait(
        groups.map((g) async {
          try {
            final m = await ref.watch(facilityMapProvider((g, date)).future);
            return (g, m);
          } catch (_) {
            return (g, null);
          }
        }),
      );

      final out = <RoomSchedule>[];
      for (final (group, map) in maps) {
        if (map == null) continue;
        for (final roomLabel in map.rooms) {
          final byHour = <int, SlotStatus>{};
          int sroomNo = 0;
          for (final s in map.slots) {
            if (s.roomLabel != roomLabel) continue;
            final h = _parseHour(s.time);
            if (h == null) continue;
            byHour[h] = s.status;
            if (sroomNo == 0 && s.sroomNo > 0) sroomNo = s.sroomNo;
          }
          final slots = [
            for (final h in LibseatHours.all)
              RoomTimeSlot(hour: h, status: byHour[h] ?? SlotStatus.disabled),
          ];
          out.add(
            RoomSchedule(
              group: group,
              roomLabel: roomLabel,
              sroomNo: sroomNo,
              roomIndex: _parseRoomIndex(roomLabel),
              minCapacity: _minCapacityFor(category, group.seatCnt),
              maxCapacity: group.seatCnt,
              slots: slots,
            ),
          );
        }
      }
      // 룸 번호 순으로 정렬.
      out.sort((a, b) => a.roomIndex.compareTo(b.roomIndex));
      return out;
    });

int? _parseHour(String hhmm) {
  final m = RegExp(r'^(\d{1,2}):').firstMatch(hhmm);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

int _parseRoomIndex(String label) {
  // "01스터디룸" -> 1, "시네마룸3" -> 3, "SL10" -> 10
  final m = RegExp(r'(\d+)').firstMatch(label);
  if (m == null) return 0;
  return int.tryParse(m.group(1)!) ?? 0;
}

/// 카테고리별 최소 인원 정책 (사용자 안내 텍스트 기준):
///  - 스터디룸: 3 ~ 12 (12인실은 6 이상)
///  - 시네마룸: 1 ~ 3
///  - S-Lounge: 2 ~ 6
int _minCapacityFor(FacilityCategory category, int seatCnt) {
  switch (category) {
    case FacilityCategory.studyRoom:
      return seatCnt >= 12 ? 6 : 3;
    case FacilityCategory.cinema:
      return 1;
    case FacilityCategory.sLounge:
      return 2;
  }
}

Future<LibseatResult> reserveFacilitySlot(
  WidgetRef ref, {
  required FacilityGroup group,
  required int sroomNo,
  required String roomLabel,
  required String time,
  required int durationHours,
  required List<({String studentId, String name})> companions,
  DateTime? date,
}) async {
  final user = ref.read(currentUserProvider);
  final userId = user?.userId ?? '';
  final userName = user?.username ?? '';
  if (userId.isEmpty || userName.isEmpty) {
    return const LibseatResult(
      success: false,
      message: '로그인 정보가 없어요. 다시 로그인해주세요.',
    );
  }
  final allUsers = [(studentId: userId, name: userName), ...companions];
  final remote = await ref.read(_facilityRemoteProvider.future);
  final r = await remote.reserveSlot(
    sroomNo: sroomNo,
    allUsers: allUsers,
    time: time,
    durationMinutes: durationHours * 60,
    date: date,
  );
  if (r.success) {
    await _appendHistory(
      ref,
      roomLabel: '${group.title} · $roomLabel ($time)',
      durationMinutes: 60,
      status: LibraryUsageStatus.completed,
    );
    // 예약 한 건이라도 성공하면 시설 관련 모든 화면 cache가 stale.
    // family 인자 생략 = 모든 키 인스턴스 invalidate.
    ref.invalidate(facilityMapProvider);
    ref.invalidate(facilityRoomsForDateProvider);
    ref.invalidate(facilityGroupsProvider);
    ref.invalidate(myFacilityReservationsProvider);
    ref.invalidate(mySeatProvider);
    ref.invalidate(usageHistoryProvider);
    ref.invalidate(seatUsageHistoryProvider);
  }
  return r;
}

/// 시설 예약 취소 helper — UI에서 cancel 버튼이 부르는 진입점.
/// 성공 시 mySeat·시설 grid·예약 내역 모두 새로고침.
Future<LibseatResult> cancelMyFacilityReservation(
  WidgetRef ref, {
  required String reserveNo,
}) async {
  final user = ref.read(currentUserProvider);
  final userId = user?.userId ?? '';
  final remote = await ref.read(_facilityRemoteProvider.future);
  final r = await remote.cancelReservation(
    userId: userId,
    reserveNo: reserveNo,
  );
  if (r.success) {
    await _appendHistory(
      ref,
      roomLabel: '시설 예약 취소',
      durationMinutes: 0,
      status: LibraryUsageStatus.autoReturned,
    );
    ref.invalidate(facilityMapProvider);
    ref.invalidate(facilityRoomsForDateProvider);
    ref.invalidate(facilityGroupsProvider);
    ref.invalidate(myFacilityReservationsProvider);
    ref.invalidate(mySeatProvider);
    ref.invalidate(usageHistoryProvider);
    ref.invalidate(seatUsageHistoryProvider);
  }
  return r;
}

/// 8개 열람실 list. 30초마다 invalidate 가능 (사용자 새로고침).
final roomListProvider = FutureProvider.autoDispose<List<ReadingRoom>>((
  ref,
) async {
  final remote = await ref.watch(_libseatRemoteProvider.future);
  return remote.fetchRoomList();
});

/// 특정 열람실 좌석 grid (실 room_no 1개).
final seatMapProvider = FutureProvider.autoDispose.family<List<Seat>, int>((
  ref,
  roomNo,
) async {
  final remote = await ref.watch(_libseatRemoteProvider.future);
  return remote.fetchSeatMap(roomNo);
});

/// 화면 표시용 열람실 ID를 구성하는 실 libseat room_no들.
///
/// 통합 열람실(제1=1112/제4=1516)은 시스템상 A/B 2개 room_no(11·12 / 15·16)로
/// 나뉘어 있다. `seatMap.php?param_room_no=1112`는 존재하지 않아 빈 응답이라,
/// 라이브 좌석맵을 만들려면 두 wing을 각각 조회해야 한다. 단일 열람실은 1개.
List<int> libseatRealRoomNos(int displayRoomNo) {
  if (displayRoomNo <= 99) return [displayRoomNo];
  return [displayRoomNo ~/ 100, displayRoomNo % 100];
}

/// 화면 표시용 열람실의 **라이브** 좌석맵 — 통합 열람실은 양 wing 합산.
///
/// 좌석 seat_no(=asset id)가 wing별로 겹치지 않으므로 단순 concat이면 충분
/// (room_1112: A=room11 ids, B=room12 ids, 교집합 없음). 한쪽 wing 조회가
/// 실패해도 나머지는 살린다. [LibraryRoomScreen]이 이 provider를 watch.
final seatMapForRoomProvider = FutureProvider.autoDispose
    .family<List<Seat>, int>((ref, displayRoomNo) async {
      final reals = libseatRealRoomNos(displayRoomNo);
      final lists = await Future.wait(
        reals.map((rn) async {
          try {
            return await ref.watch(seatMapProvider(rn).future);
          } catch (_) {
            return const <Seat>[];
          }
        }),
      );
      return [for (final l in lists) ...l];
    });

/// 내 활성 좌석 — 없으면 null.
final mySeatProvider = FutureProvider.autoDispose<MySeat?>((ref) async {
  ref.watch(currentUserProvider);
  final remote = await ref.watch(_libseatRemoteProvider.future);
  return remote.fetchMySeat();
});

/// 내 시설 예약 내역 (스터디룸/시네마룸/S-Lounge 통합).
/// mySeat.php의 탭 2~4번 .item을 파싱 — 열람실 좌석 이력은 제외.
final myFacilityReservationsProvider =
    FutureProvider.autoDispose<List<FacilityReservation>>((ref) async {
      ref.watch(currentUserProvider);
      final remote = await ref.watch(_libseatRemoteProvider.future);
      return remote.fetchMyFacilityReservations();
    });

/// 예약/반납 직후 mySeat 재조회(네트워크, ~1-2s)가 끝나기 전까지 홈/도서관
/// 카드를 **즉시** 갱신하기 위한 낙관적 override.
///
/// - [show]: 방금 예약한 좌석을 즉시 카드로 노출 (예약 시 이미 받은 MySeat 사용 —
///   홈의 mySeatProvider 재조회를 기다리지 않음).
/// - [hide]: 방금 반납 → 즉시 카드 제거.
/// - null = override 없음(서버값 사용).
///
/// **자동 만료**: mySeatProvider가 정착(AsyncData, non-loading)하면 override를
/// 비워 이후엔 서버값만 신뢰 → stale/phantom 없음(자동반납·연장·웹발권 모두 정확).
class _SeatOverride extends Notifier<({MySeat? value})?> {
  @override
  ({MySeat? value})? build() {
    // 서버 mySeat이 정착(AsyncData, non-loading)하고 **override 의도와 일치**할
    // 때만 해제 → 서버에 인계. 의도 불일치(서버 반영 지연: 예약 직후 빈 좌석 /
    // 반납 직후 아직 좌석)면 유지해 카드 깜빡임·잔상을 막고 다음 정착에 인계.
    ref.listen(mySeatProvider, (prev, next) {
      final ov = state;
      if (ov == null || !next.hasValue || next.isLoading) return;
      final serverHasSeat = next.value != null;
      final overrideWantsSeat = ov.value != null;
      if (serverHasSeat == overrideWantsSeat) {
        // ignore: avoid_print
        print(
          '[LIBSEAT] override.autoClear (server settled '
          'hasSeat=$serverHasSeat == intent) -> 서버값 인계',
        );
        state = null;
      }
    });
    return null;
  }

  void show(MySeat seat) {
    // ignore: avoid_print
    print(
      '[LIBSEAT] override.show ${seat.roomName} ${seat.seatNo} '
      'exp=${seat.endTime}',
    );
    state = (value: seat);
  }

  void hide() {
    // ignore: avoid_print
    print('[LIBSEAT] override.hide -> 카드 즉시 제거');
    state = (value: null);
  }
}

final seatOverrideProvider =
    NotifierProvider<_SeatOverride, ({MySeat? value})?>(_SeatOverride.new);

/// 홈/도서관 화면에서 즉시 쓸 수 있는 [SeatReservation] 형태로 변환.
///
/// 기존 mock(`mockActiveLibraryReservation`)을 대체. 낙관적 override가 있으면
/// 서버 재조회 전이라도 즉시 반영([seatOverrideProvider]). 없으면 서버값. 둘 다
/// 비면 null.
final activeSeatReservationProvider = Provider<SeatReservation?>((ref) {
  // mySeatProvider는 항상 watch(조건부 watch 랜드마인 회피) — override가 있으면
  // override.value, 없으면 서버값.
  final mineAsync = ref.watch(mySeatProvider);
  final override = ref.watch(seatOverrideProvider);
  final mine = override != null ? override.value : mineAsync.value;
  if (mine == null) return null;
  return SeatReservation(
    id: '${mine.roomNo}_${mine.seatNo}',
    roomName: '${mine.roomName} ${mine.seatNo}번',
    startedAt: mine.startedAt,
    expiresAt: mine.expiresAt,
    roomNo: mine.roomNo,
    seatNo: mine.seatNo,
  );
});

final libseatNotificationStateLocalProvider =
    Provider<LibseatNotificationStateLocal>(
      (_) => LibseatNotificationStateLocal(),
    );

final libseatSyncProvider = Provider<LibseatSync>(
  (ref) => LibseatSyncService(ref),
);

abstract class LibseatSync {
  Future<LibseatSyncResult> sync({
    required String reason,
    String? notificationPayloadKey,
    int? visibleRoomNo,
    bool expectNoSeat = false,
  });
}

class LibseatSyncResult {
  const LibseatSyncResult({
    required this.reason,
    this.seat,
    this.returnAcknowledgementDue = false,
    this.acknowledgedReturnKey,
    this.error,
  });

  final String reason;
  final MySeat? seat;
  final bool returnAcknowledgementDue;
  final String? acknowledgedReturnKey;
  final Object? error;

  bool get success => error == null;
}

class LibseatSyncService implements LibseatSync {
  LibseatSyncService(this._ref);

  final Ref _ref;

  @override
  Future<LibseatSyncResult> sync({
    required String reason,
    String? notificationPayloadKey,
    int? visibleRoomNo,
    bool expectNoSeat = false,
  }) async {
    final local = _ref.read(libseatNotificationStateLocalProvider);
    final previousState = await local.read();
    try {
      final remote = await _ref.read(_libseatRemoteProvider.future);
      var seat = await remote.fetchMySeat();
      if (expectNoSeat && seat != null) {
        seat = await _fetchMySeatUntilEmpty(remote);
      }
      var returnAcknowledgementDue = false;
      String? acknowledgedReturnKey;

      if (seat == null) {
        _ref.read(seatOverrideProvider.notifier).hide();
        await LibseatNotifications.instance.cancelAll();
        await local.clearSnapshot();
        if (notificationPayloadKey != null &&
            !await local.hasAcknowledgedReturn(notificationPayloadKey)) {
          await local.acknowledgeReturn(notificationPayloadKey);
          returnAcknowledgementDue = true;
          acknowledgedReturnKey = notificationPayloadKey;
        }
      } else {
        _ref.read(seatOverrideProvider.notifier).show(seat);
        final snapshot = LibseatReservationSnapshot.fromMySeat(seat);
        final previous = previousState.current;
        if (previous == null || !previous.hasSameSchedule(snapshot)) {
          await LibseatNotifications.instance.scheduleForSeat(
            seat,
            promptExactAlarm: _shouldPromptExactAlarm(reason),
          );
          await local.saveSnapshot(snapshot);
        }
      }

      await _refreshViews(seat: seat, visibleRoomNo: visibleRoomNo);
      return LibseatSyncResult(
        reason: reason,
        seat: seat,
        returnAcknowledgementDue: returnAcknowledgementDue,
        acknowledgedReturnKey: acknowledgedReturnKey,
      );
    } catch (e) {
      return LibseatSyncResult(reason: reason, error: e);
    }
  }

  Future<MySeat?> _fetchMySeatUntilEmpty(LibseatRemote remote) async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      final seat = await remote.fetchMySeat();
      if (seat == null) return null;
    }
    return remote.fetchMySeat();
  }

  Future<void> _refreshViews({
    required MySeat? seat,
    int? visibleRoomNo,
  }) async {
    _ref.invalidate(mySeatProvider);
    _ref.invalidate(roomListProvider);
    _ref.invalidate(seatUsageHistoryProvider);

    if (visibleRoomNo != null) {
      for (final rn in libseatRealRoomNos(visibleRoomNo)) {
        _ref.invalidate(seatMapProvider(rn));
      }
      _ref.invalidate(seatMapForRoomProvider(visibleRoomNo));
    }
    if (seat != null) {
      _ref.invalidate(seatMapProvider(seat.roomNo));
    }

    await Future.wait<void>([
      _ignore(_ref.read(roomListProvider.future)),
      if (visibleRoomNo != null)
        _ignore(_ref.read(seatMapForRoomProvider(visibleRoomNo).future)),
    ]);
  }

  Future<void> _ignore(Future<Object?> future) async {
    try {
      await future;
    } catch (_) {
      // The dependent provider will render its own error state.
    }
  }

  bool _shouldPromptExactAlarm(String reason) {
    return reason == 'reserve' ||
        reason == 'extend' ||
        reason == 'libraryListRefresh' ||
        reason == 'homeRefresh';
  }
}

Future<LibseatResult> cancelFacilityReservation(
  WidgetRef ref,
  String reserveNo,
) async {
  final user = ref.read(currentUserProvider);
  final userId = user?.userId ?? '';
  final remote = await ref.read(_facilityRemoteProvider.future);
  final r = await remote.cancelReservation(
    userId: userId,
    reserveNo: reserveNo,
  );
  if (r.success) {
    await _appendHistory(
      ref,
      roomLabel: '시설 예약 취소',
      durationMinutes: 0,
      status: LibraryUsageStatus.autoReturned,
    );
    ref.invalidate(mySeatProvider);
    ref.invalidate(usageHistoryProvider);
    ref.invalidate(seatUsageHistoryProvider);
    for (final c in FacilityCategory.values) {
      ref.invalidate(facilityGroupsProvider(c));
    }
  }
  return r;
}

Future<LibseatResult> reserveLibseat(
  WidgetRef ref, {
  required int roomNo,
  required String seatNo,
  String? roomName,
  int? visibleRoomNo,
}) async {
  final remote = await ref.read(_libseatRemoteProvider.future);
  final r = await remote.reserveSeat(roomNo: roomNo, seatNo: seatNo);
  if (r.success) {
    final mine = await _fetchMySeatBounded(remote);
    if (mine != null) ref.read(seatOverrideProvider.notifier).show(mine);
    final sync = await ref
        .read(libseatSyncProvider)
        .sync(reason: 'reserve', visibleRoomNo: visibleRoomNo ?? roomNo);
    final syncedSeat = sync.seat ?? mine;
    // ignore: avoid_print
    print(
      '[LIBSEAT] reserve OK room=$roomNo seat=$seatNo '
      '-> mine=${syncedSeat?.roomName} ${syncedSeat?.seatNo} '
      'exp=${syncedSeat?.endTime}',
    );
    await _appendHistory(
      ref,
      roomLabel: syncedSeat?.roomName ?? roomName ?? '열람실 $roomNo · $seatNo번',
      durationMinutes: _durationMinutes(
        syncedSeat?.startTime,
        syncedSeat?.endTime,
      ),
      status: LibraryUsageStatus.completed,
    );
    ref.invalidate(mySeatProvider);
    ref.invalidate(seatMapProvider(roomNo));
    if (visibleRoomNo != null) {
      ref.invalidate(seatMapForRoomProvider(visibleRoomNo));
    }
    ref.invalidate(roomListProvider);
    ref.invalidate(usageHistoryProvider);
    ref.invalidate(seatUsageHistoryProvider);
  }
  return r;
}

Future<LibseatResult> returnLibseat(
  WidgetRef ref, {
  required int roomNo,
  required String seatNo,
}) async {
  final user = ref.read(currentUserProvider);
  final userId = user?.userId ?? '';
  final remote = await ref.read(_libseatRemoteProvider.future);
  final r = await remote.returnSeat(
    userId: userId,
    roomNo: roomNo,
    seatNo: seatNo,
  );
  if (r.success) {
    // 낙관적 숨김 — mySeat 재조회(네트워크) 전이라도 홈/도서관 카드 즉시 사라짐.
    ref.read(seatOverrideProvider.notifier).hide();
    await _appendHistory(
      ref,
      roomLabel: '좌석 반납 · 열람실 $roomNo · $seatNo번',
      durationMinutes: 0,
      status: LibraryUsageStatus.completed,
    );
    // 반납했으니 예약 종료 알림 취소 (#4).
    await ref
        .read(libseatSyncProvider)
        .sync(reason: 'return', visibleRoomNo: roomNo, expectNoSeat: true);
    ref.invalidate(mySeatProvider);
    ref.invalidate(seatMapProvider(roomNo));
    ref.invalidate(roomListProvider);
    ref.invalidate(usageHistoryProvider);
    ref.invalidate(seatUsageHistoryProvider);
  }
  return r;
}

Future<LibseatResult> extendLibseat(
  WidgetRef ref, {
  required int roomNo,
  required String seatNo,
}) async {
  final user = ref.read(currentUserProvider);
  final userId = user?.userId ?? '';
  final remote = await ref.read(_libseatRemoteProvider.future);
  final r = await remote.extendSeat(
    userId: userId,
    roomNo: roomNo,
    seatNo: seatNo,
  );
  if (r.success) {
    // 새 종료시간을 알아야 알림을 재예약 + 타이머가 갱신되므로 재조회.
    final mine = await _fetchMySeatBounded(remote, tries: 3);
    // 연장된 새 종료시간을 카드/타이머에 즉시 반영.
    if (mine != null) ref.read(seatOverrideProvider.notifier).show(mine);
    final sync = await ref
        .read(libseatSyncProvider)
        .sync(reason: 'extend', visibleRoomNo: roomNo);
    final syncedSeat = sync.seat ?? mine;
    await _appendHistory(
      ref,
      roomLabel: '좌석 연장 · ${syncedSeat?.roomName ?? '열람실 $roomNo · $seatNo번'}',
      durationMinutes: 60,
      status: LibraryUsageStatus.completed,
    );
    ref.invalidate(mySeatProvider);
    ref.invalidate(usageHistoryProvider);
    ref.invalidate(seatUsageHistoryProvider);
  }
  return r;
}

// ─── SeatCard 반납/연장 버튼 핸들러 (홈·도서관 공용) ────────────────────────

/// 반납 버튼 — 확인 후 [returnLibseat] 호출하고 결과를 다이얼로그로 노출.
Future<void> handleLibseatReturn(
  BuildContext context,
  WidgetRef ref,
  SeatReservation reservation,
) async {
  final roomNo = reservation.roomNo;
  final seatNo = reservation.seatNo;
  if (roomNo == null || seatNo == null) return;
  final ok = await showSejongConfirmDialog(
    context,
    icon: Symbols.logout,
    title: '좌석을 반납할까요?',
    message: '${reservation.roomName} 좌석을 반납합니다.',
    confirmLabel: '반납',
  );
  if (!ok || !context.mounted) return;
  final r = await returnLibseat(ref, roomNo: roomNo, seatNo: seatNo);
  if (!context.mounted) return;
  await showLibseatResultDialog(context, r, successTitle: '반납 완료');
}

/// 연장 버튼 — 정책(종료 120분 전부터) 선검사 후 [extendLibseat] 호출.
Future<void> handleLibseatExtend(
  BuildContext context,
  WidgetRef ref,
  SeatReservation reservation,
) async {
  final roomNo = reservation.roomNo;
  final seatNo = reservation.seatNo;
  if (roomNo == null || seatNo == null) return;
  if (!reservation.canExtendAt(DateTime.now())) {
    await showLibseatResultDialog(
      context,
      const LibseatResult(success: false, message: '연장은 종료시간 120분 전부터 가능합니다.'),
    );
    return;
  }
  final ok = await showSejongConfirmDialog(
    context,
    icon: Symbols.more_time,
    title: '이용 시간을 연장할까요?',
    message: '${reservation.roomName} 좌석을 연장합니다.',
    confirmLabel: '연장',
  );
  if (!ok || !context.mounted) return;
  final r = await extendLibseat(ref, roomNo: roomNo, seatNo: seatNo);
  if (!context.mounted) return;
  await showLibseatResultDialog(context, r, successTitle: '연장 완료');
}

// ─── 이용 내역 (실 libseat 이력 우선) ───────────────────────────────────────

/// 열람실 이용 내역 — mySeat.php 열람실 탭의 **실 이력**(날짜/시간/열람실/상태).
///
/// 로컬 timeline([usageHistoryProvider])과 달리 서버의 실제 이용 기록이라
/// 다른 기기/웹에서 한 예약도 모두 보인다. 네트워크 실패/빈 응답 시 로컬
/// timeline으로 fallback. 이용내역 화면·열람실 목록 카운트가 이 provider를 사용.
final seatUsageHistoryProvider =
    FutureProvider.autoDispose<List<LibraryUsageRecord>>((ref) async {
      ref.watch(currentUserProvider);
      try {
        final remote = await ref.watch(_libseatRemoteProvider.future);
        final entries = await remote.fetchSeatHistory();
        if (entries.isNotEmpty) {
          return entries.map(_seatHistoryToRecord).toList();
        }
      } catch (_) {
        // 토큰 만료/네트워크 오류 → 로컬 fallback.
      }
      return ref.watch(usageHistoryLocalProvider).getAll();
    });

/// libseat 이력 한 줄 → [LibraryUsageRecord]. 상태 문자열 → enum 매핑.
LibraryUsageRecord _seatHistoryToRecord(SeatHistoryEntry e) {
  final d = _parseHistDate(e.date);
  final (sh, sm, eh, em) = _parseHistTimeRange(e.timeRange);
  final start = DateTime(d.year, d.month, d.day, sh, sm);
  var end = DateTime(d.year, d.month, d.day, eh, em);
  if (end.isBefore(start)) end = end.add(const Duration(days: 1)); // 자정 넘김
  final status = e.status.contains('미반납')
      ? LibraryUsageStatus.unreturned
      : e.status.contains('자동')
      ? LibraryUsageStatus.autoReturned
      : LibraryUsageStatus.completed;
  return LibraryUsageRecord(
    startedAt: start,
    endedAt: end,
    roomLabel: e.roomName.isEmpty ? '열람실' : e.roomName,
    status: status,
  );
}

DateTime _parseHistDate(String s) {
  final m = RegExp(r'(\d{4})\.(\d{1,2})\.(\d{1,2})').firstMatch(s);
  if (m == null) return DateTime.now();
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

(int, int, int, int) _parseHistTimeRange(String s) {
  final m = RegExp(r'(\d{1,2}):(\d{2})\s*~\s*(\d{1,2}):(\d{2})').firstMatch(s);
  if (m == null) return (0, 0, 0, 0);
  return (
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
  );
}

// ─── 이용 내역 timeline 내부 helper (로컬 fallback) ─────────────────────────

Future<void> _appendHistory(
  WidgetRef ref, {
  required String roomLabel,
  required int durationMinutes,
  required LibraryUsageStatus status,
}) async {
  final now = DateTime.now();
  final record = LibraryUsageRecord(
    startedAt: now,
    endedAt: now.add(Duration(minutes: durationMinutes)),
    roomLabel: roomLabel,
    status: status,
  );
  await ref.read(usageHistoryLocalProvider).append(record);
}

/// 예약 직후 libseat이 `mySeat.php`에 반영되기까지의 짧은 지연을 흡수하는
/// bounded 재시도. 예약 성공 응답만으로 `now + 4h` 같은 추정 좌석을 만들지 않고,
/// 이 값이 잡힐 때만 정확한 종료시간/룸명을 카드와 알림에 반영한다.
/// 최악 ~2.5s(=4회 × 500ms gap) 후 포기 → 다음 폴링/resume이 서버값으로 정정.
Future<MySeat?> _fetchMySeatBounded(
  LibseatRemote remote, {
  int tries = 4,
  Duration gap = const Duration(milliseconds: 500),
}) async {
  for (var i = 0; i < tries; i++) {
    try {
      final m = await remote.fetchMySeat();
      if (m != null) return m;
    } catch (_) {
      // 네트워크 일시 오류 — 다음 시도로.
    }
    if (i < tries - 1) await Future<void>.delayed(gap);
  }
  return null;
}

int _durationMinutes(String? start, String? end) {
  if (start == null || end == null) return 0;
  final s = _toMin(start);
  final e = _toMin(end);
  if (s == null || e == null) return 0;
  final d = e - s;
  return d <= 0 ? 0 : d;
}

int? _toMin(String hhmm) {
  final m = RegExp(r'(\d{1,2})[:시]?\s*(\d{1,2})').firstMatch(hhmm);
  if (m == null) return null;
  return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}
