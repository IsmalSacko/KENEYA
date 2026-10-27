import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../core/offline/local_store.dart';

/// Vérifie le QR d'une ordonnance avec la clé publique, même sans internet :
/// une ordonnance modifiée ou inventée ne passe pas. La clé est gardée sur
/// le téléphone après la première connexion.
class VerificationOrdonnance {
  static const _cle = 'ordonnances_cle_publique';
  static const _prefixe = 'ngoni-sante:ord:';

  static Future<void> rafraichirCle() async {
    try {
      final res = await Dio(
        BaseOptions(baseUrl: ApiConstants.baseUrl),
      ).get('/public/ordonnances/cle');
      await LocalStore.write(_cle, (res.data as Map)['cle'].toString());
    } catch (_) {
      // Hors ligne : on garde la clé connue.
    }
  }

  static bool estOrdonnance(String qr) => qr.trim().startsWith(_prefixe);

  /// Le contenu signé (patient, prescripteur, lignes) s'il est authentique ;
  /// null s'il ne l'est pas ou si la clé n'est pas encore connue.
  static Future<Map<String, dynamic>?> verifier(String qr) async {
    final cle = LocalStore.read<String>(_cle);
    return cle == null ? null : verifierAvecCle(qr, cle);
  }

  static Future<Map<String, dynamic>?> verifierAvecCle(
    String qr,
    String cle,
  ) async {
    if (!estOrdonnance(qr)) return null;
    final morceaux = qr.trim().substring(_prefixe.length).split('.');
    if (morceaux.length != 2) return null;
    try {
      final ok = await Ed25519().verify(
        utf8.encode(morceaux[0]),
        signature: Signature(
          _b64(morceaux[1]),
          publicKey: SimplePublicKey(_b64(cle), type: KeyPairType.ed25519),
        ),
      );
      if (!ok) return null;
      final contenu = jsonDecode(utf8.decode(_b64(morceaux[0])));
      return contenu is Map ? Map<String, dynamic>.from(contenu) : null;
    } catch (_) {
      return null;
    }
  }

  static List<int> _b64(String texte) =>
      base64Url.decode(texte.padRight((texte.length + 3) ~/ 4 * 4, '='));
}
