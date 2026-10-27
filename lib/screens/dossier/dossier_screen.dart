import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../dossier/dossier_models.dart';
import '../../dossier/dossier_service.dart';
import '../commun/scanner_qr_screen.dart';
import '../labo/demander_analyses_screen.dart';
import '../maternite/carnet_screen.dart';
import '../maternite/grossesse_screen.dart';
import '../hospitalisation/sejour_screen.dart';
import 'champs_constantes.dart';
import 'dossier_widgets.dart';

/// Le dossier d'un patient, ouvert depuis sa visite ou depuis la recherche.
/// Sans l'accord du patient, on ne voit que ce que l'établissement a noté.
class DossierScreen extends StatefulWidget {
  const DossierScreen({this.visiteUuid, this.dossier, super.key})
    : assert(visiteUuid != null || dossier != null);

  final String? visiteUuid;
  final DossierPatient? dossier;

  @override
  State<DossierScreen> createState() => _DossierScreenState();
}

class _DossierScreenState extends State<DossierScreen> {
  final _service = DossierService();
  DossierPatient? _d;
  Tri? _tri;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _d = widget.dossier;
    _charger();
  }

  Future<void> _charger() async {
    try {
      if (widget.visiteUuid != null) {
        final (d, tri) = await _service.pourVisite(widget.visiteUuid!);
        if (mounted) {
          setState(() {
            _d = d;
            _tri = tri;
          });
        }
      } else {
        final (d, tri) = await _service.dossier(widget.dossier!.uuid);
        if (mounted) {
          setState(() {
            _d = d;
            _tri = tri;
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  void _message(String texte) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texte)));

  Future<void> _demanderParSms(DossierPatient d) async {
    try {
      await _service.envoyerCode(d.uuid);
    } on DioException catch (e) {
      _message(messageErreur(e));
      return;
    }
    if (!mounted) return;
    final code = await _saisirCode();
    if (code == null || !mounted) return;
    try {
      final ouvert = await _service.accorderParCode(d.uuid, code);
      if (mounted) setState(() => _d = ouvert);
      _message('Historique ouvert pour 7 jours.');
    } on DioException catch (e) {
      _message(messageErreur(e));
    }
  }

  Future<String?> _saisirCode() {
    final code = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code du patient'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Le patient vient de recevoir un code par SMS. Demandez-le lui.',
              ),
              TextField(
                controller: code,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Code à 6 chiffres',
                ),
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
            onPressed: () => Navigator.pop(ctx, code.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _scannerAccord() async {
    final qr = await scannerQr(
      context,
      titre: 'QR d’accord',
      consigne: 'Le patient ouvre « Mon dossier » et montre son QR.',
    );
    if (qr == null || !mounted) return;
    try {
      final ouvert = await _service.accorderParQr(qr);
      if (mounted) setState(() => _d = ouvert);
      _message('Historique ouvert pour 7 jours.');
    } on DioException catch (e) {
      _message(messageErreur(e));
    }
  }

  Future<void> _modifier(DossierPatient d) async {
    final donnees = await editerInfosMedicales(context, d);
    if (donnees == null) return;
    try {
      await _service.modifier(d.uuid, donnees);
      await _charger();
    } on DioException catch (e) {
      _message(messageErreur(e));
    }
  }

  Future<void> _demanderAnalyses(DossierPatient d) async {
    final fait = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DemanderAnalysesScreen(
          visiteUuid: widget.visiteUuid!,
          patient: d.nom,
        ),
      ),
    );
    if (fait == true) await _charger();
  }

  Future<void> _consulter(DossierPatient d) async {
    final fait = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConsultationScreen(
          visiteUuid: widget.visiteUuid!,
          patient: d.nom,
          tri: _tri,
        ),
      ),
    );
    if (fait == true) await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final d = _d;
    final peutConsulter =
        widget.visiteUuid != null && auth.peut('consultation.faire');

    return Scaffold(
      appBar: AppBar(title: const Text('Dossier patient')),
      floatingActionButton: d != null && peutConsulter
          ? FloatingActionButton.extended(
              onPressed: () => _consulter(d),
              icon: const Icon(Icons.medical_services_rounded),
              label: const Text('Consultation'),
            )
          : null,
      body: d == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  CarteMarque(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.nom,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (d.resume.isNotEmpty)
                                Text(
                                  d.resume,
                                  style: const TextStyle(
                                    color: Kolors.kJaune,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (d.telephone != null)
                                Text(
                                  d.telephone!,
                                  style: TextStyle(
                                    color: Kolors.kWhite.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const AvatarMarque(Icons.folder_shared_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_tri != null)
                    Card(
                      color: Kolors.kSecondaryLight,
                      child: ListTile(
                        leading: const Icon(Icons.monitor_heart_outlined),
                        title: Text(_tri!.resume),
                        subtitle: Text(
                          'Tri${_tri!.par == null ? '' : ' par ${_tri!.par}'}'
                          '${_tri!.le == null ? '' : ' à ${_tri!.le!.hour.toString().padLeft(2, '0')}:${_tri!.le!.minute.toString().padLeft(2, '0')}'}',
                        ),
                      ),
                    ),
                  BlocMedical(
                    d,
                    onModifier: auth.peut('dossier.ecrire')
                        ? () => _modifier(d)
                        : null,
                  ),
                  if (!d.accesHistorique && d.peutDemanderAcces)
                    _DemandeAcces(
                      ailleurs: d.consultationsAilleurs,
                      onSms: () => _demanderParSms(d),
                      onQr: _scannerAccord,
                    ),
                  if ((widget.visiteUuid != null &&
                          auth.aModule('maternite') &&
                          auth.peut('maternite.suivre') &&
                          d.sexe != 'M') ||
                      ((d.age ?? 99) < 6 &&
                          (auth.peut('maternite.suivre') ||
                              auth.peut('dossier.ecrire'))))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.visiteUuid != null &&
                              auth.aModule('maternite') &&
                              auth.peut('maternite.suivre') &&
                              d.sexe != 'M')
                            OutlinedButton.icon(
                              onPressed: () =>
                                  ouvrirGrossesse(context, widget.visiteUuid!),
                              icon: const Icon(Icons.pregnant_woman_rounded),
                              label: const Text('Grossesse'),
                            ),
                          if ((d.age ?? 99) < 6)
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CarnetScreen(dossierUuid: d.uuid),
                                ),
                              ),
                              icon: const Icon(Icons.vaccines_rounded),
                              label: const Text('Carnet de vaccination'),
                            ),
                        ],
                      ),
                    ),
                  if (widget.visiteUuid != null &&
                      auth.aModule('hospitalisation') &&
                      auth.peut('hospitalisation.gerer'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            hospitaliser(context, widget.visiteUuid!),
                        icon: const Icon(Icons.bed_rounded),
                        label: const Text('Hospitaliser'),
                      ),
                    ),
                  if (d.accesHistorique)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(
                        'Le patient vous a ouvert tout son historique.',
                        style: TextStyle(
                          color: Kolors.kSuccess,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Consultations',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (d.consultations.isEmpty)
                    const Text(
                      'Aucune consultation notée.',
                      style: TextStyle(color: Kolors.kTextMuted),
                    ),
                  for (final c in d.consultations) CarteConsultation(c),
                  if (d.analyses.isNotEmpty || peutConsulter) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Analyses',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final a in d.analyses) CarteAnalyses(a),
                    if (peutConsulter && auth.aModule('labo'))
                      OutlinedButton.icon(
                        onPressed: () => _demanderAnalyses(d),
                        icon: const Icon(Icons.science_outlined),
                        label: const Text('Demander des analyses'),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _DemandeAcces extends StatelessWidget {
  const _DemandeAcces({
    required this.ailleurs,
    required this.onSms,
    required this.onQr,
  });

  final int ailleurs;
  final VoidCallback onSms;
  final VoidCallback onQr;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Kolors.kJauneDoux,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ailleurs > 0
                  ? '$ailleurs consultation${ailleurs > 1 ? 's' : ''} ailleurs'
                  : 'Historique tenu ailleurs',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Text(
              'Avec l’accord du patient, vous la voyez pendant 7 jours.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onQr,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scanner son QR'),
                ),
                OutlinedButton.icon(
                  onPressed: onSms,
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Code par SMS'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// La consultation : motif, constantes, examen, diagnostic, conclusion.
class ConsultationScreen extends StatefulWidget {
  const ConsultationScreen({
    required this.visiteUuid,
    required this.patient,
    this.tri,
    super.key,
  });

  final String visiteUuid;
  final String patient;

  /// Les constantes du tri, reprises dans le formulaire.
  final Tri? tri;

  @override
  State<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends State<ConsultationScreen> {
  final _motif = TextEditingController();
  final _examen = TextEditingController();
  final _diagnostic = TextEditingController();
  final _cim10 = TextEditingController();
  final _conclusion = TextEditingController();
  late final _constantes = controleursConstantes(widget.tri?.constantes);
  DateTime? _revoir;
  bool _envoi = false;

  Future<void> _valider() async {
    final probleme = _motif.text.trim().isEmpty
        ? 'Indiquez le motif de la consultation.'
        : erreurConstantes(_constantes);
    if (probleme != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(probleme)));
      return;
    }
    setState(() => _envoi = true);
    try {
      await DossierService().consulter(widget.visiteUuid, {
        'motif': _motif.text.trim(),
        'constantes': lireConstantes(_constantes),
        'examen': _examen.text.trim(),
        'diagnostic': _diagnostic.text.trim(),
        'cim10': _cim10.text.trim(),
        'conclusion': _conclusion.text.trim(),
        if (_revoir != null)
          'prochain_rdv': DateFormat('yyyy-MM-dd').format(_revoir!),
      });
      if (mounted) Navigator.pop(context, true);
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.patient)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _motif,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Motif (ex. fièvre depuis 3 jours)',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Constantes',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ChampsConstantes(champs: _constantes),
          const SizedBox(height: 12),
          TextField(
            controller: _examen,
            maxLines: null,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Examen clinique'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _diagnostic,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Diagnostic'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cim10,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Code CIM-10 (facultatif, ex. B54)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _conclusion,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Conclusion, conseils',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_repeat_rounded),
            title: Text(
              _revoir == null
                  ? 'À revoir le… (facultatif)'
                  : 'À revoir le ${dateCourte(_revoir)}',
            ),
            trailing: _revoir == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _revoir = null),
                  ),
            onTap: () async {
              final choix = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (choix != null) setState(() => _revoir = choix);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _envoi ? null : _valider,
              child: const Text('Enregistrer la consultation'),
            ),
          ),
        ],
      ),
    );
  }
}
