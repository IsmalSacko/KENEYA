import '../compte/compte_api.dart';

/// La console Ngoni Santé (`/plateforme`), avec le jeton de la personne :
/// réservée à l'équipe Ngoni Santé.
class PlateformeService {
  Future<Map<String, dynamic>> _get(
    String chemin, [
    Map<String, dynamic>? params,
  ]) async {
    final res = await CompteApi.dio.get(chemin, queryParameters: params);
    return Map<String, dynamic>.from(res.data as Map);
  }

  List<Map<String, dynamic>> _liste(Map<String, dynamic> d) => [
    for (final x in (d['data'] as List?) ?? const [])
      if (x is Map) Map<String, dynamic>.from(x),
  ];

  Future<Map<String, dynamic>> tableau() => _get('/plateforme/tableau');

  Future<List<Map<String, dynamic>>> etablissements({
    String q = '',
    String filtre = '',
  }) async => _liste(
    await _get('/plateforme/etablissements', {'q': q, 'filtre': filtre}),
  );

  Future<void> valider(String uuid) =>
      CompteApi.dio.post('/plateforme/etablissements/$uuid/valider');

  Future<void> accorder(
    String uuid, {
    required String formule,
    DateTime? fin,
    String? note,
  }) => CompteApi.dio.post(
    '/plateforme/etablissements/$uuid/abonnement',
    data: {
      'formule': formule,
      'fin': fin?.toIso8601String().substring(0, 10),
      'note': note,
    },
  );

  Future<List<Map<String, dynamic>>> demandes(String statut) async =>
      _liste(await _get('/plateforme/demandes', {'statut': statut}));

  Future<void> approuver(String uuid) =>
      CompteApi.dio.post('/plateforme/demandes/$uuid/approuver');

  Future<void> refuser(String uuid, String motif) => CompteApi.dio.post(
    '/plateforme/demandes/$uuid/refuser',
    data: {'motif': motif},
  );

  Future<Map<String, dynamic>> formules() => _get('/plateforme/formules');

  Future<void> modifierFormule(String code, Map<String, dynamic> donnees) =>
      CompteApi.dio.patch('/plateforme/formules/$code', data: donnees);
}
