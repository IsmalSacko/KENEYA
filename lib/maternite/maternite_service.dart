import '../core/api/api_client.dart';
import 'maternite_models.dart';

/// La maternité et la vaccination (jeton du membre).
class MaterniteService {
  /// En cours ; [terminees] : accouchées et closes, les dernières d'abord.
  Future<List<Grossesse>> grossesses({
    String recherche = '',
    bool terminees = false,
  }) async {
    final res = await ApiClient.dio.get(
      '/maternite/grossesses',
      queryParameters: {
        if (recherche.isNotEmpty) 'q': recherche,
        if (terminees) 'statut': 'terminees',
      },
    );
    final d = (res.data as Map)['data'];
    return [
      if (d is List)
        for (final m in d.whereType<Map>())
          Grossesse.fromJson(Map<String, dynamic>.from(m)),
    ];
  }

  /// La grossesse en cours de la patiente de la visite, ou null.
  Future<Grossesse?> pourVisite(String visite) async {
    final g = (await ApiClient.dio.get('/visites/$visite/grossesse')).data;
    final m = g is Map ? g['grossesse'] : null;
    return m is Map ? Grossesse.fromJson(Map<String, dynamic>.from(m)) : null;
  }

  Future<Grossesse> declarer(String visite, Map<String, dynamic> d) async => _g(
    (await ApiClient.dio.post('/visites/$visite/grossesse', data: d)).data,
  );

  Future<Grossesse> grossesse(String uuid) async =>
      _g((await ApiClient.dio.get('/maternite/grossesses/$uuid')).data);

  /// Corriger la DDR (le terme suit), la gestité, la parité, les risques.
  Future<Grossesse> modifier(String uuid, Map<String, dynamic> d) async => _g(
    (await ApiClient.dio.patch('/maternite/grossesses/$uuid', data: d)).data,
  );

  /// Clore sans accouchement ici ; [le] au format AAAA-MM-JJ.
  Future<Grossesse> terminer(String uuid, String issue, String le) async => _g(
    (await ApiClient.dio.post(
      '/maternite/grossesses/$uuid/terminer',
      data: {'issue': issue, 'le': le},
    )).data,
  );

  /// Corriger la dernière CPN.
  Future<Grossesse> modifierCpn(String cpn, Map<String, dynamic> d) async =>
      _g((await ApiClient.dio.patch('/maternite/cpn/$cpn', data: d)).data);

  Future<Grossesse> cpn(String uuid, Map<String, dynamic> d) async => _g(
    (await ApiClient.dio.post('/maternite/grossesses/$uuid/cpn', data: d)).data,
  );

  Future<Grossesse> accoucher(String uuid, Map<String, dynamic> d) async => _g(
    (await ApiClient.dio.post(
      '/maternite/grossesses/$uuid/accouchement',
      data: d,
    )).data,
  );

  Future<CarnetEnfant> carnet(String dossier) async => CarnetEnfant.fromJson(
    Map<String, dynamic>.from(
      (await ApiClient.dio.get('/dossiers/$dossier/vaccins')).data as Map,
    ),
  );

  /// [faitLe] au format AAAA-MM-JJ ; sans lui, aujourd'hui.
  Future<CarnetEnfant> vacciner(
    String dossier,
    String vaccin, {
    String? lot,
    String? faitLe,
  }) async => CarnetEnfant.fromJson(
    Map<String, dynamic>.from(
      (await ApiClient.dio.post(
            '/dossiers/$dossier/vaccins',
            data: {
              'vaccin': vaccin,
              if (lot != null && lot.isNotEmpty) 'lot': lot,
              'fait_le': ?faitLe,
            },
          )).data
          as Map,
    ),
  );

  /// Un vaccin noté par erreur.
  Future<CarnetEnfant> annulerVaccin(String dossier, String vaccin) async =>
      CarnetEnfant.fromJson(
        Map<String, dynamic>.from(
          (await ApiClient.dio.delete(
                '/dossiers/$dossier/vaccins/$vaccin',
              )).data
              as Map,
        ),
      );

  Grossesse _g(Object? data) => Grossesse.fromJson(
    Map<String, dynamic>.from((data as Map)['grossesse'] as Map),
  );
}
