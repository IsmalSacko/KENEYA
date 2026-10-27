import '../constants/api_constants.dart';
import '../offline/local_store.dart';
import '../offline/offline_mirror.dart';
import '../storage/token_storage.dart';
import '../../file/appareil_api.dart';

/// L'app a changé d'API (production ↔ API locale de développement) : les
/// sessions et le miroir mémorisés appartiennent à l'autre API. On les
/// oublie, sinon l'app demanderait à l'une des comptes qui n'existent que
/// dans l'autre.
class ChangementApi {
  static const _cle = 'api_url';

  static Future<void> verifier() async {
    final precedente = LocalStore.read<String>(_cle);
    if (precedente != null && precedente != ApiConstants.baseUrl) {
      await TokenStorage.clearToken();
      await TokenStorage.clearPersonneToken();
      await AppareilApi.oublier();
      await OfflineMirror.viderTout();
      for (final cle in const [
        'compte_personne',
        'compte_espaces',
        'compte_espace_actif',
        'membre_contexte',
        'token_membre_uuid',
        'offline_provisional_profile',
      ]) {
        await LocalStore.remove(cle);
      }
    }
    await LocalStore.write(_cle, ApiConstants.baseUrl);
  }
}
