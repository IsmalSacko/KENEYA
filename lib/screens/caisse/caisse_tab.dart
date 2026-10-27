import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../caisse/caisse_service.dart';
import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import 'assureurs_screen.dart';
import 'tarifs_screen.dart';
import 'visite_screen.dart';

/// La caisse : ouvrir et clôturer sa caisse, retrouver une visite (nom,
/// téléphone ou numéro de ticket), encaisser.
class CaisseTab extends StatefulWidget {
  const CaisseTab({super.key});

  @override
  State<CaisseTab> createState() => _CaisseTabState();
}

class _CaisseTabState extends State<CaisseTab> {
  final _service = CaisseService();
  final _recherche = TextEditingController();
  Map<String, dynamic>? _session;
  List<Visite> _visites = [];
  String _devise = 'XOF';
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final auth = context.read<AuthController>();
      if (auth.peut('caisse.encaisser')) {
        final s = await _service.session();
        _session = s['session'] is Map
            ? Map<String, dynamic>.from(s['session'] as Map)
            : null;
        _devise = (s['devise'] ?? 'XOF').toString();
      }
      _visites = await _service.visites(recherche: _recherche.text.trim());
    } on DioException catch (e) {
      _dire(messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<int?> _demanderMontant(String titre, String aide) {
    final ctrl = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d ,.]')),
          ],
          decoration: InputDecoration(labelText: '$aide ($_devise)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
              lireMontant(ctrl.text.isEmpty ? '0' : ctrl.text, _devise),
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _ouvrir() async {
    final fond = await _demanderMontant(
      'Ouvrir la caisse',
      'Fond de caisse en espèces',
    );
    if (fond == null) return;
    try {
      await _service.ouvrir(fond);
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _cloturer() async {
    final comptees = await _demanderMontant(
      'Clôturer la caisse',
      'Espèces comptées dans le tiroir',
    );
    if (comptees == null) return;
    try {
      final r = await _service.cloturer(comptees);
      if (!mounted) return;
      final ecart = (r['ecart'] as num).toInt();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Caisse clôturée'),
          content: Text(
            'Espèces attendues : ${formatMontant((r['especes_attendues'] as num).toInt(), _devise)}\n'
            'Espèces comptées : ${formatMontant(comptees, _devise)}\n'
            '${ecart == 0 ? 'Aucun écart.' : 'Écart : ${ecart > 0 ? '+' : ''}${formatMontant(ecart, _devise)}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final encaisse = auth.peut('caisse.encaisser');
    final totaux = _session?['totaux'] is Map
        ? Map<String, dynamic>.from(_session!['totaux'] as Map)
        : const <String, dynamic>{};

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (encaisse)
            CarteMarque(
              child: _session == null
                  ? Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Votre caisse est fermée.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Kolors.kJaune,
                            foregroundColor: Kolors.kPrimaryDark,
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: _ouvrir,
                          child: const Text('Ouvrir ma caisse'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Encaissé dans ma caisse',
                          style: TextStyle(
                            color: Kolors.kWhite.withValues(alpha: 0.85),
                          ),
                        ),
                        Text(
                          formatMontant(
                            totaux.values.fold<int>(
                              0,
                              (s, v) => s + (v as num).toInt(),
                            ),
                            _devise,
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Kolors.kJaune,
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          children: [
                            for (final e in totaux.entries)
                              Text(
                                '${libellesMoyens[e.key] ?? e.key} : ${formatMontant((e.value as num).toInt(), _devise)}',
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Kolors.kWhite,
                              side: BorderSide(
                                color: Kolors.kWhite.withValues(alpha: 0.6),
                              ),
                              minimumSize: const Size(0, 44),
                            ),
                            onPressed: _cloturer,
                            child: const Text('Clôturer ma caisse'),
                          ),
                        ),
                      ],
                    ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _recherche,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _charger(),
                  decoration: const InputDecoration(
                    hintText: 'Nom, téléphone ou ticket (A012)',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              if (auth.peut('caisse.rapports') ||
                  auth.peut('etablissement.regler'))
                IconButton(
                  tooltip: 'Tarifs et rapport',
                  icon: const Icon(Icons.price_change_outlined),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TarifsScreen()),
                    );
                    _charger();
                  },
                ),
              if (auth.aModule('assurances') &&
                  (auth.peut('assurances.gerer') ||
                      auth.peut('etablissement.regler') ||
                      auth.peut('caisse.rapports')))
                IconButton(
                  tooltip: 'Assureurs',
                  icon: const Icon(Icons.health_and_safety_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AssureursScreen()),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_chargement)
            const Center(child: CircularProgressIndicator())
          else if (_visites.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucune visite ouverte.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final v in _visites)
                    ListTile(
                      title: Text(v.titre),
                      subtitle: Text(
                        [
                          if (v.tickets.isNotEmpty) v.tickets.join(' → '),
                          if (v.telephone != null) v.telephone!,
                        ].join(' · '),
                      ),
                      trailing: Text(
                        v.reste > 0
                            ? formatMontant(v.reste, v.devise)
                            : (v.total > 0 ? 'Payé' : 'Rien à facturer'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: v.reste > 0 ? Kolors.kGold : Kolors.kSuccess,
                        ),
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VisiteScreen(uuid: v.uuid),
                          ),
                        );
                        _charger();
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
