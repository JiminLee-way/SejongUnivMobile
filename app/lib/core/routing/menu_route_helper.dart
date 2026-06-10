import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sejong_smart_campus/core/network/service_urls.dart';
import 'package:sejong_smart_campus/core/routing/app_page_route.dart';
import 'package:sejong_smart_campus/shared/widgets/app_toast.dart';
import 'package:sejong_smart_campus/features/academic/presentation/screens/grades_screen.dart';
import 'package:sejong_smart_campus/features/cafeteria/presentation/screens/cafeteria_screen.dart';
import 'package:sejong_smart_campus/features/finance/presentation/screens/finance_screen.dart';
import 'package:sejong_smart_campus/features/library/presentation/screens/library_list_screen.dart';
import 'package:sejong_smart_campus/features/libseat/presentation/screens/libseat_screen.dart';
import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';
import 'package:sejong_smart_campus/features/menu/presentation/screens/settings_screen.dart';
import 'package:sejong_smart_campus/features/notices/domain/entities/notice_models.dart';
import 'package:sejong_smart_campus/features/notices/presentation/screens/news_screen.dart';
import 'package:sejong_smart_campus/features/notices/presentation/screens/notices_screen.dart';
import 'package:sejong_smart_campus/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:sejong_smart_campus/features/phone_directory/presentation/screens/phone_directory_screen.dart';
import 'package:sejong_smart_campus/features/shell/presentation/screens/app_shell.dart';
import 'package:sejong_smart_campus/features/sjpt/presentation/screens/sjpt_screen.dart';
import 'package:sejong_smart_campus/features/study_room/presentation/screens/study_room_screen.dart';
import 'package:sejong_smart_campus/features/support/presentation/screens/support_screen.dart';
import 'package:sejong_smart_campus/features/timetable/presentation/screens/timetable_screen.dart';
import 'package:sejong_smart_campus/features/ucheck/presentation/screens/ucheck_screen.dart';

