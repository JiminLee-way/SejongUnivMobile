import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';

/// 우리 앱의 "전체 서비스" 메뉴 구조를 sjapp 트리 위에 덮어쓰는 transform.
///
/// sjapp이 내려보내는 STUDENT_MAIN 트리를 그대로 미러링하지 않고, UX
/// 관점에서 정리한 우리 구조를 만든다. 핵심 변경:
///  - **대학소개 그룹 제거** — "교내 전화번호"는 서버 leaf(웹 handoff) 대신
///    네이티브 [_phoneDirectoryItemId] 가상 leaf로 [_universityLifeId]
///    그룹(대학생활) 마지막에 주입(PhoneDirectoryScreen으로 직접 라우팅).
///  - **스마트서비스 그룹 제거** — 안의 학술 인프라 4개(스터디룸 현황/예약
///    조회, 열람실 좌석예약, 도서 연체료 결제)를 새 가상 그룹 "학술정보원"
///    으로 묶어 노출. 그 외 17개 항목은 노출 트리에서 제외.
///
/// 서버 fetch는 그대로 사용 — itemId는 sjapp 원본이라 즐겨찾기·메뉴 순서
/// 편집 storage와 호환된다. 학술정보원 그룹만 클라이언트에서 합성한 가상
/// itemId를 갖는다 ([infoCenterGroupId]).
const String _universityIntroId = '02a95164';
const String _universityLifeId = 'student-university-life';
const String _smartServiceId = 'student-smart-service';

/// 강의실 예약 클라이언트 가상 항목 itemId.
const String sjptClassroomItemId = 'client-sjpt-classroom';

/// 교내 전화번호(PhoneDirectoryScreen) 클라이언트 가상 항목 itemId.
const String _phoneDirectoryItemId = 'client-phone-directory';

const String _studyRoomStatusId = 'student-study-room-status';
const String _studyRoomReservationId = 'student-study-room-reservation';
const String _seatReservationId = 'student-seat-reservation';
// 도서 연체료 결제 — sjapp이 발급한 itemId. 가공된 형태지만 원본 유지.
const String _libraryOverdueId = 'STUDENT_MAIN_206x9x';

/// 열람실(LibraryListScreen) 클라이언트 가상 항목 itemId.
const String _libraryFloorsItemId = 'client-library-floors';

/// 학술정보원 가상 그룹 itemId. 사용자 메뉴 순서 storage에서도 이 id로 추적.
const String infoCenterGroupId = 'client-info-center';

/// 커뮤니티 가상 그룹 itemId.
const String communityGroupId = 'client-community-group';
const String _communityTabItemId = 'client-community-tab';
const String _clubItemId = 'client-club';
const String _labItemId = 'client-lab';
const String _petitionItemId = 'client-petition';

/// 집현캠퍼스 클라이언트 가상 항목 itemId.
const String _jiphyunCampusItemId = 'client-jiphyun-campus';

/// 학점계산기 클라이언트 가상 항목 itemId.
const String _gradeCalculatorItemId = 'client-grade-calculator';

/// "지원" 단일 leaf 가상 항목 itemId (sjapp 트리의 "지원 서비스" GROUP을 대체).
const String _supportItemId = 'client-support';

/// "설정" 단일 leaf 가상 항목 itemId (sjapp `cmm.setting` + 클라이언트 자체
/// 앱 설정 카드 통합).
const String _settingsItemId = 'client-settings';

/// 학술정보원 그룹이 묶을 leaf itemId 순서. 열람실 가상 항목이 맨 위.
const List<String> _infoCenterChildOrder = [
  _libraryFloorsItemId,
  _studyRoomStatusId,
  _studyRoomReservationId,
  _seatReservationId,
  _libraryOverdueId,
];

