import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class ConsultationsScreen extends StatelessWidget {
  const ConsultationsScreen({
    super.key,
    this.allowCreate = true,
    this.allowUpdate = true,
    this.allowDelete = true,
  });

  final bool allowCreate;
  final bool allowUpdate;
  final bool allowDelete;

  @override
  Widget build(BuildContext context) {
    return ApiModuleScreen(
      title: 'Consultations',
      endpoint: '/consultations',
      allowCreate: allowCreate,
      allowUpdate: allowUpdate,
      allowDelete: allowDelete,
      fields: [
        ModuleField(
          key: 'patient_id',
          label: 'Patient',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/patients',
          relationLabelKey: 'nom',
          relationSubtitleKey: 'telephone',
          emptyOptionsHint: 'Ajoutez d abord un patient.',
        ),
        ModuleField(
          key: 'medecin_id',
          label: 'Medecin',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/etablissements/users',
          relationLabelKey: 'name',
          relationSubtitleKey: 'telephone',
          relationFilterKey: 'role',
          relationFilterValue: 'medecin',
          emptyOptionsHint: 'Aucun medecin disponible dans cet etablissement.',
        ),
        ModuleField(
          key: 'motif',
          label: 'Motif',
          type: ModuleFieldType.text,
          required: true,
        ),
        ModuleField(
          key: 'montant',
          label: 'Montant',
          type: ModuleFieldType.decimal,
          required: true,
          minValue: 0,
        ),
        ModuleField(
          key: 'statut',
          label: 'Statut',
          type: ModuleFieldType.select,
          options: ['en_attente', 'payee'],
          optionLabels: {'en_attente': 'En attente', 'payee': 'Payee'},
        ),
      ],
    );
  }
}
