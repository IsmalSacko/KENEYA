import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../presence/presence_service.dart';
import '../commun/scanner_qr_screen.dart';
import 'badges_screen.dart';
import '../../common/widgets/formulaire.dart';

final _heure = DateFormat('HH:mm');

/// L'entrée de l'établissement : le personnel pointe, les visiteurs entrent
/// et sortent avec leur badge.
class EntreeTab extends StatefulWidget {
  const EntreeTab({super.key});

  @override
  State<EntreeTab> createState() => _EntreeTabState();
}

class _EntreeTabState extends State<EntreeTab> {
  final _service = PresenceService();
  bool _visiteurs = false;
  List<Map<String, dynamic>>? _presents;
  List<VisiteurPresent>? _listeVisiteurs;
  String? _erreur;

  bool get _badges => context.read<AuthController>().aModule('badges');
  bool get _hospit => context.read<AuthController>().aModule('hospitalisation');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_badges && _hospit) setState(() => _visiteurs = true);
      _charger();
    });
  }

  Future<void> _charger() async {
    try {
      final p = _badges ? await _service.presents() : <Map<String, dynamic>>[];
      final v = _hospit ? await _service.visiteurs() : <VisiteurPresent>[];
      if (mounted) {
        setState(() {
          _presents = p;
          _listeVisiteurs = v;
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

  Future<void> _scanner() async {
    final qr = await scannerQr(
      context,
      titre: _visiteurs ? 'Badge visiteur' : 'Badge du personnel',
      consigne: _visiteurs
          ? 'Scannez le badge du visiteur qui sort.'
          : 'Scannez le badge : arrivée, puis départ.',
    );
    if (qr == null) return;
    try {
      if (_visiteurs) {
        await _service.sortir(qr: qr);
        _dire('Sortie notée.');
      } else {
        final p = await _service.pointer(qr);
        final at = DateTime.tryParse('${p['at']}')?.toLocal();
        _dire(
          '${p['type'] == 'arrivee' ? 'Arrivée' : 'Départ'} de ${p['nom']}'
          '${at == null ? '' : ' à ${_heure.format(at)}'}',
        );
      }
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _nouveauVisiteur() async {
    final List<Map<String, dynamic>> patients;
    try {
      patients = await _service.patients();
    } on DioException catch (e) {
      _dire(messageErreur(e));
      return;
    }
    if (!mounted) return;
    final nom = TextEditingController();
    final telephone = TextEditingController();
    String? sejour;
    final ok = await formulaire<bool>(
      context,
      titre: const Text('Nouveau visiteur'),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nom,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom du visiteur'),
          ),
          TextField(
            controller: telephone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone (facultatif)',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: sejour,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Patient visité'),
            items: [
              for (final p in patients)
                DropdownMenuItem(
                  value: p['uuid'].toString(),
                  child: Text(
                    '${p['patient']} · ${p['lit'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => sejour = v),
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
          child: const Text('Entrer'),
        ),
      ],
    );
    if (ok != true || nom.text.trim().isEmpty) return;
    try {
      final v = await _service.entrer({
        'nom': nom.text.trim(),
        'telephone': telephone.text.trim(),
        'sejour_uuid': ?sejour,
      });
      await _charger();
      if (mounted) await _montrerBadge(v);
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _montrerBadge(VisiteurPresent v) => showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CarteMarque(
                child: Column(
                  children: [
                    Text(
                      'VISITEUR',
                      style: GoogleFonts.poppins(
                        color: Kolors.kJaune,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      v.nom,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (v.patient != null)
                      Text(
                        'Pour ${v.patient}${v.lit == null ? '' : ' · ${v.lit}'}',
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Kolors.kWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(data: v.qr, size: 180),
                    ),
                    const SizedBox(height: 6),
                    const Text('À scanner à la sortie'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final badges = auth.aModule('badges');
    final hospit = auth.aModule('hospitalisation');
    final presents = _presents;
    final visiteurs = _listeVisiteurs;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'entree',
        onPressed: _scanner,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text(_visiteurs ? 'Sortie visiteur' : 'Pointer'),
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                if (badges && hospit)
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Personnel')),
                        ButtonSegment(value: true, label: Text('Visiteurs')),
                      ],
                      selected: {_visiteurs},
                      onSelectionChanged: (s) =>
                          setState(() => _visiteurs = s.first),
                    ),
                  )
                else
                  const Spacer(),
                if (!_visiteurs && auth.peut('badges.gerer'))
                  IconButton(
                    tooltip: 'Badges et présence du mois',
                    icon: const Icon(Icons.badge_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BadgesScreen()),
                    ),
                  ),
                if (_visiteurs)
                  IconButton(
                    tooltip: 'Nouveau visiteur',
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    onPressed: _nouveauVisiteur,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (presents == null || visiteurs == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: _erreur == null
                      ? const CircularProgressIndicator()
                      : Text(_erreur!),
                ),
              )
            else if (!_visiteurs) ...[
              Text(
                '${presents.length} présent${presents.length > 1 ? 's' : ''}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final p in presents)
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.how_to_reg_rounded,
                      color: Kolors.kSuccess,
                    ),
                    title: Text('${p['nom']}'),
                    subtitle: Text(
                      [
                        '${p['role']}',
                        if (DateTime.tryParse('${p['depuis']}') != null)
                          'depuis ${_heure.format(DateTime.parse('${p['depuis']}').toLocal())}',
                      ].join(' · '),
                    ),
                  ),
                ),
            ] else ...[
              Text(
                '${visiteurs.length} visiteur${visiteurs.length > 1 ? 's' : ''} dans l’établissement',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final v in visiteurs)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge_rounded),
                    title: Text(v.nom),
                    subtitle: Text(
                      [
                        if (v.patient != null) 'chez ${v.patient}',
                        if (v.entree != null)
                          'entré à ${_heure.format(v.entree!)}',
                      ].join(' · '),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await _service.sortir(uuid: v.uuid);
                          await _charger();
                        } on DioException catch (e) {
                          _dire(messageErreur(e));
                        }
                      },
                      child: const Text('Sorti'),
                    ),
                    onTap: () => _montrerBadge(v),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
