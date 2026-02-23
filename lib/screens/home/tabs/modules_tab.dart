import 'package:flutter/material.dart';
import 'package:keneya_plus/controllers/auth_controller.dart';
import 'package:keneya_plus/controllers/etablissement_controller.dart';
import 'package:keneya_plus/screens/home/widgets/module_card.dart';
import 'package:keneya_plus/screens/modules/consultations_screen.dart';
import 'package:keneya_plus/screens/modules/etablissements_screen.dart';
import 'package:keneya_plus/screens/modules/journal_audits_screen.dart';
import 'package:keneya_plus/screens/modules/medicaments_screen.dart';
import 'package:keneya_plus/screens/modules/mouvements_stock_screen.dart';
import 'package:keneya_plus/screens/modules/paiements_screen.dart';
import 'package:keneya_plus/screens/modules/vente_articles_screen.dart';
import 'package:keneya_plus/screens/modules/ventes_pharmacie_screen.dart';
import 'package:provider/provider.dart';

class ModulesTab extends StatelessWidget {
  const ModulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context
        .watch<AuthController>()
        .currentUser
        ?.role
        .toLowerCase();
    final etablissementTypes = context
        .watch<EtablissementController>()
        .etablissements
        .map((e) => e.type.toLowerCase())
        .toSet();
    final hasTypeInfo = etablissementTypes.isNotEmpty;
    final hasCabinet =
        !hasTypeInfo ||
        etablissementTypes.any(
          (type) => type == 'cabinet' || type == 'cabinet_pharmacie',
        );
    final hasPharmacie =
        !hasTypeInfo ||
        etablissementTypes.any(
          (type) => type == 'pharmacie' || type == 'cabinet_pharmacie',
        );
    final isAdmin = role == 'admin';
    final isMedecin = role == 'medecin';
    final isPharmacien = role == 'pharmacien';
    final isCaissier = role == 'caissier';
    final enforceRoleFilter = const {
      'admin',
      'medecin',
      'pharmacien',
      'caissier',
    }.contains(role);

    final modules = <_ModuleItem>[
      _ModuleItem(
        title: 'Consultations',
        subtitle: 'Suivi des consultations medicales',
        icon: Icons.medical_information_outlined,
        allowedRoles: const {'admin', 'medecin', 'caissier'},
        requiresCabinet: true,
        builder: (_) => ConsultationsScreen(
          allowCreate: isAdmin || isMedecin || isCaissier,
          allowUpdate: isAdmin || isMedecin,
          allowDelete: isAdmin,
        ),
      ),
      _ModuleItem(
        title: 'Medicaments',
        subtitle: 'Catalogue et suivi des stocks',
        icon: Icons.medication_outlined,
        allowedRoles: const {'admin', 'medecin', 'pharmacien', 'caissier'},
        requiresPharmacie: true,
        builder: (_) => MedicamentsScreen(
          allowCreate: isAdmin || isPharmacien,
          allowUpdate: isAdmin || isPharmacien,
          allowDelete: isAdmin,
        ),
      ),
      _ModuleItem(
        title: 'Mouvements Stock',
        subtitle: 'Entrees, sorties et ajustements',
        icon: Icons.inventory_2_outlined,
        allowedRoles: const {'admin', 'pharmacien', 'caissier'},
        requiresPharmacie: true,
        builder: (_) => MouvementsStockScreen(
          allowCreate: isAdmin || isPharmacien || isCaissier,
          allowUpdate: isAdmin || isPharmacien,
          allowDelete: isAdmin || isPharmacien,
        ),
      ),
      _ModuleItem(
        title: 'Paiements',
        subtitle: 'Reglement consultations et ventes',
        icon: Icons.payments_outlined,
        allowedRoles: const {'admin', 'pharmacien', 'caissier'},
        builder: (_) => PaiementsScreen(
          hasCabinet: hasCabinet,
          hasPharmacie: hasPharmacie,
          allowCreate: isAdmin || isPharmacien || isCaissier,
          allowUpdate: isAdmin,
          allowDelete: isAdmin,
        ),
      ),
      _ModuleItem(
        title: 'Ventes Pharmacie',
        subtitle: 'Operations de vente pharmacie',
        icon: Icons.point_of_sale_outlined,
        allowedRoles: const {'admin', 'pharmacien', 'caissier'},
        requiresPharmacie: true,
        builder: (_) => VentesPharmacieScreen(
          allowCreate: isAdmin || isPharmacien || isCaissier,
          allowDelete: isAdmin || isPharmacien,
        ),
      ),
      _ModuleItem(
        title: 'Articles Vente',
        subtitle: 'Lignes detaillees de vente',
        icon: Icons.receipt_long_outlined,
        allowedRoles: const {'admin', 'pharmacien', 'caissier'},
        requiresPharmacie: true,
        builder: (_) => VenteArticlesScreen(
          allowCreate: isAdmin || isPharmacien || isCaissier,
          allowUpdate: isAdmin || isPharmacien,
          allowDelete: isAdmin || isPharmacien,
        ),
      ),
      _ModuleItem(
        title: 'Journal Audits',
        subtitle: 'Historique des actions',
        icon: Icons.history_outlined,
        allowedRoles: const {'admin'},
        builder: (_) => JournalAuditsScreen(allowDelete: isAdmin),
      ),
      _ModuleItem(
        title: 'Etablissements',
        subtitle: 'Gestion des structures',
        icon: Icons.local_hospital_outlined,
        allowedRoles: const {'admin'},
        builder: (_) =>
            EtablissementsScreen(allowUpdate: isAdmin, allowDelete: isAdmin),
      ),
    ];
    final visibleModules = modules.where((module) {
      if (enforceRoleFilter && !module.allowedRoles.contains(role)) {
        return false;
      }
      if (module.requiresCabinet && !hasCabinet) {
        return false;
      }
      if (module.requiresPharmacie && !hasPharmacie) {
        return false;
      }
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1200
            ? 4
            : width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1;
        if (visibleModules.isEmpty) {
          return const Center(
            child: Text('Aucun module disponible pour ce profil.'),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: width >= 900 ? 1.55 : 1.30,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: visibleModules.length,
          itemBuilder: (context, index) {
            final module = visibleModules[index];
            return ModuleCard(
              title: module.title,
              subtitle: module.subtitle,
              icon: module.icon,
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: module.builder));
              },
            );
          },
        );
      },
    );
  }
}

class _ModuleItem {
  const _ModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    this.allowedRoles = const {'admin', 'medecin', 'pharmacien', 'caissier'},
    this.requiresCabinet = false,
    this.requiresPharmacie = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
  final Set<String> allowedRoles;
  final bool requiresCabinet;
  final bool requiresPharmacie;
}
