import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../core/api/api_client.dart';
import '../../maternite/maternite_models.dart';
import '../../maternite/maternite_service.dart';
import '../dossier/dossier_widgets.dart';
import 'carnet_screen.dart';
import '../../common/widgets/formulaire.dart';

/// Ouvre la grossesse en cours de la patiente de la visite, ou la déclare.
Future<void> ouvrirGrossesse(BuildContext context, String visite) async {
  final service = MaterniteService();
  void dire(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  try {
    var g = await service.pourVisite(visite);
    if (g == null) {
      if (!context.mounted) return;
      final donnees = await _declarer(context);
      if (donnees == null) return;
      g = await service.declarer(visite, donnees);
    }
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GrossesseScreen(grossesse: g!)));
  } on DioException catch (e) {
    if (context.mounted) dire(messageErreur(e));
  }
}

Future<Map<String, dynamic>?> _declarer(BuildContext context) {
  DateTime? ddr;
  final gestite = TextEditingController();
  final parite = TextEditingController();
  final risques = TextEditingController();
  return formulaire<Map<String, dynamic>>(
    context,
    titre: const Text('Nouvelle grossesse'),
    corps: (ctx, setState) => Column(
      spacing: 12,
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_rounded),
          title: Text(
            ddr == null
                ? 'Date des dernières règles'
                : 'DDR : ${dateCourte(ddr)}',
          ),
          onTap: () async {
            final choix = await showDatePicker(
              context: ctx,
              initialDate: DateTime.now().subtract(const Duration(days: 60)),
              firstDate: DateTime.now().subtract(const Duration(days: 300)),
              lastDate: DateTime.now(),
            );
            if (choix != null) setState(() => ddr = choix);
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: gestite,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Gestité'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: parite,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Parité'),
              ),
            ),
          ],
        ),
        TextField(
          controller: risques,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: 'Facteurs de risque (ex. HTA, césarienne)',
          ),
        ),
      ],
    ),
    actions: (ctx, setState) => [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Annuler'),
      ),
      ElevatedButton(
        onPressed: ddr == null
            ? null
            : () => Navigator.pop(ctx, {
                'ddr': DateFormat('yyyy-MM-dd').format(ddr!),
                'gestite': int.tryParse(gestite.text),
                'parite': int.tryParse(parite.text),
                'risques': risques.text.trim(),
              }),
        child: const Text('Déclarer'),
      ),
    ],
  );
}

/// Le suivi de la grossesse : CPN, puis accouchement.
class GrossesseScreen extends StatefulWidget {
  const GrossesseScreen({required this.grossesse, super.key});

  final Grossesse grossesse;

  @override
  State<GrossesseScreen> createState() => _GrossesseScreenState();
}

class _GrossesseScreenState extends State<GrossesseScreen> {
  late Grossesse _g = widget.grossesse;

  Future<void> _ouvrir(Widget ecran) async {
    final g = await Navigator.of(
      context,
    ).push<Grossesse>(MaterialPageRoute(builder: (_) => ecran));
    if (g != null && mounted) setState(() => _g = g);
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return Scaffold(
      appBar: AppBar(title: Text(g.patiente)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CarteMarque(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.enCours ? '${g.semaines} SA' : 'Accouchée',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Kolors.kJaune,
                  ),
                ),
                Text(
                  [
                    'Terme ${dateCourte(DateTime.tryParse(g.dpa))}',
                    if (g.gp.isNotEmpty) g.gp,
                  ].join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (g.prochainRdv != null && g.enCours)
                  Text(
                    'Prochaine CPN le ${dateCourte(DateTime.tryParse(g.prochainRdv!))}',
                    style: TextStyle(
                      color: Kolors.kWhite.withValues(alpha: 0.85),
                    ),
                  ),
                if (g.risques != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'À risque : ${g.risques}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (g.enCours)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _ouvrir(CpnScreen(grossesse: g)),
                  icon: const Icon(Icons.pregnant_woman_rounded),
                  label: Text('CPN ${g.cpn.length + 1}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _ouvrir(AccouchementScreen(grossesse: g)),
                  icon: const Icon(Icons.child_friendly_rounded),
                  label: const Text('Accouchement'),
                ),
              ],
            ),
          if (g.accouchement != null) ...[
            Text(
              'Accouchement le ${DateFormat('d MMM yyyy à HH:mm', 'fr').format(g.accouchement!)}'
              ' · ${modesAccouchement[g.modeAccouchement] ?? g.modeAccouchement ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final e in g.enfants)
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.child_care_rounded,
                    color: e.vivant ? Kolors.kPrimary : Kolors.kTextMuted,
                  ),
                  title: Text(e.nom ?? (e.vivant ? 'Enfant' : 'Mort-né(e)')),
                  subtitle: Text(
                    [
                      e.sexe == 'F' ? 'Fille' : 'Garçon',
                      if (e.poidsG != null) '${e.poidsG} g',
                      if (e.apgar1 != null && e.apgar5 != null)
                        'Apgar ${e.apgar1}/${e.apgar5}',
                    ].join(' · '),
                  ),
                  trailing: e.dossierUuid == null
                      ? null
                      : const Icon(Icons.vaccines_rounded),
                  onTap: e.dossierUuid == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CarnetScreen(dossierUuid: e.dossierUuid!),
                          ),
                        ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'Consultations prénatales',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (g.cpn.isEmpty)
            const Text(
              'Aucune CPN notée.',
              style: TextStyle(color: Kolors.kTextMuted),
            ),
          for (final c in g.cpn.reversed) CarteCpn(c),
        ],
      ),
    );
  }
}

