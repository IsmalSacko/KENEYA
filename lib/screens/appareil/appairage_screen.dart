import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/api_client.dart';
import '../../file/appareil_api.dart';
import '../compte/cadre_acces.dart';

/// Faire de cet appareil un écran de salle ou une borne : le code (ou son
/// QR) se crée dans l'espace pro, « Régler la file ».
class AppairageScreen extends StatefulWidget {
  const AppairageScreen({super.key});

  @override
  State<AppairageScreen> createState() => _AppairageScreenState();
}

class _AppairageScreenState extends State<AppairageScreen> {
  final _code = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _appairer(String code) async {
    if (code.length != 6 || _envoi) return;
    setState(() => _envoi = true);
    try {
      await AppareilApi.appairer(code);
      if (!mounted) return;
      // L'app se réaiguille seule vers l'écran ou la borne.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on DioException catch (e) {
      if (!mounted) return;
      afficherMessage(context, messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _scanner() async {
    final lu = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const _Scanner()));
    // QR créé par l'espace pro : « ngoni-sante:appairer:123456 ».
    final code = lu?.split(':').last;
    if (code != null) {
      _code.text = code;
      await _appairer(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CadreAcces(
      titre: 'Écran ou borne',
      sousTitre:
          'Dans l’espace pro, « File d’attente › Régler la file », ajoutez un écran ou une borne : un code s’affiche. Scannez-le ou tapez-le ici.',
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: _envoi ? null : _scanner,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scanner le QR'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 8),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Code à 6 chiffres',
            counterText: '',
          ),
          onChanged: (v) {
            if (v.length == 6) _appairer(v);
          },
        ),
        const SizedBox(height: 14),
        BoutonAcces(
          label: 'Appairer',
          chargement: _envoi,
          onPressed: () => _appairer(_code.text),
        ),
      ],
    );
  }
}

class _Scanner extends StatefulWidget {
  const _Scanner();

  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> {
  bool _lu = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner le QR')),
      body: MobileScanner(
        onDetect: (capture) {
          final valeur = capture.barcodes.firstOrNull?.rawValue;
          if (_lu || valeur == null) return;
          _lu = true;
          Navigator.of(context).pop(valeur);
        },
      ),
    );
  }
}
