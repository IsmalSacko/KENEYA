// Pharmacie : produits, lots, ordonnances, ventes.

import 'rayons.dart';

export 'rayons.dart' show Rayons;

/// Les rayons de l'officine : tout ce qu'on y vend n'est pas un médicament.
/// Chaque établissement a les siens (voir [Rayons]).
Map<String, String> get rayons => Rayons.noms;

class LotProduit {
  const LotProduit({
    required this.uuid,
    required this.quantite,
    required this.perime,
    this.numero,
    this.peremption,
    this.intact = false,
  });

  final String uuid;
  final int quantite;
  final bool perime;

  /// Rien n'en est sorti : la réception peut encore s'annuler.
  final bool intact;
  final String? numero;
  final String? peremption;

  factory LotProduit.fromJson(Map<String, dynamic> j) => LotProduit(
    uuid: (j['uuid'] ?? '').toString(),
    quantite: _int(j['quantite']),
    perime: j['perime'] == true,
    numero: j['numero']?.toString(),
    peremption: j['peremption']?.toString(),
    intact: j['intact'] == true,
  );
}

class Produit {
  const Produit({
    required this.uuid,
    required this.nom,
    required this.conditionnement,
    required this.venteUnite,
    required this.prixBoite,
    required this.ordonnanceRequise,
    required this.stockUnites,
    required this.stockBoites,
    required this.seuilAlerte,
    required this.lots,
    this.dci,
    this.forme,
    this.dosage,
    this.prixUnite,
    this.rayon = 'medicaments',
    this.prixAchat,
    this.codeBarres,
    this.ventes = 0,
  });

  final String uuid;
  final String nom;
  final int conditionnement;
  final bool venteUnite;
  final double prixBoite;
  final bool ordonnanceRequise;
  final int stockUnites;
  final int stockBoites;
  final int seuilAlerte;
  final List<LotProduit> lots;
  final String? dci;
  final String? forme;
  final String? dosage;
  final double? prixUnite;
  final String rayon;

  /// Prix d'achat de la boîte (pour la marge).
  final double? prixAchat;
  final String? codeBarres;

  /// Nombre de ventes sur 30 jours : les raccourcis de l'écran « Vendre ».
  final int ventes;

  String get rayonLabel => rayons[rayon] ?? rayon;
  bool get estMedicament => rayon == 'medicaments';

  bool get stockBas => stockUnites <= seuilAlerte;

  /// « 3 boîtes (90 cp) » ou « 12 ».
  String get stockLabel => conditionnement > 1
      ? 'En stock : $stockBoites boîte(s) · $stockUnites unités'
      : 'En stock : $stockUnites';

  String get description => [
    dci,
    forme,
    dosage,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  factory Produit.fromJson(Map<String, dynamic> j) => Produit(
    uuid: (j['uuid'] ?? '').toString(),
    nom: (j['nom'] ?? '').toString(),
    conditionnement: _int(j['conditionnement'], 1),
    venteUnite: j['vente_unite'] == true,
    prixBoite: double.tryParse('${j['prix_boite']}') ?? 0,
    ordonnanceRequise: j['ordonnance_requise'] == true,
    stockUnites: _int(j['stock_unites']),
    stockBoites: _int(j['stock_boites']),
    seuilAlerte: _int(j['seuil_alerte']),
    lots: _maps(j['lots']).map(LotProduit.fromJson).toList(),
    dci: j['dci']?.toString(),
    forme: j['forme']?.toString(),
    dosage: j['dosage']?.toString(),
    prixUnite: double.tryParse('${j['prix_unite']}'),
    rayon: (j['rayon'] ?? 'medicaments').toString(),
    prixAchat: double.tryParse('${j['prix_achat']}'),
    codeBarres: j['code_barres']?.toString(),
    ventes: _int(j['ventes']),
  );
}

class LigneOrdonnance {
  const LigneOrdonnance({
    required this.uuid,
    required this.produit,
    required this.quantite,
    required this.delivree,
    required this.reste,
    this.posologie,
    this.medicamentUuid,
  });

  final String uuid;
  final String produit;
  final int quantite;
  final int delivree;
  final int reste;
  final String? posologie;
  final String? medicamentUuid;

  factory LigneOrdonnance.fromJson(Map<String, dynamic> j) => LigneOrdonnance(
    uuid: (j['uuid'] ?? '').toString(),
    produit: (j['produit'] ?? '').toString(),
    quantite: _int(j['quantite']),
    delivree: _int(j['quantite_delivree']),
    reste: _int(j['reste']),
    posologie: j['posologie']?.toString(),
    medicamentUuid: j['medicament_uuid']?.toString(),
  );
}

class OrdonnanceRx {
  const OrdonnanceRx({
    required this.uuid,
    required this.statut,
    required this.patientNom,
    required this.etablissement,
    required this.qr,
    required this.lignes,
    this.prescripteur,
    this.date,
  });

  final String uuid;
  final String statut;
  final String patientNom;
  final String etablissement;
  final String qr;
  final List<LigneOrdonnance> lignes;
  final String? prescripteur;
  final String? date;

  String get statutLabel =>
      const {
        'emise': 'À délivrer',
        'partielle': 'Délivrée en partie',
        'delivree': 'Délivrée',
        'annulee': 'Annulée',
      }[statut] ??
      statut;

  factory OrdonnanceRx.fromJson(Map<String, dynamic> j) => OrdonnanceRx(
    uuid: (j['uuid'] ?? '').toString(),
    statut: (j['statut'] ?? 'emise').toString(),
    patientNom: (j['patient_nom'] ?? '').toString(),
    etablissement: (j['etablissement'] ?? '').toString(),
    qr: (j['qr'] ?? '').toString(),
    lignes: _maps(j['lignes']).map(LigneOrdonnance.fromJson).toList(),
    prescripteur: j['prescripteur']?.toString(),
    date: j['date']?.toString(),
  );
}

/// Un patient attendu à la pharmacie : son ticket (s'il fait la queue) et
/// ses ordonnances du jour qui restent à servir.
class PatientAServir {
  const PatientAServir({
    required this.patient,
    required this.ordonnances,
    this.visiteUuid,
    this.ticketCode,
    this.ticketStatut,
  });

