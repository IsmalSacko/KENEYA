import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../caisse/caisse_models.dart';
import '../../caisse/recu.dart';
import '../../common/utils/kcolors.dart';
import '../../common/whatsapp.dart';
import '../file/ticket_carte.dart';

/// Le reçu après l'encaissement, comme le ticket de Ngoni Caisse : on le
/// voit tel qu'il sera imprimé, puis on l'imprime, on le partage en PDF ou on
/// l'envoie par WhatsApp. [annuler] : la vente du jour peut être annulée.
class RecuScreen extends StatelessWidget {
  const RecuScreen({required this.recu, this.annuler, super.key});

  final Recu recu;
  final Future<void> Function()? annuler;

  Future<void> _partager(BuildContext context) async {
    final octets = await recu.pdf();
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            octets,
            mimeType: 'application/pdf',
            name: 'Recu-${recu.numero}.pdf',
          ),
        ],
        fileNameOverrides: ['Recu-${recu.numero}.pdf'],
        text:
            'Reçu ${recu.numero}${recu.etablissement == null ? '' : ' — ${recu.etablissement}'}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String m(int x) => formatMontant(x, recu.devise);
    // La police de l'app, chiffres alignés comme sur un ticket : la même sur
    // Android, iPhone et Windows.
    const mono = TextStyle(
      fontSize: 13.5,
      height: 1.4,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    Widget ligne(String g, String d, {bool gras = false}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            g,
            style: mono.copyWith(fontWeight: gras ? FontWeight.w800 : null),
          ),
        ),
        Text(
          d,
          style: mono.copyWith(fontWeight: gras ? FontWeight.w800 : null),
        ),
      ],
    );
    const trait = Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1, color: Colors.black26),
    );

    return Scaffold(
      appBar: AppBar(title: Text('Reçu ${recu.numero}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (recu.etablissement != null)
                      Text(
                        recu.etablissement!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (recu.adresse != null)
                      Text(
                        recu.adresse!,
                        textAlign: TextAlign.center,
                        style: mono,
                      ),
                    if (recu.telephoneEtablissement != null)
                      Text(
                        recu.telephoneEtablissement!,
                        textAlign: TextAlign.center,
                        style: mono,
                      ),
                    trait,
                    Text(
                      'Reçu N° ${recu.numero}',
                      textAlign: TextAlign.center,
                      style: mono.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (recu.le != null)
                      Text(
                        '${recu.le!.day.toString().padLeft(2, '0')}/${recu.le!.month.toString().padLeft(2, '0')}/${recu.le!.year} ${recu.le!.hour.toString().padLeft(2, '0')}:${recu.le!.minute.toString().padLeft(2, '0')}',
                        textAlign: TextAlign.center,
                        style: mono,
                      ),
                    if (recu.annule)
                      Text(
                        'VENTE ANNULÉE',
                        textAlign: TextAlign.center,
                        style: mono.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Kolors.kRed,
                        ),
                      ),
                    if (recu.client != null && recu.client!.isNotEmpty)
                      Text(
                        'Patient : ${recu.client}${recu.numeroDossier == null ? '' : '\nDossier ${recu.numeroDossier}'}',
                        style: mono,
                      ),
                    trait,
                    for (final l in recu.lignes)
                      ligne(
                        '${l.libelle}${l.quantite > 1 ? ' × ${l.quantite}' : ''}',
                        m(l.montant),
                      ),
                    trait,
                    ligne('TOTAL', m(recu.total), gras: true),
                    if (recu.partAssureur > 0)
                      ligne(
                        'Assurance${recu.assureur == null ? '' : ' ${recu.assureur}'}',
                        m(recu.partAssureur),
                      ),
                    for (final p in recu.paiements.where((p) => p.montant > 0))
                      ligne('Payé (${p.moyen})', m(p.montant)),
                    if (recu.reste > 0)
                      ligne('Reste à payer', m(recu.reste), gras: true),
                    if (recu.caissier != null)
                      Text('Caisse : ${recu.caissier}', style: mono),
                    const SizedBox(height: 10),
                    const Text(
                      'Merci de votre visite',
                      textAlign: TextAlign.center,
                      style: mono,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => imprimerSurThermique(context, recu.octets),
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Imprimer'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () => _partager(context),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Partager (PDF)'),
                  ),
                  if (recu.telephoneClient != null &&
                      recu.telephoneClient!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () => envoyerWhatsApp(
                        context,
                        recu.telephoneClient!,
                        recu.texte(),
                      ),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Envoyer par WhatsApp'),
                    ),
                  ],
                  if (annuler != null && !recu.annule) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Kolors.kRed),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Annuler cette vente ?'),
                            content: const Text(
                              'Les produits rentrent en stock et l’argent est rendu au client.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Non'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Annuler la vente'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true || !context.mounted) return;
                        Navigator.pop(context);
                        await annuler!();
                      },
                      icon: const Icon(Icons.block_rounded),
                      label: const Text('Annuler la vente'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
