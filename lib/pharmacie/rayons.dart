import '../core/api/api_client.dart';

/// Les catégories (rayons) de la pharmacie de l'établissement ouvert. Celles
/// de départ tant que le serveur n'a pas répondu (ou hors ligne).
class Rayons {
  Rayons._();

  static const _depart = {
    'medicaments': 'Médicaments',
    'contraception': 'Contraception',
    'bebe': 'Bébé',
    'hygiene_beaute': 'Hygiène et beauté',
    'materiel_medical': 'Matériel médical',
    'complements': 'Compléments',
    'autres': 'Autres',
  };

  static Map<String, String> noms = Map.of(_depart);

  static Future<void> charger() async {
    try {
      final res = await ApiClient.dio.get('/pharmacie/rayons');
      _lire(res.data);
    } catch (_) {
      // Hors ligne : on garde les dernières connues.
    }
  }

  /// La liste entière, dans l'ordre ; un code null est une nouvelle catégorie.
  static Future<void> enregistrer(List<(String?, String)> liste) async {
    final res = await ApiClient.dio.put(
      '/pharmacie/rayons',
      data: {
        'rayons': [
          for (final (code, nom) in liste) {'code': code, 'nom': nom},
        ],
      },
    );
    _lire(res.data);
  }

  /// Ajoute une catégorie et renvoie son code.
  static Future<String?> ajouter(String nom) async {
    await enregistrer([
      for (final e in noms.entries) (e.key, e.value),
      (null, nom),
    ]);
    return noms.entries
        .where((e) => e.value.toLowerCase() == nom.trim().toLowerCase())
        .map((e) => e.key)
        .firstOrNull;
  }

  static void _lire(dynamic data) {
    final d = data is Map ? data['data'] : null;
    if (d is! List || d.isEmpty) return;
    noms = {for (final r in d.whereType<Map>()) '${r['code']}': '${r['nom']}'};
  }
}