/// 마지막 호출에 대한 identity-기반 memo. 같은 raw list 인스턴스가 다시 들어
/// 오면(전형적인 FutureProvider 재방출 케이스) 같은 transform 결과 인스턴스를
/// 반환해 downstream provider cascade를 끊는다. Provider가 동일성으로 변경
/// 감지하므로 동일 List를 돌려주면 sorted/view 트리도 rebuild 안 함.
List<SejongMenuItem>? _memoRawRef;
List<SejongMenuItem>? _memoOut;

/// sjapp 원본 트리를 우리 노출 구조로 변환.
///
/// 트리는 mutate하지 않고 새 list를 반환. menuOrder 적용 전에 호출하면
/// 사용자 순서가 이 결과 위에 자연스럽게 덮인다.
List<SejongMenuItem> customizeMenuTree(List<SejongMenuItem> raw) {
  if (identical(_memoRawRef, raw) && _memoOut != null) {
    return _memoOut!;
  }
  // 1) 스마트서비스 안에서 학술정보원으로 옮길 4개를 빼낸다.
  final infoCenterChildren = <SejongMenuItem>[];

  for (final g in raw) {
    if (g.itemId == _smartServiceId) {
      for (final c in g.children ?? const <SejongMenuItem>[]) {
        if (_infoCenterChildOrder.contains(c.itemId)) {
          infoCenterChildren.add(c);
        }
      }
    }
  }

  // 열람실(가상) — sjapp 트리에 없으므로 클라이언트에서 주입.
  infoCenterChildren.add(_buildLibraryFloorsItem());

  // _infoCenterChildOrder 순서대로 정렬 — sjapp displayOrder와 무관하게 우리
  // 의도된 순서로 (열람실 → 스터디룸 현황 → 예약 조회 → 시설예약 → 연체료).
  infoCenterChildren.sort(
    (a, b) =>
        _infoCenterChildOrder.indexOf(a.itemId) -
        _infoCenterChildOrder.indexOf(b.itemId),
  );

  // 3) 본 transform.
  final out = <SejongMenuItem>[];
  var infoCenterInserted = false;
  var communityInserted = false;
  for (final g in raw) {
    // 대학소개 그룹 자체 제거.
    if (g.itemId == _universityIntroId) continue;
    // 스마트서비스 그룹 자체 제거.
    if (g.itemId == _smartServiceId) continue;
    // "지원 서비스" 그룹 자체 제거 — 안의 알림함/설정/도움말은 별도로 노출
    // (알림함은 Topbar에 있으니 삭제, 도움말+설정은 단일 leaf로 재구성).
    if (_isSupportGroup(g)) continue;
    // sjapp 트리가 `cmm.setting` 같은 항목을 top-level PAGE 로도 내려보내는
    // 경우가 있어 그대로 두면 우리가 합성한 단일 leaf 와 중복 노출된다
    // (`_stripHiddenLeaves` 는 그룹 children 에만 적용되므로 top-level 은
    // 빠져나간다). 여기서 명시적으로 동일 url 셋을 한 번 더 거른다.
    if (g.itemType != 'GROUP' &&
        (_hiddenLeafUrls.contains(g.url) || _isHiddenLeafByName(g))) {
      continue;
    }

    if (g.itemId == _universityLifeId) {
      // 대학생활에 강의실 예약(sjpt 네이티브) + 교내 전화번호(네이티브) append.
      final children = [
        ...(g.children ?? const <SejongMenuItem>[]),
        _buildSjptClassroomItem(),
        _buildPhoneDirectoryItem(),
      ];
      out.add(g.copyWith(children: _stripHiddenLeaves(children)));
    } else if (_isSmartAcademicsGroup(g)) {
      // 스마트학사 그룹에 학점계산기 + 집현캠퍼스 가상 항목 append.
      final children = [
        ...(g.children ?? const <SejongMenuItem>[]),
        _buildGradeCalculatorItem(),
        _buildJiphyunCampusItem(),
      ];
      out.add(g.copyWith(children: _stripHiddenLeaves(children)));
    } else {
      out.add(
        g.copyWith(
          children: _stripHiddenLeaves(g.children ?? const <SejongMenuItem>[]),
        ),
      );
    }

    // 학술정보원 그룹은 대학생활 바로 뒤에 배치. (대학생활이 없으면 fallback
    // 으로 끝에 append.)
    if (!infoCenterInserted &&
        g.itemId == _universityLifeId &&
        infoCenterChildren.isNotEmpty) {
      out.add(_buildInfoCenterGroup(infoCenterChildren));
      infoCenterInserted = true;
      // 커뮤니티 그룹은 학술정보원 바로 뒤.
      out.add(_buildCommunityGroup());
      communityInserted = true;
    }
  }

  if (!infoCenterInserted && infoCenterChildren.isNotEmpty) {
    out.add(_buildInfoCenterGroup(infoCenterChildren));
  }
  if (!communityInserted) {
    out.add(_buildCommunityGroup());
  }

  // 마지막에 단일 leaf "지원", "설정" 추가 (그룹 X). routeByKey가
  // client.support / client.settings 를 각각 SupportScreen / SettingsScreen
  // 으로 push.
  out.add(_buildSupportLeaf());
  out.add(_buildSettingsLeaf());

  _memoRawRef = raw;
  _memoOut = out.map(_applyNameOverride).toList();
  return _memoOut!;
}

