import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class EtablissementsScreen extends StatelessWidget {
  const EtablissementsScreen({
    super.key,
    this.allowCreate = false,
    this.allowUpdate = true,
    this.allowDelete = true,
  });

  final bool allowCreate;
  final bool allowUpdate;
  final bool allowDelete;

  @override
  Widget build(BuildContext context) {
    return ApiModuleScreen(
      title: 'Etablissements',
      endpoint: '/etablissements',
      allowCreate: allowCreate,
      allowUpdate: allowUpdate,
      allowDelete: allowDelete,
      fields: [
        ModuleField(key: 'nom', label: 'Nom', type: ModuleFieldType.text),
        ModuleField(
          key: 'type',
          label: 'Type',
          type: ModuleFieldType.select,
          options: ['cabinet', 'pharmacie', 'cabinet_pharmacie'],
          optionLabels: {
            'cabinet': 'Cabinet',
            'pharmacie': 'Pharmacie',
            'cabinet_pharmacie': 'Cabinet + Pharmacie',
          },
        ),
        ModuleField(
          key: 'telephone',
          label: 'Telephone',
          type: ModuleFieldType.text,
        ),
        ModuleField(
          key: 'adresse',
          label: 'Adresse',
          type: ModuleFieldType.text,
        ),
        ModuleField(
          key: 'latitude',
          label: 'Latitude',
          type: ModuleFieldType.decimal,
          minValue: -90,
          maxValue: 90,
        ),
        ModuleField(
          key: 'longitude',
          label: 'Longitude',
          type: ModuleFieldType.decimal,
          minValue: -180,
          maxValue: 180,
        ),
        ModuleField(
          key: 'actif',
          label: 'Actif',
          type: ModuleFieldType.boolean,
        ),
      ],
    );
  }
}
