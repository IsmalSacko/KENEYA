import 'package:flutter/widgets.dart';

/// Permet à un écran de l'accueil d'ouvrir un autre onglet par son nom
/// (« File d’attente », « Caisse »…), par exemple depuis « À faire ».
class OuvrirOnglet extends InheritedWidget {
  const OuvrirOnglet({
    required this.ouvrirOnglet,
    required super.child,
    super.key,
  });

  final void Function(String titre) ouvrirOnglet;

  static void ouvrir(BuildContext context, String titre) => context
      .getInheritedWidgetOfExactType<OuvrirOnglet>()
      ?.ouvrirOnglet(titre);

  @override
  bool updateShouldNotify(OuvrirOnglet oldWidget) => false;
}
