import 'package:flutter_test/flutter_test.dart';
import 'package:sejong_smart_campus/features/timetable/domain/entities/enrolled_course.dart';

/// `EnrolledCourse.fromSjptRow` + `EnrolledSummary.fromCourses` 회귀 —
/// SJPT 수강내역(`SueReqLesnQ/doList.do` dl_main) 기반 전체 학점 산정과
/// 온라인/수업일 미등록 강의 분류.
///
/// 데이터는 수강내역.har 실측(2025/2학기 8과목): 그리드 6 + 온라인 1
/// (인공지능과빅데이터, e-러닝) + 무수업일 1(세종사회봉사1). 합계 19학점.
void main() {
  Map<String, dynamic> row({
    required String nm,
    required String cdt,
    String? cyber,
    String? time,
    String cancel = '',
    String cls = '001',
    String curiNo = '000000',
    String type = '전선',
  }) => {
    'CURI_NM': nm,
    'CDT': cdt,
    'CYBER_TYPE_NM': cyber,
    'TIME_ALL': time,
    'CANCEL_YN': cancel,
    'CLASS': cls,
    'CURI_NO': curiNo,
    'CURI_TYPE_CD_NM': type,
  };

  // 수강내역.har 실측 8행.
  final harRows = [
    row(nm: '세종인을위한전공탐색', cdt: '1.0', time: '목19:00-20:00(최창희/호203)'),
    row(nm: '서양철학:쟁점과토론', cdt: '3.0', time: '수11:00-13:00(고현범/이203)'),
    row(nm: '대학영어', cdt: '2.0', time: '월11:00-13:00(Young In Chang/군514)'),
    row(nm: '고급C프로그래밍및실습', cdt: '3.0', time: '화10:00-12:00(김종현/호202)'),
    row(nm: '공업수학1', cdt: '3.0', time: '화목16:30-18:00(우형수/이204)'),
    row(nm: '인공지능과빅데이터', cdt: '3.0', cyber: '본교 e-러닝강의'), // 온라인, TIME 없음
    row(nm: '선형대수', cdt: '3.0', time: '월수13:30-15:00(배진수/충908)'),
    row(nm: '세종사회봉사1', cdt: '1.0'), // 무수업일(봉사), 온라인 아님
  ];

  test('fromSjptRow — 온라인/무수업일/학점 분류', () {
    final online = EnrolledCourse.fromSjptRow(harRows[5])!;
    expect(online.name, '인공지능과빅데이터');
    expect(online.credits, 3.0);
    expect(online.isOnline, isTrue);
    expect(online.hasSchedule, isFalse);
    expect(online.isOffGrid, isTrue);
    expect(online.creditsLabel, '3학점');

    final volunteer = EnrolledCourse.fromSjptRow(harRows[7])!;
    expect(volunteer.isOnline, isFalse);
    expect(volunteer.hasSchedule, isFalse);
    expect(volunteer.isOffGrid, isTrue);
    expect(volunteer.creditsLabel, '1학점');

    final normal = EnrolledCourse.fromSjptRow(harRows[1])!;
    expect(normal.hasSchedule, isTrue);
    expect(normal.isOffGrid, isFalse);
  });

  test('EnrolledSummary — 전체 19학점/8과목, 온라인1·무수업일1', () {
    final s = EnrolledSummary.fromCourses([
      for (final r in harRows) EnrolledCourse.fromSjptRow(r)!,
    ]);
    expect(s.courseCount, 8);
    expect(s.totalCredits, 19.0);
    expect(s.totalCreditsLabel, '19');
    expect(s.online.map((c) => c.name), ['인공지능과빅데이터']);
    expect(s.offlineNoSchedule.map((c) => c.name), ['세종사회봉사1']);
    expect(s.hasOffGrid, isTrue);
  });

  test('수강취소(CANCEL_YN=Y) 과목은 학점/목록에서 제외', () {
    final s = EnrolledSummary.fromCourses([
      EnrolledCourse.fromSjptRow(row(nm: '유효과목', cdt: '3.0', time: '월1'))!,
      EnrolledCourse.fromSjptRow(row(nm: '취소과목', cdt: '3.0', cancel: 'Y'))!,
    ]);
    expect(s.courseCount, 1);
    expect(s.totalCredits, 3.0);
    expect(s.hasOffGrid, isFalse);
  });

  test('빈 과목명 행은 null', () {
    expect(EnrolledCourse.fromSjptRow({'CURI_NM': '  '}), isNull);
    expect(EnrolledCourse.fromSjptRow({'CDT': '3.0'}), isNull);
  });
}
