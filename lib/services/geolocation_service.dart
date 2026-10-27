import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Géolocalisation des établissements + ouverture d'itinéraire Google Maps.
class GeolocationService {
  /// Position actuelle de l'appareil (gère les permissions). Null si refusé
  /// ou service désactivé.
  static Future<Position?> currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    // Sans délai, un GPS lent (intérieur, zone rurale) bloquait l'écran
    // indéfiniment : 8 s au plus, sinon la dernière position connue.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// URL Google Maps en mode itinéraire vers (lat, lng). Le point de départ
  /// (position de l'utilisateur) est fourni automatiquement par Google Maps.
  static String directionsUrl(double latitude, double longitude) =>
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';

  /// Ouvre l'itinéraire dans l'app cartographique externe.
  static Future<bool> openItinerary(double latitude, double longitude) async {
    final uri = Uri.parse(directionsUrl(latitude, longitude));
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
