import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';

import '../controllers/auth_controller.dart';
import '../core/offline/local_store.dart';
import '../core/offline/offline_mirror.dart';
import '../core/offline/pin_cache.dart';
import '../core/offline/sync_manager.dart';
import '../core/offline/sync_queue.dart';
import '../core/offline/uuid.dart';
import '../core/storage/token_storage.dart';
import 'compte_api.dart';
import 'compte_models.dart';

/// Résultat d'une inscription : le serveur peut exiger le code SMS.
enum ResultatInscription { reussie, codeRequis, echec }

/// Le compte de la personne : qui est connecté, ses espaces pro, l'espace
/// ouvert. L'[AuthController] garde la session du membre (espace pro), que
/// tous les écrans pro utilisent déjà.
class CompteController extends ChangeNotifier {
  CompteController({CompteApi? api}) : _api = api ?? CompteApi();

  final CompteApi _api;

  static const _clePersonne = 'compte_personne';
  static const _cleEspaces = 'compte_espaces';
  static const _cleEspaceActif = 'compte_espace_actif';
  static const _clePays = 'referentiel_pays';
  static const _cleProfils = 'referentiel_profils';

  bool initialisation = true;
  bool chargement = false;
  String? erreur;

  Personne? personne;
  List<Espace> espaces = [];

  /// Membre dont l'espace pro est ouvert ; null = « Ma santé ».
  String? espaceActif;

  List<Pays> pays = Pays.secours;
  List<ProfilEtablissement> profils = ProfilEtablissement.secours;

  bool get connecte => personne != null;

  Espace? get espaceOuvert =>
      espaces.where((e) => e.membreUuid == espaceActif).firstOrNull;

  Pays paysDe(String code) =>
      pays.where((p) => p.code == code).firstOrNull ?? pays.first;

  // ------------------------------------------------------------ démarrage

  /// Relit le compte mémorisé, puis le rafraîchit si le réseau répond.
  /// [auth] : session membre déjà restaurée (app 3.x mise à jour).
  Future<void> restaurer(AuthController auth) async {
    _lireReferentielEnCache();
    final p = LocalStore.read<Map<String, dynamic>>(_clePersonne);
    if (p != null) personne = Personne.fromJson(p);
    espaces = _lireEspacesEnCache();
    espaceActif = LocalStore.read<String>(_cleEspaceActif);

    initialisation = false;
    notifyListeners();

    _rafraichirReferentiel();
    final token = await TokenStorage.getPersonneToken();
    if (token != null && token.isNotEmpty) {
      await rafraichir();
    } else if (auth.isAuthenticated && auth.currentUser != null) {
      await _connexionSilencieuse(auth);
    }
  }

  /// Utilisateur de l'app 3.x : il a une session membre mais pas encore de
  /// compte personne. Son PIN en cache suffit à l'ouvrir sans rien lui
  /// redemander (le serveur a rattaché ses membres à une personne).
  Future<void> _connexionSilencieuse(AuthController auth) async {
    final telephone = auth.currentUser!.telephone;
    final pin = await PinCache.lire(telephone);
    if (pin == null) return;
    try {
      final data = await _api.connexion(
        paysCode: Pays.defaut,
        telephone: telephone,
        pin: pin,
      );
      await _enregistrerConnexion(data, Pays.defaut, telephone, pin);
      final membre = auth.currentUser;
      espaceActif = espaces
          .where((e) => e.role == membre?.role)
          .map((e) => e.membreUuid)
          .firstOrNull;
      await LocalStore.write(_cleEspaceActif, espaceActif);
      notifyListeners();
    } catch (_) {
      // Hors ligne ou PIN changé : on réessaiera au prochain démarrage.
    }
  }

