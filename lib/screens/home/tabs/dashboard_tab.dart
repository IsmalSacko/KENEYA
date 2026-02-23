import 'dart:async';
import 'package:flutter/material.dart';
import 'package:keneya_plus/controllers/auth_controller.dart';
import 'package:keneya_plus/controllers/etablissement_controller.dart';
import 'package:keneya_plus/controllers/medicament_controller.dart';
import 'package:keneya_plus/controllers/patient_controller.dart';
import 'package:keneya_plus/controllers/user_controller.dart';
import 'package:keneya_plus/screens/home/widgets/section_card.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.auth,
    required this.patientCtrl,
    required this.medicamentCtrl,
    required this.etablissementCtrl,
    required this.userCtrl,
    required this.onRefresh,
  });

  final AuthController auth;
  final PatientController patientCtrl;
  final MedicamentController medicamentCtrl;
  final EtablissementController etablissementCtrl;
  final UserController userCtrl;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final cardWidth = wide
              ? (constraints.maxWidth - 48) / 2
              : constraints.maxWidth;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Bienvenue ${auth.currentUser?.name ?? ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: SectionCard(
                      title: 'Patients',
                      loading: patientCtrl.loading,
                      error: patientCtrl.error,
                      emptyMessage: 'Aucun patient.',
                      children: patientCtrl.patients
                          .take(5)
                          .map(
                            (p) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.nom),
                              subtitle: Text(p.telephone ?? '-'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: SectionCard(
                      title: 'Medicaments',
                      loading: medicamentCtrl.loading,
                      error: medicamentCtrl.error,
                      emptyMessage: 'Aucun medicament.',
                      children: medicamentCtrl.medicaments
                          .take(5)
                          .map(
                            (m) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(m.nom),
                              subtitle: Text(
                                'Stock: ${m.stock} | Prix: ${m.prixUnitaire}',
                              ),
                              trailing: m.stock <= m.seuilAlerte
                                  ? const Icon(
                                      Icons.warning_amber,
                                      color: Colors.orange,
                                    )
                                  : null,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: SectionCard(
                      title: 'Etablissements',
                      loading: etablissementCtrl.loading,
                      error: etablissementCtrl.error,
                      emptyMessage: 'Aucun etablissement.',
                      children: etablissementCtrl.etablissements
                          .take(5)
                          .map(
                            (e) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.nom),
                              subtitle: Text(
                                '${e.type} | ${e.telephone ?? '-'}',
                              ),
                              trailing: Icon(
                                e.actif ? Icons.check_circle : Icons.cancel,
                                color: e.actif ? Colors.green : Colors.red,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: SectionCard(
                      title: 'Utilisateurs',
                      loading: userCtrl.loading,
                      error: userCtrl.error,
                      emptyMessage: 'Aucun utilisateur.',
                      children: userCtrl.users
                          .take(5)
                          .map(
                            (u) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(u.name),
                              subtitle: Text('${u.role} | ${u.telephone}'),
                              trailing: Icon(
                                u.actif ? Icons.check_circle : Icons.cancel,
                                color: u.actif ? Colors.green : Colors.red,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
