import 'dart:async';
import 'package:flutter/material.dart';
import 'package:keneya_plus/controllers/user_controller.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key, required this.userCtrl});

  final UserController userCtrl;

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _role = 'admin';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await widget.userCtrl.createUser(
      name: _nameCtrl.text.trim(),
      telephone: _phoneCtrl.text.trim(),
      role: _role,
      pin: _pinCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _pinCtrl.clear();
      final message = widget.userCtrl.lastActionQueued
          ? 'Hors connexion: utilisateur en file d\'attente de synchronisation.'
          : 'Utilisateur ajoute.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.userCtrl.error ?? 'Echec creation utilisateur.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;

    final formCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Champ obligatoire'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telephone'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 8 || t.length > 20) {
                    return 'Telephone invalide (8 a 20 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'medecin', child: Text('Medecin')),
                  DropdownMenuItem(
                    value: 'pharmacien',
                    child: Text('Pharmacien'),
                  ),
                  DropdownMenuItem(value: 'caissier', child: Text('Caissier')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _role = v);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'PIN'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 4 || t.length > 6) {
                    return 'PIN invalide (4 a 6 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.userCtrl.loading ? null : _submit,
                  child: const Text('Ajouter utilisateur'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.userCtrl.loading
                      ? null
                      : () => widget.userCtrl.fetchUsers(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rafraichir la liste'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final listCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: widget.userCtrl.loading && widget.userCtrl.users.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : widget.userCtrl.users.isEmpty
            ? const Text('Aucun utilisateur.')
            : Column(
                children: widget.userCtrl.users
                    .map(
                      (u) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(u.name),
                        subtitle: Text('${u.role} | ${u.telephone}'),
                      ),
                    )
                    .toList(),
              ),
      ),
    );

    if (!isDesktop) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [formCard, const SizedBox(height: 12), listCard],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            children: [formCard],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            children: [listCard],
          ),
        ),
      ],
    );
  }
}
