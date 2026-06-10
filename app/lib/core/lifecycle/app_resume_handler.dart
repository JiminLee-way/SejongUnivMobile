import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/auth/presentation/providers/auth_providers.dart';
import 'package:sejong_smart_campus/features/friends/presentation/providers/friends_providers.dart';
import 'package:sejong_smart_campus/features/home/presentation/providers/home_events_providers.dart';
import 'package:sejong_smart_campus/features/home_widgets/presentation/providers/home_widgets_providers.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/providers/libseat_providers.dart';
import 'package:sejong_smart_campus/features/library/presentation/providers/usage_history_providers.dart';
import 'package:sejong_smart_campus/features/notices/presentation/providers/notice_providers.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sejong_smart_campus/features/study_room/presentation/providers/study_room_providers.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/providers/timetable_providers.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/auto_attend_controller.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/providers/ucheck_providers.dart';

/// 백그라운드/잠자기에서 깨어났을 때 호출 — sjapp 세션 정합성과 화면 신선도를
/// 한 번에 보장한다.
///
/// 흐름:
/// 1. **선제 토큰 갱신** — access token이 만료(또는 1분 임박)면 명시적으로
///    `repo.refresh()` 호출. 이렇게 하면 사용자가 깬 직후 곧장 어떤 화면을
///    열어도 401 retry 체인이 화면 spinner를 길게 늘이는 일이 없다.
/// 2. **libseat token cache 초기화** — `_SjappLibseatTokenSource` 인스턴스가
///    들고 있는 10분 짜리 in-memory cache를 새 인스턴스로 교체. libseat
///    백엔드가 sleep 동안 세션을 끊었어도 다음 요청 때 fresh sjapp token으로
///    재발급된다.
/// 3. **활성 화면 data provider 일괄 invalidate** — 시설 예약/홈/시간표 등
///    어느 sub-screen에서 깨더라도 stale 상태 없이 새로 fetch.
///
/// [pauseDuration]이 짧으면(예: 30초 미만) Step 1만 수행하고 Step 2~3은
/// 건너뜀 — 잠깐 다른 앱 다녀온 케이스에서 불필요한 fetch 폭주 회피.
Future<void> handleAppResume(
  ProviderContainer container, {
  required Duration pauseDuration,
}) async {
  await _ensureFreshAccessToken(container);

  // V2 자동출석 — "지금이 출석 시간인가?"를 **복귀할 때마다(짧은 전환 포함)**
  // 확인한다. AppShell이 어느 탭에 있든 이 함수를 호출하므로 탭 독립적이고,
  // 컨트롤러 자체 30초 debounce가 폭주를 막는다. 무거운 일괄 invalidate(아래
  // 30초 게이트)와 **분리**해, 잠깐(<30초) 다른 앱을 보고 와도 출석 윈도우를
  // 놓치지 않게 한다. 자동출석 OFF면 controller가 즉시 early-return.
  // (controller가 ucheckDataProvider를 새로 fetch하므로 출석 시간이면 데이터도
  //  같이 최신화된다 — 출석 아님이면 아래 게이트의 invalidate가 화면을 갱신.)
  unawaited(
    container
        .read(autoAttendControllerProvider.notifier)
        .checkAndTrigger(reason: 'resume'),
  );

  // 짧은 일시정지(앱 전환, 빠른 알림 확인 등)는 도메인 cache까지 무효화하지
  // 않는다 — 새 자료가 필요한 사용자는 pull-to-refresh로 명시 가능.
  const heavyRefreshThreshold = Duration(seconds: 30);
  if (pauseDuration < heavyRefreshThreshold) return;

  // 자체서버 last_seen_at 갱신 — 처리방침 §보유기간 ④ "3개월 휴면 자동 삭제"
  // 산정 기준. heavyRefreshThreshold(30초)가 자연 throttle 역할을 하므로
  // 추가 cooldown 불필요. 익명 세션 없으면 remote가 silent skip.
  unawaited(
    container
        .read(supabaseOnboardingProvider)
        .updateLastSeen()
        .catchError((_) {}),
  );

  // libseat token 캐시 폐기.
  container.invalidate(libseatTokenSourceProvider);

  // 활성 화면 어디에 있어도 stale 상태를 노출하지 않도록 일괄 무효화.
  // family는 인자 없이 invalidate하면 모든 키 인스턴스 정리.
  // 열람실 대여 여부(홈 EventCard·열람실 탭 카드)는 mySeatProvider가 결정 —
  // resume마다 무효화해 백그라운드로 최신 발권 상태를 반영.
  container.invalidate(mySeatProvider);
  container.invalidate(roomListProvider);
  container.invalidate(seatMapProvider);
  container.invalidate(seatMapForRoomProvider);
  container.invalidate(facilityGroupsProvider);
  container.invalidate(facilityMapProvider);
  container.invalidate(timetableForSemesterProvider);
  container.invalidate(homeNoticePreviewProvider);
  container.invalidate(feedsLatestProvider);
  container.invalidate(homeBannersProvider);
  container.invalidate(homeEventsProvider);
  container.invalidate(unreadCountProvider);
  container.invalidate(usageHistoryProvider);
  container.invalidate(seatUsageHistoryProvider);
  container.invalidate(studyRoomStatusProvider);
  container.invalidate(myStudyRoomReservationsProvider);

  // UCheck — 사용자 요구: "잠자기/절전 복귀 시에도 매번 refreshSession + 새 data".
  // 자동출석이 OFF이거나 출석 시간이 아니어서 controller가 fetch하지 않았어도
  // 여기서 화면을 최신화한다.
  container.invalidate(ucheckDataProvider);

  // 7일치 알림 재예약 — 자정 넘어 깨거나 시간표/공휴일 데이터 갱신 시 반영.
  unawaited(
    container
        .read(autoAttendControllerProvider.notifier)
        .scheduleClassReminders(),
  );
}

void unawaited(Future<void> _) {}

/// access token이 만료/임박이면 선제적으로 refresh.
///
/// 실패는 silent — 다음 인터셉터 401 흐름이 자연스럽게 처리하거나, refresh
/// cookie 자체가 만료라면 AuthGate가 로그인 화면으로 라우팅.
Future<void> _ensureFreshAccessToken(ProviderContainer container) async {
  try {
    final storage = container.read(tokenStorageProvider);
    final valid = await storage.isAccessTokenLikelyValid();
    if (valid) return;
    final repo = await container.read(authRepositoryProvider.future);
    await repo.refresh();
  } catch (_) {
    // 잠자기 중 cookie 만료 등 — 다음 요청에서 사용자에게 자연스럽게 노출.
  }
}
