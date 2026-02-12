import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class MedicamentsScreen extends StatelessWidget {
  const MedicamentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiModuleScreen(
      title: 'Medicaments',
      endpoint: '/medicaments',
      fields: [
        ModuleField(
          key: 'nom',
          label: 'Nom',
          type: ModuleFieldType.text,
          required: true,
        ),
        ModuleField(key: 'stock', label: 'Stock', type: ModuleFieldType.number),
        ModuleField(
          key: 'prix_unitaire',
          label: 'Prix unitaire',
          type: ModuleFieldType.decimal,
          required: true,
        ),
        ModuleField(
          key: 'seuil_alerte',
          label: 'Seuil alerte',
          type: ModuleFieldType.number,
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
