import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../file/impression_ticket.dart';
import '../pharmacie/pharmacie_models.dart';
import 'caisse_models.dart';

/// Le reçu d'un encaissement, comme le ticket de Ngoni Caisse : à l'écran,
/// imprimé (thermique 58 mm), en PDF à partager, ou en texte par WhatsApp.
/// Il vient d'une visite (consultation, labo…) ou d'une vente du comptoir.
class Recu {
  const Recu({
    required this.numero,
    required this.devise,
    required this.lignes,
    required this.total,
    required this.paye,
    required this.reste,
    required this.paiements,
    this.etablissement,
    this.adresse,
    this.telephoneEtablissement,
    this.client,
    this.numeroDossier,
    this.telephoneClient,
    this.le,
    this.partAssureur = 0,
    this.assureur,
    this.caissier,
    this.annule = false,
  });

  final String numero;
  final String devise;
  final List<({String libelle, int quantite, int montant})> lignes;
  final int total;
  final int paye;
  final int reste;
  final List<({String moyen, int montant, String? reference})> paiements;
  final String? etablissement;
  final String? adresse;
  final String? telephoneEtablissement;
  final String? client;
  final String? numeroDossier;
  final String? telephoneClient;
  final DateTime? le;
  final int partAssureur;
  final String? assureur;
  final String? caissier;
  final bool annule;

  factory Recu.deVisite(Visite v) {
    final payes = v.encaissements.where((e) => !e.rembourse).toList();
    return Recu(
      numero: v.numeroFacture ?? v.uuid.substring(0, 8).toUpperCase(),
      devise: v.devise,
      lignes: [
        for (final l in v.lignes)
          (libelle: l.libelle, quantite: l.quantite, montant: l.montant),
      ],
      total: v.total,
      paye: v.paye,
      reste: v.reste,
      paiements: [
        for (final e in payes)
          (moyen: e.moyenLabel, montant: e.montant, reference: e.reference),
      ],
      etablissement: v.recu['etablissement'] ?? v.etablissement,
      adresse: v.recu['adresse'],
      telephoneEtablissement: v.recu['telephone'],
      client: v.nom,
      numeroDossier: v.recu['numero_dossier'],
      telephoneClient: v.telephone,
      le: payes.isEmpty ? v.ouverteAt : payes.last.at,
      partAssureur: v.partAssureur,
      assureur: v.assureur,
      caissier: payes.isEmpty ? null : payes.last.par,
      annule: v.statut == 'annulee',
    );
  }

  factory Recu.deVente(Vente v) => Recu(
    numero: v.numero,
    devise: v.devise,
    lignes: v.lignes,
    total: v.total,
    paye: v.total - v.reste,
    reste: v.reste,
    paiements: [
      for (final m in v.moyens)
        (
          moyen: libellesMoyens[m] ?? m,
          montant: v.moyens.length == 1 ? v.total - v.reste : 0,
          reference: null,
        ),
    ],
    etablissement: v.etablissement,
    adresse: v.etablissementAdresse,
    telephoneEtablissement: v.etablissementTelephone,
    client: v.client,
    telephoneClient: v.telephone,
    le: v.le,
    annule: v.annulee,
  );

  String _m(int x) => formatMontant(x, devise);

  String get _date =>
      le == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(le!);

  /// Le reçu en texte, tel qu'il part par WhatsApp.
  String texte() => [
    ?etablissement,
    'Reçu N° $numero${_date.isEmpty ? '' : ' · $_date'}',
    if (annule) 'VENTE ANNULÉE',
    if (client != null && client!.isNotEmpty)
      'Patient : $client${numeroDossier == null ? '' : ' (dossier $numeroDossier)'}',
    '',
    for (final l in lignes)
      '• ${l.libelle}${l.quantite > 1 ? ' × ${l.quantite}' : ''} : ${_m(l.montant)}',
    '',
    'Total : ${_m(total)}',
    if (partAssureur > 0)
      'Assurance${assureur == null ? '' : ' $assureur'} : ${_m(partAssureur)}',
    for (final p in paiements.where((p) => p.montant > 0))
      'Payé (${p.moyen}) : ${_m(p.montant)}',
    if (reste > 0) 'Reste à payer : ${_m(reste)}',
    'Merci de votre visite.',
  ].join('\n');

