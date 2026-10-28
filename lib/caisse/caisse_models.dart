import 'package:intl/intl.dart';

// Caisse unifiée : la visite, sa facture, ses paiements.

/// « 2 000 FCFA », « 12,50 GHS ». Le montant est en unité mineure (un franc
/// CFA n'a pas de centimes, un cedi en a).
String formatMontant(int montant, String devise) {
  final decimales = const {'XOF': 0, 'XAF': 0, 'GNF': 0}[devise] ?? 2;
  final valeur = decimales == 0 ? montant : montant / 100;
  final texte = NumberFormat.decimalPatternDigits(
    locale: 'fr',
    decimalDigits: decimales,
  ).format(valeur);
  final symbole = const {'XOF': 'FCFA', 'XAF': 'FCFA'}[devise] ?? devise;
  return '$texte $symbole';
}

/// Montant saisi → unité mineure. Sans centimes (FCFA), points, virgules et
/// espaces ne sont que des séparateurs de milliers : « 50.000 », « 50 000 »
/// et « 50,000 » font 50 000. Avec centimes, le dernier séparateur est la
/// virgule décimale : « 1.250,50 » ou « 1,250.50 » font 1 250,50.
int? lireMontant(String saisi, String devise) {
  final decimales = const {'XOF': 0, 'XAF': 0, 'GNF': 0}[devise] ?? 2;
  final brut = saisi.replaceAll(RegExp(r'[\s\u00a0\u202f]'), '');
  if (brut.isEmpty) return null;
  if (decimales == 0) return int.tryParse(brut.replaceAll(RegExp('[.,]'), ''));
  final dernier = brut.lastIndexOf(RegExp('[.,]'));
  final entier = dernier < 0 ? brut : brut.substring(0, dernier);
  final fraction = dernier < 0 ? '' : brut.substring(dernier + 1);
  final v = double.tryParse(
    '${entier.replaceAll(RegExp('[.,]'), '')}.${fraction.isEmpty ? '0' : fraction}',
  );
  return v == null ? null : (v * 100).round();
}

const Map<String, String> libellesMoyens = {
  'especes': 'Espèces',
  'orange_money': 'Orange Money',
  'moov_money': 'Moov Money',
  'wave': 'Wave',
  'mtn_momo': 'MTN MoMo',
  'free_money': 'Free Money',
  'mpesa': 'M-Pesa',
  'credit': 'À crédit',
};

class Tarif {
  const Tarif({
    required this.uuid,
    required this.nom,
    required this.categorie,
    required this.prix,
    required this.actif,
  });

  final String uuid;
  final String nom;
  final String categorie;
  final int prix;
  final bool actif;

  factory Tarif.fromJson(Map<String, dynamic> j) => Tarif(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    categorie: (j['categorie'] ?? 'acte').toString(),
    prix: _int(j['prix']),
    actif: j['actif'] != false,
  );
}

const Map<String, String> libellesCategories = {
  'consultation': 'Consultation',
  'labo': 'Laboratoire',
  'soin': 'Soin',
  'acte': 'Acte',
  'hospitalisation': 'Hospitalisation',
};

class LigneVisite {
  const LigneVisite({
    required this.uuid,
    required this.libelle,
    required this.quantite,
    required this.prixUnitaire,
    required this.montant,
  });

  final String uuid;
  final String libelle;
  final int quantite;
  final int prixUnitaire;
  final int montant;

  factory LigneVisite.fromJson(Map<String, dynamic> j) => LigneVisite(
    uuid: (j['uuid'] ?? '').toString(),
    libelle: (j['libelle'] ?? '').toString(),
    quantite: _int(j['quantite'], 1),
    prixUnitaire: _int(j['prix_unitaire']),
    montant: _int(j['montant']),
  );
}

class EncaissementVisite {
  const EncaissementVisite({
    this.uuid = '',
    this.remboursable = false,
    required this.montant,
    required this.moyen,
    this.reference,
    this.at,
    this.par,
    this.rembourse = false,
  });

  final String uuid;

  /// Sa caisse est encore ouverte : il peut être remboursé.
  final bool remboursable;
  final int montant;
  final String moyen;
  final String? reference;
  final DateTime? at;

  /// Le caissier qui a encaissé.
  final String? par;

  /// Rendu au client (vente annulée) : ne compte plus.
  final bool rembourse;

  String get moyenLabel => libellesMoyens[moyen] ?? moyen;

