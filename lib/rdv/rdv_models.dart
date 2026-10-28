// Rendez-vous : agendas, créneaux, réservations.

class AgendaRdv {
  const AgendaRdv({
    required this.uuid,
    required this.nom,
    required this.dureeCreneau,
    required this.placesParCreneau,
    required this.reservationEnLigne,
    required this.validationAuto,
    required this.actif,
    required this.horaires,
    required this.absences,
    this.serviceUuid,
    this.serviceNom,
    this.membreUuid,
    this.membreNom,
    this.delaiMinHeures = 0,
    this.horizonJours = 60,
  });

  final String uuid;
  final String nom;
  final int dureeCreneau;
  final int placesParCreneau;
  final bool reservationEnLigne;
  final bool validationAuto;
  final bool actif;
  final List<HoraireRdv> horaires;
  final List<AbsenceRdv> absences;
  final String? serviceUuid;
  final String? serviceNom;

  /// Le soignant de cet agenda (facultatif).
  final String? membreUuid;
  final String? membreNom;

  /// Réserver au plus tôt N heures avant (patients), au plus tard N jours après.
  final int delaiMinHeures;
  final int horizonJours;

  factory AgendaRdv.fromJson(Map<String, dynamic> j) {
    final service = j['service'];
    final membre = j['membre'];
    return AgendaRdv(
      uuid: (j['uuid'] ?? '').toString(),
      nom: (j['nom'] ?? '').toString(),
      dureeCreneau: _int(j['duree_creneau_min']) ?? 15,
      placesParCreneau: _int(j['places_par_creneau']) ?? 1,
      reservationEnLigne: j['reservation_en_ligne'] != false,
      validationAuto: j['validation_auto'] != false,
      actif: j['actif'] != false,
      horaires: _maps(j['horaires']).map(HoraireRdv.fromJson).toList(),
      absences: _maps(j['absences']).map(AbsenceRdv.fromJson).toList(),
      serviceUuid: service is Map ? service['uuid']?.toString() : null,
      serviceNom: service is Map
          ? service['nom']?.toString()
          : (service is String ? service : null),
      membreUuid: membre is Map ? membre['uuid']?.toString() : null,
      membreNom: membre is Map ? membre['nom']?.toString() : null,
      delaiMinHeures: _int(j['delai_min_heures']) ?? 0,
      horizonJours: _int(j['horizon_jours']) ?? 60,
    );
  }
}

/// Une absence de l'agenda (congé, formation) : pas de rendez-vous ces jours-là.
class AbsenceRdv {
  const AbsenceRdv({
    required this.id,
    required this.du,
    required this.au,
    this.motif,
  });

  final int id;
  final DateTime du;
  final DateTime au;
  final String? motif;

  /// Pas encore terminée : on la montre.
  bool get aVenir {
    final n = DateTime.now();
    return !au.isBefore(DateTime(n.year, n.month, n.day));
  }

  factory AbsenceRdv.fromJson(Map<String, dynamic> j) => AbsenceRdv(
    id: _int(j['id']) ?? 0,
    du: DateTime.tryParse('${j['du']}'.split('T').first) ?? DateTime.now(),
    au: DateTime.tryParse('${j['au']}'.split('T').first) ?? DateTime.now(),
    motif: (j['motif']?.toString().trim().isEmpty ?? true)
        ? null
        : j['motif'].toString(),
  );
}

/// Une plage d'ouverture : jour 1 (lundi) à 7 (dimanche), « 08:00 »-« 12:30 ».
class HoraireRdv {
  const HoraireRdv(this.jour, this.debut, this.fin);

  final int jour;
  final String debut;
  final String fin;

  factory HoraireRdv.fromJson(Map<String, dynamic> j) => HoraireRdv(
    _int(j['jour']) ?? 1,
    (j['debut'] ?? '08:00').toString(),
    (j['fin'] ?? '12:00').toString(),
  );

  Map<String, dynamic> toJson() => {'jour': jour, 'debut': debut, 'fin': fin};
}

const List<String> joursSemaine = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

class CreneauRdv {
  const CreneauRdv({
    required this.debut,
    required this.heure,
    required this.jour,
    required this.places,
  });

  /// ISO 8601 (UTC), tel que l'API l'attend pour réserver.
  final String debut;

  /// Heure locale de l'établissement : « 09:30 ».
  final String heure;
  final String jour;
  final int places;

  factory CreneauRdv.fromJson(Map<String, dynamic> j) => CreneauRdv(
    debut: (j['debut'] ?? '').toString(),
    heure: (j['heure'] ?? '').toString(),
    jour: (j['jour'] ?? '').toString(),
    places: _int(j['places']) ?? 1,
  );
}

class RendezVousRdv {
  const RendezVousRdv({
    required this.uuid,
    required this.statut,
    required this.statutLabel,
    required this.jour,
    required this.heure,
    required this.etablissementUuid,
    required this.etablissementNom,
    required this.qr,
    this.agendaNom,
    this.motif,
    this.patientNom,
    this.patientTelephone,
    this.arrive = false,
    this.creneau = true,
    this.agendaUuid,
    this.dossierUuid,
  });

  final String uuid;
  final String statut;
  final String statutLabel;
  final String jour;
  final String heure;
  final String etablissementUuid;
  final String etablissementNom;
  final String qr;
  final String? agendaNom;
  final String? motif;
  final String? patientNom;
  final String? patientTelephone;
  final bool arrive;

  /// Faux pour une demande venue sans heure (seulement un jour souhaité).
  final bool creneau;
  final String? agendaUuid;

  /// La fiche du patient, pour l'ouvrir depuis la liste.
  final String? dossierUuid;

  bool get actif => statut == 'demande' || statut == 'confirme';

  /// Le rendez-vous est aujourd'hui : on peut noter l'arrivée.
  bool get aujourdhui {
    final n = DateTime.now();
    final d = DateTime.tryParse(jour);
    return d != null &&
        d.year == n.year &&
        d.month == n.month &&
        d.day == n.day;
  }

  /// L'étiquette courte de la liste : « À confirmer », « Confirmé »…
  String get statutCourt => switch (statut) {
    'demande' => 'À confirmer',
    'confirme' => 'Confirmé',
    'refuse' => 'Refusé',
    'annule' => 'Annulé',
    'honore' => 'Venu',
    'absent' => 'Absent',
    _ => statutLabel,
  };

  DateTime? get date => DateTime.tryParse('${jour}T$heure');

  factory RendezVousRdv.fromJson(Map<String, dynamic> j) {
    final agenda = j['agenda'];
    final etab = j['etablissement'];
    return RendezVousRdv(
      uuid: (j['uuid'] ?? '').toString(),
      statut: (j['statut'] ?? '').toString(),
      statutLabel: (j['statut_label'] ?? '').toString(),
      jour: (j['jour'] ?? '').toString(),
      heure: (j['heure'] ?? '').toString(),
      etablissementUuid: etab is Map ? (etab['uuid'] ?? '').toString() : '',
      etablissementNom: etab is Map ? (etab['nom'] ?? '').toString() : '',
      qr: (j['qr'] ?? '').toString(),
      agendaNom: agenda is Map ? agenda['nom']?.toString() : null,
      agendaUuid: agenda is Map ? agenda['uuid']?.toString() : null,
      creneau: j['creneau'] != false,
      dossierUuid: j['dossier_uuid']?.toString(),
      motif: j['motif']?.toString(),
      patientNom: j['patient_nom']?.toString(),
      patientTelephone: j['patient_telephone']?.toString(),
      arrive: j['arrivee_at'] != null,
    );
  }
}

int? _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const <Map<String, dynamic>>[];
