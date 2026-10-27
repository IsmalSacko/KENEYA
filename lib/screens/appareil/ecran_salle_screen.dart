import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../common/utils/kcolors.dart';
import '../../file/appareil_api.dart';
import '../../file/file_models.dart';
import 'sortie_appareil.dart';

/// L'écran de la salle d'attente (télé, tablette) : le dernier appel en
/// très grand, annoncé à voix haute, et l'attente de chaque service. Jamais
/// de nom, seulement les numéros.
class EcranSalleScreen extends StatefulWidget {
  const EcranSalleScreen({required this.onQuitter, super.key});

  final VoidCallback onQuitter;

  @override
  State<EcranSalleScreen> createState() => _EcranSalleScreenState();
}

class _EcranSalleScreenState extends State<EcranSalleScreen> {
  final _voix = FlutterTts();
  Timer? _minuteur;
  EtatFile? _etat;
  bool _horsLigne = false;

  /// Appels déjà annoncés (un rappel du même ticket se réannonce).
  final Set<String> _annonces = {};
  final List<AppelEcran> _aAnnoncer = [];
  bool _parle = false;
  bool _premierChargement = true;

  /// Le dernier appel clignote quelques secondes.
  String? _enEvidence;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _voix
      ..setLanguage('fr-FR')
      ..setSpeechRate(0.45)
      ..awaitSpeakCompletion(true);
    _interroger();
    _minuteur = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _interroger(),
    );
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _voix.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _interroger() async {
    try {
      final etat = await AppareilApi.etat();
      if (!mounted) return;
      setState(() {
        _etat = etat;
        _horsLigne = false;
      });
      _nouveauxAppels(etat.derniersAppels);
    } on DioException catch (e) {
      if (AppareilApi.estRevoque(e)) {
        await AppareilApi.oublier();
        widget.onQuitter();
        return;
      }
      if (mounted) setState(() => _horsLigne = true);
    }
  }

  void _nouveauxAppels(List<AppelEcran> appels) {
    // Au démarrage, on n'annonce pas les appels déjà passés.
    if (_premierChargement) {
      _annonces.addAll(appels.map((a) => a.cle));
      _premierChargement = false;
      return;
    }
    for (final a in appels.reversed) {
      if (_annonces.add(a.cle)) _aAnnoncer.add(a);
    }
    _annoncerSuivant();
  }

  Future<void> _annoncerSuivant() async {
    if (_parle || _aAnnoncer.isEmpty) return;
    _parle = true;
    final a = _aAnnoncer.removeAt(0);
    setState(() => _enEvidence = a.cle);
    // « Ticket A 12, Salle 2 » : la lettre puis le nombre, plus clair à
    // l'oreille que « A zéro un deux ».
    final lettre = a.code.replaceAll(RegExp(r'\d'), '');
    final nombre = int.tryParse(a.code.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final salle = a.salle == null ? '' : ', ${a.salle}';
    for (var i = 0; i < 2; i++) {
      await _voix.speak('Ticket $lettre $nombre$salle');
    }
    _parle = false;
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _enEvidence == a.cle) setState(() => _enEvidence = null);
    });
    _annoncerSuivant();
  }

  @override
  Widget build(BuildContext context) {
    final etat = _etat;
    final dernier = etat?.derniersAppels.firstOrNull;

    return Scaffold(
      backgroundColor: Kolors.kPrimaryDark,
      body: SortieAppareil(
        onQuitter: widget.onQuitter,
        child: SafeArea(
          child: etat == null
              ? const Center(
                  child: CircularProgressIndicator(color: Kolors.kJaune),
                )
              : LayoutBuilder(
                  builder: (context, c) {
                    final large = c.maxWidth > c.maxHeight;
                    final appel = _AppelEnCours(
                      appel: dernier,
                      enEvidence: dernier != null && dernier.cle == _enEvidence,
                    );
                    final liste = _ListeServices(services: etat.services);
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  etat.etablissementNom,
                                  style: GoogleFonts.poppins(
                                    color: Kolors.kWhite,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (_horsLigne)
                                const Text(
                                  'Connexion perdue…',
                                  style: TextStyle(color: Kolors.kJaune),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: large
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(flex: 3, child: appel),
                                      const SizedBox(width: 20),
                                      Expanded(flex: 2, child: liste),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(child: appel),
                                      const SizedBox(height: 16),
                                      Expanded(child: liste),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AppelEnCours extends StatelessWidget {
  const _AppelEnCours({required this.appel, required this.enEvidence});

  final AppelEcran? appel;
  final bool enEvidence;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        gradient: enEvidence ? null : Kolors.heroGradient,
        color: enEvidence ? Kolors.kJaune : null,
        borderRadius: BorderRadius.circular(28),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: FittedBox(
        child: appel == null
            ? Text(
                'Bienvenue',
                style: GoogleFonts.poppins(
                  color: Kolors.kWhite,
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                ),
              )
            : Column(
                children: [
                  Text(
                    appel!.code,
                    style: GoogleFonts.poppins(
                      color: enEvidence ? Kolors.kPrimaryDark : Kolors.kJaune,
                      fontSize: 140,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    appel!.salle == null ? appel!.service : '→ ${appel!.salle}',
                    style: GoogleFonts.poppins(
                      color: enEvidence ? Kolors.kPrimaryDark : Kolors.kWhite,
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ListeServices extends StatelessWidget {
  const _ListeServices({required this.services});

  final List<ServiceEcran> services;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final s in services)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Kolors.kWhite.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.nom,
                        style: const TextStyle(
                          color: Kolors.kWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.appeles.isEmpty
                            ? '—'
                            : s.appeles
                                  .map(
                                    (a) => a.salle == null
                                        ? a.code
                                        : '${a.code} → ${a.salle}',
                                  )
                                  .join('   '),
                        style: const TextStyle(
                          color: Kolors.kJaune,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${s.enAttente}',
                      style: GoogleFonts.poppins(
                        color: Kolors.kWhite,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'en attente',
                      style: TextStyle(color: Kolors.kGrayLight),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
