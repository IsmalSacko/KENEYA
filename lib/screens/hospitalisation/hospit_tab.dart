import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../hospitalisation/hospit_models.dart';
import '../../hospitalisation/hospit_service.dart';
import '../../patients/patients_service.dart';
import '../commun/scanner_qr_screen.dart';
import '../dossier/dossier_widgets.dart';
import '../patients/choix_patient.dart';
import 'sejour_screen.dart';
import '../../common/widgets/formulaire.dart';

/// Les patients hospitalisés et les lits.
class HospitTab extends StatefulWidget {
  const HospitTab({super.key});

  @override
  State<HospitTab> createState() => _HospitTabState();
}

/// Ce que montre l'onglet.
enum _Vue { patients, sortis, lits }

class _HospitTabState extends State<HospitTab> {
  final _service = HospitService();
  _Vue _vue = _Vue.patients;
  List<Sejour>? _sejours;
  List<Sejour>? _sortis;
  List<Chambre>? _chambres;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final s = await _service.sejours();
      final c = await _service.chambres();
      // Les sortis ne se chargent qu'une fois l'onglet ouvert.
      final sortis = _vue == _Vue.sortis
          ? await _service.sejours(sortis: true)
          : _sortis;
      if (mounted) {
        setState(() {
          _sejours = s;
          _chambres = c;
          _sortis = sortis;
          _erreur = null;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  void _changerVue(_Vue v) {
    setState(() => _vue = v);
    if (v == _Vue.sortis) _charger();
  }

  Future<void> _ouvrir(Future<Sejour> Function() charger) async {
    try {
      final s = await charger();
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SejourScreen(sejour: s)));
      await _charger();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  Future<void> _scanner() async {
    final qr = await scannerQr(
      context,
      titre: 'Bracelet du patient',
      consigne: 'Visez le QR du bracelet.',
    );
    if (qr != null) await _ouvrir(() => _service.lireBracelet(qr));
  }

  Future<void> _nouvelleChambre() async {
    final devise = context.read<AuthController>().devise;
    final nom = TextEditingController();
    final service = TextEditingController();
    final lits = TextEditingController(text: '4');
    final prix = TextEditingController();
    String? erreurNom;
    final ok = await formulaire<bool>(
      context,
      titre: const Text('Nouvelle chambre'),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nom,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nom (ex. Salle d’observation)',
              errorText: erreurNom,
            ),
            onChanged: (_) {
              if (erreurNom != null) setState(() => erreurNom = null);
            },
          ),
          TextField(
            controller: service,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Service (ex. Pédiatrie)',
            ),
          ),
          TextField(
            controller: lits,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Nombre de lits'),
          ),
          TextField(
            controller: prix,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Prix de la nuit ($devise)'),
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
            if (nom.text.trim().isEmpty) {
              setState(() => erreurNom = 'Indiquez le nom de la chambre.');
              return;
            }
            Navigator.pop(ctx, true);
          },
          child: const Text('Créer'),
        ),
      ],
    );
    if (ok != true) return;
    try {
      await _service.creerChambre({
        'nom': nom.text.trim(),
        'service': service.text.trim(),
        'lits': int.tryParse(lits.text) ?? 1,
        'prix': int.tryParse(prix.text),
      });
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  /// Modifier la chambre : nom, service, prix, lits en plus, fermer.
  Future<void> _modifierChambre(Chambre c) async {
    final devise = context.read<AuthController>().devise;
    final nom = TextEditingController(text: c.nom);
    final service = TextEditingController(text: c.service ?? '');
    final prix = TextEditingController(text: c.prix?.toString() ?? '');
    final ajout = TextEditingController();
    var actif = c.actif;
    final occupee = c.lits.any((l) => l.sejourUuid != null);
    String? erreurNom;
    final ok = await formulaire<bool>(
      context,
      titre: const Text('Modifier la chambre'),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nom,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Nom', errorText: erreurNom),
            onChanged: (_) {
              if (erreurNom != null) setState(() => erreurNom = null);
            },
          ),
          TextField(
            controller: service,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Service'),
          ),
          TextField(
            controller: prix,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Prix de la nuit ($devise)',
              helperText: 'Vide : la nuit n’est pas facturée.',
            ),
          ),
          TextField(
            controller: ajout,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Lits à ajouter',
              helperText:
                  'La chambre a ${c.lits.length} lit${c.lits.length > 1 ? 's' : ''}.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chambre ouverte'),
            subtitle: Text(
              actif
                  ? 'Ses lits libres reçoivent des patients.'
                  : 'Fermée : ses lits ne reçoivent plus personne.',
            ),
            value: actif,
            onChanged: (v) => setState(() => actif = v),
          ),
          if (!actif && occupee)
            const Text(
              'Des patients y sont couchés : changez-les de lit avant de fermer la chambre.',
              style: TextStyle(color: Kolors.kRed),
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
            if (nom.text.trim().isEmpty) {
              setState(() => erreurNom = 'Indiquez le nom de la chambre.');
              return;
            }
            Navigator.pop(ctx, true);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
    if (ok != true) return;
    final lits = int.tryParse(ajout.text) ?? 0;
    try {
      await _service.modifierChambre(c.uuid, {
        'nom': nom.text.trim(),
        'service': service.text.trim().isEmpty ? null : service.text.trim(),
        'prix': int.tryParse(prix.text),
        'actif': actif,
        if (lits > 0) 'ajouter_lits': lits,
      });
      _dire('Chambre enregistrée.');
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  /// Un lit libre : on y couche un patient cherché par son nom.
  Future<void> _admettreSurLit(Chambre c, LitInfo l) async {
    Patient? patient;
    final motif = TextEditingController();
    String? erreurPatient;
    String? erreurMotif;
    final ok = await formulaire<bool>(
      context,
      titre: Text('${c.nom} · lit ${l.numero}'),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChoixPatient(
            patient: patient,
            onChoisi: (p) => setState(() {
              patient = p;
              erreurPatient = null;
            }),
          ),
          if (erreurPatient != null)
            Text(erreurPatient!, style: const TextStyle(color: Kolors.kRed)),
          TextField(
            controller: motif,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Motif d’hospitalisation',
              errorText: erreurMotif,
            ),
            onChanged: (_) {
              if (erreurMotif != null) setState(() => erreurMotif = null);
            },
          ),
          const Text(
            'Le patient a une visite aujourd’hui ? Hospitalisez-le depuis sa fiche : les nuits iront sur sa facture.',
            style: TextStyle(color: Kolors.kTextMuted),
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
            setState(() {
              erreurPatient = patient == null
                  ? 'Cherchez le patient par son nom.'
                  : null;
              erreurMotif = motif.text.trim().isEmpty
                  ? 'Indiquez le motif.'
                  : null;
            });
            if (erreurPatient == null && erreurMotif == null) {
              Navigator.pop(ctx, true);
            }
          },
          child: const Text('Hospitaliser'),
        ),
      ],
    );
    final p = patient;
    if (ok != true || p == null) return;
    await _ouvrir(
      () => _service.admettreDossier(p.uuid, l.uuid, motif.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final devise = auth.devise;
    final sejours = _sejours;
    final chambres = _chambres;
    final sortis = _sortis;
    final regle =
        auth.peut('hospitalisation.gerer') || auth.peut('etablissement.regler');
    final admet = auth.peut('hospitalisation.gerer');

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bracelet',
        onPressed: _scanner,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Bracelet'),
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            SegmentedButton<_Vue>(
              segments: const [
                ButtonSegment(value: _Vue.patients, label: Text('Patients')),
                ButtonSegment(value: _Vue.sortis, label: Text('Sortis')),
                ButtonSegment(value: _Vue.lits, label: Text('Lits')),
              ],
              selected: {_vue},
              onSelectionChanged: (s) => _changerVue(s.first),
            ),
            if (_vue == _Vue.lits && regle) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _nouvelleChambre,
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle chambre'),
              ),
            ],
            const SizedBox(height: 12),
            if (sejours == null || chambres == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: _erreur == null
                      ? const CircularProgressIndicator()
                      : Text(_erreur!),
                ),
              )
            else if (_vue == _Vue.patients) ...[
              if (sejours.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'Personne n’est hospitalisé. On hospitalise depuis la visite du patient, ou en touchant un lit libre.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Kolors.kTextMuted),
                  ),
                ),
              for (final s in sejours)
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.bed_rounded,
                      color: Kolors.kPrimary,
                    ),
                    title: Text(s.patient),
                    subtitle: Text('${s.lit ?? 'Sans lit'} · ${s.motif}'),
                    trailing: s.enRetard > 0
                        ? Text(
                            '${s.enRetard} en retard',
                            style: const TextStyle(
                              color: Kolors.kRed,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                    onTap: () => _ouvrir(() => _service.sejour(s.uuid)),
                  ),
                ),
            ] else if (_vue == _Vue.sortis) ...[
              if (sortis == null)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (sortis.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'Aucun patient sorti.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Kolors.kTextMuted),
                  ),
                ),
              for (final s in sortis ?? const <Sejour>[])
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Kolors.kTextMuted,
                    ),
                    title: Text(s.patient),
                    subtitle: Text(
                      [
                        'Sorti le ${dateCourte(s.sortie)}',
                        ?modesSortie[s.modeSortie],
                        '${s.nuits} nuit${s.nuits > 1 ? 's' : ''}',
                        s.motif,
                      ].join(' · '),
                    ),
                    onTap: () => _ouvrir(() => _service.sejour(s.uuid)),
                  ),
                ),
            ] else ...[
              if (chambres.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    regle
                        ? 'Aucune chambre. Touchez « Nouvelle chambre » pour créer les chambres et leurs lits.'
                        : 'Aucune chambre.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Kolors.kTextMuted),
                  ),
                ),
              for (final c in chambres)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: regle ? () => _modifierChambre(c) : null,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  [
                                    c.nom,
                                    ?c.service,
                                    if (c.prix != null)
                                      '${formatMontant(c.prix!, devise)} / nuit',
                                    if (!c.actif) 'fermée',
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: c.actif ? null : Kolors.kTextMuted,
                                  ),
                                ),
                              ),
                              if (regle)
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: Kolors.kTextMuted,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final l in c.lits)
                              ActionChip(
                                avatar: Icon(
                                  l.libre
                                      ? Icons.bed_outlined
                                      : Icons.bed_rounded,
                                  size: 18,
                                  color: l.libre
                                      ? Kolors.kSuccess
                                      : Kolors.kPrimary,
                                ),
                                label: Text(
                                  l.patient == null
                                      ? 'Lit ${l.numero}'
                                      : '${l.numero} · ${l.patient}',
                                ),
                                onPressed: l.sejourUuid != null
                                    ? () => _ouvrir(
                                        () => _service.sejour(l.sejourUuid!),
                                      )
                                    : l.libre && admet
                                    ? () => _admettreSurLit(c, l)
                                    : null,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
