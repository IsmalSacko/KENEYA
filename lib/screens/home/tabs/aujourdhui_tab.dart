import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../caisse/caisse_models.dart';
import '../../../caisse/caisse_service.dart';
import '../../../common/utils/kcolors.dart';
import '../../../common/widgets/carte_marque.dart';
import '../../../compte/compte_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../../core/api/api_client.dart';
import '../../../file/file_service.dart';
import '../../../hospitalisation/hospit_service.dart';
import '../../../labo/labo_service.dart';
import '../../../maternite/maternite_service.dart';
import '../../file/donner_ticket_sheet.dart';
import '../../patients/patient_screen.dart';
import '../ouvrir_onglet.dart';

/// Ce qu'il y a à faire maintenant, en une phrase et un bouton ; puis la
/// journée de l'établissement en chiffres, et les gestes de l'accueil.
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

/// Une chose à faire : une phrase, et le bouton qui ouvre le bon onglet.
class _AFaire {
  const _AFaire(
    this.icone,
    this.phrase,
    this.bouton,
    this.onglet, {
    this.urgent = false,
  });

  final IconData icone;
  final String phrase;
  final String bouton;
  final String onglet;
  final bool urgent;
}

class _AujourdhuiTabState extends State<AujourdhuiTab> {
  List<_Chiffre>? _chiffres;
  List<_AFaire> _aFaire = [];

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
    final aFaire = <_AFaire>[];
    String fois(int n, String un, String plusieurs) =>
        '$n ${n > 1 ? plusieurs : un}';
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
        if (attente > 0 &&
            (auth.peut('file.appeler') || auth.peut('file.gerer'))) {
          aFaire.add(
            _AFaire(
              Icons.groups_2_rounded,
              '${fois(attente, 'patient attend', 'patients attendent')}.',
              'Voir la file',
              'File d’attente',
            ),
          );
        }
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
        final impaye = int.tryParse('${r['impaye']}') ?? 0;
        if (impaye > 0 && auth.peut('caisse.encaisser')) {
          aFaire.add(
            _AFaire(
              Icons.point_of_sale_rounded,
              '${formatMontant(impaye, devise)} restent à encaisser aujourd’hui.',
              'Voir la caisse',
              'Caisse',
            ),
          );
        }
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
        final urgentes = d.where((x) => x.urgent).length;
        if (d.isNotEmpty) {
          aFaire.add(
            _AFaire(
              Icons.science_rounded,
              '${fois(d.length, 'analyse à faire', 'analyses à faire')}'
                  '${urgentes > 0 ? ', dont ${fois(urgentes, 'urgente', 'urgentes')}' : ''}.',
              'Commencer',
              'Laboratoire',
              urgent: urgentes > 0,
            ),
          );
        }
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
        if (retard > 0) {
          aFaire.add(
            _AFaire(
              Icons.alarm_rounded,
              '${fois(retard, 'soin est en retard', 'soins sont en retard')}.',
              'Voir les soins',
              'Hospitalisation',
              urgent: true,
            ),
          );
        }
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
    // L'urgent d'abord.
    aFaire.sort((a, b) => (b.urgent ? 1 : 0) - (a.urgent ? 1 : 0));
    if (mounted) {
      setState(() {
        _chiffres = chiffres;
        _aFaire = aFaire;
      });
    }
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
    // Le nom du compte (le même que dans « Ma santé »), sinon celui du membre.
    final prenom = _appel(
      context.watch<CompteController>().personne?.nom ??
          auth.currentUser?.name ??
          '',
    );

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
          // Les deux gestes de l'accueil côte à côte, même au téléphone :
          // chacun prend la moitié, le texte rétrécit au besoin.
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Row(
                children: [
                  for (final (i, bouton) in [
                    if (auth.peut('patients.gerer'))
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: _nouveauPatient,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const FittedBox(child: Text('Nouveau patient')),
                      ),
                    if (auth.aModule('file') && auth.peut('file.emettre'))
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: _ticket,
                        icon: const Icon(Icons.confirmation_number_outlined),
                        label: const FittedBox(child: Text('Donner un ticket')),
                      ),
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: bouton),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (chiffres != null) ...[
            const _Titre('À faire maintenant'),
            if (_aFaire.isEmpty)
              const Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    Icons.check_circle_rounded,
                    color: Kolors.kSuccess,
                  ),
                  title: Text('Rien en attente : tout est à jour.'),
                ),
              )
            else
              for (final a in _aFaire)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CarteAFaire(
                    a,
                    onPressed: () => OuvrirOnglet.ouvrir(context, a.onglet),
                  ),
                ),
            const SizedBox(height: 16),
            const _Titre('La journée'),
          ],
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

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      texte,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Kolors.kTextHigh,
      ),
    ),
  );
}

class _CarteAFaire extends StatelessWidget {
  const _CarteAFaire(this.a, {required this.onPressed});

  final _AFaire a;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final couleur = a.urgent ? Kolors.kRed : Kolors.kPrimary;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: couleur.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, c) {
            final phrase = Row(
              children: [
                Icon(a.icone, color: couleur, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a.phrase,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: a.urgent ? Kolors.kRed : Kolors.kTextHigh,
                    ),
                  ),
                ),
              ],
            );
            final bouton = ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 48),
                backgroundColor: a.urgent ? Kolors.kRed : null,
              ),
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(a.bouton),
            );
            // Au téléphone, le bouton passe sous la phrase, sur toute la
            // largeur ; sur un grand écran, il se range à droite.
            return c.maxWidth < 520
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [phrase, const SizedBox(height: 12), bouton],
                  )
                : Row(
                    children: [
                      Expanded(child: phrase),
                      const SizedBox(width: 12),
                      bouton,
                    ],
                  );
          },
        ),
      ),
    );
  }
}
