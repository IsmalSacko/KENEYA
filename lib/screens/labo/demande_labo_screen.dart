import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../common/utils/kcolors.dart';
import '../../common/whatsapp.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../file/impression_ticket.dart';
import '../../labo/labo_models.dart';
import '../../labo/labo_service.dart';
import '../dossier/dossier_widgets.dart';

/// Une demande au labo : étiquette du tube, saisie des résultats, validation.
class DemandeLaboScreen extends StatefulWidget {
  const DemandeLaboScreen({required this.demande, super.key});

  final DemandeLabo demande;

  @override
  State<DemandeLaboScreen> createState() => _DemandeLaboScreenState();
}

class _DemandeLaboScreenState extends State<DemandeLaboScreen> {
  final _service = LaboService();
  late DemandeLabo _d = widget.demande;
  final Map<String, TextEditingController> _champs = {};
  final Map<String, TextEditingController> _commentaires = {};
  final Map<String, String?> _choix = {};
  bool _envoi = false;

  /// Un résultat validé en cours de correction.
  bool _correction = false;

  @override
  void initState() {
    super.initState();
    _remplir();
  }

  @override
  void dispose() {
    for (final c in [..._champs.values, ..._commentaires.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _remplir() {
    for (final l in _d.lignes) {
      if (l.typeResultat == 'choix') {
        _choix[l.uuid] = l.resultat;
      } else {
        (_champs[l.uuid] ??= TextEditingController()).text = l.resultat ?? '';
      }
      (_commentaires[l.uuid] ??= TextEditingController()).text =
          l.commentaire ?? '';
    }
  }

  Map<String, String> get _notes => {
    for (final l in _d.lignes) l.uuid: _commentaires[l.uuid]!.text.trim(),
  };

  Future<bool> _confirmer(String titre, String texte, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(titre),
          content: Text(texte),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  /// Une raison à écrire ; [suggestions] la remplissent d'un toucher. Null
  /// si l'on renonce ; vide permis seulement si ![obligatoire].
  Future<String?> _raison({
    required String titre,
    required String texte,
    required String action,
    List<String> suggestions = const [],
    bool obligatoire = true,
  }) async {
    final motif = TextEditingController();
    String? erreur;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(titre),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texte),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in suggestions)
                      ActionChip(
                        label: Text(m),
                        onPressed: () => setState(() {
                          motif.text = m;
                          erreur = null;
                        }),
                      ),
                  ],
                ),
                TextField(
                  controller: motif,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: obligatoire ? 'Raison' : 'Raison (facultatif)',
                    errorText: erreur,
                  ),
                  onChanged: (_) {
                    if (erreur != null) setState(() => erreur = null);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () {
                if (obligatoire && motif.text.trim().isEmpty) {
                  setState(() => erreur = 'Indiquez la raison.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    return ok == true ? motif.text.trim() : null;
  }

  Future<void> _prelever() async {
    if (await _confirmer(
      'Prélèvement fait ?',
      'Le tube de ${_d.patient} est prélevé (${_d.lignes.map((l) => l.nom).join(', ')}). Collez l’étiquette sur le tube.',
      'Prélevé',
    )) {
      await _faire(() => _service.prelever(_d.uuid), 'Prélèvement noté.');
    }
  }

  Future<void> _rejeter() async {
    final motif = await _raison(
      titre: 'Échantillon rejeté',
      texte:
          'L’échantillon ne peut pas être analysé : la demande revient « à prélever », les résultats saisis s’effacent.',
      action: 'Rejeter',
      suggestions: const [
        'Hémolysé',
        'Coagulé',
        'Quantité insuffisante',
        'Mal étiqueté',
      ],
    );
    if (motif == null) return;
    await _faire(
      () => _service.rejeter(_d.uuid, motif),
      'Échantillon rejeté : à prélever de nouveau.',
    );
  }

  Future<void> _annuler() async {
    final motif = await _raison(
      titre: 'Annuler la demande ?',
      texte:
          'Les analyses sortent de la facture du patient si elle n’est pas encore payée.',
      action: 'Annuler la demande',
      obligatoire: false,
      suggestions: const ['Erreur de patient', 'Le patient refuse'],
    );
    if (motif == null) return;
    setState(() => _envoi = true);
    try {
      final (d, note) = await _service.annuler(_d.uuid, motif: motif);
      if (!mounted) return;
      setState(() {
        _d = d;
        _envoi = false;
      });
      _message(note ?? 'Demande annulée.');
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        _message(messageErreur(e));
      }
    }
  }

  Future<void> _valider(bool peutSaisir) async {
    if (!await _confirmer(
      'Valider les résultats ?',
      'Ils seront visibles dans le dossier, et ${_d.patient} est prévenu(e) par SMS que ses résultats sont prêts.',
      'Valider',
    )) {
      return;
    }
    await _faire(() async {
      // Ce qui est à l'écran est enregistré avant de valider.
      if (peutSaisir) {
        await _service.saisir(_d.uuid, _saisis, commentaires: _notes);
      }
      return _service.valider(_d.uuid);
    }, 'Validé : le patient est prévenu.');
  }

  Future<void> _enregistrerCorrection() async {
    final motif = await _raison(
      titre: 'Corriger le résultat',
      texte:
          'L’ancien résultat reste écrit au dossier, avec la raison. Le patient est prévenu de nouveau.',
      action: 'Corriger',
      suggestions: const ['Erreur de saisie', 'Contrôle refait'],
    );
    if (motif == null) return;
    await _faire(
      () => _service.corriger(
        _d.uuid,
        _saisis,
        motif: motif,
        commentaires: _notes,
      ),
      'Résultat corrigé : le patient est prévenu.',
    );
  }

  Map<String, String> get _saisis => {
    for (final l in _d.lignes)
      l.uuid: l.typeResultat == 'choix'
          ? (_choix[l.uuid] ?? '')
          : _champs[l.uuid]!.text.trim(),
  };

  Future<void> _faire(
    Future<DemandeLabo> Function() action, [
    String? ok,
  ]) async {
    setState(() => _envoi = true);
    try {
      final d = await action();
      if (!mounted) return;
      setState(() {
        _d = d;
        _envoi = false;
        // Une correction réussie est finie.
        _correction = false;
      });
      _remplir();
      if (ok != null) _message(ok);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        _message(messageErreur(e));
      }
    }
  }

  void _message(String texte) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texte)));

  Future<void> _imprimer() async {
    if (ImpressionTicket.imprimanteChoisie == null) {
      _message('Choisissez l’imprimante dans File d’attente › Régler la file.');
      return;
    }
    final ok = await LaboService.imprimerEtiquette(_d);
    if (mounted) {
      _message(ok ? 'Étiquette imprimée.' : 'L’imprimante ne répond pas.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final d = _d;
    final peutSaisir =
        (d.modifiable && auth.peut('labo.saisir')) || _correction;
    final auLabo = auth.peut('labo.saisir') || auth.peut('labo.valider');

    return Scaffold(
      appBar: AppBar(title: Text(d.patient)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CarteMarque(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.patient,
                        style: GoogleFonts.poppins(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          d.statutLabel,
                          if (d.urgent) 'URGENT',
                          dateCourte(d.date),
                        ].join(' · '),
                        style: const TextStyle(
                          color: Kolors.kJaune,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (d.prescripteur != null)
                        Text(
                          'Demandé par ${d.prescripteur}',
                          style: TextStyle(
                            color: Kolors.kWhite.withValues(alpha: 0.85),
                          ),
                        ),
                      if (d.renseignements != null) ...[
                        const SizedBox(height: 6),
                        Text(d.renseignements!),
                      ],
                    ],
                  ),
                ),
                if (d.qr != null)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Kolors.kWhite,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(data: d.qr!, size: 84),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (d.statut == 'demandee' && d.rejetMotif != null)
            Card(
              color: Kolors.kJauneDoux,
              child: ListTile(
                leading: const Icon(Icons.replay_rounded),
                title: const Text('Échantillon rejeté : à prélever de nouveau'),
                subtitle: Text(d.rejetMotif!),
              ),
            ),
          if (d.statut == 'annulee')
            Card(
              child: ListTile(
                leading: const Icon(Icons.block_rounded),
                title: const Text('Demande annulée'),
                subtitle: d.motifAnnulation == null
                    ? null
                    : Text(d.motifAnnulation!),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (d.statut == 'demandee' && auth.peut('labo.saisir'))
                ElevatedButton.icon(
                  onPressed: _envoi ? null : _prelever,
                  icon: const Icon(Icons.water_drop_rounded),
                  label: const Text('Prélevé'),
                ),
              // L'étiquette se réimprime tant que le tube est au labo.
              if (d.modifiable && auLabo)
                OutlinedButton.icon(
                  onPressed: _imprimer,
                  icon: const Icon(Icons.print_rounded),
                  label: Text(
                    d.statut == 'demandee'
                        ? 'Étiquette'
                        : 'Réimprimer l’étiquette',
                  ),
                ),
              if (d.statut == 'prelevee' && auLabo)
                OutlinedButton.icon(
                  onPressed: _envoi ? null : _rejeter,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Échantillon rejeté'),
                ),
              if (d.modifiable &&
                  (auth.peut('consultation.faire') || auth.peut('labo.saisir')))
                TextButton(
                  onPressed: _envoi ? null : _annuler,
                  child: const Text('Annuler la demande'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final l in d.lignes)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.nom,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (l.anormal == true)
                          const Chip(
                            label: Text('Anormal'),
                            labelStyle: TextStyle(color: Kolors.kWhite),
                            backgroundColor: Kolors.kRed,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    if (l.normale != null)
                      Text(
                        'Normale : ${l.normale}',
                        style: const TextStyle(
                          color: Kolors.kTextMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (!peutSaisir) ...[
                      Text(
                        l.resultatAffiche ?? '—',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: l.anormal == true
                              ? Kolors.kRed
                              : Kolors.kTextHigh,
                        ),
                      ),
                      if (l.commentaire != null) Text(l.commentaire!),
                    ] else if (l.typeResultat == 'choix' && l.choix.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in l.choix)
                            ChoiceChip(
                              label: Text(c),
                              selected: _choix[l.uuid] == c,
                              onSelected: (oui) => setState(
                                () => _choix[l.uuid] = oui ? c : null,
                              ),
                            ),
                        ],
                      )
                    else
                      TextField(
                        controller: _champs[l.uuid],
                        maxLines: l.typeResultat == 'texte' ? null : 1,
                        keyboardType: l.typeResultat == 'nombre'
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.multiline,
                        decoration: InputDecoration(
                          labelText: 'Résultat',
                          suffixText: l.unite,
                        ),
                      ),
                    if (peutSaisir)
                      TextField(
                        controller: _commentaires[l.uuid],
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Commentaire (facultatif)',
                        ),
                      ),
                    for (final c in l.corrections)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          [
                            'Corrigé${c.le == null ? '' : ' le ${dateCourte(c.le)}'}',
                            'était « ${c.ancien ?? '—'} »',
                            c.motif,
                            ?c.par,
                          ].join(' · '),
                          style: const TextStyle(
                            color: Kolors.kTextMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_correction) ...[
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _envoi ? null : _enregistrerCorrection,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Enregistrer la correction'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _correction = false;
                _remplir();
              }),
              child: const Text('Abandonner la correction'),
            ),
          ] else if (peutSaisir)
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _envoi
                    ? null
                    : () => _faire(
                        () => _service.saisir(
                          d.uuid,
                          _saisis,
                          commentaires: _notes,
                        ),
                        'Résultats enregistrés.',
                      ),
                child: const Text('Enregistrer les résultats'),
              ),
            ),
          if (d.modifiable && auth.peut('labo.valider')) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _envoi ? null : () => _valider(peutSaisir),
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Valider et prévenir le patient'),
              ),
            ),
          ],
          if (d.validee && !_correction && auth.peut('labo.valider'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _correction = true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Corriger le résultat'),
              ),
            ),
          if (d.validee && (d.telephone ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => envoyerWhatsApp(
                  context,
                  d.telephone!,
                  'Ngoni Santé : vos résultats d’analyses sont prêts (${d.etablissement}). '
                  'Passez les chercher ou ouvrez « Mon dossier » dans l’app.',
                ),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Prévenir sur WhatsApp'),
              ),
            ),
          if (d.validee && d.validePar != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Validé par ${d.validePar}',
                style: const TextStyle(color: Kolors.kSuccess),
              ),
            ),
        ],
      ),
    );
  }
}
