import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import '../caisse/caisse_models.dart';
import '../file/impression_ticket.dart';
import 'pharmacie_models.dart';

/// Le reçu d'une vente : à imprimer (thermique 58 mm) ou à envoyer par
/// WhatsApp au client.
class Recu {
  /// Le texte du reçu, tel qu'il part par WhatsApp.
  static String texte(Vente v) {
    final quand = v.le == null
        ? ''
        : DateFormat('dd/MM/yyyy HH:mm').format(v.le!);
    return [
      if (v.etablissement != null) v.etablissement!,
      'Reçu N° ${v.numero}${quand.isEmpty ? '' : ' · $quand'}',
      '',
      for (final l in v.lignes)
        '• ${l.libelle} : ${formatMontant(l.montant, v.devise)}',
      '',
      'Total : ${formatMontant(v.total, v.devise)}',
      if (v.payee && v.moyens.isNotEmpty)
        'Payé : ${v.moyens.map((m) => libellesMoyens[m] ?? m).join(', ')}',
      'Merci de votre visite.',
    ].join('\n');
  }

  static Future<List<int>> octets(Vente v) async {
    final g = Generator(PaperSize.mm58, await CapabilityProfile.load());
    const centre = PosStyles(align: PosAlign.center);
    String a(String s) => ImpressionTicket.sansAccents(s);
    String m(int x) => a(formatMontant(x, v.devise));

    return [
      ...g.reset(),
      if (v.etablissement != null)
        ...g.text(
          a(v.etablissement!),
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      if (v.etablissementAdresse != null)
        ...g.text(a(v.etablissementAdresse!), styles: centre),
      if (v.etablissementTelephone != null)
        ...g.text(v.etablissementTelephone!, styles: centre),
      ...g.hr(ch: '-'),
      ...g.text('Recu N° ${v.numero}'.replaceAll('°', 'o'), styles: centre),
      if (v.le != null)
        ...g.text(DateFormat('dd/MM/yyyy HH:mm').format(v.le!), styles: centre),
      ...g.hr(ch: '-'),
      for (final l in v.lignes) ...[
        ...g.text(a(l.libelle)),
        ...g.text(m(l.montant), styles: const PosStyles(align: PosAlign.right)),
      ],
      ...g.hr(ch: '='),
      ...g.row([
        PosColumn(text: 'TOTAL', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(
          text: m(v.total),
          width: 7,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
      if (v.payee && v.moyens.isNotEmpty)
        ...g.text(
          a('Paye : ${v.moyens.map((x) => libellesMoyens[x] ?? x).join(', ')}'),
        ),
      ...g.feed(1),
      ...g.text(a('Merci de votre visite'), styles: centre),
      ...g.feed(2),
      ...g.cut(),
    ];
  }
}
