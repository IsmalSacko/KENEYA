import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../compte/compte_controller.dart';
import '../../compte/mes_tickets_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/plateforme.dart';

/// Supprimer son compte depuis l'application (exigé par l'App Store) : ce
/// qui part, et ce que la loi oblige à garder, est dit avant ; puis le PIN
/// et « SUPPRIMER » tapés.
Future<void> supprimerMonCompte(BuildContext context) async {
  final compte = context.read<CompteController>();
  final messager = ScaffoldMessenger.of(context);
  Map<String, dynamic> apercu = const {};
  try {
    apercu = await compte.apercuSuppression();
  } on DioException catch (e) {
    messager.showSnackBar(SnackBar(content: Text(messageErreur(e))));
    return;
  }
  if (!context.mounted) return;
  final supprime = await showDialog<bool>(
    context: context,
    builder: (_) => DialogueSuppressionCompte(apercu: apercu),
  );
  if (supprime == true) {
    messager.showSnackBar(
      const SnackBar(content: Text('Votre compte Ngoni Santé est supprimé.')),
    );
  }
}

class DialogueSuppressionCompte extends StatefulWidget {
  const DialogueSuppressionCompte({required this.apercu, super.key});

  /// La réponse de GET /compte/suppression.
  final Map<String, dynamic> apercu;

  @override
  State<DialogueSuppressionCompte> createState() =>
      _DialogueSuppressionCompteState();
}

class _DialogueSuppressionCompteState extends State<DialogueSuppressionCompte> {
  final _pin = TextEditingController();
  final _mot = TextEditingController();
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _pin.dispose();
    _mot.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _liste(String cle) => [
    for (final x in (widget.apercu[cle] as List?) ?? const [])
      if (x is Map) Map<String, dynamic>.from(x),
  ];

  Future<void> _supprimer() async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    final auth = context.read<AuthController>();
    final tickets = context.read<MesTicketsController>();
    try {
      await context.read<CompteController>().supprimerCompte(_pin.text, auth);
      tickets.arreter();
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _envoi = false;
          _erreur = messageErreur(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supprimes = _liste('etablissements_supprimes');
    final gardes = _liste('etablissements_gardes');
    final blocage = widget.apercu['blocage'] as String?;
    final pret =
        blocage == null &&
        !_envoi &&
        _pin.text.length >= 4 &&
        _mot.text.trim().toUpperCase() == 'SUPPRIMER';
    const discret = TextStyle(color: Kolors.kTextMuted, fontSize: 13);

    return AlertDialog(
      title: const Text('Supprimer mon compte ?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            const Text(
              'Votre compte Ngoni Santé est supprimé : nom, numéro, PIN et carte santé. Vos rendez-vous, tickets et ordonnances n’apparaîtront plus dans l’application.',
            ),
            for (final e in supprimes)
              Text(
                '« ${e['nom']} » est supprimé aussi, car vous en êtes le seul administrateur : '
                '${e['patients'] ?? 0} patient${(e['patients'] ?? 0) == 1 ? '' : 's'} et leurs dossiers, consultations, ventes, stock, '
                'équipe (${e['equipe'] ?? 0}) et abonnement.',
                key: Key('suppression-etablissement-${e['nom']}'),
                style: const TextStyle(
                  color: Kolors.kRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            for (final e in gardes)
              Text(
                e['repreneur'] == null
                    ? '« ${e['nom']} » continue : votre accès s’y ferme.'
                    : '« ${e['nom']} » continue avec ${e['repreneur']} : votre accès s’y ferme.',
              ),
            Text(switch (widget.apercu['dossier']) {
              'garde' =>
                'Votre dossier médical, noté par les établissements qui vous ont soigné, reste chez eux sans lien avec votre compte, '
                    'pendant la durée de conservation imposée par la loi. Les accès que vous aviez donnés sont retirés.',
              'supprime' => 'Votre dossier « Ma santé » est supprimé.',
              _ =>
                'Ce que les établissements ont noté à votre sujet reste chez eux, pendant la durée de conservation imposée par la loi.',
            }),
            const Text(
              'Restent aussi, comme la loi l’exige : les factures et les actes déjà enregistrés dans les établissements '
              '(votre nom y figure, plus votre numéro), et les reçus d’abonnement payés.',
              style: discret,
            ),
            if (achatsInterdits)
              const Text(
                'Pensez à résilier votre abonnement dans les réglages Apple : supprimer le compte ne l’arrête pas.',
                key: Key('suppression-abonnement-apple'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            const Text(
              'Cette action est définitive.',
              style: TextStyle(color: Kolors.kRed, fontWeight: FontWeight.w700),
            ),
            if (blocage != null)
              Text(blocage, style: const TextStyle(color: Kolors.kRed))
            else ...[
              TextField(
                key: const Key('suppression-pin'),
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Votre PIN',
                  prefixIcon: Icon(Icons.lock_outline),
                  counterText: '',
                ),
              ),
              TextField(
                key: const Key('suppression-confirmation'),
                controller: _mot,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Tapez SUPPRIMER pour confirmer',
                  prefixIcon: Icon(Icons.keyboard_outlined),
                ),
              ),
            ],
            if (_erreur != null)
              Text(_erreur!, style: const TextStyle(color: Kolors.kRed)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('confirmer-suppression-compte'),
          style: FilledButton.styleFrom(backgroundColor: Kolors.kRed),
          onPressed: pret ? _supprimer : null,
          child: Text(_envoi ? 'Suppression…' : 'Supprimer'),
        ),
      ],
    );
  }
}