/// 메뉴 트리 어느 위치든 등장할 수 있는 "숨김 대상" leaf url 목록.
/// 알림함은 Topbar에서, 도움말/설정은 통합 단일 leaf에서 노출하므로 트리에서
/// 중복 노출되지 않도록 그룹 children에서 제거.
const _hiddenLeafUrls = <String>{
  'cmm.notificationBox',
  'cmm.faq',
  'cmm.setting',
};

/// 표시명에 이 키워드가 포함된 leaf는 노출에서 제외. sjapp 서버가 내려주는
/// 항목이라 url/itemId가 안정적이지 않아 표시명으로 거른다.
/// (사용자 요청: "대학생활 증명서 신청" · "세종신문" 메뉴 제거.)
const _hiddenLeafNameKeywords = <String>['증명서', '세종신문'];

bool _isHiddenLeafByName(SejongMenuItem item) {
  if (item.itemType == 'GROUP') return false;
  return _hiddenLeafNameKeywords.any((k) => item.itemName.contains(k));
}

List<SejongMenuItem> _stripHiddenLeaves(List<SejongMenuItem> items) {
  return items
      .where((c) => !_hiddenLeafUrls.contains(c.url) && !_isHiddenLeafByName(c))
      .toList();
}

/// "지원 서비스" 그룹은 sjapp에서 itemId가 안정적이지 않을 수 있어 children에
/// `cmm.faq`(자주 묻는 질문)가 있는 GROUP 으로 식별.
bool _isSupportGroup(SejongMenuItem g) {
  if (g.itemType != 'GROUP') return false;
  return (g.children ?? const <SejongMenuItem>[]).any(
    (c) => c.url == 'cmm.faq',
  );
}

/// 서버 메뉴명 → 우리 화면 타이틀 통일 오버라이드.
/// URL 키 또는 itemId로 매칭.
const _urlNameOverrides = <String, String>{
  'inf.scheduleManagement': '학사 캘린더',
  'cmm.faq': '도움말',
  'cmm.notificationBox': '알림함',
};

const _idNameOverrides = <String, String>{_seatReservationId: '시설 예약'};

SejongMenuItem _applyNameOverride(SejongMenuItem item) {
  final newName = _urlNameOverrides[item.url] ?? _idNameOverrides[item.itemId];
  final children = item.children?.map(_applyNameOverride).toList();
  if (newName != null || children != null) {
    return item.copyWith(
      itemName: newName ?? item.itemName,
      children: children,
    );
  }
  return item;
}

