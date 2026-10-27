import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';

/// Couleurs des graphiques : une série = le bleu nuit de Ngoni ; femmes et
/// hommes = les deux premières teintes de la palette validée (daltonisme).
const _serie = Kolors.kPrimary;
const _femmes = Color(0xFF2A78D6);
const _hommes = Color(0xFFEB6834);
const _grille = Color(0xFFE4EBF7);

/// Le rapport mensuel d'activité du centre : les chiffres clés comparés au
/// mois d'avant, l'activité jour par jour, les consultations par âge et
/// sexe, les diagnostics, les indicateurs (paludisme, CPN, recouvrement),
/// la vaccination et les recettes. Il se copie en texte pour le district.
class RapportMensuelScreen extends StatefulWidget {
  const RapportMensuelScreen({super.key});

  @override
  State<RapportMensuelScreen> createState() => _RapportMensuelScreenState();
}

class _RapportMensuelScreenState extends State<RapportMensuelScreen> {
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _r;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _r = null;
      _erreur = null;
    });
    try {
      final res = await ApiClient.dio.get(
        '/rapports/mensuel',
        queryParameters: {'mois': DateFormat('yyyy-MM').format(_mois)},
      );
      if (mounted) {
        setState(() => _r = Map<String, dynamic>.from(res.data as Map));
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  void _changer(int delta) {
    final m = DateTime(_mois.year, _mois.month + delta);
    if (m.isAfter(DateTime.now())) return;
    _mois = m;
    _charger();
  }

  Map<String, dynamic> _m(String cle) =>
      _r?[cle] is Map ? Map<String, dynamic>.from(_r![cle] as Map) : const {};

  static int _n(Map<String, dynamic> m, String cle) =>
      (m[cle] as num?)?.toInt() ?? 0;

  String get _libelleMois =>
      toBeginningOfSentenceCase(DateFormat('MMMM yyyy', 'fr').format(_mois));

  /// Le rapport en texte, à coller dans un message ou sur le canevas.
  String _texte(String devise) {
    final f = _m('frequentation'), c = _m('consultations'), p = _m('paludisme');
    final mat = _m('maternite'),
        h = _m('hospitalisation'),
        fin = _m('finances');
    final ages = c['par_age'] is Map
        ? Map<String, dynamic>.from(c['par_age'] as Map)
        : const <String, dynamic>{};
    final diag = _r?['diagnostics'] is List
        ? _r!['diagnostics'] as List
        : const [];
    final vacc = _m('vaccination');
    return [
      'Rapport d’activité — $_libelleMois — ${_r?['etablissement'] ?? ''}',
      '',
      'Visites : ${_n(f, 'visites')} · Patients : ${_n(f, 'patients')} · Nouveaux : ${_n(f, 'nouveaux_patients')}',
      'Consultations : ${_n(c, 'total')}',
      for (final e in ages.entries)
        if (_n(Map<String, dynamic>.from(e.value as Map), 'F') +
                _n(Map<String, dynamic>.from(e.value as Map), 'M') >
            0)
          '  ${e.key} : ${(e.value as Map)['F']} F, ${(e.value as Map)['M']} M',
      if (diag.isNotEmpty) 'Diagnostics :',
      for (final d in diag) '  ${(d as Map)['diagnostic']} : ${d['cas']}',
      'Paludisme : TDR ${_n(p, 'tdr')} (${_n(p, 'tdr_positifs')} positifs), GE ${_n(p, 'ge')} (${_n(p, 'ge_positives')} positives)',
      'Maternité : CPN ${_n(mat, 'cpn')} (CPN1 ${_n(mat, 'cpn1')}, CPN4+ ${_n(mat, 'cpn4_et_plus')}, TPI ${_n(mat, 'tpi')}), accouchements ${_n(mat, 'accouchements')}, nés vivants ${_n(mat, 'naissances_vivantes')}, mort-nés ${_n(mat, 'mort_nes')}',
      if (vacc.isNotEmpty)
        'Vaccination : ${vacc.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
      'Hospitalisation : ${_n(h, 'admissions')} admissions, ${_n(h, 'sorties')} sorties, ${_n(h, 'deces')} décès',
      'Recettes : facturé ${formatMontant(_n(fin, 'facture'), devise)}, encaissé ${formatMontant(_n(fin, 'encaisse'), devise)}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final devise = context.watch<AuthController>().devise;
    final r = _r;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport du mois'),
        actions: [
          if (r != null)
            IconButton(
              tooltip: 'Copier le rapport (texte)',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _texte(devise)));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Rapport copié : collez-le dans un message.',
                      ),
                    ),
                  );
                }
              },
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
                  IconButton(
                    color: Kolors.kWhite,
                    onPressed: () => _changer(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Rapport d’activité',
                          style: TextStyle(
                            color: Kolors.kWhite.withValues(alpha: 0.85),
                          ),
                        ),
                        Text(
                          _libelleMois,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (r?['etablissement'] != null)
                          Text(
                            '${r!['etablissement']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Kolors.kJaune,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    color: Kolors.kWhite,
                    disabledColor: Kolors.kWhite.withValues(alpha: 0.3),
                    onPressed:
                        DateTime(
                          _mois.year,
                          _mois.month + 1,
                        ).isAfter(DateTime.now())
                        ? null
                        : () => _changer(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (r == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: _erreur == null
                      ? const CircularProgressIndicator()
                      : Text(_erreur!),
                ),
              )
            else
              ..._contenu(devise),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenu(String devise) {
    final f = _m('frequentation'), avant = _m('precedent');
    final c = _m('consultations'), p = _m('paludisme'), mat = _m('maternite');
    final h = _m('hospitalisation'), fin = _m('finances');
    final ages = c['par_age'] is Map
        ? Map<String, dynamic>.from(c['par_age'] as Map)
        : const <String, dynamic>{};
    final diag = [
      for (final d in (_r?['diagnostics'] as List? ?? const []))
        ((d as Map)['diagnostic'].toString(), (d['cas'] as num).toInt()),
    ];
    final jours = [
      for (final j in (_r?['par_jour'] as List? ?? const []))
        (
          DateTime.parse((j as Map)['jour'].toString()),
          (j['visites'] as num).toInt(),
        ),
    ];
    final vacc = [
      for (final e in _m('vaccination').entries)
        (e.key, (e.value as num).toInt()),
    ];
    final parMoyen = fin['par_moyen'] is Map
        ? Map<String, dynamic>.from(fin['par_moyen'] as Map)
        : const <String, dynamic>{};
    final moyens = [
      for (final e in parMoyen.entries)
        (libellesMoyens[e.key] ?? e.key, (e.value as num).toInt()),
    ];
    String argent(int v) => formatMontant(v, devise);
    String? taux(int num, int den) =>
        den == 0 ? null : '${(num * 100 / den).round()} %';

    Widget deuxColonnes(Widget a, Widget b) => LayoutBuilder(
      builder: (context, contraintes) => contraintes.maxWidth >= 820
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: a),
                const SizedBox(width: 16),
                Expanded(child: b),
              ],
            )
          : Column(children: [a, b]),
    );

    return [
      _Section(
        titre: 'Chiffres clés',
        sousTitre: 'Comparés au mois précédent',
        enfant: _Grille(
          children: [
            _Tuile(
              'Visites',
              '${_n(f, 'visites')}',
              _n(f, 'visites'),
              _n(avant, 'visites'),
            ),
            _Tuile(
              'Patients',
              '${_n(f, 'patients')}',
              _n(f, 'patients'),
              _n(avant, 'patients'),
            ),
            _Tuile(
              'Nouveaux patients',
              '${_n(f, 'nouveaux_patients')}',
              _n(f, 'nouveaux_patients'),
              _n(avant, 'nouveaux_patients'),
            ),
            _Tuile(
              'Consultations',
              '${_n(c, 'total')}',
              _n(c, 'total'),
              _n(avant, 'consultations'),
            ),
            _Tuile(
              'Encaissé',
              argent(_n(fin, 'encaisse')),
              _n(fin, 'encaisse'),
              _n(avant, 'encaisse'),
            ),
          ],
        ),
      ),
      _Section(
        titre: 'Activité jour par jour',
        sousTitre: 'Visites de patients · touchez une barre pour le détail',
        enfant: _BarresJour(jours),
      ),
      deuxColonnes(
        _Section(
          titre: 'Consultations par âge et sexe',
          sousTitre: '${_n(c, 'total')} consultations',
          enfant: _BarresAgeSexe(ages),
        ),
        _Section(
          titre: 'Diagnostics les plus fréquents',
          sousTitre: 'Nombre de cas',
          enfant: _BarresHorizontales(
            diag,
            vide: 'Aucun diagnostic noté ce mois-ci.',
          ),
        ),
      ),
      _Section(
        titre: 'Indicateurs',
        enfant: _Grille(
          children: [
            _Indicateur(
              'Positivité TDR paludisme',
              taux(_n(p, 'tdr_positifs'), _n(p, 'tdr')),
              '${_n(p, 'tdr_positifs')} positifs sur ${_n(p, 'tdr')} TDR',
            ),
            _Indicateur(
              'Positivité goutte épaisse',
              taux(_n(p, 'ge_positives'), _n(p, 'ge')),
              '${_n(p, 'ge_positives')} sur ${_n(p, 'ge')}',
            ),
            _Indicateur(
              'CPN4+ / CPN1',
              taux(_n(mat, 'cpn4_et_plus'), _n(mat, 'cpn1')),
              '${_n(mat, 'cpn4_et_plus')} CPN4+ pour ${_n(mat, 'cpn1')} CPN1',
            ),
            _Indicateur(
              'CPN réalisées',
              '${_n(mat, 'cpn')}',
              'dont ${_n(mat, 'tpi')} avec TPI',
            ),
            _Indicateur(
              'Accouchements',
              '${_n(mat, 'accouchements')}',
              '${_n(mat, 'naissances_vivantes')} nés vivants · ${_n(mat, 'mort_nes')} mort-nés',
            ),
            _Indicateur(
              'Hospitalisation',
              '${_n(h, 'admissions')} admissions',
              '${_n(h, 'sorties')} sorties · ${_n(h, 'deces')} décès',
            ),
            _Indicateur(
              'Recouvrement',
              taux(_n(fin, 'encaisse'), _n(fin, 'facture')),
              '${argent(_n(fin, 'encaisse'))} sur ${argent(_n(fin, 'facture'))} facturés',
            ),
          ],
        ),
      ),
      deuxColonnes(
        _Section(
          titre: 'Vaccination',
          sousTitre: 'Doses données',
          enfant: _BarresHorizontales(
            vacc,
            vide: 'Aucun vaccin noté ce mois-ci.',
          ),
        ),
        _Section(
          titre: 'Recettes par moyen de paiement',
          sousTitre: 'Encaissé : ${argent(_n(fin, 'encaisse'))}',
          enfant: _BarresHorizontales(
            moyens,
            vide: 'Aucun encaissement ce mois-ci.',
            format: argent,
          ),
        ),
      ),
      const Text(
        'Les chiffres viennent de ce qui est saisi dans l’app : consultations, CPN, vaccins, analyses, caisse.',
        style: TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
      ),
    ];
  }
}

