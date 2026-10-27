import '../core/api/api_client.dart';

/// Un membre et son badge.
class BadgeMembre {
  const BadgeMembre({
    required this.uuid,
    required this.nom,
    required this.role,
    required this.badge,
  });

  final String uuid;
  final String nom;
  final String role;
  final String badge;

  factory BadgeMembre.fromJson(Map<String, dynamic> j) => BadgeMembre(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    role: (j['role'] ?? '').toString(),
    badge: (j['badge'] ?? '').toString(),
  );
}

/// Un visiteur présent.
class VisiteurPresent {
  const VisiteurPresent({
    required this.uuid,
    required this.nom,
    required this.qr,
    this.patient,
    this.lit,
    this.entree,
  });

  final String uuid;
  final String nom;
  final String qr;
  final String? patient;
  final String? lit;
  final DateTime? entree;

  factory VisiteurPresent.fromJson(Map<String, dynamic> j) => VisiteurPresent(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    qr: (j['qr'] ?? '').toString(),
    patient: j['patient']?.toString(),
    lit: j['lit']?.toString(),
    entree: DateTime.tryParse('${j['entree_at']}')?.toLocal(),
  );
}

/// Pointage du personnel, badges et visiteurs (jeton du membre).
class PresenceService {
  Future<List<BadgeMembre>> badges() async => [
    for (final m in await _donnees('/badges')) BadgeMembre.fromJson(m),
  ];

  Future<BadgeMembre> renouveler(String uuid) async {
    final res = await ApiClient.dio.post('/badges/$uuid/renouveler');
    return BadgeMembre.fromJson(
      Map<String, dynamic>.from((res.data as Map)['membre'] as Map),
    );
  }

  /// Le badge scanné : « arrivee » ou « depart », avec le nom.
  Future<Map<String, dynamic>> pointer(String qr) async {
    final res = await ApiClient.dio.post('/pointages', data: {'qr': qr});
    return Map<String, dynamic>.from((res.data as Map)['pointage'] as Map);
  }

  Future<List<Map<String, dynamic>>> presents() =>
      _donnees('/pointages/presents');

  Future<List<Map<String, dynamic>>> rapport(String mois) =>
      _donnees('/pointages/rapport', {'mois': mois});

  Future<List<VisiteurPresent>> visiteurs() async => [
    for (final m in await _donnees('/visiteurs')) VisiteurPresent.fromJson(m),
  ];

  /// Les patients hospitalisés qu'on peut visiter (nom, lit).
  Future<List<Map<String, dynamic>>> patients() =>
      _donnees('/visiteurs/patients');

  Future<VisiteurPresent> entrer(Map<String, dynamic> donnees) async {
    final res = await ApiClient.dio.post('/visiteurs', data: donnees);
    return VisiteurPresent.fromJson(
      Map<String, dynamic>.from((res.data as Map)['visiteur'] as Map),
    );
  }

  Future<void> sortir({String? qr, String? uuid}) async {
    await ApiClient.dio.post(
      '/visiteurs/sortie',
      data: {'qr': ?qr, 'uuid': ?uuid},
    );
  }

  Future<List<Map<String, dynamic>>> _donnees(
    String chemin, [
    Map<String, dynamic>? query,
  ]) async {
    final res = await ApiClient.dio.get(chemin, queryParameters: query);
    final d = (res.data as Map)['data'];
    return d is List
        ? [for (final m in d.whereType<Map>()) Map<String, dynamic>.from(m)]
        : [];
  }
}
