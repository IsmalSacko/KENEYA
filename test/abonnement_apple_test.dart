import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/abonnement/abonnement_service.dart';
import 'package:keneya_plus/abonnement/achats_apple_controller.dart';
import 'package:keneya_plus/abonnement/boutique_apple.dart';
import 'package:keneya_plus/caisse/caisse_models.dart';
import 'package:keneya_plus/compte/compte_controller.dart';
import 'package:keneya_plus/controllers/auth_controller.dart';
import 'package:keneya_plus/screens/abonnement/abonnement_screen.dart';
import 'package:provider/provider.dart';

const _uuid = '6e0d1a10-0002-4c3a-9a51-0000000000a2';

Map<String, dynamic> _tarif(int mois, int montant, String? apple) => {
  'mois': mois,
  'montant': montant,
  'devise': 'XOF',
  'apple_produit': apple,
};

/// La réponse de GET /abonnement : un essai, trois formules, de quoi payer
/// par Orange Money et WhatsApp, un paiement dans l'historique.
Map<String, dynamic> _etat({String formule = 'essai', bool enCours = true}) => {
  'abonnement': {
    'formule': formule,
    'formule_nom': formule == 'essai' ? 'Essai gratuit' : 'Pro',
    'essai': formule == 'essai',
    'en_cours': enCours,
    'fin': '2026-11-16',
    'jours_restants': 14,
    'membres': 2,
    'max_membres': null,
    'demande_en_attente': {
      'uuid': 'b1',
      'formule_nom': 'Pro',
      'mois': 1,
      'montant': 15000,
      'devise': 'XOF',
    },
  },
  'formules': [
    {
      'code': 'essentiel',
      'nom': 'Essentiel',
      'description': 'Cabinet médical',
      'modules': ['file', 'consultation'],
      'fonctions': <String>[],
      'max_membres': 5,
      'tarifs': [
        _tarif(1, 5000, 'ngonisante.essentiel.mensuel'),
        _tarif(3, 14000, null),
        _tarif(12, 50000, 'ngonisante.essentiel.annuel'),
      ],
    },
    {
      'code': 'pro',
      'nom': 'Pro',
      'description': 'Centre de santé',
      'modules': ['file', 'labo'],
      'fonctions': ['rapport'],
      'max_membres': 15,
      'tarifs': [
        _tarif(1, 15000, 'ngonisante.pro.mensuel'),
        _tarif(12, 150000, 'ngonisante.pro.annuel'),
      ],
    },
    {
      'code': 'hopital',
      'nom': 'Hôpital',
      'description': 'Clinique',
      'modules': ['file'],
      'fonctions': <String>[],
      'max_membres': null,
      // Pas encore configurée chez Apple : elle n'est pas proposée.
      'tarifs': [_tarif(1, 40000, 'ngonisante.hopital.mensuel')],
    },
  ],
  'paiement': {
    'numeros': [
      {
        'telephone': '+22373136789',
        'moyens': ['orange_money', 'wave'],
      },
    ],
    'whatsapp': '+33605758494',
    'moyens': ['orange_money', 'wave'],
  },
  'historique': [
    {
      'uuid': 'h1',
      'formule_nom': 'Pro',
      'mois': 1,
      'montant': 15000,
      'devise': 'XOF',
      'moyen': 'orange_money',
      'statut': 'approuvee',
      'recu_numero': 'A26-0001',
      'periode_debut': '2026-10-01',
      'periode_fin': '2026-10-31',
    },
  ],
  'apple_compte': _uuid,
};

class _Service extends AbonnementService {
  _Service({this.refus});

  /// Le serveur refuse l'achat (422), ou il est injoignable.
  DioException? refus;
  final transactions = <String>[];
  var abonne = false;

  @override
  Future<Map<String, dynamic>> etat() async =>
      _etat(formule: abonne ? 'pro' : 'essai');

  @override
  Future<Map<String, dynamic>> validerAchatApple(String jws) async {
    transactions.add(jws);
    if (refus != null) throw refus!;
    abonne = true;
    return _etat(formule: 'pro');
  }
}

DioException _reponse(int code, String message) {
  final options = RequestOptions(path: '/abonnement/apple');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: code,
      data: {'message': message},
    ),
  );
}

/// Fausse boutique Apple : les abonnements Essentiel et Pro, et des achats
/// qu'on pousse à la main.
class _BoutiqueApple implements BoutiqueApple {
  final achatsEnvoyes = StreamController<List<AchatApple>>.broadcast();
  final achetes = <(String, String)>[];
  final restaurations = <String>[];
  final termines = <String>[];

