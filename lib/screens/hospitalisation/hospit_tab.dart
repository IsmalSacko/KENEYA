import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../hospitalisation/hospit_models.dart';
import '../../hospitalisation/hospit_service.dart';
import '../commun/scanner_qr_screen.dart';
import 'sejour_screen.dart';
import '../../common/widgets/formulaire.dart';

/// Les patients hospitalisés et les lits.
class HospitTab extends StatefulWidget {
  const HospitTab({super.key});

  @override
  State<HospitTab> createState() => _HospitTabState();
}

class _HospitTabState extends State<HospitTab> {
  final _service = HospitService();
  bool _lits = false;
  List<Sejour>? _sejours;
  List<Chambre>? _chambres;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final s = await _service.sejours();
      final c = await _service.chambres();
      if (mounted) {
        setState(() {
          _sejours = s;
          _chambres = c;
          _erreur = null;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Future<void> _ouvrir(Future<Sejour> Function() charger) async {
    try {
      final s = await charger();
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => SejourScreen(sejour: s)));
      await _charger();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  Future<void> _scanner() async {
    final qr = await scannerQr(
      context,
      titre: 'Bracelet du patient',
      consigne: 'Visez le QR du bracelet.',
    );
    if (qr != null) await _ouvrir(() => _service.lireBracelet(qr));
  }

  Future<void> _nouvelleChambre() async {
    final devise = context.read<AuthController>().devise;
    final nom = TextEditingController();
    final service = TextEditingController();
    final lits = TextEditingController(text: '4');
    final prix = TextEditingController();
    final ok = await formulaire<bool>(
      context,
      titre: const Text('Nouvelle chambre'),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nom,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nom (ex. Salle d’observation)',
            ),
          ),
          TextField(
            controller: service,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Service (ex. Pédiatrie)',
            ),
          ),
          TextField(
            controller: lits,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Nombre de lits'),
          ),
          TextField(
            controller: prix,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Prix de la nuit ($devise)'),
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
          child: const Text('Créer'),
        ),
      ],
    );
    if (ok != true || nom.text.trim().isEmpty) return;
    try {
      await _service.creerChambre({
        'nom': nom.text.trim(),
        'service': service.text.trim(),
        'lits': int.tryParse(lits.text) ?? 1,
        'prix': int.tryParse(prix.text),
      });
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
    final devise = auth.devise;
    final sejours = _sejours;
    final chambres = _chambres;
    final regle =
        auth.peut('hospitalisation.gerer') || auth.peut('etablissement.regler');

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bracelet',
        onPressed: _scanner,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Bracelet'),
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Patients')),
                      ButtonSegment(value: true, label: Text('Lits')),
                    ],
                    selected: {_lits},
                    onSelectionChanged: (s) => setState(() => _lits = s.first),
                  ),
                ),
                if (_lits && regle)
                  IconButton(
                    tooltip: 'Nouvelle chambre',
                    icon: const Icon(Icons.add),
                    onPressed: _nouvelleChambre,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (sejours == null || chambres == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: _erreur == null
                      ? const CircularProgressIndicator()
                      : Text(_erreur!),
                ),
              )
            else if (!_lits) ...[
              if (sejours.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'Personne n’est hospitalisé. On hospitalise depuis la visite du patient.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Kolors.kTextMuted),
                  ),
                ),
              for (final s in sejours)
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.bed_rounded,
                      color: Kolors.kPrimary,
                    ),
                    title: Text(s.patient),
                    subtitle: Text('${s.lit ?? 'Sans lit'} · ${s.motif}'),
                    trailing: s.enRetard > 0
                        ? Text(
                            '${s.enRetard} en retard',
                            style: const TextStyle(
                              color: Kolors.kRed,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                    onTap: () => _ouvrir(() => _service.sejour(s.uuid)),
                  ),
                ),
            ] else ...[
              if (chambres.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'Aucune chambre. Touchez + pour créer les chambres et leurs lits.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Kolors.kTextMuted),
                  ),
                ),
              for (final c in chambres)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            c.nom,
                            ?c.service,
                            if (c.prix != null)
                              '${formatMontant(c.prix!, devise)} / nuit',
                          ].join(' · '),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final l in c.lits)
                              ActionChip(
                                avatar: Icon(
                                  l.libre
                                      ? Icons.bed_outlined
                                      : Icons.bed_rounded,
                                  size: 18,
                                  color: l.libre
                                      ? Kolors.kSuccess
                                      : Kolors.kPrimary,
                                ),
                                label: Text(
                                  l.patient == null
                                      ? 'Lit ${l.numero}'
                                      : '${l.numero} · ${l.patient}',
                                ),
                                onPressed: l.sejourUuid == null
                                    ? null
                                    : () => _ouvrir(
                                        () => _service.sejour(l.sejourUuid!),
                                      ),
                              ),
                          ],
                        ),
                      ],
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
