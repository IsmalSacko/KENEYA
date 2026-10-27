import 'package:flutter/material.dart';

/// Partout dans l'app, le texte se sélectionne et se copie (un numéro de
/// dossier, un téléphone, un message d'erreur), d'un appui long.
///
/// La sélection a besoin d'un calque au-dessus pour ses poignées et son
/// menu « Copier » : on le pose ici, autour de toute la navigation.
class ToutSelectionnable extends StatefulWidget {
  const ToutSelectionnable({required this.child, super.key});

  final Widget child;

  @override
  State<ToutSelectionnable> createState() => _ToutSelectionnableState();
}

class _ToutSelectionnableState extends State<ToutSelectionnable> {
  late final _calque = OverlayEntry(
    builder: (_) => SelectionArea(child: widget.child),
  );

  @override
  void didUpdateWidget(ToutSelectionnable ancien) {
    super.didUpdateWidget(ancien);
    _calque.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_calque]);
}
