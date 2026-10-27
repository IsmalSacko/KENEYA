import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../core/api/api_client.dart';
import '../../presence/presence_service.dart';

/// Les badges du personnel (à montrer ou imprimer) et la présence du mois.
class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _service = PresenceService();
  final _mois = DateFormat('yyyy-MM').format(DateTime.now());
  List<BadgeMembre>? _badges;
  List<Map<String, dynamic>>? _rapport;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final b = await _service.badges();
      final r = await _service.rapport(_mois);
      if (mounted) {
        setState(() {
          _badges = b;
          _rapport = r;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Future<void> _voir(BadgeMembre m) async {
    final renouveler = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CarteMarque(
                  child: Column(
                    children: [
                      Text(
                        m.nom,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        m.role,
                        style: const TextStyle(
                          color: Kolors.kJaune,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Kolors.kWhite,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(data: m.badge, size: 200),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Kolors.kWhite,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Badge perdu'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Fermer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (renouveler != true) return;
    try {
      await _service.renouveler(m.uuid);
      await _charger();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nouveau badge : l’ancien ne marche plus.'),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _badges;
    final r = _rapport;
    return Scaffold(
      appBar: AppBar(title: const Text('Badges et présence')),
      body: b == null || r == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Présence du mois',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final l in r)
                        ListTile(
                          dense: true,
                          title: Text('${l['nom']}'),
                          subtitle: Text('${l['role']}'),
                          trailing: Text(
                            '${l['jours']} j · ${l['heures']} h',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Badges',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final m in b)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.badge_rounded),
                      title: Text(m.nom),
                      subtitle: Text(m.role),
                      trailing: const Icon(Icons.qr_code_2_rounded),
                      onTap: () => _voir(m),
                    ),
                  ),
              ],
            ),
    );
  }
}
