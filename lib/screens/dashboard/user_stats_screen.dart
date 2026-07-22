import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../common/utils/kcolors.dart';
import '../../services/user_stats_service.dart';
import 'widgets/panel.dart';

/// Tableau de bord des utilisateurs (admin) : effectifs, activité,
/// inscriptions par mois et tendance.
class UserStatsScreen extends StatefulWidget {
  const UserStatsScreen({super.key});

  @override
  State<UserStatsScreen> createState() => _UserStatsScreenState();
}

class _UserStatsScreenState extends State<UserStatsScreen> {
  late Future<UserStats> _future;

  @override
  void initState() {
    super.initState();
    _future = UserStatsService().load();
  }

  Future<void> _refresh() async {
    setState(() => _future = UserStatsService().load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Kolors.kOffWhite,
      appBar: AppBar(title: const Text('Tableau de bord — Utilisateurs')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<UserStats>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || snap.data == null) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Statistiques indisponibles.')),
                ],
              );
            }
            final s = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _kpiGrid(s),
                const SizedBox(height: 16),
                _trendCard(s),
                const SizedBox(height: 16),
                Panel(
                  title: 'Inscriptions (12 derniers mois)',
                  child: SizedBox(
                    height: 220,
                    child: _InscriptionsChart(s.parMois),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      _LegendDot(color: Kolors.kPrimary, label: 'Hausse / stable'),
                      SizedBox(width: 16),
                      _LegendDot(color: Kolors.kRed, label: 'Baisse'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Panel(
                  title: 'Répartition par rôle',
                  child: _RoleBreakdown(parRole: s.parRole, total: s.total),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kpiGrid(UserStats s) {
    final tiles = [
      _KpiTile(
        label: 'Utilisateurs',
        value: '${s.total}',
        icon: Icons.groups_rounded,
        color: Kolors.kPrimary,
      ),
      _KpiTile(
        label: 'Actifs',
        value: '${s.actifs}',
        icon: Icons.verified_user_rounded,
        color: Kolors.kSuccess,
      ),
      _KpiTile(
        label: 'Désactivés',
        value: '${s.inactifs}',
        icon: Icons.person_off_rounded,
        color: Kolors.kRed,
      ),
      _KpiTile(
        label: "Taux d'activité",
        value: '${s.tauxActivite.toStringAsFixed(0)}%',
        icon: Icons.percent_rounded,
        color: Kolors.kBlue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final twoCols = c.maxWidth < 520;
        final width = twoCols
            ? (c.maxWidth - 12) / 2
            : (c.maxWidth - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in tiles) SizedBox(width: width, child: t),
          ],
        );
      },
    );
  }

  Widget _trendCard(UserStats s) {
    final up = s.variationPct >= 0;
    final color = up ? Kolors.kSuccess : Kolors.kRed;
    return Panel(
      title: 'Tendance des inscriptions',
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.nouveauxCeMois} ce mois-ci',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Kolors.kTextHigh,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${up ? '+' : ''}${s.variationPct.toStringAsFixed(1)}% vs mois précédent (${s.nouveauxMoisPrecedent})',
                  style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Kolors.kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Kolors.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Kolors.kTextHigh,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Kolors.kTextMuted),
          ),
        ],
      ),
    );
  }
}

class _InscriptionsChart extends StatelessWidget {
  const _InscriptionsChart(this.points);
  final List<MonthPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('Aucune donnée.'));
    }
    double maxY = 1;
    for (final p in points) {
      if (p.total > maxY) maxY = p.total.toDouble();
    }

    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(enabled: true),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox();
                // Label court : le mois (avant le "/").
                final mm = points[i].label.split('/').first;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    mm,
                    style: const TextStyle(fontSize: 9, color: Kolors.kTextMuted),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].total.toDouble(),
                  // Rouge quand le mois est en baisse par rapport au précédent.
                  color: (i > 0 && points[i].total < points[i - 1].total)
                      ? Kolors.kRed
                      : Kolors.kPrimary,
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RoleBreakdown extends StatelessWidget {
  const _RoleBreakdown({required this.parRole, required this.total});
  final Map<String, int> parRole;
  final int total;

  static const Map<String, String> _labels = {
    'admin': 'Administrateurs',
    'medecin': 'Médecins',
    'pharmacien': 'Pharmaciens',
    'caissier': 'Caissiers',
  };

  @override
  Widget build(BuildContext context) {
    final entries = _labels.entries.toList();
    return Column(
      children: [
        for (final e in entries) ...[
          _RoleRow(
            label: e.value,
            count: parRole[e.key] ?? 0,
            ratio: total > 0 ? (parRole[e.key] ?? 0) / total : 0,
          ),
          if (e.key != entries.last.key) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.label,
    required this.count,
    required this.ratio,
  });
  final String label;
  final int count;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Kolors.kTextHigh),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Kolors.kTextHigh,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 8,
            backgroundColor: Kolors.kSecondaryLight,
            valueColor: const AlwaysStoppedAnimation<Color>(Kolors.kPrimary),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Kolors.kTextMuted),
        ),
      ],
    );
  }
}
