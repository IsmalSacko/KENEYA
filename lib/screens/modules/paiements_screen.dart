import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class PaiementsScreen extends StatelessWidget {
  const PaiementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiModuleScreen(
      title: 'Paiements',
      endpoint: '/paiements',
      fields: [
        ModuleField(
          key: 'source_type',
          label: 'Source type',
          type: ModuleFieldType.select,
          required: true,
          options: ['consultation', 'vente_pharmacie'],
        ),
        ModuleField(
          key: 'consultation_id',
          label: 'Consultation',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/consultations',
          relationLabelKey: 'motif',
          visibleWhenKey: 'source_type',
          visibleWhenValue: 'consultation',
        ),
        ModuleField(
          key: 'vente_pharmacie_id',
          label: 'Vente pharmacie',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/ventes-pharmacie',
          relationLabelKey: 'id',
          visibleWhenKey: 'source_type',
          visibleWhenValue: 'vente_pharmacie',
        ),
        ModuleField(
          key: 'montant',
          label: 'Montant',
          type: ModuleFieldType.decimal,
          required: true,
        ),
        ModuleField(
          key: 'mode_paiement',
          label: 'Mode paiement',
          type: ModuleFieldType.select,
          required: true,
          options: ['espece', 'orange', 'wave', 'moov'],
        ),
      ],
    );
  }
}
