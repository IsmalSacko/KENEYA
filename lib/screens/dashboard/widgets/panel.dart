import 'package:flutter/material.dart';

import '../../../common/utils/kcolors.dart';

/// Carte titrée réutilisable pour les écrans de tableau de bord.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Kolors.kWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Kolors.kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0E9F6E),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Kolors.kTextHigh,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
