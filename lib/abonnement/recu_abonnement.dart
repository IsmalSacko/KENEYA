import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../caisse/caisse_models.dart';
import 'abonnement_service.dart';

/// Le reçu d'un abonnement payé à Ngoni Santé, en PDF (A5) : qui a payé,
/// la formule, la période couverte, le montant. Comme le reçu d'abonnement
/// de Ngoni Caisse.
Future<Uint8List> recuAbonnementPdf({
  required Map<String, dynamic> demande,
  required String etablissement,
}) async {
  final doc = pw.Document(
    title: 'Reçu ${demande['recu_numero']}',
    author: 'IsmaelDev · Ngoni Santé',
  );
  final nuit = PdfColor.fromHex('#0F2A5C');
  final jaune = PdfColor.fromHex('#FFCC1F');
  final gris = PdfColor.fromHex('#5A6478');
  final fond = PdfColor.fromHex('#EEF2F8');
  final gras = pw.TextStyle(fontWeight: pw.FontWeight.bold);
  String date(Object? iso) {
    final d = DateTime.tryParse('${iso ?? ''}');
    return d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
  }

  // La police PDF de base ne connaît pas l'espace fine des montants.
  String m(Object? montant) => formatMontant(
    int.tryParse('$montant') ?? 0,
    '${demande['devise'] ?? 'XOF'}',
  ).replaceAll(' ', ' ').replaceAll(' ', ' ');
  final mois = int.tryParse('${demande['mois']}') ?? 1;
  final duree = mois == 12 ? '1 an' : '$mois mois';

  pw.Widget ligne(String g, String d, {bool fort = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(g, style: pw.TextStyle(color: gris)),
        pw.Text(d, style: fort ? gras.copyWith(fontSize: 14) : gras),
      ],
    ),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: nuit,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'NGONI SANTÉ',
                        style: gras.copyWith(
                          color: PdfColors.white,
                          fontSize: 16,
                        ),
                      ),
                      pw.Text(
                        'IsmaelDev · ismael-dev.com',
                        style: pw.TextStyle(color: jaune, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'REÇU',
                      style: gras.copyWith(color: jaune, fontSize: 12),
                    ),
                    pw.Text(
                      'N° ${demande['recu_numero']}',
                      style: gras.copyWith(
                        color: PdfColors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Reçu de', style: pw.TextStyle(color: gris)),
          pw.Text(etablissement, style: gras.copyWith(fontSize: 15)),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: fond,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              children: [
                ligne(
                  'Abonnement',
                  'Formule ${demande['formule_nom']} · $duree',
                ),
                ligne(
                  'Période',
                  'du ${date(demande['periode_debut'])} au ${date(demande['periode_fin'])}',
                ),
                ligne(
                  'Payé par',
                  '${libellesMoyensAbonnement[demande['moyen']] ?? demande['moyen'] ?? ''}'
                      '${demande['telephone'] == null ? '' : ' · ${demande['telephone']}'}',
                ),
                ligne('Demandé le', date(demande['le'])),
                pw.Divider(color: PdfColor.fromHex('#D7DEEA')),
                ligne('Montant payé', m(demande['montant']), fort: true),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'Merci de votre confiance. Ce reçu atteste le paiement de l'abonnement '
            'Ngoni Santé pour la période indiquée.',
            style: pw.TextStyle(color: gris, fontSize: 9),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
