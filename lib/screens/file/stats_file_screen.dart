import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../common/utils/kcolors.dart';
import '../../core/api/api_client.dart';
import '../../file/file_service.dart';

/// Les chiffres du jour de la file : pour savoir où l'on attend trop, et à
/// quelle heure il faut du monde au guichet.
class StatsFileScreen extends StatefulWidget {
  const StatsFileScreen({super.key});

  @override
  State<StatsFileScreen> createState() => _StatsFileScreenState();
}

class _StatsFileScreenState extends State<StatsFileScreen> {
  Map<String, dynamic>? _stats;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final s = await FileService().statistiques();
      if (mounted) setState(() => _stats = s);
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Chiffres du jour')),
      body: stats == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${stats['total']} tickets aujourd’hui',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Kolors.kTextHigh,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final s in (stats['services'] as List).cast<Map>())
                    _CarteService(s: Map<String, dynamic>.from(s)),
                  const SizedBox(height: 16),
                  Text(
                    'Arrivées par heure',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Kolors.kTextHigh,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Affluence(
                    heures: (stats['par_heure'] as List)
                        .cast<Map>()
                        .map((m) => Map<String, dynamic>.from(m))
                        .toList(),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CarteService extends StatelessWidget {
  const _CarteService({required this.s});

  final Map<String, dynamic> s;

  String _min(dynamic v) => v == null ? '—' : '$v min';

  @override
  Widget build(BuildContext context) {
    Widget chiffre(String label, String valeur) => Expanded(
      child: Column(
        children: [
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Kolors.kPrimary,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Kolors.kTextMuted),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (s['service'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                chiffre('servis', '${s['servis']}'),
                chiffre('en attente', '${s['en_attente']}'),
                chiffre('absents', '${s['absents']}'),
                chiffre('attente moyenne', _min(s['attente_moyenne_min'])),
                chiffre('attente max', _min(s['attente_max_min'])),
                chiffre('par patient', _min(s['passage_moyen_min'])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Affluence extends StatelessWidget {
  const _Affluence({required this.heures});

  final List<Map<String, dynamic>> heures;

  @override
  Widget build(BuildContext context) {
    if (heures.isEmpty) {
      return const Text(
        'Pas encore de ticket aujourd’hui.',
        style: TextStyle(color: Kolors.kTextMuted),
      );
    }
    final max = heures
        .map((h) => (h['tickets'] as num).toInt())
        .reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final h in heures)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 44, child: Text('${h['heure']} h')),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 16,
                            width: c.maxWidth * (h['tickets'] as num) / max,
                            decoration: BoxDecoration(
                              color: Kolors.kPrimary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${h['tickets']}',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
