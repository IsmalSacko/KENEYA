import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../dossier/dossier_service.dart';
import '../../patients/patients_service.dart';
import '../commun/scanner_qr_screen.dart';
import '../dossier/dossier_screen.dart';
import 'patient_screen.dart';

/// Les patients : on les retrouve (nom, téléphone), on les enregistre une
/// fois, puis tout part de leur fiche.
class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key});

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  final _service = PatientsService();
  final _recherche = TextEditingController();
  Timer? _attente;
  List<Patient>? _liste;
  String? _erreur;

  /// La dernière page chargée, et s'il y en a d'autres (« Voir plus »).
  int _page = 1;
  bool _suite = false;
  bool _chargeSuite = false;

  /// Seulement ceux qui sont dans le centre aujourd'hui.
  bool _aujourdhui = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _attente?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    final recherche = _recherche.text.trim();
    final aujourdhui = _aujourdhui;
    try {
      final (l, suite) = await _service.page(
        recherche: recherche,
        aujourdhui: aujourdhui,
      );
      // Une réponse arrivée après une autre frappe ne compte plus.
      if (!mounted ||
          recherche != _recherche.text.trim() ||
          aujourdhui != _aujourdhui) {
        return;
      }
      setState(() {
        _liste = l;
        _page = 1;
        _suite = suite;
        _erreur = null;
      });
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Future<void> _voirPlus() async {
    setState(() => _chargeSuite = true);
    try {
      final (l, suite) = await _service.page(
        recherche: _recherche.text.trim(),
        aujourdhui: _aujourdhui,
        page: _page + 1,
      );
      if (mounted) {
        setState(() {
          _liste = [...?_liste, ...l];
          _page++;
          _suite = suite;
        });
      }
    } on DioException catch (e) {
      _dire(messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargeSuite = false);
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _ouvrir(Patient p) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PatientScreen(patient: p)));
    await _charger();
  }

  Future<void> _nouveau() async {
    try {
      final p = await nouveauPatient(context, recherche: _recherche.text);
      if (p != null && mounted) await _ouvrir(p);
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  /// Le soignant scanne le QR d'accord du patient : son historique s'ouvre.
  Future<void> _scannerAccord() async {
    final qr = await scannerQr(
      context,
      titre: 'QR d’accord',
      consigne: 'Le patient ouvre « Mon dossier » et montre son QR.',
    );
    if (qr == null || !mounted) return;
    try {
      final d = await DossierService().accorderParQr(qr);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DossierScreen(dossier: d)));
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final l = _liste;
    return Scaffold(
      floatingActionButton: auth.peut('patients.gerer')
          ? FloatingActionButton.extended(
              heroTag: 'nouveau-patient',
              onPressed: _nouveau,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nouveau patient'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recherche,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Nom, téléphone ou N°',
                    ),
                    onChanged: (_) {
                      _attente?.cancel();
                      _attente = Timer(
                        const Duration(milliseconds: 350),
                        _charger,
                      );
                    },
                  ),
                ),
                if (auth.peut('dossier.lire'))
                  IconButton(
                    tooltip: 'QR d’accord du patient',
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: _scannerAccord,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                avatar: const Icon(Icons.today_rounded, size: 18),
                label: const Text('Dans le centre aujourd’hui'),
                selected: _aujourdhui,
                onSelected: (v) {
                  setState(() {
                    _aujourdhui = v;
                    _liste = null;
                  });
                  _charger();
                },
              ),
            ),
            const SizedBox(height: 8),
            if (l == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: _erreur == null
                      ? const CircularProgressIndicator()
                      : Text(_erreur!),
                ),
              )
            else if (l.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  _aujourdhui && _recherche.text.isEmpty
                      ? 'Personne n’est dans le centre pour le moment.'
                      : _recherche.text.isEmpty
                      ? 'Aucun patient pour l’instant. Enregistrez-le à son arrivée : « Nouveau patient ».'
                      : 'Personne à ce nom. Nouveau ? Enregistrez-le.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Kolors.kTextMuted),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  _recherche.text.isEmpty
                      ? '${_aujourdhui ? 'Dans le centre' : 'Dossiers patients'} · ${l.length}${_suite ? '+' : ''}'
                      : '${l.length}${_suite ? '+' : ''} dossier${l.length > 1 ? 's' : ''} trouvé${l.length > 1 ? 's' : ''}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Kolors.kPrimary,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, c) {
                  final colonnes = c.maxWidth >= 1100
                      ? 3
                      : (c.maxWidth >= 640 ? 2 : 1);
                  final largeur = (c.maxWidth - 12 * (colonnes - 1)) / colonnes;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    children: [
                      for (final p in l)
                        SizedBox(
                          width: largeur,
                          child: CarteDossier(p, onTap: () => _ouvrir(p)),
                        ),
                    ],
                  );
                },
              ),
              if (_suite)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: _chargeSuite ? null : _voirPlus,
                      icon: _chargeSuite
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: const Text('Voir plus'),
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

/// Un dossier patient, comme une chemise cartonnée : l'onglet avec son
/// numéro, l'icône du dossier, qui il est, et quand il est venu.
class CarteDossier extends StatelessWidget {
  const CarteDossier(this.patient, {required this.onTap, super.key});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final couleur = p.enCours ? Kolors.kJaune : Kolors.kPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // L'onglet de la chemise.
        Container(
          margin: const EdgeInsets.only(left: 14),
          padding: const EdgeInsets.fromLTRB(12, 4, 14, 4),
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Text(
            p.numero == null ? 'Dossier' : 'N° ${p.numero}',
            style: TextStyle(
              color: p.enCours ? Kolors.kPrimaryDark : Kolors.kWhite,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Material(
          color: Kolors.kWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: couleur, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: p.enCours
                          ? Kolors.kJauneDoux
                          : Kolors.kSecondaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.folder_shared_rounded,
                      color: Kolors.kPrimary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Kolors.kPrimaryDark,
                          ),
                        ),
                        if (p.resume.isNotEmpty || p.telephone != null)
                          Text(
                            [
                              p.resume,
                              ?p.telephone,
                            ].where((x) => x.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Kolors.kTextMuted),
                          ),
                        const SizedBox(height: 6),
                        _Etat(p),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Kolors.kTextMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// « Dans le centre aujourd'hui », « Venu le 12 oct. », ou « Jamais venu ».
class _Etat extends StatelessWidget {
  const _Etat(this.p);

  final Patient p;

  @override
  Widget build(BuildContext context) {
    final (icone, texte, couleur) = p.enCours
        ? (Icons.circle, 'Dans le centre aujourd’hui', Kolors.kGold)
        : p.derniereVisite != null
        ? (
            Icons.history_rounded,
            'Dernière visite : ${DateFormat('d MMM y', 'fr').format(p.derniereVisite!)}',
            Kolors.kTextMuted,
          )
        : (
            Icons.info_outline_rounded,
            'Pas encore venu ici',
            Kolors.kTextMuted,
          );
    return Row(
      children: [
        Icon(icone, size: p.enCours ? 10 : 16, color: couleur),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texte,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
        ),
      ],
    );
  }
}
