import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../common/whatsapp.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../dossier/dossier_models.dart';
import '../../file/file_service.dart';
import '../../patients/patients_service.dart';
import '../caisse/visite_screen.dart';
import '../dossier/dossier_screen.dart';
import '../dossier/dossier_widgets.dart';
import '../hospitalisation/sejour_screen.dart';
import '../labo/demander_analyses_screen.dart';
import '../maternite/carnet_screen.dart';
import '../maternite/grossesse_screen.dart';
import '../pharmacie/ordonnance_screens.dart';
import '../../rdv/rdv_service.dart';
import '../file/donner_ticket_sheet.dart';
import '../rdv/nouveau_rdv_sheet.dart';
import '../../common/widgets/formulaire.dart';

/// Nouveau patient à l'accueil. Pendant qu'on tape, ceux déjà enregistrés
/// s'affichent : un toucher ouvre leur fiche, sans rien retaper. Renvoie le
/// patient (nouveau ou retrouvé), ou null.
Future<Patient?> nouveauPatient(
  BuildContext context, {
  String recherche = '',
}) async {
  final identite = await editerPatient(context, null, recherche);
  if (identite == null) return null;
  if (identite['existant'] case final Patient p) return p;
  final (p, existant) = await PatientsService().creer(identite);
  if (existant && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ce patient est déjà enregistré : voici sa fiche.'),
      ),
    );
  }
  return p;
}

