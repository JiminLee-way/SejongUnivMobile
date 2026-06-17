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
  'client.sjpt': QuickActionInfo(label: '학교시설대여', icon: Symbols.door_open),
  'client.club': QuickActionInfo(label: '동아리', icon: Symbols.groups),
  'client.lab': QuickActionInfo(label: '연구실', icon: Symbols.science),
  'client.petition': QuickActionInfo(label: '청원', icon: Symbols.campaign),
  'client.communityTab': QuickActionInfo(
    label: '커뮤니티',
    icon: Symbols.forum,
    tabIndex: 2,
  ),
  'client.studentIdTab': QuickActionInfo(
    label: '학생증',
    icon: Symbols.badge,
    tabIndex: 1,
  ),
  'client.jiphyunCampus': QuickActionInfo(label: '집현캠퍼스', icon: Symbols.school),
  // 추가로 picker에서 노출할 항목들
  'cmm.notificationBox': QuickActionInfo(
    label: '알림함',
    icon: Symbols.notifications,
  ),
  'cmm.faq': QuickActionInfo(label: '도움말', icon: Symbols.help),
  'inf.scheduleManagement': QuickActionInfo(
    label: '학사캘린더',
    icon: Symbols.event_note,
  ),
  'inf.notice.general': QuickActionInfo(label: '일반공지', icon: Symbols.article),
  'inf.notice.academic': QuickActionInfo(label: '학사공지', icon: Symbols.school),
  'aca.gradeInquiry': QuickActionInfo(label: '성적', icon: Symbols.grade),
  'aca.scholarshipStatus': QuickActionInfo(label: '장학금', icon: Symbols.school),
  'aca.tuitionDetails': QuickActionInfo(label: '등록금', icon: Symbols.payments),
  'svc.studyRoomStatus': QuickActionInfo(
    label: '스터디룸',
    icon: Symbols.meeting_room,
  ),
};

/// 첫 실행 시 기본 바로가기 키.
const kDefaultQuickActionKeys = <String>[
  'inf.scheduleManagement',
  'aca.classSchedule',
  'client.libraryFloors',
  'client.libseat',
  'client.uCheckTab',
  'client.sjpt',
  'client.jiphyunCampus',
  'client.studentIdTab',
  'inf.notice.general',
  'inf.universityLife.schoolCafeteria',
];

/// 1.0.10 기본 바로가기. 저장값이 이 순서 그대로면 사용자가 커스텀하지 않은
/// 상태로 보고 현재 기본값으로 1회 승격한다.
const kPreviousDefaultQuickActionKeys = <String>[
  'inf.scheduleManagement',
  'aca.classSchedule',
  'client.libraryFloors',
  'client.libseat',
  'inf.universityLife.schoolCafeteria',
  'client.sjpt',
  'client.jiphyunCampus',
  'client.studentIdTab',
  'inf.notice.general',
  'inf.notice.academic',
];

/// 1.0.8까지의 기본 바로가기. 저장값이 이 순서 그대로면 사용자가 커스텀하지
/// 않은 상태로 보고 새 기본값으로 1회 승격한다.
const kLegacyDefaultQuickActionKeys = <String>[
  'aca.classSchedule',
  'client.libraryFloors',
  'inf.universityLife.schoolCafeteria',
  'client.libseat',
  'client.uCheckTab',
  'client.sjpt',
  'client.lab',
  'client.petition',
  'client.communityTab',
  'client.jiphyunCampus',
];

const _legacyQuickActionKeyReplacements = <String, String>{
  'client.club': 'client.sjpt',
};

const _defaultQuickActionMigrationSources = <List<String>>[
  kLegacyDefaultQuickActionKeys,
  kPreviousDefaultQuickActionKeys,
];

/// 저장된 예전 바로가기 키를 현재 기본 구성으로 보정한다.
///
/// 기존 설치에서 `client.club`이 로컬 저장소에 남아 있어도 홈 버튼은 새
/// "학교시설대여" 동작으로 바뀌어야 하므로, 읽기 시점에 1회 치환한다.
List<String> normalizeQuickActionKeys(Iterable<String> keys) {
  final out = <String>[];
  for (final key in keys) {
    final normalized = _legacyQuickActionKeyReplacements[key] ?? key;
    if (out.contains(normalized)) continue;
    out.add(normalized);
    if (out.length >= kQuickActionsMaxCount) break;
  }
  return out;
}

/// 저장소에서 읽은 바로가기만 대상으로 하는 버전 마이그레이션.
///
/// 사용자가 직접 바꾼 순서는 건드리지 않고, 기존 기본값과 같은 경우만 새
/// 기본값으로 교체한다.
List<String> migrateSavedQuickActionKeys(Iterable<String> keys) {
  final normalized = normalizeQuickActionKeys(keys);
  for (final previousDefault in _defaultQuickActionMigrationSources) {
    if (_sameKeys(normalized, previousDefault)) {
      return List<String>.from(kDefaultQuickActionKeys);
    }
  }
  return normalized;
}

bool _sameKeys(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 그리드 최대 행 / 최대 항목 수.
const int kQuickActionsMaxCols = 5;
const int kQuickActionsMaxRows = 3;
const int kQuickActionsMaxCount = kQuickActionsMaxCols * kQuickActionsMaxRows;
