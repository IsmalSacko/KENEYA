import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../compte/compte_controller.dart';
import 'cadre_acces.dart';

/// PIN oublié : un code par SMS, puis un nouveau PIN.
class PinOublieScreen extends StatefulWidget {
  const PinOublieScreen({
    required this.paysCode,
    this.telephone = '',
    super.key,
  });

  final String paysCode;
  final String telephone;

  @override
  State<PinOublieScreen> createState() => _PinOublieScreenState();
}

class _PinOublieScreenState extends State<PinOublieScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _telephone = TextEditingController(text: widget.telephone);
  final _code = TextEditingController();
  final _pin = TextEditingController();
  late String _pays = widget.paysCode;
  bool _codeEnvoye = false;

  @override
  void dispose() {
    _telephone.dispose();
    _code.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;
    final compte = context.read<CompteController>();

    if (!_codeEnvoye) {
      final ok = await compte.demanderCodePin(
        paysCode: _pays,
        telephone: _telephone.text.trim(),
      );
      if (!mounted) return;
      if (ok) {
        setState(() => _codeEnvoye = true);
        afficherMessage(
          context,
          'Si ce numéro a un compte, un code vient de lui être envoyé.',
        );
      } else {
        afficherMessage(context, compte.erreur ?? 'Envoi impossible.');
      }
      return;
    }

    final ok = await compte.pinOublie(
      paysCode: _pays,
      telephone: _telephone.text.trim(),
      code: _code.text.trim(),
      pin: _pin.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      afficherMessage(context, compte.erreur ?? 'Code incorrect.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final compte = context.watch<CompteController>();
    return CadreAcces(
      titre: 'PIN oublié',
      sousTitre: _codeEnvoye
          ? 'Entrez le code reçu par SMS et choisissez un nouveau PIN.'
          : 'Nous allons vous envoyer un code par SMS.',
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
              if (_codeEnvoye) ...[
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
                const SizedBox(height: 12),
                ChampPin(
                  controller: _pin,
                  label: 'Nouveau PIN',
                  onSubmitted: _valider,
                ),
              ],
              const SizedBox(height: 18),
              BoutonAcces(
                label: _codeEnvoye ? 'Changer mon PIN' : 'Recevoir le code',
                chargement: compte.chargement,
                onPressed: _valider,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
