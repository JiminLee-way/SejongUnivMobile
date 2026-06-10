// UCheck 화면 한 화면치의 모든 데이터 — 학생명/현재 주차/총 주차/강의 목록.
//
// 여러 API(web mobileInfo/login + per-lecture records)를 머지한 결과를 담는
// "presentation-ready" 컨테이너. 화면은 이 한 객체만 watch하면 된다.

import 'package:sejong_smart_campus/features/ucheck/domain/entities/lecture_with_attendance.dart';

/// 한 학기 한 학생의 UCheck 전체 상태.
class UCheckData {
  const UCheckData({
    required this.studentName,
    required this.currentWeek,
    required this.totalWeeks,
    required this.lectures,
  });

  /// 학생 이름.
  final String studentName;

  /// 현재 주차 (1-indexed). 학기 시작 전이면 0.
  final int currentWeek;

  /// 학기 총 주차 (보통 16).
  final int totalWeeks;

  /// 강의별 출결 wrapper 리스트.
  final List<LectureWithAttendance> lectures;

  /// 초기 상태/빈 상태 표현용. `const`이라 위젯 비교에 안전.
  static const UCheckData empty = UCheckData(
    studentName: '',
    currentWeek: 0,
    totalWeeks: 16,
    lectures: <LectureWithAttendance>[],
  );
}
