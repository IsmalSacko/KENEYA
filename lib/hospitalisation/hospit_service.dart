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

  Future<List<Sejour>> sejours() async {
    final res = await ApiClient.dio.get('/hospitalisation/sejours');
    return [for (final m in _liste(res.data)) Sejour.fromJson(m)];
  }

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

  Future<Sejour> sortie(String uuid, String mode, String resume) async => _s(
    (await ApiClient.dio.post(
      '/hospitalisation/sejours/$uuid/sortie',
      data: {'mode_sortie': mode, 'resume': resume},
    )).data,
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
