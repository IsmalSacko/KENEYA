import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/constants/api_constants.dart';
import '../core/storage/token_storage.dart';

/// Appels du compte Ngoni Santé (`/compte`, `/pays`, `/profils`). Ils portent
/// le jeton de la personne, jamais celui du membre.
class CompteApi {
  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Accept': 'application/json'},
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await TokenStorage.getPersonneToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
          ),
        );

  static bool estHorsLigne(DioException e) => ApiClient.isNetworkError(e);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final res = await _dio.post(path, data: data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> pays() async {
    final res = await _dio.get('/pays');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> profils() async {
    final res = await _dio.get('/profils');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> connexion({
    required String paysCode,
    required String telephone,
    required String pin,
  }) => _post('/compte/connexion', {
    'pays_code': paysCode,
    'telephone': telephone,
    'pin': pin,
  });

  Future<Map<String, dynamic>> inscription({
    required String paysCode,
    required String telephone,
    required String nom,
    required String pin,
    String? code,
    bool pro = false,
  }) => _post('/compte/inscription', {
    'pays_code': paysCode,
    'telephone': telephone,
    'nom': nom,
    'pin': pin,
    'code': ?code,
    'pro': pro,
  });

  /// [objet] : `inscription` ou `pin`.
  Future<void> demanderCode({
    required String paysCode,
    required String telephone,
    required String objet,
  }) async {
    await _dio.post(
      '/compte/code',
      data: {'pays_code': paysCode, 'telephone': telephone, 'objet': objet},
    );
  }

  Future<Map<String, dynamic>> pinOublie({
    required String paysCode,
    required String telephone,
    required String code,
    required String pin,
  }) => _post('/compte/pin-oublie', {
    'pays_code': paysCode,
    'telephone': telephone,
    'code': code,
    'pin': pin,
  });

  /// La personne indique qu'elle est professionnelle de santé.
  Future<void> devenirPro() async {
    await _dio.patch('/compte', data: {'pro': true});
  }

  Future<Map<String, dynamic>> moi() async {
    final res = await _dio.get('/compte');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> ouvrirEspace(String membreUuid) =>
      _post('/compte/espaces/$membreUuid', {});

  Future<Map<String, dynamic>> creerEtablissement({
    required String nom,
    required String profil,
    required String uuid,
    required String membreUuid,
    required String autorisation,
    required String responsable,
  }) => _post('/compte/etablissements', {
    'nom': nom,
    'profil': profil,
    'uuid': uuid,
    'membre_uuid': membreUuid,
    'autorisation': autorisation,
    'responsable': responsable,
  });

  // ------------------------------------------------------------ tickets

  /// Services d'un établissement où l'on peut prendre un ticket (public).
  Future<Map<String, dynamic>> fileEtablissement(
    String etablissementUuid,
  ) async {
    final res = await _dio.get(
      '/public/etablissements/$etablissementUuid/file',
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> prendreTicket(String serviceUuid) =>
      _post('/compte/tickets', {'service_uuid': serviceUuid});

  Future<List<Map<String, dynamic>>> mesTickets() async {
    final res = await _dio.get('/compte/tickets');
    final d = (res.data as Map)['data'];
    return d is List
        ? d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : [];
  }

  Future<void> annulerTicket(String uuid) async {
    await _dio.post('/compte/tickets/$uuid/annuler');
  }

  // ------------------------------------------------------------ rendez-vous

  Future<List<Map<String, dynamic>>> _donnees(
    String chemin, [
    Map<String, dynamic>? query,
  ]) async {
    final res = await _dio.get(chemin, queryParameters: query);
    final d = (res.data as Map)['data'];
    return d is List
        ? d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : [];
  }

  /// Agendas où l'on réserve en ligne (public).
  Future<List<Map<String, dynamic>>> agendas(String etablissementUuid) =>
      _donnees('/public/etablissements/$etablissementUuid/agendas');

  Future<List<Map<String, dynamic>>> creneaux(
    String agendaUuid,
    String du,
    String au,
  ) => _donnees('/public/agendas/$agendaUuid/creneaux', {'du': du, 'au': au});

  Future<Map<String, dynamic>> reserverRdv({
    required String agendaUuid,
    required String debut,
    String? motif,
  }) => _post('/compte/rdv', {
    'agenda_uuid': agendaUuid,
    'debut': debut,
    if (motif != null && motif.isNotEmpty) 'motif': motif,
  });

  Future<List<Map<String, dynamic>>> mesRdv() => _donnees('/compte/rdv');

  Future<void> annulerRdv(String uuid) async {
    await _dio.post('/compte/rdv/$uuid/annuler');
  }

  /// La personne a scanné l'affiche de l'accueil : son rendez-vous du jour
  /// la fait entrer dans la file.
  Future<Map<String, dynamic>> arrivee(String qr) =>
      _post('/compte/arrivee', {'qr': qr});

  Future<Map<String, dynamic>> carte() async {
    final res = await _dio.get('/compte/carte');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> renouvelerCarte() =>
      _post('/compte/carte/renouveler', {});

  /// Ses visites des 90 derniers jours : actes facturés et paiements.
  Future<List<Map<String, dynamic>>> mesVisites() =>
      _donnees('/compte/visites');

  /// Ses ordonnances, avec leur QR.
  Future<List<Map<String, dynamic>>> mesOrdonnances() =>
      _donnees('/compte/ordonnances');

  // ------------------------------------------------------------ dossier

  /// Son dossier, qui y a accès, qui l'a ouvert.
  Future<Map<String, dynamic>> monDossier() async {
    final res = await _dio.get('/compte/dossier');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> modifierMonDossier(Map<String, dynamic> donnees) async {
    await _dio.patch('/compte/dossier', data: donnees);
  }

  /// Sa grossesse en cours et ses enfants, avec leur carnet de vaccination.
  Future<Map<String, dynamic>> maMaternite() async {
    final res = await _dio.get('/compte/maternite');
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Le QR à montrer au soignant pour qu'il voie l'historique (10 min).
  Future<Map<String, dynamic>> accordDossier() =>
      _post('/compte/dossier/accord', {});

  Future<void> retirerAcces(int id) async {
    await _dio.delete('/compte/dossier/acces/$id');
  }

  Future<void> deconnexion() async {
    await _dio.post('/compte/deconnexion');
  }
}
