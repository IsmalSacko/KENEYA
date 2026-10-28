import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../caisse/caisse_models.dart';
import '../../core/api/api_client.dart';
import '../../file/impression_ticket.dart';
import '../../hospitalisation/hospit_models.dart';
import '../../hospitalisation/hospit_service.dart';
import '../commun/scanner_qr_screen.dart';
import '../dossier/dossier_widgets.dart';
import '../../common/widgets/formulaire.dart';
import '../../common/widgets/feuille.dart';

/// Choisir un lit libre ; null si l'on renonce.
Future<LitInfo?> choisirLit(BuildContext context) async {
  final List<Chambre> chambres;
  try {
    chambres = await HospitService().chambres();
  } on DioException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
    }
    return null;
  }
  if (!context.mounted) return null;
  return feuille<LitInfo>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              'Choisir un lit libre',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (chambres.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Aucune chambre : créez-les dans l’onglet Hospitalisation › Lits.',
                ),
              ),
            for (final c in chambres) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Text(
                  '${c.nom} · ${c.libres} libre${c.libres > 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final l in c.lits)
                    ActionChip(
                      avatar: Icon(
                        l.libre ? Icons.bed_outlined : Icons.bed_rounded,
                        size: 18,
                      ),
                      label: Text('Lit ${l.numero}'),
                      onPressed: l.libre ? () => Navigator.pop(ctx, l) : null,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Hospitaliser le patient de la visite : lit, motif, puis le séjour. Déjà
/// hospitalisé, on ouvre son séjour : on ne le couche pas deux fois.
Future<void> hospitaliser(BuildContext context, String visite) async {
  final service = HospitService();
  try {
    final deja = await service.sejourDeLaVisite(visite);
    if (deja != null) {
      if (!context.mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SejourScreen(sejour: deja)));
      return;
    }
  } on DioException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
    }
    return;
  }
  if (!context.mounted) return;
  final lit = await choisirLit(context);
  if (lit == null || !context.mounted) return;
  final motif = TextEditingController();
  String? erreur;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Lit ${lit.numero}'),
        content: SingleChildScrollView(
          child: TextField(
            controller: motif,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Motif d’hospitalisation',
              errorText: erreur,
            ),
            onChanged: (_) {
              if (erreur != null) setState(() => erreur = null);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (motif.text.trim().isEmpty) {
                setState(() => erreur = 'Indiquez le motif.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Hospitaliser'),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final s = await service.admettre(visite, lit.uuid, motif.text.trim());
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SejourScreen(sejour: s)));
  } on DioException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
    }
  }
}

/// Le bouton « Hospitaliser » d'une visite : « Ouvrir le séjour » quand le
/// patient est déjà couché. [builder] reçoit le libellé et l'action.
class BoutonHospitaliser extends StatefulWidget {
  const BoutonHospitaliser({
    required this.visite,
    required this.builder,
    super.key,
  });

  final String visite;
  final Widget Function(String libelle, VoidCallback action) builder;

  @override
  State<BoutonHospitaliser> createState() => _BoutonHospitaliserState();
}

class _BoutonHospitaliserState extends State<BoutonHospitaliser> {
  bool _hospitalise = false;

  @override
  void initState() {
    super.initState();
    _verifier();
  }

  Future<void> _verifier() async {
    try {
      final s = await HospitService().sejourDeLaVisite(widget.visite);
      if (mounted) setState(() => _hospitalise = s != null);
    } on DioException {
      // Le bouton reste « Hospitaliser » : l'action vérifie de nouveau.
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    _hospitalise ? 'Ouvrir le séjour' : 'Hospitaliser',
    () async {
      await hospitaliser(context, widget.visite);
      await _verifier();
    },
  );
}

/// Le séjour : plan de soins du jour, prescriptions, bracelet, sortie.
class SejourScreen extends StatefulWidget {
  const SejourScreen({required this.sejour, super.key});

  final Sejour sejour;

  @override
  State<SejourScreen> createState() => _SejourScreenState();
}

class _SejourScreenState extends State<SejourScreen> {
  final _service = HospitService();
  late Sejour _s = widget.sejour;

  @override
  void initState() {
    super.initState();
    _faire(() => _service.sejour(widget.sejour.uuid));
  }

