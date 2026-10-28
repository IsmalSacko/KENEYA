import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../common/utils/kcolors.dart';
import '../../core/api/api_client.dart';
import '../../pharmacie/pharmacie_models.dart';
import '../../pharmacie/pharmacie_service.dart';

/// Tout ce qui est entré et sorti d'un produit : réceptions, ventes,
/// inventaires, retraits. Le plus récent d'abord.
class HistoriqueProduitScreen extends StatefulWidget {
  const HistoriqueProduitScreen({required this.produit, super.key});

  final Produit produit;

  @override
  State<HistoriqueProduitScreen> createState() =>
      _HistoriqueProduitScreenState();
}

class _HistoriqueProduitScreenState extends State<HistoriqueProduitScreen> {
  List<Map<String, dynamic>>? _mouvements;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    PharmacieService()
        .mouvements(widget.produit.uuid)
        .then((m) {
          if (mounted) setState(() => _mouvements = m);
        })
        .catchError((Object e) {
          if (mounted) {
            setState(
              () => _erreur = e is DioException
                  ? messageErreur(e)
                  : 'Chargement impossible.',
            );
          }
        });
  }

  /// « 2026-10-28 14:05:00 » → « 28/10/2026 14:05 ».
  static String _date(dynamic brut) {
    final d = DateTime.tryParse('$brut');
    if (d == null) return '';
    String n(int x) => x.toString().padLeft(2, '0');
    return '${n(d.day)}/${n(d.month)}/${d.year} ${n(d.hour)}:${n(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final m = _mouvements;
    return Scaffold(
      appBar: AppBar(title: Text(widget.produit.nom)),
      body: m == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : m.isEmpty
          ? const Center(
              child: Text(
                'Aucun mouvement pour l’instant.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: m.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final x = m[i];
                final entree = x['entree'] == true;
                final boites = int.tryParse('${x['boites']}') ?? 0;
                return ListTile(
                  leading: Icon(
                    entree
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                    color: entree ? Kolors.kSuccess : Kolors.kRed,
                  ),
                  title: Text('${x['commentaire'] ?? x['type']}'),
                  subtitle: Text(_date(x['date'])),
                  trailing: Text(
                    '${entree ? '+' : '−'}${x['quantite']} unité(s)'
                    '${boites > 0 ? '\n$boites boîte(s)' : ''}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: entree ? Kolors.kSuccess : Kolors.kRed,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
