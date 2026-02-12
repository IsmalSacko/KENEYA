import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class VentesPharmacieScreen extends StatelessWidget {
  const VentesPharmacieScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiModuleScreen(
      title: 'Ventes Pharmacie',
      endpoint: '/ventes-pharmacie',
      allowUpdate: false,
      fields: [
        ModuleField(
          key: 'patient_id',
          label: 'Patient (optionnel)',
          type: ModuleFieldType.relation,
          relationEndpoint: '/patients',
          relationLabelKey: 'nom',
          relationSubtitleKey: 'telephone',
        ),
        ModuleField(
          key: 'mode_paiement',
          label: 'Mode paiement',
          type: ModuleFieldType.select,
          required: true,
          options: ['espece', 'orange', 'wave', 'moov'],
        ),
        ModuleField(
          key: 'statut_sync',
          label: 'Statut sync',
          type: ModuleFieldType.select,
          options: ['en_attente', 'synchronise'],
        ),
        ModuleField(
          key: 'article_medicament_id',
          label: 'Medicament',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/medicaments',
          relationLabelKey: 'nom',
        ),
        ModuleField(
          key: 'article_quantite',
          label: 'Quantite (article)',
          type: ModuleFieldType.number,
          required: true,
        ),
      ],
    );
  }
}
