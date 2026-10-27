class Etablissement {
  Etablissement({
    required this.uuid,
    required this.nom,
    required this.type,
    this.profilLabel,
    this.modules = const [],
    this.telephone,
    this.adresse,
    this.latitude,
    this.longitude,
    this.itineraireUrl,
    this.distanceKm,
  });

  final String uuid;
  final String nom;
  final String type;
  final String? profilLabel;
  final List<String> modules;

  /// L'établissement a une file d'attente : on peut y prendre un ticket.
  bool get aFile => modules.contains('file');
  final String? telephone;
  final String? adresse;
  final double? latitude;
  final double? longitude;
  final String? itineraireUrl;
  final double? distanceKm;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get typeLabel =>
      profilLabel ??
      switch (type) {
        'pharmacie' => 'Pharmacie',
        'cabinet' => 'Cabinet médical',
        'cabinet_pharmacie' => 'Cabinet + Pharmacie',
        _ => type,
      };

  factory Etablissement.fromJson(Map<String, dynamic> j) {
    return Etablissement(
      uuid: (j['uuid'] ?? '').toString(),
      nom: (j['nom'] ?? '').toString(),
      type: (j['type'] ?? '').toString(),
      profilLabel: j['profil_label']?.toString(),
      modules: j['modules'] is List
          ? (j['modules'] as List).map((m) => m.toString()).toList()
          : const [],
      telephone: j['telephone']?.toString(),
      adresse: j['adresse']?.toString(),
      latitude: _toDouble(j['latitude']),
      longitude: _toDouble(j['longitude']),
      itineraireUrl: j['itineraire_url']?.toString(),
      distanceKm: _toDouble(j['distance_km']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
