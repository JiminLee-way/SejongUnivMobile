/// 한국천문연구원 특일 정보 — `getRestDeInfo` 응답 한 건.
class Holiday {
  const Holiday({
    required this.date,
    required this.name,
    required this.isHoliday,
  });

  /// 양력 날짜 (시각 부분은 00:00).
  final DateTime date;

  /// "어린이날", "부처님오신날" 등.
  final String name;

  /// 실제로 쉬는 날인지 — 일부 기념일은 N(평일)일 수 있음.
  final bool isHoliday;
}
