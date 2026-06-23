/// 통합 서비스 API endpoint 상수.
///
/// `${SejongPrefix.secureApi}/...` 같은 식으로 합성해서 사용한다.
/// 절대 base URL은 dart-define으로 주입한다.
///
/// 새 endpoint를 추가할 때는 호출 목적과 응답 형태를 코드 리뷰에서 함께 남긴다.
library;

class SejongPrefix {
  const SejongPrefix._();
  static const String auth = '/api/auth';
  static const String publicApi = '/api/publicapi';
  static const String secureApi = '/api/secureapi';
  static const String ums = '/api/v1/ums';
  static const String mcp = '/api/v1/mcp';
}

class SejongEndpoints {
  const SejongEndpoints._();

  // 인증
  static const String login = '${SejongPrefix.auth}/login';
  static const String refresh = '${SejongPrefix.auth}/refresh';
  static const String ssoVerify = '${SejongPrefix.auth}/sso/verify';
  static const String me = '${SejongPrefix.auth}/me';
  static const String logout = '${SejongPrefix.auth}/logout';

  // 메뉴 트리 (menuId로 path 합성)
  static String menuTree(String menuId) =>
      '${SejongPrefix.publicApi}/menus/$menuId/authorized/tree';

  // 홈 위젯
  static const String weather = '${SejongPrefix.publicApi}/weather';
  static const String homeBanners =
      '${SejongPrefix.publicApi}/home-banners?type=MAIN';
  static const String popups =
      '${SejongPrefix.publicApi}/popups?page=0&size=100';
  static const String i18nMessages = '${SejongPrefix.publicApi}/i18n/messages';
  static const String universityNoticeLatest =
      '${SejongPrefix.publicApi}/university-notice/latest';

  /// 세종소식 계열 5 type — `/sejong-news/{slug}` 패턴.
  /// slug ∈ {news, media, press, sejong-webzine, engineering-webzine}.
  static const String sejongNews = '${SejongPrefix.publicApi}/sejong-news/news';
  static String sejongNewsList(String slug) =>
      '${SejongPrefix.publicApi}/sejong-news/$slug';
  static String sejongNewsDetail(String slug, String id) =>
      '${SejongPrefix.publicApi}/sejong-news/$slug/$id';

  /// 대학공지 detail — `/university-notice/{type}/{id}`.
  static String universityNoticeDetail(String type, String id) =>
      '${SejongPrefix.publicApi}/university-notice/$type/$id';

  static const String feedsLatest = '${SejongPrefix.publicApi}/feeds/latest';

  // 교내 전화번호 (교직원 디렉터리, 공개 — 인증 불필요)
  /// `?page&size&keyword&searchType` — searchType ∈ {name,major,phone}(생략=전체).
  /// 응답 data는 Spring Pageable: `content:[{name,position,department,phone}]`.
  static const String phoneDirectory = '${SejongPrefix.publicApi}/phone-number';

  // 학식
  static const String foodBuildings =
      '${SejongPrefix.publicApi}/food/buildings';
  static String foodPlacesOfBuilding(int buildingId) =>
      '${SejongPrefix.publicApi}/food/buildings/$buildingId/places';
  static String foodMealTypes(int placeId) =>
      '${SejongPrefix.publicApi}/food/places/$placeId/meal-types';
  static String foodSchedulesOfDate(String yyyyMmDd, {required int placeId}) =>
      '${SejongPrefix.publicApi}/food/schedules/date/$yyyyMmDd?placeId=$placeId';

  // 시간표
  static const String availableSemesters =
      '${SejongPrefix.secureApi}/class-schedule/available-semesters';
  static const String timetable =
      '${SejongPrefix.secureApi}/class-schedule/timetable';
  static const String enrolledCourses =
      '${SejongPrefix.secureApi}/class-schedule/enrolled-courses';

  // 학생증
  static const String photosMe = '${SejongPrefix.secureApi}/photos/me';
  static const String qrGenerate = '${SejongPrefix.secureApi}/qr/generate';

  // 도서관
  static const String libraryReadingRoomToken =
      '${SejongPrefix.secureApi}/library/reading-room-token';
  static const String libraryLoanInfo =
      '${SejongPrefix.secureApi}/library/loan-info';

  // 성적·일정
  static const String gradeInquiryAll =
      '${SejongPrefix.secureApi}/grade-inquiry/all';
  static const String gradeInquiryCurrent =
      '${SejongPrefix.secureApi}/grade-inquiry/current';

  /// 특정 학기 성적 — `data` 는 `GradeSelectedSemester` 모양.
  static String gradeInquirySemester(String year, String smtCd) =>
      '${SejongPrefix.secureApi}/grade-inquiry/semester?year=$year&smtCd=$smtCd';
  static String academicCalendarDaily(String yyyyMmDd) =>
      '${SejongPrefix.publicApi}/academic-calendar/daily?date=$yyyyMmDd';
  static String studentDailyAll(String yyyyMmDd) =>
      '${SejongPrefix.secureApi}/academic-calendar/student/daily-all?date=$yyyyMmDd';

  /// 월간 marks — `data.scheduleDates: [1,5,9,...]` 형태로 해당 월 중
  /// 일정이 있는 날짜 day-of-month list만 반환. month grid의 dot 마커용.
  static String academicCalendarMonthlyMarks(int year, int month) =>
      '${SejongPrefix.publicApi}/academic-calendar/monthly-marks?year=$year&month=$month';
  static String studentMonthlyMarks(int year, int month, {String? orgCode}) {
    final base =
        '${SejongPrefix.secureApi}/academic-calendar/student/monthly-marks?year=$year&month=$month';
    return orgCode == null ? base : '$base&orgCode=$orgCode';
  }

  /// 학과/대학원 목록 — `[{code:"20",name:"학부"},...]`.
  /// `student/daily?orgCode=...` 필터링 옵션 source.
  static const String academicOrganizationTypes =
      '${SejongPrefix.secureApi}/academic-calendar/organization-types';
  static String studentDaily(String yyyyMmDd, {required String orgCode}) =>
      '${SejongPrefix.secureApi}/academic-calendar/student/daily?date=$yyyyMmDd&orgCode=$orgCode';

  // 알림함
  static const String umsInbox = '${SejongPrefix.ums}/inbox';
}
