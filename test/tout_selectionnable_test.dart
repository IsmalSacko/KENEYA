import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/common/widgets/tout_selectionnable.dart';

void main() {
  testWidgets('le texte se sélectionne, et les boutons répondent toujours', (
    tester,
  ) async {
    var touche = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ToutSelectionnable(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              const Text('Dossier N° 26-4821'),
              ElevatedButton(
                onPressed: () => touche++,
                child: const Text('Envoyer'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Dossier N° 26-4821'));
    await tester.pumpAndSettle();
    // Le menu de copie (en anglais : le test n'a pas les traductions).
    expect(find.text('Copy'), findsOneWidget);

    await tester.tapAt(const Offset(5, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer'));
    expect(touche, 1);
    expect(tester.takeException(), isNull);
  });
}
