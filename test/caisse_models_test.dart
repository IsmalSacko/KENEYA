import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keneya_plus/caisse/caisse_models.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test(
    'les montants s’écrivent dans la devise, sans centimes pour le franc CFA',
    () {
      expect(
        formatMontant(2000, 'XOF').replaceAll(' ', ' ').replaceAll(' ', ' '),
        '2 000 FCFA',
      );
      expect(
        formatMontant(1250, 'GHS').replaceAll(' ', ' ').replaceAll(' ', ' '),
        '12,50 GHS',
      );
    },
  );

  test('un montant saisi passe en unité mineure', () {
    expect(lireMontant('2 000', 'XOF'), 2000);
    expect(lireMontant('12,5', 'GHS'), 1250);
    expect(lireMontant('abc', 'XOF'), isNull);
    // Les séparateurs de milliers ne font jamais des centimes en FCFA.
    expect(lireMontant('50.000', 'XOF'), 50000);
    expect(lireMontant('50,000', 'XOF'), 50000);
    expect(lireMontant('50\u202f000', 'XOF'), 50000);
    expect(lireMontant('1.250,50', 'GHS'), 125050);
    expect(lireMontant('1,250.50', 'GHS'), 125050);
    expect(lireMontant('', 'XOF'), isNull);
  });
}
