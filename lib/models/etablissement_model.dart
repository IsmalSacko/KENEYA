class EtablissementModel {
  final int id;
  final String nom;
  final String type;
  final String? telephone;
  final bool actif;
  final String? adresse;

  EtablissementModel({
    required this.id,
    required this.nom,
    required this.type,
    required this.telephone,
    required this.actif,
    required this.adresse,
  });

  factory EtablissementModel.fromJson(Map<String, dynamic> json) {
    return EtablissementModel(
      id: _toInt(json['id']) ?? 0,
      nom: (json['nom'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      telephone: json['telephone']?.toString(),
      actif: _toBool(json['actif']),
      adresse: json['adresse']?.toString(),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    return value?.toString().toLowerCase() == 'true';
  }
}
