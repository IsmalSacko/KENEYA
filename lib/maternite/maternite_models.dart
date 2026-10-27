// Maternité : grossesse, CPN, accouchement, carnet de vaccination.

import '../dossier/dossier_models.dart';

const modesAccouchement = {
  'voie_basse': 'Voie basse',
  'ventouse': 'Ventouse',
  'cesarienne': 'Césarienne',
};

const presentations = {
  'cephalique': 'Céphalique',
  'siege': 'Siège',
  'transverse': 'Transverse',
};

class CpnVisite {
  const CpnVisite({
    required this.numero,
    required this.semaines,
    required this.etablissement,
    required this.fer,
    required this.moustiquaire,
    this.date,
    this.praticien,
    this.poids,
    this.taSys,
    this.taDia,
    this.hauteurUterine,
    this.bcf,
    this.presentation,
    this.tpi,
    this.vat,
    this.observations,
    this.prochainRdv,
  });

  final int numero;
  final int semaines;
  final String etablissement;
  final bool fer;
  final bool moustiquaire;
  final DateTime? date;
  final String? praticien;
  final double? poids;
  final int? taSys;
  final int? taDia;
  final int? hauteurUterine;
  final int? bcf;
  final String? presentation;
  final int? tpi;
  final int? vat;
  final String? observations;
  final String? prochainRdv;

  factory CpnVisite.fromJson(Map<String, dynamic> j) => CpnVisite(
    numero: _int(j['numero']) ?? 0,
    semaines: _int(j['semaines']) ?? 0,
    etablissement: (j['etablissement'] ?? '').toString(),
    fer: j['fer'] == true,
    moustiquaire: j['moustiquaire'] == true,
    date: DateTime.tryParse('${j['date']}')?.toLocal(),
    praticien: _texte(j['praticien']),
    poids: double.tryParse('${j['poids']}'),
    taSys: _int(j['ta_sys']),
    taDia: _int(j['ta_dia']),
    hauteurUterine: _int(j['hauteur_uterine']),
    bcf: _int(j['bcf']),
    presentation: _texte(j['presentation']),
    tpi: _int(j['tpi']),
    vat: _int(j['vat']),
    observations: _texte(j['observations']),
    prochainRdv: _texte(j['prochain_rdv']),
  );

  /// « 62 kg · TA 110/70 · HU 22 cm · BCF 140 · TPI 1 · VAT 1 · fer »
  String get resume => [
    if (poids != null) '${_n(poids!)} kg',
    if (taSys != null && taDia != null) 'TA $taSys/$taDia',
    if (hauteurUterine != null) 'HU $hauteurUterine cm',
    if (bcf != null) 'BCF $bcf',
    if (presentation != null) presentations[presentation] ?? presentation!,
    if (tpi != null) 'TPI $tpi',
    if (vat != null) 'VAT $vat',
    if (fer) 'fer',
    if (moustiquaire) 'moustiquaire',
  ].join(' · ');
}

class EnfantNe {
  const EnfantNe({
    required this.sexe,
    required this.vivant,
    this.poidsG,
    this.apgar1,
    this.apgar5,
    this.dossierUuid,
    this.nom,
  });

  final String sexe;
  final bool vivant;
  final int? poidsG;
  final int? apgar1;
  final int? apgar5;
  final String? dossierUuid;
  final String? nom;

  factory EnfantNe.fromJson(Map<String, dynamic> j) => EnfantNe(
    sexe: (j['sexe'] ?? '').toString(),
    vivant: j['vivant'] != false,
    poidsG: _int(j['poids_g']),
    apgar1: _int(j['apgar1']),
    apgar5: _int(j['apgar5']),
    dossierUuid: _texte(j['dossier_uuid']),
    nom: _texte(j['nom']),
  );
}

class Grossesse {
  const Grossesse({
    required this.uuid,
    required this.statut,
    required this.patiente,
    required this.ddr,
    required this.dpa,
    required this.cpn,
    this.dossierUuid,
    this.semaines,
    this.gestite,
    this.parite,
    this.risques,
    this.prochainRdv,
    this.accouchement,
    this.modeAccouchement,
    this.enfants = const [],
  });

  final String uuid;
  final String statut;
  final String patiente;
  final String ddr;
  final String dpa;
  final List<CpnVisite> cpn;
  final String? dossierUuid;
  final int? semaines;
  final int? gestite;
  final int? parite;
  final String? risques;
  final String? prochainRdv;
  final DateTime? accouchement;
  final String? modeAccouchement;
  final List<EnfantNe> enfants;

  bool get enCours => statut == 'en_cours';

  /// « G3 P2 »
  String get gp => [
    if (gestite != null) 'G$gestite',
    if (parite != null) 'P$parite',
  ].join(' ');

  factory Grossesse.fromJson(Map<String, dynamic> j) {
    final a = j['accouchement'];
    final acc = a is Map ? Map<String, dynamic>.from(a) : null;
    return Grossesse(
      uuid: (j['uuid'] ?? '').toString(),
      statut: (j['statut'] ?? 'en_cours').toString(),
      patiente: (j['patiente'] ?? '').toString(),
      ddr: (j['ddr'] ?? '').toString(),
      dpa: (j['dpa'] ?? '').toString(),
      cpn: [
        if (j['cpn'] is List)
          for (final c in (j['cpn'] as List).whereType<Map>())
            CpnVisite.fromJson(Map<String, dynamic>.from(c)),
      ],
      dossierUuid: _texte(j['dossier_uuid']),
      semaines: _int(j['semaines']),
      gestite: _int(j['gestite']),
      parite: _int(j['parite']),
      risques: _texte(j['risques']),
      prochainRdv: _texte(j['prochain_rdv']),
      accouchement: DateTime.tryParse('${acc?['date_heure']}')?.toLocal(),
      modeAccouchement: _texte(acc?['mode']),
      enfants: [
        if (acc?['enfants'] is List)
          for (final e in (acc!['enfants'] as List).whereType<Map>())
            EnfantNe.fromJson(Map<String, dynamic>.from(e)),
      ],
    );
  }
}

class VaccinCarnet {
  const VaccinCarnet({
    required this.code,
    required this.nom,
    required this.enRetard,
    this.prevuLe,
    this.faitLe,
    this.lieu,
  });

  final String code;
  final String nom;
  final bool enRetard;
  final String? prevuLe;
  final String? faitLe;
  final String? lieu;

  bool get fait => faitLe != null;

  factory VaccinCarnet.fromJson(Map<String, dynamic> j) => VaccinCarnet(
    code: (j['code'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    enRetard: j['en_retard'] == true,
    prevuLe: _texte(j['prevu_le']),
    faitLe: _texte(j['fait_le']),
    lieu: _texte(j['lieu']),
  );
}

/// Un enfant et son carnet.
class CarnetEnfant {
  const CarnetEnfant({required this.enfant, required this.vaccins});

  final DossierPatient enfant;
  final List<VaccinCarnet> vaccins;

  int get enRetard => vaccins.where((v) => v.enRetard).length;

  factory CarnetEnfant.fromJson(Map<String, dynamic> j) => CarnetEnfant(
    enfant: DossierPatient.fromJson(j),
    vaccins: [
      if (j['carnet'] is List)
        for (final v in (j['carnet'] as List).whereType<Map>())
          VaccinCarnet.fromJson(Map<String, dynamic>.from(v)),
    ],
  );
}

String? _texte(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}

int? _int(Object? v) => v is int ? v : int.tryParse('$v');

String _n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
