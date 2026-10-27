// Le compte Ngoni Santé : une personne (un numéro), et ses espaces pro.

/// Un pays où l'app fonctionne. La liste vient du serveur (`GET /pays`) ;
/// [secours] sert au premier lancement hors ligne.
class Pays {
  const Pays({
    required this.code,
    required this.nom,
    required this.drapeau,
    required this.indicatif,
    required this.devise,
  });

  final String code;
  final String nom;
  final String drapeau;
  final String indicatif;
  final String devise;

  factory Pays.fromJson(Map<String, dynamic> j) => Pays(
    code: (j['code'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    drapeau: (j['drapeau'] ?? '').toString(),
    indicatif: (j['indicatif'] ?? '').toString(),
    devise: (j['devise'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'nom': nom,
    'drapeau': drapeau,
    'indicatif': indicatif,
    'devise': devise,
  };

  String get libelle => '$drapeau $nom (+$indicatif)';

  /// Le Mali par défaut, comme Ngoni Caisse.
  static const String defaut = 'ML';

  static const List<Pays> secours = [
    Pays(
      code: 'ML',
      nom: 'Mali',
      drapeau: '🇲🇱',
      indicatif: '223',
      devise: 'XOF',
    ),
    Pays(
      code: 'SN',
      nom: 'Sénégal',
      drapeau: '🇸🇳',
      indicatif: '221',
      devise: 'XOF',
    ),
    Pays(
      code: 'CI',
      nom: 'Côte d’Ivoire',
      drapeau: '🇨🇮',
      indicatif: '225',
      devise: 'XOF',
    ),
    Pays(
      code: 'BF',
      nom: 'Burkina Faso',
      drapeau: '🇧🇫',
      indicatif: '226',
      devise: 'XOF',
    ),
    Pays(
      code: 'GN',
      nom: 'Guinée',
      drapeau: '🇬🇳',
      indicatif: '224',
      devise: 'GNF',
    ),
  ];
}

/// Profil d'établissement (son métier) et les modules qu'il active.
class ProfilEtablissement {
  const ProfilEtablissement({
    required this.code,
    required this.label,
    required this.description,
    required this.modules,
  });

  final String code;
  final String label;
  final String description;
  final List<String> modules;

  factory ProfilEtablissement.fromJson(Map<String, dynamic> j) =>
      ProfilEtablissement(
        code: (j['code'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        modules: _strings(j['modules']),
      );

  Map<String, dynamic> toJson() => {
    'code': code,
    'label': label,
    'description': description,
    'modules': modules,
  };

  /// Liste de secours, hors ligne au premier lancement.
  static const List<ProfilEtablissement> secours = [
    ProfilEtablissement(
      code: 'cabinet_medical',
      label: 'Cabinet médical',
      description: 'Consultations, rendez-vous et file d’attente.',
      modules: ['file', 'rdv', 'consultation', 'caisse'],
    ),
    ProfilEtablissement(
      code: 'centre_sante',
      label: 'Centre de santé',
      description: 'CSCom, CSRéf : consultation, pharmacie, labo, maternité.',
      modules: [
        'file',
        'rdv',
        'consultation',
        'caisse',
        'pharmacie',
        'labo',
        'maternite',
      ],
    ),
    ProfilEtablissement(
      code: 'clinique',
      label: 'Clinique / hôpital',
      description: 'Plusieurs services, hospitalisation, badges.',
      modules: [
        'file',
        'rdv',
        'consultation',
        'caisse',
        'pharmacie',
        'labo',
        'maternite',
        'hospitalisation',
        'badges',
        'assurances',
      ],
    ),
    ProfilEtablissement(
      code: 'pharmacie',
      label: 'Pharmacie',
      description: 'Ordonnances, lots et péremption, grossistes.',
      modules: ['file', 'caisse', 'pharmacie'],
    ),
    ProfilEtablissement(
      code: 'depot_medicaments',
      label: 'Dépôt de médicaments',
      description: 'Vente de médicaments, stock et caisse.',
      modules: ['caisse', 'pharmacie'],
    ),
    ProfilEtablissement(
      code: 'laboratoire',
      label: 'Laboratoire',
      description: 'Demandes d’examens, résultats, rendez-vous.',
      modules: ['file', 'rdv', 'labo', 'caisse'],
    ),
    ProfilEtablissement(
      code: 'maternite',
      label: 'Maternité',
      description: 'Suivi de grossesse, accouchement, vaccination.',
      modules: ['file', 'rdv', 'maternite', 'consultation', 'caisse'],
    ),
    ProfilEtablissement(
      code: 'cabinet_dentaire',
      label: 'Cabinet dentaire',
      description: 'Soins dentaires, rendez-vous et file d’attente.',
      modules: ['file', 'rdv', 'consultation', 'caisse'],
    ),
  ];

  static String labelDe(String? code) =>
      secours.where((p) => p.code == code).firstOrNull?.label ?? (code ?? '');
}

/// La personne connectée (espace « Ma santé »).
class Personne {
  const Personne({
    required this.uuid,
    required this.nom,
    required this.paysCode,
    required this.telephone,
  });

  final String uuid;
  final String nom;
  final String paysCode;

  /// Format international : +22376123456.
  final String telephone;

  String get prenom => prenomDe(nom);

  factory Personne.fromJson(Map<String, dynamic> j) => Personne(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    paysCode: (j['pays_code'] ?? Pays.defaut).toString(),
    telephone: (j['telephone'] ?? '').toString(),
  );

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'nom': nom,
    'pays_code': paysCode,
    'telephone': telephone,
  };
}

/// Un espace pro : la personne, membre d'un établissement, avec un rôle.
class Espace {
  const Espace({
    required this.membreUuid,
    required this.role,
    required this.roleLabel,
    required this.actif,
    required this.etablissementUuid,
    required this.etablissementNom,
    required this.profil,
    required this.modules,
    required this.devise,
  });

  final String membreUuid;
  final String role;
  final String roleLabel;
  final bool actif;
  final String etablissementUuid;
  final String etablissementNom;
  final String profil;
  final List<String> modules;
  final String devise;

  String get profilLabel => ProfilEtablissement.labelDe(profil);

  factory Espace.fromJson(Map<String, dynamic> j) {
    final e = j['etablissement'] is Map
        ? Map<String, dynamic>.from(j['etablissement'] as Map)
        : const <String, dynamic>{};
    return Espace(
      membreUuid: (j['membre_uuid'] ?? '').toString(),
      role: (j['role'] ?? '').toString(),
      roleLabel: (j['role_label'] ?? j['role'] ?? '').toString(),
      actif: j['actif'] == true || j['actif'] == 1,
      etablissementUuid: (e['uuid'] ?? '').toString(),
      etablissementNom: (e['nom'] ?? '').toString(),
      profil: (e['profil'] ?? '').toString(),
      modules: _strings(e['modules']),
      devise: (e['devise'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'membre_uuid': membreUuid,
    'role': role,
    'role_label': roleLabel,
    'actif': actif,
    'etablissement': {
      'uuid': etablissementUuid,
      'nom': etablissementNom,
      'profil': profil,
      'modules': modules,
      'devise': devise,
    },
  };
}

/// Le premier mot du nom qui n'est pas un titre : « Dr Fatoumata Diarra »
/// donne « Fatoumata ».
String prenomDe(String nom) {
  const titres = {
    'dr',
    'pr',
    'docteur',
    'professeur',
    'm',
    'mr',
    'mme',
    'mlle',
  };
  final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
  return mots
          .where((m) => !titres.contains(m.toLowerCase().replaceAll('.', '')))
          .firstOrNull ??
      mots.firstOrNull ??
      '';
}

List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const <String>[];

/// Libellés des modules (mêmes codes que l'API).
const Map<String, String> libellesModules = {
  'file': "File d'attente",
  'rdv': 'Rendez-vous',
  'consultation': 'Consultation',
  'caisse': 'Caisse',
  'pharmacie': 'Pharmacie',
  'labo': 'Laboratoire',
  'maternite': 'Maternité',
  'hospitalisation': 'Hospitalisation',
  'badges': 'Badges',
  'assurances': 'Assurances',
};
