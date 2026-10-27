import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../compte/compte_api.dart';
import '../../compte/compte_controller.dart';
import '../../compte/mes_tickets_controller.dart';
import '../../ma_sante/etablissement_public.dart';
import '../compte/connexion_screen.dart';
import '../file/ticket_carte.dart';
import '../../common/widgets/feuille.dart';

/// Prendre un ticket sans se déplacer : on choisit le service, on voit
/// l'attente, et l'on est prévenu quand son tour approche.
Future<void> prendreTicket(BuildContext context, Etablissement e) async {
  if (!context.read<CompteController>().connecte) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ConnexionScreen()));
    return;
  }
  final ticket = await feuille<dynamic>(
    context: context,
    showDragHandle: true,
    // Beaucoup de services : la feuille grandit puis défile.
    isScrollControlled: true,
    builder: (_) => _Services(etablissement: e),
  );
  if (ticket != null && context.mounted) {
    await afficherTicket(context, ticket, imprimer: false);
  }
}

class _Services extends StatefulWidget {
  const _Services({required this.etablissement});

  final Etablissement etablissement;

  @override
  State<_Services> createState() => _ServicesState();
}

class _ServicesState extends State<_Services> {
  List<Map<String, dynamic>>? _services;
  String? _erreur;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    CompteApi()
        .fileEtablissement(widget.etablissement.uuid)
        .then((data) {
          if (!mounted) return;
          setState(() {
            _services = (data['services'] as List)
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .where((s) => s['ticket_distance'] == true)
                .toList();
          });
        })
        .catchError((_) {
          if (mounted) {
            setState(() => _erreur = 'Impossible de charger la file.');
          }
        });
  }

  Future<void> _prendre(String serviceUuid) async {
    setState(() => _envoi = true);
    try {
      final t = await context.read<MesTicketsController>().prendre(serviceUuid);
      if (mounted) Navigator.pop(context, t);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (mounted) {
        setState(() {
          _envoi = false;
          _erreur = data is Map && data['message'] != null
              ? data['message'].toString()
              : 'Ticket impossible. Vérifiez la connexion.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Prendre un ticket',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Kolors.kTextHigh,
              ),
            ),
            Text(
              widget.etablissement.nom,
              style: const TextStyle(color: Kolors.kTextMuted),
            ),
            const SizedBox(height: 12),
            if (_erreur != null)
              Text(_erreur!, style: const TextStyle(color: Kolors.kRed))
            else if (_services == null)
              const Center(child: CircularProgressIndicator())
            else if (_services!.isEmpty)
              const Text('Pas de ticket à distance dans cet établissement.')
            else
              for (final s in _services!)
                Card(
                  child: ListTile(
                    title: Text(s['nom'].toString()),
                    subtitle: Text(
                      s['en_attente'] == 0
                          ? 'Pas d’attente'
                          : '${s['en_attente']} en attente · environ ${s['attente_min']} min',
                    ),
                    trailing: const Icon(Icons.confirmation_number_outlined),
                    enabled: !_envoi,
                    onTap: () => _prendre(s['uuid'].toString()),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
