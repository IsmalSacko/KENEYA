import 'package:flutter/material.dart';

import '../utils/kcolors.dart';

/// « Annuler ce rendez-vous ? » : vrai si la personne confirme. [action] est
/// le mot du bouton (« Annuler le rendez-vous ») ; [danger] le met en rouge.
Future<bool> confirmer(
  BuildContext context, {
  required String titre,
  String? texte,
  required String action,
  bool danger = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: texte == null ? null : Text(texte),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            style: danger
                ? TextButton.styleFrom(foregroundColor: Kolors.kRed)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    ) ==
    true;

/// Comme [confirmer], avec une raison facultative (envoyée au patient).
/// Null si la personne renonce ; sinon la raison, vide si aucune.
Future<String?> confirmerAvecRaison(
  BuildContext context, {
  required String titre,
  String? texte,
  required String action,
  String exemple = 'ex. Médecin absent ce jour-là',
}) {
  final raison = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (texte != null) Text(texte),
            TextField(
              controller: raison,
              maxLength: 255,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Raison (facultatif, envoyée au patient)',
                hintText: exemple,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Non'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Kolors.kRed),
          onPressed: () => Navigator.pop(ctx, raison.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
}
