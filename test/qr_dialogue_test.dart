import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('un QR de taille fixe s’affiche dans une fenêtre AlertDialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                content: SizedBox(
                  width: 240,
                  height: 240,
                  child: QrImageView(data: 'ngoni-sante:etab:test', size: 240),
                ),
              ),
            ),
            child: const Text('Voir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Voir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
