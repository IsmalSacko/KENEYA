import '../caisse/caisse_models.dart';
import '../core/api/api_client.dart';
import 'pharmacie_models.dart';

/// La pharmacie (jeton du membre).
class PharmacieService {
  Future<List<Produit>> produits({String? recherche}) async {
    final res = await ApiClient.dio.get(
      '/pharmacie/produits',
      queryParameters: {
        if (recherche != null && recherche.isNotEmpty) 'q': recherche,
      },
    );
    return _liste(res.data).map(Produit.fromJson).toList();
  }

  /// Crée ou modifie le produit ; renvoie le produit enregistré.
  Future<Produit?> enregistrerProduit(
    Map<String, dynamic> donnees, {
    String? uuid,
  }) async {
    final res = uuid == null
        ? await ApiClient.dio.post('/pharmacie/produits', data: donnees)
        : await ApiClient.dio.patch('/pharmacie/produits/$uuid', data: donnees);
    final produit = res.data is Map ? (res.data as Map)['produit'] : null;
    return produit is Map
        ? Produit.fromJson(Map<String, dynamic>.from(produit))
        : null;
  }

  Future<List<Map<String, dynamic>>> fournisseurs() async {
    final res = await ApiClient.dio.get('/pharmacie/fournisseurs');
    return _liste(res.data);
  }

  Future<void> creerFournisseur(String nom, String? telephone) async {
    await ApiClient.dio.post(
      '/pharmacie/fournisseurs',
      data: {'nom': nom, 'telephone': ?telephone},
    );
  }

  /// [lignes] : medicament_uuid, numero, peremption (AAAA-MM-JJ), boites.
  Future<void> recevoir(
    List<Map<String, dynamic>> lignes, {
    String? fournisseur,
  }) async {
    await ApiClient.dio.post(
      '/pharmacie/receptions',
      data: {'fournisseur_uuid': ?fournisseur, 'lignes': lignes},
    );
  }

  Future<void> inventorier(String lot, int quantite) async {
    await ApiClient.dio.post(
      '/pharmacie/lots/$lot/inventaire',
      data: {'quantite': quantite},
    );
  }

  Future<Map<String, dynamic>> alertes() async {
    final res = await ApiClient.dio.get('/pharmacie/alertes');
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// La vente du comptoir : le panier, l'ordonnance scannée, le client et le
  /// paiement (null : le client passe à la caisse).
  Future<Vente> vendre(
    List<Map<String, dynamic>> lignes, {
    String? ordonnance,
    String? client,
    String? telephone,
    String? moyen,
    String? reference,
  }) async {
    final res = await ApiClient.dio.post(
      '/pharmacie/ventes',
      data: {
        'ordonnance_uuid': ?ordonnance,
        'lignes': lignes,
        'client': {'nom': ?client, 'telephone': ?telephone},
        if (moyen != null)
          'paiement': {'moyen': moyen, 'reference': ?reference},
      },
    );
    return Vente.fromJson(
      Map<String, dynamic>.from((res.data as Map)['vente'] as Map),
    );
  }

  Future<VentesDuJour> ventesDuJour() async {
    final res = await ApiClient.dio.get('/pharmacie/ventes');
    return VentesDuJour.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<ACommander>> aCommander() async {
    final res = await ApiClient.dio.get('/pharmacie/a-commander');
    return _liste(res.data).map(ACommander.fromJson).toList();
  }

  /// Qui attend à la pharmacie aujourd'hui, avec ses ordonnances.
  Future<List<PatientAServir>> aServir() async {
    final res = await ApiClient.dio.get('/pharmacie/a-servir');
    return _liste(res.data).map(PatientAServir.fromJson).toList();
  }

  Future<OrdonnanceRx> lireOrdonnance(String qr) async {
    final res = await ApiClient.dio.post(
      '/pharmacie/ordonnances/lire',
      data: {'qr': qr},
    );
    return OrdonnanceRx.fromJson(
      Map<String, dynamic>.from((res.data as Map)['ordonnance'] as Map),
    );
  }

  /// [lignes] : medicament_uuid, quantite, unite (boite|unite), ordonnance_ligne_uuid.
  Future<Visite> delivrer(
    List<Map<String, dynamic>> lignes, {
    String? ordonnance,
    String? visite,
  }) async {
    final res = await ApiClient.dio.post(
      '/pharmacie/delivrances',
      data: {
        'ordonnance_uuid': ?ordonnance,
        'visite_uuid': ?visite,
        'lignes': lignes,
      },
    );
    return Visite.fromJson(
      Map<String, dynamic>.from((res.data as Map)['visite'] as Map),
    );
  }

  /// [lignes] : produit, posologie, quantite, medicament_uuid (produit de la
  /// pharmacie).
  Future<OrdonnanceRx> prescrire(
    List<Map<String, dynamic>> lignes, {
    String? visite,
    String? patient,
  }) async {
    final res = await ApiClient.dio.post(
      '/ordonnances',
      data: {'visite_uuid': ?visite, 'patient_nom': ?patient, 'lignes': lignes},
    );
    return OrdonnanceRx.fromJson(
      Map<String, dynamic>.from((res.data as Map)['ordonnance'] as Map),
    );
  }

  Future<List<OrdonnanceRx>> ordonnancesDeLaVisite(String visite) async {
    final res = await ApiClient.dio.get(
      '/ordonnances',
      queryParameters: {'visite': visite},
    );
    return _liste(res.data).map(OrdonnanceRx.fromJson).toList();
  }

  List<Map<String, dynamic>> _liste(dynamic data) {
    final d = data is Map ? data['data'] : null;
    return d is List
        ? d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];
  }
}
