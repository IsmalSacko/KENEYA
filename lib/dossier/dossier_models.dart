// Dossier patient : identité médicale et consultations.

import '../labo/labo_models.dart';

/// Les constantes notées à la consultation, dans l'ordre d'affichage.
const constantesConnues = <String, (String, String)>{
  'ta_sys': ('TA systolique', 'mmHg'),
  'ta_dia': ('TA diastolique', 'mmHg'),
  'temperature': ('Température', '°C'),
  'pouls': ('Pouls', '/min'),
  'spo2': ('SpO₂', '%'),
  'poids': ('Poids', 'kg'),
  'taille': ('Taille', 'cm'),
  'glycemie': ('Glycémie', 'g/L'),
};

/// Les valeurs possibles de chaque constante (les mêmes que l'API) : au-delà,
/// c'est une faute de frappe ou une autre unité.
const bornesConstantes = <String, (num, num)>{
  'ta_sys': (40, 300),
  'ta_dia': (20, 200),
  'temperature': (30, 45),
  'pouls': (20, 250),
  'spo2': (50, 100),
  'poids': (0.3, 400),
  'taille': (20, 250),
  'glycemie': (0.1, 10),
};

const groupesSanguins = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

class Consultation {
  const Consultation({
    required this.uuid,
    required this.etablissement,
    required this.ici,
    required this.motif,
    required this.constantes,
    this.date,
    this.praticien,
    this.examen,
    this.diagnostic,
    this.cim10,
    this.conclusion,
    this.prochainRdv,
    this.modifiable = false,
  });

  final String uuid;

  /// Son auteur peut la corriger (le jour même).
  final bool modifiable;
  final String etablissement;
  final bool ici;
  final String motif;
  final Map<String, num> constantes;
  final DateTime? date;
  final String? praticien;
  final String? examen;
  final String? diagnostic;
  final String? cim10;
  final String? conclusion;
  final String? prochainRdv;

  factory Consultation.fromJson(Map<String, dynamic> j) {
    final c = j['constantes'];
    return Consultation(
      uuid: (j['uuid'] ?? '').toString(),
      etablissement: (j['etablissement'] ?? '').toString(),
      ici: j['ici'] == true,
      motif: (j['motif'] ?? '').toString(),
      constantes: {
        if (c is Map)
          for (final e in c.entries)
            if (num.tryParse(e.value.toString()) != null)
              e.key.toString(): num.parse(e.value.toString()),
      },
      date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
      praticien: _texte(j['praticien']),
      examen: _texte(j['examen']),
      diagnostic: _texte(j['diagnostic']),
      cim10: _texte(j['cim10']),
      conclusion: _texte(j['conclusion']),
      prochainRdv: _texte(j['prochain_rdv']),
      modifiable: j['modifiable'] == true,
    );
  }

  /// « TA 120/80 · T° 38.5 °C · 62 kg »
  String get constantesCourtes {
    final morceaux = <String>[];
    if (constantes['ta_sys'] != null && constantes['ta_dia'] != null) {
      morceaux.add(
        'TA ${_n(constantes['ta_sys']!)}/${_n(constantes['ta_dia']!)}',
      );
    }
    for (final e in constantesConnues.entries) {
      if (e.key.startsWith('ta_')) continue;
      final v = constantes[e.key];
      if (v != null) morceaux.add('${e.value.$1} ${_n(v)} ${e.value.$2}');
    }
    return morceaux.join(' · ');
  }
}

class DossierPatient {
  const DossierPatient({
    required this.uuid,
    required this.nom,
    required this.aUnCompte,
    required this.consultations,
    this.analyses = const [],
    this.telephone,
    this.dateNaissance,
    this.age,
    this.sexe,
    this.groupeSanguin,
    this.allergies,
    this.antecedents,
    this.traitements,
    this.accesHistorique = false,
    this.consultationsAilleurs = 0,
    this.peutDemanderAcces = false,
  });

  final String uuid;
  final String nom;
  final bool aUnCompte;
  final List<Consultation> consultations;

  /// Les demandes d'analyses ; les résultats seulement une fois validés.
  final List<DemandeLabo> analyses;
  final String? telephone;
  final String? dateNaissance;
  final int? age;
  final String? sexe;
  final String? groupeSanguin;
  final String? allergies;
  final String? antecedents;
  final String? traitements;
  final bool accesHistorique;
  final int consultationsAilleurs;
  final bool peutDemanderAcces;

