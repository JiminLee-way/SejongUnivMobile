import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sejong_smart_campus/main.dart';

void main() {
  testWidgets('App boots inside ProviderScope', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SejongApp()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
