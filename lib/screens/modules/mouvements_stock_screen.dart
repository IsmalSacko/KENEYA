import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class MouvementsStockScreen extends StatelessWidget {
  const MouvementsStockScreen({
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
      title: 'Mouvements Stock',
      endpoint: '/mouvement-stocks',
      allowCreate: allowCreate,
      allowUpdate: allowUpdate,
      allowDelete: allowDelete,
      fields: [
        ModuleField(
          key: 'medicament_id',
          label: 'Medicament',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/medicaments',
          relationLabelKey: 'nom',
          emptyOptionsHint:
              'Aucun medicament. Creez un medicament avant un mouvement.',
        ),
        ModuleField(
          key: 'type',
          label: 'Type',
          type: ModuleFieldType.select,
          required: true,
          options: ['entree', 'sortie', 'ajustement'],
          optionLabels: {
            'entree': 'Entree stock',
            'sortie': 'Sortie stock',
            'ajustement': 'Ajustement',
          },
        ),
        ModuleField(
          key: 'quantite',
          label: 'Quantite',
          type: ModuleFieldType.number,
          required: true,
          minValue: 1,
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
