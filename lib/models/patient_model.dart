class PatientModel {
  final int id;
  final int etablissementId;
  final String nom;
  final String? telephone;
  final String? adresse;

  PatientModel({
    required this.id,
    required this.etablissementId,
    required this.nom,
    required this.telephone,
    required this.adresse,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: _toInt(json['id']) ?? 0,
      etablissementId: _toInt(json['etablissement_id']) ?? 0,
      nom: (json['nom'] ?? '').toString(),
      telephone: json['telephone']?.toString(),
      adresse: json['adresse']?.toString(),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