/// Des cases de même largeur qui remplissent la ligne (5 au plus, 2 au
/// téléphone) : pas de trou en bout de ligne.
class _Grille extends StatelessWidget {
  const _Grille({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final colonnes = ((c.maxWidth + 12) / (170 + 12)).floor().clamp(2, 5);
        // Des lignes équilibrées : 7 cases font 4 + 3, pas 5 + 2.
        final lignes = (children.length / colonnes).ceil();
        final parLigne = (children.length / lignes).ceil();
        final largeur = (c.maxWidth - 12 * (parLigne - 1)) / parLigne;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final enfant in children)
              SizedBox(width: largeur, child: enfant),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.titre, required this.enfant, this.sousTitre});

  final String titre;
  final String? sousTitre;
  final Widget enfant;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titre,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (sousTitre != null)
              Text(
                sousTitre!,
                style: const TextStyle(color: Kolors.kTextMuted),
              ),
            const SizedBox(height: 14),
            enfant,
          ],
        ),
      ),
    );
  }
}

/// Un chiffre clé et son évolution sur le mois d'avant (flèche + mot : la
/// couleur ne porte jamais seule l'information).
class _Tuile extends StatelessWidget {
  const _Tuile(this.libelle, this.valeur, this.maintenant, this.avant);

  final String libelle;
  final String valeur;
  final int maintenant;
  final int avant;

