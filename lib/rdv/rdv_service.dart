import '../core/api/api_client.dart';
import '../file/file_models.dart';
import 'rdv_models.dart';

/// Rendez-vous côté équipe (jeton du membre).
class RdvService {
  Future<List<AgendaRdv>> agendas() async {
    final res = await ApiClient.dio.get('/agendas');
    return _liste(res.data).map(AgendaRdv.fromJson).toList();
  }

  Future<void> enregistrerAgenda(
    Map<String, dynamic> donnees, {
    String? uuid,
  }) async {
    if (uuid == null) {
      await ApiClient.dio.post('/agendas', data: donnees);
    } else {
      await ApiClient.dio.patch('/agendas/$uuid', data: donnees);
    }
  }

  Future<void> supprimerAgenda(String uuid) async {
    await ApiClient.dio.delete('/agendas/$uuid');
  }

  Future<void> ajouterAbsence(
    String agendaUuid,
    String du,
    String au,
    String? motif,
  ) async {
    await ApiClient.dio.post(
      '/agendas/$agendaUuid/absences',
      data: {'du': du, 'au': au, 'motif': ?motif},
    );
  }

  Future<List<CreneauRdv>> creneaux(
    String agendaUuid,
    String du,
    String au,
  ) async {
    final res = await ApiClient.dio.get(
      '/agendas/$agendaUuid/creneaux',
      queryParameters: {'du': du, 'au': au},
    );
    return _liste(res.data).map(CreneauRdv.fromJson).toList();
  }

  Future<List<RendezVousRdv>> rendezVous(
    String jour, {
    String? agendaUuid,
  }) async {
    final res = await ApiClient.dio.get(
      '/rdv',
      queryParameters: {'du': jour, 'au': jour, 'agenda': ?agendaUuid},
    );
    return _liste(res.data).map(RendezVousRdv.fromJson).toList();
  }

  Future<void> reserver({
    required String agendaUuid,
    required String debut,
    String? dossierUuid,
    String? nom,
    String? telephone,
    String? motif,
  }) async {
    await ApiClient.dio.post(
      '/rdv',
      data: {
        'agenda_uuid': agendaUuid,
        'debut': debut,
        'dossier_uuid': ?dossierUuid,
        if (dossierUuid == null) 'nom': nom,
        if (dossierUuid == null && telephone != null && telephone.isNotEmpty)
          'telephone': telephone,
        if (motif != null && motif.isNotEmpty) 'motif': motif,
      },
    );
  }

  /// confirmer, refuser, annuler, absent.
  Future<void> action(String uuid, String action) async {
    await ApiClient.dio.post('/rdv/$uuid/$action');
  }

  /// Arrivée du patient : il entre dans la file (priorité rendez-vous).
  Future<TicketFile> arrivee(String uuid) async {
    final res = await ApiClient.dio.post('/rdv/$uuid/arrivee');
    return TicketFile.fromJson(
      Map<String, dynamic>.from((res.data as Map)['ticket'] as Map),
    );
  }

  /// L'accueil scanne un QR : rendez-vous ou carte santé.
  Future<Map<String, dynamic>> scanner(
    String qr, {
    String? serviceUuid,
    String? priorite,
  }) async {
    final res = await ApiClient.dio.post(
      '/accueil/scan',
      data: {'qr': qr, 'service_uuid': ?serviceUuid, 'priorite': ?priorite},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> qrAccueil() async {
    final res = await ApiClient.dio.get('/accueil/qr');
    return Map<String, dynamic>.from(res.data as Map);
  }

  List<Map<String, dynamic>> _liste(dynamic data) {
    final d = data is Map ? data['data'] : null;
    return d is List
        ? d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];
  }
}
