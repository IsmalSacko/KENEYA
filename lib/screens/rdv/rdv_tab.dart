import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../common/whatsapp.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../common/widgets/confirmer.dart';
import '../../patients/patients_service.dart';
import '../patients/patient_screen.dart';
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

  /// Retrouver le rendez-vous d'un patient, sans connaître le jour.
  final _recherche = TextEditingController();
  Timer? _attente;

  String get _jourIso => DateFormat('yyyy-MM-dd').format(_jour);

  bool get _cherche => _recherche.text.trim().length >= 2;

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      _agendas = await _service.agendas();
      final recherche = _recherche.text.trim();
      final rdv = _cherche
          ? await _service.rechercher(recherche, agendaUuid: _agenda)
          : await _service.rendezVous(_jourIso, agendaUuid: _agenda);
      // Une réponse arrivée après une autre frappe ne compte plus.
      if (recherche != _recherche.text.trim()) return;
      _rdv = rdv;
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

  Future<void> _choisirJour() async {
    final choix = await showDatePicker(
      context: context,
      initialDate: _jour,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Rendez-vous de quel jour ?',
    );
    if (choix == null) return;
    setState(() => _jour = choix);
    _charger();
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  /// Le rendez-vous ouvre la fiche du patient (ses visites, son dossier).
  Future<void> _ouvrirPatient(RendezVousRdv r) async {
    final uuid = r.dossierUuid;
    if (uuid == null) return;
    try {
      final p = await PatientsService().fiche(uuid);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PatientScreen(patient: p)));
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  /// Confirmer : une demande venue sans heure reçoit d'abord son créneau.
  Future<void> _confirmer(RendezVousRdv r) async {
    if (r.creneau) {
      await _service.action(r.uuid, 'confirmer');
      return;
    }
    final choix = await choisirCreneau(
      context,
      _agendas,
      titre: 'Heure du rendez-vous de ${r.patientNom ?? 'ce patient'}',
      action: 'Confirmer à cette heure',
      agendaUuid: r.agendaUuid,
      depart: DateTime.tryParse(r.jour),
    );
    if (choix == null) return;
    await _service.action(
      r.uuid,
      'confirmer',
      debut: choix.$2.debut,
      agendaUuid: choix.$1,
    );
    _dire('Confirmé le ${_date(choix.$2.jour)} à ${choix.$2.heure}.');
  }

  Future<void> _deplacer(RendezVousRdv r) async {
    final choix = await choisirCreneau(
      context,
      _agendas,
      titre: 'Déplacer le rendez-vous de ${r.patientNom ?? 'ce patient'}',
      action: 'Déplacer ici',
      agendaUuid: r.agendaUuid,
      depart: DateTime.tryParse(r.jour),
    );
    if (choix == null) return;
    await _service.deplacer(
      r.uuid,
      debut: choix.$2.debut,
      agendaUuid: choix.$1,
    );
    _dire(
      'Déplacé au ${_date(choix.$2.jour)} à ${choix.$2.heure}'
      '${(r.patientTelephone ?? '').isEmpty ? '.' : ' : le patient est prévenu par SMS.'}',
    );
  }

  String _date(String jour) =>
      DateFormat('d MMMM', 'fr').format(DateTime.tryParse(jour) ?? _jour);

  Future<void> _action(RendezVousRdv r, String action) async {
    if (action == 'patient') {
      await _ouvrirPatient(r);
      return;
    }
    if (action == 'whatsapp') {
      await envoyerWhatsApp(
        context,
        r.patientTelephone!,
        'Ngoni Santé : rappel de votre rendez-vous le ${r.jour.split('-').reversed.join('/')} à ${r.heure}'
        '${r.agendaNom == null ? '' : ' (${r.agendaNom})'}, ${r.etablissementNom}. Empêché ? Prévenez-nous.',
      );
      return;
    }
    final qui = r.patientNom ?? 'ce patient';
    final prevenu = (r.patientTelephone ?? '').isEmpty
        ? null
        : 'Le patient est prévenu par SMS.';
    try {
      switch (action) {
        case 'arrivee':
          final ticket = await _service.arrivee(r.uuid);
          if (mounted) await afficherTicket(context, ticket);
        case 'confirmer':
          await _confirmer(r);
        case 'deplacer':
          await _deplacer(r);
        case 'annuler' || 'refuser':
          final raison = await confirmerAvecRaison(
            context,
            titre: action == 'annuler'
                ? 'Annuler le rendez-vous de $qui ?'
                : 'Refuser la demande de $qui ?',
            texte: prevenu,
            action: action == 'annuler' ? 'Annuler le rendez-vous' : 'Refuser',
          );
          if (raison == null) return;
          await _service.action(r.uuid, action, raison: raison);
        case 'absent':
          if (!await confirmer(
            context,
            titre: '$qui n’est pas venu ?',
            texte: 'Le rendez-vous est noté « manqué ».',
            action: 'Absent',
          )) {
            return;
          }
          await _service.action(r.uuid, 'absent');
      }
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final gere = auth.peut('rdv.gerer');
    final libelleJour = DateFormat('EEEE d MMMM', 'fr').format(_jour);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: gere && _agendas.any((a) => a.actif)
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
                  tooltip: 'Jour précédent',
                  onPressed: _cherche ? null : () => _decaler(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _cherche ? null : _choisirJour,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _cherche
                            ? 'Rendez-vous trouvés'
                            : libelleJour[0].toUpperCase() +
                                  libelleJour.substring(1),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Kolors.kTextHigh,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Jour suivant',
                  onPressed: _cherche ? null : () => _decaler(1),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _recherche,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  labelText: 'Chercher un patient (nom, téléphone)',
                  suffixIcon: _recherche.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer la recherche',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _recherche.clear();
                            _charger();
                          },
                        ),
                ),
                onChanged: (_) {
                  setState(() {});
                  _attente?.cancel();
                  _attente = Timer(const Duration(milliseconds: 350), _charger);
                },
              ),
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
              _Vide(
                texte: _cherche
                    ? 'Aucun rendez-vous à ce nom (du mois dernier aux mois à venir).'
                    : 'Aucun rendez-vous ce jour-là.',
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final r in _rdv)
                      _LigneRdv(
                        rdv: r,
                        gere: gere,
                        accueil: auth.peut('file.emettre') || gere,
                        avecDate: _cherche,
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
    this.avecDate = false,
  });

  final RendezVousRdv rdv;
  final bool gere;
  final bool accueil;
  final ValueChanged<String> onAction;

  /// Résultat de recherche : le jour s'affiche avec l'heure.
  final bool avecDate;

  @override
  Widget build(BuildContext context) {
    final couleur = switch (rdv.statut) {
      'confirme' => Kolors.kSuccess,
      'demande' => Kolors.kGold,
      'honore' => Kolors.kPrimary,
      'absent' || 'refuse' => Kolors.kRed,
      _ => Kolors.kTextMuted,
    };
    final actions = <(String, String)>[
      // L'arrivée se note le jour même (un ticket vaut pour aujourd'hui).
      if (accueil && rdv.actif && rdv.aujourdhui) ('arrivee', 'Il est arrivé'),
      if (gere && rdv.statut == 'demande')
        ('confirmer', rdv.creneau ? 'Confirmer' : 'Fixer l’heure et confirmer'),
      if (gere && rdv.statut == 'demande') ('refuser', 'Refuser'),
      if (gere && rdv.actif && rdv.agendaUuid != null) ('deplacer', 'Déplacer'),
      if (gere && rdv.actif && rdv.creneau) ('absent', 'Absent'),
      if (gere && rdv.actif) ('annuler', 'Annuler'),
      if (rdv.actif && (rdv.patientTelephone ?? '').isNotEmpty)
        ('whatsapp', 'Rappel WhatsApp'),
      if (rdv.dossierUuid != null) ('patient', 'Fiche du patient'),
    ];
    final date = DateTime.tryParse(rdv.jour);
    return ListTile(
      onTap: rdv.dossierUuid == null ? null : () => onAction('patient'),
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (avecDate && date != null)
            Text(
              DateFormat('d MMM', 'fr').format(date),
              style: const TextStyle(fontSize: 12, color: Kolors.kTextMuted),
            ),
          Text(
            rdv.creneau ? rdv.heure : 'Heure à fixer',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: rdv.creneau ? 16 : 12,
              color: rdv.creneau ? Kolors.kPrimary : Kolors.kGold,
            ),
          ),
        ],
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rdv.statutCourt,
              style: TextStyle(
                color: couleur,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          if (actions.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Que faire ?',
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
