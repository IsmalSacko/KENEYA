import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class VentesPharmacieScreen extends StatelessWidget {
  const VentesPharmacieScreen({
    super.key,
    this.allowCreate = true,
    this.allowUpdate = false,
    this.allowDelete = true,
  });

  final bool allowCreate;
  final bool allowUpdate;
  final bool allowDelete;

  @override
  Widget build(BuildContext context) {
    return ApiModuleScreen(
      title: 'Ventes Pharmacie',
      endpoint: '/ventes-pharmacie',
      allowCreate: allowCreate,
      allowUpdate: allowUpdate,
      allowDelete: allowDelete,
      fields: [
        ModuleField(
          key: 'type_client',
          label: 'Type de client',
          type: ModuleFieldType.select,
          required: true,
          options: ['passage', 'enregistre', 'nouveau'],
          optionLabels: {
            'passage': 'Client de passage',
            'enregistre': 'Patient existant',
            'nouveau': 'Nouveau client',
          },
        ),
        ModuleField(
          key: 'patient_id',
          label: 'Patient',
          type: ModuleFieldType.relation,
          relationEndpoint: '/patients',
          relationLabelKey: 'nom',
          relationSubtitleKey: 'telephone',
          visibleWhenKey: 'type_client',
          visibleWhenValue: 'enregistre',
        ),
        ModuleField(
          key: 'patient_nom',
          label: 'Nom du client',
          type: ModuleFieldType.text,
          required: true,
          visibleWhenKey: 'type_client',
          visibleWhenValue: 'nouveau',
        ),
        ModuleField(
          key: 'patient_telephone',
          label: 'Telephone (optionnel)',
          type: ModuleFieldType.text,
          visibleWhenKey: 'type_client',
          visibleWhenValue: 'nouveau',
        ),
        ModuleField(
          key: 'patient_adresse',
          label: 'Adresse (optionnel)',
          type: ModuleFieldType.text,
          visibleWhenKey: 'type_client',
          visibleWhenValue: 'nouveau',
        ),
        ModuleField(
          key: 'mode_paiement',
          label: 'Mode paiement',
          type: ModuleFieldType.select,
          required: true,
          options: ['espece', 'orange', 'wave', 'moov'],
          optionLabels: {
            'espece': 'Especes',
            'orange': 'Orange Money',
            'wave': 'Wave',
            'moov': 'Moov Money',
          },
        ),
        ModuleField(
          key: 'article_medicament_id',
          label: 'Medicament',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/medicaments',
          relationLabelKey: 'nom',
          emptyOptionsHint:
              'Aucun medicament disponible. Verifiez le stock de votre etablissement.',
        ),
        ModuleField(
          key: 'article_quantite',
          label: 'Quantite (article)',
          type: ModuleFieldType.number,
          required: true,
          minValue: 1,
        ),
      ],
    );
  }
}
