import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keneya_plus/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const KeneyaPlusApp());
    await tester.pump();

    final hasLogin = find.text('Connexion').evaluate().isNotEmpty;
    final hasLoader = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    expect(hasLogin || hasLoader, isTrue);
  });
}