  /// Les octets ESC/POS pour l'imprimante thermique 58 mm.
  Future<List<int>> octets() async {
    final g = Generator(PaperSize.mm58, await CapabilityProfile.load());
    String a(String s) => ImpressionTicket.sansAccents(s);
    const centre = PosStyles(align: PosAlign.center);
    List<int> ligne(String gauche, String droite, {bool gras = false}) =>
        g.row([
          PosColumn(
            text: a(gauche),
            width: 7,
            styles: PosStyles(bold: gras),
          ),
          PosColumn(
            text: a(droite),
            width: 5,
            styles: PosStyles(align: PosAlign.right, bold: gras),
          ),
        ]);
    return [
      ...g.reset(),
      if (etablissement != null)
        ...g.text(
          a(etablissement!),
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      if (adresse != null) ...g.text(a(adresse!), styles: centre),
      if (telephoneEtablissement != null)
        ...g.text(telephoneEtablissement!, styles: centre),
      ...g.hr(ch: '-'),
      ...g.text('Recu No $numero', styles: centre),
      if (_date.isNotEmpty) ...g.text(_date, styles: centre),
      if (annule)
        ...g.text(
          'VENTE ANNULEE',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      if (client != null && client!.isNotEmpty) ...[
        ...g.text(a('Patient : $client')),
        if (numeroDossier != null) ...g.text('Dossier $numeroDossier'),
      ],
      ...g.hr(ch: '-'),
      for (final l in lignes) ...[
        ...g.text(a('${l.libelle}${l.quantite > 1 ? ' x${l.quantite}' : ''}')),
        ...g.text(
          a(_m(l.montant)),
          styles: const PosStyles(align: PosAlign.right),
        ),
      ],
      ...g.hr(ch: '='),
      ...ligne('TOTAL', _m(total), gras: true),
      if (partAssureur > 0) ...ligne('Assurance', _m(partAssureur)),
      for (final p in paiements.where((p) => p.montant > 0))
        ...ligne('Paye ${p.moyen}', _m(p.montant)),
      if (reste > 0) ...ligne('Reste', _m(reste), gras: true),
      if (caissier != null) ...g.text(a('Caisse : $caissier')),
      ...g.feed(1),
      ...g.text(a('Merci de votre visite'), styles: centre),
      ...g.feed(2),
      ...g.cut(),
    ];
  }

  /// Le reçu en PDF, au format d'un ticket de caisse (80 mm), à partager.
  Future<Uint8List> pdf() async {
    final doc = pw.Document(title: 'Reçu $numero', author: etablissement);
    final gras = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    pw.Widget ligne(String g, String d, {bool fort = false}) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: pw.Text(g, style: fort ? gras : null)),
        pw.Text(d, style: fort ? gras : null),
      ],
    );
    // La police PDF de base ne connaît pas l'espace insécable fin de
    // l'écriture des montants : on la remplace par une espace simple.
    String m(int x) => _m(x).replaceAll(' ', ' ').replaceAll(' ', ' ');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (etablissement != null)
              pw.Text(
                etablissement!,
                style: gras.copyWith(fontSize: 13),
                textAlign: pw.TextAlign.center,
              ),
            if (adresse != null)
              pw.Text(adresse!, textAlign: pw.TextAlign.center),
            if (telephoneEtablissement != null)
              pw.Text(telephoneEtablissement!, textAlign: pw.TextAlign.center),
            pw.Divider(),
            pw.Text(
              'Reçu N° $numero',
              style: gras,
              textAlign: pw.TextAlign.center,
            ),
            if (_date.isNotEmpty)
              pw.Text(_date, textAlign: pw.TextAlign.center),
            if (annule)
              pw.Text(
                'VENTE ANNULÉE',
                style: gras,
                textAlign: pw.TextAlign.center,
              ),
            if (client != null && client!.isNotEmpty)
              pw.Text(
                'Patient : $client${numeroDossier == null ? '' : ' · dossier $numeroDossier'}',
              ),
            pw.Divider(),
            for (final l in lignes)
              ligne(
                '${l.libelle}${l.quantite > 1 ? ' × ${l.quantite}' : ''}',
                m(l.montant),
              ),
            pw.Divider(),
            ligne('TOTAL', m(total), fort: true),
            if (partAssureur > 0)
              ligne(
                'Assurance${assureur == null ? '' : ' $assureur'}',
                m(partAssureur),
              ),
            for (final p in paiements.where((p) => p.montant > 0))
              ligne('Payé (${p.moyen})', m(p.montant)),
            if (reste > 0) ligne('Reste à payer', m(reste), fort: true),
            if (caissier != null) pw.Text('Caisse : $caissier'),
            pw.SizedBox(height: 8),
            pw.Text('Merci de votre visite', textAlign: pw.TextAlign.center),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
