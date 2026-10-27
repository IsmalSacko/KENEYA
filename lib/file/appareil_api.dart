import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/api_constants.dart';
import '../core/offline/local_store.dart';
import 'file_models.dart';

/// Cet appareil est un écran de salle ou une borne d'établissement : il
/// parle à l'API avec son propre jeton (`X-Appareil`), sans compte.
class AppareilApi {
  static const _cleJeton = 'appareil_jeton';
  static const _cleConfig = 'appareil_config';
  static const _stockage = FlutterSecureStorage();

  static String? _jeton;

  /// Change quand l'appareil est appairé ou oublié : l'app se réaiguille.
  static final ValueNotifier<int> changements = ValueNotifier(0);

  static final Dio _dio =
      Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
            headers: {'Accept': 'application/json'},
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              _jeton ??= await _stockage.read(key: _cleJeton);
              if (_jeton != null) options.headers['X-Appareil'] = _jeton;
              handler.next(options);
            },
          ),
        );

  /// `{mode: ecran|borne, nom, etablissement}` si l'appareil est appairé.
  static Map<String, dynamic>? get config =>
      LocalStore.read<Map<String, dynamic>>(_cleConfig);

  static String? get mode => config?['mode']?.toString();

  static Future<void> appairer(String code) async {
    final res = await _dio.post('/appareils/appairer', data: {'code': code});
    final data = Map<String, dynamic>.from(res.data as Map);
    _jeton = data['jeton'].toString();
    await _stockage.write(key: _cleJeton, value: _jeton);
    final appareil = Map<String, dynamic>.from(data['appareil'] as Map);
    await LocalStore.write(_cleConfig, {
      'mode': appareil['mode'],
      'nom': appareil['nom'],
      'etablissement': (data['etablissement'] as Map)['nom'],
    });
    changements.value++;
  }

  static Future<void> oublier() async {
    _jeton = null;
    await _stockage.delete(key: _cleJeton);
    await LocalStore.remove(_cleConfig);
    changements.value++;
  }

  /// L'appareil a été retiré dans l'espace pro.
  static bool estRevoque(DioException e) => e.response?.statusCode == 401;

  static Future<EtatFile> etat() async {
    final res = await _dio.get('/appareil/etat');
    return EtatFile.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  static Future<List<Map<String, dynamic>>> services() async {
    final res = await _dio.get('/appareil/services');
    final d = (res.data as Map)['data'];
    return d is List
        ? d.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : [];
  }

  /// La borne scanne le QR d'un rendez-vous : le patient entre dans la file.
  static Future<TicketFile> scanRdv(String qr) async {
    final res = await _dio.post('/appareil/scan', data: {'qr': qr});
    return TicketFile.fromJson(
      Map<String, dynamic>.from((res.data as Map)['ticket'] as Map),
    );
  }

  static Future<TicketFile> emettre({
    required String serviceUuid,
    required bool prioritaire,
    String? telephone,
  }) async {
    final res = await _dio.post(
      '/appareil/tickets',
      data: {
        'service_uuid': serviceUuid,
        'priorite': prioritaire ? 'prioritaire' : 'ordinaire',
        if (telephone != null && telephone.isNotEmpty) 'telephone': telephone,
      },
    );
    return TicketFile.fromJson(
      Map<String, dynamic>.from((res.data as Map)['ticket'] as Map),
    );
  }
}
