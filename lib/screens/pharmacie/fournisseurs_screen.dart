import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../common/utils/kcolors.dart';
import '../../core/api/api_client.dart';
import '../../pharmacie/pharmacie_service.dart';

/// Les grossistes : ajouter, corriger, supprimer. Les lots déjà reçus d'un
/// fournisseur supprimé gardent leur historique.
class FournisseursScreen extends StatefulWidget {
  const FournisseursScreen({super.key});

  @override
  State<FournisseursScreen> createState() => _FournisseursScreenState();
}

class _FournisseursScreenState extends State<FournisseursScreen> {
  final _service = PharmacieService();
  List<Map<String, dynamic>> _fournisseurs = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      _fournisseurs = await _service.fournisseurs();
      _erreur = null;
    } on DioException catch (e) {
      _erreur = messageErreur(e);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _dire(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _editer([Map<String, dynamic>? f]) async {
    final nom = TextEditingController(text: f?['nom']?.toString() ?? '');
    final tel = TextEditingController(text: f?['telephone']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          f == null ? 'Nouveau fournisseur' : 'Modifier le fournisseur',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nom,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            TextField(
              controller: tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nom.text.trim().isNotEmpty),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final t = tel.text.trim().isEmpty ? null : tel.text.trim();
    try {
      if (f == null) {
        await _service.creerFournisseur(nom.text.trim(), t);
      } else {
        await _service.modifierFournisseur('${f['uuid']}', nom.text.trim(), t);
      }
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _supprimer(Map<String, dynamic> f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ${f['nom']} ?'),
        content: const Text(
          'Il ne sera plus proposé aux réceptions. Les lots déjà reçus de lui gardent leur historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.supprimerFournisseur('${f['uuid']}');
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fournisseurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editer(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau fournisseur'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (_erreur != null)
                    Text(_erreur!, style: const TextStyle(color: Kolors.kRed))
                  else if (_fournisseurs.isEmpty)
                    const Text(
                      'Aucun fournisseur. Ajoutez vos grossistes : ils seront proposés à chaque réception.',
                      style: TextStyle(color: Kolors.kTextMuted),
                    ),
                  for (final f in _fournisseurs)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: Text('${f['nom']}'),
                        subtitle: Text(
                          (f['telephone'] ?? '').toString().isEmpty
                              ? 'Pas de téléphone'
                              : '${f['telephone']}',
                        ),
                        onTap: () => _editer(f),
                        trailing: IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _supprimer(f),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
