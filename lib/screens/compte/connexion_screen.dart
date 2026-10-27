import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../compte/compte_controller.dart';
import '../../compte/compte_models.dart';
import 'cadre_acces.dart';
import 'inscription_screen.dart';
import 'pin_oublie_screen.dart';

/// Connexion d'une personne : son numéro et son PIN. Le même compte ouvre
/// « Ma santé » et les espaces pro de ses établissements.
class ConnexionScreen extends StatefulWidget {
  const ConnexionScreen({super.key});

  @override
  State<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends State<ConnexionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _telephone = TextEditingController();
  final _pin = TextEditingController();
  String _pays = Pays.defaut;

  @override
  void dispose() {
    _telephone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;
    final compte = context.read<CompteController>();
    final ok = await compte.connexion(
      paysCode: _pays,
      telephone: _telephone.text.trim(),
      pin: _pin.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      afficherMessage(context, compte.erreur ?? 'Connexion impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final compte = context.watch<CompteController>();
    return CadreAcces(
      titre: 'Connexion',
      sousTitre:
          'Votre numéro et votre PIN : un seul compte pour votre santé et votre travail.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChampTelephone(
                pays: compte.pays,
                paysChoisi: _pays,
                onPays: (p) => setState(() => _pays = p),
                controller: _telephone,
              ),
              const SizedBox(height: 12),
              ChampPin(controller: _pin, onSubmitted: _valider),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PinOublieScreen(
                        paysCode: _pays,
                        telephone: _telephone.text.trim(),
                      ),
                    ),
                  ),
                  child: const Text('PIN oublié ?'),
                ),
              ),
              const SizedBox(height: 4),
              BoutonAcces(
                label: 'Se connecter',
                chargement: compte.chargement,
                onPressed: _valider,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Pas encore de compte ?',
                    style: TextStyle(color: Kolors.kTextMuted),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const InscriptionScreen(),
                      ),
                    ),
                    child: const Text('Créer un compte'),
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
