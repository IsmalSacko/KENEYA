import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keneya_plus/common/utils/kcolors.dart';
import 'package:keneya_plus/common/widgets/carte_marque.dart';
import 'package:keneya_plus/common/utils/role_ui.dart';
import 'package:keneya_plus/compte/compte_controller.dart';
import 'package:keneya_plus/controllers/auth_controller.dart';
import 'package:provider/provider.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthController>().refreshCurrentUser();
    });
  }

  Future<void> _deconnexion() async {
    final auth = context.read<AuthController>();
    final compte = context.read<CompteController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez entrer votre numéro et votre PIN pour revenir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (ok == true) await compte.deconnexion(auth);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final role = RoleUi.of(user?.role);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CarteMarque(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarMarque(role.icon, size: 62),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Kolors.kWhite,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.telephone ?? '-',
                          style: TextStyle(
                            color: Kolors.kWhite.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _WhiteChip(icon: role.icon, label: role.label),
                  _WhiteChip(
                    icon: auth.offlineProvisionalSession
                        ? Icons.cloud_off_rounded
                        : Icons.cloud_done_rounded,
                    label: auth.offlineProvisionalSession
                        ? 'Hors ligne'
                        : 'En ligne',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.key_outlined),
            title: Text('Un seul compte, un seul PIN'),
            subtitle: Text(
              'Votre numéro et votre PIN servent pour « Ma santé » et tous vos établissements. PIN oublié : touchez « PIN oublié » sur l’écran de connexion.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Kolors.kRed),
          onPressed: auth.loading ? null : _deconnexion,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Se déconnecter'),
        ),
      ],
    );
  }
}

/// Puce blanche translucide pour les en-têtes en dégradé.
class _WhiteChip extends StatelessWidget {
  const _WhiteChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Kolors.kWhite.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Kolors.kJaune),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Kolors.kWhite,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