class CarteCpn extends StatelessWidget {
  const CarteCpn(this.c, {super.key});

  final CpnVisite c;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CPN ${c.numero} · ${c.semaines} SA',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              [
                dateCourte(c.date),
                c.etablissement,
                ?c.praticien,
              ].where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
            ),
            if (c.resume.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(c.resume),
            ],
            if (c.observations != null) ...[
              const SizedBox(height: 4),
              Text(c.observations!),
            ],
          ],
        ),
      ),
    );
  }
}

/// La consultation prénatale.
class CpnScreen extends StatefulWidget {
  const CpnScreen({required this.grossesse, super.key});

  final Grossesse grossesse;

  @override
  State<CpnScreen> createState() => _CpnScreenState();
}

class _CpnScreenState extends State<CpnScreen> {
  final _champs = {
    for (final k in [
      'poids',
      'ta_sys',
      'ta_dia',
      'hauteur_uterine',
      'bcf',
      'tpi',
      'vat',
    ])
      k: TextEditingController(),
  };
  final _observations = TextEditingController();
  String? _presentation;
  bool _fer = true;
  bool _moustiquaire = false;
  DateTime? _revoir;
  bool _envoi = false;

  static const _libelles = {
    'poids': ('Poids', 'kg'),
    'ta_sys': ('TA systolique', 'mmHg'),
    'ta_dia': ('TA diastolique', 'mmHg'),
    'hauteur_uterine': ('Hauteur utérine', 'cm'),
    'bcf': ('BCF', '/min'),
    'tpi': ('TPI (dose de SP)', ''),
    'vat': ('VAT (dose)', ''),
  };

