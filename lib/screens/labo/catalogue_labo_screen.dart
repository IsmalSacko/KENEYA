import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../labo/labo_models.dart';
import '../../labo/labo_service.dart';
import '../../common/widgets/formulaire.dart';

/// Les analyses du labo : prix (facturé sur la visite), valeurs normales.
class CatalogueLaboScreen extends StatefulWidget {
  const CatalogueLaboScreen({super.key});

  @override
  State<CatalogueLaboScreen> createState() => _CatalogueLaboScreenState();
}

class _CatalogueLaboScreenState extends State<CatalogueLaboScreen> {
  final _service = LaboService();
  List<AnalyseLabo>? _liste;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final l = await _service.analyses(toutes: true);
      if (mounted) setState(() => _liste = l);
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Future<void> _editer([AnalyseLabo? a]) async {
    final devise = context.read<AuthController>().devise;
    final code = TextEditingController(text: a?.code);
    final nom = TextEditingController(text: a?.nom);
    final unite = TextEditingController(text: a?.unite);
    final min = TextEditingController(text: _n(a?.normaleMin));
    final max = TextEditingController(text: _n(a?.normaleMax));
    final prix = TextEditingController(
      text: a?.prix == null ? '' : '${a!.prix}',
    );
    // Les réponses possibles d'une analyse « à choix », séparées par des virgules.
    final choix = TextEditingController(text: a?.choix.join(', ') ?? '');
    String? normal = a?.choixNormal;
    var type = a?.typeResultat ?? 'nombre';
    var categorie = a?.categorie ?? 'autre';
    var actif = a?.actif ?? true;
    String? erreurCode;
    String? erreurNom;
    String? erreurChoix;
    List<String> reponses() => [
      for (final c in choix.text.split(','))
        if (c.trim().isNotEmpty) c.trim(),
    ];

    final donnees = await formulaire<Map<String, dynamic>>(
      context,
      titre: Text(a == null ? 'Nouvelle analyse' : a.nom),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (a == null)
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Code (ex. CRP)',
                errorText: erreurCode,
              ),
              onChanged: (_) {
                if (erreurCode != null) setState(() => erreurCode = null);
              },
            ),
          TextField(
            controller: nom,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Nom', errorText: erreurNom),
            onChanged: (_) {
              if (erreurNom != null) setState(() => erreurNom = null);
            },
          ),
          const Text('Catégorie'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in categoriesLabo.entries)
                ChoiceChip(
                  label: Text(c.value),
                  selected: categorie == c.key,
                  onSelected: (_) => setState(() => categorie = c.key),
                ),
            ],
          ),
          const Text('Résultat'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'nombre', label: Text('Nombre')),
              ButtonSegment(value: 'choix', label: Text('Choix')),
              ButtonSegment(value: 'texte', label: Text('Texte')),
            ],
            selected: {type},
            onSelectionChanged: (s) => setState(() => type = s.first),
          ),
          TextField(
            controller: prix,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Prix ($devise) — vide : non facturé',
            ),
          ),
          if (type == 'nombre') ...[
            TextField(
              controller: unite,
              decoration: const InputDecoration(labelText: 'Unité (ex. g/L)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: min,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Normale min'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: max,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Normale max'),
                  ),
                ),
              ],
            ),
          ],
          if (type == 'choix') ...[
            TextField(
              controller: choix,
              decoration: InputDecoration(
                labelText: 'Réponses possibles, séparées par des virgules',
                hintText: 'Négatif, Positif',
                errorText: erreurChoix,
              ),
              onChanged: (_) => setState(() {
                erreurChoix = null;
                if (!reponses().contains(normal)) normal = null;
              }),
            ),
            if (reponses().isNotEmpty) ...[
              const Text(
                'Réponse normale (les autres sont marquées anormales)',
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in reponses())
                    ChoiceChip(
                      label: Text(r),
                      selected: normal == r,
                      onSelected: (oui) =>
                          setState(() => normal = oui ? r : null),
                    ),
                ],
              ),
            ],
          ],
          if (a != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Proposée aux médecins'),
              value: actif,
              onChanged: (v) => setState(() => actif = v),
            ),
        ],
      ),
      actions: (ctx, setState) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              erreurCode = a == null && code.text.trim().isEmpty
                  ? 'Indiquez un code.'
                  : null;
              erreurNom = nom.text.trim().isEmpty ? 'Indiquez le nom.' : null;
              erreurChoix = type == 'choix' && reponses().length < 2
                  ? 'Au moins deux réponses.'
                  : null;
            });
            if (erreurCode != null ||
                erreurNom != null ||
                erreurChoix != null) {
              return;
            }
            Navigator.pop(ctx, {
              if (a == null) 'code': code.text.trim() else 'actif': actif,
              'nom': nom.text.trim(),
              'categorie': categorie,
              'type_resultat': type,
              'prix': int.tryParse(prix.text) ?? 0,
              if (type == 'nombre') ...{
                'unite': unite.text.trim(),
                'normale_min': double.tryParse(min.text.replaceAll(',', '.')),
                'normale_max': double.tryParse(max.text.replaceAll(',', '.')),
              },
              if (type == 'choix') ...{
                'choix': reponses(),
                'choix_normal': normal,
              },
            });
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
    if (donnees == null) return;
    try {
      await _service.enregistrerAnalyse(donnees, uuid: a?.uuid);
      await _charger();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devise = context.watch<AuthController>().devise;
    final l = _liste;
    return Scaffold(
      appBar: AppBar(title: const Text('Analyses et prix')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nouvelle-analyse',
        onPressed: () => _editer(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle analyse'),
      ),
      body: l == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final (i, a) in l.indexed) ...[
                  if (i == 0 || l[i - 1].categorie != a.categorie)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                      child: Text(
                        a.categorieLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Kolors.kTextMuted,
                        ),
                      ),
                    ),
                  Card(
                    child: ListTile(
                      title: Text(
                        a.nom,
                        style: TextStyle(
                          color: a.actif ? null : Kolors.kTextMuted,
                        ),
                      ),
                      subtitle: a.normale == null
                          ? (a.typeResultat == 'choix' && a.choix.isNotEmpty
                                ? Text(a.choix.join(' / '))
                                : null)
                          : Text('Normale : ${a.normale}'),
                      trailing: Text(
                        a.prix == null
                            ? 'Non facturé'
                            : formatMontant(a.prix!, devise),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: a.prix == null ? Kolors.kTextMuted : null,
                        ),
                      ),
                      onTap: () => _editer(a),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

String _n(double? v) =>
    v == null ? '' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');
