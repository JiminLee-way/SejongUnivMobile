/// 행복기숙사 주간식단 응답 매핑.
///
/// 원본 endpoint:
///   POST /food/getWeeklyMenu.do  (form: locgbn=SJ&sch_date=YYYY-MM-DD?)
///
/// 응답:
///   { root: [ { WEEKLYMENU: [ { fo_date1..7, fo_menu_mor1..7,
///                                fo_menu_lun1..7, fo_menu_eve1..7,
///                                fo_sub_menu1..7, today, locgbn, seq } ],
///              LASTNEXT:  [ { go, mon_date? }, ... ] } ] }
///
/// fo_date{i} 는 i=1(월) ~ i=7(일). [DateTime.weekday]도 1(월) ~ 7(일)이라
/// 그대로 인덱싱 가능.
///
/// `WEEKLYMENU`가 빈 배열 → 아직 업로드되지 않은 주.
/// 어떤 하루의 mor/lun/eve가 모두 빈 문자열 → 그 날만 미업로드.
library;

class HappydormWeeklyMenu {
  const HappydormWeeklyMenu({required this.days, required this.today});

  /// 키: 'yyyy-MM-dd' (서버가 준 문자열 그대로). 7일치.
  final Map<String, HappydormDayMenu> days;

  /// 서버 기준 오늘 — 단순 디버깅·테스트용. 클라이언트는 자신의 [DateTime.now]
  /// 와 [selectedDateProvider] 를 신뢰.
  final String? today;

  bool get isEmpty => days.isEmpty;

  HappydormDayMenu? forDate(String yyyyMmDd) => days[yyyyMmDd];

  /// 빈 응답 — 아직 업로드되지 않은 주.
  static const empty = HappydormWeeklyMenu(days: {}, today: null);

  factory HappydormWeeklyMenu.fromJson(Map<String, dynamic> json) {
    final root = (json['root'] as List?) ?? const [];
    if (root.isEmpty) return empty;
    final first = (root.first as Map).cast<String, dynamic>();
    final weekly = (first['WEEKLYMENU'] as List?) ?? const [];
    if (weekly.isEmpty) return empty;
    final w = (weekly.first as Map).cast<String, dynamic>();

    String s(String k) => (w[k] ?? '').toString();
    final days = <String, HappydormDayMenu>{};
    for (var i = 1; i <= 7; i++) {
      final date = s('fo_date$i');
      if (date.isEmpty) continue;
      days[date] = HappydormDayMenu(
        date: date,
        breakfast: s('fo_menu_mor$i'),
        lunch: s('fo_menu_lun$i'),
        dinner: s('fo_menu_eve$i'),
        subMenu: s('fo_sub_menu$i'),
      );
    }
    return HappydormWeeklyMenu(days: days, today: s('today'));
  }
}

class HappydormDayMenu {
  const HappydormDayMenu({
    required this.date,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.subMenu,
  });

  final String date;
  final String breakfast; // 조식
  final String lunch; // 중식
  final String dinner; // 석식
  final String subMenu; // 대체식/간편식 안내 — 보통 안내 문구

  bool get hasAnyMeal =>
      breakfast.trim().isNotEmpty ||
      lunch.trim().isNotEmpty ||
      dinner.trim().isNotEmpty;

  /// 공백 split → 빈 문자열 제거. 메뉴 문자열은 "쌀밥 미역국 ..." 처럼 공백 구분.
  /// "정전으로 인한 식당 휴무" 같은 안내 문구도 그대로 토큰화되지만 UI에서
  /// 단순 텍스트로 보여주므로 의미를 잃지 않는다.
  static List<String> tokenize(String menu) =>
      menu.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
}
