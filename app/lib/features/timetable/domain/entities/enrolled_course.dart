/// SJPT 수강내역(`SueReqLesnQ/doList.do`의 `dl_main`) 한 행 → 도메인 모델.
///
/// 시간표 그리드는 sjapp `/class-schedule` 셀(수업시간 있는 강의)만 그리므로
/// 온라인(e-러닝)·수업일 미등록(봉사 등) 강의가 빠진다. 이 모델은 **그 빠진
/// 강의까지 포함한 전체 수강 과목**을 담아 정확한 총학점 산정과 "시간표 외 강의"
/// 목록의 근거가 된다.
class EnrolledCourse {
  const EnrolledCourse({
    required this.curiNo,
    required this.className,
    required this.name,
    required this.credits,
    required this.category,
    required this.cyberTypeName,
    required this.timeAll,
    required this.cancelled,
  });

  final String curiNo;
  final String className;
  final String name;

  /// 학점(CDT). "3.0" → 3.0.
  final double credits;

  /// 이수구분(CURI_TYPE_CD_NM) — 전필/전선/공필/교선 등.
  final String category;

  /// 온라인 강의 유형(CYBER_TYPE_NM) — 예: "본교 e-러닝강의". 오프라인이면 null.
  final String? cyberTypeName;

  /// 수업시간 전체(TIME_ALL) — 예: "목19:00-20:00(최창희/호203)". 미등록이면 null.
  final String? timeAll;

  /// 수강취소 여부(CANCEL_YN == 'Y').
  final bool cancelled;

  String get id => '$curiNo-$className';

  /// 온라인(사이버/e-러닝) 강의.
  bool get isOnline => (cyberTypeName ?? '').trim().isNotEmpty;

  /// 수업일(시간)이 등록돼 있는가.
  bool get hasSchedule => (timeAll ?? '').trim().isNotEmpty;

  /// 시간표 그리드에 안 뜨는 강의 = 온라인 또는 수업일 미등록.
  bool get isOffGrid => isOnline || !hasSchedule;

  /// "3학점" / "1.5학점" — 정수면 소수점 제거.
  String get creditsLabel {
    final isWhole = credits == credits.roundToDouble();
    final n = isWhole ? credits.toInt().toString() : credits.toString();
    return '$n학점';
  }

  /// dl_main 한 행에서 생성. 필수 필드(과목명) 없으면 null.
  static EnrolledCourse? fromSjptRow(Map<String, dynamic> r) {
    final name = (r['CURI_NM'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    String? nz(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return EnrolledCourse(
      curiNo: (r['CURI_NO'] ?? '').toString(),
      className: (r['CLASS'] ?? r['CURI_CLASS'] ?? '').toString(),
      name: name,
      credits: double.tryParse((r['CDT'] ?? '').toString()) ?? 0,
      category: (r['CURI_TYPE_CD_NM'] ?? '').toString(),
      cyberTypeName: nz(r['CYBER_TYPE_NM']),
      timeAll: nz(r['TIME_ALL']),
      cancelled: (r['CANCEL_YN'] ?? '').toString().toUpperCase() == 'Y',
    );
  }
}

/// 한 학기 수강내역 요약 — 총학점/과목수 + 시간표 외(온라인·무수업일) 강의 분리.
class EnrolledSummary {
  const EnrolledSummary({
    required this.courses,
    required this.totalCredits,
    required this.online,
    required this.offlineNoSchedule,
  });

  /// 수강취소 제외 전체 과목.
  final List<EnrolledCourse> courses;

  /// 전체 학점(취소 제외, 온라인·무수업일 포함).
  final double totalCredits;

  /// 온라인(e-러닝) 강의.
  final List<EnrolledCourse> online;

  /// 온라인은 아니지만 수업일이 없는 강의(봉사 등).
  final List<EnrolledCourse> offlineNoSchedule;

  int get courseCount => courses.length;

  /// 시간표 외(그리드에 안 뜨는) 강의 = 온라인 + 무수업일.
  bool get hasOffGrid => online.isNotEmpty || offlineNoSchedule.isNotEmpty;

  /// "12" / "12.5" — 배지 표기용.
  String get totalCreditsLabel {
    final isWhole = totalCredits == totalCredits.roundToDouble();
    return isWhole ? totalCredits.toInt().toString() : totalCredits.toString();
  }

  factory EnrolledSummary.fromCourses(List<EnrolledCourse> all) {
    final active = [
      for (final c in all)
        if (!c.cancelled) c,
    ];
    return EnrolledSummary(
      courses: active,
      totalCredits: active.fold<double>(0, (s, c) => s + c.credits),
      online: [
        for (final c in active)
          if (c.isOnline) c,
      ],
      offlineNoSchedule: [
        for (final c in active)
          if (!c.isOnline && !c.hasSchedule) c,
      ],
    );
  }
}
