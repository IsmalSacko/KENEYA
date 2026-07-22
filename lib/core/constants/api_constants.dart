class ApiConstants {
  // Back-end KENEYA en PRODUCTION : expose derriere Traefik/nginx en HTTPS
  // (certificat Let's Encrypt) sur https://keneya.ismaeldev.fr, prefixe /api.
  //
  // Valeur par defaut = PRODUCTION (utilisee par les builds release / Play Store).
  //
  // Pour cibler un back-end LOCAL en developpement, surcharger au lancement
  // sans editer ce fichier (--dart-define) selon la cible d'execution :
  //
  //   - Emulateur Android                 : http://10.0.2.2:8000/api
  //   - iOS Simulator / Desktop / Web      : http://localhost:8000/api
  //   - Appareil physique (meme reseau)    : http://192.168.2.19:8000/api  (IP LAN de l'hote)
  //
  //   flutter run --dart-define=API_URL=http://10.0.2.2:8000/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://keneya.ismaeldev.fr/api',
  );
}
