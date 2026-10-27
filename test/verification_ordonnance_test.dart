import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/pharmacie/verification_ordonnance.dart';

// Une ordonnance signée par l'API (PHP, sodium) et sa clé publique : la
// vérification en Dart doit l'accepter, et refuser la moindre retouche.
const _qr =
    'ngoni-sante:ord:eyJ2IjoxLCJ1IjoiNWFiMGI4ZmYtOGYwNi00ZjlmLTk4MzYtZjNmNjA0ODYwNzE3IiwiZSI6IkNTQ29tIGRlIEhhbWRhbGxheWUiLCJtIjoiRHIgRmF0b3VtYXRhIERpYXJyYSIsInAiOiJBd2EgVHJhb3LDqSIsImQiOiIyMDI2LTEwLTI2IiwibCI6W1siUGFyYWPDqXRhbW9sIDUwMCBtZyIsMTgsIjEgY3AgMyBmb2lzIHBhciBqb3VyIl1dfQ.vg1wLPkLpdcGwCpXaUGjsKEpcsSV8s5q1E84pHHWXoWC7EjaTUqwrp5rXWCbzzKy14UWbL50cQJXRwMNVEBxCA';
const _cle = 'ItO4JOiW4fVh1_ocoa53JrfrS1HFM0mkV_zPF1hSWhQ';

void main() {
  test('accepte une ordonnance signée par le serveur', () async {
    final contenu = await VerificationOrdonnance.verifierAvecCle(_qr, _cle);
    expect(contenu, isNotNull);
    expect(contenu!['p'], 'Awa Traoré');
    expect((contenu['l'] as List).first[1], 18);
  });

  test('refuse une ordonnance retouchée', () async {
    final corps = _qr.substring(0, _qr.indexOf('.'));
    final i = corps.length - 3;
    final change =
        corps.substring(0, i) +
        (corps[i] == 'A' ? 'B' : 'A') +
        corps.substring(i + 1);
    final falsifie = change + _qr.substring(_qr.indexOf('.'));
    expect(
      await VerificationOrdonnance.verifierAvecCle(falsifie, _cle),
      isNull,
    );
  });

  test('refuse ce qui n’est pas une ordonnance', () async {
    expect(
      await VerificationOrdonnance.verifierAvecCle('ngoni-sante:rdv:abc', _cle),
      isNull,
    );
  });
}
