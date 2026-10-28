import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../common/utils/kcolors.dart';
import '../../core/api/api_client.dart';
import '../../pharmacie/pharmacie_models.dart';

/// Les catégories de la pharmacie : ajouter, renommer, ranger, retirer.
/// « Médicaments » reste toujours (ordonnance et molécule n'ont de sens que
/// là) ; une catégorie qui contient des produits ne se retire pas.
class RayonsScreen extends StatefulWidget {
  const RayonsScreen({super.key});

  @override
  State<RayonsScreen> createState() => _RayonsScreenState();
}

class _RayonsScreenState extends State<RayonsScreen> {
  late List<(String?, String)> _liste = _depuisStore();
  bool _envoi = false;

  static List<(String?, String)> _depuisStore() => [
    for (final e in Rayons.noms.entries) (e.key, e.value),
  ];

  @override
  void initState() {
    super.initState();
    Rayons.charger().then((_) {
      if (mounted) setState(() => _liste = _depuisStore());
    });
  }

  Future<void> _enregistrer(List<(String?, String)> liste) async {
    setState(() => _envoi = true);
    try {
      await Rayons.enregistrer(liste);
      if (mounted) setState(() => _liste = _depuisStore());
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<String?> _nom({String? actuel}) {
    final ctrl = TextEditingController(text: actuel);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(actuel == null ? 'Nouvelle catégorie' : 'Renommer'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Nom (ex. Parapharmacie, Lunettes)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _retirer(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer « ${_liste[i].$2} » ?'),
        content: const Text(
          'Possible seulement si aucun produit n’y est rangé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok == true) await _enregistrer([..._liste]..removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catégories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _envoi
            ? null
            : () async {
                final nom = await _nom();
                if (nom != null) await _enregistrer([..._liste, (null, nom)]);
              },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle catégorie'),
      ),
      body: Column(
        children: [
          if (_envoi) const LinearProgressIndicator(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Glissez pour changer l’ordre (c’est celui de l’écran « Vendre »). Touchez pour renommer.',
              style: TextStyle(color: Kolors.kTextMuted),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              onReorderItem: (de, vers) {
                final l = [..._liste];
                l.insert(vers, l.removeAt(de));
                _enregistrer(l);
              },
              children: [
                for (var i = 0; i < _liste.length; i++)
                  Card(
                    key: ValueKey(_liste[i].$1 ?? 'nouveau$i'),
                    child: ListTile(
                      leading: const Icon(Icons.drag_indicator_rounded),
                      title: Text(_liste[i].$2),
                      subtitle: _liste[i].$1 == 'medicaments'
                          ? const Text('Toujours là : ordonnance et molécule')
                          : null,
                      onTap: () async {
                        final nom = await _nom(actuel: _liste[i].$2);
                        if (nom == null) return;
                        final l = [..._liste];
                        l[i] = (l[i].$1, nom);
                        await _enregistrer(l);
                      },
                      trailing: _liste[i].$1 == 'medicaments'
                          ? null
                          : IconButton(
                              tooltip: 'Retirer',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _retirer(i),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
