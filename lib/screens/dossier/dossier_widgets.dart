import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../common/utils/kcolors.dart';
import '../../dossier/dossier_models.dart';
import '../../labo/labo_models.dart';
import '../../common/widgets/formulaire.dart';

final _date = DateFormat('d MMM yyyy', 'fr');

String dateCourte(DateTime? d) => d == null ? '' : _date.format(d);

/// Allergies, antécédents, traitements : ce qu'on doit savoir avant tout.
class BlocMedical extends StatelessWidget {
  const BlocMedical(this.dossier, {this.onModifier, super.key});

  final DossierPatient dossier;
  final VoidCallback? onModifier;

  @override
  Widget build(BuildContext context) {
    final vide =
        dossier.allergies == null &&
        dossier.antecedents == null &&
        dossier.traitements == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'À savoir',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (onModifier != null)
                  TextButton.icon(
                    onPressed: onModifier,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Modifier'),
                  ),
              ],
            ),
            if (vide)
              const Text(
                'Rien de noté : allergies, antécédents, traitements en cours.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            if (dossier.allergies != null)
              _Ligne(
                'Allergies',
                dossier.allergies!,
                couleur: Kolors.kRed,
                icone: Icons.warning_amber_rounded,
              ),
            if (dossier.antecedents != null)
              _Ligne('Antécédents', dossier.antecedents!),
            if (dossier.traitements != null)
              _Ligne('Traitements en cours', dossier.traitements!),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.titre, this.texte, {this.couleur, this.icone});

  final String titre;
  final String texte;
  final Color? couleur;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 18, color: couleur),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$titre : ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: couleur ?? Kolors.kTextHigh,
                    ),
                  ),
                  TextSpan(text: texte),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une consultation du dossier.
class CarteConsultation extends StatelessWidget {
  const CarteConsultation(
    this.c, {
    this.montrerLieu = true,
    this.onModifier,
    super.key,
  });

  final Consultation c;
  final bool montrerLieu;

  /// Corriger la consultation (son auteur, le jour même).
  final VoidCallback? onModifier;

  @override
  Widget build(BuildContext context) {
    final constantes = c.constantesCourtes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                dateCourte(c.date),
                if (montrerLieu) c.etablissement,
                ?c.praticien,
              ].where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 4),
            Text(
              c.motif,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            if (constantes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(constantes, style: const TextStyle(fontSize: 13)),
            ],
            if (c.diagnostic != null) ...[
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Diagnostic : ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: c.cim10 == null
                          ? c.diagnostic
                          : '${c.diagnostic} (${c.cim10})',
                    ),
                  ],
                ),
              ),
            ],
            if (c.examen != null) ...[
              const SizedBox(height: 4),
              Text(c.examen!),
            ],
            if (c.conclusion != null) ...[
              const SizedBox(height: 4),
              Text(
                c.conclusion!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            if (c.prochainRdv != null) ...[
              const SizedBox(height: 4),
              Text(
                'À revoir le ${dateCourte(DateTime.tryParse(c.prochainRdv!))}',
                style: const TextStyle(
                  color: Kolors.kPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (onModifier != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: onModifier,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Une demande d'analyses dans le dossier : en cours, ou ses résultats.
class CarteAnalyses extends StatelessWidget {
  const CarteAnalyses(this.d, {super.key});

  final DemandeLabo d;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                dateCourte(d.date),
                d.etablissement,
                if (!d.validee) d.statutLabel,
              ].where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            for (final l in d.lignes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        l.normale == null ? l.nom : '${l.nom} (${l.normale})',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.resultatAffiche ?? (d.validee ? '—' : 'en attente'),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: l.anormal == true
                              ? Kolors.kRed
                              : l.resultat == null
                              ? Kolors.kTextMuted
                              : Kolors.kTextHigh,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Modifier allergies, antécédents, traitements, groupe sanguin, sexe et
/// date de naissance. Renvoie les champs à envoyer, ou null.
Future<Map<String, dynamic>?> editerInfosMedicales(
  BuildContext context,
  DossierPatient d,
) {
  final allergies = TextEditingController(text: d.allergies);
  final antecedents = TextEditingController(text: d.antecedents);
  final traitements = TextEditingController(text: d.traitements);
  String? groupe = d.groupeSanguin;
  String? sexe = d.sexe;
  DateTime? naissance = DateTime.tryParse(d.dateNaissance ?? '');

  return formulaire<Map<String, dynamic>>(
    context,
    titre: const Text('Informations médicales'),
    corps: (ctx, setState) => Column(
      spacing: 12,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: allergies,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: 'Allergies (ex. pénicilline)',
          ),
        ),
        TextField(
          controller: antecedents,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: 'Antécédents (maladies, opérations)',
          ),
        ),
        TextField(
          controller: traitements,
          maxLines: null,
          decoration: const InputDecoration(labelText: 'Traitements en cours'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: groupe,
          decoration: const InputDecoration(labelText: 'Groupe sanguin'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Inconnu')),
            for (final g in groupesSanguins)
              DropdownMenuItem(value: g, child: Text(g)),
          ],
          onChanged: (v) => setState(() => groupe = v),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'F', label: Text('Femme')),
            ButtonSegment(value: 'M', label: Text('Homme')),
          ],
          selected: {?sexe},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) =>
              setState(() => sexe = s.isEmpty ? null : s.first),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cake_outlined),
          title: Text(
            naissance == null
                ? 'Date de naissance'
                : 'Né(e) le ${dateCourte(naissance)}',
          ),
          onTap: () async {
            final choix = await showDatePicker(
              context: ctx,
              initialDate: naissance ?? DateTime(1990),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              initialDatePickerMode: DatePickerMode.year,
            );
            if (choix != null) setState(() => naissance = choix);
          },
        ),
      ],
    ),
    actions: (ctx, setState) => [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Annuler'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.pop(ctx, {
          'allergies': allergies.text.trim(),
          'antecedents': antecedents.text.trim(),
          'traitements': traitements.text.trim(),
          'groupe_sanguin': groupe,
          'sexe': sexe,
          'date_naissance': naissance == null
              ? null
              : DateFormat('yyyy-MM-dd').format(naissance!),
        }),
        child: const Text('Enregistrer'),
      ),
    ],
  );
}
