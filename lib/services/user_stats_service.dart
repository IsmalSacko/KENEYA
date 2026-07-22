import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/offline/local_store.dart';

/// Point mensuel d'inscriptions.
class MonthPoint {
  MonthPoint(this.mois, this.label, this.total);
  final String mois; // "2026-07"
  final String label; // "07/2026"
  final int total;
}

/// Statistiques utilisateurs (tableau de bord admin).
class UserStats {
  UserStats({
    required this.total,
    required this.actifs,
    required this.inactifs,
    required this.tauxActivite,
    required this.parRole,
    required this.nouveauxCeMois,
    required this.nouveauxMoisPrecedent,
    required this.variationPct,
    required this.parMois,
  });

  final int total;
  final int actifs;
  final int inactifs;
  final double tauxActivite;
  final Map<String, int> parRole;
  final int nouveauxCeMois;
  final int nouveauxMoisPrecedent;
  final double variationPct;
  final List<MonthPoint> parMois;

  factory UserStats.fromJson(Map<String, dynamic> j) {
    final roles = <String, int>{};
    final rawRoles = j['par_role'];
    if (rawRoles is Map) {
      rawRoles.forEach((k, v) => roles[k.toString()] = _toInt(v));
    }

    final mois = <MonthPoint>[];
    final rawMois = j['inscriptions_par_mois'];
    if (rawMois is List) {
      for (final m in rawMois) {
        if (m is Map) {
          mois.add(MonthPoint(
            (m['mois'] ?? '').toString(),
            (m['label'] ?? '').toString(),
            _toInt(m['total']),
          ));
        }
      }
    }

    return UserStats(
      total: _toInt(j['total']),
      actifs: _toInt(j['actifs']),
      inactifs: _toInt(j['inactifs']),
      tauxActivite: _toDouble(j['taux_activite']),
      parRole: roles,
      nouveauxCeMois: _toInt(j['nouveaux_ce_mois']),
      nouveauxMoisPrecedent: _toInt(j['nouveaux_mois_precedent']),
      variationPct: _toDouble(j['variation_pct']),
      parMois: mois,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class UserStatsService {
  static const String _cacheKey = 'cache_user_stats';

  Future<UserStats> load() async {
    try {
      final res = await ApiClient.dio.get('/stats/users');
      final data = Map<String, dynamic>.from(res.data as Map);
      await LocalStore.write(_cacheKey, data);
      return UserStats.fromJson(data);
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      final cached = LocalStore.read<Map<String, dynamic>>(_cacheKey);
      if (cached != null) return UserStats.fromJson(cached);
      rethrow;
    }
  }
}
