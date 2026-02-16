import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class VenteArticlesScreen extends StatelessWidget {
  const VenteArticlesScreen({
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
      title: 'Articles Vente',
      endpoint: '/vente-pharmacie-articles',
      allowCreate: allowCreate,
      allowUpdate: allowUpdate,
      allowDelete: allowDelete,
      fields: [
        ModuleField(
          key: 'vente_pharmacie_id',
          label: 'Vente pharmacie',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/ventes-pharmacie',
          relationLabelKey: 'id',
          emptyOptionsHint: 'Aucune vente disponible. Creez une vente d abord.',
        ),
        ModuleField(
          key: 'medicament_id',
          label: 'Medicament',
          type: ModuleFieldType.relation,
          required: true,
          relationEndpoint: '/medicaments',
          relationLabelKey: 'nom',
          emptyOptionsHint:
              'Aucun medicament disponible dans votre etablissement.',
        ),
        ModuleField(
          key: 'quantite',
          label: 'Quantite',
          type: ModuleFieldType.number,
          required: true,
          minValue: 1,
        ),
      ],
    );
  }
}
