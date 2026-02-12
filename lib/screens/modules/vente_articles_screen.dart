import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class VenteArticlesScreen extends StatelessWidget {
  const VenteArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiModuleScreen(
      title: 'Articles Vente',
      endpoint: '/vente-pharmacie-articles',
      fields: [
        ModuleField(
          key: 'vente_pharmacie_id',
          label: 'Vente pharmacie',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/ventes-pharmacie',
          relationLabelKey: 'id',
        ),
        ModuleField(
          key: 'medicament_id',
          label: 'Medicament',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/medicaments',
          relationLabelKey: 'nom',
        ),
        ModuleField(
          key: 'quantite',
          label: 'Quantite',
          type: ModuleFieldType.number,
          required: true,
        ),
      ],
    );
  }
}
