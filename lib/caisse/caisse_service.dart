import '../core/api/api_client.dart';
import 'caisse_models.dart';

/// La caisse unifiée (jeton du membre).
class CaisseService {
  Future<List<Tarif>> tarifs() async {
    final res = await ApiClient.dio.get('/tarifs');
    return _liste(res.data).map(Tarif.fromJson).toList();
  }

  Future<void> enregistrerTarif(
    Map<String, dynamic> donnees, {
    String? uuid,
  }) async {
    if (uuid == null) {
      await ApiClient.dio.post('/tarifs', data: donnees);
    } else {
      await ApiClient.dio.patch('/tarifs/$uuid', data: donnees);
    }
  }

  Future<void> supprimerTarif(String uuid) async {
    await ApiClient.dio.delete('/tarifs/$uuid');
  }

  Future<List<Visite>> visites({String? recherche, bool toutes = false}) async {
    final res = await ApiClient.dio.get(
      '/visites',
      queryParameters: {
        if (recherche != null && recherche.isNotEmpty) 'q': recherche,
        if (toutes) 'statut': 'toutes',
      },
    );
    return _liste(res.data).map(Visite.fromJson).toList();
  }

  Future<Visite> visite(String uuid) async {
    final res = await ApiClient.dio.get('/visites/$uuid');
    return _visite(res.data);
  }

  Future<Visite> ajouterActe(
    String visite,
    Tarif tarif, {
    int quantite = 1,
  }) async {
    final res = await ApiClient.dio.post(
      '/visites/$visite/lignes',
      data: {'tarif_uuid': tarif.uuid, 'quantite': quantite},
    );
    return _visite(res.data);
  }

  Future<Visite> ajouterLigneLibre(
    String visite,
    String libelle,
    int prix,
  ) async {
    final res = await ApiClient.dio.post(
      '/visites/$visite/lignes',
      data: {'libelle': libelle, 'prix': prix},
    );
    return _visite(res.data);
  }

  Future<Visite> retirerLigne(String visite, String ligne) async {
    final res = await ApiClient.dio.delete('/visites/$visite/lignes/$ligne');
    return _visite(res.data);
  }

  Future<Visite> encaisser(
    String visite, {
    required int montant,
    required String moyen,
    String? reference,
  }) async {
    final res = await ApiClient.dio.post(
      '/visites/$visite/encaisser',
      data: {
        'montant': montant,
        'moyen': moyen,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
      },
    );
    return _visite(res.data);
  }

  /// Une vente ou une facture sans ticket (le client du comptoir).
  Future<Visite> nouvelleVisite({String? nom, String? telephone}) async {
    final res = await ApiClient.dio.post(
      '/visites',
      data: {'nom': ?nom, 'telephone': ?telephone},
    );
    return _visite(res.data);
  }

  Future<Visite> cloturerVisite(String visite) async {
    final res = await ApiClient.dio.post('/visites/$visite/cloturer');
    return _visite(res.data);
  }

  /// `{session, moyens, devise}` ; session null si la caisse est fermée.
  Future<Map<String, dynamic>> session() async {
    final res = await ApiClient.dio.get('/caisse/session');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> ouvrir(int fondInitial) async {
    final res = await ApiClient.dio.post(
      '/caisse/ouvrir',
      data: {'fond_initial': fondInitial},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> cloturer(int especesComptees) async {
    final res = await ApiClient.dio.post(
      '/caisse/cloturer',
      data: {'especes_comptees': especesComptees},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ------------------------------------------------------------ assurances

  Future<List<Assureur>> assureurs() async {
    final res = await ApiClient.dio.get('/assureurs');
    return _liste(res.data).map(Assureur.fromJson).toList();
  }

  Future<void> enregistrerAssureur(
    Map<String, dynamic> donnees, {
    String? uuid,
  }) async {
    if (uuid == null) {
      await ApiClient.dio.post('/assureurs', data: donnees);
    } else {
      await ApiClient.dio.patch('/assureurs/$uuid', data: donnees);
    }
  }

  Future<Visite> couvrir(String visite, String assureur, String numero) async {
    final res = await ApiClient.dio.post(
      '/visites/$visite/assurance',
      data: {'assureur_uuid': assureur, 'numero': numero},
    );
    return _visite(res.data);
  }

  Future<Visite> retirerAssurance(String visite) async =>
      _visite((await ApiClient.dio.delete('/visites/$visite/assurance')).data);

  /// Le bordereau du mois ([mois] : « 2026-10 »).
  Future<Map<String, dynamic>> bordereau(String assureur, String mois) async {
    final res = await ApiClient.dio.get(
      '/assurances/bordereau',
      queryParameters: {'assureur': assureur, 'mois': mois},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> rapport() async {
    final res = await ApiClient.dio.get('/caisse/rapport');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Visite _visite(dynamic data) => Visite.fromJson(
    Map<String, dynamic>.from((data as Map)['visite'] as Map),
  );

  List<Map<String, dynamic>> _liste(dynamic data) {
    final d = data is Map ? data['data'] : null;
    return d is List
        ? d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];
  }
}