  factory DossierPatient.fromJson(Map<String, dynamic> j) => DossierPatient(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    aUnCompte: j['a_un_compte'] == true,
    consultations: [
      if (j['consultations'] is List)
        for (final c in (j['consultations'] as List).whereType<Map>())
          Consultation.fromJson(Map<String, dynamic>.from(c)),
    ],
    analyses: [
      if (j['analyses'] is List)
        for (final a in (j['analyses'] as List).whereType<Map>())
          DemandeLabo.fromJson(Map<String, dynamic>.from(a)),
    ],
    telephone: _texte(j['telephone']),
    dateNaissance: _texte(j['date_naissance']),
    age: int.tryParse((j['age'] ?? '').toString()),
    sexe: _texte(j['sexe']),
    groupeSanguin: _texte(j['groupe_sanguin']),
    allergies: _texte(j['allergies']),
    antecedents: _texte(j['antecedents']),
    traitements: _texte(j['traitements']),
    accesHistorique: j['acces_historique'] == true,
    consultationsAilleurs: int.tryParse('${j['consultations_ailleurs']}') ?? 0,
    peutDemanderAcces: j['peut_demander_acces'] == true,
  );

  /// « F · 34 ans · O+ »
  String get resume => [
    if (sexe == 'F') 'Femme',
    if (sexe == 'M') 'Homme',
    if (age != null) '$age ans',
    ?groupeSanguin,
  ].join(' · ');
}

/// Les constantes prises au tri par l'infirmier, avant le médecin.
class Tri {
  const Tri({required this.constantes, this.par, this.le});

  final Map<String, num> constantes;
  final String? par;
  final DateTime? le;

  /// Même présentation que celle d'une consultation.
  String get resume => Consultation(
    uuid: '',
    etablissement: '',
    ici: true,
    motif: '',
    constantes: constantes,
  ).constantesCourtes;

  static Tri? fromJson(Object? j) {
    if (j is! Map || j['constantes'] is! Map) return null;
    final c = j['constantes'] as Map;
    return Tri(
      constantes: {
        for (final e in c.entries)
          if (num.tryParse('${e.value}') != null)
            e.key.toString(): num.parse('${e.value}'),
      },
      par: _texte(j['par']),
      le: DateTime.tryParse('${j['at']}')?.toLocal(),
    );
  }
}

/// Un établissement que le patient a autorisé à voir son historique.
class AccesAccorde {
  const AccesAccorde({
    required this.id,
    required this.etablissement,
    required this.par,
    this.expire,
  });

  final int id;
  final String etablissement;
  final String par;
  final DateTime? expire;

  factory AccesAccorde.fromJson(Map<String, dynamic> j) => AccesAccorde(
    id: int.tryParse('${j['id']}') ?? 0,
    etablissement: (j['etablissement'] ?? '').toString(),
    par: (j['par'] ?? '').toString(),
    expire: DateTime.tryParse((j['expire_at'] ?? '').toString())?.toLocal(),
  );
}

/// Une ouverture du dossier, que le patient voit.
class LectureDossier {
  const LectureDossier({
    required this.etablissement,
    required this.historique,
    this.par,
    this.le,
  });

  final String etablissement;
  final bool historique;
  final String? par;
  final DateTime? le;

  factory LectureDossier.fromJson(Map<String, dynamic> j) => LectureDossier(
    etablissement: (j['etablissement'] ?? '').toString(),
    historique: j['historique'] == true,
    par: _texte(j['par']),
    le: DateTime.tryParse((j['lu_at'] ?? '').toString())?.toLocal(),
  );
}

/// Ce que la personne voit de son propre dossier.
class MonDossier {
  const MonDossier({
    required this.dossier,
    required this.acces,
    required this.lectures,
  });

  final DossierPatient dossier;
  final List<AccesAccorde> acces;
  final List<LectureDossier> lectures;

  factory MonDossier.fromJson(Map<String, dynamic> j) => MonDossier(
    dossier: DossierPatient.fromJson(j),
    acces: [
      if (j['acces'] is List)
        for (final a in (j['acces'] as List).whereType<Map>())
          AccesAccorde.fromJson(Map<String, dynamic>.from(a)),
    ],
    lectures: [
      if (j['lectures'] is List)
        for (final l in (j['lectures'] as List).whereType<Map>())
          LectureDossier.fromJson(Map<String, dynamic>.from(l)),
    ],
  );
}

String? _texte(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';
