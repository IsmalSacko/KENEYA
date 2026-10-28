import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../abonnement/abonnement_service.dart';
import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../common/widgets/formulaire.dart';
import '../../compte/compte_models.dart';
import '../../core/api/api_client.dart';
import '../../plateforme/plateforme_service.dart';

/// La console Ngoni Santé, comme celle de Ngoni Caisse : le tableau de bord,
/// les établissements (valider, accorder une formule), les demandes
/// d'abonnement à valider, les formules et leurs prix.
class ConsoleScreen extends StatelessWidget {
  const ConsoleScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Console Ngoni Santé'),
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Kolors.kJaune,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Kolors.kJaune,
          tabs: [
            Tab(text: 'Tableau de bord'),
            Tab(text: 'Établissements'),
            Tab(text: 'Demandes'),
            Tab(text: 'Formules'),
          ],
        ),
      ),
      body: const TabBarView(
        children: [_Tableau(), _Etablissements(), _Demandes(), _Formules()],
      ),
    ),
  );
}

final _service = PlateformeService();

void _dire(BuildContext context, String texte) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));

String _date(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  return d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
}

String _duree(Object? mois) => switch (int.tryParse('$mois')) {
  12 => '1 an',
  final m => '${m ?? 1} mois',
};

/// Charge une liste, affiche l'attente ou l'erreur, se recharge en tirant.
class _Chargement<T> extends StatelessWidget {
  const _Chargement({
    required this.future,
    required this.onRefresh,
    required this.builder,
  });

  final Future<T> future;
  final Future<void> Function() onRefresh;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, s) {
      if (s.hasError) {
        final e = s.error;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is DioException ? messageErreur(e) : 'Erreur : $e',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: builder(s.data as T),
      );
    },
  );
}

// ------------------------------------------------------------ Tableau de bord

class _Tableau extends StatefulWidget {
  const _Tableau();

  @override
  State<_Tableau> createState() => _TableauState();
}

class _TableauState extends State<_Tableau> {
  late Future<Map<String, dynamic>> _f = _service.tableau();

