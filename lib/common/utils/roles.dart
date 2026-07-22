/// Rôles utilisateur KENEYA (miroir de App\Enums\Role côté backend).
///
/// Deux niveaux d'administration :
///  - [admin]              : administrateur de l'instance (toute la plateforme).
///  - [adminEtablissement] : administrateur de SON établissement uniquement.
/// Les autres rôles sont opérationnels (aucune action d'administration).
class AppRoles {
  const AppRoles._();

  static const String admin = 'admin';
  static const String adminEtablissement = 'admin_etablissement';
  static const String medecin = 'medecin';
  static const String infirmier = 'infirmier';
  static const String sageFemme = 'sage_femme';
  static const String pharmacien = 'pharmacien';
  static const String laborantin = 'laborantin';
  static const String caissier = 'caissier';
  static const String gestionnaire = 'gestionnaire';

  /// Tous les rôles connus.
  static const List<String> all = [
    admin,
    adminEtablissement,
    medecin,
    infirmier,
    sageFemme,
    pharmacien,
    laborantin,
    caissier,
    gestionnaire,
  ];

  /// Administrateur de l'instance (peut gérer plusieurs établissements).
  static bool isInstanceAdmin(String? role) => role == admin;

  /// Peut administrer son établissement : gérer les utilisateurs, régler
  /// l'établissement, voir les statistiques. (admin OU admin d'établissement)
  static bool canAdministerEtablissement(String? role) =>
      role == admin || role == adminEtablissement;

  /// Rôles qu'un utilisateur peut attribuer via le formulaire d'ajout :
  /// l'admin d'instance peut tout attribuer ; l'admin d'établissement, tout
  /// sauf le rôle d'admin d'instance (pas d'escalade de privilège).
  static List<String> assignableBy(String? role) => isInstanceAdmin(role)
      ? List<String>.from(all)
      : all.where((r) => r != admin).toList();

  static const Map<String, String> labels = {
    admin: 'Administrateur',
    adminEtablissement: "Admin d'établissement",
    medecin: 'Médecin',
    infirmier: 'Infirmier',
    sageFemme: 'Sage-femme',
    pharmacien: 'Pharmacien',
    laborantin: 'Laborantin',
    caissier: 'Caissier',
    gestionnaire: 'Gestionnaire',
  };

  static String labelOf(String? role) =>
      labels[role] ?? (role == null || role.isEmpty ? 'Utilisateur' : role);
}
