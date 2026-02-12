class MedicamentModel {
  final int id;
  final int etablissementId;
  final String nom;
  final int stock;
  final double prixUnitaire;
  final int seuilAlerte;
  final String? dateExpiration;
  final bool actif;

  MedicamentModel({
    required this.id,
    required this.etablissementId,
    required this.nom,
    required this.stock,
    required this.prixUnitaire,
    required this.seuilAlerte,
    required this.dateExpiration,
    required this.actif,
  });

  factory MedicamentModel.fromJson(Map<String, dynamic> json) {
    return MedicamentModel(
      id: _toInt(json['id']) ?? 0,
      etablissementId: _toInt(json['etablissement_id']) ?? 0,
      nom: (json['nom'] ?? '').toString(),
      stock: _toInt(json['stock']) ?? 0,
      prixUnitaire: _toDouble(json['prix_unitaire']) ?? 0,
      seuilAlerte: _toInt(json['seuil_alerte']) ?? 0,
      dateExpiration: json['date_expiration']?.toString(),
      actif: _toBool(json['actif']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    return value?.toString().toLowerCase() == 'true';
  }
}
