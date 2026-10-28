import '../core/api/api_client.dart';

/// Une venue du patient dans l'établissement.
class VisitePatient {
  const VisitePatient({
    required this.uuid,
    required this.statut,
    required this.services,
    required this.actes,
    required this.total,
    required this.reste,
    required this.devise,
    this.date,
    this.parcours = const [],
  });

  final String uuid;
  final String statut;
  final List<String> services;

  /// Ce qui a été facturé : « Consultation », « Paracétamol 500 mg · 2 unité(s) ».
  final List<String> actes;
  final int total;
  final int reste;
  final String devise;
  final DateTime? date;

  /// Le chemin du patient pendant la visite en cours : « Arrivé »,
  /// « Consultation », « Labo »… avec ce qui est fait.
  final List<({String libelle, bool fait})> parcours;

  bool get ouverte => statut == 'ouverte';

  /// « Consultation › Pharmacie » puis ce qui a été facturé en plus
  /// (« Paracétamol 500 mg · 2 unité(s) »), sans redire le nom du service.
  String get resume {
    final enPlus = [
      for (final a in actes.toSet())
        if (!services.contains(a)) a,
    ];
    if (services.isEmpty && enPlus.isEmpty) return 'Rien de facturé';
    return [
      if (services.isNotEmpty) services.join(' › '),
      if (enPlus.isNotEmpty) enPlus.join(', '),
    ].join('\n');
  }

  factory VisitePatient.fromJson(Map<String, dynamic> j) => VisitePatient(
    uuid: (j['uuid'] ?? '').toString(),
    statut: (j['statut'] ?? '').toString(),
    services: j['services'] is List
        ? [for (final s in j['services'] as List) s.toString()]
        : const [],
    actes: j['actes'] is List
        ? [for (final a in j['actes'] as List) a.toString()]
        : const [],
    total: int.tryParse('${j['total']}') ?? 0,
    reste: int.tryParse('${j['reste']}') ?? 0,
    devise: (j['devise'] ?? 'XOF').toString(),
    date: DateTime.tryParse('${j['ouverte_at']}')?.toLocal(),
    parcours: [
      if (j['parcours'] is List)
        for (final e in (j['parcours'] as List).whereType<Map>())
          (libelle: '${e['libelle'] ?? ''}', fait: e['etat'] == 'fait'),
    ],
  );
}

/// Un rendez-vous à venir du patient.
class RdvPatient {
  const RdvPatient({required this.uuid, this.debut, this.agenda, this.motif});

  final String uuid;
  final DateTime? debut;
  final String? agenda;
  final String? motif;

  factory RdvPatient.fromJson(Map<String, dynamic> j) => RdvPatient(
    uuid: (j['uuid'] ?? '').toString(),
    debut: DateTime.tryParse('${j['debut']}')?.toLocal(),
    agenda: _texte(j['agenda']),
    motif: _texte(j['motif']),
  );
}

/// Le patient vu de l'accueil : son identité et ses visites, rien de médical.
class Patient {
  const Patient({
    required this.uuid,
    required this.nom,
    required this.aUnCompte,
    required this.naissanceEstimee,
    this.telephone,
    this.adresse,
    this.sexe,
    this.dateNaissance,
    this.age,
    this.numero,
    this.derniereVisite,
    this.enCours = false,
    this.visites = const [],
    this.rendezVous = const [],
  });

  final String uuid;
  final String nom;
  final bool aUnCompte;
  final bool naissanceEstimee;
  final String? telephone;
  final String? adresse;
  final String? sexe;
  final String? dateNaissance;
  final int? age;

  /// Le numéro de dossier (« 000012 »).
  final String? numero;

  /// Sa dernière visite ici, et s'il est dans le centre aujourd'hui (liste).
  final DateTime? derniereVisite;
  final bool enCours;
  final List<VisitePatient> visites;
  final List<RdvPatient> rendezVous;

  /// « Homme · 34 ans · Banconi »
  String get resume => [
    if (sexe == 'F') 'Femme',
    if (sexe == 'M') 'Homme',
    if (age != null) age == 0 ? 'moins d’un an' : '$age ans',
    ?adresse,
  ].join(' · ');

  VisitePatient? get visiteDuJour {
    final v = visites.firstOrNull;
    if (v == null || !v.ouverte || v.date == null) return null;
    final n = DateTime.now();
    return v.date!.year == n.year &&
            v.date!.month == n.month &&
            v.date!.day == n.day
        ? v
        : null;
  }

