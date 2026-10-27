import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../compte/compte_api.dart';
import '../../core/api/api_client.dart';

/// Ses visites : ce qui a été fait, ce qu'on a payé, ce qui reste.
class MesVisitesScreen extends StatefulWidget {
  const MesVisitesScreen({super.key});

  @override
  State<MesVisitesScreen> createState() => _MesVisitesScreenState();
}

class _MesVisitesScreenState extends State<MesVisitesScreen> {
  List<Visite>? _visites;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    CompteApi()
        .mesVisites()
        .then((d) {
          if (mounted) {
            setState(() => _visites = d.map(Visite.fromJson).toList());
          }
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

  @override
  Widget build(BuildContext context) {
    final v = _visites;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes paiements')),
      body: v == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : v.isEmpty
          ? const Center(
              child: Text(
                'Aucune visite ces 3 derniers mois.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final visite in v)
                  Card(
                    child: ExpansionTile(
                      title: Text(
                        visite.etablissement ?? 'Visite',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${visite.ouverteAt == null ? '' : DateFormat('d MMM yyyy', 'fr').format(visite.ouverteAt!)} · '
                        '${visite.reste > 0 ? 'reste ${formatMontant(visite.reste, visite.devise)}' : 'payé ${formatMontant(visite.paye, visite.devise)}'}',
                      ),
                      children: [
                        for (final l in visite.lignes)
                          ListTile(
                            dense: true,
                            title: Text(
                              l.quantite > 1
                                  ? '${l.quantite} × ${l.libelle}'
                                  : l.libelle,
                            ),
                            trailing: Text(
                              formatMontant(l.montant, visite.devise),
                            ),
                          ),
                        for (final e in visite.encaissements)
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.check_circle_rounded,
                              color: Kolors.kSuccess,
                            ),
                            title: Text('Payé · ${e.moyenLabel}'),
                            subtitle: e.reference == null
                                ? null
                                : Text('Réf. ${e.reference}'),
                            trailing: Text(
                              formatMontant(e.montant, visite.devise),
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