  Future<void> _faire(Future<Sejour> Function() action, [String? ok]) async {
    try {
      final s = await action();
      if (!mounted) return;
      setState(() => _s = s);
      if (ok != null) _dire(ok);
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

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

  Future<void> _donner(Prise p) async {
    final qr = await scannerQr(
      context,
      titre: 'Bracelet du patient',
      consigne: 'Scannez le bracelet avant de donner ${p.produit}.',
    );
    if (qr == null) return;
    await _faire(
      () => _service.administrer(_s.uuid, p, statut: 'faite', bracelet: qr),
      'Soin noté.',
    );
  }

  Future<void> _nonFait(Prise p, String statut) async {
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(statut == 'refusee' ? 'Refusé par le patient' : 'Non fait'),
        content: SingleChildScrollView(
          child: TextField(
            controller: motif,
            decoration: const InputDecoration(labelText: 'Pourquoi ?'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Noter'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _faire(
      () => _service.administrer(
        _s.uuid,
        p,
        statut: statut,
        commentaire: motif.text.trim(),
      ),
    );
  }

  /// Une prise notée par erreur : le bon statut, la raison ; « donné »
  /// exige le bracelet, comme au lit.
  Future<void> _corriger(Prise p) async {
    const libelles = {
      'faite': 'Donné',
      'refusee': 'Refusé par le patient',
      'omise': 'Non fait',
    };
    var statut = libelles.keys.firstWhere((k) => k != p.statut);
    final motif = TextEditingController();
    String? erreur;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Corriger : ${p.produit} de ${p.heure}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Noté : ${libelles[p.statut] ?? p.statut}.'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in libelles.entries)
                      if (e.key != p.statut)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: statut == e.key,
                          onSelected: (_) => setState(() => statut = e.key),
                        ),
                  ],
                ),
                TextField(
                  controller: motif,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Pourquoi corriger ?',
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (motif.text.trim().isEmpty) {
                  setState(() => erreur = 'Indiquez la raison.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Corriger'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    String? bracelet;
    if (statut == 'faite') {
      bracelet = await scannerQr(
        context,
        titre: 'Bracelet du patient',
        consigne: 'Scannez le bracelet du patient.',
      );
      if (bracelet == null) return;
    }
    await _faire(
      () => _service.corrigerPrise(
        _s.uuid,
        p,
        statut: statut,
        motif: motif.text.trim(),
        bracelet: bracelet,
      ),
      'Prise corrigée.',
    );
  }

  Future<void> _arreter(SoinPrescrit soin) async {
    if (await _confirmer(
      'Arrêter ce soin ?',
      '${soin.resume}\n\nLes prises à venir disparaissent du plan.',
      'Arrêter',
    )) {
      await _faire(() => _service.arreter(soin.uuid), 'Soin arrêté.');
    }
  }

  Future<void> _annulerAdmission() async {
    if (!await _confirmer(
      'Annuler l’admission ?',
      'Pour une admission faite par erreur : le lit se libère, rien n’est facturé, les soins prescrits s’arrêtent.',
      'Annuler l’admission',
    )) {
      return;
    }
    await _faire(() => _service.annuler(_s.uuid), 'Admission annulée.');
  }

  Future<void> _prescrire() async {
    final produit = TextEditingController();
    final dose = TextEditingController();
    final instructions = TextEditingController();
    var voie = 'po';
    final horaires = <String>{'08:00'};
    const proposes = [
      '06:00',
      '08:00',
      '12:00',
      '14:00',
      '16:00',
      '18:00',
      '20:00',
      '22:00',
      '00:00',
    ];
    final aujourdhui = DateUtils.dateOnly(DateTime.now());
    // La durée : null = jusqu'à l'arrêt ou la sortie.
    DateTime? fin;
    String? erreurProduit;
    String? erreurHeures;
    String duree(DateTime f) {
      final jours = f.difference(aujourdhui).inDays + 1;
      return '$jours jour${jours > 1 ? 's' : ''}, jusqu’au ${dateCourte(f)}';
    }

    final donnees = await formulaire<Map<String, dynamic>>(
      context,
      titre: const Text('Prescrire un soin'),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: produit,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Produit (ex. Artésunate)',
              errorText: erreurProduit,
            ),
            onChanged: (_) {
              if (erreurProduit != null) setState(() => erreurProduit = null);
            },
          ),
          TextField(
            controller: dose,
            decoration: const InputDecoration(labelText: 'Dose (ex. 120 mg)'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in voies.entries)
                ChoiceChip(
                  label: Text(v.value),
                  selected: voie == v.key,
                  onSelected: (_) => setState(() => voie = v.key),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Heures'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in proposes)
                FilterChip(
                  label: Text(h),
                  selected: horaires.contains(h),
                  onSelected: (oui) => setState(() {
                    oui ? horaires.add(h) : horaires.remove(h);
                    erreurHeures = null;
                  }),
                ),
            ],
          ),
          if (erreurHeures != null)
            Text(erreurHeures!, style: const TextStyle(color: Kolors.kRed)),
          const SizedBox(height: 10),
          const Text('Durée'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Jusqu’à l’arrêt'),
                selected: fin == null,
                onSelected: (_) => setState(() => fin = null),
              ),
              for (final jours in const [3, 5, 7])
                ChoiceChip(
                  label: Text('$jours jours'),
                  selected: fin == aujourdhui.add(Duration(days: jours - 1)),
                  onSelected: (_) => setState(
                    () => fin = aujourdhui.add(Duration(days: jours - 1)),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.event_rounded, size: 18),
                label: const Text('Autre date'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: fin ?? aujourdhui,
                    firstDate: aujourdhui,
                    lastDate: aujourdhui.add(const Duration(days: 365)),
                    helpText: 'Dernier jour du traitement',
                  );
                  if (d != null) setState(() => fin = d);
                },
              ),
            ],
          ),
          if (fin != null)
            Text(duree(fin!), style: const TextStyle(color: Kolors.kTextMuted)),
          TextField(
            controller: instructions,
            decoration: const InputDecoration(
              labelText: 'Consignes (facultatif)',
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
          onPressed: () {
            setState(() {
              erreurProduit = produit.text.trim().isEmpty
                  ? 'Indiquez le produit.'
                  : null;
              erreurHeures = horaires.isEmpty
                  ? 'Choisissez au moins une heure.'
                  : null;
            });
            if (erreurProduit != null || erreurHeures != null) return;
            Navigator.pop(ctx, {
              'produit': produit.text.trim(),
              'dose': dose.text.trim(),
              'voie': voie,
              'horaires': horaires.toList()..sort(),
              'instructions': instructions.text.trim(),
              if (fin != null) 'fin': DateFormat('yyyy-MM-dd').format(fin!),
            });
          },
          child: const Text('Prescrire'),
        ),
      ],
    );
    if (donnees == null) return;
    await _faire(() => _service.prescrire(_s.uuid, donnees), 'Soin prescrit.');
  }

