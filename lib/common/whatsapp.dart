import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ouvre WhatsApp avec le message déjà écrit : le soignant n'a plus qu'à
/// toucher « Envoyer ». Gratuit, avec les données du téléphone.
Future<void> envoyerWhatsApp(
  BuildContext context,
  String telephone,
  String message,
) async {
  final chiffres = telephone.replaceAll(RegExp(r'\D'), '');
  final uri = Uri.parse(
    'https://wa.me/$chiffres?text=${Uri.encodeComponent(message)}',
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('WhatsApp ne s’ouvre pas sur ce téléphone.'),
      ),
    );
  }
}