/// 강의실 예약 가상 leaf.
/// 서버 트리에 없으므로 클라이언트에서 주입하고 내부 라우터가 처리한다.
SejongMenuItem _buildSjptClassroomItem() {
  return SejongMenuItem(
    itemId: sjptClassroomItemId,
    menuId: 'STUDENT_MAIN',
    itemName: '학교 시설 대여',
    itemType: 'PAGE',
    parentItemId: _universityLifeId,
    itemLevel: 1,
    displayOrder: 998,
    url: 'client.sjpt',
    webUrl: '',
    target: '_self',
    iconClass: 'DoorOpen',
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: ['STUDENT'],
    itemKey: 'client.sjpt',
    children: null,
  );
}

/// 교내 전화번호 가상 leaf — PhoneDirectoryScreen으로 직접 라우팅.
/// 서버 트리의 교내 전화번호(웹 handoff)를 대체. url='client.phoneDirectory' +
/// callType='NONE' → routeByKey가 잡아 slideRoute로 push(dispatcher 우회).
SejongMenuItem _buildPhoneDirectoryItem() {
  return SejongMenuItem(
    itemId: _phoneDirectoryItemId,
    menuId: 'STUDENT_MAIN',
    itemName: '교내 전화번호',
    itemType: 'PAGE',
    parentItemId: _universityLifeId,
    itemLevel: 1,
    displayOrder: 997,
    url: 'client.phoneDirectory',
    webUrl: '',
    target: '_self',
    iconClass: 'Phone', // lucide_icon_map: 'Phone' -> Symbols.phone
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: const ['STUDENT'],
    itemKey: 'client.phoneDirectory',
    children: null,
  );
}

SejongMenuItem _buildInfoCenterGroup(List<SejongMenuItem> children) {
  return SejongMenuItem(
    itemId: infoCenterGroupId,
    menuId: 'STUDENT_MAIN',
    itemName: '학술정보원',
    itemType: 'GROUP',
    parentItemId: null,
    itemLevel: 0,
    // displayOrder는 우리 transform에서 직접 배치하므로 임의값.
    displayOrder: 0,
    url: '',
    webUrl: '',
    target: '_self',
    iconClass: 'Library',
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: const ['STUDENT'],
    itemKey: 'client.infoCenter',
    children: children,
  );
}

/// 스마트학사 그룹 판별 — sjapp itemId가 안정적이지 않을 수 있어 자식 중
/// `aca.classSchedule`(수업시간표) URL을 가진 항목 존재 여부로 식별.
bool _isSmartAcademicsGroup(SejongMenuItem g) {
  if (g.itemType != 'GROUP') return false;
  return (g.children ?? const <SejongMenuItem>[]).any(
    (c) => c.url == 'aca.classSchedule',
  );
}

/// 열람실 가상 leaf — LibraryListScreen으로 직접 라우팅.
SejongMenuItem _buildLibraryFloorsItem() {
  return SejongMenuItem(
    itemId: _libraryFloorsItemId,
    menuId: 'STUDENT_MAIN',
    itemName: '열람실',
    itemType: 'PAGE',
    parentItemId: infoCenterGroupId,
    itemLevel: 1,
    displayOrder: 1,
    url: 'client.libraryFloors',
    webUrl: '',
    target: '_self',
    iconClass: 'LocalLibrary',
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: const ['STUDENT'],
    itemKey: 'client.libraryFloors',
    children: null,
  );
}

/// 학점계산기 가상 leaf — 성적 조회와 분리된 로컬 예측 화면으로 라우팅.
SejongMenuItem _buildGradeCalculatorItem() {
  return SejongMenuItem(
    itemId: _gradeCalculatorItemId,
    menuId: 'STUDENT_MAIN',
    itemName: '학점계산기',
    itemType: 'PAGE',
    parentItemId: null,
    itemLevel: 1,
    displayOrder: 998,
    url: 'client.gradeCalculator',
    webUrl: '',
    target: '_self',
    iconClass: 'Calculator',
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: const ['STUDENT'],
    itemKey: 'client.gradeCalculator',
    children: null,
  );
}

