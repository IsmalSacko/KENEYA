import '../core/api/api_client.dart';

/// Nombre d'éléments (consultations/ventes) pour un jour donné.
class DayActivity {
  DayActivity(this.label, this.consultations, this.ventes);
  final String label; // ex: "22/07"
  int consultations;
  int ventes;
}

class TopMed {
  TopMed(this.nom, this.quantite);
  final String nom;
  int quantite;
}

/// Données agrégées pour les écrans Statistiques et Caisse du jour.
class AnalyticsData {
  AnalyticsData({
    required this.recettesParMode,
    required this.topMedicaments,
    required this.activite,
    required this.caisseJourTotal,
    required this.caisseJourParMode,
    required this.nbPaiementsJour,
  });

  final Map<String, double> recettesParMode;
  final List<TopMed> topMedicaments;
  final List<DayActivity> activite; // 7 derniers jours
  final double caisseJourTotal;
  final Map<String, double> caisseJourParMode;
  final int nbPaiementsJour;
}

class AnalyticsService {
  Future<AnalyticsData> load() async {
    final results = await Future.wait([
      _getList('/paiements'),
      _getList('/consultations'),
      _getList('/ventes-pharmacie'),
    ]);
    final paiements = results[0];
    final consultations = results[1];
    final ventes = results[2];

    // Recettes par mode (tous paiements)
    final recettesParMode = <String, double>{};
    for (final p in paiements) {
      final mode = _modeLabel(p['mode_paiement']?.toString());
      recettesParMode[mode] =
          (recettesParMode[mode] ?? 0) + _toDouble(p['montant']);
    }

    // Top médicaments (à partir des articles de ventes)
    final medMap = <String, int>{};
    for (final v in ventes) {
      final articles = v['articles'];
      if (articles is List) {
        for (final a in articles) {
          if (a is Map) {
            final med = a['medicament'];
            final nom = (med is Map ? med['nom'] : null)?.toString() ??
                'Médicament #${a['medicament_id']}';
            medMap[nom] = (medMap[nom] ?? 0) + _toInt(a['quantite']);
          }
        }
      }
    }
    final topMedicaments = medMap.entries
        .map((e) => TopMed(e.key, e.value))
        .toList()
      ..sort((a, b) => b.quantite.compareTo(a.quantite));

    // Activité 7 derniers jours
    final now = DateTime.now();
    final days = <DateTime>[
      for (int i = 6; i >= 0; i--)
        DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
    ];
    final activite = [
      for (final d in days)
        DayActivity(
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
          0,
          0,
        ),
    ];
    void bump(List<dynamic> items, bool isConsultation) {
      for (final it in items) {
        final date = _parseDate(it['created_at']?.toString());
        if (date == null) continue;
        for (var i = 0; i < days.length; i++) {
          if (_sameDay(date, days[i])) {
            if (isConsultation) {
              activite[i].consultations++;
            } else {
              activite[i].ventes++;
            }
            break;
          }
        }
      }
    }

    bump(consultations, true);
    bump(ventes, false);

    // Caisse du jour (paiements d'aujourd'hui)
    var caisseTotal = 0.0;
    final caisseParMode = <String, double>{};
    var nbJour = 0;
    for (final p in paiements) {
      final date = _parseDate(p['created_at']?.toString());
      if (date == null || !_sameDay(date, now)) continue;
      final montant = _toDouble(p['montant']);
      caisseTotal += montant;
      final mode = _modeLabel(p['mode_paiement']?.toString());
      caisseParMode[mode] = (caisseParMode[mode] ?? 0) + montant;
      nbJour++;
    }

    return AnalyticsData(
      recettesParMode: recettesParMode,
      topMedicaments: topMedicaments.take(5).toList(),
      activite: activite,
      caisseJourTotal: caisseTotal,
      caisseJourParMode: caisseParMode,
      nbPaiementsJour: nbJour,
    );
  }

  Future<List<dynamic>> _getList(String path) async {
    try {
      final res = await ApiClient.dio.get(path);
      final data = res.data;
      if (data is List) return data;
      if (data is Map && data['data'] is List) return data['data'] as List;
      return const [];
    } catch (_) {
      return const [];
    }
  }

  static String _modeLabel(String? raw) {
    switch (raw) {
      case 'espece':
        return 'Espèces';
      case 'orange':
        return 'Orange Money';
      case 'wave':
        return 'Wave';
      case 'moov':
        return 'Moov Money';
      default:
        return raw ?? 'Autre';
    }
  }

  /// Parse "dd/MM/yyyy HH:mm" (format renvoyé par l'API) ou ISO.
  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final datePart = s.split(' ').first;
    if (datePart.contains('/')) {
      final p = datePart.split('/');
      if (p.length == 3) {
        final d = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        final y = int.tryParse(p[2]);
        if (d != null && m != null && y != null) return DateTime(y, m, d);
      }
    }
    return DateTime.tryParse(s);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
