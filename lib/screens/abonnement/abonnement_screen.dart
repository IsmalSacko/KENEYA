import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../abonnement/abonnement_service.dart';
import '../../abonnement/recu_abonnement.dart';
import '../../compte/compte_controller.dart';
import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../common/whatsapp.dart';
import '../../common/widgets/carte_marque.dart';
import '../../common/widgets/formulaire.dart';
import '../../compte/compte_models.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';

/// L'abonnement de l'établissement, comme dans Ngoni Caisse : où il en est,
/// les formules et leurs prix, payer puis envoyer sa demande, que Ngoni
/// Santé valide. Le soin ne s'arrête jamais : échu, seule la gestion ferme.
class AbonnementScreen extends StatefulWidget {
  const AbonnementScreen({super.key});

  @override
  State<AbonnementScreen> createState() => _AbonnementScreenState();
}

class _AbonnementScreenState extends State<AbonnementScreen> {
  final _service = AbonnementService();
  Map<String, dynamic>? _donnees;
  String? _erreur;
  int _mois = 1;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final d = await _service.etat();
      if (!mounted) return;
      setState(() {
        _donnees = d;
        _erreur = null;
      });
      final etat = d['abonnement'];
      if (etat is Map) {
        await context.read<AuthController>().majAbonnement(
          Map<String, dynamic>.from(etat),
        );
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Map<String, dynamic> get _etat =>
      Map<String, dynamic>.from((_donnees?['abonnement'] as Map?) ?? {});
  List<Map<String, dynamic>> _liste(String cle) => [
    for (final x in (_donnees?[cle] as List?) ?? const [])
      if (x is Map) Map<String, dynamic>.from(x),
  ];
  Map<String, dynamic> get _paiement =>
      Map<String, dynamic>.from((_donnees?['paiement'] as Map?) ?? {});

  static String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    return d == null ? '' : DateFormat('dd/MM/yyyy').format(d);
  }

  static String _duree(int mois) => switch (mois) {
    0 => 'à vie',
    1 => '1 mois',
    3 => '3 mois',
    6 => '6 mois',
    12 => '1 an',
    _ => '$mois mois',
  };

