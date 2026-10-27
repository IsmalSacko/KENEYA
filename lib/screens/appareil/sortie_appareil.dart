import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../file/appareil_api.dart';

/// Un appui long de 3 secondes sur l'écran propose de quitter le mode
/// écran ou borne (l'appareil redevient un téléphone normal).
class SortieAppareil extends StatelessWidget {
  const SortieAppareil({
    required this.child,
    required this.onQuitter,
    super.key,
  });

  final Widget child;
  final VoidCallback onQuitter;

  Future<void> _demander(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter ce mode ?'),
        content: const Text(
          'Cet appareil ne sera plus un écran ou une borne de l’établissement. Il faudra un nouveau code pour l’appairer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AppareilApi.oublier();
    onQuitter();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(seconds: 3),
              ),
              (r) => r.onLongPress = () => _demander(context),
            ),
      },
      child: child,
    );
  }
}
