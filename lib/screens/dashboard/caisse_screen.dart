import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../services/analytics_service.dart';
import 'widgets/panel.dart';

class CaisseScreen extends StatefulWidget {
  const CaisseScreen({super.key});

  @override
  State<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends State<CaisseScreen> {
  late Future<AnalyticsData> _future;
  final _fmt = NumberFormat.decimalPattern('fr_FR');

  @override
  void initState() {
    super.initState();
    _future = AnalyticsService().load();
  }

  Future<void> _refresh() async {
    setState(() => _future = AnalyticsService().load());
    await _future;
  }

  String _money(num v) => '${_fmt.format(v)} FCFA';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caisse du jour')),
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
            final total = data.caisseJourTotal;
            final modes = data.caisseJourParMode.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CarteMarque(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Encaissé aujourd’hui',
                        style: TextStyle(
                          color: Kolors.kWhite.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _money(total),
                        style: GoogleFonts.poppins(
                          color: Kolors.kJaune,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${data.nbPaiementsJour} paiement(s)',
                        style: TextStyle(
                          color: Kolors.kWhite.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Panel(
                  title: 'Répartition par mode de paiement',
                  child: modes.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Aucun encaissement aujourd’hui.',
                            style: TextStyle(color: Kolors.kTextMuted),
                          ),
                        )
                      : Column(
                          children: [
                            for (final e in modes)
                              _ModeRow(
                                mode: e.key,
                                montant: e.value,
                                part: total > 0 ? e.value / total : 0,
                                money: _money,
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.montant,
    required this.part,
    required this.money,
  });

  final String mode;
  final double montant;
  final double part;
  final String Function(num) money;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${money(montant)}  ·  ${(part * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: part,
              minHeight: 8,
              backgroundColor: Kolors.kOffWhite,
              color: Kolors.kPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
