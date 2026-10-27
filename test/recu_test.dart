import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/caisse/caisse_models.dart';
import 'package:keneya_plus/caisse/recu.dart';

void main() {
  final visite = Visite.fromJson({
    'uuid': 'b2c3d4e5-0000-0000-0000-000000000000',
    'statut': 'cloturee',
    'devise': 'XOF',
    'total': 3500,
    'paye': 3500,
    'reste': 0,
    'nom': 'Awa Traoré',
    'telephone': '+22376123456',
    'numero_facture': 'F26-4821',
    'recu': {'etablissement': 'CSCom Ngoni', 'numero_dossier': '26-4821'},
    'lignes': [
      {
        'uuid': 'l1',
        'libelle': 'Consultation',
        'quantite': 1,
        'prix_unitaire': 1500,
        'montant': 1500,
      },
      {
        'uuid': 'l2',
        'libelle': 'Goutte épaisse',
        'quantite': 1,
        'prix_unitaire': 2000,
        'montant': 2000,
      },
    ],
    'encaissements': [
      {
        'montant': 3500,
        'moyen': 'especes',
        'at': '2026-10-27T10:00:00Z',
        'par': 'Assétou',
      },
    ],
  });

  test(
    'le reçu d’une visite : numéro de facture, patient, lignes, paiement',
    () {
      final recu = Recu.deVisite(visite);
      expect(recu.numero, 'F26-4821');
      final texte = recu.texte();
      expect(texte, contains('Reçu N° F26-4821'));
      expect(texte, contains('Patient : Awa Traoré (dossier 26-4821)'));
      expect(texte, contains('Goutte épaisse'));
      expect(texte, contains('Payé (Espèces)'));
      expect(recu.caissier, 'Assétou');
    },
  );

  test('le PDF du reçu se fabrique', () async {
    final octets = await Recu.deVisite(visite).pdf();
    expect(String.fromCharCodes(octets.take(4)), '%PDF');
  });
}
