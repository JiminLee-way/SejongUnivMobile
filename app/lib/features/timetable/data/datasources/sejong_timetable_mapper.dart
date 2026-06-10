/// 세종 공식 `/api/secureapi/class-schedule/*` 응답 → 우리 도메인 매핑.
///
/// 기존 mock Course/Timetable 구조를 그대로 유지하므로 화면 위젯(TimetableGrid,
/// _CreditSummary 등)은 수정 없이 사용 가능. 학기는 (year, smtCd)를 기존
/// Semester enum에 매핑 — 매핑 표가 없으면 null (UI는 fallback 처리).
///
/// 핵심:
///   - hourCd ↔ 시각: **시작 = 07:30 + hourCd × 30분** (sjapp 백엔드 공식)
///   - dayCd 1~5 = 월~금
///   - 30분 cell들을 (dayCd, curiNo, className)로 묶고 연속 hourCd끼리 merge
///   - palette는 curiNo 해시로 deterministic 배정 (학기 안에서 같은 강의=같은 색)
library;

import 'package:sejong_smart_campus/features/timetable/domain/entities/timetable_models.dart';

class SejongTimetableMapper {
  const SejongTimetableMapper._();

  static const Map<Semester, (String year, String smtCd)> _semToSjapp = {
    Semester.spring2025: ('2025', '10'),
    Semester.summer2025: ('2025', '11'),
    Semester.fall2025: ('2025', '20'),
    Semester.winter2025: ('2025', '21'),
    Semester.spring2026: ('2026', '10'),
  };

  /// `(year, smtCd)` → 우리 enum. 미정의 학기는 null.
  static Semester? toSemester(String year, String smtCd) {
    for (final e in _semToSjapp.entries) {
      if (e.value.$1 == year && e.value.$2 == smtCd) return e.key;
    }
    return null;
  }

  static (String year, String smtCd)? toSejongKey(Semester s) => _semToSjapp[s];

  /// `Semester.spring2025` 같은 표시 라벨이 enum에 없는 경우, sjapp 키를
  /// "2026-1" 같은 한국식 라벨로 변환.
  static String prettyLabel(String year, String smtCd) {
    final tail = switch (smtCd) {
      '10' => '1학기',
      '11' => '여름학기',
      '20' => '2학기',
      '21' => '겨울학기',
      _ => smtCd,
    };
    return '$year년 $tail';
  }

  /// 30분 셀 시각 — `hourCd` → "HH:mm".
  static (int hour, int minute) hourCdToTime(String hourCd) {
    final n = int.tryParse(hourCd) ?? 0;
    final total = 7 * 60 + 30 + n * 30; // 07:30 baseline
    return (total ~/ 60, total % 60);
  }

  /// 화·목→Weekday 매핑 (dayCd "1"=월 ... "5"=금). 토일은 mock에 없으므로
  /// 만약 들어오면 null 반환 — 그리드에 안 그려진다.
  static Weekday? dayCdToWeekday(String dayCd) {
    return switch (dayCd) {
      '1' => Weekday.mon,
      '2' => Weekday.tue,
      '3' => Weekday.wed,
      '4' => Weekday.thu,
      '5' => Weekday.fri,
      _ => null,
    };
  }