  @override
  Widget build(BuildContext context) => _Chargement<Map<String, dynamic>>(
    future: _f,
    onRefresh: () async => setState(() => _f = _service.tableau()),
    builder: (t) {
      final encaisse = [
        for (final e in (t['encaisse_mois'] as List?) ?? const [])
          if (e is Map)
            formatMontant(int.tryParse('${e['total']}') ?? 0, '${e['devise']}'),
      ];
      final tuiles = [
        ('Établissements', '${t['etablissements']}', Icons.local_hospital),
        ('À valider', '${t['a_valider']}', Icons.verified_user_outlined),
        ('Demandes en attente', '${t['demandes_en_attente']}', Icons.inbox),
        ('En essai', '${t['essais']}', Icons.hourglass_top),
        ('Abonnés', '${t['payants']}', Icons.workspace_premium),
        ('Échus', '${t['echus']}', Icons.lock_clock),
        (
          'Encaissé ce mois',
          encaisse.isEmpty ? '0 FCFA' : encaisse.join(' · '),
          Icons.payments,
        ),
        ('Nouveaux (30 j)', '${t['nouveaux_30j']}', Icons.fiber_new),
        ('Membres actifs', '${t['membres']}', Icons.badge_outlined),
        ('Comptes', '${t['personnes']}', Icons.people_outline),
      ];
      return LayoutBuilder(
        builder: (context, c) {
          final colonnes = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 500 ? 3 : 2);
          final largeur = (c.maxWidth - 32 - 10 * (colonnes - 1)) / colonnes;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (libelle, valeur, icone) in tuiles)
                    SizedBox(
                      width: largeur,
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icone, color: Kolors.kPrimary),
                              const SizedBox(height: 6),
                              FittedBox(
                                child: Text(
                                  valeur,
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                libelle,
                                style: const TextStyle(
                                  color: Kolors.kTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

// ------------------------------------------------------------ Établissements

class _Etablissements extends StatefulWidget {
  const _Etablissements();

  @override
  State<_Etablissements> createState() => _EtablissementsState();
}

class _EtablissementsState extends State<_Etablissements> {
  String _q = '';
  String _filtre = '';
  late Future<List<Map<String, dynamic>>> _f = _charger();

  Future<List<Map<String, dynamic>>> _charger() =>
      _service.etablissements(q: _q, filtre: _filtre);

  void _recharger() => setState(() => _f = _charger());

  Future<void> _accorder(Map<String, dynamic> e) async {
    final formules = await _service.formules();
    if (!mounted) return;
    final codes = [
      for (final f in (formules['data'] as List?) ?? const [])
        if (f is Map) ('${f['code']}', '${f['nom']}'),
    ];
    var formule = '${e['formule'] ?? 'essentiel'}';
    if (!codes.any((c) => c.$1 == formule)) formule = codes.first.$1;
    DateTime? fin = DateTime.tryParse('${e['fin'] ?? ''}');
    var sansEcheance = e['fin'] == null && e['manuel'] == true;
    final note = TextEditingController(text: '${e['note'] ?? ''}');

    final ok = await formulaire<bool>(
      context,
      titre: Text('Formule · ${e['nom']}'),
      corps: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          DropdownButtonFormField<String>(
            initialValue: formule,
            decoration: const InputDecoration(labelText: 'Formule'),
            items: [
              for (final (code, nom) in codes)
                DropdownMenuItem(value: code, child: Text(nom)),
            ],
            onChanged: (v) => setState(() => formule = v ?? formule),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sans échéance'),
            value: sansEcheance,
            onChanged: (v) => setState(() => sansEcheance = v),
          ),
          if (!sansEcheance) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (libelle, jours) in const [
                  ('+7 jours', 7),
                  ('+14 jours', 14),
                  ('+1 mois', 30),
                  ('+1 an', 365),
                ])
                  ActionChip(
                    label: Text(libelle),
                    onPressed: () => setState(() {
                      final base = fin != null && fin!.isAfter(DateTime.now())
                          ? fin!
                          : DateTime.now();
                      fin = base.add(Duration(days: jours));
                    }),
                  ),
              ],
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(
                fin == null
                    ? 'Choisir la date de fin'
                    : 'Jusqu’au ${_date(fin!.toIso8601String())}',
              ),
              onPressed: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate:
                      fin ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (d != null) setState(() => fin = d);
              },
            ),
          ],
          TextField(
            controller: note,
            decoration: const InputDecoration(
              labelText: 'Note (partenaire, geste…)',
            ),
          ),
        ],
      ),
      actions: (ctx, setState) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: sansEcheance || fin != null
              ? () => Navigator.pop(ctx, true)
              : null,
          child: const Text('Enregistrer'),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await _service.accorder(
        '${e['uuid']}',
        formule: formule,
        fin: sansEcheance ? null : fin,
        note: note.text.trim(),
      );
      if (mounted) _dire(context, 'Formule enregistrée pour ${e['nom']}.');
      _recharger();
    } on DioException catch (err) {
      if (mounted) _dire(context, messageErreur(err));
    }
  }

  Future<void> _valider(Map<String, dynamic> e) async {
    try {
      await _service.valider('${e['uuid']}');
      if (mounted) _dire(context, '${e['nom']} est validé.');
      _recharger();
    } on DioException catch (err) {
      if (mounted) _dire(context, messageErreur(err));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Nom de l’établissement',
          ),
          onSubmitted: (v) {
            _q = v.trim();
            _recharger();
          },
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          spacing: 8,
          children: [
            for (final (code, libelle) in const [
              ('', 'Tous'),
              ('a_valider', 'À valider'),
              ('essai', 'En essai'),
              ('payant', 'Abonnés'),
              ('echu', 'Échus'),
            ])
              ChoiceChip(
                label: Text(libelle),
                selected: _filtre == code,
                onSelected: (_) {
                  _filtre = code;
                  _recharger();
                },
              ),
          ],
        ),
      ),
      Expanded(
        child: _Chargement<List<Map<String, dynamic>>>(
          future: _f,
          onRefresh: () async => _recharger(),
          builder: (liste) => liste.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucun établissement.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: liste.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = liste[i];
                    final echu = e['en_cours'] == false;
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e['nom']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              [
                                ProfilEtablissement.labelDe('${e['profil']}'),
                                '${e['pays_code']}',
                                '${e['membres']} membre${(e['membres'] as int? ?? 0) > 1 ? 's' : ''}',
                                'créé le ${_date(e['cree_le'])}',
                              ].join(' · '),
                              style: const TextStyle(color: Kolors.kTextMuted),
                            ),
                            if (e['responsable'] != null ||
                                e['autorisation'] != null)
                              Text(
                                'Responsable : ${e['responsable'] ?? '—'} · Autorisation : ${e['autorisation'] ?? '—'}',
                                style: const TextStyle(
                                  color: Kolors.kTextMuted,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              '${e['formule_nom'] ?? 'Sans formule'}'
                              '${e['fin'] == null ? (e['formule'] == null ? '' : ' · sans échéance') : ' · ${echu ? 'échu le' : 'jusqu’au'} ${_date(e['fin'])}'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: echu ? Kolors.kRed : Kolors.kPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (e['valide'] != true)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.verified_rounded),
                                    label: const Text('Valider'),
                                    onPressed: () => _valider(e),
                                  ),
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.workspace_premium_outlined,
                                  ),
                                  label: const Text('Formule'),
                                  onPressed: () => _accorder(e),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    ],
  );
}