  Future<void> _valider() async {
    setState(() => _envoi = true);
    try {
      final g = await MaterniteService().cpn(widget.grossesse.uuid, {
        for (final e in _champs.entries)
          if (num.tryParse(e.value.text.replaceAll(',', '.')) != null)
            e.key: num.parse(e.value.text.replaceAll(',', '.')),
        'presentation': ?_presentation,
        'fer': _fer,
        'moustiquaire': _moustiquaire,
        'observations': _observations.text.trim(),
        if (_revoir != null)
          'prochain_rdv': DateFormat('yyyy-MM-dd').format(_revoir!),
      });
      if (mounted) Navigator.pop(context, g);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.grossesse;
    return Scaffold(
      appBar: AppBar(title: Text('CPN ${g.cpn.length + 1} · ${g.semaines} SA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final largeur = c.maxWidth >= 560
                  ? (c.maxWidth - 24) / 4
                  : (c.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 14,
                children: [
                  for (final e in _libelles.entries)
                    SizedBox(
                      width: largeur,
                      child: TextField(
                        controller: _champs[e.key],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: e.value.$1,
                          suffixText: e.value.$2.isEmpty ? null : e.value.$2,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Text('Présentation'),
          Wrap(
            spacing: 6,
            children: [
              for (final p in presentations.entries)
                ChoiceChip(
                  label: Text(p.value),
                  selected: _presentation == p.key,
                  onSelected: (oui) =>
                      setState(() => _presentation = oui ? p.key : null),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fer et acide folique donnés'),
            value: _fer,
            onChanged: (v) => setState(() => _fer = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Moustiquaire imprégnée donnée'),
            value: _moustiquaire,
            onChanged: (v) => setState(() => _moustiquaire = v),
          ),
          TextField(
            controller: _observations,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Observations'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_repeat_rounded),
            title: Text(
              _revoir == null
                  ? 'Prochaine CPN le…'
                  : 'Prochaine CPN le ${dateCourte(_revoir)}',
            ),
            onTap: () async {
              final choix = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 28)),
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 180)),
              );
              if (choix != null) setState(() => _revoir = choix);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _envoi ? null : _valider,
              child: const Text('Enregistrer la CPN'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Enfant {
  String sexe = 'F';
  bool vivant = true;
  final prenom = TextEditingController();
  final poids = TextEditingController();
  final apgar1 = TextEditingController();
  final apgar5 = TextEditingController();
}

/// L'accouchement : chaque enfant né vivant reçoit son dossier.
class AccouchementScreen extends StatefulWidget {
  const AccouchementScreen({required this.grossesse, super.key});

  final Grossesse grossesse;

  @override
  State<AccouchementScreen> createState() => _AccouchementScreenState();
}

class _AccouchementScreenState extends State<AccouchementScreen> {
  final List<_Enfant> _enfants = [_Enfant()];
  final _observations = TextEditingController();
  String _mode = 'voie_basse';
  DateTime _quand = DateTime.now();
  bool _envoi = false;

  Future<void> _valider() async {
    setState(() => _envoi = true);
    try {
      final g = await MaterniteService().accoucher(widget.grossesse.uuid, {
        'date_heure': _quand.toUtc().toIso8601String(),
        'mode': _mode,
        'observations': _observations.text.trim(),
        'enfants': [
          for (final e in _enfants)
            {
              'sexe': e.sexe,
              'vivant': e.vivant,
              'prenom': e.prenom.text.trim(),
              'poids_g': ?int.tryParse(e.poids.text),
              'apgar1': ?int.tryParse(e.apgar1.text),
              'apgar5': ?int.tryParse(e.apgar5.text),
            },
        ],
      });
      if (mounted) Navigator.pop(context, g);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  Widget _nombre(TextEditingController c, String libelle) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: libelle),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Accouchement · ${widget.grossesse.patiente}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: Text(DateFormat('d MMM yyyy à HH:mm', 'fr').format(_quand)),
            subtitle: const Text('Toucher pour changer l’heure'),
            onTap: () async {
              final h = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_quand),
              );
              if (h == null) return;
              final n = DateTime.now();
              var choix = DateTime(n.year, n.month, n.day, h.hour, h.minute);
              // Une heure « future » est celle de la nuit passée.
              if (choix.isAfter(n)) {
                choix = choix.subtract(const Duration(days: 1));
              }
              setState(() => _quand = choix);
            },
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final m in modesAccouchement.entries)
                ChoiceChip(
                  label: Text(m.value),
                  selected: _mode == m.key,
                  onSelected: (_) => setState(() => _mode = m.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, e) in _enfants.indexed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _enfants.length > 1 ? 'Enfant ${i + 1}' : 'Enfant',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (_enfants.length > 1)
                          IconButton(
                            tooltip: 'Retirer',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () =>
                                setState(() => _enfants.removeAt(i)),
                          ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Fille'),
                          selected: e.sexe == 'F',
                          onSelected: (_) => setState(() => e.sexe = 'F'),
                        ),
                        ChoiceChip(
                          label: const Text('Garçon'),
                          selected: e.sexe == 'M',
                          onSelected: (_) => setState(() => e.sexe = 'M'),
                        ),
                        FilterChip(
                          label: const Text('Mort-né(e)'),
                          selected: !e.vivant,
                          onSelected: (v) => setState(() => e.vivant = !v),
                        ),
                      ],
                    ),
                    if (e.vivant)
                      TextField(
                        controller: e.prenom,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Prénom (facultatif)',
                        ),
                      ),
                    _nombre(e.poids, 'Poids (g)'),
                    Row(
                      children: [
                        Expanded(child: _nombre(e.apgar1, 'Apgar 1 min')),
                        const SizedBox(width: 8),
                        Expanded(child: _nombre(e.apgar5, 'Apgar 5 min')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _enfants.add(_Enfant())),
            icon: const Icon(Icons.add),
            label: const Text('Jumeaux : un autre enfant'),
          ),
          TextField(
            controller: _observations,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Observations'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _envoi ? null : _valider,
              child: const Text('Enregistrer l’accouchement'),
            ),
          ),
        ],
      ),
    );
  }
}