  @override
  Widget build(BuildContext context) {
    final (icone, texte, couleur) = avant == 0
        ? (
            Icons.remove_rounded,
            maintenant == 0 ? 'stable' : 'nouveau',
            Kolors.kTextMuted,
          )
        : maintenant == avant
        ? (Icons.remove_rounded, 'stable', Kolors.kTextMuted)
        : maintenant > avant
        ? (
            Icons.trending_up_rounded,
            '+${((maintenant - avant) * 100 / avant).round()} %',
            Kolors.kSuccess,
          )
        : (
            Icons.trending_down_rounded,
            '−${((avant - maintenant) * 100 / avant).round()} %',
            Kolors.kRed,
          );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _grille),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(libelle, style: const TextStyle(color: Kolors.kTextMuted)),
          const SizedBox(height: 4),
          // Un montant long rétrécit plutôt que de passer à la ligne.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Kolors.kPrimaryDark,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 16, color: couleur),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$texte vs mois préc.',
                  style: TextStyle(
                    fontSize: 12,
                    color: couleur,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Indicateur extends StatelessWidget {
  const _Indicateur(this.libelle, this.valeur, this.detail);

  final String libelle;
  final String? valeur;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Kolors.kSecondaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(libelle, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            valeur ?? '—',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Kolors.kPrimary,
            ),
          ),
          Text(
            detail,
            style: const TextStyle(fontSize: 12, color: Kolors.kTextMuted),
          ),
        ],
      ),
    );
  }
}

