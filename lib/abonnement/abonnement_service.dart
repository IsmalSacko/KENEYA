import '../core/api/api_client.dart';

/// Les libellés des moyens de paiement d'un abonnement.
const libellesMoyensAbonnement = {
  'orange_money': 'Orange Money',
  'moov_money': 'Moov Money',
  'wave': 'Wave',
  'especes': 'Espèces',
  'virement': 'Virement',
  'apple_app_store': 'App Store',
};

/// Ce que la formule ouvre en plus des modules.
const libellesFonctions = {
  'ecrans': 'Écran de salle et borne',
  'rapport': 'Rapport du mois',
};

/// L'abonnement de l'établissement, vu par ses administrateurs.
class AbonnementService {
  Future<Map<String, dynamic>> etat() async {
    final res = await ApiClient.dio.get('/abonnement');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> demander({
    required String formule,
    required int mois,
    required String moyen,
    String? telephone,
    String? note,
  }) async {
    final res = await ApiClient.dio.post(
      '/abonnement/demandes',
      data: {
        'formule': formule,
        'mois': mois,
        'moyen': moyen,
        if (telephone != null && telephone.isNotEmpty) 'telephone': telephone,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return Map<String, dynamic>.from((res.data as Map)['demande'] as Map);
  }

  Future<void> annuler(String uuid) =>
      ApiClient.dio.delete('/abonnement/demandes/$uuid');

  /// Un achat intégré Apple (transaction signée par Apple, StoreKit 2) : le
  /// serveur la vérifie et accorde la formule. Renvoie le nouvel état, comme
  /// [etat].
  Future<Map<String, dynamic>> validerAchatApple(
    String transactionSignee,
  ) async {
    final res = await ApiClient.dio.post(
      '/abonnement/apple',
      data: {'signed_transaction': transactionSignee},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }
}