// ------------------------------------------------------------ Demandes

class _Demandes extends StatefulWidget {
  const _Demandes();

  @override
  State<_Demandes> createState() => _DemandesState();
}

class _DemandesState extends State<_Demandes> {
  String _statut = 'en_attente';
  late Future<List<Map<String, dynamic>>> _f = _service.demandes(_statut);

  void _recharger() => setState(() => _f = _service.demandes(_statut));

  Future<void> _approuver(Map<String, dynamic> d) async {
    try {
      await _service.approuver('${d['uuid']}');
      if (mounted) {
        _dire(context, 'Abonnement activé pour ${d['etablissement']}.');
      }
      _recharger();
    } on DioException catch (e) {
      if (mounted) _dire(context, messageErreur(e));
    }
  }

  Future<void> _refuser(Map<String, dynamic> d) async {
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la demande ?'),
        content: TextField(
          controller: motif,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Motif (vu par l’établissement)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (ok != true || motif.text.trim().isEmpty) return;
    try {
      await _service.refuser('${d['uuid']}', motif.text.trim());
      _recharger();
    } on DioException catch (e) {
      if (mounted) _dire(context, messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'en_attente', label: Text('En attente')),
            ButtonSegment(value: 'approuvee', label: Text('Approuvées')),
            ButtonSegment(value: 'toutes', label: Text('Toutes')),
          ],
          selected: {_statut},
          onSelectionChanged: (s) {
            _statut = s.first;
            _recharger();
          },
        ),
      ),
      Expanded(
        child: _Chargement<List<Map<String, dynamic>>>(
          future: _f,
          onRefresh: () async => _recharger(),
          builder: (liste) => liste.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucune demande.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: liste.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = liste[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(
                              '${d['etablissement']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${d['formule_nom']} · ${_duree(d['mois'])} · '
                              '${formatMontant(int.tryParse('${d['montant']}') ?? 0, '${d['devise']}')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Kolors.kPrimary,
                              ),
                            ),
                            Text(
                              '${libellesMoyensAbonnement[d['moyen']] ?? d['moyen']}'
                              '${d['telephone'] == null ? '' : ' · payé depuis ${d['telephone']}'}'
                              ' · le ${_date(d['le'])}',
                            ),
                            if (d['demandeur'] != null)
                              Text(
                                'Demandé par ${d['demandeur']} (${d['demandeur_telephone'] ?? ''})',
                                style: const TextStyle(
                                  color: Kolors.kTextMuted,
                                ),
                              ),
                            if ('${d['note'] ?? ''}'.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Kolors.kSecondaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SelectableText('${d['note']}'),
                              ),
                            if (d['statut'] == 'approuvee')
                              Text(
                                'Reçu ${d['recu_numero']} · du ${_date(d['periode_debut'])} au ${_date(d['periode_fin'])}',
                                style: const TextStyle(color: Kolors.kSuccess),
                              ),
                            if (d['statut'] == 'refusee')
                              Text(
                                'Refusée : ${d['motif_refus'] ?? ''}',
                                style: const TextStyle(color: Kolors.kRed),
                              ),
                            if (d['statut'] == 'en_attente')
                              Wrap(
                                spacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Approuver'),
                                    onPressed: () => _approuver(d),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _refuser(d),
                                    child: const Text('Refuser'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    ],
  );
}

// ------------------------------------------------------------ Formules

class _Formules extends StatefulWidget {
  const _Formules();

  @override
  State<_Formules> createState() => _FormulesState();
}

class _FormulesState extends State<_Formules> {
  late Future<Map<String, dynamic>> _f = _service.formules();

  Future<void> _modifier(Map<String, dynamic> f, Map<String, dynamic> d) async {
    final tousModules = [
      for (final m in (d['modules'] as List?) ?? const []) '$m',
    ];
    final toutesFonctions = [
      for (final m in (d['fonctions'] as List?) ?? const []) '$m',
    ];
    final nom = TextEditingController(text: '${f['nom']}');
    final essai = TextEditingController(text: '${f['jours_essai'] ?? 0}');
    final max = TextEditingController(text: '${f['max_membres'] ?? ''}');
    final tarifs = {
      for (final m in const [1, 3, 6, 12])
        m: TextEditingController(
          text:
              '${((f['tarifs'] as List?) ?? const []).whereType<Map>().where((t) => t['mois'] == m).firstOrNull?['montant'] ?? ''}',
        ),
    };
    final modules = {for (final m in (f['modules'] as List?) ?? const []) '$m'};
    final fonctions = {
      for (final m in (f['fonctions'] as List?) ?? const []) '$m',
    };
    var actif = f['actif'] != false;
    final estEssai = f['code'] == 'essai';
    final chiffres = [FilteringTextInputFormatter.digitsOnly];

    final ok = await formulaire<bool>(
      context,
      titre: Text('Formule ${f['nom']}'),
      corps: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TextField(
            controller: nom,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          if (estEssai)
            TextField(
              controller: essai,
              keyboardType: TextInputType.number,
              inputFormatters: chiffres,
              decoration: const InputDecoration(
                labelText: 'Durée de l’essai (jours)',
                helperText:
                    'Pour les établissements créés à partir de maintenant.',
              ),
            ),
          TextField(
            controller: max,
            keyboardType: TextInputType.number,
            inputFormatters: chiffres,
            decoration: const InputDecoration(
              labelText: 'Membres de l’équipe au plus (vide : sans limite)',
            ),
          ),
          if (!estEssai) ...[
            const Text(
              'Prix (FCFA)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final m in const [1, 3, 6, 12])
              TextField(
                controller: tarifs[m],
                keyboardType: TextInputType.number,
                inputFormatters: chiffres,
                decoration: InputDecoration(labelText: _duree(m)),
              ),
          ],
          const Text('Modules', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in tousModules)
                FilterChip(
                  label: Text(libellesModules[m] ?? m),
                  selected: modules.contains(m),
                  onSelected: (v) =>
                      setState(() => v ? modules.add(m) : modules.remove(m)),
                ),
              for (final fn in toutesFonctions)
                FilterChip(
                  label: Text(libellesFonctions[fn] ?? fn),
                  selected: fonctions.contains(fn),
                  onSelected: (v) => setState(
                    () => v ? fonctions.add(fn) : fonctions.remove(fn),
                  ),
                ),
            ],
          ),
          if (!estEssai)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Proposée aux établissements'),
              value: actif,
              onChanged: (v) => setState(() => actif = v),
            ),
        ],
      ),
      actions: (ctx, setState) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Enregistrer'),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await _service.modifierFormule('${f['code']}', {
        'nom': nom.text.trim(),
        if (estEssai) 'jours_essai': int.tryParse(essai.text) ?? 14,
        'max_membres': int.tryParse(max.text),
        'modules': modules.toList(),
        'fonctions': fonctions.toList(),
        if (!estEssai) 'actif': actif,
        if (!estEssai)
          'tarifs': [
            for (final m in const [1, 3, 6, 12])
              if (int.tryParse(tarifs[m]!.text) != null)
                {'mois': m, 'montant': int.parse(tarifs[m]!.text)},
          ],
      });
      if (mounted) _dire(context, 'Formule enregistrée.');
      setState(() => _f = _service.formules());
    } on DioException catch (e) {
      if (mounted) _dire(context, messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) => _Chargement<Map<String, dynamic>>(
    future: _f,
    onRefresh: () async => setState(() => _f = _service.formules()),
    builder: (d) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final f in ((d['data'] as List?) ?? const []).whereType<Map>())
          Card(
            child: ListTile(
              title: Text(
                '${f['nom']}${f['actif'] == false ? ' (masquée)' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                f['code'] == 'essai'
                    ? 'Essai : ${f['jours_essai']} jours · tout inclus'
                    : [
                        for (final t
                            in ((f['tarifs'] as List?) ?? const [])
                                .whereType<Map>())
                          '${_duree(t['mois'])} : ${formatMontant(int.tryParse('${t['montant']}') ?? 0, '${t['devise']}')}',
                        f['max_membres'] == null
                            ? 'équipe sans limite'
                            : 'équipe : ${f['max_membres']}',
                      ].join(' · '),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _modifier(Map<String, dynamic>.from(f), d),
            ),
          ),
      ],
    ),
  );
}
