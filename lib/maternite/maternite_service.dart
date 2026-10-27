import '../core/api/api_client.dart';
import 'maternite_models.dart';

/// La maternité et la vaccination (jeton du membre).
class MaterniteService {
  Future<List<Grossesse>> grossesses({String recherche = ''}) async {
    final res = await ApiClient.dio.get(
      '/maternite/grossesses',
      queryParameters: {if (recherche.isNotEmpty) 'q': recherche},
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

  Future<CarnetEnfant> vacciner(
    String dossier,
    String vaccin, {
    String? lot,
  }) async => CarnetEnfant.fromJson(
    Map<String, dynamic>.from(
      (await ApiClient.dio.post(
            '/dossiers/$dossier/vaccins',
            data: {
              'vaccin': vaccin,
              if (lot != null && lot.isNotEmpty) 'lot': lot,
            },
          )).data
          as Map,
    ),
  );

  Grossesse _g(Object? data) => Grossesse.fromJson(
    Map<String, dynamic>.from((data as Map)['grossesse'] as Map),
  );
}
