import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../pharmacie/pharmacie_models.dart';

/// La caisse d'une officine : les ventes du jour, ce qui attend d'être
/// encaissé (caisse séparée), les totaux par moyen de paiement et par rayon.
class VentesDuJourVue extends StatelessWidget {
  const VentesDuJourVue({
    required this.jour,
    required this.devise,
    required this.onVente,
    super.key,
  });

  final VentesDuJour jour;
  final String devise;

  /// Une vente touchée : l'encaisser si elle attend, sinon revoir son reçu.
  final ValueChanged<Vente> onVente;

  @override
  Widget build(BuildContext context) {
    String f(int m) => formatMontant(m, devise);
    final attente = jour.ventes.where((v) => !v.payee).toList();
    final payees = jour.ventes.where((v) => v.payee).toList();
    final maxRayon = jour.parRayon.fold(
      1,
      (m, r) => r.montant > m ? r.montant : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Chiffre('Ventes du jour', '${jour.nombre}'),
            _Chiffre('Encaissé', f(jour.encaisse)),
            if (jour.aEncaisser > 0)
              _Chiffre('À encaisser', f(jour.aEncaisser), alerte: true),
            for (final e in jour.parMoyen.entries)
              _Chiffre(libellesMoyens[e.key] ?? e.key, f(e.value)),
          ],
        ),
        if (attente.isNotEmpty) ...[
          const SizedBox(height: 16),
          _titre('Attendent à la caisse'),
          Card(
            color: Kolors.kJauneDoux,
            child: Column(children: [for (final v in attente) _ligne(v, f)]),
          ),
        ],
        if (jour.parRayon.isNotEmpty) ...[
          const SizedBox(height: 16),
          _titre('Par rayon'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final r in jour.parRayon)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(width: 140, child: Text(r.label)),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: r.montant / maxRayon,
                                minHeight: 10,
                                backgroundColor: Kolors.kSecondaryLight,
                                color: Kolors.kPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 100,
                            child: Text(
                              f(r.montant),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _titre('Ventes'),
        if (payees.isEmpty)
          const Text(
            'Aucune vente encaissée aujourd’hui.',
            style: TextStyle(color: Kolors.kTextMuted),
          )
        else
          Card(child: Column(children: [for (final v in payees) _ligne(v, f)])),
      ],
    );
  }

  Widget _titre(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );

  Widget _ligne(Vente v, String Function(int) f) => ListTile(
    leading: Icon(
      v.payee ? Icons.receipt_rounded : Icons.hourglass_top_rounded,
      color: v.payee ? Kolors.kSuccess : Kolors.kGold,
    ),
    title: Text(
      '${v.le == null ? '' : '${DateFormat('HH:mm').format(v.le!)} · '}${v.client}',
    ),
    subtitle: Text(
      v.lignes.map((l) => l.libelle).join(', '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: Text(
      f(v.total),
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    onTap: () => onVente(v),
  );
}

class _Chiffre extends StatelessWidget {
  const _Chiffre(this.libelle, this.valeur, {this.alerte = false});

  final String libelle;
  final String valeur;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alerte ? Kolors.kJauneDoux : Kolors.kWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Kolors.kSecondaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valeur,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Kolors.kPrimary,
            ),
          ),
          Text(libelle, style: const TextStyle(color: Kolors.kTextMuted)),
        ],
      ),
    );
  }
}
