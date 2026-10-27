import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../rapports/rapport_mensuel_screen.dart';
import '../../../caisse/caisse_models.dart';
import '../../../caisse/caisse_service.dart';
import '../../../common/utils/kcolors.dart';
import '../../../common/widgets/carte_marque.dart';
import '../../../controllers/auth_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../file/file_service.dart';
import '../../../hospitalisation/hospit_service.dart';
import '../../../labo/labo_service.dart';
import '../../../maternite/maternite_service.dart';
import '../../file/donner_ticket_sheet.dart';
import '../../patients/patient_screen.dart';

/// La journée de l'établissement en un coup d'œil, et les gestes de
/// l'accueil : enregistrer un patient, donner un ticket.
class AujourdhuiTab extends StatefulWidget {
  const AujourdhuiTab({super.key});

  @override
  State<AujourdhuiTab> createState() => _AujourdhuiTabState();
}

class _Chiffre {
  const _Chiffre(this.libelle, this.valeur, this.icone, {this.alerte = false});

  final String libelle;
  final String valeur;
  final IconData icone;
  final bool alerte;
}

class _AujourdhuiTabState extends State<AujourdhuiTab> {
  List<_Chiffre>? _chiffres;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  /// Chaque chiffre selon les droits du membre ; un service qui ne répond
  /// pas n'empêche pas les autres.
  Future<void> _charger() async {
    final auth = context.read<AuthController>();
    final chiffres = <_Chiffre>[];
    Future<void> essayer(Future<void> Function() f) async {
      try {
        await f();
      } on DioException {
        // Ce chiffre manque ; les autres restent.
      }
    }

    if (auth.aModule('file') &&
        ['file.emettre', 'file.appeler', 'file.gerer'].any(auth.peut)) {
      await essayer(() async {
        final services = await FileService().services();
        final attente = services.fold<int>(0, (s, x) => s + x.enAttente);
        chiffres.add(
          _Chiffre(
            'patients en attente',
            '$attente',
            Icons.groups_2_rounded,
            alerte: attente > 15,
          ),
        );
      });
    }
    if (auth.aModule('caisse') && auth.peut('caisse.rapports')) {
      await essayer(() async {
        final r = await CaisseService().rapport();
        final devise = '${r['devise'] ?? auth.devise}';
        chiffres
          ..add(
            _Chiffre(
              'patients venus aujourd’hui',
              '${r['visites'] ?? 0}',
              Icons.how_to_reg_rounded,
            ),
          )
          ..add(
            _Chiffre(
              'encaissé aujourd’hui',
              formatMontant(int.tryParse('${r['encaisse']}') ?? 0, devise),
              Icons.payments_rounded,
            ),
          )
          ..add(
            _Chiffre(
              'reste à payer aujourd’hui',
              formatMontant(int.tryParse('${r['impaye']}') ?? 0, devise),
              Icons.money_off_rounded,
              alerte: (int.tryParse('${r['impaye']}') ?? 0) > 0,
            ),
          );
      });
    }
    if (auth.aModule('labo') &&
        (auth.peut('labo.saisir') || auth.peut('labo.valider'))) {
      await essayer(() async {
        final d = await LaboService().demandes();
        chiffres.add(
          _Chiffre(
            'analyses à faire',
            '${d.length}',
            Icons.science_rounded,
            alerte: d.any((x) => x.urgent),
          ),
        );
      });
    }
    if (auth.aModule('hospitalisation') &&
        (auth.peut('hospitalisation.gerer') ||
            auth.peut('soins.administrer'))) {
      await essayer(() async {
        final s = await HospitService().sejours();
        final retard = s.fold<int>(0, (n, x) => n + x.enRetard);
        chiffres
          ..add(_Chiffre('hospitalisés', '${s.length}', Icons.bed_rounded))
          ..add(
            _Chiffre(
              'soins en retard',
              '$retard',
              Icons.alarm_rounded,
              alerte: retard > 0,
            ),
          );
      });
    }
    if (auth.aModule('maternite') && auth.peut('maternite.suivre')) {
      await essayer(() async {
        final g = await MaterniteService().grossesses();
        chiffres.add(
          _Chiffre(
            'grossesses suivies',
            '${g.length}',
            Icons.pregnant_woman_rounded,
          ),
        );
      });
    }
    if (mounted) setState(() => _chiffres = chiffres);
  }

  Future<void> _nouveauPatient() async {
    try {
      final p = await nouveauPatient(context);
      if (p == null || !mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PatientScreen(patient: p)));
      await _charger();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  Future<void> _ticket() async {
    try {
      final services = await FileService().services();
      if (!mounted) return;
      await donnerTicket(context, services);
      await _charger();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final chiffres = _chiffres;
    final prenom = _appel(auth.currentUser?.name ?? '');

    return RefreshIndicator(
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
                        'Bonjour${prenom.isEmpty ? '' : ', $prenom'}',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Voici la journée.',
                        style: TextStyle(
                          color: Kolors.kWhite.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const AvatarMarque(Icons.local_hospital_rounded),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (auth.peut('patients.gerer'))
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: _nouveauPatient,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Nouveau patient'),
                ),
              if (auth.aModule('file') && auth.peut('file.emettre'))
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: _ticket,
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('Donner un ticket'),
                ),
              if (auth.peut('stats.voir') ||
                  auth.peut('caisse.rapports') ||
                  auth.peut('etablissement.regler'))
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RapportMensuelScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.summarize_outlined),
                  label: const Text('Rapport du mois'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (chiffres == null)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final colonnes = c.maxWidth >= 700
                    ? 4
                    : c.maxWidth >= 420
                    ? 3
                    : 2;
                final largeur = (c.maxWidth - 10 * (colonnes - 1)) / colonnes;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final x in chiffres)
                      SizedBox(
                        width: largeur,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  x.icone,
                                  color: x.alerte
                                      ? Kolors.kRed
                                      : Kolors.kPrimary,
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    x.valeur,
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: x.alerte
                                          ? Kolors.kRed
                                          : Kolors.kTextHigh,
                                    ),
                                  ),
                                ),
                                Text(
                                  x.libelle,
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
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Comment saluer : « Awa » pour Awa Traoré, mais « Dr Diarra » pour
/// Dr Fatoumata Diarra — le titre appelle le nom de famille.
String _appel(String nom) {
  final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
  if (mots.isEmpty) return '';
  const titres = {'dr', 'dr.', 'pr', 'pr.', 'mme', 'm.', 'mlle', 'docteur'};
  if (titres.contains(mots.first.toLowerCase()) && mots.length > 1) {
    return '${mots.first} ${mots.last}';
  }
  return mots.first;
}
