import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/features/menu/data/datasources/menu_order_storage.dart';
import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';
import 'package:sejong_smart_campus/features/menu/presentation/providers/custom_menu_tree.dart';
import 'package:sejong_smart_campus/features/menu/presentation/providers/menu_dispatcher.dart';

/// STUDENT_MAIN — 전체 서비스 트리 (서버 원본 순서).
final studentMenuTreeProvider = FutureProvider<List<SejongMenuItem>>((
  ref,
) async {
  final remote = await ref.watch(menuRemoteProvider.future);
  return remote.fetchTree('STUDENT_MAIN');
});

/// 우리 앱 구조로 transform된 트리 — 대학소개·스마트서비스 그룹 제거 +
/// 학술정보원 가상 그룹 합성. 사용자 순서가 아직 적용되지 않은 상태이므로
/// 메뉴 순서 편집기는 이 트리를 base seed로 사용해야 한다 (편집기가 raw를
/// 봤다면 학술정보원 그룹이 없고 대학소개/스마트서비스가 살아있어 불일치).
final customizedStudentMenuTreeProvider =
    Provider<AsyncValue<List<SejongMenuItem>>>((ref) {
      final treeAsync = ref.watch(studentMenuTreeProvider);
      return treeAsync.whenData(customizeMenuTree);
    });

/// 사용자가 직접 편집한 그룹·leaf 순서. AsyncNotifier로 file 로드/저장 일원화.
class MenuOrderNotifier extends AsyncNotifier<MenuOrder> {
  final _storage = MenuOrderStorage();

  @override
  Future<MenuOrder> build() => _storage.load();

  Future<void> save(MenuOrder order) async {
    // 디스크 저장을 먼저 성공시킨 뒤에만 state 반영. 실패 시 예외가 전파되어
    // (편집기가 catch) state는 그대로 유지된다.
    await _storage.save(order);
    state = AsyncData(order);
  }

  Future<void> reset() async {
    // save()와 동일 — 디스크 저장 성공 후에만 state 반영. 실패 시 호출부로 전파.
    await _storage.save(MenuOrder.empty());
    state = AsyncData(MenuOrder.empty());
  }
}

final menuOrderProvider = AsyncNotifierProvider<MenuOrderNotifier, MenuOrder>(
  MenuOrderNotifier.new,
);

/// 사용자 순서가 적용된 메뉴 트리. ServicesScreen이 watch.
///
/// 순서: sjapp 원본 → [customizeMenuTree] (우리 구조로 transform) →
/// [applyMenuOrder] (사용자 편집 순서). transform이 먼저라 사용자 순서는
/// 학술정보원 같은 가상 그룹도 포함한 우리 구조 위에서 동작.
/// 신규 그룹/leaf는 사용자 순서 뒤에 append (잃지 않음).
final sortedStudentMenuTreeProvider =
    Provider<AsyncValue<List<SejongMenuItem>>>((ref) {
      final treeAsync = ref.watch(customizedStudentMenuTreeProvider);
      final orderAsync = ref.watch(menuOrderProvider);
      return treeAsync.whenData((tree) {
        final order = orderAsync.value ?? MenuOrder.empty();
        return applyMenuOrder(tree, order);
      });
    });

/// 메뉴 트리에 사용자 순서 적용. group + 각 group children 모두.
List<SejongMenuItem> applyMenuOrder(
  List<SejongMenuItem> tree,
  MenuOrder order,
) {
  final byId = {for (final g in tree) g.itemId: g};
  final used = <String>{};
  final out = <SejongMenuItem>[];
  for (final id in order.groupOrder) {
    final g = byId[id];
    if (g != null) {
      out.add(_applyLeafOrder(g, order.leafOrder[id]));
      used.add(id);
    }
  }
  for (final g in tree) {
    if (!used.contains(g.itemId)) {
      out.add(_applyLeafOrder(g, order.leafOrder[g.itemId]));
    }
  }
  return out;
}

SejongMenuItem _applyLeafOrder(SejongMenuItem group, List<String>? order) {
  final children = group.children;
  if (children == null || children.isEmpty || order == null || order.isEmpty) {
    return group;
  }
  final byId = {for (final c in children) c.itemId: c};
  final used = <String>{};
  final out = <SejongMenuItem>[];
  for (final id in order) {
    final c = byId[id];
    if (c != null) {
      out.add(c);
      used.add(id);
    }
  }
  for (final c in children) {
    if (!used.contains(c.itemId)) out.add(c);
  }
  return group.copyWith(children: out);
}
