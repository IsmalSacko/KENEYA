import 'package:flutter/material.dart';

import 'kcolors.dart';

/// Représentation visuelle d'un rôle utilisateur (icône, couleur, libellé).
class RoleUi {
  const RoleUi(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static RoleUi of(String? role) {
    switch (role) {
      case 'admin':
        return const RoleUi(
          'Admin',
          Icons.admin_panel_settings_rounded,
          Kolors.kPrimaryDark,
        );
      case 'medecin':
        return const RoleUi(
          'Médecin',
          Icons.medical_services_rounded,
          Kolors.kBlue,
        );
      case 'pharmacien':
        return const RoleUi(
          'Pharmacien',
          Icons.local_pharmacy_rounded,
          Kolors.kSuccess,
        );
      case 'caissier':
        return const RoleUi(
          'Caissier',
          Icons.point_of_sale_rounded,
          Kolors.kWarning,
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
