import 'package:flutter/material.dart';

/// Une feuille de choix ou de saisie. Au téléphone, elle monte du bas ; sur
/// tablette, elle s'ouvre au centre, à une largeur lisible, au lieu de
/// s'étirer collée en bas de l'écran.
///
/// Mêmes paramètres que [showModalBottomSheet], pour s'y substituer.
Future<T?> feuille<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
}) {
  if (MediaQuery.sizeOf(context).shortestSide < 600) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      useSafeArea: true,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        // Pas de poignée sur une fenêtre : un peu d'air en haut à la place.
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: builder(ctx),
        ),
      ),
    ),
  );
}
