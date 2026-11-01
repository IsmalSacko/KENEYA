import 'package:flutter/foundation.dart';

/// iPhone et iPad : Apple interdit de payer un abonnement autrement que par
/// son propre système (règles 3.1.1 et 3.1.3 de l'App Store), et même d'y
/// renvoyer par un bouton ou un lien. Les formules s'y achètent par l'achat
/// intégré d'Apple ; ailleurs, par Orange Money, Wave… que Ngoni Santé valide.
bool get achatsInterdits =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
