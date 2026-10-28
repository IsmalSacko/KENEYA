import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/maternite/maternite_models.dart';

void main() {
  test('lit une grossesse, ses CPN et l’accouchement', () {
    final g = Grossesse.fromJson({
      'uuid': 'g1',
      'statut': 'accouchee',
      'patiente': 'Aminata Coulibaly',
      'ddr': '2026-01-10',
      'dpa': '2026-10-17',
      'semaines': null,
      'gestite': 3,
      'parite': 2,
      'cpn': [
        {
          'numero': 1,
          'semaines': 16,
          'etablissement': 'CSRéf',
          'poids': 62.5,
          'ta_sys': 110,
          'ta_dia': 70,
          'tpi': 1,
          'fer': true,
          'moustiquaire': false,
          'presentation': 'cephalique',
        },
      ],
      'accouchement': {
        'date_heure': '2026-10-15T03:20:00+00:00',
        'mode': 'voie_basse',
        'enfants': [
          {
            'sexe': 'F',
            'vivant': true,
            'poids_g': 3100,
            'dossier_uuid': 'e1',
            'nom': 'Awa',
          },
        ],
      },
    });

    expect(g.enCours, isFalse);
    expect(g.gp, 'G3 P2');
    expect(
      g.cpn.single.resume,
      '62.5 kg · TA 110/70 · Céphalique · TPI 1 · fer',
    );
    expect(g.enfants.single.nom, 'Awa');
    expect(g.modeAccouchement, 'voie_basse');
  });

  test('compte les vaccins en retard du carnet', () {
    final c = CarnetEnfant.fromJson({
      'uuid': 'e1',
      'nom': 'Awa',
      'date_naissance': '2026-08-28',
      'consultations': <dynamic>[],
      'carnet': [
        {
          'code': 'BCG',
          'nom': 'BCG',
          'prevu_le': '2026-08-28',
          'fait_le': '2026-08-28',
          'en_retard': false,
        },
        {
          'code': 'VPO0',
          'nom': 'Polio oral 0',
          'prevu_le': '2026-08-28',
          'fait_le': null,
          'en_retard': true,
        },
        {
          'code': 'PENTA2',
          'nom': 'Pentavalent 2',
          'prevu_le': '2026-11-06',
          'en_retard': false,
        },
      ],
    });
    expect(c.enRetard, 1);
    expect(c.vaccins.first.fait, isTrue);
    expect(c.vaccins[2].fait, isFalse);
  });

  test('lit une grossesse close, la CPN complète et la taille du bébé', () {
    final g = Grossesse.fromJson({
      'uuid': 'g',
      'statut': 'terminee',
      'issue': 'fausse_couche',
      'terminee_at': '2026-10-20',
      'patiente': 'Aminata',
      'ddr': '2026-09-01',
      'dpa': '2027-06-08',
      'cpn': [
        {
          'uuid': 'c',
          'numero': 1,
          'semaines': 6,
          'oedemes': true,
          'albuminurie': '++',
        },
      ],
    });
    expect(g.enCours, isFalse);
    expect(g.fin, 'Fausse couche');
    expect(g.termineeLe, '2026-10-20');
    expect(g.cpn.single.uuid, 'c');
    expect(g.cpn.single.resume, contains('œdèmes'));
    expect(g.cpn.single.resume, contains('albuminurie ++'));

    final e = EnfantNe.fromJson({'sexe': 'F', 'taille_cm': 49});
    expect(e.tailleCm, 49);
  });
}
