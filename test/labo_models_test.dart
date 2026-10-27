import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/labo/labo_models.dart';

void main() {
  test('lit une demande du labo et compte les résultats anormaux', () {
    final d = DemandeLabo.fromJson({
      'uuid': 'd1',
      'statut': 'prelevee',
      'urgent': true,
      'patient': 'Fanta Keïta',
      'etablissement': 'CSCom Sabalibougou',
      'qr': 'ngoni-sante:labo:d1',
      'lignes': [
        {
          'uuid': 'l1',
          'nom': 'Goutte épaisse',
          'type_resultat': 'choix',
          'choix': ['Négatif', 'Positif +'],
          'normale': 'Négatif',
          'resultat': 'Positif +',
          'anormal': true,
        },
        {
          'uuid': 'l2',
          'nom': 'Glycémie à jeun',
          'type_resultat': 'nombre',
          'unite': 'g/L',
          'resultat': '0,95',
          'anormal': false,
        },
        {'uuid': 'l3', 'nom': 'NFS', 'type_resultat': 'texte', 'anormal': null},
      ],
    });

    expect(d.statutLabel, 'Prélevée');
    expect(d.modifiable, isTrue);
    expect(d.toutSaisi, isFalse);
    expect(d.anormaux, 1);
    expect(d.lignes[0].choix, ['Négatif', 'Positif +']);
    expect(d.lignes[1].resultatAffiche, '0,95 g/L');
    expect(d.lignes[2].anormal, isNull);
  });

  test('lit une analyse du catalogue', () {
    final a = AnalyseLabo.fromJson({
      'uuid': 'a',
      'code': 'GLY',
      'nom': 'Glycémie à jeun',
      'categorie': 'biochimie',
      'type_resultat': 'nombre',
      'normale_min': 0.7,
      'normale_max': '1.1',
      'prix': 1500,
      'choix': <dynamic>[],
    });
    expect(a.categorieLabel, 'Biochimie');
    expect(a.normaleMax, 1.1);
    expect(a.prix, 1500);
  });
}
