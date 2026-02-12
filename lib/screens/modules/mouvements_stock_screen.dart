import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class MouvementsStockScreen extends StatelessWidget {
  const MouvementsStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiModuleScreen(
      title: 'Mouvements Stock',
      endpoint: '/mouvement-stocks',
      fields: [
        ModuleField(
          key: 'medicament_id',
          label: 'Medicament',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/medicaments',
          relationLabelKey: 'nom',
        ),
        ModuleField(
          key: 'type',
          label: 'Type',
          type: ModuleFieldType.select,
          required: true,
          options: ['entree', 'sortie', 'ajustement'],
        ),
        ModuleField(
          key: 'quantite',
          label: 'Quantite',
          type: ModuleFieldType.number,
          required: true,
        ),
        ModuleField(
          key: 'commentaire',
          label: 'Commentaire',
          type: ModuleFieldType.text,
        ),
      ],
    );
  }
}
