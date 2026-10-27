/// Demande de rendez-vous mémorisée localement sur l'appareil (Phase 1 sans
/// compte). Le suivi serveur multi-appareils viendra avec les comptes patients.
class Booking {
  Booking({
    required this.uuid,
    required this.etablissementNom,
    required this.patientNom,
    required this.dateSouhaitee,
    required this.statut,
    required this.creeLe,
    this.motif,
  });

  final String uuid;
  final String etablissementNom;
  final String patientNom;
  final String dateSouhaitee; // ISO 8601
  final String statut;
  final String creeLe; // ISO 8601
  final String? motif;

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'etablissement_nom': etablissementNom,
    'patient_nom': patientNom,
    'date_souhaitee': dateSouhaitee,
    'statut': statut,
    'cree_le': creeLe,
    'motif': motif,
  };

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    uuid: (j['uuid'] ?? '').toString(),
    etablissementNom: (j['etablissement_nom'] ?? '').toString(),
    patientNom: (j['patient_nom'] ?? '').toString(),
    dateSouhaitee: (j['date_souhaitee'] ?? '').toString(),
    statut: (j['statut'] ?? 'demande').toString(),
    creeLe: (j['cree_le'] ?? '').toString(),
    motif: j['motif']?.toString(),
  );
}
