import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../common/utils/kcolors.dart';

/// Scanne un QR et renvoie son contenu (ou null si l'on revient en arrière).
class ScannerQrScreen extends StatefulWidget {
  const ScannerQrScreen({
    this.titre = 'Scanner le QR',
    this.consigne,
    super.key,
  });

  final String titre;
  final String? consigne;

  @override
  State<ScannerQrScreen> createState() => _ScannerQrScreenState();
}

class _ScannerQrScreenState extends State<ScannerQrScreen> {
  bool _lu = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titre)),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final valeur = capture.barcodes.firstOrNull?.rawValue;
              if (_lu || valeur == null) return;
              _lu = true;
              Navigator.of(context).pop(valeur);
            },
          ),
          if (widget.consigne != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Kolors.kPrimaryDark.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  widget.consigne!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Kolors.kWhite, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ouvre le scanner et renvoie le contenu lu.
Future<String?> scannerQr(
  BuildContext context, {
  String? titre,
  String? consigne,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) =>
          ScannerQrScreen(titre: titre ?? 'Scanner le QR', consigne: consigne),
    ),
  );
}
