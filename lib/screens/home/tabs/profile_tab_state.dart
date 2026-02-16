import 'dart:async';
import 'package:flutter/material.dart';
import 'package:keneya_plus/common/utils/kcolors.dart';
import 'package:keneya_plus/controllers/auth_controller.dart';
import 'package:keneya_plus/core/offline/local_store.dart';
import 'package:provider/provider.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _stockAlerts = true;
  bool _syncAlerts = true;
  bool _soundNotif = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _nameCtrl.text = auth.currentUser?.name ?? '';
    _phoneCtrl.text = auth.currentUser?.telephone ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthController>().refreshCurrentUser().then((_) {
        if (!mounted) return;
        final updated = context.read<AuthController>();
        _nameCtrl.text = updated.currentUser?.name ?? _nameCtrl.text;
        _phoneCtrl.text = updated.currentUser?.telephone ?? _phoneCtrl.text;
      });
    });
    _loadSettings();
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final auth = context.read<AuthController>();
    _nameCtrl.text = auth.currentUser?.name ?? '';
    _phoneCtrl.text = auth.currentUser?.telephone ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final stock = LocalStore.read<bool>('settings_stock_alerts');
    final sync = LocalStore.read<bool>('settings_sync_alerts');
    final sound = LocalStore.read<bool>('settings_sound_notif');
    if (!mounted) return;
    setState(() {
      _stockAlerts = stock ?? true;
      _syncAlerts = sync ?? true;
      _soundNotif = sound ?? false;
    });
  }

  Future<void> _saveSettings() async {
    await LocalStore.write('settings_stock_alerts', _stockAlerts);
    await LocalStore.write('settings_sync_alerts', _syncAlerts);
    await LocalStore.write('settings_sound_notif', _soundNotif);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ok = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      telephone: _phoneCtrl.text.trim(),
      pin: _pinCtrl.text.trim().isEmpty ? null : _pinCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      _pinCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil mis a jour.')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(auth.error ?? 'Echec de mise a jour du profil.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;

    final profileInfoCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  child: Icon(Icons.person, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '-',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(user?.telephone ?? '-'),
                    ],
                  ),
                ),
                Chip(
                  label: Text(user?.role ?? '-'),
                  avatar: const Icon(Icons.verified_user_outlined, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(
                  label: Text(
                    auth.offlineProvisionalSession
                        ? 'Session locale'
                        : 'Session active',
                  ),
                  avatar: Icon(
                    auth.offlineProvisionalSession
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_done_outlined,
                    size: 18,
                  ),
                ),
                Chip(
                  label: Text(
                    user?.actif == true ? 'Compte actif' : 'Compte inactif',
                  ),
                  avatar: Icon(
                    user?.actif == true
                        ? Icons.check_circle_outline
                        : Icons.block_outlined,
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final editCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modifier mon profil',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom complet'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Champ obligatoire'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
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
              TextFormField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nouveau PIN (optionnel)',
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return null;
                  if (t.length < 4 || t.length > 6) {
                    return 'PIN invalide (4 a 6 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: auth.loading ? null : _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Enregistrer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: auth.loading ? null : () => auth.logout(),
                      // icon: const Icon(Icons.logout, color: Kolors.kOffWhite),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Kolors.kRed,
                        //side: const BorderSide(color: Colors.white),
                      ),
                      label: const Text(
                        'Déconnexion',
                        style: TextStyle(
                          color: Kolors.kWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final settingsCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alertes et notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _stockAlerts,
              onChanged: (v) async {
                setState(() => _stockAlerts = v);
                await _saveSettings();
              },
              title: const Text('Alertes stock faible'),
              subtitle: const Text('Afficher les alertes de seuil de stock.'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _syncAlerts,
              onChanged: (v) async {
                setState(() => _syncAlerts = v);
                await _saveSettings();
              },
              title: const Text('Alertes synchronisation'),
              subtitle: const Text(
                'Notifier les echecs et reprises de synchro.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _soundNotif,
              onChanged: (v) async {
                setState(() => _soundNotif = v);
                await _saveSettings();
              },
              title: const Text('Son des notifications'),
              subtitle: const Text(
                'Activer un son lors des notifications locales.',
              ),
            ),
          ],
        ),
      ),
    );

    if (!isDesktop) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          profileInfoCard,
          const SizedBox(height: 12),
          editCard,
          const SizedBox(height: 12),
          settingsCard,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            children: [
              profileInfoCard,
              const SizedBox(height: 12),
              settingsCard,
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            children: [editCard],
          ),
        ),
      ],
    );
  }
}
