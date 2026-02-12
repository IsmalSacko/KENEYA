import 'package:flutter/material.dart';

import '../api_module_screen.dart';

class JournalAuditsScreen extends StatelessWidget {
  const JournalAuditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ApiModuleScreen(
      title: 'Journal Audits',
      endpoint: '/journal-audits',
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