  factory Patient.fromJson(Map<String, dynamic> j) => Patient(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    aUnCompte: j['a_un_compte'] == true,
    naissanceEstimee: j['naissance_estimee'] == true,
    telephone: _texte(j['telephone']),
    adresse: _texte(j['adresse']),
    sexe: _texte(j['sexe']),
    dateNaissance: _texte(j['date_naissance']),
    age: int.tryParse('${j['age']}'),
    numero: _texte(j['numero']),
    derniereVisite: DateTime.tryParse('${j['derniere_visite']}')?.toLocal(),
    enCours: j['en_cours'] == true,
    visites: [
      if (j['visites'] is List)
        for (final v in (j['visites'] as List).whereType<Map>())
          VisitePatient.fromJson(Map<String, dynamic>.from(v)),
    ],
    rendezVous: [
      if (j['rendez_vous'] is List)
        for (final r in (j['rendez_vous'] as List).whereType<Map>())
          RdvPatient.fromJson(Map<String, dynamic>.from(r)),
    ],
  );
}

/// Les patients de l'établissement (jeton du membre).
class PatientsService {
  Future<List<Patient>> rechercher(String recherche) async {
    final res = await ApiClient.dio.get(
      '/patients',
      queryParameters: {if (recherche.isNotEmpty) 'q': recherche},
    );
    final d = (res.data as Map)['data'];
    return [
      if (d is List)
        for (final m in d.whereType<Map>())
          Patient.fromJson(Map<String, dynamic>.from(m)),
    ];
  }

  /// Une page de la liste (50 par page) : les patients, et s'il y en a
  /// d'autres. [aujourdhui] : ceux qui sont dans le centre en ce moment.
  Future<(List<Patient>, bool)> page({
    String recherche = '',
    int page = 1,
    bool aujourdhui = false,
  }) async {
    final res = await ApiClient.dio.get(
      '/patients',
      queryParameters: {
        if (recherche.isNotEmpty) 'q': recherche,
        if (page > 1) 'page': page,
        if (aujourdhui) 'aujourdhui': 1,
      },
    );
    final data = res.data as Map;
    final d = data['data'];
    return (
      [
        if (d is List)
          for (final m in d.whereType<Map>())
            Patient.fromJson(Map<String, dynamic>.from(m)),
      ],
      data['page_suivante'] == true,
    );
  }

  /// Le médecin reçoit le patient sans ticket : sa visite du jour s'ouvre
  /// (ou reprend). Renvoie l'uuid de la visite.
  Future<String> ouvrirVisite(String uuid) async {
    final res = await ApiClient.dio.post(
      '/visites',
      data: {'dossier_uuid': uuid},
    );
    return '${((res.data as Map)['visite'] as Map)['uuid']}';
  }

  /// Une fiche créée par erreur, sur laquelle rien n'est rattaché.
  Future<void> supprimer(String uuid) async {
    await ApiClient.dio.delete('/patients/$uuid');
  }

  Future<Patient> fiche(String uuid) async =>
      _p((await ApiClient.dio.get('/patients/$uuid')).data);

  /// Crée le patient ; s'il est déjà connu, c'est sa fiche qui revient
  /// (`existant` vrai).
  Future<(Patient, bool)> creer(Map<String, dynamic> identite) async {
    final res = await ApiClient.dio.post('/patients', data: identite);
    return (_p(res.data), (res.data as Map)['existant'] == true);
  }

  Future<Patient> modifier(String uuid, Map<String, dynamic> identite) async =>
      _p((await ApiClient.dio.patch('/patients/$uuid', data: identite)).data);

  /// PIN oublié : un nouveau PIN, remis par l'accueil.
  Future<String> nouveauPin(String uuid) async {
    final res = await ApiClient.dio.post('/patients/$uuid/nouveau-pin');
    return '${(res.data as Map)['pin']}';
  }

  /// Le patient montre sa carte santé : la fiche rejoint son compte.
  Future<Patient> relier(String uuid, String qrCarte) async {
    final res = await ApiClient.dio.post(
      '/patients/$uuid/relier',
      data: {'qr': qrCarte},
    );
    return _p(res.data);
  }

  /// [doublon] rejoint cette fiche (visites, examens…) puis disparaît.
  Future<Patient> fusionner(String uuid, String doublon) async {
    final res = await ApiClient.dio.post(
      '/patients/$uuid/fusionner',
      data: {'doublon_uuid': doublon},
    );
    return _p(res.data);
  }

  Patient _p(Object? data) => Patient.fromJson(
    Map<String, dynamic>.from((data as Map)['patient'] as Map),
  );
}

String? _texte(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}
