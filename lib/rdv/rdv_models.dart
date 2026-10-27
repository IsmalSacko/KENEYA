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
  });

  final String uuid;
  final String nom;
  final int dureeCreneau;
  final int placesParCreneau;
  final bool reservationEnLigne;
  final bool validationAuto;
  final bool actif;
  final List<HoraireRdv> horaires;
  final List<Map<String, dynamic>> absences;
  final String? serviceUuid;
  final String? serviceNom;

  factory AgendaRdv.fromJson(Map<String, dynamic> j) {
    final service = j['service'];
    return AgendaRdv(
      uuid: (j['uuid'] ?? '').toString(),
      nom: (j['nom'] ?? '').toString(),
      dureeCreneau: _int(j['duree_creneau_min']) ?? 15,
      placesParCreneau: _int(j['places_par_creneau']) ?? 1,
      reservationEnLigne: j['reservation_en_ligne'] != false,
      validationAuto: j['validation_auto'] != false,
      actif: j['actif'] != false,
      horaires: _maps(j['horaires']).map(HoraireRdv.fromJson).toList(),
      absences: _maps(j['absences']),
      serviceUuid: service is Map ? service['uuid']?.toString() : null,
      serviceNom: service is Map
          ? service['nom']?.toString()
          : (service is String ? service : null),
    );
  }
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

  bool get actif => statut == 'demande' || statut == 'confirme';

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
