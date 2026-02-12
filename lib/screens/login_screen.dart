import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController telephoneCtrl = TextEditingController();
  final TextEditingController pinCtrl = TextEditingController();

  @override
  void dispose() {
    telephoneCtrl.dispose();
    pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    final success = await auth.login(
      telephone: telephoneCtrl.text.trim(),
      pin: pinCtrl.text.trim(),
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Erreur de connexion')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: telephoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telephone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Entrer',
              loading: auth.loading,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