  final String patient;
  final List<OrdonnanceRx> ordonnances;
  final String? visiteUuid;
  final String? ticketCode;
  final String? ticketStatut;

  factory PatientAServir.fromJson(Map<String, dynamic> j) {
    final t = j['ticket'] is Map
        ? Map<String, dynamic>.from(j['ticket'] as Map)
        : null;
    return PatientAServir(
      patient: (j['patient'] ?? '').toString(),
      ordonnances: _maps(j['ordonnances']).map(OrdonnanceRx.fromJson).toList(),
      visiteUuid: j['visite_uuid']?.toString(),
      ticketCode: t?['code']?.toString(),
      ticketStatut: t?['statut']?.toString(),
    );
  }
}

/// Une vente du comptoir, telle que le reçu l'imprime.
class Vente {
  const Vente({
    required this.uuid,
    required this.numero,
    required this.client,
    required this.statut,
    required this.total,
    required this.reste,
    required this.devise,
    required this.lignes,
    required this.moyens,
    this.le,
    this.telephone,
    this.etablissement,
    this.etablissementTelephone,
    this.etablissementAdresse,
  });

  final String uuid;
  final String numero;
  final String client;
  final String statut;
  final int total;
  final int reste;
  final String devise;
  final List<({String libelle, int quantite, int montant})> lignes;
  final List<String> moyens;
  final DateTime? le;
  final String? telephone;
  final String? etablissement;
  final String? etablissementTelephone;
  final String? etablissementAdresse;

  bool get payee => statut == 'payee';
  bool get annulee => statut == 'annulee';
  bool get aCredit => statut == 'a_credit';

  factory Vente.fromJson(Map<String, dynamic> j) => Vente(
    uuid: (j['uuid'] ?? '').toString(),
    numero: (j['numero'] ?? '').toString(),
    client: (j['client'] ?? '').toString(),
    statut: (j['statut'] ?? '').toString(),
    total: _int(j['total']),
    reste: _int(j['reste']),
    devise: (j['devise'] ?? 'XOF').toString(),
    lignes: [
      for (final l in _maps(j['lignes']))
        (
          libelle: (l['libelle'] ?? '').toString(),
          quantite: _int(l['quantite']),
          montant: _int(l['montant']),
        ),
    ],
    moyens: [
      if (j['moyens'] is List)
        for (final m in j['moyens'] as List) m.toString(),
    ],
    le: DateTime.tryParse('${j['le']}')?.toLocal(),
    telephone: j['telephone']?.toString(),
    etablissement: j['etablissement'] is Map
        ? (j['etablissement'] as Map)['nom']?.toString()
        : null,
    etablissementTelephone: j['etablissement'] is Map
        ? (j['etablissement'] as Map)['telephone']?.toString()
        : null,
    etablissementAdresse: j['etablissement'] is Map
        ? (j['etablissement'] as Map)['adresse']?.toString()
        : null,
  );
}

/// La journée du comptoir : les ventes et leurs totaux.
class VentesDuJour {
  const VentesDuJour({
    required this.ventes,
    required this.nombre,
    required this.chiffre,
    required this.encaisse,
    required this.aEncaisser,
    required this.parMoyen,
    required this.parRayon,
    this.credits = const [],
  });

  final List<Vente> ventes;
  final int nombre;
  final int chiffre;
  final int encaisse;
  final int aEncaisser;
  final Map<String, int> parMoyen;
  final List<({String label, int montant})> parRayon;

  /// Les ventes à crédit pas encore payées, de tous les jours.
  final List<Vente> credits;

  factory VentesDuJour.fromJson(Map<String, dynamic> j) => VentesDuJour(
    ventes: _maps(j['ventes']).map(Vente.fromJson).toList(),
    nombre: _int(j['nombre']),
    chiffre: _int(j['chiffre']),
    encaisse: _int(j['encaisse']),
    aEncaisser: _int(j['a_encaisser']),
    parMoyen: {
      if (j['par_moyen'] is Map)
        for (final e in (j['par_moyen'] as Map).entries)
          e.key.toString(): _int(e.value),
    },
    parRayon: [
      for (final r in _maps(j['par_rayon']))
        (label: (r['label'] ?? '').toString(), montant: _int(r['montant'])),
    ],
    credits: _maps(j['credits']).map(Vente.fromJson).toList(),
  );
}

/// Un produit à recommander au grossiste.
class ACommander {
  const ACommander({
    required this.uuid,
    required this.nom,
    required this.stockUnites,
    required this.boites,
    this.fournisseur,
    this.telephoneFournisseur,
  });

  final String uuid;
  final String nom;
  final int stockUnites;
  final int boites;
  final String? fournisseur;
  final String? telephoneFournisseur;

  factory ACommander.fromJson(Map<String, dynamic> j) {
    final f = j['fournisseur'] is Map ? j['fournisseur'] as Map : null;
    return ACommander(
      uuid: (j['uuid'] ?? '').toString(),
      nom: (j['nom'] ?? '').toString(),
      stockUnites: _int(j['stock_unites']),
      boites: _int(j['boites']),
      fournisseur: f?['nom']?.toString(),
      telephoneFournisseur: f?['telephone']?.toString(),
    );
  }
}

int _int(dynamic v, [int defaut = 0]) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? defaut;

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const <Map<String, dynamic>>[];
