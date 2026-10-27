import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/dossier/dossier_models.dart';

void main() {
  test('lit le dossier tel que l’API le renvoie', () {
    final d = DossierPatient.fromJson({
      'uuid': 'd1',
      'nom': 'Awa Traoré',
      'sexe': 'F',
      'age': 34,
      'groupe_sanguin': 'O+',
      'allergies': 'Pénicilline',
      'antecedents': '',
      'a_un_compte': true,
      'acces_historique': false,
      'consultations_ailleurs': 2,
      'peut_demander_acces': true,
      'consultations': [
        {
          'uuid': 'c1',
          'date': '2026-10-27T09:30:00+00:00',
          'etablissement': 'CSCom Hamdallaye',
          'ici': true,
          'praticien': 'Dr Diallo',
          'motif': 'Fièvre',
          'constantes': {
            'ta_sys': 120,
            'ta_dia': 80,
            'temperature': 38.5,
            'poids': '62',
          },
          'diagnostic': 'Paludisme simple',
        },
      ],
    });

    expect(d.resume, 'Femme · 34 ans · O+');
    expect(d.antecedents, isNull);
    expect(d.consultationsAilleurs, 2);
    final c = d.consultations.single;
    expect(c.constantes['poids'], 62);
    expect(
      c.constantesCourtes,
      'TA 120/80 · Température 38.5 °C · Poids 62 kg',
    );
  });

  test('les constantes vides de PHP arrivent en objet ou en liste', () {
    for (final vide in [<String, dynamic>{}, <dynamic>[]]) {
      final c = Consultation.fromJson({
        'uuid': 'x',
        'motif': 'M',
        'constantes': vide,
      });
      expect(c.constantes, isEmpty);
      expect(c.constantesCourtes, '');
    }
  });

  test('lit ce que le patient voit : accès et lectures', () {
    final m = MonDossier.fromJson({
      'uuid': 'd1',
      'nom': 'Awa',
      'consultations': <dynamic>[],
      'acces': [
        {
          'id': 3,
          'etablissement': 'Clinique Pasteur',
          'par': 'qr',
          'expire_at': '2026-11-03T10:00:00+00:00',
        },
      ],
      'lectures': [
        {
          'etablissement': 'Clinique Pasteur',
          'par': 'Dr Coulibaly',
          'historique': true,
          'lu_at': '2026-10-27T10:00:00+00:00',
        },
      ],
    });
    expect(m.acces.single.id, 3);
    expect(m.lectures.single.historique, isTrue);
  });
}
