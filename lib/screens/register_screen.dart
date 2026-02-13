import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/utils/app_style.dart';
import '../common/utils/kcolors.dart';
import '../common/utils/kstrings.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _etablissementCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _typeEtablissement = 'cabinet';
  bool _hidePin = true;

  @override
  void dispose() {
    _etablissementCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final ok = await auth.register(
      nomEtablissement: _etablissementCtrl.text.trim(),
      type: _typeEtablissement,
      name: _nameCtrl.text.trim(),
      telephone: _phoneCtrl.text.trim(),
      pin: _pinCtrl.text.trim(),
    );

    if (!mounted) return;
    if (ok) {
      if (auth.lastRegisterQueued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hors connexion: inscription en attente de synchronisation. '
              'Mode local active, synchronisation automatique au retour d\'Internet.',
            ),
          ),
        );
        Navigator.of(context).maybePop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Inscription reussie.')));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(auth.error ?? 'Echec de l\'inscription.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(
          AppText.kRegisterTitle,
          style: appStyle(18, Kolors.kWhite, FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _etablissementCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom de l\'etablissement',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ obligatoire'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _typeEtablissement,
                  decoration: const InputDecoration(
                    labelText: 'Type d\'etablissement',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cabinet', child: Text('Cabinet')),
                    DropdownMenuItem(
                      value: 'pharmacie',
                      child: Text('Pharmacie'),
                    ),
                    DropdownMenuItem(
                      value: 'cabinet_pharmacie',
                      child: Text('Cabinet + Pharmacie'),
                    ),
                  ],
                  onChanged: auth.loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _typeEtablissement = value);
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom complet'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ obligatoire'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telephone'),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.length < 8 || text.length > 20) {
                      return 'Telephone invalide (8 a 20 caracteres)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: _hidePin,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hidePin = !_hidePin),
                      icon: Icon(
                        _hidePin
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.length < 4 || text.length > 6) {
                      return 'PIN invalide (4 a 6 caracteres)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: auth.loading ? null : _submit,
                    child: auth.loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Creer mon compte'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
