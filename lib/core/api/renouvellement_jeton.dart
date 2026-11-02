import 'package:dio/dio.dart';

/// Un jeton vit 24 h. À la première réponse 401, il est renouvelé (le serveur
/// l'accepte jusqu'à 14 jours après son émission) et la requête repart une
/// fois avec le nouveau. Sans cela, le soignant restait devant « non
/// authentifié » en enregistrant un médicament, et la déconnexion elle-même
/// était refusée (2026-11-02).
///
/// Jeton trop vieux : [surExpiration] ramène à la connexion. Hors ligne :
/// rien ne change, la session reste et on réessaiera.
class RenouvellementJeton extends Interceptor {
  RenouvellementJeton({
    required this.dio,
    required this.chemin,
    required this.lire,
    required this.ecrire,
    this.surExpiration,
  });

  /// Le client qui rejoue la requête (et dont les intercepteurs remettent le
  /// jeton à jour).
  final Dio dio;

  /// `/refresh` (espace pro) ou `/compte/refresh` (personne).
  final String chemin;
  final Future<String?> Function() lire;
  final Future<void> Function(String jeton) ecrire;
  final void Function()? surExpiration;

  /// Plusieurs requêtes refusées en même temps : un seul renouvellement.
  Future<_Resultat>? _enCours;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requete = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        requete.extra['jeton_renouvele'] == true ||
        requete.path.endsWith(chemin)) {
      return handler.next(err);
    }
    final ancien = await lire();
    if (ancien == null || ancien.isEmpty) return handler.next(err);

    final resultat = await (_enCours ??= _renouveler(
      ancien,
    ).whenComplete(() => _enCours = null));
    if (resultat.expire) surExpiration?.call();
    final jeton = resultat.jeton;
    if (jeton == null) return handler.next(err);

    requete.headers['Authorization'] = 'Bearer $jeton';
    requete.extra['jeton_renouvele'] = true;
    try {
      handler.resolve(await dio.fetch<dynamic>(requete));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<_Resultat> _renouveler(String ancien) async {
    final client = Dio(
      BaseOptions(
        baseUrl: dio.options.baseUrl,
        connectTimeout: dio.options.connectTimeout,
        receiveTimeout: dio.options.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $ancien',
        },
      ),
    )..httpClientAdapter = dio.httpClientAdapter;
    try {
      final res = await client.post<dynamic>(chemin);
      final data = res.data;
      final jeton = data is Map ? data['access_token']?.toString() : null;
      if (jeton == null || jeton.isEmpty) return const _Resultat.expire();
      await ecrire(jeton);
      return _Resultat(jeton);
    } on DioException catch (e) {
      // Refus net : il faut se reconnecter. Réseau, serveur : on réessaiera.
      return e.response?.statusCode == 401
          ? const _Resultat.expire()
          : const _Resultat(null);
    }
  }
}

class _Resultat {
  const _Resultat(this.jeton) : expire = false;
  const _Resultat.expire() : jeton = null, expire = true;

  final String? jeton;
  final bool expire;
}