/// 메뉴 키(`SejongMenuItem.url` 또는 `client.*` 가상 키) 1개로 화면 이동.
///
/// 라우팅 가능하면 true. 알려진 키가 아니거나 dispatcher 위임이 필요하면 false.
/// services_screen / home_screen 둘 다 사용.
///
/// 일부 키는 [SejongMenuItem.parsedCallParams]가 필요해 [params] 인자로 받음.
/// (홈 바로가기 경로에서는 params 없음 — 기본 카테고리로 폴백.)
bool routeByKey(
  BuildContext context,
  String key, {
  Map<String, dynamic>? params,
}) {
  Future<void> push(Widget screen) async {
    await Navigator.of(context, rootNavigator: true).push(slideRoute(screen));
  }

  // 열람실 URL 직접 push
  if (ServiceUrls.libseat.isNotEmpty &&
      key.startsWith(ServiceUrls.libseat) &&
      key.contains('seatMain.php')) {
    push(const LibseatScreen());
    return true;
  }
  if (key == 'client.sjpt' ||
      (ServiceUrls.sjpt.isNotEmpty && key.startsWith(ServiceUrls.sjpt))) {
    push(const SjptScreen());
    return true;
  }
  switch (key) {
    case 'aca.classSchedule':
      push(const TimetableScreen());
      return true;
    case 'inf.universityLife.schoolCafeteria':
      push(const CafeteriaScreen());
      return true;
    case 'inf.notice.list':
      final type = (params?['type'] ?? 'general').toString().trim();
      final newsCat = NewsCategory.fromType(type);
      if (newsCat != null) {
        push(NewsScreen(category: newsCat));
      } else {
        final cat = NoticeCategory.fromType(type) ?? NoticeCategory.general;
        push(NoticesScreen(initial: cat));
      }
      return true;
    case 'cmm.notificationBox':
      push(const NotificationsScreen());
      return true;
    case 'inf.scheduleManagement':
      // 학사일정 — 자체 네이티브 캘린더 대신 세종대 공식 웹 학사일정 페이지를
      // 인앱 브라우저로 노출(가독성이 더 좋음).
      unawaited(openAcademicCalendar(context));
      return true;
    case 'aca.gradeInquiry':
    case 'aca.currentSemesterGrade':
      push(const GradesScreen());
      return true;
    case 'aca.scholarshipStatus':
      push(const FinanceScreen(initial: FinanceTab.scholarship));
      return true;
    case 'aca.tuitionDetails':
      push(const FinanceScreen(initial: FinanceTab.tuition));
      return true;
    case 'aca.discretionarySpending':
      push(const FinanceScreen(initial: FinanceTab.discretionary));
      return true;
    case 'cmm.faq':
    case 'client.support':
      push(const SupportScreen());
      return true;
    case 'client.settings':
      push(const SettingsScreen());
      return true;
    case 'svc.studyRoomStatus':
      push(const StudyRoomScreen(initial: StudyRoomTab.status));
      return true;
    case 'svc.studyRoomReservation':
      push(const StudyRoomScreen(initial: StudyRoomTab.reservations));
      return true;
    case 'client.libraryFloors':
      push(const LibraryListScreen());
      return true;
    case 'client.phoneDirectory':
      push(const PhoneDirectoryScreen());
      return true;
    case 'client.communityTab':
    case 'client.communityTab.switch':
      // 커뮤니티는 nav 탭(index 2)이다. 전체서비스에서 standalone push하면
      // CommunityScreen이 투명 Scaffold(자체 MeshBackground 없음)라 opaque
      // route 위에서 검은 배경으로 보였고(탭 화면이라 뒤로가기 버튼도 없어
      // 갇힘), AppShell의 MeshBackground는 push된 route 아래에 있어 비치지
      // 않았다. 그래서 standalone push 대신 **탭 전환**한다(드로어면 닫고).
      _switchTab(context, 2);
      return true;
    case 'client.libseat':
      // 바로가기 가상 키 — LibseatScreen 직접 push
      push(const LibseatScreen());
      return true;
    case 'client.uCheckTab':
      // UCheck는 nav 탭에서 빠지고 sub-screen으로 push (열람실·학식 패턴).
      push(const UCheckScreen());
      return true;
    // 동아리/연구실/청원 — 미구현. dispatcher fallback(느린 웹뷰/그룹헤더)으로 새지
    // 않도록 여기서 즉시 "준비 중" 안내. (전체서비스·홈 바로가기 공통 경로)
    case 'client.club':
      showRouteUnavailable(context, '동아리');
      return true;
    case 'client.lab':
      showRouteUnavailable(context, '연구실');
      return true;
    case 'client.petition':
      showRouteUnavailable(context, '청원');
      return true;
    default:
      return false;
  }
}

/// 편의 wrapper — SejongMenuItem을 받아 callParams까지 전달.
bool routeByMenuItem(BuildContext context, SejongMenuItem item) {
  return routeByKey(context, item.url, params: item.parsedCallParams());
}

/// 학사일정 웹페이지 — 자체 네이티브 캘린더보다 가독성이 좋아 웹으로 노출.
const String kAcademicCalendarUrl =
    '${ServiceUrls.sejongWeb}/kor/academics/academic-calendar.do?mode=calendar';

/// 학사일정 — 세종대 공식 웹 학사일정을 인앱 브라우저로 연다.
Future<void> openAcademicCalendar(BuildContext context) async {
  try {
    final ok = await launchUrl(
      Uri.parse(kAcademicCalendarUrl),
      mode: LaunchMode.inAppBrowserView,
    );
    if (!ok && context.mounted) showRouteUnavailable(context, '학사일정');
  } catch (_) {
    if (context.mounted) showRouteUnavailable(context, '학사일정');
  }
}

/// 키 라우팅 실패 시 "준비 중" 토스트.
///
/// SnackBar는 루트 Scaffold(AppShell) 하단에만 떠서 커스텀 바텀 네비/열린
/// 드로어 뒤로 가려졌다(전체서비스 동아리/연구실/청원 안내가 안 보이던 원인).
/// 루트 Overlay 토스트로 그 위에 띄운다. [showAppToast] 참고.
void showRouteUnavailable(BuildContext context, String label) {
  showAppToast(context, '$label은(는) 아직 준비 중이에요');
}

void _switchTab(BuildContext context, int index) {
  try {
    AppShell.of(context).switchTab(index);
  } catch (_) {
    // AppShell 외부 컨텍스트 — 무시.
  }
}
