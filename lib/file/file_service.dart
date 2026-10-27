import '../core/api/api_client.dart';
import 'file_models.dart';

/// La file d'attente côté équipe (jeton du membre).
class FileService {
  Future<List<ServiceFile>> services() async {
    final res = await ApiClient.dio.get('/file/services');
    return _liste(res.data).map(ServiceFile.fromJson).toList();
  }

  Future<List<TicketFile>> tickets({String? serviceUuid}) async {
    final res = await ApiClient.dio.get(
      '/file/tickets',
      queryParameters: {'service': ?serviceUuid},
    );
    return _liste(res.data).map(TicketFile.fromJson).toList();
  }

  Future<TicketFile> emettre({
    required String serviceUuid,
    required String priorite,
    String? nom,
    String? telephone,
    String? dossierUuid,
  }) async {
    final res = await ApiClient.dio.post(
      '/file/tickets',
      data: {
        'service_uuid': serviceUuid,
        'priorite': priorite,
        if (nom != null && nom.isNotEmpty) 'nom': nom,
        if (telephone != null && telephone.isNotEmpty) 'telephone': telephone,
        'dossier_uuid': ?dossierUuid,
      },
    );
    return _ticket(res.data);
  }

  /// Le suivant, ou null s'il n'y a personne.
  Future<TicketFile?> appeler({
    required List<String> services,
    String? salleUuid,
  }) async {
    final res = await ApiClient.dio.post(
      '/file/appeler',
      data: {'services': services, 'point_uuid': ?salleUuid},
    );
    final t = (res.data as Map)['ticket'];
    return t is Map ? TicketFile.fromJson(Map<String, dynamic>.from(t)) : null;
  }

  /// rappeler, servir, terminer, absent, annuler.
  Future<TicketFile> action(
    String ticketUuid,
    String action, {
    String? salleUuid,
  }) async {
    final res = await ApiClient.dio.post(
      '/file/tickets/$ticketUuid/$action',
      data: {'point_uuid': ?salleUuid},
    );
    return _ticket(res.data);
  }

  Future<TicketFile> transferer(String ticketUuid, String serviceUuid) async {
    final res = await ApiClient.dio.post(
      '/file/tickets/$ticketUuid/transferer',
      data: {'service_uuid': serviceUuid},
    );
    return _ticket(res.data);
  }

  /// Les chiffres du jour : passages, absents, attentes, affluence par heure.
  Future<Map<String, dynamic>> statistiques() async {
    final res = await ApiClient.dio.get('/file/statistiques');
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ------------------------------------------------------------ réglages

  Future<void> creerService(Map<String, dynamic> donnees) async {
    await ApiClient.dio.post('/file/services', data: donnees);
  }

  Future<void> modifierService(
    String uuid,
    Map<String, dynamic> donnees,
  ) async {
    await ApiClient.dio.patch('/file/services/$uuid', data: donnees);
  }

  Future<void> supprimerService(String uuid) async {
    await ApiClient.dio.delete('/file/services/$uuid');
  }

  Future<void> creerSalle(String serviceUuid, String nom) async {
    await ApiClient.dio.post(
      '/file/services/$serviceUuid/points',
      data: {'nom': nom},
    );
  }

  Future<void> supprimerSalle(String uuid) async {
    await ApiClient.dio.delete('/file/points/$uuid');
  }

  Future<List<Map<String, dynamic>>> appareils() async {
    final res = await ApiClient.dio.get('/file/appareils');
    return _liste(res.data);
  }

  /// Nouvel écran ou nouvelle borne : renvoie le code d'appairage et son QR.
  Future<Map<String, dynamic>> creerAppareil({
    required String mode,
    required String nom,
  }) async {
    final res = await ApiClient.dio.post(
      '/file/appareils',
      data: {'mode': mode, 'nom': nom},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> nouveauCode(String appareilUuid) async {
    final res = await ApiClient.dio.post('/file/appareils/$appareilUuid/code');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> retirerAppareil(String uuid) async {
    await ApiClient.dio.delete('/file/appareils/$uuid');
  }

  TicketFile _ticket(dynamic data) => TicketFile.fromJson(
    Map<String, dynamic>.from((data as Map)['ticket'] as Map),
  );

  List<Map<String, dynamic>> _liste(dynamic data) {
    final d = data is Map ? data['data'] : null;
    return d is List
        ? d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];
  }
}
