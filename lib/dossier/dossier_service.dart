import '../core/api/api_client.dart';
import 'dossier_models.dart';

/// Le dossier patient côté équipe (jeton du membre).
class DossierService {
  Future<List<DossierPatient>> rechercher(String recherche) async {
    final res = await ApiClient.dio.get(
      '/dossiers',
      queryParameters: {if (recherche.isNotEmpty) 'q': recherche},
    );
    final d = (res.data as Map)['data'];
    return [
      if (d is List)
        for (final m in d.whereType<Map>())
          DossierPatient.fromJson(Map<String, dynamic>.from(m)),
    ];
  }

  /// Le dossier du patient de la visite (créé au besoin), et le tri.
  Future<(DossierPatient, Tri?)> pourVisite(String visite) async {
    final data = (await ApiClient.dio.get('/visites/$visite/dossier')).data;
    return (_dossier(data), Tri.fromJson((data as Map)['tri']));
  }

  /// Le tri : les constantes prises avant le médecin.
  Future<Tri?> trier(String visite, Map<String, num> constantes) async {
    final res = await ApiClient.dio.post(
      '/visites/$visite/tri',
      data: {'constantes': constantes},
    );
    return Tri.fromJson((res.data as Map)['tri']);
  }

  /// Le dossier, et le tri de la visite en cours ici s'il y en a un.
  Future<(DossierPatient, Tri?)> dossier(String uuid) async {
    final data = (await ApiClient.dio.get('/dossiers/$uuid')).data;
    return (_dossier(data), Tri.fromJson((data as Map)['tri']));
  }

  Future<void> modifier(String uuid, Map<String, dynamic> donnees) async {
    await ApiClient.dio.patch('/dossiers/$uuid', data: donnees);
  }

  Future<void> envoyerCode(String uuid) async {
    await ApiClient.dio.post('/dossiers/$uuid/acces/code');
  }

  Future<DossierPatient> accorderParCode(String uuid, String code) async =>
      _dossier(
        (await ApiClient.dio.post(
          '/dossiers/$uuid/acces',
          data: {'code': code},
        )).data,
      );

  /// Le patient est là et d'accord, de vive voix (sans SMS).
  Future<DossierPatient> accorderSurPlace(String uuid) async => _dossier(
    (await ApiClient.dio.post('/dossiers/$uuid/acces/sur-place')).data,
  );

  Future<DossierPatient> accorderParQr(String qr) async => _dossier(
    (await ApiClient.dio.post('/dossiers/acces-qr', data: {'qr': qr})).data,
  );

  Future<void> consulter(String visite, Map<String, dynamic> donnees) async {
    await ApiClient.dio.post('/visites/$visite/consultation', data: donnees);
  }

  /// Le médecin corrige sa consultation (le jour même).
  Future<void> corriger(String uuid, Map<String, dynamic> donnees) async {
    await ApiClient.dio.patch('/dossiers/consultations/$uuid', data: donnees);
  }

  DossierPatient _dossier(Object? data) => DossierPatient.fromJson(
    Map<String, dynamic>.from((data as Map)['dossier'] as Map),
  );
}
