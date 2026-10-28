import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/confirmer.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../services/user_service.dart';
import '../../file/file_models.dart';
import '../../file/file_service.dart';
import '../../rdv/rdv_models.dart';
import '../../rdv/rdv_service.dart';

/// Les agendas de l'établissement : un médecin, un service (vaccination,
/// CPN…), avec ses heures d'ouverture, la durée d'un rendez-vous et le
/// nombre de patients par créneau.
class AgendasScreen extends StatefulWidget {
  const AgendasScreen({super.key});

  @override
  State<AgendasScreen> createState() => _AgendasScreenState();
}

class _AgendasScreenState extends State<AgendasScreen> {
  final _service = RdvService();
  List<AgendaRdv> _agendas = [];
  List<ServiceFile> _services = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final agendas = await _service.agendas();
      List<ServiceFile> services = [];
      try {
        services = await FileService().services();
      } on DioException {
        // Pas de module file : l'agenda n'a pas de service.
      }
      if (mounted) {
        setState(() {
          _agendas = agendas;
          _services = services;
        });
      }
    } on DioException catch (e) {
      _dire(messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  /// L'éditeur enregistre lui-même et ne se ferme qu'une fois l'agenda
  /// accepté : une erreur ne fait rien perdre de ce qui a été saisi.
  Future<void> _editer([AgendaRdv? a]) async {
    final fait = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EditionAgenda(
          agenda: a,
          services: _services,
          enregistrer: (donnees) =>
              _service.enregistrerAgenda(donnees, uuid: a?.uuid),
          supprimer: a == null ? null : () => _service.supprimerAgenda(a.uuid),
        ),
      ),
    );
    if (fait == true) await _charger();
  }

  Future<void> _absence(AgendaRdv a) async {
    final periode = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Absence de ${a.nom}',
    );
    if (periode == null || !mounted) return;
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Absence du ${DateFormat('d/MM').format(periode.start)} au ${DateFormat('d/MM').format(periode.end)}',
        ),
        content: TextField(
          controller: motif,
          autofocus: true,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Raison (facultatif)',
            hintText: 'ex. Congé, formation',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final f = DateFormat('yyyy-MM-dd');
    try {
      final touches = await _service.ajouterAbsence(
        a.uuid,
        f.format(periode.start),
        f.format(periode.end),
        motif.text.trim().isEmpty ? null : motif.text.trim(),
      );
      await _charger();
      if (!mounted) return;
      if (touches.isEmpty) {
        _dire(
          'Pas de rendez-vous du ${DateFormat('d/MM').format(periode.start)} au ${DateFormat('d/MM').format(periode.end)}.',
        );
        return;
      }
      // Des patients ont déjà rendez-vous ces jours-là : à déplacer.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            '${touches.length} rendez-vous pendant l’absence',
            style: const TextStyle(color: Kolors.kRed),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ils sont toujours prévus : déplacez-les ou annulez-les dans Rendez-vous (le patient est prévenu par SMS).',
                ),
                const SizedBox(height: 10),
                for (final r in touches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${DateFormat('EEE d/MM', 'fr').format(DateTime.tryParse(r.jour) ?? periode.start)} à ${r.heure} — ${r.patientNom ?? '—'}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _retirerAbsence(AgendaRdv a, AbsenceRdv x) async {
    final ok = await confirmer(
      context,
      titre: 'Retirer cette absence ?',
      texte:
          '${a.nom} reprend les rendez-vous du ${DateFormat('d/MM').format(x.du)} au ${DateFormat('d/MM').format(x.au)}.',
      action: 'Retirer',
    );
    if (!ok) return;
    try {
      await _service.supprimerAbsence(x.id);
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editer(),
        icon: const Icon(Icons.add),
        label: const Text('Agenda'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (_agendas.isEmpty)
                  const Text(
                    'Un agenda par médecin ou par service (vaccination, CPN, labo…).',
                    style: TextStyle(color: Kolors.kTextMuted),
                  ),
                for (final a in _agendas)
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text(
                            a.actif ? a.nom : '${a.nom} · en pause',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: a.actif ? null : Kolors.kTextMuted,
                            ),
                          ),
                          subtitle: Text(
                            [
                              '${a.dureeCreneau} min',
                              if (a.placesParCreneau > 1)
                                '${a.placesParCreneau} patients par créneau',
                              ?a.membreNom,
                              if (a.serviceNom != null) a.serviceNom!,
                              a.reservationEnLigne
                                  ? 'réservation en ligne'
                                  : 'au téléphone seulement',
                              _resumeHoraires(a.horaires),
                            ].join(' · '),
                          ),
                          onTap: () => _editer(a),
                          trailing: IconButton(
                            tooltip: 'Ajouter une absence',
                            icon: const Icon(Icons.beach_access_outlined),
                            onPressed: () => _absence(a),
                          ),
                        ),
                        if (a.absences.any((x) => x.aVenir))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final x in a.absences.where(
                                  (x) => x.aVenir,
                                ))
                                  InputChip(
                                    avatar: const Icon(
                                      Icons.beach_access_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      'Absent du ${DateFormat('d/MM').format(x.du)} au ${DateFormat('d/MM').format(x.au)}'
                                      '${x.motif == null ? '' : ' · ${x.motif}'}',
                                    ),
                                    deleteButtonTooltipMessage:
                                        'Retirer l’absence',
                                    onDeleted: () => _retirerAbsence(a, x),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  String _resumeHoraires(List<HoraireRdv> h) {
    if (h.isEmpty) return 'aucune heure d’ouverture';
    final jours = h.map((x) => x.jour).toSet().toList()..sort();
    return jours.map((j) => joursSemaine[j - 1].substring(0, 3)).join(', ');
  }
}

/// Création et modification d'un agenda, horaires compris.
class _EditionAgenda extends StatefulWidget {
  const _EditionAgenda({
    required this.agenda,
    required this.services,
    required this.enregistrer,
    this.supprimer,
  });

  final AgendaRdv? agenda;
  final List<ServiceFile> services;

  /// Envoie l'agenda ; la page se ferme seulement si c'est accepté.
  final Future<void> Function(Map<String, dynamic> donnees) enregistrer;
  final Future<void> Function()? supprimer;

  @override
  State<_EditionAgenda> createState() => _EditionAgendaState();
}

class _EditionAgendaState extends State<_EditionAgenda> {
  static const _delais = [0, 1, 2, 4, 12, 24, 48];
  static const _horizons = [7, 14, 30, 60, 90, 180, 365];

  late final _nom = TextEditingController(text: widget.agenda?.nom);
  late int _duree = widget.agenda?.dureeCreneau ?? 15;
  late int _places = widget.agenda?.placesParCreneau ?? 1;
  late bool _enLigne = widget.agenda?.reservationEnLigne ?? true;
  late bool _auto = widget.agenda?.validationAuto ?? true;
  late String? _serviceUuid =
      widget.agenda?.serviceUuid ?? widget.services.firstOrNull?.uuid;
  late bool _actif = widget.agenda?.actif ?? true;
  late String? _membre = widget.agenda?.membreUuid;
  late int _delai = widget.agenda?.delaiMinHeures ?? 0;
  late int _horizon = widget.agenda?.horizonJours ?? 60;
  bool _envoi = false;

  /// L'équipe de l'établissement : le soignant de l'agenda.
  List<(String, String)> _membres = [];

  @override
  void initState() {
    super.initState();
    final ici = context.read<AuthController>().currentUser?.etablissementId;
    UserService()
        .getUsersInMyEtablissements()
        .then((l) {
          if (!mounted) return;
          setState(() {
            _membres = [
              for (final u in l.whereType<Map>())
                if (u['uuid'] != null &&
                    '${u['etablissement_id']}' == '$ici' &&
                    '${u['name'] ?? ''}'.trim().isNotEmpty)
                  ('${u['uuid']}', '${u['name']}'),
            ];
          });
        })
        .catchError((Object _) {});
  }

  void _dire(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Une plage qui finit avant de commencer : on le dit tout de suite.
  String? _plageFausse() {
    for (final l in _horaires.entries) {
      for (final h in l.value) {
        if (h.fin.compareTo(h.debut) <= 0) {
          return '${joursSemaine[l.key - 1]} : la fin (${h.fin}) doit venir après le début (${h.debut}).';
        }
      }
    }
    return null;
  }

  Future<void> _enregistrer() async {
    if (_nom.text.trim().isEmpty) {
      _dire('Donnez un nom à l’agenda (ex. Dr Diarra).');
      return;
    }
    final faux = _plageFausse();
    if (faux != null) {
      _dire(faux);
      return;
    }
    setState(() => _envoi = true);
    try {
      await widget.enregistrer({
        'nom': _nom.text.trim(),
        'service_uuid': _serviceUuid,
        'membre_uuid': _membre,
        'duree_creneau_min': _duree,
        'places_par_creneau': _places,
        'reservation_en_ligne': _enLigne,
        'validation_auto': _auto,
        'actif': _actif,
        'delai_min_heures': _delai,
        'horizon_jours': _horizon,
        'horaires': _horaires.values
            .expand((l) => l)
            .map((h) => h.toJson())
            .toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      _dire(messageErreur(e));
    }
  }

  Future<void> _supprimer() async {
    final ok = await confirmer(
      context,
      titre: 'Supprimer l’agenda ${widget.agenda!.nom} ?',
      texte:
          'Il disparaît, avec ses heures d’ouverture. Pour l’arrêter un temps, mettez-le plutôt en pause.',
      action: 'Supprimer',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _envoi = true);
    try {
      await widget.supprimer!();
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      _dire(messageErreur(e));
    }
  }

  /// Une plage par jour (matin), une seconde facultative (après-midi).
  late final Map<int, List<HoraireRdv>> _horaires = {
    for (var j = 1; j <= 7; j++)
      j:
          (widget.agenda?.horaires ??
                  (widget.agenda == null && j <= 5
                      ? [HoraireRdv(j, '08:00', '12:00')]
                      : const <HoraireRdv>[]))
              .where((h) => h.jour == j)
              .toList(),
  };

  Future<String?> _heure(String depart) async {
    final parts = depart.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.agenda == null ? 'Nouvel agenda' : 'Modifier l’agenda',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nom,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nom (ex. Dr Diarra, Vaccination)',
            ),
          ),
          const SizedBox(height: 10),
          if (widget.services.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _serviceUuid,
              decoration: const InputDecoration(
                labelText: 'File d’attente à l’arrivée',
              ),
              items: [
                for (final s in widget.services)
                  DropdownMenuItem(value: s.uuid, child: Text(s.nom)),
              ],
              onChanged: (v) => setState(() => _serviceUuid = v),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _duree,
                  decoration: const InputDecoration(
                    labelText: 'Durée d’un rendez-vous',
                  ),
                  items: [
                    for (final m in [5, 10, 15, 20, 30, 45, 60])
                      DropdownMenuItem(value: m, child: Text('$m min')),
                  ],
                  onChanged: (v) => setState(() => _duree = v ?? _duree),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _places,
                  decoration: const InputDecoration(
                    labelText: 'Patients par créneau',
                  ),
                  items: [
                    for (final p in [1, 2, 3, 5, 10, 20])
                      DropdownMenuItem(value: p, child: Text('$p')),
                  ],
                  onChanged: (v) => setState(() => _places = v ?? _places),
                ),
              ),
            ],
          ),
          if (_membres.isNotEmpty) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _membres.any((m) => m.$1 == _membre)
                  ? _membre
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Soignant (facultatif)',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Aucun')),
                for (final m in _membres)
                  DropdownMenuItem(value: m.$1, child: Text(m.$2)),
              ],
              onChanged: (v) => setState(() => _membre = v),
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Agenda ouvert'),
            subtitle: Text(
              _actif
                  ? 'Il prend des rendez-vous.'
                  : 'En pause : plus de nouveaux rendez-vous ; ceux déjà pris restent.',
            ),
            value: _actif,
            onChanged: (v) => setState(() => _actif = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Les patients réservent depuis l’app'),
            value: _enLigne,
            onChanged: (v) => setState(() => _enLigne = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Confirmer tout de suite'),
            subtitle: const Text('Sinon, l’accueil valide chaque demande.'),
            value: _auto,
            onChanged: (v) => setState(() => _auto = v),
          ),
          if (_enLigne)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _delais.contains(_delai) ? _delai : null,
                    decoration: const InputDecoration(
                      labelText: 'Réserver au plus tard',
                    ),
                    items: [
                      for (final h in _delais)
                        DropdownMenuItem(
                          value: h,
                          child: Text(
                            h == 0
                                ? 'Jusqu’à l’heure'
                                : (h < 24
                                      ? '$h h avant'
                                      : '${h ~/ 24} j avant'),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _delai = v ?? _delai),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _horizons.contains(_horizon)
                        ? _horizon
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Réserver jusqu’à',
                    ),
                    items: [
                      for (final j in _horizons)
                        DropdownMenuItem(
                          value: j,
                          child: Text(j < 30 ? '$j jours' : '${j ~/ 30} mois'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _horizon = v ?? _horizon),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          const Text(
            'Heures d’ouverture',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          for (var j = 1; j <= 7; j++) _ligneJour(j),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _envoi ? null : _enregistrer,
              child: const Text('Enregistrer'),
            ),
          ),
          if (widget.supprimer != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Kolors.kRed),
              onPressed: _envoi ? null : _supprimer,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Supprimer l’agenda'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ligneJour(int j) {
    final plages = _horaires[j]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Row(
              children: [
                Checkbox(
                  value: plages.isNotEmpty,
                  onChanged: (v) => setState(() {
                    _horaires[j] = v == true
                        ? [HoraireRdv(j, '08:00', '12:00')]
                        : [];
                  }),
                ),
                Text(joursSemaine[j - 1].substring(0, 3)),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < plages.length; i++)
                  InputChip(
                    label: Text('${plages[i].debut} – ${plages[i].fin}'),
                    onPressed: () async {
                      final debut = await _heure(plages[i].debut);
                      if (debut == null || !mounted) return;
                      final fin = await _heure(plages[i].fin);
                      if (fin == null || !mounted) return;
                      if (fin.compareTo(debut) <= 0) {
                        _dire(
                          'La fin ($fin) doit venir après le début ($debut).',
                        );
                        return;
                      }
                      setState(() => plages[i] = HoraireRdv(j, debut, fin));
                    },
                    onDeleted: () => setState(() => plages.removeAt(i)),
                  ),
                if (plages.isNotEmpty && plages.length < 2)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Après-midi'),
                    onPressed: () => setState(
                      () => plages.add(HoraireRdv(j, '15:00', '18:00')),
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