/// 집현캠퍼스 가상 leaf — 스마트학사 그룹에 주입.
SejongMenuItem _buildJiphyunCampusItem() {
  return SejongMenuItem(
    itemId: _jiphyunCampusItemId,
    menuId: 'STUDENT_MAIN',
    itemName: '집현캠퍼스',
    itemType: 'PAGE',
    parentItemId: null,
    itemLevel: 1,
    displayOrder: 999,
    url: 'client.jiphyunCampus',
    webUrl: 'https://ecampus.sejong.ac.kr/',
    target: '_self',
    iconClass: 'School',
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: const ['STUDENT'],
    itemKey: 'client.jiphyunCampus',
    children: null,
  );
}

/// 커뮤니티 가상 그룹 — 커뮤니티/동아리/연구실/청원 4개 leaf.
SejongMenuItem _buildCommunityGroup() {
  return SejongMenuItem(
    itemId: communityGroupId,
    menuId: 'STUDENT_MAIN',
    itemName: '커뮤니티',
    itemType: 'GROUP',
    parentItemId: null,
    itemLevel: 0,
    displayOrder: 0,
    url: '',
    webUrl: '',
    target: '_self',
    iconClass: 'Forum',
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: const ['STUDENT'],
    itemKey: 'client.community',
    children: [
      _buildCommunityLeaf(
        id: _communityTabItemId,
        name: '커뮤니티',
        url: 'client.communityTab',
        icon: 'Forum',
      ),
      _buildCommunityLeaf(
        id: _clubItemId,
        name: '동아리',
        url: 'client.club',
        icon: 'Groups',
      ),
      _buildCommunityLeaf(
        id: _labItemId,
        name: '연구실',
        url: 'client.lab',
        icon: 'Science',
      ),
      _buildCommunityLeaf(
        id: _petitionItemId,
        name: '청원',
        url: 'client.petition',
        icon: 'Campaign',
      ),
    ],
  );
}

/// 지원 단일 leaf — SupportScreen으로 직접 라우팅.
SejongMenuItem _buildSupportLeaf() {
  return SejongMenuItem(
    itemId: _supportItemId,
    menuId: 'STUDENT_MAIN',
    itemName: '지원',
    itemType: 'PAGE',
    parentItemId: null,
    itemLevel: 0,
    displayOrder: 9000,
    url: 'client.support',
    webUrl: '',
    target: '_self',
    iconClass: 'Headset',
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: const ['STUDENT'],
    itemKey: 'client.support',
    children: null,
  );
}

/// 설정 단일 leaf — 통합 SettingsScreen으로 직접 라우팅.
SejongMenuItem _buildSettingsLeaf() {
  return SejongMenuItem(
    itemId: _settingsItemId,
    menuId: 'STUDENT_MAIN',
    itemName: '설정',
    itemType: 'PAGE',
    parentItemId: null,
    itemLevel: 0,
    displayOrder: 9001,
    url: 'client.settings',
    webUrl: '',
    target: '_self',
    iconClass: 'Settings',
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: const ['STUDENT'],
    itemKey: 'client.settings',
    children: null,
  );
}

SejongMenuItem _buildCommunityLeaf({
  required String id,
  required String name,
  required String url,
  required String icon,
}) {
  return SejongMenuItem(
    itemId: id,
    menuId: 'STUDENT_MAIN',
    itemName: name,
    itemType: 'PAGE',
    parentItemId: communityGroupId,
    itemLevel: 1,
    displayOrder: 1,
    url: url,
    webUrl: '',
    target: '_self',
    iconClass: icon,
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: const ['STUDENT'],
    itemKey: url,
    children: null,
  );
}
