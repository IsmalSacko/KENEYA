import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/core/api/renouvellement_jeton.dart';

/// Le serveur de Ngoni Santé, réduit à ce qui compte ici : un jeton expiré
/// est refusé (401), `/refresh` l'échange contre un neuf tant qu'il le peut.
class _Serveur implements HttpClientAdapter {
  _Serveur({this.renouvelable = true, this.horsLigne = false});

  final bool renouvelable;
  final bool horsLigne;
  int renouvellements = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? corps,
    Future<void>? annule,
  ) async {
    final jeton = o.headers['Authorization'];
    if (o.path.endsWith('/refresh')) {
      if (horsLigne)
        throw DioException.connectionError(
          requestOptions: o,
          reason: 'hors ligne',
        );
      renouvellements++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return renouvelable && jeton == 'Bearer ancien'
          ? _json(200, {'access_token': 'nouveau'})
          : _json(401, {
              'message': 'Votre session a expiré : reconnectez-vous.',
            });
    }
    return jeton == 'Bearer nouveau'
        ? _json(200, {'ok': true})
        : _json(401, {'message': 'Unauthenticated.'});
  }

  ResponseBody _json(int code, Map<String, dynamic> data) =>
      ResponseBody.fromString(
        jsonEncode(data),
        code,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  late String stocke;
  late bool expire;

  Dio client(_Serveur serveur) {
    final dio = Dio(BaseOptions(baseUrl: 'https://keneya.test/api'))
      ..httpClientAdapter = serveur;
    dio.interceptors
      ..add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            o.headers['Authorization'] = 'Bearer $stocke';
            h.next(o);
          },
        ),
      )
      ..add(
        RenouvellementJeton(
          dio: dio,
          chemin: '/refresh',
          lire: () async => stocke,
          ecrire: (j) async => stocke = j,
          surExpiration: () => expire = true,
        ),
      );
    return dio;
  }

  setUp(() {
    stocke = 'ancien';
    expire = false;
  });

  test('un jeton expiré est renouvelé et la requête repart', () async {
    final serveur = _Serveur();
    final res = await client(
      serveur,
    ).post('/pharmacie/produits', data: {'nom': 'Paracétamol'});

    expect(res.statusCode, 200);
    expect(stocke, 'nouveau');
    expect(serveur.renouvellements, 1);
    expect(expire, isFalse);
  });

  test(
    'plusieurs requêtes refusées en même temps : un seul renouvellement',
    () async {
      final serveur = _Serveur();
      final dio = client(serveur);
      final res = await Future.wait([
        dio.get('/patients'),
        dio.get('/medicaments'),
        dio.get('/me'),
      ]);

      expect(res.map((r) => r.statusCode), everyElement(200));
      expect(serveur.renouvellements, 1);
    },
  );

  test('un jeton trop vieux ramène à la connexion', () async {
    final serveur = _Serveur(renouvelable: false);

    await expectLater(client(serveur).get('/me'), throwsA(isA<DioException>()));
    expect(expire, isTrue);
    expect(stocke, 'ancien');
  });

  test('hors ligne, la session reste', () async {
    final serveur = _Serveur(horsLigne: true);

    await expectLater(client(serveur).get('/me'), throwsA(isA<DioException>()));
    expect(expire, isFalse);
  });
}
