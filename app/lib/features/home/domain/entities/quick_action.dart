import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';
import 'package:sejong_smart_campus/features/menu/domain/lucide_icon_map.dart';

/// 홈 화면 바로가기 1건. `key`는 안정된 라우팅/저장 식별자(메뉴 url 또는
/// `client.*` 가상 키). 저장은 key만 — label/icon은 [resolveQuickActionInfo]
/// 가 registry → 메뉴 트리 leaf → fallback 순으로 동적 resolve.
@immutable
class QuickAction {
  const QuickAction(this.key);
  final String key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is QuickAction && other.key == key);

  @override
  int get hashCode => key.hashCode;
}

/// 바로가기 key의 표시 정보를 결정한다.
///
/// 우선순위:
///  1. [kQuickActionRegistry] — 정적 등록(가상 키 + 자주 쓰는 sjapp url).
///  2. [tree] 의 leaf 중 `url == key`인 항목 → `itemName` + `iconClass→Symbols`.
///     picker에서 추가된 임의 메뉴 항목(예: "학교 시설 대여")이 registry에 없어도
///     트리에서 자동으로 라벨/아이콘을 얻는다.
///  3. 둘 다 없으면 fallback — key 자체 + help_outline. (트리 fetch 실패 등)
QuickActionInfo resolveQuickActionInfo(String key, List<SejongMenuItem> tree) {
  final reg = kQuickActionRegistry[key];
  if (reg != null) return reg;

  final match = _findLeafByUrl(tree, key);
  if (match != null) {
    return QuickActionInfo(
      label: match.itemName,
      icon: lucideToSymbol(match.iconClass, fallback: Symbols.help_outline),
    );
  }

  return QuickActionInfo(label: key, icon: Symbols.help_outline);
}

SejongMenuItem? _findLeafByUrl(List<SejongMenuItem> tree, String url) {
  for (final g in tree) {
    final found = _walk(g, url);
    if (found != null) return found;
  }
  return null;
}

SejongMenuItem? _walk(SejongMenuItem n, String url) {
  if (n.isLeaf && n.url == url) return n;
  for (final c in n.children ?? const <SejongMenuItem>[]) {
    final found = _walk(c, url);
    if (found != null) return found;
  }
  return null;
}

/// 한 항목의 표시 정보. `tabIndex`가 있으면 AppShell.switchTab으로 라우팅,
/// 없으면 url 기반 routeByKey로 push.
@immutable
class QuickActionInfo {
  const QuickActionInfo({
    required this.label,
    required this.icon,
    this.tabIndex,
  });
  final String label;
  final IconData icon;
  final int? tabIndex;
}

/// key → (label, icon, [tabIndex]) 매핑. 신규 항목을 picker에서 추가할 때도
/// 이 테이블을 사용해 표시 정보를 조회한다.
const kQuickActionRegistry = <String, QuickActionInfo>{
  'aca.classSchedule': QuickActionInfo(
    label: '시간표',
    icon: Symbols.calendar_month,
  ),
  'client.libraryFloors': QuickActionInfo(
    label: '열람실',
    icon: Symbols.local_library,
  ),
  'inf.universityLife.schoolCafeteria': QuickActionInfo(
    label: '학식',
    icon: Symbols.restaurant,
  ),
  'client.libseat': QuickActionInfo(label: '시설예약', icon: Symbols.meeting_room),
  // U-Check는 더 이상 nav 탭이 아니라 sub-screen push (routeByKey가 처리).
  'client.uCheckTab': QuickActionInfo(
    label: 'U-Check',
    icon: Symbols.qr_code_scanner,
  ),
  'client.club': QuickActionInfo(label: '동아리', icon: Symbols.groups),
  'client.lab': QuickActionInfo(label: '연구실', icon: Symbols.science),
  'client.petition': QuickActionInfo(label: '청원', icon: Symbols.campaign),
  'client.communityTab': QuickActionInfo(
    label: '커뮤니티',
    icon: Symbols.forum,
    tabIndex: 2,
  ),
  'client.jiphyunCampus': QuickActionInfo(label: '집현캠퍼스', icon: Symbols.school),
  // 추가로 picker에서 노출할 항목들
  'cmm.notificationBox': QuickActionInfo(
    label: '알림함',
    icon: Symbols.notifications,
  ),
  'cmm.faq': QuickActionInfo(label: '도움말', icon: Symbols.help),
  'inf.scheduleManagement': QuickActionInfo(
    label: '학사 캘린더',
    icon: Symbols.event_note,
  ),
  'aca.gradeInquiry': QuickActionInfo(label: '성적', icon: Symbols.grade),
  'aca.scholarshipStatus': QuickActionInfo(label: '장학금', icon: Symbols.school),
  'aca.tuitionDetails': QuickActionInfo(label: '등록금', icon: Symbols.payments),
  'svc.studyRoomStatus': QuickActionInfo(
    label: '스터디룸',
    icon: Symbols.meeting_room,
  ),
};

/// 첫 실행 시 기본 바로가기 키 (현재 home_screen에 하드코딩 됐던 10개와 동일).
const kDefaultQuickActionKeys = <String>[
  'aca.classSchedule',
  'client.libraryFloors',
  'inf.universityLife.schoolCafeteria',
  'client.libseat',
  'client.uCheckTab',
  'client.club',
  'client.lab',
  'client.petition',
  'client.communityTab',
  'client.jiphyunCampus',
];

/// 그리드 최대 행 / 최대 항목 수.
const int kQuickActionsMaxCols = 5;
const int kQuickActionsMaxRows = 3;
const int kQuickActionsMaxCount = kQuickActionsMaxCols * kQuickActionsMaxRows;
