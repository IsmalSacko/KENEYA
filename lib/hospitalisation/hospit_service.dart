import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../core/api/api_client.dart';
import '../file/impression_ticket.dart';
import 'hospit_models.dart';

/// L'hospitalisation (jeton du membre).
class HospitService {
  Future<List<Chambre>> chambres() async {
    final res = await ApiClient.dio.get('/hospitalisation/chambres');
    return [for (final m in _liste(res.data)) Chambre.fromJson(m)];
  }

  Future<void> creerChambre(Map<String, dynamic> donnees) async {
    await ApiClient.dio.post('/hospitalisation/chambres', data: donnees);
  }

  Future<void> modifierChambre(String uuid, Map<String, dynamic> d) async {
    await ApiClient.dio.patch('/hospitalisation/chambres/$uuid', data: d);
  }

  /// Les hospitalisés ; [sortis] : ceux qui sont sortis, les derniers d'abord.
  Future<List<Sejour>> sejours({bool sortis = false, String? q}) async {
    final res = await ApiClient.dio.get(
      '/hospitalisation/sejours',
      queryParameters: {
        if (sortis) 'statut': 'sortie',
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    return [for (final m in _liste(res.data)) Sejour.fromJson(m)];
  }

  /// Le séjour en cours du patient de la visite, s'il est déjà hospitalisé.
  Future<Sejour?> sejourDeLaVisite(String visite) async {
    final res = await ApiClient.dio.get('/visites/$visite/hospitalisation');
    final s = (res.data as Map)['sejour'];
    return s is Map ? Sejour.fromJson(Map<String, dynamic>.from(s)) : null;
  }

  /// Admettre sans visite, depuis un lit libre.
  Future<Sejour> admettreDossier(
    String dossier,
    String lit,
    String motif,
  ) async => _s(
    (await ApiClient.dio.post(
      '/hospitalisation/sejours',
      data: {'dossier_uuid': dossier, 'lit_uuid': lit, 'motif': motif},
    )).data,
  );

  Future<Sejour> sejour(String uuid) async =>
      _s((await ApiClient.dio.get('/hospitalisation/sejours/$uuid')).data);

  Future<Sejour> lireBracelet(String qr) async => _s(
    (await ApiClient.dio.post(
      '/hospitalisation/sejours/lire',
      data: {'qr': qr},
    )).data,
  );

  Future<Sejour> admettre(String visite, String lit, String motif) async => _s(
    (await ApiClient.dio.post(
      '/visites/$visite/hospitalisation',
      data: {'lit_uuid': lit, 'motif': motif},
    )).data,
  );

  Future<Sejour> transferer(String uuid, String lit) async => _s(
    (await ApiClient.dio.post(
      '/hospitalisation/sejours/$uuid/transferer',
      data: {'lit_uuid': lit},
    )).data,
  );

  /// La sortie, et ce qu'elle a mis sur la facture (null : pas de prix de nuit).
  Future<(Sejour, FactureNuits?)> sortie(
    String uuid,
    String mode,
    String resume,
  ) async {
    final res = await ApiClient.dio.post(
      '/hospitalisation/sejours/$uuid/sortie',
      data: {'mode_sortie': mode, 'resume': resume},
    );
    final f = (res.data as Map)['facture'];
    return (
      _s(res.data),
      f is Map ? FactureNuits.fromJson(Map<String, dynamic>.from(f)) : null,
    );
  }

  Future<Sejour> annuler(String uuid) async => _s(
    (await ApiClient.dio.post('/hospitalisation/sejours/$uuid/annuler')).data,
  );

  Future<Sejour> prescrire(String uuid, Map<String, dynamic> d) async => _s(
    (await ApiClient.dio.post(
      '/hospitalisation/sejours/$uuid/soins',
      data: d,
    )).data,
  );

  Future<Sejour> arreter(String soin) async => _s(
    (await ApiClient.dio.post('/hospitalisation/soins/$soin/arreter')).data,
  );

  Future<Sejour> administrer(
    String uuid,
    Prise p, {
    required String statut,
    String? bracelet,
    String? commentaire,
  }) async => _s(
    (await ApiClient.dio.post(
      '/hospitalisation/sejours/$uuid/administrations',
      data: {
        'soin_uuid': p.soinUuid,
        'prevue_at': p.prevueAt,
        'statut': statut,
        'bracelet': ?bracelet,
        if (commentaire != null && commentaire.isNotEmpty)
          'commentaire': commentaire,
      },
    )).data,
  );

  Future<Sejour> corrigerPrise(
    String uuid,
    Prise p, {
    required String statut,
    required String motif,
    String? bracelet,
  }) async => _s(
    (await ApiClient.dio.post(
      '/hospitalisation/sejours/$uuid/administrations/corriger',
      data: {
        'soin_uuid': p.soinUuid,
        'prevue_at': p.prevueAt,
        'statut': statut,
        'motif': motif,
        'bracelet': ?bracelet,
      },
    )).data,
  );

  /// Le bracelet (étiquette thermique) : nom, lit, QR.
  static Future<bool> imprimerBracelet(Sejour s) async {
    final g = Generator(PaperSize.mm58, await CapabilityProfile.load());
    final t = ImpressionTicket.sansAccents;
    return ImpressionTicket.envoyer([
      ...g.reset(),
      ...g.text(t(s.patient), styles: const PosStyles(bold: true)),
      if (s.lit != null) ...g.text(t(s.lit!)),
      if (s.allergies != null)
        ...g.text(
          t('ALLERGIE : ${s.allergies}'),
          styles: const PosStyles(reverse: true),
        ),
      ...g.qrcode(s.bracelet, size: QRSize.size4),
      ...g.feed(2),
      ...g.cut(),
    ]);
  }

  Sejour _s(Object? data) => Sejour.fromJson(
    Map<String, dynamic>.from((data as Map)['sejour'] as Map),
  );

  List<Map<String, dynamic>> _liste(Object? data) {
    final d = data is Map ? data['data'] : null;
    return d is List
        ? [for (final m in d.whereType<Map>()) Map<String, dynamic>.from(m)]
        : [];
  }
}
