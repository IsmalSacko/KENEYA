import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../compte/compte_controller.dart';
import '../../compte/compte_models.dart';
import 'cadre_acces.dart';
import 'connexion_screen.dart';

/// Création d'un compte : tout le monde commence par « Ma santé ». Un
/// professionnel crée ou rejoint ensuite son établissement.
class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({super.key});

  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  final _code = TextEditingController();
  String _pays = Pays.defaut;

  /// Professionnel de santé : il verra aussi la partie pro. « Ma santé »
  /// reste à tous.
  bool _pro = false;

  /// Le serveur exige le code SMS : on l'a envoyé, on le demande.
  bool _codeDemande = false;

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _pin.dispose();
    _confirmation.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;
    final compte = context.read<CompteController>();
    final resultat = await compte.inscription(
      paysCode: _pays,
      telephone: _telephone.text.trim(),
      nom: _nom.text.trim(),
      pin: _pin.text,
      code: _codeDemande ? _code.text.trim() : null,
      pro: _pro,
    );
    if (!mounted) return;
    switch (resultat) {
      case ResultatInscription.reussie:
        Navigator.of(context).popUntil((route) => route.isFirst);
      case ResultatInscription.codeRequis:
        setState(() => _codeDemande = true);
        afficherMessage(context, 'Un code vient de vous être envoyé par SMS.');
      case ResultatInscription.echec:
        afficherMessage(context, compte.erreur ?? 'Inscription impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final compte = context.watch<CompteController>();
    return CadreAcces(
      titre: 'Créer mon compte',
      sousTitre:
          'Rendez-vous, tickets, ordonnances : tout au même endroit. Gratuit pour les patients.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Vous êtes :',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              // Sur un petit écran, « Professionnel » se coupait en deux :
              // pas de coche en plus de l'icône, et le mot rétrécit au besoin.
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.person_outline_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Patient', maxLines: 1),
                    ),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.medical_services_outlined),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Professionnel', maxLines: 1),
                    ),
                  ),
                ],
                selected: {_pro},
                onSelectionChanged: (s) => setState(() => _pro = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                _pro
                    ? 'Vous gardez « Ma santé » pour vous soigner, et vous pourrez créer votre établissement. Si votre établissement vous a déjà ajouté, votre espace apparaîtra tout seul.'
                    : 'Rendez-vous, tickets, ordonnances et dossier : tout au même endroit.',
                style: const TextStyle(
                  color: Kolors.kTextMuted,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nom,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nom et prénom',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Indiquez votre nom' : null,
              ),
              const SizedBox(height: 12),
              ChampTelephone(
                pays: compte.pays,
                paysChoisi: _pays,
                onPays: (p) => setState(() => _pays = p),
                controller: _telephone,
              ),
              const SizedBox(height: 12),
              ChampPin(controller: _pin, label: 'Choisissez un PIN'),
              const SizedBox(height: 12),
              ChampPin(
                controller: _confirmation,
                label: 'Confirmez le PIN',
                validator: (v) =>
                    v != _pin.text ? 'Les deux PIN sont différents' : null,
              ),
              if (_codeDemande) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Code reçu par SMS',
                    counterText: '',
                    prefixIcon: Icon(Icons.sms_outlined),
                  ),
                  validator: (v) =>
                      (v ?? '').length < 4 ? 'Entrez le code reçu' : null,
                ),
              ],
              const SizedBox(height: 18),
              BoutonAcces(
                label: 'Créer mon compte',
                chargement: compte.chargement,
                onPressed: _valider,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Déjà un compte ?',
                    style: TextStyle(color: Kolors.kTextMuted),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const ConnexionScreen(),
                      ),
                    ),
                    child: const Text('Se connecter'),
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
