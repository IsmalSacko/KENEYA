import 'dart:io';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

class ApiClient {
  static final Dio dio =
      Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Accept': 'application/json'},
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await TokenStorage.getToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
          ),
        );

  static bool isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        (e.type == DioExceptionType.unknown && e.error is SocketException);
  }
}

/// Message à montrer pour une erreur d'API, toujours en français.
String messageErreur(
  DioException e, {
  String defaut = 'Une erreur est survenue. Réessayez.',
}) {
  if (ApiClient.isNetworkError(e)) {
    return 'Pas de connexion internet. Réessayez.';
  }
  if (e.response?.statusCode == 429) {
    return 'Trop d’essais. Patientez une minute, puis réessayez.';
  }
  final data = e.response?.data;
  final message = data is Map ? data['message']?.toString() : null;
  // Messages techniques de Laravel, en anglais : jamais montrés tels quels.
  if (e.response?.statusCode == 404 &&
      (message == null ||
          message.startsWith('The route') ||
          message.startsWith('No query results'))) {
    return 'Introuvable : cet élément n’existe plus, ou l’app doit être mise à jour.';
  }
  // Erreurs de saisie : toutes, une par ligne, plutôt que la première
  // suivie de « (et 1 autre erreur) ».
  final erreurs = data is Map ? data['errors'] : null;
  if (e.response?.statusCode == 422 && erreurs is Map && erreurs.isNotEmpty) {
    return [
      for (final l in erreurs.values)
        if (l is List && l.isNotEmpty) l.first.toString(),
    ].join('\n');
  }
  if (message != null && message.isNotEmpty) return message;
  return defaut;
}