  Future<void> _changerLit() async {
    final lit = await choisirLit(context);
    if (lit == null) return;
    await _faire(() => _service.transferer(_s.uuid, lit.uuid), 'Lit changé.');
  }

  Future<void> _sortie() async {
    final resume = TextEditingController();
    var mode = 'gueri';
    final ok = await formulaire<bool>(
      context,
      titre: const Text('Sortie du patient'),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in modesSortie.entries)
                ChoiceChip(
                  label: Text(m.value),
                  selected: mode == m.key,
                  onSelected: (_) => setState(() => mode = m.key),
                ),
            ],
          ),
          TextField(
            controller: resume,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Résumé de sortie'),
          ),
        ],
      ),
      actions: (ctx, setState) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Valider la sortie'),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    final devise = context.read<AuthController>().devise;
    try {
      final (s, f) = await _service.sortie(_s.uuid, mode, resume.text.trim());
      if (!mounted) return;
      setState(() => _s = s);
      final nuits = f == null ? '' : '${f.nuits} nuit${f.nuits > 1 ? 's' : ''}';
      _dire(
        f == null
            ? 'Sortie notée. La chambre n’a pas de prix : rien n’est facturé.'
            : f.nouvelle
            ? 'Sortie notée. La visite d’admission était close : $nuits (${formatMontant(f.montant, devise)}) sur une nouvelle facture, à régler à la caisse.'
            : 'Sortie notée : $nuits (${formatMontant(f.montant, devise)}) ajoutées à la facture.',
      );
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _imprimer() async {
    if (ImpressionTicket.imprimanteChoisie == null) {
      _dire('Choisissez l’imprimante dans File d’attente › Régler la file.');
      return;
    }
    final ok = await HospitService.imprimerBracelet(_s);
    _dire(ok ? 'Bracelet imprimé.' : 'L’imprimante ne répond pas.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final s = _s;
    final gere = s.enCours && auth.peut('hospitalisation.gerer');
    final prescrit = s.enCours && auth.peut('ordonnance.prescrire');
    final soigne = s.enCours && auth.peut('soins.administrer');

    return Scaffold(
      appBar: AppBar(title: Text(s.patient)),
      body: RefreshIndicator(
        onRefresh: () => _faire(() => _service.sejour(s.uuid)),
        child: ListView(
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
                          s.lit ?? 'Sans lit',
                          style: GoogleFonts.poppins(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          s.enCours
                              ? '${s.motif} · ${s.nuits} nuit${s.nuits > 1 ? 's' : ''}'
                              : s.annule
                              ? 'Admission annulée'
                              : 'Sorti le ${dateCourte(s.sortie)} · ${modesSortie[s.modeSortie] ?? ''}',
                          style: const TextStyle(
                            color: Kolors.kJaune,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (s.entree != null)
                          Text(
                            'Entré le ${dateCourte(s.entree)}${s.medecin == null ? '' : ' · ${s.medecin}'}',
                            style: TextStyle(
                              color: Kolors.kWhite.withValues(alpha: 0.85),
                            ),
                          ),
                        if (s.allergies != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'ALLERGIE : ${s.allergies}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _imprimer,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Kolors.kWhite,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: QrImageView(data: s.bracelet, size: 80),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (prescrit)
                  ElevatedButton.icon(
                    onPressed: _prescrire,
                    icon: const Icon(Icons.medication_liquid_rounded),
                    label: const Text('Prescrire un soin'),
                  ),
                if (gere)
                  OutlinedButton.icon(
                    onPressed: _changerLit,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Changer de lit'),
                  ),
                if (gere)
                  OutlinedButton.icon(
                    onPressed: _sortie,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sortie'),
                  ),
                if (gere && s.annulable)
                  TextButton.icon(
                    onPressed: _annulerAdmission,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Annuler l’admission'),
                  ),
                OutlinedButton.icon(
                  onPressed: _imprimer,
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Bracelet'),
                ),
              ],
            ),
            if (!s.enCours && s.resumeSortie != null) ...[
              const SizedBox(height: 12),
              Text(
                'Résumé de sortie',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(s.resumeSortie!),
            ],
            const SizedBox(height: 16),
            Text(
              'Soins du jour',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (s.plan.isEmpty)
              const Text(
                'Aucun soin prévu aujourd’hui.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            for (final p in s.plan)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p.aFaire
                        ? (p.enRetard ? Kolors.kRed : Kolors.kJauneDoux)
                        : p.statut == 'faite'
                        ? Kolors.kSuccess
                        : Kolors.kGrayLight,
                    child: Text(
                      p.heure.substring(0, 2),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: p.aFaire && !p.enRetard
                            ? Kolors.kPrimaryDark
                            : Kolors.kWhite,
                      ),
                    ),
                  ),
                  title: Text([p.produit, ?p.dose].join(' ')),
                  subtitle: Text(
                    [
                      '${p.heure} · ${voies[p.voie] ?? p.voie}',
                      if (p.statut == 'faite') 'fait par ${p.par ?? '?'}',
                      if (p.statut == 'refusee') 'refusé',
                      if (p.statut == 'omise') 'non fait',
                      if (p.aFaire && p.enRetard) 'EN RETARD',
                      if (p.corrigee) 'corrigé',
                      ?p.commentaire,
                    ].join(' · '),
                  ),
                  trailing: p.aFaire && soigne
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              tooltip: 'Non fait',
                              onSelected: (v) => _nonFait(p, v),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'refusee',
                                  child: Text('Refusé par le patient'),
                                ),
                                PopupMenuItem(
                                  value: 'omise',
                                  child: Text('Non fait'),
                                ),
                              ],
                            ),
                            FilledButton(
                              // Le thème étire les boutons sur toute la largeur.
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                              onPressed: () => _donner(p),
                              child: const Text('Donner'),
                            ),
                          ],
                        )
                      : !p.aFaire && p.corrigeable && soigne
                      ? TextButton(
                          onPressed: () => _corriger(p),
                          child: const Text('Corriger'),
                        )
                      : null,
                ),
              ),
            if (s.soins.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Plan de soins',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final soin in s.soins)
                Card(
                  child: ListTile(
                    title: Text(
                      soin.resume,
                      style: TextStyle(
                        decoration: soin.arrete
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (soin.fin != null)
                          'jusqu’au ${dateCourte(soin.fin)}',
                        ?soin.instructions,
                        ?soin.prescripteur,
                      ].join(' · '),
                    ),
                    trailing: prescrit && !soin.arrete
                        ? TextButton(
                            onPressed: () => _arreter(soin),
                            child: const Text('Arrêter'),
                          )
                        : null,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
