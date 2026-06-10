import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 사용자가 직접 정한 그룹·leaf 순서를 로컬 파일로 보존.
///
/// sjapp 백엔드에 같은 spec이 없어서 디바이스 로컬에만 둠. 새 메뉴가 트리에
/// 추가되면 [applyOrder]에서 자동으로 뒤로 붙는다.
class MenuOrderStorage {
  static const _filename = 'menu_order.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }

  Future<MenuOrder> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return MenuOrder.empty();
      final txt = await f.readAsString();
      if (txt.isEmpty) return MenuOrder.empty();
      final j = jsonDecode(txt) as Map<String, dynamic>;
      final groups = (j['groupOrder'] as List?)?.cast<String>() ?? const [];
      final leaves = <String, List<String>>{};
      final raw = j['leafOrder'];
      if (raw is Map) {
        for (final e in raw.entries) {
          final v = e.value;
          if (v is List) leaves[e.key as String] = v.cast<String>();
        }
      }
      return MenuOrder(groupOrder: groups, leafOrder: leaves);
    } catch (_) {
      return MenuOrder.empty();
    }
  }

  Future<void> save(MenuOrder order) async {
    // 예외를 삼키지 않고 호출부로 전파 — 디스크 쓰기 실패를 사용자에게 알리고,
    // 메모리 state만 바뀌어 "저장했는데 다음에 보면 원복"되는 착시를 막기 위함.
    final f = await _file();
    await f.writeAsString(
      jsonEncode({
        'groupOrder': order.groupOrder,
        'leafOrder': order.leafOrder,
      }),
    );
  }
}

class MenuOrder {
  const MenuOrder({required this.groupOrder, required this.leafOrder});
  factory MenuOrder.empty() => const MenuOrder(
    groupOrder: <String>[],
    leafOrder: <String, List<String>>{},
  );

  /// 그룹 itemId 순서.
  final List<String> groupOrder;

  /// 그룹 itemId → leaf itemId 순서.
  final Map<String, List<String>> leafOrder;

  MenuOrder copyWith({
    List<String>? groupOrder,
    Map<String, List<String>>? leafOrder,
  }) {
    return MenuOrder(
      groupOrder: groupOrder ?? this.groupOrder,
      leafOrder: leafOrder ?? this.leafOrder,
    );
  }
}