/// Les visites jour par jour : une barre fine par jour, le maximum annoncé,
/// le détail au toucher.
class _BarresJour extends StatelessWidget {
  const _BarresJour(this.jours);

  final List<(DateTime, int)> jours;

  @override
  Widget build(BuildContext context) {
    final max = jours.fold(0, (m, j) => j.$2 > m ? j.$2 : m);
    if (max == 0) {
      return const Text(
        'Aucune visite ce mois-ci.',
        style: TextStyle(color: Kolors.kTextMuted),
      );
    }
    const hauteur = 140.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maximum : $max visite${max > 1 ? 's' : ''} dans la journée',
          style: const TextStyle(fontSize: 12, color: Kolors.kTextMuted),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: hauteur,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (jour, n) in jours)
                Expanded(
                  child: Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    message:
                        '${DateFormat('EEEE d MMMM', 'fr').format(jour)} : $n visite${n > 1 ? 's' : ''}',
                    child: Container(
                      // Zone de toucher pleine hauteur, plus grande que la barre.
                      color: Colors.transparent,
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Container(
                        height: n == 0
                            ? 2
                            : (n / max * (hauteur - 4)).clamp(3, hauteur),
                        decoration: BoxDecoration(
                          color: n == 0 ? _grille : _serie,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: _grille),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final (jour, _) in jours)
              Expanded(
                child: Text(
                  jour.day == 1 || jour.day % 5 == 0 ? '${jour.day}' : '',
                  textAlign: TextAlign.center,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Kolors.kTextMuted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Une barre horizontale par ligne, valeur écrite à droite.
class _BarresHorizontales extends StatelessWidget {
  const _BarresHorizontales(this.lignes, {required this.vide, this.format});

  final List<(String, int)> lignes;
  final String vide;
  final String Function(int)? format;

  @override
  Widget build(BuildContext context) {
    final max = lignes.fold(0, (m, l) => l.$2 > m ? l.$2 : m);
    if (max == 0) {
      return Text(vide, style: const TextStyle(color: Kolors.kTextMuted));
    }
    return Column(
      children: [
        for (final (libelle, n) in lignes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    libelle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: (n / max * c.maxWidth).clamp(4, c.maxWidth),
                        height: 12,
                        decoration: const BoxDecoration(
                          color: _serie,
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: format == null ? 36 : 110,
                  child: Text(
                    format?.call(n) ?? '$n',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Consultations par tranche d'âge : femmes et hommes côte à côte, légende
/// en tête et valeurs écrites (la couleur n'est jamais seule).
class _BarresAgeSexe extends StatelessWidget {
  const _BarresAgeSexe(this.ages);

  final Map<String, dynamic> ages;

  @override
  Widget build(BuildContext context) {
    int v(Object? m, String s) => m is Map ? ((m[s] as num?)?.toInt() ?? 0) : 0;
    final lignes = [
      for (final e in ages.entries)
        if (e.key != 'Âge inconnu' || v(e.value, 'F') + v(e.value, 'M') > 0)
          (e.key, v(e.value, 'F'), v(e.value, 'M')),
    ];
    final max = lignes.fold(0, (m, l) {
      final plus = l.$2 > l.$3 ? l.$2 : l.$3;
      return plus > m ? plus : m;
    });
    if (max == 0) {
      return const Text(
        'Aucune consultation ce mois-ci.',
        style: TextStyle(color: Kolors.kTextMuted),
      );
    }
    Widget barre(int n, Color couleur, double largeur) => Row(
      children: [
        Container(
          width: n == 0 ? 2 : (n / max * largeur).clamp(4, largeur),
          height: 10,
          decoration: BoxDecoration(
            color: n == 0 ? _grille : couleur,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$n',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            _Legende(_femmes, 'Femmes'),
            SizedBox(width: 16),
            _Legende(_hommes, 'Hommes'),
          ],
        ),
        const SizedBox(height: 10),
        for (final (tranche, femmes, hommes) in lignes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 100, child: Text(tranche)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final largeur = c.maxWidth - 40;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          barre(femmes, _femmes, largeur),
                          const SizedBox(height: 2),
                          barre(hommes, _hommes, largeur),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Legende extends StatelessWidget {
  const _Legende(this.couleur, this.libelle);

  final Color couleur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(libelle, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
