// Pharmacie : produits, lots, ordonnances.

class LotProduit {
  const LotProduit({
    required this.uuid,
    required this.quantite,
    required this.perime,
    this.numero,
    this.peremption,
  });

  final String uuid;
  final int quantite;
  final bool perime;
  final String? numero;
  final String? peremption;

  factory LotProduit.fromJson(Map<String, dynamic> j) => LotProduit(
    uuid: (j['uuid'] ?? '').toString(),
    quantite: _int(j['quantite']),
    perime: j['perime'] == true,
    numero: j['numero']?.toString(),
    peremption: j['peremption']?.toString(),
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

int _int(dynamic v, [int defaut = 0]) =>
    v is int ? v : int.tryParse(v?.toString() ?? '') ?? defaut;

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : const <Map<String, dynamic>>[];
