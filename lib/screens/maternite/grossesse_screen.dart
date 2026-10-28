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
      final donnees = await _formGrossesse(context);
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

/// Déclarer la grossesse, ou corriger [g] (DDR, gestité, parité, risques).
Future<Map<String, dynamic>?> _formGrossesse(
  BuildContext context, {
  Grossesse? g,
}) {
  DateTime? ddr = DateTime.tryParse(g?.ddr ?? '');
  final gestite = TextEditingController(text: g?.gestite?.toString() ?? '');
  final parite = TextEditingController(text: g?.parite?.toString() ?? '');
  final risques = TextEditingController(text: g?.risques ?? '');
  return formulaire<Map<String, dynamic>>(
    context,
    titre: Text(g == null ? 'Nouvelle grossesse' : 'Modifier la grossesse'),
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
              initialDate:
                  ddr ?? DateTime.now().subtract(const Duration(days: 60)),
              firstDate: DateTime.now().subtract(const Duration(days: 300)),
              lastDate: DateTime.now(),
            );
            if (choix != null) setState(() => ddr = choix);
          },
        ),
        if (g != null && ddr != null)
          Text(
            'Terme : ${dateCourte(ddr!.add(const Duration(days: 280)))}',
            style: const TextStyle(color: Kolors.kTextMuted),
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
        child: Text(g == null ? 'Déclarer' : 'Enregistrer'),
      ),
    ],
  );
}

