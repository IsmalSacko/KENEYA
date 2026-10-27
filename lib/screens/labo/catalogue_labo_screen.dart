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
    var type = a?.typeResultat ?? 'nombre';
    var actif = a?.actif ?? true;

    final donnees = await formulaire<Map<String, dynamic>>(
      context,
      titre: Text(a == null ? 'Nouvelle analyse' : a.nom),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a == null) ...[
            TextField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Code (ex. CRP)'),
            ),
            TextField(
              controller: nom,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'nombre', label: Text('Nombre')),
                ButtonSegment(value: 'texte', label: Text('Texte')),
              ],
              selected: {type},
              onSelectionChanged: (s) => setState(() => type = s.first),
            ),
          ],
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
          onPressed: () => Navigator.pop(ctx, {
            if (a == null) ...{
              'code': code.text.trim(),
              'nom': nom.text.trim(),
              'type_resultat': type,
            } else
              'actif': actif,
            'prix': int.tryParse(prix.text) ?? 0,
            if (type == 'nombre') ...{
              'unite': unite.text.trim(),
              'normale_min': double.tryParse(min.text.replaceAll(',', '.')),
              'normale_max': double.tryParse(max.text.replaceAll(',', '.')),
            },
          }),
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
      appBar: AppBar(
        title: const Text('Analyses et prix'),
        actions: [
          IconButton(
            tooltip: 'Nouvelle analyse',
            icon: const Icon(Icons.add),
            onPressed: () => _editer(),
          ),
        ],
      ),
      body: l == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
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
                          ? null
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
