import 'package:flutter/material.dart';

import 'kcolors.dart';
import 'roles.dart';

/// Représentation visuelle d'un rôle utilisateur (icône, couleur, libellé).
class RoleUi {
  const RoleUi(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static RoleUi of(String? role) {
    switch (role) {
      case AppRoles.admin:
        return const RoleUi(
          'Administrateur',
          Icons.admin_panel_settings_rounded,
          Kolors.kPrimaryDark,
        );
      case AppRoles.adminEtablissement:
        return const RoleUi(
          "Admin d'établissement",
          Icons.manage_accounts_rounded,
          Kolors.kPrimary,
        );
      case AppRoles.medecin:
        return const RoleUi(
          'Médecin',
          Icons.medical_services_rounded,
          Kolors.kBlue,
        );
      case AppRoles.infirmier:
        return const RoleUi(
          'Infirmier',
          Icons.vaccines_rounded,
          Kolors.kSuccess,
        );
      case AppRoles.sageFemme:
        return const RoleUi(
          'Sage-femme',
          Icons.pregnant_woman_rounded,
          Kolors.kGold,
        );
      case AppRoles.pharmacien:
        return const RoleUi(
          'Pharmacien',
          Icons.local_pharmacy_rounded,
          Kolors.kPrimaryLight,
        );
      case AppRoles.laborantin:
        return const RoleUi(
          'Laborantin',
          Icons.science_rounded,
          Kolors.kBlue,
        );
      case AppRoles.caissier:
        return const RoleUi(
          'Caissier',
          Icons.point_of_sale_rounded,
          Kolors.kWarning,
        );
      case AppRoles.gestionnaire:
        return const RoleUi(
          'Gestionnaire',
          Icons.badge_rounded,
          Kolors.kGray,
        );
      default:
        return RoleUi(
          role == null || role.isEmpty ? 'Utilisateur' : role,
          Icons.person_rounded,
          Kolors.kGray,
        );
    }
  }
}