  /// sjapp `enrolled-courses` 응답 + `timetable.courses` 셀 배열 + `cyberLectures`를
  /// 받아 [Timetable] 객체로 묶는다.
  ///
  /// [enrolled]는 강의 메타(이름·교수·학점·강의실)의 출처.
  /// [cells]는 grid 배치를 위한 30분 cell 배열 — 같은 강의의 연속 cell을 묶어
  /// `CourseTime`으로 변환한다.
  /// [cyberLectures]는 시간 슬롯 없는 사이버 강의명 — `times: []`인 Course로 추가.
  static Timetable buildTimetable({
    required Semester semester,
    required List<Map<String, dynamic>> enrolled,
    required List<Map<String, dynamic>> cells,
    required List<String> cyberLectures,
  }) {
    // 1) (curiNo, className) → 기본 Course 정보
    final base = <String, _CourseBase>{};
    for (final e in enrolled) {
      final curiNo = (e['curiNo'] ?? '').toString();
      final className = (e['className'] ?? '').toString();
      final key = '$curiNo-$className';
      base[key] = _CourseBase(
        id: key,
        name: (e['name'] ?? '').toString(),
        professor: (e['professor'] ?? '').toString(),
        building: (e['building'] ?? '').toString(),
        credits: ((e['credits'] as num?) ?? 3).toInt(),
        category: (e['category'] ?? '').toString(),
      );
    }

    // 2) cell들을 (key, dayCd) 그룹으로 묶고 hourCd 정렬 후 연속 merge
    final grouped =
        <String, Map<String, List<_CellRef>>>{}; // key → dayCd → cells
    for (final c in cells) {
      final curiNo = (c['curiNo'] ?? '').toString();
      final className = (c['className'] ?? '').toString();
      final dayCd = (c['dayCd'] ?? '').toString();
      final hourCd = (c['hourCd'] ?? '').toString();
      final key = '$curiNo-$className';
      grouped
          .putIfAbsent(key, () => {})
          .putIfAbsent(dayCd, () => [])
          .add(
            _CellRef(
              hourCd: int.tryParse(hourCd) ?? 0,
              roomNmAlias: (c['roomNmAlias'] ?? '').toString(),
              curiNm: (c['curiNm'] ?? '').toString(),
              empNm: (c['empNm'] ?? '').toString(),
              curiTypeCdNm: (c['curiTypeCdNm'] ?? '').toString(),
            ),
          );
    }

    // 3) 빌드. enrolled에 없지만 cells엔 있는 경우(과거 데이터 잔여 등)는
    //    cell 정보로 base 보강.
    final courses = <Course>[];
    for (final key in {...base.keys, ...grouped.keys}) {
      final times = <CourseTime>[];
      final byDay = grouped[key];
      String? professorFromCell;
      String? roomFromCell;
      String? nameFromCell;
      if (byDay != null) {
        for (final entry in byDay.entries) {
          final wd = dayCdToWeekday(entry.key);
          if (wd == null) continue;
          final sorted = [...entry.value]
            ..sort((a, b) => a.hourCd.compareTo(b.hourCd));
          // 연속 hourCd 묶기
          int? segStart;
          int? segEnd;
          for (final cell in sorted) {
            professorFromCell ??= cell.empNm;
            roomFromCell ??= cell.roomNmAlias;
            nameFromCell ??= cell.curiNm;
            if (segStart == null) {
              segStart = cell.hourCd;
              segEnd = cell.hourCd;
              continue;
            }
            // 같은 hourCd가 두 번 이상 오는 팀티칭(공동담당) 강의 — sjapp이 한 30분
            // 슬롯을 담당 교수 수만큼 중복 cell로 내려준다(예: 임베디드시스템은
            // 김재호+석문기 공동 강의라 hourCd가 3,3,4,4,…처럼 두 번씩 옴). 시각이
            // 동일하므로 건너뛴다. 건너뛰지 않으면 연속 판정(== segEnd+1)이 깨져 한
            // 강의가 30분짜리 블록 여러 개로 쪼개져 겹쳐 그려진다.
            // (sorted 오름차순이라 중복은 cell.hourCd <= segEnd 로 잡힌다. 이 `!`는
            //  segEnd를 non-null로 승격시키므로 아래 줄의 `!`는 제거했다.)
            if (cell.hourCd <= segEnd!) continue;
            if (cell.hourCd == segEnd + 1) {
              segEnd = cell.hourCd;
            } else {
              times.add(_segmentToTime(wd, segStart, segEnd));
              segStart = cell.hourCd;
              segEnd = cell.hourCd;
            }
          }
          if (segStart != null) {
            times.add(_segmentToTime(wd, segStart, segEnd!));
          }
        }
      }

      final b = base[key];
      final name = b?.name ?? nameFromCell ?? '강의';
      // "최낙중 교수" → "최낙중" — UI는 일관되게 이름만.
      final prof = (b?.professor ?? professorFromCell ?? '').replaceAll(
        RegExp(r'\s*교수$'),
        '',
      );
      courses.add(
        Course(
          id: key,
          code: key,
          name: name,
          professor: prof,
          location: b?.building ?? roomFromCell ?? '',
          palette: _paletteOf(key),
          credits: b?.credits ?? 3,
          times: times,
        ),
      );
    }

    // 4) cyberLectures — times 없는 Course 추가 (학점 합산엔 들어가지 않도록
    //    enrolled 기준 학점만 합산. 표시는 별도 섹션에서.)
    final existingNames = courses.map((c) => c.name).toSet();
    for (final cy in cyberLectures) {
      if (existingNames.contains(cy)) continue;
      courses.add(
        Course(
          id: 'cyber-$cy',
          code: 'CYBER',
          name: cy,
          professor: '',
          location: '사이버 강좌',
          palette: _paletteOf(cy),
          credits: 0,
          times: const [],
        ),
      );
    }

    // 정렬: 가장 이른 시간 가진 강의 → 사이버 강의 순.
    courses.sort((a, b) {
      final am = _firstMinute(a) ?? 99999;
      final bm = _firstMinute(b) ?? 99999;
      return am.compareTo(bm);
    });

    return Timetable(semester: semester, courses: courses);
  }

  // ─── helpers ────────────────────────────────────────────────────────────

  static CourseTime _segmentToTime(Weekday wd, int startHourCd, int endHourCd) {
    final (sh, sm) = hourCdToTime(startHourCd.toString());
    // endHourCd가 가리키는 30분 cell의 "끝" 시각 = 다음 cell 시작.
    final (eh, em) = hourCdToTime((endHourCd + 1).toString());
    return CourseTime(weekday: wd, start: HMTime(sh, sm), end: HMTime(eh, em));
  }

  /// curiNo·이름 해시로 안정적 팔레트 선택 — 한 학기 내 같은 강의=같은 색.
  static CoursePalette _paletteOf(String key) {
    final h = key.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return CoursePalette.values[h % CoursePalette.values.length];
  }

  static int? _firstMinute(Course c) {
    if (c.times.isEmpty) return null;
    final m = c.times
        .map((t) => t.start.totalMinutes + t.weekday.index * 24 * 60)
        .reduce((a, b) => a < b ? a : b);
    return m;
  }
}

class _CourseBase {
  _CourseBase({
    required this.id,
    required this.name,
    required this.professor,
    required this.building,
    required this.credits,
    required this.category,
  });
  final String id;
  final String name;
  final String professor;
  final String building;
  final int credits;
  final String category;
}

class _CellRef {
  _CellRef({
    required this.hourCd,
    required this.roomNmAlias,
    required this.curiNm,
    required this.empNm,
    required this.curiTypeCdNm,
  });
  final int hourCd;
  final String roomNmAlias;
  final String curiNm;
  final String empNm;
  final String curiTypeCdNm;
}
