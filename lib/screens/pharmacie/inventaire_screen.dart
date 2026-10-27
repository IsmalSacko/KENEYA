import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/utils/kcolors.dart';
import '../../core/api/api_client.dart';
import '../../pharmacie/pharmacie_models.dart';
import '../../pharmacie/pharmacie_service.dart';

/// L'inventaire complet : on compte chaque lot en rayon, on écrit ce qu'on a
/// trouvé ; seuls les écarts sont enregistrés (le stock connu devient celui
/// compté).
class InventaireScreen extends StatefulWidget {
  const InventaireScreen({super.key});

  @override
  State<InventaireScreen> createState() => _InventaireScreenState();
}

class _InventaireScreenState extends State<InventaireScreen> {
  final _service = PharmacieService();
  final _comptes = <String, TextEditingController>{};
  List<Produit>? _produits;
  String _q = '';
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    for (final c in _comptes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final l = await _service.produits();
      if (mounted) setState(() => _produits = l);
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  TextEditingController _compte(String lot) =>
      _comptes.putIfAbsent(lot, TextEditingController.new);

  /// Les lots dont le compte diffère du stock connu.
  List<(LotProduit, int)> get _ecarts => [
    for (final p in _produits ?? const <Produit>[])
      for (final l in p.lots)
        if (int.tryParse(_compte(l.uuid).text) case final n?)
          if (n != l.quantite) (l, n),
  ];

  Future<void> _enregistrer() async {
    final ecarts = _ecarts;
    if (ecarts.isEmpty) {
      _dire('Aucun écart : le stock est juste.');
      return;
    }
    setState(() => _envoi = true);
    try {
      for (final (lot, n) in ecarts) {
        await _service.inventorier(lot.uuid, n);
      }
      if (!mounted) return;
      _dire('Inventaire enregistré : ${ecarts.length} lot(s) corrigé(s).');
      Navigator.pop(context, true);
    } on DioException catch (e) {
      _dire(messageErreur(e));
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _produits;
    final q = _q.toLowerCase();
    final liste = (l ?? const <Produit>[])
        .where(
          (p) =>
              p.lots.isNotEmpty &&
              (q.isEmpty || p.nom.toLowerCase().contains(q)),
        )
        .toList();
    final ecarts = _ecarts.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Inventaire')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _envoi || l == null ? null : _enregistrer,
              child: Text(
                ecarts == 0
                    ? 'Enregistrer l’inventaire'
                    : 'Enregistrer ($ecarts écart${ecarts > 1 ? 's' : ''})',
              ),
            ),
          ),
        ),
      ),
      body: l == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Comptez ce qu’il y a en rayon, en unités (comprimés, sachets, pièces). Laissez vide ce que vous n’avez pas compté.',
                  style: TextStyle(color: Kolors.kTextMuted),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(
                    hintText: 'Chercher un produit',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                for (final p in liste)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nom,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          for (final lot in p.lots)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Lot ${lot.numero ?? '—'}${lot.peremption == null ? '' : ' · périme ${lot.peremption}'}\nConnu : ${lot.quantite}',
                                      style: TextStyle(
                                        color: lot.perime ? Kolors.kRed : null,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: TextField(
                                      controller: _compte(lot.uuid),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        labelText: 'Compté',
                                        isDense: true,
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
            ),
    );
  }
}
