/// 현재 로그인된 세종대 사용자.
///
/// `/api/auth/login` 또는 `/api/auth/me` 응답에서 만들어진다. JWT 클레임에도
/// 같은 필드들이 있지만, 클라이언트는 디코딩하지 않고 **공식 응답 body만**
/// 신뢰한다 (서버가 추가 필드를 줄 수 있고, payload 파싱은 fragility 원인).
class SejongUser {
  const SejongUser({
    required this.userId,
    required this.username,
    required this.email,
    required this.roles,
    required this.roleName,
    required this.departmentName,
    required this.organizationClassName,
    required this.birthDate,
    required this.studentYear,
    required this.cardNo,
    required this.cardNoIos,
    required this.cmsUserId,
    required this.roleCd,
    this.statusName,
  });

  /// 학번 (= 사용자 식별자).
  final String userId;

  /// 표시 이름.
  final String username;

  final String email;

  /// 권한 라벨 — ["STUDENT"] 등.
  final List<String> roles;

  /// "재학생" 등.
  final String roleName;

  /// "사이버국방학과" 등.
  final String departmentName;

  /// "학부", "대학원" 등.
  final String organizationClassName;

  /// "20050814" (YYYYMMDD).
  final String birthDate;

  /// 학년 (1~4).
  final int studentYear;

  /// Android 학생증 카드 번호 (모바일 학생증 QR/바코드 표시용).
  final String cardNo;

  /// iOS Wallet용 카드 번호.
  final String cardNoIos;

  /// Lotecs CMS 사용자 ID (사진 등 secure 자원 호출 시 권한 매칭에 사용).
  final String cmsUserId;

  /// 내부 역할 코드 ("ST000001" 등).
  final String roleCd;

  /// "재학" / "휴학" 등 — `/auth/me`에서만 옴.
  final String? statusName;

  /// 표시용 — "사이버국방학과 · 2학년".
  String get departmentLine => '$departmentName · $studentYear학년';

  /// 표시용 — "재학" (없으면 roleName 사용).
  String get statusBadge => statusName ?? roleName;
}