/// Clore la grossesse sans accouchement ici : l'issue et la date.
Future<(String, DateTime)?> _clore(BuildContext context) {
  String? issue;
  var le = DateUtils.dateOnly(DateTime.now());
  String? erreur;
  return formulaire<(String, DateTime)>(
    context,
    titre: const Text('Clore la grossesse'),
    corps: (ctx, setState) => Column(
      spacing: 12,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pour une grossesse qui ne finit pas par un accouchement ici. Une nouvelle grossesse pourra être déclarée.',
          style: TextStyle(color: Kolors.kTextMuted),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final i in issuesGrossesse.entries)
              ChoiceChip(
                label: Text(i.value),
                selected: issue == i.key,
                onSelected: (_) => setState(() {
                  issue = i.key;
                  erreur = null;
                }),
              ),
          ],
        ),
        if (erreur != null)
          Text(erreur!, style: const TextStyle(color: Kolors.kRed)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_rounded),
          title: Text('Le ${dateCourte(le)}'),
          subtitle: const Text('Toucher pour changer la date'),
          onTap: () async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: le,
              firstDate: DateTime.now().subtract(const Duration(days: 320)),
              lastDate: DateTime.now(),
            );
            if (d != null) setState(() => le = d);
          },
        ),
      ],
    ),
    actions: (ctx, setState) => [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Annuler'),
      ),
      ElevatedButton(
        onPressed: () {
          if (issue == null) {
            setState(() => erreur = 'Choisissez comment la grossesse a fini.');
            return;
          }
          Navigator.pop(ctx, (issue!, le));
        },
        child: const Text('Clore'),
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

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _modifier() async {
    final d = await _formGrossesse(context, g: _g);
    if (d == null) return;
    try {
      final g = await MaterniteService().modifier(_g.uuid, d);
      if (mounted) setState(() => _g = g);
      _dire('Grossesse enregistrée.');
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _terminer() async {
    final choix = await _clore(context);
    if (choix == null || !mounted) return;
    final (issue, le) = choix;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clore la grossesse ?'),
        content: Text(
          '${issuesGrossesse[issue]} le ${dateCourte(le)}. Le suivi (CPN, rappels) s’arrête.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final g = await MaterniteService().terminer(
        _g.uuid,
        issue,
        DateFormat('yyyy-MM-dd').format(le),
      );
      if (mounted) setState(() => _g = g);
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
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
                  g.enCours ? '${g.semaines} SA' : g.fin,
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
                if (!g.enCours && g.issue != null && g.termineeLe != null)
                  Text(
                    'Le ${dateCourte(DateTime.tryParse(g.termineeLe!))}',
                    style: TextStyle(
                      color: Kolors.kWhite.withValues(alpha: 0.85),
                    ),
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
                OutlinedButton.icon(
                  onPressed: _modifier,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier (DDR, G/P, risques)'),
                ),
                TextButton.icon(
                  onPressed: _terminer,
                  icon: const Icon(Icons.do_not_disturb_on_outlined),
                  label: const Text('Clore la grossesse'),
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
                      if (e.tailleCm != null) '${e.tailleCm} cm',
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
          for (final c in g.cpn.reversed)
            CarteCpn(
              c,
              // Seule la dernière CPN se corrige.
              onCorriger: g.enCours && c == g.cpn.last
                  ? () => _ouvrir(CpnScreen(grossesse: g, cpn: c))
                  : null,
            ),
        ],
      ),
    );
  }
}

class CarteCpn extends StatelessWidget {
  const CarteCpn(this.c, {this.onCorriger, super.key});

  final CpnVisite c;
  final VoidCallback? onCorriger;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CPN ${c.numero} · ${c.semaines} SA',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (onCorriger != null)
                  TextButton(
                    onPressed: onCorriger,
                    child: const Text('Corriger'),
                  ),
              ],
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

/// La consultation prénatale ; avec [cpn], la corriger.
class CpnScreen extends StatefulWidget {
  const CpnScreen({required this.grossesse, this.cpn, super.key});

  final Grossesse grossesse;
  final CpnVisite? cpn;

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
  bool? _oedemes;
  String? _albuminurie;
  bool _fer = true;
  bool _moustiquaire = false;
  DateTime? _revoir;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cpn;
    if (c == null) return;
    String n(num? v) => v == null
        ? ''
        : v == v.roundToDouble()
        ? '${v.toInt()}'
        : '$v';
    _champs['poids']!.text = n(c.poids);
    _champs['ta_sys']!.text = n(c.taSys);
    _champs['ta_dia']!.text = n(c.taDia);
    _champs['hauteur_uterine']!.text = n(c.hauteurUterine);
    _champs['bcf']!.text = n(c.bcf);
    _champs['tpi']!.text = n(c.tpi);
    _champs['vat']!.text = n(c.vat);
    _observations.text = c.observations ?? '';
    _presentation = c.presentation;
    _oedemes = c.oedemes;
    _albuminurie = c.albuminurie;
    _fer = c.fer;
    _moustiquaire = c.moustiquaire;
    _revoir = DateTime.tryParse(c.prochainRdv ?? '');
  }

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
    final corrige = widget.cpn;
    // Tout est envoyé, vide compris : un champ vidé à la correction s'efface.
    final donnees = {
      for (final e in _champs.entries)
        e.key: num.tryParse(e.value.text.replaceAll(',', '.')),
      'presentation': _presentation,
      'oedemes': _oedemes,
      'albuminurie': _albuminurie,
      'fer': _fer,
      'moustiquaire': _moustiquaire,
      'observations': _observations.text.trim(),
      if (_revoir != null &&
          (corrige == null ||
              _revoir!.isAfter(DateUtils.dateOnly(DateTime.now()))))
        'prochain_rdv': DateFormat('yyyy-MM-dd').format(_revoir!),
    };
    try {
      final g = corrige == null
          ? await MaterniteService().cpn(widget.grossesse.uuid, donnees)
          : await MaterniteService().modifierCpn(corrige.uuid, donnees);
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
      appBar: AppBar(
        title: Text(
          widget.cpn == null
              ? 'CPN ${g.cpn.length + 1} · ${g.semaines} SA'
              : 'Corriger la CPN ${widget.cpn!.numero}',
        ),
      ),
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
          const SizedBox(height: 12),
          const Text('Œdèmes'),
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Non'),
                selected: _oedemes == false,
                onSelected: (oui) =>
                    setState(() => _oedemes = oui ? false : null),
              ),
              ChoiceChip(
                label: const Text('Oui'),
                selected: _oedemes == true,
                onSelected: (oui) =>
                    setState(() => _oedemes = oui ? true : null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Albuminurie (bandelette)'),
          Wrap(
            spacing: 6,
            children: [
              for (final a in albuminuries.entries)
                ChoiceChip(
                  label: Text(a.value),
                  selected: _albuminurie == a.key,
                  onSelected: (oui) =>
                      setState(() => _albuminurie = oui ? a.key : null),
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
              child: Text(
                widget.cpn == null
                    ? 'Enregistrer la CPN'
                    : 'Enregistrer la correction',
              ),
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
  final taille = TextEditingController();
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

  /// Le récapitulatif avant d'enregistrer : un dossier s'ouvre par enfant
  /// né vivant, l'erreur se rattrape mal.
  Future<void> _confirmer() async {
    final enfants = [
      for (final (i, e) in _enfants.indexed)
        [
          _enfants.length > 1 ? 'Enfant ${i + 1}' : 'Enfant',
          e.sexe == 'F' ? 'fille' : 'garçon',
          if (!e.vivant) 'mort-né(e)',
          if (e.prenom.text.trim().isNotEmpty) e.prenom.text.trim(),
          if (e.poids.text.isNotEmpty) '${e.poids.text} g',
          if (e.taille.text.isNotEmpty) '${e.taille.text} cm',
          if (e.apgar1.text.isNotEmpty || e.apgar5.text.isNotEmpty)
            'Apgar ${e.apgar1.text}/${e.apgar5.text}',
        ].join(' · '),
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enregistrer l’accouchement ?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(
                '${DateFormat('d MMM yyyy à HH:mm', 'fr').format(_quand)} · ${modesAccouchement[_mode]}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final e in enfants) Text(e),
              const SizedBox(height: 4),
              const Text(
                'Chaque enfant né vivant reçoit son dossier, rattaché à celui de sa mère.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Corriger'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok == true) await _valider();
  }

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
              'taille_cm': ?int.tryParse(e.taille.text),
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
            subtitle: const Text(
              'Toucher pour changer le jour et l’heure (accouchement noté après coup)',
            ),
            onTap: () async {
              final n = DateTime.now();
              final jour = await showDatePicker(
                context: context,
                initialDate: _quand,
                firstDate: n.subtract(const Duration(days: 60)),
                lastDate: n,
                helpText: 'Jour de l’accouchement',
              );
              if (jour == null || !context.mounted) return;
              final h = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_quand),
                helpText: 'Heure de l’accouchement',
              );
              if (h == null) return;
              var choix = DateTime(
                jour.year,
                jour.month,
                jour.day,
                h.hour,
                h.minute,
              );
              // Pas d'accouchement dans le futur : l'heure de la nuit passée.
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
                    Row(
                      children: [
                        Expanded(child: _nombre(e.poids, 'Poids (g)')),
                        const SizedBox(width: 8),
                        Expanded(child: _nombre(e.taille, 'Taille (cm)')),
                      ],
                    ),
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
              onPressed: _envoi ? null : _confirmer,
              child: const Text('Enregistrer l’accouchement'),
            ),
          ),
        ],
      ),
    );
  }
}
