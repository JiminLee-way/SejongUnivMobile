import 'package:flutter_test/flutter_test.dart';

import 'package:sejong_smart_campus/features/menu/domain/entities/sejong_menu_item.dart';
import 'package:sejong_smart_campus/features/menu/presentation/providers/custom_menu_tree.dart';

void main() {
  test('smart academics receives grade calculator leaf', () {
    final tree = customizeMenuTree([
      _group(
        id: 'smart-academics',
        name: '스마트학사',
        children: [_leaf(name: '수업시간표', url: 'aca.classSchedule')],
      ),
    ]);

    final smartAcademics = tree.firstWhere(
      (item) =>
          item.children?.any((child) => child.url == 'aca.classSchedule') ==
          true,
    );
    final calculator = smartAcademics.children!.firstWhere(
      (item) => item.url == 'client.gradeCalculator',
    );

    expect(calculator.itemId, 'client-grade-calculator');
    expect(calculator.itemName, '학점계산기');
    expect(calculator.iconClass, 'Calculator');
  });
}

SejongMenuItem _group({
  required String id,
  required String name,
  required List<SejongMenuItem> children,
}) {
  return SejongMenuItem(
    itemId: id,
    menuId: 'STUDENT_MAIN',
    itemName: name,
    itemType: 'GROUP',
    parentItemId: null,
    itemLevel: 0,
    displayOrder: 1,
    url: '',
    webUrl: '',
    target: '_self',
    iconClass: 'School',
    callType: 'NONE',
    callParams: null,
    appScheme: null,
    active: true,
    visible: true,
    allowedRoles: const ['STUDENT'],
    itemKey: id,
    children: children,
  );
}

SejongMenuItem _leaf({required String name, required String url}) {
  return SejongMenuItem(
    itemId: url,
    menuId: 'STUDENT_MAIN',
    itemName: name,
    itemType: 'PAGE',
    parentItemId: 'smart-academics',
    itemLevel: 1,
    displayOrder: 1,
    url: url,
    webUrl: '',
    target: '_self',
    iconClass: 'Calendar',
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
