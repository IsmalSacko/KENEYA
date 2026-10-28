import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../caisse/caisse_models.dart';
import '../../caisse/caisse_service.dart';
import '../../common/utils/kcolors.dart';
import '../../core/api/api_client.dart';

/// Les caisses des 30 derniers jours : qui, quand, ce qui est entré, et
/// l'écart entre les espèces comptées et attendues.
class CaissesScreen extends StatefulWidget {
  const CaissesScreen({required this.devise, super.key});

  final String devise;

  @override
  State<CaissesScreen> createState() => _CaissesScreenState();
}

class _CaissesScreenState extends State<CaissesScreen> {
  List<Map<String, dynamic>>? _sessions;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final s = await CaisseService().sessions();
      if (mounted) setState(() => _sessions = s);
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  static final _format = DateFormat('dd/MM HH:mm');

  String _date(dynamic iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    return d == null ? '' : _format.format(d);
  }

  int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final s = _sessions;
    return Scaffold(
      appBar: AppBar(title: const Text('Caisses clôturées')),
      body: s == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : s.isEmpty
          ? const Center(
              child: Text(
                'Aucune caisse ces 30 derniers jours.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final c in s)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${c['caissier'] ?? 'Caissier'} · ${_date(c['ouverte_at'])}'
                          '${c['cloturee_at'] == null ? ' · ouverte' : ' → ${_date(c['cloturee_at'])}'}',
                        ),
                        subtitle: Text(
                          [
                            'Fond ${formatMontant(_n(c['fond_initial']), widget.devise)}',
                            for (final e
                                in ((c['totaux'] as Map?) ?? const {}).entries)
                              '${libellesMoyens[e.key] ?? e.key} ${formatMontant(_n(e.value), widget.devise)}',
                            if (c['cloturee_at'] != null)
                              'attendu ${formatMontant(_n(c['especes_attendues']), widget.devise)}, compté ${formatMontant(_n(c['especes_comptees']), widget.devise)}',
                          ].join(' · '),
                        ),
                        trailing: c['cloturee_at'] == null
                            ? null
                            : Text(
                                _n(c['ecart']) == 0
                                    ? 'Juste'
                                    : '${_n(c['ecart']) > 0 ? '+' : ''}${formatMontant(_n(c['ecart']), widget.devise)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _n(c['ecart']) == 0
                                      ? Kolors.kSuccess
                                      : Kolors.kRed,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