/// Créer ou corriger la fiche : nom, sexe, âge (ou date de naissance),
/// téléphone, quartier. Renvoie les champs, ou null ; à la création,
/// `{'existant': Patient}` si l'accueil a reconnu un patient déjà venu.
Future<Map<String, dynamic>?> editerPatient(
  BuildContext context, [
  Patient? p,
  String recherche = '',
]) {
  // Ce qu'on avait cherché remplit déjà le nom, ou le téléphone.
  final chiffres = RegExp(r'^[\d\s+]+$').hasMatch(recherche.trim());
  final nom = TextEditingController(
    text: p?.nom ?? (chiffres ? null : recherche.trim()),
  );
  final age = TextEditingController(
    text: p?.age == null || p!.naissanceEstimee == false ? '' : '${p.age}',
  );
  final telephone = TextEditingController(
    text: p?.telephone ?? (chiffres ? recherche.trim() : null),
  );
  final adresse = TextEditingController(text: p?.adresse);
  String? sexe = p?.sexe;
  DateTime? naissance = p != null && !p.naissanceEstimee
      ? DateTime.tryParse(p.dateNaissance ?? '')
      : null;

  return formulaire<Map<String, dynamic>>(
    context,
    titre: Text(p == null ? 'Nouveau patient' : 'Fiche du patient'),
    corps: (ctx, setState) => Column(
      spacing: 12,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nom,
          autofocus: p == null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Prénom et nom'),
        ),
        if (p == null)
          DejaEnregistres(
            nom: nom,
            telephone: telephone,
            onChoisir: (x) => Navigator.pop(ctx, {'existant': x}),
          ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'F', label: Text('Femme')),
            ButtonSegment(value: 'M', label: Text('Homme')),
          ],
          selected: {?sexe},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) =>
              setState(() => sexe = s.isEmpty ? null : s.first),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: age,
                enabled: naissance == null,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Âge (ans)'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () async {
                final choix = await showDatePicker(
                  context: ctx,
                  initialDate: naissance ?? DateTime(1990),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (choix != null) setState(() => naissance = choix);
              },
              icon: const Icon(Icons.cake_outlined, size: 18),
              label: Text(
                naissance == null ? 'Date exacte' : dateCourte(naissance),
              ),
            ),
          ],
        ),
        TextField(
          controller: telephone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Téléphone (pour les SMS)',
          ),
        ),
        TextField(
          controller: adresse,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Quartier'),
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
          if (nom.text.trim().isEmpty) return;
          Navigator.pop(ctx, {
            'nom': nom.text.trim(),
            'sexe': sexe,
            'telephone': telephone.text.trim(),
            'adresse': adresse.text.trim(),
            if (naissance != null)
              'date_naissance':
                  '${naissance!.year}-${naissance!.month.toString().padLeft(2, '0')}-${naissance!.day.toString().padLeft(2, '0')}'
            else if (int.tryParse(age.text) != null)
              'age': int.parse(age.text),
          });
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

/// Une action de la fiche : icône et mot, un toucher.
class _Action extends StatelessWidget {
  const _Action(this.icone, this.libelle, this.onTap);

  final IconData icone;
  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              Icon(icone, color: Kolors.kPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  libelle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Déjà venu ? » : les patients qui ressemblent à ce qu'on tape (nom, ou
/// numéro dès 6 chiffres).
class DejaEnregistres extends StatefulWidget {
  const DejaEnregistres({
    required this.nom,
    required this.telephone,
    required this.onChoisir,
    super.key,
  });

  final TextEditingController nom;
  final TextEditingController telephone;
  final ValueChanged<Patient> onChoisir;

  @override
  State<DejaEnregistres> createState() => _DejaEnregistresState();
}

class _DejaEnregistresState extends State<DejaEnregistres> {
  Timer? _attente;
  String _cherche = '';
  List<Patient> _trouves = [];

  @override
  void initState() {
    super.initState();
    widget.nom.addListener(_changer);
    widget.telephone.addListener(_changer);
    _changer();
  }

  @override
  void dispose() {
    _attente?.cancel();
    widget.nom.removeListener(_changer);
    widget.telephone.removeListener(_changer);
    super.dispose();
  }

  void _changer() {
    final numero = widget.telephone.text.replaceAll(RegExp(r'\D'), '');
    final nom = widget.nom.text.trim();
    final q = numero.length >= 6 ? numero : (nom.length >= 3 ? nom : '');
    if (q == _cherche) return;
    _cherche = q;
    _attente?.cancel();
    if (q.isEmpty) {
      setState(() => _trouves = []);
      return;
    }
    _attente = Timer(const Duration(milliseconds: 350), () async {
      try {
        final l = await PatientsService().rechercher(q);
        // Une réponse arrivée après une autre frappe ne compte plus.
        if (mounted && q == _cherche) {
          setState(() => _trouves = l.take(5).toList());
        }
      } on DioException {
        // Pas de réseau : on enregistre sans suggestion.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_trouves.isEmpty) return const SizedBox.shrink();
    return Card(
      color: Kolors.kJauneDoux,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Déjà venu ? Touchez sa fiche plutôt que de la refaire.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final x in _trouves)
            ListTile(
              leading: const Icon(Icons.person_search_rounded),
              title: Text(x.nom),
              subtitle: Text(
                [x.resume, ?x.telephone].where((t) => t.isNotEmpty).join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => widget.onChoisir(x),
            ),
        ],
      ),
    );
  }
}

/// La fiche du patient : son identité, ses visites, et ce qu'on fait pour
/// lui aujourd'hui (l'envoyer en consultation, ouvrir son dossier).
class PatientScreen extends StatefulWidget {
  const PatientScreen({required this.patient, super.key});

  final Patient patient;

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  final _service = PatientsService();
  late Patient _p = widget.patient;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final p = await _service.fiche(_p.uuid);
      if (mounted) setState(() => _p = p);
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _modifier() async {
    final d = await editerPatient(context, _p);
    if (d == null) return;
    try {
      final p = await _service.modifier(_p.uuid, d);
      if (mounted) setState(() => _p = p);
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _envoyer() async {
    try {
      final services = await FileService().services();
      if (!mounted) return;
      final ticket = await donnerTicket(
        context,
        services,
        patient: _p,
        consultation: _p.visiteDuJour == null,
      );
      if (ticket != null) await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _nouveauPin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN oublié'),
        content: const Text(
          'Vérifiez sa pièce d’identité. Un nouveau PIN va s’afficher : donnez-le lui, il pourra le changer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pièce vérifiée'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final pin = await _service.nouveauPin(_p.uuid);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nouveau PIN'),
          content: Text(
            pin,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('C’est noté'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _rendezVous() async {
    try {
      final agendas = await RdvService().agendas();
      if (!mounted) return;
      if (agendas.where((a) => a.actif).isEmpty) {
        _dire('Aucun agenda : créez-le dans Rendez-vous (icône calendrier).');
        return;
      }
      final ok = await nouveauRdv(
        context,
        agendas,
        DateTime.now(),
        patient: _p,
      );
      if (ok == true) await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _ouvrir(Widget ecran) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ecran));
    await _charger();
  }

  /// Ce qu'on fait pour ce patient, selon qui on est et s'il est là
  /// aujourd'hui : l'accueil l'envoie, le soignant le soigne, et tout le
  /// monde suit (rendez-vous, carnet, message).
  List<Widget> _actions(AuthController auth, Patient p, VisitePatient? duJour) {
    final envoyer = auth.aModule('file') && auth.peut('file.emettre');
    final soigne = duJour != null && auth.peut('consultation.faire');
    final visite = duJour?.uuid;
    final dossier = DossierPatient(
      uuid: p.uuid,
      nom: p.nom,
      aUnCompte: p.aUnCompte,
      consultations: const [],
    );
    DossierScreen ecranDossier() =>
        DossierScreen(visiteUuid: visite, dossier: dossier);

    final tuiles = <_Action>[
      if (envoyer && duJour != null)
        _Action(
          Icons.confirmation_number_outlined,
          'Autre service',
          _envoyer,
        ),
      if (visite != null && auth.peut('ordonnance.prescrire'))
        _Action(
          Icons.receipt_long_outlined,
          'Ordonnance',
          () => _ouvrir(PrescrireScreen(visiteUuid: visite, patient: p.nom)),
        ),
      if (soigne && auth.aModule('labo'))
        _Action(
          Icons.science_outlined,
          'Analyses',
          () => _ouvrir(
            DemanderAnalysesScreen(visiteUuid: visite!, patient: p.nom),
          ),
        ),
      if (visite != null &&
          p.sexe != 'M' &&
          auth.aModule('maternite') &&
          auth.peut('maternite.suivre'))
        _Action(
          Icons.pregnant_woman_rounded,
          'Grossesse · CPN',
          () => ouvrirGrossesse(context, visite),
        ),
      if ((p.age ?? 99) < 6 &&
          (auth.peut('maternite.suivre') || auth.peut('dossier.ecrire')))
        _Action(
          Icons.vaccines_outlined,
          'Carnet de vaccination',
          () => _ouvrir(CarnetScreen(dossierUuid: p.uuid)),
        ),
      if (visite != null &&
          auth.aModule('hospitalisation') &&
          auth.peut('hospitalisation.gerer'))
        _Action(
          Icons.bed_outlined,
          'Hospitaliser',
          () => hospitaliser(context, visite),
        ),
      if (auth.aModule('rdv') && auth.peut('rdv.gerer'))
        _Action(Icons.event_available_outlined, 'Rendez-vous', _rendezVous),
      if (auth.peut('dossier.lire') && !soigne)
        _Action(
          Icons.folder_shared_outlined,
          'Dossier médical',
          () => _ouvrir(ecranDossier()),
        ),
      if (p.telephone != null)
        _Action(
          Icons.chat_outlined,
          'WhatsApp',
          () => envoyerWhatsApp(context, p.telephone!, 'Bonjour ${p.nom}, '),
        ),
    ];

    return [
      if (duJour != null) const SizedBox(height: 10),
      // L'action du moment, en grand.
      if (soigne)
        ElevatedButton.icon(
          onPressed: () => _ouvrir(ecranDossier()),
          icon: const Icon(Icons.medical_services_rounded),
          label: const Text('Consulter'),
        )
      else if (envoyer && duJour == null)
        ElevatedButton.icon(
          onPressed: _envoyer,
          icon: const Icon(Icons.confirmation_number_rounded),
          label: const Text('Envoyer en consultation'),
        ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, c) {
          final colonnes = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 3 : 2);
          final largeur = (c.maxWidth - 8 * (colonnes - 1)) / colonnes;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tuiles) SizedBox(width: largeur, child: t),
            ],
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final p = _p;
    final duJour = p.visiteDuJour;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient'),
        actions: [
          if (auth.peut('patients.gerer'))
            IconButton(
              tooltip: 'Corriger la fiche',
              icon: const Icon(Icons.edit_rounded),
              onPressed: _modifier,
            ),
          if (auth.peut('patients.gerer') && _p.aUnCompte)
            IconButton(
              tooltip: 'PIN oublié',
              icon: const Icon(Icons.password_rounded),
              onPressed: _nouveauPin,
            ),
        ],
      ),
      body: RefreshIndicator(
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
                          p.nom,
                          style: GoogleFonts.poppins(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (p.resume.isNotEmpty)
                          Text(
                            p.resume,
                            style: const TextStyle(
                              color: Kolors.kJaune,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (p.telephone != null)
                          Text(
                            p.telephone!,
                            style: TextStyle(
                              color: Kolors.kWhite.withValues(alpha: 0.85),
                            ),
                          ),
                        if (p.aUnCompte)
                          Text(
                            'A l’app Ngoni Santé',
                            style: TextStyle(
                              color: Kolors.kWhite.withValues(alpha: 0.85),
                              fontSize: 12.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const AvatarMarque(Icons.person_rounded),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (duJour != null)
              Card(
                color: Kolors.kJauneDoux,
                child: ListTile(
                  leading: const Icon(Icons.today_rounded),
                  title: const Text('Visite en cours aujourd’hui'),
                  subtitle: Text(
                    duJour.services.isEmpty
                        ? 'Ouverte'
                        : duJour.services.join(' › '),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _ouvrir(VisiteScreen(uuid: duJour.uuid)),
                ),
              ),
            ..._actions(auth, p, duJour),
            if (p.rendezVous.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Prochains rendez-vous',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final r in p.rendezVous)
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.event_rounded,
                      color: Kolors.kPrimary,
                    ),
                    title: Text(
                      r.debut == null
                          ? 'À fixer'
                          : '${dateCourte(r.debut)} à ${r.debut!.hour.toString().padLeft(2, '0')}:${r.debut!.minute.toString().padLeft(2, '0')}',
                    ),
                    subtitle: Text([?r.agenda, ?r.motif].join(' · ')),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              'Visites',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (p.visites.isEmpty)
              const Text(
                'Pas encore de visite ici.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            for (final v in p.visites)
              Card(
                child: ListTile(
                  leading: Icon(
                    v.ouverte
                        ? Icons.pending_actions_rounded
                        : Icons.check_circle_outline_rounded,
                    color: v.ouverte ? Kolors.kWarning : Kolors.kSuccess,
                  ),
                  title: Text(dateCourte(v.date)),
                  subtitle: Text(
                    v.resume,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    v.reste > 0
                        ? 'Reste ${formatMontant(v.reste, v.devise)}'
                        : formatMontant(v.total, v.devise),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: v.reste > 0 ? Kolors.kRed : null,
                    ),
                  ),
                  onTap: () => _ouvrir(VisiteScreen(uuid: v.uuid)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
