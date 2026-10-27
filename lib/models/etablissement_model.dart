import '../compte/compte_models.dart';

class EtablissementModel {
  final int id;
  final String nom;
  final String type;
  final String? profil;
  final String? telephone;
  final bool actif;
  final String? adresse;
  final double? latitude;
  final double? longitude;
  final String? itineraireUrl;

  EtablissementModel({
    required this.id,
    required this.nom,
    required this.type,
    this.profil,
    required this.telephone,
    required this.actif,
    required this.adresse,
    this.latitude,
    this.longitude,
    this.itineraireUrl,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  /// « Centre de santé » plutôt que l'ancien type technique.
  String get profilLabel => profil == null || profil!.isEmpty
      ? type
      : ProfilEtablissement.labelDe(profil);

  factory EtablissementModel.fromJson(Map<String, dynamic> json) {
    return EtablissementModel(
      id: _toInt(json['id']) ?? 0,
      nom: (json['nom'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      profil: json['profil']?.toString(),
      telephone: json['telephone']?.toString(),
      actif: _toBool(json['actif']),
      adresse: json['adresse']?.toString(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      itineraireUrl: json['itineraire_url']?.toString(),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    return value?.toString().toLowerCase() == 'true';
  }
}
