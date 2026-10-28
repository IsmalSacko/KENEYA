// Laboratoire : catalogue, demandes et résultats.

const categoriesLabo = {
  'parasitologie': 'Parasitologie',
  'hematologie': 'Hématologie',
  'biochimie': 'Biochimie',
  'immuno_hematologie': 'Immuno-hématologie',
  'serologie': 'Sérologie',
  'urines': 'Urines',
  'bacteriologie': 'Bactériologie',
  'autre': 'Autres',
};

const statutsLabo = {
  'demandee': 'À prélever',
  'prelevee': 'Prélevée',
  'validee': 'Validée',
  'annulee': 'Annulée',
};

class AnalyseLabo {
  const AnalyseLabo({
    required this.uuid,
    required this.code,
    required this.nom,
    required this.categorie,
    required this.typeResultat,
    required this.choix,
    required this.actif,
    this.unite,
    this.normaleMin,
    this.normaleMax,
    this.normale,
    this.choixNormal,
    this.prix,
  });

  final String uuid;
  final String code;
  final String nom;
  final String categorie;
  final String typeResultat;
  final List<String> choix;
  final bool actif;
  final String? unite;
  final double? normaleMin;
  final double? normaleMax;
  final String? normale;
  final String? choixNormal;
  final int? prix;

  String get categorieLabel => categoriesLabo[categorie] ?? categorie;

  factory AnalyseLabo.fromJson(Map<String, dynamic> j) => AnalyseLabo(
    uuid: (j['uuid'] ?? '').toString(),
    code: (j['code'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    categorie: (j['categorie'] ?? 'autre').toString(),
    typeResultat: (j['type_resultat'] ?? 'texte').toString(),
    choix: _textes(j['choix']),
    actif: j['actif'] != false,
    unite: _texte(j['unite']),
    normaleMin: double.tryParse('${j['normale_min']}'),
    normaleMax: double.tryParse('${j['normale_max']}'),
    normale: _texte(j['normale']),
    choixNormal: _texte(j['choix_normal']),
    prix: int.tryParse('${j['prix']}'),
  );
}

/// Un résultat validé puis corrigé : l'ancien reste écrit.
class CorrectionLabo {
  const CorrectionLabo({required this.motif, this.ancien, this.par, this.le});

  final String motif;
  final String? ancien;
  final String? par;
  final DateTime? le;

  factory CorrectionLabo.fromJson(Map<String, dynamic> j) => CorrectionLabo(
    motif: (j['motif'] ?? '').toString(),
    ancien: _texte(j['ancien']),
    par: _texte(j['par']),
    le: DateTime.tryParse('${j['le']}')?.toLocal(),
  );
}

class LigneLabo {
  const LigneLabo({
    required this.uuid,
    required this.nom,
    required this.typeResultat,
    required this.choix,
    this.unite,
    this.normale,
    this.resultat,
    this.anormal,
    this.commentaire,
    this.corrections = const [],
  });

  final String uuid;
  final String nom;
  final String typeResultat;
  final List<String> choix;
  final String? unite;
  final String? normale;
  final String? resultat;
  final bool? anormal;
  final String? commentaire;
  final List<CorrectionLabo> corrections;

  factory LigneLabo.fromJson(Map<String, dynamic> j) => LigneLabo(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    typeResultat: (j['type_resultat'] ?? 'texte').toString(),
    choix: _textes(j['choix']),
    unite: _texte(j['unite']),
    normale: _texte(j['normale']),
    resultat: _texte(j['resultat']),
    anormal: j['anormal'] is bool ? j['anormal'] as bool : null,
    commentaire: _texte(j['commentaire']),
    corrections: [
      if (j['corrections'] is List)
        for (final c in (j['corrections'] as List).whereType<Map>())
          CorrectionLabo.fromJson(Map<String, dynamic>.from(c)),
    ],
  );

  /// « 0,95 g/L »
  String? get resultatAffiche => resultat == null
      ? null
      : unite == null || typeResultat != 'nombre'
      ? resultat
      : '$resultat $unite';
}

class DemandeLabo {
  const DemandeLabo({
    required this.uuid,
    required this.statut,
    required this.urgent,
    required this.patient,
    required this.etablissement,
    required this.lignes,
    this.dossierUuid,
    this.telephone,
    this.qr,
    this.date,
    this.prescripteur,
    this.validePar,
    this.renseignements,
    this.motifAnnulation,
    this.rejetMotif,
  });

  final String uuid;
  final String statut;
  final bool urgent;
  final String patient;
  final String etablissement;
  final List<LigneLabo> lignes;
  final String? dossierUuid;
  final String? telephone;
  final String? qr;
  final DateTime? date;
  final String? prescripteur;
  final String? validePar;
  final String? renseignements;
  final String? motifAnnulation;

  /// L'échantillon a été rejeté : à prélever de nouveau.
  final String? rejetMotif;

  String get statutLabel => statutsLabo[statut] ?? statut;
  bool get validee => statut == 'validee';
  bool get modifiable => statut == 'demandee' || statut == 'prelevee';
  bool get toutSaisi => lignes.every((l) => l.resultat != null);
  int get anormaux => lignes.where((l) => l.anormal == true).length;

  factory DemandeLabo.fromJson(Map<String, dynamic> j) => DemandeLabo(
    uuid: (j['uuid'] ?? '').toString(),
    statut: (j['statut'] ?? 'demandee').toString(),
    urgent: j['urgent'] == true,
    patient: (j['patient'] ?? '').toString(),
    etablissement: (j['etablissement'] ?? '').toString(),
    lignes: [
      if (j['lignes'] is List)
        for (final l in (j['lignes'] as List).whereType<Map>())
          LigneLabo.fromJson(Map<String, dynamic>.from(l)),
    ],
    dossierUuid: _texte(j['dossier_uuid']),
    telephone: _texte(j['telephone']),
    qr: _texte(j['qr']),
    date: DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
    prescripteur: _texte(j['prescripteur']),
    validePar: _texte(j['valide_par']),
    renseignements: _texte(j['renseignements']),
    motifAnnulation: _texte(j['motif_annulation']),
    rejetMotif: _texte(j['rejet_motif']),
  );
}

String? _texte(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

List<String> _textes(Object? v) =>
    v is List ? [for (final x in v) x.toString()] : const [];
