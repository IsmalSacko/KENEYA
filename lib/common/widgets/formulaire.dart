import 'package:flutter/material.dart';

/// Un formulaire de saisie en plein écran. Une fenêtre (AlertDialog) n'a
/// plus de place quand le clavier s'ouvre sur une tablette en paysage : ici
/// la page défile, les boutons restent au-dessus du clavier.
///
/// [corps] et [actions] reçoivent le `setState` de la page ; une action
/// ferme avec `Navigator.pop(ctx, valeur)`.
Future<T?> formulaire<T>(
  BuildContext context, {
  required Widget titre,
  required Widget Function(BuildContext ctx, StateSetter setState) corps,
  required List<Widget> Function(BuildContext ctx, StateSetter setState)
  actions,
}) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      fullscreenDialog: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => PageFormulaire(
          titre: titre,
          corps: corps(ctx, setState),
          actions: actions(ctx, setState),
        ),
      ),
    ),
  );
}

/// La page d'un formulaire : titre, champs qui défilent, boutons en bas.
class PageFormulaire extends StatelessWidget {
  const PageFormulaire({
    required this.titre,
    required this.corps,
    required this.actions,
    super.key,
  });

  final Widget titre;
  final Widget corps;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: titre),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: corps,
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 592),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  // Le thème étire les boutons sur toute la largeur : ici,
                  // côte à côte, ils reprennent leur taille.
                  child: Theme(
                    data: _boutonsCompacts(Theme.of(context)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (final (i, a) in actions.indexed)
                          Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                            child: a,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ThemeData _boutonsCompacts(ThemeData t) {
  const taille = WidgetStatePropertyAll(Size(88, 48));
  return t.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: (t.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: taille,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (t.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: taille,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: (t.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
        minimumSize: taille,
      ),
    ),
  );
}
