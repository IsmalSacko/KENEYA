import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../file/file_models.dart';
import '../../file/impression_ticket.dart';

/// Le ticket tel que le patient le voit : le code en grand, son service, sa
/// place, et le QR qui ouvre le suivi en direct.
class TicketCarte extends StatelessWidget {
  const TicketCarte({required this.ticket, this.qr = true, super.key});

  final TicketFile ticket;
  final bool qr;

  @override
  Widget build(BuildContext context) {
    return CarteMarque(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(
            ticket.etablissementNom,
            textAlign: TextAlign.center,
            style: TextStyle(color: Kolors.kWhite.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 6),
          Text(
            ticket.code,
            style: GoogleFonts.poppins(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: Kolors.kJaune,
              letterSpacing: 2,
            ),
          ),
          Text(
            ticket.serviceNom,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (ticket.prioritaire) ...[
            const SizedBox(height: 8),
            _Pastille(ticket.prioriteLabel),
          ],
          const SizedBox(height: 12),
          Text(
            _etat(ticket),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (qr && ticket.suiviUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Kolors.kWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(data: ticket.suiviUrl, size: 140),
            ),
            const SizedBox(height: 6),
            Text(
              'Scannez pour suivre votre tour',
              style: TextStyle(
                color: Kolors.kWhite.withValues(alpha: 0.85),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _etat(TicketFile t) {
  if (t.appele || t.enService) {
    return t.salle == null ? 'C’est à vous !' : 'C’est à vous → ${t.salle}';
  }
  if (t.enAttente) {
    final avant = t.position ?? 0;
    final attente = t.attenteMin == null
        ? ''
        : ' · environ ${t.attenteMin} min';
    return avant == 0
        ? 'Vous êtes le prochain$attente'
        : '$avant ${avant > 1 ? 'personnes' : 'personne'} avant vous$attente';
  }
  return t.statutLabel;
}

class _Pastille extends StatelessWidget {
  const _Pastille(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Kolors.kJaune,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texte,
        style: const TextStyle(
          color: Kolors.kPrimaryDark,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Le ticket qu'on vient de donner : à montrer ou à imprimer.
/// [imprimer] : faux sur le téléphone du patient (pas d'imprimante).
Future<void> afficherTicket(
  BuildContext context,
  TicketFile ticket, {
  bool imprimer = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TicketCarte(ticket: ticket),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (imprimer) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Kolors.kWhite,
                        ),
                        onPressed: () => imprimerTicket(ctx, ticket),
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Imprimer'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Imprime, après avoir fait choisir l'imprimante la première fois.
Future<void> imprimerTicket(BuildContext context, TicketFile ticket) async {
  void dire(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  final obstacle = await ImpressionTicket.obstacle();
  if (obstacle != null) {
    dire(obstacle);
    return;
  }
  if (ImpressionTicket.imprimanteChoisie == null) {
    final imprimantes = await ImpressionTicket.imprimantes();
    if (!context.mounted) return;
    if (imprimantes.isEmpty) {
      dire(ImpressionTicket.aucuneImprimante);
      return;
    }
    final choix = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choisir l’imprimante'),
        children: [
          for (final i in imprimantes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i.macAdress),
              child: Text(i.name),
            ),
        ],
      ),
    );
    if (choix == null) return;
    await ImpressionTicket.choisir(choix);
  }
  final ok = await ImpressionTicket.imprimer(ticket);
  if (context.mounted && !ok) {
    dire('Impression impossible : vérifiez que l’imprimante est allumée.');
  }
}
