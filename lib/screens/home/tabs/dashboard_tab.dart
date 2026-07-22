import 'dart:async';
import 'package:flutter/material.dart';
import 'package:keneya_plus/common/utils/kcolors.dart';
import 'package:keneya_plus/common/utils/role_ui.dart';
import 'package:keneya_plus/controllers/auth_controller.dart';
import 'package:keneya_plus/screens/dashboard/alertes_screen.dart';
import 'package:keneya_plus/screens/dashboard/caisse_screen.dart';
import 'package:keneya_plus/screens/dashboard/stats_screen.dart';
import 'package:keneya_plus/controllers/etablissement_controller.dart';
import 'package:keneya_plus/controllers/medicament_controller.dart';
import 'package:keneya_plus/controllers/patient_controller.dart';
import 'package:keneya_plus/controllers/user_controller.dart';
import 'package:keneya_plus/screens/home/widgets/section_card.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.auth,
    required this.patientCtrl,
    required this.medicamentCtrl,
    required this.etablissementCtrl,
    required this.userCtrl,
    required this.onRefresh,
  });

  final AuthController auth;
  final PatientController patientCtrl;
  final MedicamentController medicamentCtrl;
  final EtablissementController etablissementCtrl;
  final UserController userCtrl;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final stockBas = medicamentCtrl.medicaments
        .where((m) => m.stock <= m.seuilAlerte)
        .length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final cardWidth = wide
              ? (constraints.maxWidth - 48) / 2
              : constraints.maxWidth;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _WelcomeHeader(name: auth.currentUser?.name ?? ''),
              const SizedBox(height: 18),
              _StatsGrid(
                stats: [
                  _Stat('Patients', patientCtrl.patients.length,
                      Icons.groups_rounded, Kolors.kPrimary),
                  _Stat('Médicaments', medicamentCtrl.medicaments.length,
                      Icons.medication_rounded, Kolors.kBlue),
                  _Stat('Stock bas', stockBas, Icons.warning_amber_rounded,
                      Kolors.kWarning),
                  _Stat(
                      'Établissements',
                      etablissementCtrl.etablissements.length,
                      Icons.local_hospital_rounded,
                      Kolors.kSuccess),
                ],
              ),
              const SizedBox(height: 22),
              _QuickActions(role: auth.currentUser?.role),
              const SizedBox(height: 22),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: SectionCard(
                      title: 'Patients',
                      loading: patientCtrl.loading,
                      error: patientCtrl.error,
                      emptyMessage: 'Aucun patient.',
                      children: patientCtrl.patients
                          .take(5)
                          .map(
                            (p) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const _Avatar(icon: Icons.person_rounded),
                              title: Text(p.nom),
                              subtitle: Text(p.telephone ?? '-'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: SectionCard(
                      title: 'Médicaments',
                      loading: medicamentCtrl.loading,
                      error: medicamentCtrl.error,
                      emptyMessage: 'Aucun médicament.',
                      children: medicamentCtrl.medicaments
                          .take(5)
                          .map(
                            (m) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const _Avatar(
                                icon: Icons.medication_rounded,
                              ),
                              title: Text(m.nom),
                              subtitle: Text(
                                'Stock: ${m.stock} · Prix: ${m.prixUnitaire}',
                              ),
                              trailing: m.stock <= m.seuilAlerte
                                  ? const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Kolors.kWarning,
                                    )
                                  : null,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: SectionCard(
                      title: 'Établissements',
                      loading: etablissementCtrl.loading,
                      error: etablissementCtrl.error,
                      emptyMessage: 'Aucun établissement.',
                      children: etablissementCtrl.etablissements
                          .take(5)
                          .map(
                            (e) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const _Avatar(
                                icon: Icons.local_hospital_rounded,
                              ),
                              title: Text(e.nom),
                              subtitle:
                                  Text('${e.type} · ${e.telephone ?? '-'}'),
                              trailing: _StatusDot(active: e.actif),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: SectionCard(
                      title: 'Utilisateurs',
                      loading: userCtrl.loading,
                      error: userCtrl.error,
                      emptyMessage: 'Aucun utilisateur.',
                      children: userCtrl.users
                          .take(5)
                          .map((u) {
                            final r = RoleUi.of(u.role);
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: _Avatar(icon: r.icon, color: r.color),
                              title: Text(u.name),
                              subtitle: Text('${r.label} · ${u.telephone}'),
                              trailing: _StatusDot(active: u.actif),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// En-tête de bienvenue en dégradé émeraude.
class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final prenom = name.trim().isEmpty ? '' : name.trim().split(' ').first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Kolors.kPrimary, Kolors.kBlue],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Kolors.kPrimary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour${prenom.isEmpty ? '' : ', $prenom'} !',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Voici l’activité de votre établissement aujourd’hui.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 640 ? 4 : 2;
        const spacing = 12.0;
        final tileWidth = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats
              .map((s) => SizedBox(width: tileWidth, child: _StatTile(stat: s)))
              .toList(),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Kolors.kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Kolors.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(stat.icon, color: stat.color, size: 21),
          ),
          const SizedBox(height: 10),
          Text(
            '${stat.value}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Kolors.kTextHigh,
            ),
          ),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Kolors.kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon, this.color});
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Kolors.kPrimaryDark;
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: c, size: 19),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Kolors.kSuccess : Kolors.kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Actif' : 'Inactif',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Raccourcis vers les écrans de tableau de bord, ordonnés selon le rôle.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.role});
  final String? role;

  @override
  Widget build(BuildContext context) {
    final stats = _ActionCard(
      icon: Icons.insights_rounded,
      label: 'Statistiques',
      color: Kolors.kPrimary,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
      ),
    );
    final alertes = _ActionCard(
      icon: Icons.warning_amber_rounded,
      label: 'Alertes stock',
      color: Kolors.kWarning,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AlertesScreen()),
      ),
    );
    final caisse = _ActionCard(
      icon: Icons.point_of_sale_rounded,
      label: 'Caisse du jour',
      color: Kolors.kSuccess,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CaisseScreen()),
      ),
    );

    final List<Widget> cards;
    switch (role) {
      case 'pharmacien':
        cards = [alertes, caisse, stats];
        break;
      case 'caissier':
        cards = [caisse, alertes, stats];
        break;
      default:
        cards = [stats, alertes, caisse];
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Kolors.kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Kolors.kBorder),
        ),
        child: Column(
          children: [
            Container(
              height: 42,
              width: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Kolors.kTextHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
