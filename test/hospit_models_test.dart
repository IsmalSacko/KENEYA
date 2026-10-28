import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/caisse/caisse_models.dart';
import 'package:keneya_plus/hospitalisation/hospit_models.dart';

void main() {
  test('lit un séjour, son plan de soins et ses prises', () {
    final s = Sejour.fromJson({
      'uuid': 's1',
      'statut': 'en_cours',
      'patient': 'Bakary Sanogo',
      'motif': 'Paludisme grave',
      'nuits': 2,
      'bracelet': 'ngoni-sante:bracelet:s1',
      'lit': 'Salle Médecine · lit 1',
      'allergies': 'Pénicilline',
      'soins': [
        {
          'uuid': 'p1',
          'produit': 'Artésunate',
          'dose': '120 mg',
          'voie': 'iv',
          'horaires': ['08:00', '20:00'],
          'arrete': false,
        },
      ],
      'plan': [
        {
          'soin_uuid': 'p1',
          'produit': 'Artésunate',
          'voie': 'iv',
          'prevue_at': '2026-10-27T08:00:00+00:00',
          'heure': '08:00',
          'statut': 'a_faire',
          'en_retard': true,
        },
      ],
    });
    expect(s.soins.single.resume, 'Artésunate 120 mg · IV · 08:00, 20:00');
    expect(s.plan.single.aFaire, isTrue);
    expect(s.plan.single.enRetard, isTrue);
    expect(s.enCours, isTrue);
  });

  test('compte les lits libres d’une chambre', () {
    final c = Chambre.fromJson({
      'uuid': 'c',
      'nom': 'Salle 1',
      'prix': 5000,
      'lits': [
        {
          'uuid': 'l1',
          'numero': '1',
          'actif': true,
          'sejour_uuid': 's1',
          'patient': 'Bakary',
        },
        {'uuid': 'l2', 'numero': '2', 'actif': true},
        {'uuid': 'l3', 'numero': '3', 'actif': false},
      ],
    });
    expect(c.libres, 1);
    expect(c.lits.first.libre, isFalse);
  });

  test('lit la part de l’assureur sur la visite', () {
    final v = Visite.fromJson({
      'uuid': 'v',
      'total': 10000,
      'paye': 0,
      'reste': 3000,
      'part_assureur': 7000,
      'assurance': {'nom': 'AMO', 'taux': 70, 'numero': 'AMO-1'},
    });
    expect(v.partAssureur, 7000);
    expect(v.assureur, 'AMO');
    expect(v.tauxAssurance, 70);
    expect(v.reste, 3000);
  });

  test('lit la sortie, l’annulation, la correction et la fin d’un soin', () {
    final s = Sejour.fromJson({
      'uuid': 's',
      'statut': 'annulee',
      'patient': 'Bakary',
      'motif': 'X',
      'bracelet': 'b',
      'annulable': false,
      'sortie_at': '2026-10-27T10:00:00Z',
      'soins': [
        {
          'uuid': 'so',
          'produit': 'Amoxicilline',
          'voie': 'po',
          'horaires': ['08:00'],
          'fin': '2026-10-29',
        },
      ],
      'plan': [
        {
          'soin_uuid': 'so',
          'statut': 'faite',
          'corrigee': true,
          'corrigeable': true,
        },
      ],
    });
    expect(s.annule, isTrue);
    expect(s.enCours, isFalse);
    expect(s.sortie, isNotNull);
    expect(s.soins.first.fin, DateTime(2026, 10, 29));
    expect(s.plan.first.corrigee, isTrue);
    expect(s.plan.first.corrigeable, isTrue);

    final f = FactureNuits.fromJson({
      'nuits': 2,
      'montant': 10000,
      'nouvelle': true,
    });
    expect(f.nuits, 2);
    expect(f.nouvelle, isTrue);

    final c = Chambre.fromJson({'uuid': 'c', 'nom': 'A', 'actif': false});
    expect(c.actif, isFalse);
  });
}
