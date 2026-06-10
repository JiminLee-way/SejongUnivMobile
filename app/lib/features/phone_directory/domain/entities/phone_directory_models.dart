/// 교내 전화번호(교직원 + 학과사무실) 도메인 모델.
///
/// 두 출처를 한 화면에서 합친다:
///  - **교직원**: sjapp `/api/publicapi/phone-number` 실시간 검색 → [StaffContact].
///  - **학과사무실**: Supabase `dept_offices` 공개 read-only → [DeptOffice].
///    (실시간 API가 없어 서버 구동 콘텐츠로 둔다 — 행만 고치면 APK 재빌드 없이 반영.)
library;

/// 검색 유형. sjapp `searchType` 쿼리값과 1:1.
/// 전체(`all`)는 파라미터를 생략 → 서버가 이름·학과 등 전체 필드를 본다.
enum PhoneSearchType {
  all('전체', null),
  name('이름', 'name'),
  major('학과', 'major'),
  phone('전화번호', 'phone');

  const PhoneSearchType(this.label, this.apiValue);

  /// 칩에 표시할 한글 라벨.
  final String label;

  /// sjapp `searchType` 쿼리값. 전체는 null(파라미터 생략).
  final String? apiValue;
}

/// 교직원 1명. sjapp phone-number API의 `content[]` 한 행.
class StaffContact {
  const StaffContact({
    required this.name,
    required this.position,
    required this.department,
    required this.phone,
  });

  final String name;
  final String position; // 직위 (예: 부교수)
  final String department; // 소속 학과
  final String phone; // 표시형 02-XXXX-XXXX

  factory StaffContact.fromJson(Map<String, dynamic> json) {
    String s(Object? v) => (v ?? '').toString().trim();
    return StaffContact(
      name: s(json['name']),
      position: s(json['position']),
      department: s(json['department']),
      phone: s(json['phone']),
    );
  }
}

/// 교직원 검색 결과 한 페이지 + 페이지 메타.
class StaffSearchResult {
  const StaffSearchResult({
    required this.contacts,
    required this.total,
    required this.hasMore,
  });

  final List<StaffContact> contacts;

  /// 전체 매칭 수(totalElements). 우리가 한 페이지(size=100)만 받아도 총량 안내용.
  final int total;

  /// 받은 페이지 뒤에 더 있는지(`last == false`).
  final bool hasMore;

  static const StaffSearchResult empty = StaffSearchResult(
    contacts: <StaffContact>[],
    total: 0,
    hasMore: false,
  );
}

/// 학과사무실 1개. Supabase `dept_offices` 한 행.
class DeptOffice {
  const DeptOffice({
    this.college,
    required this.department,
    this.subMajor,
    required this.phone,
    required this.isSpecial,
  });

  /// 단과대학. 특별사무실(법학부/교양학부 등)은 null.
  final String? college;
  final String department; // 학과/학부/사무실명
  final String? subMajor; // 전공 (없으면 null)
  final String phone; // 표시형 02-XXXX-XXXX
  final bool isSpecial; // 단과대학 외 — '특별 사무실' 그룹으로 분리 표시

  factory DeptOffice.fromJson(Map<String, dynamic> json) {
    String? nullable(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return DeptOffice(
      college: nullable(json['college']),
      department: (json['department'] ?? '').toString().trim(),
      subMajor: nullable(json['sub_major']),
      phone: (json['phone'] ?? '').toString().trim(),
      isSpecial: json['is_special'] == true,
    );
  }
}
