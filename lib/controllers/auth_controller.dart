import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/offline/local_store.dart';
import '../core/storage/token_storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  static const String _offlineProfileKey = 'offline_provisional_profile';

  bool initializing = true;
  bool loading = false;
  String? error;
  bool offlineProvisionalSession = false;
  String? accessToken;
  UserModel? currentUser;

  /// Droits du membre dans son établissement (`patients.voir`,
  /// `file.appeler`…) et modules actifs de l'établissement.
  List<String> permissions = [];
  List<String> modules = [];
  String? profil;

  /// Officine où le client paie au caissier (le vendeur n'encaisse pas).
  bool caisseSeparee = false;

  /// Vérifié par Ngoni Santé : visible des patients (recherche, tickets, RDV).
  bool etablissementValide = true;

  /// L'abonnement de l'établissement (formule, fin, ce qu'il ouvre) ; null
  /// tant que le serveur ne l'a pas dit.
  Map<String, dynamic>? abonnement;

  /// Échu : le soin continue, la gestion est fermée jusqu'au renouvellement.
  bool get abonnementEchu => abonnement?['en_cours'] == false;
  bool get enEssai => abonnement?['essai'] == true;
  int? get joursRestants => int.tryParse('${abonnement?['jours_restants']}');

  /// Écrans de salle et rapport du mois : inclus dans la formule ?
  bool aFonction(String fonction) {
    final f = abonnement?['fonctions'];
    return f is! List || f.contains(fonction);
  }

  /// Fermé par la formule : le nom de la formule qui l'ouvre (« Pro »), à
  /// afficher avec un cadenas ; null si c'est ouvert.
  String? verrou(String code) {
    final v = abonnement?['verrous'];
    return v is Map ? v[code]?.toString() : null;
  }

  /// Pharmacie ou dépôt : un commerce, où l'on vend plutôt qu'on soigne.
  bool get estOfficine =>
      profil == 'pharmacie' || profil == 'depot_medicaments';
  String devise = 'XOF';

  bool peut(String droit) => permissions.contains(droit);
  bool aModule(String module) => modules.contains(module);

  static const String _contexteKey = 'membre_contexte';

  // Ngoni Santé : profil mémorisé de chaque membre (un par espace pro), et
  // membre à qui appartient le jeton enregistré.
  String _membreProfilKey(String membreUuid) => 'membre_profil_$membreUuid';
  static const String _tokenMembreKey = 'token_membre_uuid';

  Map<String, dynamic> _profileMap(UserModel u) => {
    'id': u.id,
    'etablissement_id': u.etablissementId,
    'name': u.name,
    'telephone': u.telephone,
    'role': u.role,
    'actif': u.actif,
  };

  UserModel? _parseUser(dynamic userJson) {
    if (userJson is Map<String, dynamic>) return UserModel.fromJson(userJson);
    if (userJson is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(userJson));
    }
    return null;
  }

  bool get isAuthenticated =>
      (accessToken != null && accessToken!.isNotEmpty) ||
      offlineProvisionalSession;

  AuthController() {
    restoreSession();
  }

  Future<void> restoreSession() async {
    initializing = true;
    notifyListeners();

    _lireContexte(LocalStore.read<Map<String, dynamic>>(_contexteKey));
    accessToken = await TokenStorage.getToken();
    if (accessToken == null || accessToken!.isEmpty) {
      final profile = LocalStore.read<Map<String, dynamic>>(_offlineProfileKey);
      if (profile != null) {
        currentUser = UserModel.fromJson(profile);
        offlineProvisionalSession = true;
      }
    } else {
      await refreshCurrentUser();
    }

    initializing = false;
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    if (accessToken == null || accessToken!.isEmpty) return;
    if (offlineProvisionalSession) return;

    try {
      final data = await _authService.moi();
      final user = _parseUser(data['user']);
      if (user != null) currentUser = user;
      await _appliquerContexte(data);
      final membre = LocalStore.read<String>(_tokenMembreKey);
      if (membre != null) {
        await LocalStore.write('${_contexteKey}_$membre', _contexte());
      }
      notifyListeners();
    } catch (_) {
      // Keep session even if profile refresh fails.
    }
  }

  /// Ouvre la session d'un membre (espace pro) avec la réponse de
  /// /compte/espaces ou /compte/etablissements.
  Future<void> ouvrirSessionMembre(
    Map<String, dynamic> data,
    String membreUuid,
  ) async {
    final token = (data['access_token'] ?? '').toString();
    if (token.isEmpty) throw StateError('Jeton manquant');

    accessToken = token;
    currentUser = _parseUser(data['user']);
    offlineProvisionalSession = false;
    await LocalStore.remove(_offlineProfileKey);
    await TokenStorage.saveToken(token);
    await LocalStore.write(_tokenMembreKey, membreUuid);
    await _appliquerContexte(data);
    await LocalStore.write('${_contexteKey}_$membreUuid', _contexte());
    if (currentUser != null) {
      await LocalStore.write(
        _membreProfilKey(membreUuid),
        _profileMap(currentUser!),
      );
    }
    notifyListeners();
  }

  /// Hors ligne : rouvre un espace déjà ouvert sur ce téléphone, avec son
  /// profil mémorisé. Le jeton enregistré n'est gardé que s'il est le sien.
  Future<bool> reprendreSessionMembreHorsLigne(String membreUuid) async {
    final profile = LocalStore.read<Map<String, dynamic>>(
      _membreProfilKey(membreUuid),
    );
    if (profile == null) return false;

    currentUser = UserModel.fromJson(profile);
    _lireContexte(
      LocalStore.read<Map<String, dynamic>>('${_contexteKey}_$membreUuid'),
    );
    await LocalStore.write(_contexteKey, _contexte());
    if (LocalStore.read<String>(_tokenMembreKey) == membreUuid) {
      accessToken = await TokenStorage.getToken();
      offlineProvisionalSession = accessToken == null || accessToken!.isEmpty;
    } else {
      await TokenStorage.clearToken();
      await LocalStore.remove(_tokenMembreKey);
      accessToken = null;
      offlineProvisionalSession = true;
      await LocalStore.write(_offlineProfileKey, profile);
    }
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    loading = true;
    notifyListeners();

    try {
      await _authService.logout();
    } catch (_) {
      // Ignore API logout errors and clear local session.
    } finally {
      await TokenStorage.clearToken();
      await LocalStore.remove(_offlineProfileKey);
      await LocalStore.remove(_tokenMembreKey);
      await LocalStore.remove(_contexteKey);
      permissions = [];
      modules = [];
      profil = null;
      accessToken = null;
      currentUser = null;
      offlineProvisionalSession = false;
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String telephone,
    String? pin,
  }) async {
    final userId = currentUser?.id;
    if (offlineProvisionalSession) {
      currentUser = UserModel(
        id: currentUser?.id ?? -1,
        etablissementId: currentUser?.etablissementId,
        name: name,
        telephone: telephone,
        role: currentUser?.role ?? 'admin',
        actif: currentUser?.actif ?? true,
      );
      await LocalStore.write(_offlineProfileKey, {
        'id': currentUser!.id,
        'etablissement_id': currentUser!.etablissementId,
        'name': currentUser!.name,
        'telephone': currentUser!.telephone,
        'role': currentUser!.role,
        'actif': currentUser!.actif,
      });
      notifyListeners();
      return true;
    }

    if (userId == null || userId <= 0) {
      error = 'Utilisateur invalide.';
      notifyListeners();
      return false;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{'name': name, 'telephone': telephone};
      if (pin != null && pin.trim().isNotEmpty) {
        payload['pin'] = pin.trim();
      }
      final data = await _authService.updateProfile(
        userId: userId,
        payload: payload,
      );
      final userJson = data['user'];
      if (userJson is Map<String, dynamic>) {
        currentUser = UserModel.fromJson(userJson);
      } else if (userJson is Map) {
        currentUser = UserModel.fromJson(Map<String, dynamic>.from(userJson));
      } else {
        currentUser = UserModel(
          id: currentUser!.id,
          etablissementId: currentUser!.etablissementId,
          name: name,
          telephone: telephone,
          role: currentUser!.role,
          actif: currentUser!.actif,
        );
      }

      if (offlineProvisionalSession) {
        await LocalStore.write(_offlineProfileKey, {
          'id': currentUser!.id,
          'etablissement_id': currentUser!.etablissementId,
          'name': currentUser!.name,
          'telephone': currentUser!.telephone,
          'role': currentUser!.role,
          'actif': currentUser!.actif,
        });
      }
      return true;
    } on DioException catch (e) {
      error = _extractApiMessage(e) ?? 'Echec de mise a jour du profil.';
      return false;
    } catch (_) {
      error = 'Echec de mise a jour du profil.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Droits et établissement renvoyés par /me ou à l'ouverture d'un espace.
  Future<void> _appliquerContexte(Map<String, dynamic> data) async {
    _lireContexte({
      'permissions': data['permissions'],
      'etablissement': data['etablissement'],
      'abonnement': data['abonnement'],
    });
    await LocalStore.write(_contexteKey, _contexte());
  }

  void _lireContexte(Map<String, dynamic>? contexte) {
    if (contexte == null) return;
    final p = contexte['permissions'];
    if (p is List) permissions = p.map((e) => e.toString()).toList();
    final a = contexte['abonnement'];
    abonnement = a is Map ? Map<String, dynamic>.from(a) : null;
    final e = contexte['etablissement'];
    if (e is Map) {
      final m = e['modules'];
      if (m is List) modules = m.map((x) => x.toString()).toList();
      profil = e['profil']?.toString();
      devise = (e['devise'] ?? devise).toString();
      caisseSeparee = e['caisse_separee'] == true;
      if (e.containsKey('valide_at')) {
        etablissementValide = e['valide_at'] != null;
      }
    }
  }

  /// Après un renouvellement : le nouvel état, sans attendre la reconnexion.
  Future<void> majAbonnement(Map<String, dynamic> etat) async {
    abonnement = etat;
    await LocalStore.write(_contexteKey, _contexte());
    notifyListeners();
  }

  Map<String, dynamic> _contexte() => {
    'permissions': permissions,
    'abonnement': abonnement,
    'etablissement': {
      'modules': modules,
      'profil': profil,
      'devise': devise,
      'caisse_separee': caisseSeparee,
      'valide_at': etablissementValide ? 'oui' : null,
    },
  };

  String? _extractApiMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }
}
