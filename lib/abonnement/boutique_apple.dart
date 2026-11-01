import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Un abonnement tel qu'Apple le vend : son prix est celui du pays de
/// l'acheteur, déjà mis en forme par Apple (« 9 900 F CFA », « 14,99 € »).
typedef ProduitApple = ({String id, String titre, String prix});

/// Où en est un achat : Apple le confirme ([transactionSignee] à faire
/// vérifier par le serveur), l'acheteur l'annule, ou il échoue.
enum StatutAchatApple { enAttente, achete, restaure, annule, erreur }

class AchatApple {
  const AchatApple({
    required this.produitId,
    required this.statut,
    this.transactionSignee,
    this.erreur,
    this.brut,
  });

  final String produitId;
  final StatutAchatApple statut;

  /// La transaction signée par Apple (JWS), preuve de l'achat pour le serveur.
  final String? transactionSignee;
  final String? erreur;

  /// L'achat tel que le donne le plugin, pour le clore.
  final PurchaseDetails? brut;
}

/// Achats intégrés d'Apple (iPhone, iPad). Derrière cette interface,
/// StoreKit 2 ; dans les tests, une fausse boutique.
abstract class BoutiqueApple {
  Future<bool> disponible();

  /// Les abonnements connus d'Apple parmi [ids] ; un produit pas encore
  /// configuré chez Apple manque simplement.
  Future<Map<String, ProduitApple>> produits(Set<String> ids);

  /// [compte] : l'uuid de l'établissement, transmis à Apple (appAccountToken)
  /// pour que l'abonnement revienne à cet établissement.
  Future<void> acheter(String produitId, {required String compte});

  Future<void> restaurer({required String compte});

  Stream<List<AchatApple>> get achats;

  /// Clôt l'achat chez Apple : sans cela, il revient à chaque lancement.
  Future<void> terminer(AchatApple achat);
}

class BoutiqueStoreKit implements BoutiqueApple {
  final _iap = InAppPurchase.instance;
  final _details = <String, ProductDetails>{};

  @override
  Future<bool> disponible() => _iap.isAvailable();

  @override
  Future<Map<String, ProduitApple>> produits(Set<String> ids) async {
    if (ids.isEmpty || !await _iap.isAvailable()) return const {};
    final reponse = await _iap.queryProductDetails(ids);
    for (final p in reponse.productDetails) {
      _details[p.id] = p;
    }
    return {
      for (final p in reponse.productDetails)
        p.id: (id: p.id, titre: p.title, prix: p.price),
    };
  }

  @override
  Future<void> acheter(String produitId, {required String compte}) async {
    final connus = _details[produitId];
    final details =
        connus ??
        (await _iap.queryProductDetails({produitId})).productDetails.firstOrNull;
    if (details == null) {
      throw StateError('Abonnement indisponible chez Apple.');
    }
    // Un abonnement se renouvelle : il s'achète comme un « non consommable ».
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: details,
        applicationUserName: compte,
      ),
    );
  }

  @override
  Future<void> restaurer({required String compte}) =>
      _iap.restorePurchases(applicationUserName: compte);

  @override
  Stream<List<AchatApple>> get achats =>
      _iap.purchaseStream.map((liste) => [for (final p in liste) _depuis(p)]);

  @override
  Future<void> terminer(AchatApple achat) async {
    final brut = achat.brut;
    if (brut != null && brut.pendingCompletePurchase) {
      await _iap.completePurchase(brut);
    }
  }

  AchatApple _depuis(PurchaseDetails p) => AchatApple(
    produitId: p.productID,
    statut: switch (p.status) {
      PurchaseStatus.pending => StatutAchatApple.enAttente,
      PurchaseStatus.purchased => StatutAchatApple.achete,
      PurchaseStatus.restored => StatutAchatApple.restaure,
      PurchaseStatus.canceled => StatutAchatApple.annule,
      PurchaseStatus.error => StatutAchatApple.erreur,
    },
    transactionSignee: p.verificationData.serverVerificationData.isEmpty
        ? null
        : p.verificationData.serverVerificationData,
    erreur: p.error?.message,
    brut: p,
  );
}
