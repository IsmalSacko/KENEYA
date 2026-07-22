class ApiConstants {
  // Back-end KENEYA sous Docker : nginx (conteneur keneya_nginx) expose l'API
  // sur le port 8000 de l'hote, prefixe /api.
  // Choisir l'hote selon la cible d'execution :
  //
  //   - Emulateur Android                 : http://10.0.2.2:8000/api  (actif)
  //   - iOS Simulator / Desktop / Web      : http://localhost:8000/api
  //   - Appareil physique (meme reseau)    : http://192.168.2.19:8000/api  (IP LAN de l'hote)
  //
  // Surchargeable au lancement sans editer ce fichier :
  //   flutter run --dart-define=API_URL=http://192.168.2.19:8000/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
}
