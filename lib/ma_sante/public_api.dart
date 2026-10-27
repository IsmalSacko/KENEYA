import '../core/api/api_client.dart';
import 'etablissement_public.dart';

/// Accès aux endpoints publics du backend (aucune authentification requise).
class PublicApi {
  /// Recherche d'établissements de santé, triés par proximité si lat/lng fournis.
  Future<List<Etablissement>> search({
    double? lat,
    double? lng,
    String? profil,
    String? query,
    double? radiusKm,
  }) async {
    final res = await ApiClient.dio.get(
      '/public/etablissements',
      queryParameters: {
        'lat': ?lat,
        'lng': ?lng,
        'profil': ?profil,
        'q': ?(query != null && query.isNotEmpty ? query : null),
        'radius_km': ?radiusKm,
      },
    );

    final data = res.data;
    final list = (data is Map && data['data'] is List)
        ? data['data'] as List
        : const <dynamic>[];

    return list
        .whereType<Map>()
        .map((e) => Etablissement.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Prise de rendez-vous (statut initial « demande »). Idempotent via [uuid].
  Future<Map<String, dynamic>> book({
    required String uuid,
    required String etablissementUuid,
    String? medecinUuid,
    required String patientNom,
    required String patientTelephone,
    required DateTime dateSouhaitee,
    String? motif,
  }) async {
    final res = await ApiClient.dio.post(
      '/public/rendez-vous',
      data: {
        'uuid': uuid,
        'etablissement_uuid': etablissementUuid,
        'medecin_uuid': ?medecinUuid,
        'patient_nom': patientNom,
        'patient_telephone': patientTelephone,
        'date_souhaitee': dateSouhaitee.toIso8601String(),
        'motif': ?(motif != null && motif.isNotEmpty ? motif : null),
      },
    );

    return Map<String, dynamic>.from(res.data as Map);
  }
}
