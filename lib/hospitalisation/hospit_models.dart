// Hospitalisation : chambres, lits, séjours, plan de soins.

const voies = {
  'po': 'Orale',
  'iv': 'IV',
  'im': 'IM',
  'sc': 'SC',
  'autre': 'Autre',
};

const modesSortie = {
  'gueri': 'Guéri',
  'ameliore': 'Amélioré',
  'transfere': 'Transféré',
  'contre_avis': 'Contre avis médical',
  'evade': 'Évadé',
  'decede': 'Décédé',
};

class LitInfo {
  const LitInfo({
    required this.uuid,
    required this.numero,
    required this.actif,
    this.patient,
    this.sejourUuid,
  });

  final String uuid;
  final String numero;
  final bool actif;
  final String? patient;
  final String? sejourUuid;

  bool get libre => actif && sejourUuid == null;

  factory LitInfo.fromJson(Map<String, dynamic> j) => LitInfo(
    uuid: (j['uuid'] ?? '').toString(),
    numero: (j['numero'] ?? '').toString(),
    actif: j['actif'] != false,
    patient: _texte(j['patient']),
    sejourUuid: _texte(j['sejour_uuid']),
  );
}

class Chambre {
  const Chambre({
    required this.uuid,
    required this.nom,
    required this.lits,
    this.service,
    this.prix,
    this.actif = true,
  });

  final String uuid;
  final String nom;
  final List<LitInfo> lits;
  final String? service;
  final int? prix;

  /// Fermée, ses lits ne reçoivent plus personne.
  final bool actif;

  int get libres => lits.where((l) => l.libre).length;

  factory Chambre.fromJson(Map<String, dynamic> j) => Chambre(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    lits: [
      if (j['lits'] is List)
        for (final l in (j['lits'] as List).whereType<Map>())
          LitInfo.fromJson(Map<String, dynamic>.from(l)),
    ],
    service: _texte(j['service']),
    prix: int.tryParse('${j['prix']}'),
    actif: j['actif'] != false,
  );
}

class SoinPrescrit {
  const SoinPrescrit({
    required this.uuid,
    required this.produit,
    required this.voie,
    required this.horaires,
    required this.arrete,
    this.dose,
    this.instructions,
    this.prescripteur,
    this.fin,
  });

  final String uuid;
  final String produit;
  final String voie;
  final List<String> horaires;
  final bool arrete;
  final String? dose;
  final String? instructions;
  final String? prescripteur;

  /// Le dernier jour du traitement, s'il est fixé.
  final DateTime? fin;

  /// « Artésunate 120 mg · IV · 08:00, 20:00 »
  String get resume => [
    [produit, ?dose].join(' '),
    voies[voie] ?? voie,
    horaires.join(', '),
  ].join(' · ');

  factory SoinPrescrit.fromJson(Map<String, dynamic> j) => SoinPrescrit(
    uuid: (j['uuid'] ?? '').toString(),
    produit: (j['produit'] ?? '').toString(),
    voie: (j['voie'] ?? 'autre').toString(),
    horaires: j['horaires'] is List
        ? [for (final h in j['horaires'] as List) h.toString()]
        : const [],
    arrete: j['arrete'] == true,
    dose: _texte(j['dose']),
    instructions: _texte(j['instructions']),
    prescripteur: _texte(j['prescripteur']),
    fin: DateTime.tryParse('${j['fin']}'),
  );
}

/// Une prise du plan de soins du jour.
class Prise {
  const Prise({
    required this.soinUuid,
    required this.produit,
    required this.voie,
    required this.prevueAt,
    required this.heure,
    required this.statut,
    required this.enRetard,
    this.dose,
    this.instructions,
    this.par,
    this.commentaire,
    this.corrigee = false,
    this.corrigeable = false,
  });

  final String soinUuid;
  final String produit;
  final String voie;
  final String prevueAt;
  final String heure;
  final String statut; // a_faire, faite, refusee, omise
  final bool enRetard;
  final String? dose;
  final String? instructions;
  final String? par;
  final String? commentaire;

