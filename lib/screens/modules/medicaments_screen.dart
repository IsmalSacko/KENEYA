import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class MedicamentsScreen extends StatelessWidget {
  const MedicamentsScreen({
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
      title: 'Medicaments',
      endpoint: '/medicaments',
      allowCreate: allowCreate,
      allowUpdate: allowUpdate,
      allowDelete: allowDelete,
      fields: [
        ModuleField(
          key: 'nom',
          label: 'Nom',
          type: ModuleFieldType.text,
          required: true,
        ),
        ModuleField(
          key: 'stock',
          label: 'Stock',
          type: ModuleFieldType.number,
          minValue: 0,
        ),
        ModuleField(
          key: 'prix_unitaire',
          label: 'Prix unitaire',
          type: ModuleFieldType.decimal,
          required: true,
          minValue: 0,
        ),
        ModuleField(
          key: 'seuil_alerte',
          label: 'Seuil alerte',
          type: ModuleFieldType.number,
          minValue: 0,
        ),
        ModuleField(
          key: 'date_expiration',
          label: 'Date expiration (YYYY-MM-DD)',
          type: ModuleFieldType.date,
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
