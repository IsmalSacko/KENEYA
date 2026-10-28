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

  test('le propriétaire et la limite d’établissements se lisent et se gardent', () {
    final espace = Espace.fromJson({
      'membre_uuid': 'm-2',
      'proprietaire': true,
      'etablissement': {'uuid': 'e-2', 'nom': 'Cabinet'},
    });
    expect(espace.proprietaire, isTrue);
    expect(Espace.fromJson(espace.toJson()).proprietaire, isTrue);
    expect(Espace.fromJson({'membre_uuid': 'm-3'}).proprietaire, isFalse);

    final limite = LimiteEtablissements.fromJson({
      'crees': 2,
      'max': 3,
      'restants': 1,
    })!;
    expect(limite.restants, 1);
    expect(LimiteEtablissements.fromJson(limite.toJson())!.max, 3);
    expect(LimiteEtablissements.fromJson(null), isNull);
    expect(limite.atteinte, isFalse);

    // Sans limite (Hôpital réglé « illimité » dans la console).
    final libre = LimiteEtablissements.fromJson({'crees': 4, 'max': null})!;
    expect(libre.max, isNull);
    expect(libre.atteinte, isFalse);
  });
}
