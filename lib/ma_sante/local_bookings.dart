import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'booking.dart';

/// Stockage local des demandes de rendez-vous (Phase 1, sans compte).
class LocalBookings {
  static const String _key = 'my_bookings_v1';

  /// Demandes, les plus récentes d'abord.
  static Future<List<Booking>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    final list = raw
        .map((s) {
          try {
            return Booking.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Booking>()
        .toList();
    return list.reversed.toList();
  }

  static Future<void> add(Booking booking) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    raw.add(jsonEncode(booking.toJson()));
    await prefs.setStringList(_key, raw);
  }
}