  Future<void> _choisir(Map<String, dynamic> f) async {
    final tarif = (f['tarifs'] as List? ?? const [])
        .whereType<Map>()
        .where((t) => t['mois'] == _mois)
        .firstOrNull;
    if (tarif == null) return;
    final montant = int.tryParse('${tarif['montant']}') ?? 0;
    final devise = '${tarif['devise'] ?? 'XOF'}';
    final numeros = [
      for (final n in (_paiement['numeros'] as List?) ?? const [])
        if (n is Map) n,
    ];
    final moyens = [
      for (final m in (_paiement['moyens'] as List?) ?? const []) m.toString(),
    ];
    var moyen = moyens.isNotEmpty ? moyens.first : 'orange_money';
    final telephone = TextEditingController();
    final note = TextEditingController();

    final ok = await formulaire<bool>(
      context,
      titre: Text('${f['nom']} · ${_duree(_mois)}'),
      corps: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            'À payer : ${formatMontant(montant, devise)}',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (numeros.isNotEmpty) ...[
            const Text('Envoyez le montant à :'),
            for (final n in numeros)
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.phone_android_rounded),
                  title: SelectableText(
                    '${n['telephone']}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    [
                      for (final m in (n['moyens'] as List?) ?? const [])
                        libellesMoyensAbonnement[m] ?? '$m',
                    ].join(' · '),
                  ),
                ),
              ),
          ],
          const Text('Payé par :'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in moyens)
                ChoiceChip(
                  label: Text(libellesMoyensAbonnement[m] ?? m),
                  selected: moyen == m,
                  onSelected: (_) => setState(() => moyen = m),
                ),
            ],
          ),
          TextField(
            controller: telephone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Numéro qui a payé'),
          ),
          TextField(
            controller: note,
            maxLines: 3,
            maxLength: 255,
            decoration: const InputDecoration(
              labelText: 'Référence ou SMS de confirmation (collez-le)',
            ),
          ),
          const Text(
            'Ngoni Santé vérifie le paiement et active la formule : revenez sur cet écran pour voir où en est votre demande.',
            style: TextStyle(color: Kolors.kTextMuted),
          ),
        ],
      ),
      actions: (ctx, setState) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('J’ai payé : envoyer'),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await _service.demander(
        formule: '${f['code']}',
        mois: _mois,
        moyen: moyen,
        telephone: telephone.text.trim(),
        note: note.text.trim(),
      );
      await _charger();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande envoyée : Ngoni Santé va la valider.'),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  /// Le reçu PDF d'un abonnement payé, à partager (WhatsApp, e-mail…).
  Future<void> _recu(Map<String, dynamic> d) async {
    final etablissement =
        context.read<CompteController>().espaceOuvert?.etablissementNom ??
        'Établissement';
    final octets = await recuAbonnementPdf(
      demande: d,
      etablissement: etablissement,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            octets,
            mimeType: 'application/pdf',
            name: 'Recu-${d['recu_numero']}.pdf',
          ),
        ],
        fileNameOverrides: ['Recu-${d['recu_numero']}.pdf'],
        text: 'Reçu Ngoni Santé ${d['recu_numero']}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final donnees = _donnees;
    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement')),
      body: donnees == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_erreur!, textAlign: TextAlign.center),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Etat(etat: _etat, date: _date),
                  const SizedBox(height: 12),
                  _Places(
                    membres: int.tryParse('${_etat['membres']}'),
                    maxMembres: int.tryParse('${_etat['max_membres']}'),
                    limite: context.watch<CompteController>().limite,
                  ),
                  const SizedBox(height: 12),
                  if (_etat['demande_en_attente'] is Map)
                    _EnAttente(
                      demande: Map<String, dynamic>.from(
                        _etat['demande_en_attente'] as Map,
                      ),
                      duree: _duree,
                      onAnnuler: (uuid) async {
                        await _service.annuler(uuid);
                        await _charger();
                      },
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Choisir une formule',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (final m in const [1, 3, 6, 12])
                        ButtonSegment(
                          value: m,
                          label: FittedBox(child: Text(_duree(m))),
                        ),
                    ],
                    selected: {_mois},
                    onSelectionChanged: (s) => setState(() => _mois = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (_liste('formules').isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Aucune formule proposée pour le moment : écrivez-nous.',
                        style: TextStyle(color: Kolors.kTextMuted),
                      ),
                    ),
                  for (final f in _liste('formules'))
                    _CarteFormule(
                      formule: f,
                      mois: _mois,
                      actuelle: f['code'] == _etat['formule'],
                      peutChoisir: _etat['demande_en_attente'] == null,
                      onChoisir: () => _choisir(f),
                    ),
                  if ('${_paiement['whatsapp'] ?? ''}'.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => envoyerWhatsApp(
                        context,
                        '${_paiement['whatsapp']}',
                        'Bonjour, je voudrais m’abonner à Ngoni Santé.',
                      ),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Une question ? WhatsApp'),
                    ),
                  if (_liste('historique').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Historique',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final d in _liste('historique'))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(switch (d['statut']) {
                          'approuvee' => Icons.check_circle_rounded,
                          'refusee' => Icons.cancel_rounded,
                          _ => Icons.schedule_rounded,
                        }),
                        title: Text(
                          '${d['formule_nom']} · ${_duree(int.tryParse('${d['mois']}') ?? 1)} · '
                          '${formatMontant(int.tryParse('${d['montant']}') ?? 0, '${d['devise']}')}',
                        ),
                        subtitle: Text(switch (d['statut']) {
                          'approuvee' =>
                            'Reçu ${d['recu_numero']} · du ${_date(d['periode_debut'] as String?)} au ${_date(d['periode_fin'] as String?)}',
                          'refusee' => 'Refusée : ${d['motif_refus'] ?? ''}',
                          'annulee' => 'Annulée',
                          _ => 'En attente de validation',
                        }),
                        trailing: d['statut'] == 'approuvee'
                            ? IconButton(
                                tooltip: 'Reçu (PDF)',
                                icon: const Icon(Icons.receipt_long_rounded),
                                onPressed: () => _recu(d),
                              )
                            : null,
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Etat extends StatelessWidget {
  const _Etat({required this.etat, required this.date});

  final Map<String, dynamic> etat;
  final String Function(String?) date;

  @override
  Widget build(BuildContext context) {
    final enCours = etat['en_cours'] != false;
    final fin = etat['fin'] as String?;
    final jours = int.tryParse('${etat['jours_restants']}');
    final ligne = !enCours
        ? 'Échu le ${date(fin)} : le soin continue, la gestion est fermée.'
        : fin == null
        ? 'Sans échéance.'
        : etat['essai'] == true
        ? '${jours ?? 0} jour${(jours ?? 0) > 1 ? 's' : ''} restant${(jours ?? 0) > 1 ? 's' : ''}, jusqu’au ${date(fin)}.'
        : 'Jusqu’au ${date(fin)}.';
    return CarteMarque(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${etat['formule_nom'] ?? 'Formule'}',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  ligne,
                  style: TextStyle(
                    color: enCours ? Kolors.kJaune : Kolors.kWhite,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          AvatarMarque(
            enCours ? Icons.verified_rounded : Icons.lock_clock_rounded,
          ),
        ],
      ),
    );
  }
}

