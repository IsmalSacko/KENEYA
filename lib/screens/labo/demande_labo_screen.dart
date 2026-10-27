import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../file/impression_ticket.dart';
import '../../labo/labo_models.dart';
import '../../labo/labo_service.dart';
import '../dossier/dossier_widgets.dart';

/// Une demande au labo : étiquette du tube, saisie des résultats, validation.
class DemandeLaboScreen extends StatefulWidget {
  const DemandeLaboScreen({required this.demande, super.key});

  final DemandeLabo demande;

  @override
  State<DemandeLaboScreen> createState() => _DemandeLaboScreenState();
}

class _DemandeLaboScreenState extends State<DemandeLaboScreen> {
  final _service = LaboService();
  late DemandeLabo _d = widget.demande;
  final Map<String, TextEditingController> _champs = {};
  final Map<String, String?> _choix = {};
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _remplir();
  }

  @override
  void dispose() {
    for (final c in _champs.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _remplir() {
    for (final l in _d.lignes) {
      if (l.typeResultat == 'choix') {
        _choix[l.uuid] = l.resultat;
      } else {
        (_champs[l.uuid] ??= TextEditingController()).text = l.resultat ?? '';
      }
    }
  }

  Map<String, String> get _saisis => {
    for (final l in _d.lignes)
      l.uuid: l.typeResultat == 'choix'
          ? (_choix[l.uuid] ?? '')
          : _champs[l.uuid]!.text.trim(),
  };

  Future<void> _faire(
    Future<DemandeLabo> Function() action, [
    String? ok,
  ]) async {
    setState(() => _envoi = true);
    try {
      final d = await action();
      if (!mounted) return;
      setState(() {
        _d = d;
        _envoi = false;
      });
      _remplir();
      if (ok != null) _message(ok);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        _message(messageErreur(e));
      }
    }
  }

  void _message(String texte) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texte)));

  Future<void> _imprimer() async {
    if (ImpressionTicket.imprimanteChoisie == null) {
      _message('Choisissez l’imprimante dans File d’attente › Régler la file.');
      return;
    }
    final ok = await LaboService.imprimerEtiquette(_d);
    if (mounted) {
      _message(ok ? 'Étiquette imprimée.' : 'L’imprimante ne répond pas.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final d = _d;
    final peutSaisir = d.modifiable && auth.peut('labo.saisir');

    return Scaffold(
      appBar: AppBar(title: Text(d.patient)),
      body: ListView(
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
                        d.patient,
                        style: GoogleFonts.poppins(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        [
                          d.statutLabel,
                          if (d.urgent) 'URGENT',
                          dateCourte(d.date),
                        ].join(' · '),
                        style: const TextStyle(
                          color: Kolors.kJaune,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (d.prescripteur != null)
                        Text(
                          'Demandé par ${d.prescripteur}',
                          style: TextStyle(
                            color: Kolors.kWhite.withValues(alpha: 0.85),
                          ),
                        ),
                      if (d.renseignements != null) ...[
                        const SizedBox(height: 6),
                        Text(d.renseignements!),
                      ],
                    ],
                  ),
                ),
                if (d.qr != null)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Kolors.kWhite,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(data: d.qr!, size: 84),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (d.statut == 'demandee' && auth.peut('labo.saisir'))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _envoi
                      ? null
                      : () => _faire(
                          () => _service.prelever(d.uuid),
                          'Prélèvement noté.',
                        ),
                  icon: const Icon(Icons.water_drop_rounded),
                  label: const Text('Prélevé'),
                ),
                OutlinedButton.icon(
                  onPressed: _imprimer,
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Étiquette'),
                ),
                if (auth.peut('consultation.faire') || auth.peut('labo.saisir'))
                  TextButton(
                    onPressed: _envoi
                        ? null
                        : () => _faire(
                            () => _service.annuler(d.uuid),
                            'Demande annulée.',
                          ),
                    child: const Text('Annuler la demande'),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          for (final l in d.lignes)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.nom,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (l.anormal == true)
                          const Chip(
                            label: Text('Anormal'),
                            labelStyle: TextStyle(color: Kolors.kWhite),
                            backgroundColor: Kolors.kRed,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    if (l.normale != null)
                      Text(
                        'Normale : ${l.normale}',
                        style: const TextStyle(
                          color: Kolors.kTextMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (!peutSaisir)
                      Text(
                        l.resultatAffiche ?? '—',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: l.anormal == true
                              ? Kolors.kRed
                              : Kolors.kTextHigh,
                        ),
                      )
                    else if (l.typeResultat == 'choix' && l.choix.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in l.choix)
                            ChoiceChip(
                              label: Text(c),
                              selected: _choix[l.uuid] == c,
                              onSelected: (oui) => setState(
                                () => _choix[l.uuid] = oui ? c : null,
                              ),
                            ),
                        ],
                      )
                    else
                      TextField(
                        controller: _champs[l.uuid],
                        maxLines: l.typeResultat == 'texte' ? null : 1,
                        keyboardType: l.typeResultat == 'nombre'
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.multiline,
                        decoration: InputDecoration(
                          labelText: 'Résultat',
                          suffixText: l.unite,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (peutSaisir)
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _envoi
                    ? null
                    : () => _faire(
                        () => _service.saisir(d.uuid, _saisis),
                        'Résultats enregistrés.',
                      ),
                child: const Text('Enregistrer les résultats'),
              ),
            ),
          if (d.modifiable && auth.peut('labo.valider')) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _envoi
                    ? null
                    : () => _faire(() async {
                        // Ce qui est à l'écran est enregistré avant de valider.
                        if (peutSaisir) await _service.saisir(d.uuid, _saisis);
                        return _service.valider(d.uuid);
                      }, 'Validé : le patient est prévenu.'),
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Valider et prévenir le patient'),
              ),
            ),
          ],
          if (d.validee && d.validePar != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Validé par ${d.validePar}',
                style: const TextStyle(color: Kolors.kSuccess),
              ),
            ),
        ],
      ),
    );
  }
}
