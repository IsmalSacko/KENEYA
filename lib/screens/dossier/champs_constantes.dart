import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../dossier/dossier_models.dart';

/// Une valeur normale chez l'adulte, montrée en exemple dans le champ vide.
const _exemples = {
  'ta_sys': '120',
  'ta_dia': '80',
  'temperature': '37',
  'pouls': '75',
  'spo2': '98',
  'poids': '70',
  'taille': '170',
  'glycemie': '0,9',
};

/// Un champ par constante connue.
Map<String, TextEditingController> controleursConstantes([
  Map<String, num>? valeurs,
]) => {
  for (final k in constantesConnues.keys)
    k: TextEditingController(
      text: valeurs?[k] == null ? '' : _texte(valeurs![k]!),
    ),
};

/// Les constantes saisies, en nombres (la virgule vaut le point).
Map<String, num> lireConstantes(Map<String, TextEditingController> champs) => {
  for (final e in champs.entries)
    if (_nombre(e.value.text) != null) e.key: _nombre(e.value.text)!,
};

/// La première valeur impossible, en clair ; null si tout va bien.
String? erreurConstantes(Map<String, TextEditingController> champs) {
  for (final e in champs.entries) {
    final m = _erreur(e.key, e.value.text);
    if (m != null) return '${constantesConnues[e.key]!.$1} : $m';
  }
  return null;
}

String? _erreur(String cle, String texte) {
  if (texte.trim().isEmpty) return null;
  final v = _nombre(texte);
  if (v == null) return 'un nombre';
  final b = bornesConstantes[cle];
  if (b != null && (v < b.$1 || v > b.$2)) {
    final unite = constantesConnues[cle]!.$2;
    return 'entre ${_texte(b.$1)} et ${_texte(b.$2)} $unite';
  }
  return null;
}

num? _nombre(String texte) => num.tryParse(texte.trim().replaceAll(',', '.'));

String _texte(num v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : '$v'.replaceAll('.', ',');

/// Les champs des constantes, quatre par ligne quand la place le permet,
/// sinon deux ; une valeur impossible est signalée sous le champ.
class ChampsConstantes extends StatefulWidget {
  const ChampsConstantes({required this.champs, super.key});

  final Map<String, TextEditingController> champs;

  @override
  State<ChampsConstantes> createState() => _ChampsConstantesState();
}

class _ChampsConstantesState extends State<ChampsConstantes> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Sous 760 de large, « TA systolique » serait coupé : deux par ligne.
        final largeur = c.maxWidth >= 760
            ? (c.maxWidth - 24) / 4
            : (c.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 14,
          children: [
            for (final e in constantesConnues.entries)
              SizedBox(
                width: largeur,
                child: TextField(
                  controller: widget.champs[e.key],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: e.value.$1,
                    hintText: 'ex. ${_exemples[e.key]}',
                    suffixText: e.value.$2,
                    errorText: _erreur(e.key, widget.champs[e.key]!.text),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
