import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import 'abonnement_service.dart';
import 'boutique_apple.dart';

/// Suit les achats Apple de l'iPhone, même hors de l'écran d'abonnement : un
/// achat confirmé par Apple (ou resté en suspens au lancement précédent) est
/// vérifié par le serveur, qui accorde la formule à l'établissement, puis
/// clos chez Apple. Créé seulement sur iPhone (voir main.dart).
class AchatsAppleController extends ChangeNotifier {
  AchatsAppleController({
    BoutiqueApple? boutique,
    AbonnementService? service,
    bool Function()? sessionOuverte,
    Future<void> Function(Map<String, dynamic> abonnement)? surAbonnement,
  }) : boutique = boutique ?? BoutiqueStoreKit(),
       _service = service ?? AbonnementService(),
       _sessionOuverte = sessionOuverte ?? (() => true),
       _surAbonnement = surAbonnement {
    _suivi = this.boutique.achats.listen(_traiter);
  }

  final BoutiqueApple boutique;
  final AbonnementService _service;

  /// Un espace d'établissement est ouvert : le serveur peut valider l'achat.
  final bool Function() _sessionOuverte;

  /// Le nouvel état de l'abonnement, après un achat validé.
  final Future<void> Function(Map<String, dynamic> abonnement)? _surAbonnement;

  late final StreamSubscription<List<AchatApple>> _suivi;

  /// Achats confirmés par Apple arrivés sans établissement ouvert : repris
  /// à l'ouverture de l'écran d'abonnement ([reprendre]).
  final _enSuspens = <AchatApple>[];

  bool enCours = false;
  String? message;
  bool reussi = false;

  /// Avance à chaque nouveau message : l'écran ne l'affiche qu'une fois.
  int numeroMessage = 0;

  void _etat({bool enCours = false, String? message, bool reussi = false}) {
    this.enCours = enCours;
    this.reussi = reussi;
    if (message != null) {
      this.message = message;
      numeroMessage++;
    }
    notifyListeners();
  }

  Future<Map<String, ProduitApple>> produits(Set<String> ids) =>
      boutique.produits(ids);

  /// [compte] : l'uuid de l'établissement, donné par le serveur.
  Future<void> acheter(String produitId, {required String compte}) async {
    if (enCours) return;
    _etat(enCours: true);
    try {
      await boutique.acheter(produitId, compte: compte);
    } catch (_) {
      _etat(message: 'L’achat n’a pas pu démarrer. Réessayez dans un instant.');
    }
  }

  Future<void> restaurer({required String compte}) async {
    if (enCours) return;
    _etat(enCours: true);
    try {
      await boutique.restaurer(compte: compte);
      // Sans achat à restaurer, Apple ne renvoie rien : on ne reste pas en attente.
      if (enCours) _etat(message: 'Vos abonnements Apple sont à jour.');
    } catch (_) {
      _etat(message: 'Restauration impossible pour le moment.');
    }
  }

  /// Les achats arrivés quand aucun établissement n'était ouvert.
  Future<void> reprendre() async {
    if (_enSuspens.isEmpty || !_sessionOuverte()) return;
    final achats = [..._enSuspens];
    _enSuspens.clear();
    await _traiter(achats);
  }

  Future<void> _traiter(List<AchatApple> achats) async {
    for (final achat in achats) {
      switch (achat.statut) {
        case StatutAchatApple.enAttente:
          _etat(
            enCours: true,
            message: 'Achat en attente de confirmation par Apple…',
          );
        case StatutAchatApple.annule:
          await boutique.terminer(achat);
          _etat();
        case StatutAchatApple.erreur:
          await boutique.terminer(achat);
          _etat(message: achat.erreur ?? 'L’achat a échoué.');
        case StatutAchatApple.achete:
        case StatutAchatApple.restaure:
          await _valider(achat);
      }
    }
  }

  Future<void> _valider(AchatApple achat) async {
    final jws = achat.transactionSignee;
    if (jws == null) {
      await boutique.terminer(achat);
      return;
    }
    // Pas d'établissement ouvert (lancement) : gardé, ni validé ni clos.
    if (!_sessionOuverte()) {
      _enSuspens.add(achat);
      return;
    }
    try {
      final etat = await _service.validerAchatApple(jws);
      await boutique.terminer(achat);
      final abonnement = etat['abonnement'];
      if (abonnement is Map) {
        await _surAbonnement?.call(Map<String, dynamic>.from(abonnement));
      }
      _etat(
        reussi: true,
        message: achat.statut == StatutAchatApple.achete
            ? 'Abonnement activé. Merci !'
            : 'Abonnement rétabli.',
      );
    } on DioException catch (e) {
      // Refusé par le serveur (autre établissement, période finie) : inutile
      // de le représenter à chaque lancement. Injoignable : on le garde,
      // Apple le représentera.
      if (e.response?.statusCode == 422) {
        await boutique.terminer(achat);
        _etat(message: messageErreur(e));
      } else {
        _etat(
          message: ApiClient.isNetworkError(e)
              ? 'Achat reçu, mais le serveur est injoignable : il sera validé dès le retour de la connexion.'
              : 'Achat reçu, mais pas encore validé : réessayez avec « Restaurer mes achats ».',
        );
      }
    }
  }

  @override
  void dispose() {
    _suivi.cancel();
    super.dispose();
  }
}
