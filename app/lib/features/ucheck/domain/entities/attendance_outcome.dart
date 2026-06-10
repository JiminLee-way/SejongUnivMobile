// BLE 출석 체크 시도의 결과 — sealed class로 분기.
//
// 화면 쪽은 `switch (outcome) { case AttendedOutcome ... }` 패턴으로 처리 →
// Dart 3 `sealed` 덕에 케이스 누락 시 컴파일 에러로 잡힌다.

/// 출석 체크 시도 결과의 sealed 부모.
sealed class AttendanceOutcome {
  const AttendanceOutcome();
}

/// 출석 성공.
class AttendedOutcome extends AttendanceOutcome {
  const AttendedOutcome({required this.lectureName, required this.isLate});

  /// 강의명 (토스트/스낵바 표시용).
  final String lectureName;

  /// 지각으로 처리되었는지 여부.
  final bool isLate;
}

/// 이미 출석 처리되어 있어서 재시도가 무시됨.
class AlreadyAttendedOutcome extends AttendanceOutcome {
  const AlreadyAttendedOutcome({required this.lectureName});

  final String lectureName;
}

/// 서버 거부/네트워크/BLE 통신 실패 등 일반 오류.
class FailedOutcome extends AttendanceOutcome {
  const FailedOutcome({required this.lectureName, required this.reason});

  final String lectureName;

  /// 사용자에게 보여줄 사유 (한국어).
  final String reason;
}

/// 출석 인정 시간대 밖 — 화면에서 "출석 시간이 아니에요" 등 안내.
class OutOfWindowOutcome extends AttendanceOutcome {
  const OutOfWindowOutcome({
    required this.lectureName,
    required this.classNo,
    required this.startEpochMillis,
    required this.endEpochMillis,
    required this.reasonKor,
    required this.nowEpochMillis,
  });

  final String lectureName;

  /// 차시 번호.
  final int classNo;

  /// 출석 인정 시작 epoch millis.
  final int startEpochMillis;

  /// 출석 인정 끝 epoch millis.
  final int endEpochMillis;

  /// 한국어 사유 (예: `"출석 시간이 아니에요"`).
  final String reasonKor;

  /// 평가 시점의 현재 epoch millis (디버그/로그용).
  final int nowEpochMillis;
}

/// 직전 출석 시도 후 쿨다운 중 — 사용자 액션 spam 방지.
class CooldownOutcome extends AttendanceOutcome {
  const CooldownOutcome();
}

/// 출석 처리 가능한 강의가 하나도 없음 (오늘 강의 없음 등).
class NoEligibleLectureOutcome extends AttendanceOutcome {
  const NoEligibleLectureOutcome();
}
