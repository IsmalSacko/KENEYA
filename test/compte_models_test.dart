import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/compte/compte_models.dart';

void main() {
  test('le prénom saute les titres', () {
    expect(prenomDe('Dr Fatoumata Diarra'), 'Fatoumata');
    expect(prenomDe('Mme. Awa Traoré'), 'Awa');
    expect(prenomDe('Moussa'), 'Moussa');
    expect(prenomDe('Dr'), 'Dr');
    expect(prenomDe('  '), '');
  });

  test("un espace se lit depuis la réponse de l'API", () {
    final espace = Espace.fromJson({
      'membre_uuid': 'm-1',
      'role': 'medecin',
      'role_label': 'Médecin',
      'actif': true,
      'etablissement': {
        'uuid': 'e-1',
        'nom': 'CSCom de Hamdallaye',
        'profil': 'centre_sante',
        'modules': ['file', 'pharmacie'],
        'devise': 'XOF',
      },
    });

    expect(espace.etablissementNom, 'CSCom de Hamdallaye');
    expect(espace.profilLabel, 'Centre de santé');
    expect(espace.modules, ['file', 'pharmacie']);
    expect(Espace.fromJson(espace.toJson()).membreUuid, 'm-1');
  });
}
