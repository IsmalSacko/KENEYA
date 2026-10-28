import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import '../core/api/api_client.dart';
import '../file/impression_ticket.dart';
import 'labo_models.dart';

/// Le laboratoire (jeton du membre).
class LaboService {
  Future<List<AnalyseLabo>> analyses({bool toutes = false}) async {
    final res = await ApiClient.dio.get(
      '/labo/analyses',
      queryParameters: {if (toutes) 'toutes': 1},
    );
    return [for (final m in _liste(res.data)) AnalyseLabo.fromJson(m)];
  }

  Future<void> enregistrerAnalyse(
    Map<String, dynamic> donnees, {
    String? uuid,
  }) async {
    if (uuid == null) {
      await ApiClient.dio.post('/labo/analyses', data: donnees);
    } else {
      await ApiClient.dio.patch('/labo/analyses/$uuid', data: donnees);
    }
  }

  /// [validees] : les résultats validés des [jours] derniers jours ; [q]
  /// cherche le nom du patient.
  Future<List<DemandeLabo>> demandes({
    bool validees = false,
    int jours = 1,
    String q = '',
  }) async {
    final res = await ApiClient.dio.get(
      '/labo/demandes',
      queryParameters: {
        if (validees) ...{'statut': 'validee', 'jours': jours},
        if (q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    return [for (final m in _liste(res.data)) DemandeLabo.fromJson(m)];
  }

  Future<DemandeLabo> demander({
    required String visite,
    required List<String> analyses,
    List<String> autres = const [],
    bool urgent = false,
    String? renseignements,
  }) async => _demande(
    (await ApiClient.dio.post(
      '/labo/demandes',
      data: {
        'visite_uuid': visite,
        'analyses': analyses,
        if (autres.isNotEmpty) 'autres': autres,
        'urgent': urgent,
        if (renseignements != null && renseignements.isNotEmpty)
          'renseignements': renseignements,
      },
    )).data,
  );

  Future<DemandeLabo> demande(String uuid) async =>
      _demande((await ApiClient.dio.get('/labo/demandes/$uuid')).data);

  /// L'étiquette du tube, scannée.
  Future<DemandeLabo> lire(String qr) async => _demande(
    (await ApiClient.dio.post('/labo/demandes/lire', data: {'qr': qr})).data,
  );

  Future<DemandeLabo> prelever(String uuid) async => _demande(
    (await ApiClient.dio.post('/labo/demandes/$uuid/prelever')).data,
  );

  /// [resultats] et [commentaires] : par ligne (uuid).
  Future<DemandeLabo> saisir(
    String uuid,
    Map<String, String> resultats, {
    Map<String, String> commentaires = const {},
  }) async => _demande(
    (await ApiClient.dio.post(
      '/labo/demandes/$uuid/resultats',
      data: {'resultats': _resultats(resultats, commentaires)},
    )).data,
  );

  Future<DemandeLabo> valider(String uuid) async =>
      _demande((await ApiClient.dio.post('/labo/demandes/$uuid/valider')).data);

  /// Corriger des résultats validés, avec la raison.
  Future<DemandeLabo> corriger(
    String uuid,
    Map<String, String> resultats, {
    required String motif,
    Map<String, String> commentaires = const {},
  }) async => _demande(
    (await ApiClient.dio.post(
      '/labo/demandes/$uuid/corriger',
      data: {'motif': motif, 'resultats': _resultats(resultats, commentaires)},
    )).data,
  );

  /// L'échantillon est inutilisable : à prélever de nouveau.
  Future<DemandeLabo> rejeter(String uuid, String motif) async => _demande(
    (await ApiClient.dio.post(
      '/labo/demandes/$uuid/rejeter',
      data: {'motif': motif},
    )).data,
  );

  /// Annule ; la note dit si les analyses restent sur la facture.
  Future<(DemandeLabo, String?)> annuler(String uuid, {String? motif}) async {
    final res = await ApiClient.dio.post(
      '/labo/demandes/$uuid/annuler',
      data: {if (motif != null && motif.isNotEmpty) 'motif': motif},
    );
    final note = (res.data as Map)['note'];
    return (_demande(res.data), note is String ? note : null);
  }

  List<Map<String, String?>> _resultats(
    Map<String, String> resultats,
    Map<String, String> commentaires,
  ) => [
    for (final e in resultats.entries)
      {
        'uuid': e.key,
        'resultat': e.value,
        if (commentaires.containsKey(e.key))
          'commentaire': commentaires[e.key]!.isEmpty
              ? null
              : commentaires[e.key],
      },
  ];

  /// L'étiquette du tube (58 mm) : patient, analyses, QR.
  static Future<bool> imprimerEtiquette(DemandeLabo d) async {
    final g = Generator(PaperSize.mm58, await CapabilityProfile.load());
    final s = ImpressionTicket.sansAccents;
    return ImpressionTicket.envoyer([
      ...g.reset(),
      ...g.text(s(d.patient), styles: const PosStyles(bold: true)),
      ...g.text(
        DateFormat('dd/MM/yyyy HH:mm').format(d.date ?? DateTime.now()),
      ),
      if (d.urgent) ...g.text('URGENT', styles: const PosStyles(reverse: true)),
      ...g.text(s(d.lignes.map((l) => l.nom).join(', '))),
      if (d.qr != null) ...g.qrcode(d.qr!, size: QRSize.size4),
      ...g.feed(2),
      ...g.cut(),
    ]);
  }

  DemandeLabo _demande(Object? data) => DemandeLabo.fromJson(
    Map<String, dynamic>.from((data as Map)['demande'] as Map),
  );

  List<Map<String, dynamic>> _liste(Object? data) {
    final d = data is Map ? data['data'] : null;
    return d is List
        ? [for (final m in d.whereType<Map>()) Map<String, dynamic>.from(m)]
        : [];
  }
}