/// Ce qui est utilisé et ce qui reste : l'équipe de cet établissement (selon
/// sa formule) et les établissements que la personne peut encore créer.
class _Places extends StatelessWidget {
  const _Places({
    required this.membres,
    required this.maxMembres,
    required this.limite,
  });

  final int? membres;
  final int? maxMembres;
  final LimiteEtablissements? limite;

  static String _reste(int n) => n <= 0 ? 'plus de place' : 'il en reste $n';

  @override
  Widget build(BuildContext context) {
    final l = limite;
    if (membres == null && l == null) return const SizedBox.shrink();
    return Card(
      child: Column(
        children: [
          if (membres != null)
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(
                maxMembres == null
                    ? 'Équipe : $membres personne${membres! > 1 ? 's' : ''}, sans limite'
                    : 'Équipe : $membres sur $maxMembres personnes',
              ),
              subtitle: maxMembres == null
                  ? null
                  : Text(_reste(maxMembres! - membres!)),
            ),
          if (l != null)
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text('Vos établissements : ${l.crees} sur ${l.max}'),
              subtitle: Text(
                '${_reste(l.restants)}. Chaque établissement a son propre abonnement.',
              ),
            ),
        ],
      ),
    );
  }
}

class _EnAttente extends StatelessWidget {
  const _EnAttente({
    required this.demande,
    required this.duree,
    required this.onAnnuler,
  });

  final Map<String, dynamic> demande;
  final String Function(int) duree;
  final Future<void> Function(String uuid) onAnnuler;

  @override
  Widget build(BuildContext context) => Card(
    color: Kolors.kJauneDoux,
    child: ListTile(
      leading: const Icon(Icons.hourglass_top_rounded),
      title: Text(
        'Demande envoyée : ${demande['formule_nom']}, ${duree(int.tryParse('${demande['mois']}') ?? 1)}',
      ),
      subtitle: Text(
        '${formatMontant(int.tryParse('${demande['montant']}') ?? 0, '${demande['devise']}')} · '
        'Ngoni Santé vérifie votre paiement.',
      ),
      trailing: TextButton(
        onPressed: () => onAnnuler('${demande['uuid']}'),
        child: const Text('Annuler'),
      ),
    ),
  );
}

class _CarteFormule extends StatelessWidget {
  const _CarteFormule({
    required this.formule,
    required this.mois,
    required this.actuelle,
    required this.peutChoisir,
    required this.onChoisir,
  });

  final Map<String, dynamic> formule;
  final int mois;
  final bool actuelle;
  final bool peutChoisir;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final tarif = (formule['tarifs'] as List? ?? const [])
        .whereType<Map>()
        .where((t) => t['mois'] == mois)
        .firstOrNull;
    final max = formule['max_membres'];
    final inclus = [
      for (final m in (formule['modules'] as List?) ?? const [])
        libellesModules['$m'] ?? '$m',
      for (final f in (formule['fonctions'] as List?) ?? const [])
        libellesFonctions['$f'] ?? '$f',
      max == null ? 'Équipe sans limite' : 'Équipe : $max personnes',
    ];
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: actuelle ? Kolors.kJaune : Kolors.kBorder,
          width: actuelle ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formule['nom']}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (tarif != null)
                  Text(
                    formatMontant(
                      int.tryParse('${tarif['montant']}') ?? 0,
                      '${tarif['devise'] ?? 'XOF'}',
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Kolors.kPrimary,
                    ),
                  ),
              ],
            ),
            if (formule['description'] != null)
              Text(
                '${formule['description']}',
                style: const TextStyle(color: Kolors.kTextMuted),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in inclus)
                  Chip(visualDensity: VisualDensity.compact, label: Text(i)),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: peutChoisir && tarif != null ? onChoisir : null,
              child: Text(
                tarif == null
                    ? 'Pas proposé sur cette durée'
                    : actuelle
                    ? 'Renouveler'
                    : 'Choisir ${formule['nom']}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
