import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class PaiementsScreen extends StatelessWidget {
  const PaiementsScreen({
    super.key,
    this.hasCabinet = true,
    this.hasPharmacie = true,
    this.allowCreate = true,
    this.allowUpdate = true,
    this.allowDelete = true,
  });

  final bool hasCabinet;
  final bool hasPharmacie;
  final bool allowCreate;
  final bool allowUpdate;
  final bool allowDelete;

  @override
  Widget build(BuildContext context) {
    final sourceOptions = [
      if (hasCabinet) 'consultation',
      if (hasPharmacie) 'vente_pharmacie',
    ];

    return ApiModuleScreen(
      title: 'Paiements',
      endpoint: '/paiements',
      allowCreate: allowCreate,
      allowUpdate: allowUpdate,
      allowDelete: allowDelete,
      fields: [
        ModuleField(
          key: 'source_type',
          label: 'Type de paiement',
          type: ModuleFieldType.select,
          required: true,
          options: sourceOptions,
          optionLabels: const {
            'consultation': 'Consultation',
            'vente_pharmacie': 'Vente pharmacie',
          },
        ),
        ModuleField(
          key: 'consultation_id',
          label: 'Consultation',
          type: ModuleFieldType.relation,
          required: hasCabinet,
          relationEndpoint: '/consultations',
          relationLabelKey: 'motif',
          relationSubtitleKey: 'montant',
          visibleWhenKey: 'source_type',
          visibleWhenValue: 'consultation',
          emptyOptionsHint: 'Aucune consultation disponible pour paiement.',
        ),
        ModuleField(
          key: 'vente_pharmacie_id',
          label: 'Vente pharmacie',
          type: ModuleFieldType.relation,
          required: hasPharmacie,
          relationEndpoint: '/ventes-pharmacie',
          relationLabelKey: 'id',
          relationSubtitleKey: 'mode_paiement',
          visibleWhenKey: 'source_type',
          visibleWhenValue: 'vente_pharmacie',
          emptyOptionsHint: 'Aucune vente pharmacie disponible pour paiement.',
        ),
        ModuleField(
          key: 'montant',
          label: 'Montant',
          type: ModuleFieldType.decimal,
          required: true,
          minValue: 0.01,
        ),
        ModuleField(
          key: 'mode_paiement',
          label: 'Mode paiement',
          type: ModuleFieldType.select,
          required: true,
          options: ['espece', 'orange', 'wave', 'moov'],
          optionLabels: const {
            'espece': 'Especes',
            'orange': 'Orange Money',
            'wave': 'Wave',
            'moov': 'Moov Money',
          },
        ),
      ],
    );
  }
}
