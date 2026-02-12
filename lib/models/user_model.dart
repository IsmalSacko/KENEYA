class UserModel {
  final int id;
  final int? etablissementId;
  final String name;
  final String telephone;
  final String role;
  final bool actif;

  UserModel({
    required this.id,
    required this.etablissementId,
    required this.name,
    required this.telephone,
    required this.role,
    required this.actif,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _toInt(json['id']) ?? 0,
      etablissementId: _toInt(json['etablissement_id']),
      name: (json['name'] ?? '').toString(),
      telephone: (json['telephone'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      actif: _toBool(json['actif']),
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