  /// Notée puis corrigée : l'ancienne saisie reste au dossier.
  final bool corrigee;

  /// Notée il y a peu : elle se corrige encore.
  final bool corrigeable;

  bool get aFaire => statut == 'a_faire';

  factory Prise.fromJson(Map<String, dynamic> j) => Prise(
    soinUuid: (j['soin_uuid'] ?? '').toString(),
    produit: (j['produit'] ?? '').toString(),
    voie: (j['voie'] ?? '').toString(),
    prevueAt: (j['prevue_at'] ?? '').toString(),
    heure: (j['heure'] ?? '').toString(),
    statut: (j['statut'] ?? 'a_faire').toString(),
    enRetard: j['en_retard'] == true,
    dose: _texte(j['dose']),
    instructions: _texte(j['instructions']),
    par: _texte(j['par']),
    commentaire: _texte(j['commentaire']),
    corrigee: j['corrigee'] == true,
    corrigeable: j['corrigeable'] == true,
  );
}

/// Ce que la sortie a mis sur la facture.
class FactureNuits {
  const FactureNuits({
    required this.nuits,
    required this.montant,
    required this.nouvelle,
  });

  final int nuits;
  final int montant;

  /// La visite d'admission était close : une facture du jour les porte.
  final bool nouvelle;

  factory FactureNuits.fromJson(Map<String, dynamic> j) => FactureNuits(
    nuits: int.tryParse('${j['nuits']}') ?? 1,
    montant: int.tryParse('${j['montant']}') ?? 0,
    nouvelle: j['nouvelle'] == true,
  );
}

class Sejour {
  const Sejour({
    required this.uuid,
    required this.statut,
    required this.patient,
    required this.motif,
    required this.nuits,
    required this.bracelet,
    required this.soins,
    required this.plan,
    this.dossierUuid,
    this.allergies,
    this.lit,
    this.medecin,
    this.entree,
    this.modeSortie,
    this.sortie,
    this.resumeSortie,
    this.annulable = false,
    this.enRetard = 0,
  });

  final String uuid;
  final String statut;
  final String patient;
  final String motif;
  final int nuits;
  final String bracelet;
  final List<SoinPrescrit> soins;
  final List<Prise> plan;
  final String? dossierUuid;
  final String? allergies;
  final String? lit;
  final String? medecin;
  final DateTime? entree;
  final String? modeSortie;
  final DateTime? sortie;
  final String? resumeSortie;

  /// Admis aujourd'hui : l'admission faite par erreur s'annule encore.
  final bool annulable;
  final int enRetard;

  bool get enCours => statut == 'en_cours';
  bool get annule => statut == 'annulee';

  factory Sejour.fromJson(Map<String, dynamic> j) => Sejour(
    uuid: (j['uuid'] ?? '').toString(),
    statut: (j['statut'] ?? 'en_cours').toString(),
    patient: (j['patient'] ?? '').toString(),
    motif: (j['motif'] ?? '').toString(),
    nuits: int.tryParse('${j['nuits']}') ?? 1,
    bracelet: (j['bracelet'] ?? '').toString(),
    soins: [
      if (j['soins'] is List)
        for (final s in (j['soins'] as List).whereType<Map>())
          SoinPrescrit.fromJson(Map<String, dynamic>.from(s)),
    ],
    plan: [
      if (j['plan'] is List)
        for (final p in (j['plan'] as List).whereType<Map>())
          Prise.fromJson(Map<String, dynamic>.from(p)),
    ],
    dossierUuid: _texte(j['dossier_uuid']),
    allergies: _texte(j['allergies']),
    lit: _texte(j['lit']),
    medecin: _texte(j['medecin']),
    entree: DateTime.tryParse('${j['entree_at']}')?.toLocal(),
    modeSortie: _texte(j['mode_sortie']),
    sortie: DateTime.tryParse('${j['sortie_at']}')?.toLocal(),
    resumeSortie: _texte(j['resume_sortie']),
    annulable: j['annulable'] == true,
    enRetard: int.tryParse('${j['en_retard']}') ?? 0,
  );
}

String? _texte(Object? v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}