  @override
  Future<bool> disponible() async => true;

  @override
  Future<Map<String, ProduitApple>> produits(Set<String> ids) async => {
    for (final p in [
      (
        id: 'ngonisante.essentiel.mensuel',
        titre: 'Essentiel',
        prix: '4 900 F CFA',
      ),
      (
        id: 'ngonisante.essentiel.annuel',
        titre: 'Essentiel',
        prix: '49 000 F CFA',
      ),
      (id: 'ngonisante.pro.mensuel', titre: 'Pro', prix: '14 900 F CFA'),
      (id: 'ngonisante.pro.annuel', titre: 'Pro', prix: '149 000 F CFA'),
    ])
      if (ids.contains(p.id)) p.id: p,
  };

  @override
  Future<void> acheter(String produitId, {required String compte}) async =>
      achetes.add((produitId, compte));

  @override
  Future<void> restaurer({required String compte}) async =>
      restaurations.add(compte);

  @override
  Stream<List<AchatApple>> get achats => achatsEnvoyes.stream;

  @override
  Future<void> terminer(AchatApple achat) async =>
      termines.add(achat.produitId);
}

/// Un administrateur connecté, sans stockage ni réseau.
class _Auth extends AuthController {
  @override
  Future<void> restoreSession() async {
    accessToken = 'jeton';
    initializing = false;
  }

  @override
  Future<void> majAbonnement(Map<String, dynamic> etat) async {
    abonnement = etat;
    notifyListeners();
  }
}

