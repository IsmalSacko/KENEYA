import 'package:url_launcher/url_launcher.dart';

/// Ouvre Google Maps en itinéraire vers (lat, lng). La position de départ
/// (l'utilisateur) est fournie automatiquement par Google Maps.
class MapsLauncher {
  static String directionsUrl(double lat, double lng) =>
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

  static Future<bool> openItinerary(double lat, double lng) async {
    final uri = Uri.parse(directionsUrl(lat, lng));
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> call(String telephone) async {
    final uri = Uri(scheme: 'tel', path: telephone);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }
}
