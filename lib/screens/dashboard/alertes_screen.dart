import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../controllers/medicament_controller.dart';
import '../../models/medicament_model.dart';
import 'widgets/panel.dart';

class AlertesScreen extends StatelessWidget {
  const AlertesScreen({super.key});

  static DateTime? _expDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final part = s.split(' ').first;
    if (part.contains('/')) {
      final p = part.split('/');
      if (p.length == 3) {
        final d = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        final y = int.tryParse(p[2]);
        if (d != null && m != null && y != null) return DateTime(y, m, d);
      }
    }
    return DateTime.tryParse(s);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MedicamentController>();
    final meds = ctrl.medicaments;
    final now = DateTime.now();

    final ruptures = meds.where((m) => m.stock <= 0).toList();
    final stockBas = meds
        .where((m) => m.stock > 0 && m.stock <= m.seuilAlerte)
        .toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    final peremptions = meds
        .where((m) {
          final d = _expDate(m.dateExpiration);
          if (d == null) return false;
          final diff = d.difference(now).inDays;
          return diff <= 30;
        })
        .toList()
      ..sort((a, b) {
        final da = _expDate(a.dateExpiration) ?? now;
        final db = _expDate(b.dateExpiration) ?? now;
        return da.compareTo(db);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Alertes & stock')),
      body: RefreshIndicator(
        onRefresh: ctrl.fetchMedicaments,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _Kpi(
                    'Ruptures',
                    ruptures.length,
                    Icons.error_rounded,
                    Kolors.kRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Kpi(
                    'Stock bas',
                    stockBas.length,
                    Icons.warning_amber_rounded,
                    Kolors.kWarning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Kpi(
                    'Périment < 30j',
                    peremptions.length,
                    Icons.event_busy_rounded,
                    Kolors.kBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Panel(
              title: 'Ruptures & stock bas',
              child: (ruptures.isEmpty && stockBas.isEmpty)
                  ? const _EmptyLine('Aucune alerte de stock 🎉')
                  : Column(
                      children: [
                        for (final m in [...ruptures, ...stockBas])
                          _StockRow(m),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Panel(
              title: 'Périment bientôt (30 jours)',
              child: peremptions.isEmpty
                  ? const _EmptyLine('Aucune péremption proche.')
                  : Column(
                      children: [
                        for (final m in peremptions)
                          _ExpRow(m, _expDate(m.dateExpiration)!),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Kolors.kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Kolors.kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Kolors.kTextMuted),
          ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow(this.m);
  final MedicamentModel m;

  @override
  Widget build(BuildContext context) {
    final rupture = m.stock <= 0;
    final color = rupture ? Kolors.kRed : Kolors.kWarning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.medication_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              m.nom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rupture ? 'Rupture' : 'Stock ${m.stock}/${m.seuilAlerte}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpRow extends StatelessWidget {
  const _ExpRow(this.m, this.date);
  final MedicamentModel m;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final days = date.difference(DateTime.now()).inDays;
    final expired = days < 0;
    final color = expired ? Kolors.kRed : Kolors.kWarning;
    final label = expired
        ? 'Périmé'
        : days == 0
            ? "Aujourd'hui"
            : 'J-$days';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.event_busy_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              m.nom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(color: Kolors.kTextMuted, fontSize: 13),
      ),
    );
  }
}
