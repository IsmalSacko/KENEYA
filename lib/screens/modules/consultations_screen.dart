import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class ConsultationsScreen extends StatelessWidget {
  const ConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiModuleScreen(
      title: 'Consultations',
      endpoint: '/consultations',
      fields: [
        ModuleField(
          key: 'patient_id',
          label: 'Patient',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/patients',
          relationLabelKey: 'nom',
          relationSubtitleKey: 'telephone',
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
        ),
        ModuleField(
          key: 'statut',
          label: 'Statut',
          type: ModuleFieldType.select,
          options: ['en_attente', 'payee'],
        ),
      ],
    );
  }
}
