import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../common/utils/kcolors.dart';
import '../../services/analytics_service.dart';
import 'widgets/panel.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<AnalyticsData> _future;

  @override
  void initState() {
    super.initState();
    _future = AnalyticsService().load();
  }

  Future<void> _refresh() async {
    setState(() => _future = AnalyticsService().load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<AnalyticsData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data;
            if (data == null) {
              return const Center(child: Text('Aucune donnée.'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Panel(
                  title: 'Activité (7 derniers jours)',
                  child: SizedBox(height: 200, child: _ActivityChart(data.activite)),
                ),
                const SizedBox(height: 16),
                Panel(
                  title: 'Recettes par mode de paiement',
                  child: SizedBox(
                    height: 200,
                    child: _RecettesChart(data.recettesParMode),
                  ),
                ),
                const SizedBox(height: 16),
                Panel(
                  title: 'Top médicaments vendus',
                  child: _TopMedList(data.topMedicaments),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart(this.days);
  final List<DayActivity> days;

  @override
  Widget build(BuildContext context) {
    double maxY = 1;
    for (final d in days) {
      final m = (d.consultations > d.ventes ? d.consultations : d.ventes)
          .toDouble();
      if (m > maxY) maxY = m;
    }
    return BarChart(
      BarChartData(
        maxY: maxY + 1,
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
                if (i < 0 || i >= days.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    days[i].label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Kolors.kTextMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].consultations.toDouble(),
                  color: Kolors.kPrimary,
                  width: 7,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: days[i].ventes.toDouble(),
                  color: Kolors.kBlue,
                  width: 7,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecettesChart extends StatelessWidget {
  const _RecettesChart(this.data);
  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Aucune recette.'));
    }
    final entries = data.entries.toList();
    double maxY = 1;
    for (final e in entries) {
      if (e.value > maxY) maxY = e.value;
    }
    const colors = [
      Kolors.kPrimary,
      Kolors.kBlue,
      Kolors.kSuccess,
      Kolors.kWarning,
    ];
    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
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
                if (i < 0 || i >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    entries[i].key,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Kolors.kTextMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  color: colors[i % colors.length],
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TopMedList extends StatelessWidget {
  const _TopMedList(this.meds);
  final List<TopMed> meds;

  @override
  Widget build(BuildContext context) {
    if (meds.isEmpty) {
      return const Text('Aucune vente enregistrée.');
    }
    final maxQ = meds.first.quantite.clamp(1, 1 << 31);
    return Column(
      children: [
        for (final m in meds)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    m.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: m.quantite / maxQ,
                      minHeight: 10,
                      backgroundColor: Kolors.kOffWhite,
                      color: Kolors.kPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${m.quantite}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
