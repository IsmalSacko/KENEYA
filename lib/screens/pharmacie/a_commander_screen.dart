import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/utils/kcolors.dart';
import '../../common/whatsapp.dart';
import '../../core/api/api_client.dart';
import '../../pharmacie/pharmacie_models.dart';
import '../../pharmacie/pharmacie_service.dart';

/// Ce qu'il faut recommander : les produits sous le seuil, rangés par
/// grossiste, avec la quantité qui remet du stock d'avance. La commande part
/// par WhatsApp au grossiste, ou se copie.
class ACommanderScreen extends StatefulWidget {
  const ACommanderScreen({super.key});

  @override
  State<ACommanderScreen> createState() => _ACommanderScreenState();
}

class _ACommanderScreenState extends State<ACommanderScreen> {
  List<ACommander>? _liste;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    PharmacieService()
        .aCommander()
        .then((l) {
          if (mounted) setState(() => _liste = l);
        })
        .catchError((Object e) {
          if (mounted) {
            setState(
              () => _erreur = e is DioException
                  ? messageErreur(e)
                  : 'Indisponible.',
            );
          }
        });
  }

  String _commande(List<ACommander> produits) => [
    'Bonjour, voici notre commande :',
    for (final p in produits)
      '• ${p.nom} : ${p.boites} boîte${p.boites > 1 ? 's' : ''}',
    'Merci.',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    final parGrossiste = <String, List<ACommander>>{};
    for (final p in l ?? const <ACommander>[]) {
      parGrossiste
          .putIfAbsent(p.fournisseur ?? 'Sans grossiste', () => [])
          .add(p);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('À commander')),
      body: l == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : l.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Rien à commander : tous les produits sont au-dessus de leur seuil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Kolors.kTextMuted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final g in parGrossiste.entries)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.key,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final p in g.value)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.nom),
                              subtitle: Text(
                                'Il en reste ${p.stockUnites} unité(s)',
                              ),
                              trailing: Text(
                                '${p.boites} boîte${p.boites > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (g.value.first.telephoneFournisseur != null)
                                ElevatedButton.icon(
                                  onPressed: () => envoyerWhatsApp(
                                    context,
                                    g.value.first.telephoneFournisseur!,
                                    _commande(g.value),
                                  ),
                                  icon: const Icon(Icons.chat_outlined),
                                  label: const Text('Commander par WhatsApp'),
                                ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: _commande(g.value)),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Commande copiée.'),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('Copier'),
                              ),
                            ],
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
