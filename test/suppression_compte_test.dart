import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/compte/compte_controller.dart';
import 'package:keneya_plus/compte/mes_tickets_controller.dart';
import 'package:keneya_plus/controllers/auth_controller.dart';
import 'package:keneya_plus/screens/compte/suppression_compte.dart';
import 'package:provider/provider.dart';

/// Le compte vu du serveur : ce que la suppression emporterait, et le PIN.
class _Compte extends CompteController {
  _Compte(this.apercu);

  final Map<String, dynamic> apercu;
  final pins = <String>[];

  @override
  Future<Map<String, dynamic>> apercuSuppression() async => apercu;

  @override
  Future<void> supprimerCompte(String pin, AuthController auth) async {
    pins.add(pin);
    if (pin != '1234') {
      final options = RequestOptions(path: '/compte/supprimer');
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 422,
          data: {
            'message': 'PIN incorrect.',
            'errors': {
              'pin': ['PIN incorrect.'],
            },
          },
        ),
      );
    }
  }
}

class _Auth extends AuthController {
  @override
  Future<void> restoreSession() async => initializing = false;
}

Future<_Compte> _monter(
  WidgetTester tester,
  Map<String, dynamic> apercu,
) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final compte = _Compte(apercu);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(create: (_) => _Auth()),
        ChangeNotifierProvider<CompteController>.value(value: compte),
        ChangeNotifierProvider<MesTicketsController>(
          create: (_) => MesTicketsController(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => supprimerMonCompte(context),
              child: const Text('Supprimer mon compte'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Supprimer mon compte'));
  await tester.pumpAndSettle();
  return compte;
}

void main() {
  testWidgets(
    'iPhone : ce qui part est dit avant (établissement, dossier, abonnement Apple), puis PIN et SUPPRIMER',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final compte = await _monter(tester, {
          'etablissements_supprimes': [
            {'nom': 'Cabinet Awa', 'patients': 12, 'equipe': 3},
          ],
          'etablissements_gardes': [
            {'nom': 'CSCom de Banconi', 'repreneur': 'Dr Diarra'},
          ],
          'dossier': 'garde',
          'abonnement_apple': true,
          'blocage': null,
        });

        expect(
          find.textContaining('« Cabinet Awa » est supprimé aussi'),
          findsOneWidget,
        );
        expect(find.textContaining('12 patients'), findsOneWidget);
        expect(
          find.textContaining('« CSCom de Banconi » continue avec Dr Diarra'),
          findsOneWidget,
        );
        expect(
          find.textContaining('durée de conservation imposée par la loi'),
          findsOneWidget,
        );
        expect(
          find.textContaining('les factures et les actes déjà enregistrés'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Pensez à résilier votre abonnement dans les réglages Apple : supprimer le compte ne l’arrête pas.',
          ),
          findsOneWidget,
        );

        // Le bouton attend le PIN et le mot SUPPRIMER.
        Finder bouton() =>
            find.byKey(const Key('confirmer-suppression-compte'));
        expect(tester.widget<FilledButton>(bouton()).onPressed, isNull);
        await tester.enterText(
          find.byKey(const Key('suppression-pin')),
          '9999',
        );
        await tester.enterText(
          find.byKey(const Key('suppression-confirmation')),
          'supprimer',
        );
        await tester.pump();
        expect(tester.widget<FilledButton>(bouton()).onPressed, isNotNull);

        // Mauvais PIN : expliqué, rien n'est fermé.
        await tester.tap(bouton());
        await tester.pumpAndSettle();
        expect(find.text('PIN incorrect.'), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('suppression-pin')),
          '1234',
        );
        await tester.tap(bouton());
        await tester.pumpAndSettle();
        expect(compte.pins, ['9999', '1234']);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.text('Votre compte Ngoni Santé est supprimé.'),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'Android : sans rappel Apple ; un compte de l’équipe ne se supprime pas d’ici',
    (tester) async {
      final compte = await _monter(tester, {
        'etablissements_supprimes': <Map<String, dynamic>>[],
        'etablissements_gardes': <Map<String, dynamic>>[],
        'dossier': 'supprime',
        'abonnement_apple': false,
        'blocage':
            'Compte de l’équipe Ngoni Santé : il ne se supprime pas depuis l’application.',
      });

      expect(find.textContaining('réglages Apple'), findsNothing);
      expect(
        find.text('Votre dossier « Ma santé » est supprimé.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Compte de l’équipe Ngoni Santé'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('suppression-pin')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('confirmer-suppression-compte')),
            )
            .onPressed,
        isNull,
      );
      expect(compte.pins, isEmpty);
    },
  );
}
