import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../common/whatsapp.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../rdv/rdv_models.dart';
import '../../rdv/rdv_service.dart';
import '../file/ticket_carte.dart';
import 'agendas_screen.dart';
import 'nouveau_rdv_sheet.dart';

/// Les rendez-vous du jour : qui vient, à quelle heure, et l'arrivée qui
/// fait entrer le patient dans la file avec la priorité « rendez-vous ».
class RdvTab extends StatefulWidget {
  const RdvTab({super.key});

  @override
  State<RdvTab> createState() => _RdvTabState();
}

class _RdvTabState extends State<RdvTab> {
  final _service = RdvService();
  DateTime _jour = DateTime.now();
  List<AgendaRdv> _agendas = [];
  List<RendezVousRdv> _rdv = [];
  String? _agenda;
  bool _chargement = true;
  String? _erreur;

  String get _jourIso => DateFormat('yyyy-MM-dd').format(_jour);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      _agendas = await _service.agendas();
      _rdv = await _service.rendezVous(_jourIso, agendaUuid: _agenda);
      _erreur = null;
    } on DioException catch (e) {
      _erreur = messageErreur(e);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _decaler(int jours) {
    setState(() => _jour = _jour.add(Duration(days: jours)));
    _charger();
  }

  Future<void> _action(RendezVousRdv r, String action) async {
    if (action == 'whatsapp') {
      await envoyerWhatsApp(
        context,
        r.patientTelephone!,
        'Ngoni Santé : rappel de votre rendez-vous le ${r.jour.split('-').reversed.join('/')} à ${r.heure}'
        '${r.agendaNom == null ? '' : ' (${r.agendaNom})'}, ${r.etablissementNom}. Empêché ? Prévenez-nous.',
      );
      return;
    }
    try {
      if (action == 'arrivee') {
        final ticket = await _service.arrivee(r.uuid);
        if (mounted) await afficherTicket(context, ticket);
      } else {
        await _service.action(r.uuid, action);
      }
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
    final auth = context.watch<AuthController>();
    final gere = auth.peut('rdv.gerer');
    final libelleJour = DateFormat('EEEE d MMMM', 'fr').format(_jour);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: gere && _agendas.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await nouveauRdv(context, _agendas, _jour);
                if (ok == true) _charger();
              },
              icon: const Icon(Icons.add),
              label: const Text('Rendez-vous'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _decaler(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    libelleJour[0].toUpperCase() + libelleJour.substring(1),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Kolors.kTextHigh,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _decaler(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                if (gere)
                  IconButton(
                    tooltip: 'Agendas',
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AgendasScreen(),
                        ),
                      );
                      _charger();
                    },
                  ),
              ],
            ),
            if (_agendas.length > 1)
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tous'),
                    selected: _agenda == null,
                    onSelected: (_) {
                      setState(() => _agenda = null);
                      _charger();
                    },
                  ),
                  for (final a in _agendas)
                    ChoiceChip(
                      label: Text(a.nom),
                      selected: _agenda == a.uuid,
                      onSelected: (_) {
                        setState(() => _agenda = a.uuid);
                        _charger();
                      },
                    ),
                ],
              ),
            const SizedBox(height: 12),
            if (_chargement)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_erreur != null)
              Text(_erreur!, style: const TextStyle(color: Kolors.kRed))
            else if (_agendas.isEmpty)
              _Vide(
                texte: gere
                    ? 'Créez un agenda (un médecin, un service) pour recevoir des rendez-vous.'
                    : 'Aucun agenda dans cet établissement.',
                action: gere
                    ? () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AgendasScreen(),
                          ),
                        );
                        _charger();
                      }
                    : null,
              )
            else if (_rdv.isEmpty)
              const _Vide(texte: 'Aucun rendez-vous ce jour-là.')
            else
              Card(
                child: Column(
                  children: [
                    for (final r in _rdv)
                      _LigneRdv(
                        rdv: r,
                        gere: gere,
                        accueil: auth.peut('file.emettre') || gere,
                        onAction: (a) => _action(r, a),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.texte, this.action});

  final String texte;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            texte,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Kolors.kTextMuted),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: action,
              icon: const Icon(Icons.add),
              label: const Text('Créer un agenda'),
            ),
          ],
        ],
      ),
    );
  }
}

class _LigneRdv extends StatelessWidget {
  const _LigneRdv({
    required this.rdv,
    required this.gere,
    required this.accueil,
    required this.onAction,
  });

  final RendezVousRdv rdv;
  final bool gere;
  final bool accueil;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final couleur = switch (rdv.statut) {
      'confirme' => Kolors.kSuccess,
      'demande' => Kolors.kGold,
      'honore' => Kolors.kPrimary,
      _ => Kolors.kTextMuted,
    };
    final actions = <(String, String)>[
      if (accueil && rdv.actif) ('arrivee', 'Il est arrivé'),
      if (gere && rdv.statut == 'demande') ('confirmer', 'Confirmer'),
      if (gere && rdv.statut == 'demande') ('refuser', 'Refuser'),
      if (gere && rdv.actif) ('absent', 'Absent'),
      if (gere && rdv.actif) ('annuler', 'Annuler'),
      if (rdv.actif && (rdv.patientTelephone ?? '').isNotEmpty)
        ('whatsapp', 'Rappel WhatsApp'),
    ];
    return ListTile(
      leading: Text(
        rdv.heure,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: Kolors.kPrimary,
        ),
      ),
      title: Text(rdv.patientNom ?? '—'),
      subtitle: Text(
        [
          if (rdv.agendaNom != null) rdv.agendaNom!,
          if (rdv.motif != null) rdv.motif!,
          if (rdv.patientTelephone != null) rdv.patientTelephone!,
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rdv.statutLabel,
            style: TextStyle(color: couleur, fontWeight: FontWeight.w700),
          ),
          if (actions.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: onAction,
              itemBuilder: (_) => [
                for (final a in actions)
                  PopupMenuItem(value: a.$1, child: Text(a.$2)),
              ],
            ),
        ],
      ),
    );
  }
}
