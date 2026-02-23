import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class JournalAuditsScreen extends StatelessWidget {
  const JournalAuditsScreen({
    super.key,
    this.allowCreate = false,
    this.allowUpdate = false,
    this.allowDelete = false,
  });

  final bool allowCreate;
  final bool allowUpdate;
  final bool allowDelete;

  @override
  Widget build(BuildContext context) {
    return ApiModuleScreen(
      title: 'Journal Audits',
      endpoint: '/journal-audits',
      allowCreate: allowCreate,
      allowUpdate: allowUpdate,
      allowDelete: allowDelete,
      fields: [
        ModuleField(
          key: 'action',
          label: 'Action',
          type: ModuleFieldType.text,
          required: true,
        ),
        ModuleField(
          key: 'type_cible',
          label: 'Type cible',
          type: ModuleFieldType.text,
          required: true,
        ),
        ModuleField(
          key: 'id_cible',
          label: 'ID cible',
          type: ModuleFieldType.number,
        ),
      ],
    );
  }
}
