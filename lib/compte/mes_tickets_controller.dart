import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../file/file_models.dart';
import '../services/local_notification_service.dart';
import 'compte_api.dart';

/// Les tickets de la personne, suivis en direct tant qu'il y en a un en
/// cours : position, attente, et une notification quand c'est son tour.
class MesTicketsController extends ChangeNotifier {
  MesTicketsController({CompteApi? api}) : _api = api ?? CompteApi();

  final CompteApi _api;
  Timer? _minuteur;
  List<TicketFile> tickets = [];

  List<TicketFile> get enCours => tickets.where((t) => t.enCours).toList();

  /// Statut connu de chaque ticket, pour ne notifier qu'au changement.
  final Map<String, String> _statuts = {};

  /// Tickets déjà prévenus que leur tour approche (une seule fois).
  final Set<String> _bientot = {};

  Future<void> rafraichir() async {
    try {
      final data = await _api.mesTickets();
      final nouveaux = data.map(TicketFile.fromJson).toList();
      for (final t in nouveaux) {
        final avant = _statuts[t.uuid];
        if (avant != null && avant != t.statut && t.appele) {
          LocalNotificationService.show(
            title: 'C’est à vous ! Ticket ${t.code}',
            body: t.salle == null
                ? '${t.serviceNom}, ${t.etablissementNom}'
                : 'Allez à ${t.salle} (${t.serviceNom})',
          );
        }
        // Deux personnes avant soi : il est temps de revenir près de la salle.
        if (!t.appele &&
            t.position != null &&
            t.position! <= 2 &&
            _bientot.add(t.uuid)) {
          LocalNotificationService.show(
            title: 'Bientôt à vous — ticket ${t.code}',
            body: t.position == 0
                ? 'Vous êtes le prochain (${t.serviceNom}).'
                : '${t.position} personne(s) avant vous (${t.serviceNom}).',
          );
        }
        _statuts[t.uuid] = t.statut;
      }
      tickets = nouveaux;
      notifyListeners();
      _programmer();
    } on DioException {
      // Hors ligne ou déconnecté : on garde la dernière liste.
    }
  }

  Future<TicketFile> prendre(String serviceUuid) async {
    final data = await _api.prendreTicket(serviceUuid);
    final t = TicketFile.fromJson(
      Map<String, dynamic>.from(data['ticket'] as Map),
    );
    _statuts[t.uuid] = t.statut;
    await rafraichir();
    return t;
  }

  Future<void> annuler(TicketFile t) async {
    await _api.annulerTicket(t.uuid);
    await rafraichir();
  }

  /// Suivi toutes les 10 s tant qu'un ticket est en cours ; sinon rien.
  void _programmer() {
    _minuteur?.cancel();
    if (enCours.isEmpty) return;
    _minuteur = Timer(const Duration(seconds: 10), rafraichir);
  }

  void arreter() {
    _minuteur?.cancel();
    tickets = [];
    _statuts.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }
}