  Future<void> rafraichir() async {
    try {
      final data = await _api.moi();
      _appliquer(data);
      await _memoriser();
      notifyListeners();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Jeton expiré : la session hors ligne reste, la prochaine connexion
        // en ligne en redonnera un.
        await TokenStorage.clearPersonneToken();
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------ connexion

  Future<bool> connexion({
    required String paysCode,
    required String telephone,
    required String pin,
  }) async {
    return _action(() async {
      try {
        final data = await _api.connexion(
          paysCode: paysCode,
          telephone: telephone,
          pin: pin,
        );
        await _enregistrerConnexion(data, paysCode, telephone, pin);
        return true;
      } on DioException catch (e) {
        if (!CompteApi.estHorsLigne(e)) rethrow;
        return _connexionHorsLigne(paysCode, telephone, pin);
      }
    });
  }

  /// Hors ligne : le PIN en cache et le compte mémorisé lors d'une
  /// précédente connexion en ligne sur cet appareil.
  Future<bool> _connexionHorsLigne(
    String paysCode,
    String telephone,
    String pin,
  ) async {
    final cle = _cleCache(paysCode, telephone);
    final memorise = LocalStore.read<Map<String, dynamic>>('compte_hl_$cle');
    if (memorise == null || !await PinCache.verify(cle, pin)) {
      erreur =
          'Pas de connexion internet. Connectez-vous une première fois en ligne sur ce téléphone.';
      return false;
    }
    _appliquer(memorise);
    await _memoriser();
    return true;
  }

  Future<ResultatInscription> inscription({
    required String paysCode,
    required String telephone,
    required String nom,
    required String pin,
    String? code,
    bool pro = false,
  }) async {
    var resultat = ResultatInscription.echec;
    await _action(() async {
      try {
        final data = await _api.inscription(
          paysCode: paysCode,
          telephone: telephone,
          nom: nom,
          pin: pin,
          code: code,
          pro: pro,
        );
        await _enregistrerConnexion(data, paysCode, telephone, pin);
        resultat = ResultatInscription.reussie;
        return true;
      } on DioException catch (e) {
        final data = e.response?.data;
        if (data is Map && data['code'] == 'code_requis') {
          await _api.demanderCode(
            paysCode: paysCode,
            telephone: telephone,
            objet: 'inscription',
          );
          resultat = ResultatInscription.codeRequis;
          erreur = null;
          return false;
        }
        rethrow;
      }
    });
    return resultat;
  }

  Future<bool> demanderCodePin({
    required String paysCode,
    required String telephone,
  }) => _action(() async {
    await _api.demanderCode(
      paysCode: paysCode,
      telephone: telephone,
      objet: 'pin',
    );
    return true;
  });

  Future<bool> pinOublie({
    required String paysCode,
    required String telephone,
    required String code,
    required String pin,
  }) => _action(() async {
    final data = await _api.pinOublie(
      paysCode: paysCode,
      telephone: telephone,
      code: code,
      pin: pin,
    );
    await _enregistrerConnexion(data, paysCode, telephone, pin);
    return true;
  });

  // ------------------------------------------------------------ espaces

  Future<bool> ouvrirEspace(
    Espace espace,
    AuthController auth,
  ) => _action(() async {
    if (espace.membreUuid == espaceActif) return true;
    if (!await _envoyerEnAttente()) return false;
    try {
      final data = await _api.ouvrirEspace(espace.membreUuid);
      await auth.ouvrirSessionMembre(data, espace.membreUuid);
    } on DioException catch (e) {
      if (!CompteApi.estHorsLigne(e)) rethrow;
      if (!await auth.reprendreSessionMembreHorsLigne(espace.membreUuid)) {
        erreur =
            'Pas de connexion internet. Ouvrez cet espace une première fois en ligne.';
        return false;
      }
    }
    await _changerDEspace(espace.membreUuid);
    return true;
  });

  /// Retour à « Ma santé » : la session du membre se ferme, celle de la
  /// personne reste.
  Future<bool> quitterEspace(AuthController auth) => _action(() async {
    if (!await _envoyerEnAttente()) return false;
    await auth.logout();
    await _changerDEspace(null);
    return true;
  });

  /// « Je suis professionnel de santé » : la partie pro s'ouvre, sans second
  /// compte (« Ma santé » reste la sienne).
  Future<bool> devenirPro() => _action(() async {
    await _api.devenirPro();
    await rafraichir();
    return true;
  });

  /// La personne crée son établissement et ouvre aussitôt son espace.
  Future<bool> creerEtablissement({
    required String nom,
    required String profil,
    required String autorisation,
    required String responsable,
    required AuthController auth,
  }) => _action(() async {
    if (!await _envoyerEnAttente()) return false;
    final membreUuid = uuidV4();
    final data = await _api.creerEtablissement(
      nom: nom,
      profil: profil,
      uuid: uuidV4(),
      membreUuid: membreUuid,
      autorisation: autorisation,
      responsable: responsable,
    );
    await auth.ouvrirSessionMembre(data, membreUuid);
    await rafraichir();
    await _changerDEspace(membreUuid);
    return true;
  });

  Future<void> deconnexion(AuthController auth) async {
    await SyncManager.instance.syncNow();
    try {
      await _api.deconnexion();
    } catch (_) {}
    await auth.logout();
    await TokenStorage.clearPersonneToken();
    await LocalStore.remove(_clePersonne);
    await LocalStore.remove(_cleEspaces);
    await LocalStore.remove(_cleEspaceActif);
    personne = null;
    espaces = [];
    espaceActif = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ interne

  /// Les opérations hors ligne en attente appartiennent à l'espace ouvert :
  /// elles partent avec son jeton avant qu'on en change, sinon elles
  /// arriveraient dans un autre établissement.
  Future<bool> _envoyerEnAttente() async {
    if (SyncQueue.getAll().isEmpty) return true;
    await SyncManager.instance.syncNow();
    final restantes = SyncQueue.getAll().length;
    if (restantes == 0) return true;
    erreur =
        '$restantes opération(s) attendent d’être envoyées. Connectez-vous à internet avant de changer d’espace.';
    return false;
  }

  Future<void> _changerDEspace(String? membreUuid) async {
    if (membreUuid != espaceActif) await OfflineMirror.viderTout();
    espaceActif = membreUuid;
    if (membreUuid == null) {
      await LocalStore.remove(_cleEspaceActif);
    } else {
      await LocalStore.write(_cleEspaceActif, membreUuid);
    }
  }

  Future<bool> _action(Future<bool> Function() action) async {
    chargement = true;
    erreur = null;
    notifyListeners();
    try {
      return await action();
    } on DioException catch (e) {
      erreur = _message(e);
      return false;
    } catch (_) {
      erreur = 'Une erreur est survenue. Réessayez.';
      return false;
    } finally {
      chargement = false;
      notifyListeners();
    }
  }

  Future<void> _enregistrerConnexion(
    Map<String, dynamic> data,
    String paysCode,
    String telephone,
    String pin,
  ) async {
    final token = (data['access_token'] ?? '').toString();
    if (token.isEmpty) throw StateError('Jeton manquant');
    await TokenStorage.savePersonneToken(token);
    _appliquer(data);
    await _memoriser();

    // De quoi se reconnecter hors ligne sur ce téléphone.
    final cle = _cleCache(paysCode, telephone);
    await PinCache.save(cle, pin);
    await LocalStore.write('compte_hl_$cle', {
      'personne': personne!.toJson(),
      'espaces': espaces.map((e) => e.toJson()).toList(),
    });
  }

  void _appliquer(Map<String, dynamic> data) {
    final p = data['personne'];
    if (p is Map) personne = Personne.fromJson(Map<String, dynamic>.from(p));
    final e = data['espaces'];
    if (e is List) {
      espaces = e
          .whereType<Map>()
          .map((m) => Espace.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
  }

  Future<void> _memoriser() async {
    if (personne != null) {
      await LocalStore.write(_clePersonne, personne!.toJson());
    }
    await LocalStore.write(
      _cleEspaces,
      espaces.map((e) => e.toJson()).toList(),
    );
  }

  List<Espace> _lireEspacesEnCache() {
    final brut = LocalStore.read<List<dynamic>>(_cleEspaces);
    if (brut == null) return [];
    return brut
        .whereType<Map>()
        .map((m) => Espace.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  void _lireReferentielEnCache() {
    final p = LocalStore.read<List<dynamic>>(_clePays);
    if (p != null && p.isNotEmpty) {
      pays = p
          .whereType<Map>()
          .map((m) => Pays.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    final pr = LocalStore.read<List<dynamic>>(_cleProfils);
    if (pr != null && pr.isNotEmpty) {
      profils = pr
          .whereType<Map>()
          .map(
            (m) => ProfilEtablissement.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList();
    }
  }

  Future<void> _rafraichirReferentiel() async {
    try {
      final p = await _api.pays();
      if (p['data'] is List && (p['data'] as List).isNotEmpty) {
        pays = (p['data'] as List)
            .whereType<Map>()
            .map((m) => Pays.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        await LocalStore.write(_clePays, pays.map((x) => x.toJson()).toList());
      }
      final pr = await _api.profils();
      if (pr['data'] is List && (pr['data'] as List).isNotEmpty) {
        profils = (pr['data'] as List)
            .whereType<Map>()
            .map(
              (m) => ProfilEtablissement.fromJson(Map<String, dynamic>.from(m)),
            )
            .toList();
        await LocalStore.write(
          _cleProfils,
          profils.map((x) => x.toJson()).toList(),
        );
      }
      notifyListeners();
    } catch (_) {
      // Hors ligne : les listes en cache (ou de secours) suffisent.
    }
  }

  /// Clé du cache hors ligne : le pays et les chiffres saisis.
  String _cleCache(String paysCode, String telephone) =>
      '$paysCode:${telephone.replaceAll(RegExp(r'\D'), '')}';

  String _message(DioException e) => messageErreur(e);
}