  factory EncaissementVisite.fromJson(Map<String, dynamic> j) =>
      EncaissementVisite(
        uuid: (j['uuid'] ?? '').toString(),
        remboursable: j['remboursable'] == true,
        montant: _int(j['montant']),
        moyen: (j['moyen'] ?? '').toString(),
        reference: j['reference']?.toString(),
        at: DateTime.tryParse((j['at'] ?? '').toString())?.toLocal(),
        par: j['par']?.toString(),
        rembourse: j['rembourse'] == true,
      );
}

class Visite {
  const Visite({
    required this.uuid,
    required this.statut,
    required this.devise,
    required this.total,
    required this.paye,
    required this.reste,
    required this.tickets,
    required this.lignes,
    required this.encaissements,
    this.nom,
    this.telephone,
    this.etablissement,
    this.ouverteAt,
    this.partAssureur = 0,
    this.ordonnancesAServir = 0,
    this.assureur,
    this.tauxAssurance,
    this.numeroAssure,
    this.tri,
    this.numeroFacture,
    this.recu = const {},
  });

  final String uuid;
  final String statut;
  final String devise;
  final int total;
  final int paye;
  final int reste;
  final List<String> tickets;
  final List<LigneVisite> lignes;
  final List<EncaissementVisite> encaissements;
  final String? nom;
  final String? telephone;
  final String? etablissement;
  final DateTime? ouverteAt;

  /// La part payée par l'assureur, déjà retirée du reste.
  final int partAssureur;

  /// Prescrites, pas encore servies : le médicament n'est pas encore facturé.
  final int ordonnancesAServir;
  final String? assureur;
  final int? tauxAssurance;
  final String? numeroAssure;

  /// Les constantes du tri, telles que l'API les envoie (soignants seuls).
  final Map<String, dynamic>? tri;

  /// « F26-00042 », donné au premier encaissement.
  final String? numeroFacture;

  /// L'en-tête du reçu : etablissement, adresse, telephone, numero_dossier.
  final Map<String, String> recu;

  bool get ouverte => statut == 'ouverte';

  String get titre => nom?.isNotEmpty == true
      ? nom!
      : (tickets.isEmpty ? 'Visite' : tickets.join(' → '));

  factory Visite.fromJson(Map<String, dynamic> j) => Visite(
    uuid: (j['uuid'] ?? '').toString(),
    statut: (j['statut'] ?? 'ouverte').toString(),
    devise: (j['devise'] ?? 'XOF').toString(),
    total: _int(j['total']),
    paye: _int(j['paye']),
    reste: _int(j['reste']),
    tickets: _maps(
      j['tickets'],
    ).map((t) => (t['code'] ?? '').toString()).toList(),
    lignes: _maps(j['lignes']).map(LigneVisite.fromJson).toList(),
    encaissements: _maps(
      j['encaissements'],
    ).map(EncaissementVisite.fromJson).toList(),
    nom: j['nom']?.toString(),
    telephone: j['telephone']?.toString(),
    etablissement: j['etablissement']?.toString(),
    ouverteAt: DateTime.tryParse((j['ouverte_at'] ?? '').toString())?.toLocal(),
    partAssureur: _int(j['part_assureur']),
    ordonnancesAServir: _int(j['ordonnances_a_servir']),
    assureur: j['assurance'] is Map
        ? (j['assurance'] as Map)['nom']?.toString()
        : null,
    tauxAssurance: j['assurance'] is Map
        ? int.tryParse('${(j['assurance'] as Map)['taux']}')
        : null,
    numeroAssure: j['assurance'] is Map
        ? (j['assurance'] as Map)['numero']?.toString()
        : null,
    tri: j['tri'] is Map ? Map<String, dynamic>.from(j['tri'] as Map) : null,
    numeroFacture: j['numero_facture']?.toString(),
    recu: {
      if (j['recu'] is Map)
        for (final e in (j['recu'] as Map).entries)
          if (e.value != null) e.key.toString(): e.value.toString(),
    },
  );
}

/// Un assureur avec qui l'établissement travaille.
class Assureur {
  const Assureur({
    required this.uuid,
    required this.nom,
    required this.taux,
    required this.actif,
    this.plafond,
  });

  final String uuid;
  final String nom;
  final int taux;
  final bool actif;
  final int? plafond;

  factory Assureur.fromJson(Map<String, dynamic> j) => Assureur(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    taux: _int(j['taux']),
    actif: j['actif'] != false,
    plafond: j['plafond'] == null ? null : _int(j['plafond']),
  );
}

int _int(dynamic v, [int defaut = 0]) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? defaut;

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const <Map<String, dynamic>>[];
