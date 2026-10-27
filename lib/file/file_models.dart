// File d'attente : services, salles, tickets, état des écrans.

class SalleFile {
  const SalleFile({required this.uuid, required this.nom, required this.actif});

  final String uuid;
  final String nom;
  final bool actif;

  factory SalleFile.fromJson(Map<String, dynamic> j) => SalleFile(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    actif: j['actif'] != false,
  );
}

class ServiceFile {
  const ServiceFile({
    required this.uuid,
    required this.nom,
    required this.prefixe,
    required this.actif,
    required this.ticketDistance,
    required this.dureeMoyenne,
    required this.enAttente,
    required this.salles,
    this.tarifUuid,
  });

  final String uuid;
  final String nom;
  final String prefixe;

  /// L'acte facturé à chaque ticket de ce service (ex. la consultation).
  final String? tarifUuid;
  final bool actif;
  final bool ticketDistance;
  final int dureeMoyenne;
  final int enAttente;
  final List<SalleFile> salles;

  factory ServiceFile.fromJson(Map<String, dynamic> j) => ServiceFile(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    prefixe: (j['prefixe'] ?? '').toString(),
    actif: j['actif'] != false,
    ticketDistance: j['ticket_distance'] != false,
    dureeMoyenne: _int(j['duree_moyenne_min']) ?? 10,
    enAttente: _int(j['en_attente']) ?? 0,
    salles: _maps(j['points']).map(SalleFile.fromJson).toList(),
    tarifUuid: j['tarif_uuid']?.toString(),
  );
}

/// Les priorités, de la plus urgente à la plus ordinaire.
const Map<String, String> libellesPriorite = {
  'urgence': 'Urgence',
  'rdv': 'Rendez-vous',
  'prioritaire': 'Prioritaire',
  'ordinaire': 'Ordinaire',
};

class TicketFile {
  const TicketFile({
    required this.uuid,
    required this.code,
    required this.priorite,
    required this.statut,
    required this.statutLabel,
    required this.serviceUuid,
    required this.serviceNom,
    required this.etablissementNom,
    required this.salle,
    required this.position,
    required this.attenteMin,
    required this.suiviUrl,
    required this.emisAt,
    this.nom,
    this.telephone,
    this.appels = 0,
    this.visiteUuid,
  });

  final String uuid;
  final String code;
  final String priorite;
  final String statut;
  final String statutLabel;
  final String serviceUuid;
  final String serviceNom;
  final String etablissementNom;
  final String? salle;
  final int? position;
  final int? attenteMin;
  final String suiviUrl;
  final DateTime? emisAt;
  final String? nom;
  final String? telephone;
  final int appels;

  /// La visite (facture unique) de ce passage.
  final String? visiteUuid;

  bool get enAttente => statut == 'emis';
  bool get appele => statut == 'appele';
  bool get enService => statut == 'en_service';
  bool get absent => statut == 'absent';
  bool get enCours => enAttente || appele || enService || absent;
  bool get prioritaire => priorite != 'ordinaire';

  String get prioriteLabel => libellesPriorite[priorite] ?? priorite;

  factory TicketFile.fromJson(Map<String, dynamic> j) {
    final service = _map(j['service']);
    final etab = _map(j['etablissement']);
    return TicketFile(
      uuid: (j['uuid'] ?? '').toString(),
      code: (j['code'] ?? '').toString(),
      priorite: (j['priorite'] ?? 'ordinaire').toString(),
      statut: (j['statut'] ?? 'emis').toString(),
      statutLabel: (j['statut_label'] ?? '').toString(),
      serviceUuid: (service['uuid'] ?? '').toString(),
      serviceNom: (service['nom'] ?? '').toString(),
      etablissementNom: (etab['nom'] ?? '').toString(),
      salle: j['point']?.toString(),
      position: _int(j['position']),
      attenteMin: _int(j['attente_min']),
      suiviUrl: (j['suivi_url'] ?? '').toString(),
      emisAt: DateTime.tryParse((j['emis_at'] ?? '').toString())?.toLocal(),
      nom: j['nom']?.toString(),
      telephone: j['telephone']?.toString(),
      appels: _int(j['appels']) ?? 0,
      visiteUuid: j['visite_uuid']?.toString(),
    );
  }
}

/// Un appel affiché sur l'écran de la salle : « A012 → Salle 2 ».
class AppelEcran {
  const AppelEcran({
    required this.uuid,
    required this.code,
    required this.service,
    required this.salle,
    required this.appeleAt,
    required this.appels,
  });

  final String uuid;
  final String code;
  final String service;
  final String? salle;
  final String appeleAt;
  final int appels;

  /// Identité de l'appel : un rappel du même ticket compte comme un nouvel
  /// appel (et se réannonce).
  String get cle => '$uuid#$appels';

  factory AppelEcran.fromJson(Map<String, dynamic> j) => AppelEcran(
    uuid: (j['uuid'] ?? '').toString(),
    code: (j['code'] ?? '').toString(),
    service: (j['service'] ?? '').toString(),
    salle: j['point']?.toString(),
    appeleAt: (j['appele_at'] ?? '').toString(),
    appels: _int(j['appels']) ?? 1,
  );
}

class ServiceEcran {
  const ServiceEcran({
    required this.uuid,
    required this.nom,
    required this.prefixe,
    required this.enAttente,
    required this.appeles,
  });

  final String uuid;
  final String nom;
  final String prefixe;
  final int enAttente;
  final List<AppelEcran> appeles;

  factory ServiceEcran.fromJson(Map<String, dynamic> j) => ServiceEcran(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    prefixe: (j['prefixe'] ?? '').toString(),
    enAttente: _int(j['en_attente']) ?? 0,
    appeles: _maps(j['appeles']).map(AppelEcran.fromJson).toList(),
  );
}

/// Ce que montre l'écran de la salle d'attente.
class EtatFile {
  const EtatFile({
    required this.etablissementNom,
    required this.services,
    required this.derniersAppels,
  });

  final String etablissementNom;
  final List<ServiceEcran> services;
  final List<AppelEcran> derniersAppels;

  factory EtatFile.fromJson(Map<String, dynamic> j) => EtatFile(
    etablissementNom: (_map(j['etablissement'])['nom'] ?? '').toString(),
    services: _maps(j['services']).map(ServiceEcran.fromJson).toList(),
    derniersAppels: _maps(
      j['derniers_appels'],
    ).map(AppelEcran.fromJson).toList(),
  );
}

int? _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const <Map<String, dynamic>>[];
