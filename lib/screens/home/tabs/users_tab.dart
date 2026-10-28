import 'dart:async';
import 'package:flutter/material.dart';
import 'package:keneya_plus/common/utils/kcolors.dart';
import 'package:keneya_plus/common/utils/role_ui.dart';
import 'package:keneya_plus/common/utils/roles.dart';
import 'package:keneya_plus/common/whatsapp.dart';
import 'package:keneya_plus/compte/compte_controller.dart';
import 'package:keneya_plus/controllers/auth_controller.dart';
import 'package:keneya_plus/controllers/user_controller.dart';
import 'package:keneya_plus/models/user_model.dart';
import 'package:provider/provider.dart';

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
  String _role = AppRoles.medecin;
  String? _roleAjoute;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _roleAjoute = _role;
    final ok = await widget.userCtrl.createUser(
      name: _nameCtrl.text.trim(),
      telephone: _phoneCtrl.text.trim(),
      role: _role,
      pin: _pinCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      final nom = _nameCtrl.text.trim();
      final telephone = _phoneCtrl.text.trim();
      final pin = _pinCtrl.text.trim();
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _pinCtrl.clear();
      if (widget.userCtrl.lastActionQueued) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hors connexion : le membre sera ajouté au retour du réseau.',
            ),
          ),
        );
        return;
      }
      await _inviter(nom, telephone, pin);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.userCtrl.error ?? 'Impossible d’ajouter ce membre.',
        ),
      ),
    );
  }

  /// Le membre est ajouté : on lui envoie de quoi se connecter.
  Future<void> _inviter(String nom, String telephone, String pin) async {
    final etab =
        context.read<CompteController>().espaceOuvert?.etablissementNom ??
        'notre établissement';
    final message =
        'Bonjour $nom, vous faites partie de l’équipe de $etab sur Ngoni Santé '
        '(${AppRoles.labelOf(_roleAjoute ?? _role)}).\n'
        'Installez l’application : https://play.google.com/store/apps/details?id=com.ismaeldev.keneya\n'
        'Connectez-vous avec votre numéro $telephone et le PIN $pin '
        '(si vous aviez déjà Ngoni Santé, gardez votre PIN habituel).';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$nom est dans l’équipe'),
        content: const Text(
          'Envoyez-lui l’invitation : le lien de l’application, son numéro et son PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              envoyerWhatsApp(context, telephone, message);
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Inviter par WhatsApp'),
          ),
        ],
      ),
    );
  }

  /// Un membre touché : changer son rôle, couper son accès, le retirer.
  Future<void> _gerer(UserModel u, List<String> roles) async {
    final ctrl = widget.userCtrl;
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                u.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(AppRoles.labelOf(u.role)),
            ),
            if (roles.contains(u.role))
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Changer son rôle'),
                onTap: () => Navigator.pop(ctx, 'role'),
              ),
            ListTile(
              leading: Icon(
                u.actif ? Icons.block_rounded : Icons.check_circle_outline,
              ),
              title: Text(u.actif ? 'Couper son accès' : 'Rendre son accès'),
              subtitle: u.actif
                  ? const Text('Il reste dans la liste, sans pouvoir entrer.')
                  : null,
              onTap: () => Navigator.pop(ctx, 'actif'),
            ),
            ListTile(
              leading: const Icon(
                Icons.person_remove_outlined,
                color: Kolors.kRed,
              ),
              title: const Text(
                'Retirer de l’équipe',
                style: TextStyle(color: Kolors.kRed),
              ),
              onTap: () => Navigator.pop(ctx, 'retirer'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    bool ok;
    switch (action) {
      case 'role':
        final role = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text('Rôle de ${u.name}'),
            children: [
              for (final r in roles)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, r),
                  child: Text(
                    AppRoles.labelOf(r),
                    style: TextStyle(
                      fontWeight: r == u.role ? FontWeight.w800 : null,
                    ),
                  ),
                ),
            ],
          ),
        );
        if (role == null || role == u.role) return;
        ok = await ctrl.updateUser(u.id, {'role': role});
      case 'actif':
        ok = await ctrl.updateUser(u.id, {'actif': !u.actif});
      default:
        final oui = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Retirer ${u.name} ?'),
            content: const Text(
              'Il n’aura plus accès à cet établissement. Ce qu’il y a fait (consultations, ventes…) reste.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Retirer'),
              ),
            ],
          ),
        );
        if (oui != true) return;
        ok = await ctrl.deleteUser(u.id);
    }
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(ctrl.error ?? 'Action impossible.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.userCtrl,
      builder: (context, _) => _contenu(context),
    );
  }

  Widget _contenu(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;

    // Rôles que l'utilisateur courant a le droit d'attribuer (un admin
    // d'établissement ne peut pas créer d'admin d'instance).
    final moi = context.read<AuthController>().currentUser;
    final currentRole = moi?.role;
    final assignableRoles = AppRoles.assignableBy(currentRole);
    if (!assignableRoles.contains(_role) && assignableRoles.isNotEmpty) {
      _role = assignableRoles.first;
    }

    final formCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Prénom et nom'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Champ obligatoire'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 8 || t.length > 20) {
                    return 'Numéro invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: [
                  for (final r in assignableRoles)
                    DropdownMenuItem(
                      value: r,
                      child: Text(AppRoles.labelOf(r)),
                    ),
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
                decoration: const InputDecoration(
                  labelText: 'PIN de départ (4 à 6 chiffres)',
                  helperText: 'S’il a déjà Ngoni Santé, il garde son PIN.',
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 4 || t.length > 6) {
                    return 'De 4 à 6 chiffres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.userCtrl.loading ? null : _submit,
                  child: const Text('Ajouter à l’équipe'),
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
                  label: const Text('Rafraîchir la liste'),
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
            ? Text(widget.userCtrl.error ?? 'Aucun membre.')
            : Column(
                children: [
                  for (final u in widget.userCtrl.users)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _UserCard(
                        name: u.name,
                        telephone: u.telephone,
                        role: u.role,
                        actif: u.actif,
                        onTap: u.id == moi?.id
                            ? null
                            : () => _gerer(u, assignableRoles),
                      ),
                    ),
                ],
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

/// Carte utilisateur : avatar coloré selon le rôle + puces rôle & statut.
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.name,
    required this.telephone,
    required this.role,
    required this.actif,
    this.onTap,
  });

  final String name;
  final String telephone;
  final String role;
  final bool actif;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = RoleUi.of(role);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Kolors.kWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Kolors.kBorder),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: r.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(r.icon, color: r.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: Kolors.kTextHigh,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    telephone,
                    style: const TextStyle(
                      color: Kolors.kTextMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniChip(text: r.label, color: r.color),
                const SizedBox(height: 6),
                _MiniChip(
                  text: actif ? 'Actif' : 'Inactif',
                  color: actif ? Kolors.kSuccess : Kolors.kRed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
