import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class EtablissementsScreen extends StatelessWidget {
  const EtablissementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiModuleScreen(
      title: 'Etablissements',
      endpoint: '/etablissements',
      allowCreate: false,
      fields: [
        ModuleField(key: 'nom', label: 'Nom', type: ModuleFieldType.text),
        ModuleField(
          key: 'type',
          label: 'Type',
          type: ModuleFieldType.select,
          options: ['cabinet', 'pharmacie', 'cabinet_pharmacie'],
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
          key: 'actif',
          label: 'Actif',
          type: ModuleFieldType.boolean,
        ),
      ],
    );
  }
}
