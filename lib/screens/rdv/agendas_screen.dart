import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/utils/kcolors.dart';
import '../../core/api/api_client.dart';
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

  Future<void> _editer([AgendaRdv? a]) async {
    final donnees = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _EditionAgenda(agenda: a, services: _services),
      ),
    );
    if (donnees == null) return;
    try {
      await _service.enregistrerAgenda(donnees, uuid: a?.uuid);
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _absence(AgendaRdv a) async {
    final periode = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Absence de ${a.nom}',
    );
    if (periode == null) return;
    final f = DateFormat('yyyy-MM-dd');
    try {
      await _service.ajouterAbsence(
        a.uuid,
        f.format(periode.start),
        f.format(periode.end),
        null,
      );
      await _charger();
      _dire(
        'Pas de rendez-vous du ${DateFormat('d/MM').format(periode.start)} au ${DateFormat('d/MM').format(periode.end)}.',
      );
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
                    child: ListTile(
                      title: Text(
                        a.nom,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        [
                          '${a.dureeCreneau} min',
                          if (a.placesParCreneau > 1)
                            '${a.placesParCreneau} patients par créneau',
                          if (a.serviceNom != null) a.serviceNom!,
                          a.reservationEnLigne
                              ? 'réservation en ligne'
                              : 'au téléphone seulement',
                          _resumeHoraires(a.horaires),
                        ].join(' · '),
                      ),
                      onTap: () => _editer(a),
                      trailing: IconButton(
                        tooltip: 'Absence',
                        icon: const Icon(Icons.beach_access_outlined),
                        onPressed: () => _absence(a),
                      ),
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
  const _EditionAgenda({required this.agenda, required this.services});

  final AgendaRdv? agenda;
  final List<ServiceFile> services;

  @override
  State<_EditionAgenda> createState() => _EditionAgendaState();
}

class _EditionAgendaState extends State<_EditionAgenda> {
  late final _nom = TextEditingController(text: widget.agenda?.nom);
  late int _duree = widget.agenda?.dureeCreneau ?? 15;
  late int _places = widget.agenda?.placesParCreneau ?? 1;
  late bool _enLigne = widget.agenda?.reservationEnLigne ?? true;
  late bool _auto = widget.agenda?.validationAuto ?? true;
  late String? _serviceUuid =
      widget.agenda?.serviceUuid ?? widget.services.firstOrNull?.uuid;

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
              onPressed: () {
                if (_nom.text.trim().isEmpty) return;
                Navigator.pop(context, {
                  'nom': _nom.text.trim(),
                  'service_uuid': _serviceUuid,
                  'duree_creneau_min': _duree,
                  'places_par_creneau': _places,
                  'reservation_en_ligne': _enLigne,
                  'validation_auto': _auto,
                  'horaires': _horaires.values
                      .expand((l) => l)
                      .map((h) => h.toJson())
                      .toList(),
                });
              },
              child: const Text('Enregistrer'),
            ),
          ),
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
                      if (fin == null) return;
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
