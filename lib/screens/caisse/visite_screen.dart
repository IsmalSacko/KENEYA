import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../caisse/caisse_service.dart';
import '../../caisse/recu.dart';
import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../dossier/dossier_models.dart';
import '../../dossier/dossier_service.dart';
import '../dossier/champs_constantes.dart';
import '../dossier/dossier_screen.dart';
import '../pharmacie/delivrance_screen.dart';
import 'recu_screen.dart';
import '../pharmacie/ordonnance_screens.dart';
import '../../common/widgets/formulaire.dart';
import '../../common/widgets/feuille.dart';

/// La facture unique de la visite : les actes de tous les services, ce qui
/// est payé, ce qui reste. Le soignant ajoute ses actes ; la caisse encaisse.
class VisiteScreen extends StatefulWidget {
  const VisiteScreen({required this.uuid, super.key});

  final String uuid;

  @override
  State<VisiteScreen> createState() => _VisiteScreenState();
}

class _VisiteScreenState extends State<VisiteScreen> {
  final _service = CaisseService();
  Visite? _visite;
  List<Tarif> _tarifs = [];
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final v = await _service.visite(widget.uuid);
      final t = await _service.tarifs();
      if (mounted) {
        setState(() {
          _visite = v;
          _tarifs = t.where((x) => x.actif).toList();
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  /// Le tri : l'infirmier note les constantes, le médecin les retrouvera.
  Future<void> _trier() async {
    final champs = controleursConstantes(
      Tri.fromJson(_visite!.tri)?.constantes,
    );
    final ok = await formulaire<bool>(
      context,
      titre: const Text('Tri : constantes'),
      corps: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          const Text(
            'Notez ce que vous avez mesuré avant la consultation. '
            'Le médecin le retrouvera dans le dossier du patient.',
            style: TextStyle(color: Kolors.kTextMuted),
          ),
          ChampsConstantes(champs: champs),
        ],
      ),
      actions: (ctx, setState) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            final probleme = erreurConstantes(champs);
            if (probleme != null) {
              ScaffoldMessenger.of(
                ctx,
              ).showSnackBar(SnackBar(content: Text(probleme)));
              return;
            }
            Navigator.pop(ctx, true);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    final constantes = lireConstantes(champs);
    if (constantes.isEmpty) return;
    try {
      await DossierService().trier(_visite!.uuid, constantes);
      await _charger();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  Future<void> _ouvrir(Widget ecran) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ecran));
    await _charger();
  }

  Future<void> _faire(Future<Visite> Function() action) async {
    try {
      final v = await action();
      if (mounted) setState(() => _visite = v);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  /// Clôturer, c'est « le patient est parti » : on prévient s'il lui reste
  /// une ordonnance à prendre à la pharmacie.
  Future<void> _cloturer(Visite v) async {
    if (v.ordonnancesAServir > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ordonnance pas encore servie'),
          content: const Text(
            'Les médicaments ne sont pas encore facturés. Envoyez d’abord le patient à la pharmacie.\n\nS’il les achète ailleurs, clôturez : il pourra revenir avec le QR de son ordonnance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Attendre'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clôturer quand même'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _faire(() => _service.cloturerVisite(v.uuid));
  }

  Future<void> _ajouter() async {
    final v = _visite!;
    final choix = await feuille<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ChoixActe(tarifs: _tarifs, devise: v.devise),
    );
    if (choix is Tarif) {
      await _faire(() => _service.ajouterActe(v.uuid, choix));
    } else if (choix is (String, int)) {
      await _faire(
        () => _service.ajouterLigneLibre(v.uuid, choix.$1, choix.$2),
      );
    }
  }

  Future<void> _assurer() async {
    final v = _visite!;
    final List<Assureur> assureurs;
    try {
      assureurs = (await _service.assureurs()).where((a) => a.actif).toList();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
      return;
    }
    if (!mounted) return;
    if (assureurs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun assureur : ajoutez-les dans Caisse › Assureurs.',
          ),
        ),
      );
      return;
    }
    final numero = TextEditingController();
    String choisi = assureurs.first.uuid;
    final ok = await formulaire<bool>(
      context,
      titre: const Text('Patient assuré'),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: choisi,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Assureur'),
            items: [
              for (final a in assureurs)
                DropdownMenuItem(
                  value: a.uuid,
                  child: Text(
                    '${a.nom} · ${a.taux} %',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (x) => setState(() => choisi = x ?? choisi),
          ),
          TextField(
            controller: numero,
            decoration: const InputDecoration(
              labelText: 'Numéro d’assuré (sur la carte)',
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
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Appliquer'),
        ),
      ],
    );
    if (ok != true || numero.text.trim().isEmpty) return;
    await _faire(() => _service.couvrir(v.uuid, choisi, numero.text.trim()));
  }

  Future<void> _encaisser() async {
    final v = _visite!;
    final session = await _service.session();
    if (!mounted) return;
    if (session['session'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ouvrez votre caisse (onglet Caisse) avant d’encaisser.',
          ),
        ),
      );
      return;
    }
    final moyens = (session['moyens'] as List)
        .map((m) => m.toString())
        .toList();
    final paiement = await feuille<(int, String, String?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _Encaissement(reste: v.reste, devise: v.devise, moyens: moyens),
    );
    if (paiement == null) return;
    await _faire(
      () => _service.encaisser(
        v.uuid,
        montant: paiement.$1,
        moyen: paiement.$2,
        reference: paiement.$3,
      ),
    );
    // Encaissé : le reçu s'ouvre aussitôt, comme le ticket de Ngoni Caisse.
    final apres = _visite;
    if (mounted && apres != null && apres.paye > v.paye) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RecuScreen(recu: Recu.deVisite(apres)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final v = _visite;
    final peutFacturer = [
      'caisse.encaisser',
      'consultation.faire',
      'pharmacie.delivrer',
      'labo.saisir',
      'soins.administrer',
    ].any(auth.peut);
    final peutEncaisser = auth.peut('caisse.encaisser');

    return Scaffold(
      appBar: AppBar(
        title: Text(v?.titre ?? 'Visite'),
        actions: [
          if (v != null && v.paye > 0)
            IconButton(
              tooltip: 'Reçu',
              icon: const Icon(Icons.receipt_long_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecuScreen(recu: Recu.deVisite(v)),
                ),
              ),
            ),
        ],
      ),
      body: v == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : RefreshIndicator(
              onRefresh: _charger,
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
                                v.tickets.isEmpty ? '—' : v.tickets.join(' → '),
                                style: TextStyle(
                                  color: Kolors.kWhite.withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                v.reste == 0 && v.total > 0
                                    ? 'Payé'
                                    : 'Reste à payer',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                formatMontant(v.reste, v.devise),
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Kolors.kJaune,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total ${formatMontant(v.total, v.devise)}'),
                            if (v.partAssureur > 0)
                              Text(
                                'Assureur ${formatMontant(v.partAssureur, v.devise)}',
                              ),
                            Text('Payé ${formatMontant(v.paye, v.devise)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (v.ouverte && v.ordonnancesAServir > 0) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Kolors.kJauneDoux,
                      child: const ListTile(
                        leading: Icon(
                          Icons.medication_rounded,
                          color: Kolors.kPrimaryDark,
                        ),
                        title: Text('Ordonnance pas encore servie'),
                        subtitle: Text(
                          'Le patient passe d’abord à la pharmacie : les médicaments s’ajoutent à cette facture quand elle les délivre.',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        if (v.lignes.isEmpty)
                          const ListTile(
                            title: Text('Aucun acte facturé pour l’instant.'),
                            subtitle: Text(
                              'Ajoutez l’acte fait (ex. la consultation). Pour qu’il s’ajoute tout seul à chaque ticket : File d’attente › Régler la file › le service.',
                            ),
                          ),
                        for (final l in v.lignes)
                          ListTile(
                            title: Text(l.libelle),
                            subtitle: l.quantite > 1
                                ? Text(
                                    '${l.quantite} × ${formatMontant(l.prixUnitaire, v.devise)}',
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatMontant(l.montant, v.devise),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (v.ouverte && peutFacturer)
                                  IconButton(
                                    tooltip: 'Retirer',
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () => _faire(
                                      () =>
                                          _service.retirerLigne(v.uuid, l.uuid),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (auth.aModule('assurances') &&
                      (v.assureur != null ||
                          (v.ouverte &&
                              (auth.peut('caisse.encaisser') ||
                                  auth.peut('assurances.gerer'))))) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.health_and_safety_rounded,
                          color: Kolors.kPrimary,
                        ),
                        title: Text(
                          v.assureur == null
                              ? 'Le patient est assuré ?'
                              : '${v.assureur} · ${v.tauxAssurance ?? ''} %',
                        ),
                        subtitle: v.assureur == null
                            ? null
                            : Text(
                                'N° ${v.numeroAssure ?? '—'} · part assureur ${formatMontant(v.partAssureur, v.devise)}',
                              ),
                        trailing: !v.ouverte
                            ? null
                            : v.assureur == null
                            ? TextButton(
                                onPressed: _assurer,
                                child: const Text('Ajouter'),
                              )
                            : TextButton(
                                onPressed: () => _faire(
                                  () => _service.retirerAssurance(v.uuid),
                                ),
                                child: const Text('Retirer'),
                              ),
                      ),
                    ),
                  ],
                  if (v.encaissements.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Paiements',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Card(
                      child: Column(
                        children: [
                          for (final e in v.encaissements)
                            ListTile(
                              leading: const Icon(
                                Icons.check_circle_rounded,
                                color: Kolors.kSuccess,
                              ),
                              title: Text(e.moyenLabel),
                              subtitle: e.reference == null
                                  ? null
                                  : Text('Réf. ${e.reference}'),
                              trailing: Text(
                                formatMontant(e.montant, v.devise),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (Tri.fromJson(v.tri) case final tri?) ...[
                    Card(
                      color: Kolors.kSecondaryLight,
                      child: ListTile(
                        leading: const Icon(Icons.monitor_heart_outlined),
                        title: Text(tri.resume),
                        subtitle: Text(
                          [
                            'Tri',
                            if (tri.par != null) 'par ${tri.par}',
                            if (tri.le != null)
                              'à ${tri.le!.hour.toString().padLeft(2, '0')}:${tri.le!.minute.toString().padLeft(2, '0')}',
                          ].join(' '),
                        ),
                        trailing:
                            v.ouverte &&
                                (auth.peut('dossier.ecrire') ||
                                    auth.peut('consultation.faire'))
                            ? TextButton(
                                onPressed: _trier,
                                child: const Text('Modifier'),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else if (v.ouverte &&
                      (auth.peut('dossier.ecrire') ||
                          auth.peut('consultation.faire'))) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: _trier,
                      icon: const Icon(Icons.monitor_heart_outlined),
                      label: const Text('Tri : constantes'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (auth.peut('dossier.lire')) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      // Analyses et nuits d'hospitalisation s'ajoutent à la
                      // facture : on la relit au retour.
                      onPressed: () =>
                          _ouvrir(DossierScreen(visiteUuid: v.uuid)),
                      icon: const Icon(Icons.folder_shared_rounded),
                      label: Text(
                        auth.peut('consultation.faire')
                            ? 'Dossier et consultation'
                            : 'Dossier',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (v.ouverte && auth.peut('ordonnance.prescrire')) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () => _ouvrir(
                        PrescrireScreen(visiteUuid: v.uuid, patient: v.titre),
                      ),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Ordonnance'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (v.ouverte &&
                      auth.aModule('pharmacie') &&
                      auth.peut('pharmacie.delivrer')) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: () =>
                          _ouvrir(DelivranceScreen(visiteUuid: v.uuid)),
                      icon: const Icon(Icons.medication_outlined),
                      label: const Text('Médicaments'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (v.ouverte && peutFacturer)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: _ajouter,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un acte'),
                    ),
                  if (v.ouverte && peutEncaisser && v.reste > 0) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Kolors.kJaune,
                          foregroundColor: Kolors.kPrimaryDark,
                        ),
                        onPressed: _encaisser,
                        icon: const Icon(Icons.payments_rounded),
                        label: Text(
                          'Encaisser ${formatMontant(v.reste, v.devise)}',
                        ),
                      ),
                    ),
                  ],
                  if (v.ouverte &&
                      peutEncaisser &&
                      v.reste == 0 &&
                      v.total > 0) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => _cloturer(v),
                      child: const Text('Clôturer la visite'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Un acte du tarif, ou une ligne libre (libellé et prix).
class _ChoixActe extends StatefulWidget {
  const _ChoixActe({required this.tarifs, required this.devise});

  final List<Tarif> tarifs;
  final String devise;

  @override
  State<_ChoixActe> createState() => _ChoixActeState();
}

class _ChoixActeState extends State<_ChoixActe> {
  final _recherche = TextEditingController();
  final _libelle = TextEditingController();
  final _prix = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final q = _recherche.text.toLowerCase();
    final tarifs = widget.tarifs
        .where((t) => t.nom.toLowerCase().contains(q))
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _recherche,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Chercher un acte',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            for (final t in tarifs)
              ListTile(
                title: Text(t.nom),
                subtitle: Text(libellesCategories[t.categorie] ?? t.categorie),
                trailing: Text(formatMontant(t.prix, widget.devise)),
                onTap: () => Navigator.pop(context, t),
              ),
            if (widget.tarifs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Pas encore de tarifs : l’administrateur les règle dans Caisse › Tarifs et rapport.',
                  style: TextStyle(color: Kolors.kTextMuted),
                ),
              ),
            const Divider(height: 28),
            const Text(
              'Autre acte',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _libelle,
                    decoration: const InputDecoration(labelText: 'Libellé'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _prix,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d ,.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Prix (${widget.devise})',
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: () {
                    final prix = lireMontant(_prix.text, widget.devise);
                    if (_libelle.text.trim().isEmpty || prix == null) return;
                    Navigator.pop(context, (_libelle.text.trim(), prix));
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Montant (tout le reste par défaut), moyen de paiement, référence.
class _Encaissement extends StatefulWidget {
  const _Encaissement({
    required this.reste,
    required this.devise,
    required this.moyens,
  });

  final int reste;
  final String devise;
  final List<String> moyens;

  @override
  State<_Encaissement> createState() => _EncaissementState();
}

class _EncaissementState extends State<_Encaissement> {
  late final _montant = TextEditingController(
    text: formatMontant(
      widget.reste,
      widget.devise,
    ).replaceAll(RegExp(r'[^\d,]'), ''),
  );
  final _reference = TextEditingController();
  String _moyen = 'especes';

  @override
  Widget build(BuildContext context) {
    final mobile = _moyen != 'especes';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Encaisser',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Kolors.kTextHigh,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _montant,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: 'Montant (${widget.devise})',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in widget.moyens)
                  ChoiceChip(
                    label: Text(libellesMoyens[m] ?? m),
                    selected: _moyen == m,
                    onSelected: (_) => setState(() => _moyen = m),
                  ),
              ],
            ),
            if (mobile) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Référence de la transaction (reçue par SMS)',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final montant = lireMontant(_montant.text, widget.devise);
                  if (montant == null || montant <= 0) return;
                  if (mobile && _reference.text.trim().isEmpty) return;
                  Navigator.pop(context, (
                    montant,
                    _moyen,
                    mobile ? _reference.text.trim() : null,
                  ));
                },
                child: const Text('Valider le paiement'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