Future<_Auth> _monter(
  WidgetTester tester, {
  required _Service service,
  required _BoutiqueApple apple,
  bool session = true,
  double hauteur = 2400,
}) async {
  tester.view.physicalSize = Size(1080, hauteur);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final auth = _Auth();
  final achats = AchatsAppleController(
    boutique: apple,
    service: service,
    sessionOuverte: () => session,
    surAbonnement: auth.majAbonnement,
  );
  addTearDown(achats.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<CompteController>(
          create: (_) => CompteController(),
        ),
        ChangeNotifierProvider<AchatsAppleController>.value(value: achats),
      ],
      child: MaterialApp(home: AbonnementScreen(service: service)),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets(
    'iPhone : les formules s’achètent chez Apple, sans autre moyen de paiement',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final service = _Service();
        final apple = _BoutiqueApple();
        // Tout l'écran d'un coup : rien de caché plus bas.
        final auth = await _monter(
          tester,
          service: service,
          apple: apple,
          hauteur: 9000,
        );

        // L'état reste visible.
        expect(find.text('Essai gratuit'), findsOneWidget);
        // Le prix d'Apple ; ni francs hors Apple, ni Orange Money, ni WhatsApp, ni demande.
        expect(find.text('4 900 F CFA / mois'), findsOneWidget);
        expect(find.text('14 900 F CFA / mois'), findsOneWidget);
        expect(find.textContaining('FCFA'), findsNothing);
        expect(find.text(formatMontant(5000, 'XOF')), findsNothing);
        expect(find.textContaining('Orange'), findsNothing);
        expect(find.textContaining('Wave'), findsNothing);
        expect(find.textContaining('WhatsApp'), findsNothing);
        expect(find.textContaining('+223'), findsNothing);
        expect(find.textContaining('Demande envoyée'), findsNothing);
        expect(find.text('Historique'), findsNothing);
        expect(find.text('3 mois'), findsNothing);
        // Pas encore chez Apple : pas proposée.
        expect(find.text('Hôpital'), findsNothing);
        // Ce qu'Apple exige près d'un abonnement.
        expect(
          find.textContaining('renouvellement automatique'),
          findsOneWidget,
        );
        expect(find.text('Restaurer mes achats'), findsOneWidget);
        expect(find.text('Conditions d’utilisation'), findsOneWidget);
        expect(find.text('Confidentialité'), findsOneWidget);

        // Annuel, puis achat : lié à l'établissement (son uuid).
        await tester.tap(find.text('Annuel'));
        await tester.pumpAndSettle();
        expect(find.text('149 000 F CFA / an'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const Key('acheter-apple-pro')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('acheter-apple-pro')));
        await tester.pumpAndSettle();
        expect(apple.achetes, [('ngonisante.pro.annuel', _uuid)]);

        // Apple confirme : le serveur vérifie, l'achat est clos, la formule s'active.
        apple.achatsEnvoyes.add([
          const AchatApple(
            produitId: 'ngonisante.pro.annuel',
            statut: StatutAchatApple.achete,
            transactionSignee: 'jws-1',
          ),
        ]);
        await tester.pumpAndSettle();
        expect(service.transactions, ['jws-1']);
        expect(apple.termines, ['ngonisante.pro.annuel']);
        expect(find.text('Abonnement activé. Merci !'), findsOneWidget);
        expect(auth.abonnement?['formule'], 'pro');
        expect(find.text('Pro'), findsWidgets);

        // Restaurer : avec l'uuid de l'établissement.
        await tester.ensureVisible(find.byKey(const Key('restaurer-apple')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('restaurer-apple')));
        await tester.pumpAndSettle();
        expect(apple.restaurations, [_uuid]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'iPhone : un achat refusé par le serveur est clos et expliqué ; injoignable, il est gardé',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final service = _Service(
          refus: _reponse(
            422,
            'Cet achat de l’App Store a été fait pour un autre établissement : il ne peut pas servir à celui-ci.',
          ),
        );
        final apple = _BoutiqueApple();
        await _monter(tester, service: service, apple: apple);

        apple.achatsEnvoyes.add([
          const AchatApple(
            produitId: 'ngonisante.pro.mensuel',
            statut: StatutAchatApple.achete,
            transactionSignee: 'jws-2',
          ),
        ]);
        await tester.pumpAndSettle();
        expect(apple.termines, ['ngonisante.pro.mensuel']);
        expect(
          find.textContaining('fait pour un autre établissement'),
          findsOneWidget,
        );

        service.refus = DioException(
          requestOptions: RequestOptions(path: '/abonnement/apple'),
          type: DioExceptionType.connectionError,
        );
        apple.achatsEnvoyes.add([
          const AchatApple(
            produitId: 'ngonisante.pro.mensuel',
            statut: StatutAchatApple.achete,
            transactionSignee: 'jws-3',
          ),
        ]);
        await tester.pumpAndSettle();
        expect(
          apple.termines,
          ['ngonisante.pro.mensuel'],
          reason: 'pas clos : Apple le représentera au prochain lancement',
        );
        expect(find.textContaining('serveur est injoignable'), findsOneWidget);

        // Annulé chez Apple : clos, sans rien envoyer au serveur.
        apple.achatsEnvoyes.add([
          const AchatApple(
            produitId: 'ngonisante.essentiel.mensuel',
            statut: StatutAchatApple.annule,
          ),
        ]);
        await tester.pumpAndSettle();
        expect(service.transactions, ['jws-2', 'jws-3']);
        expect(apple.termines.last, 'ngonisante.essentiel.mensuel');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test(
    'un achat arrivé sans établissement ouvert attend, puis est validé',
    () async {
      final service = _Service();
      final apple = _BoutiqueApple();
      var session = false;
      final achats = AchatsAppleController(
        boutique: apple,
        service: service,
        sessionOuverte: () => session,
      );
      addTearDown(achats.dispose);

      apple.achatsEnvoyes.add([
        const AchatApple(
          produitId: 'ngonisante.essentiel.annuel',
          statut: StatutAchatApple.restaure,
          transactionSignee: 'jws-4',
        ),
      ]);
      await pumpEventQueue();
      expect(service.transactions, isEmpty);
      expect(apple.termines, isEmpty);

      session = true;
      await achats.reprendre();
      expect(service.transactions, ['jws-4']);
      expect(apple.termines, ['ngonisante.essentiel.annuel']);
      expect(achats.message, 'Abonnement rétabli.');
    },
  );

  testWidgets(
    'Android : les formules en francs, Orange Money et WhatsApp, sans achat Apple',
    (tester) async {
      final service = _Service();
      final apple = _BoutiqueApple();
      // Tout l'écran d'un coup, historique compris.
      await _monter(tester, service: service, apple: apple, hauteur: 9000);

      expect(find.text(formatMontant(5000, 'XOF')), findsOneWidget);
      expect(find.text('Une question ? WhatsApp'), findsOneWidget);
      expect(find.textContaining('Demande envoyée'), findsOneWidget);
      expect(find.text('Historique'), findsOneWidget);
      expect(find.text('Restaurer mes achats'), findsNothing);
      expect(find.byKey(const Key('acheter-apple-pro')), findsNothing);
    },
  );
}
