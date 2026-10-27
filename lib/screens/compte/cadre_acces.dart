import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../common/utils/kcolors.dart';
import '../../compte/compte_models.dart';

/// Écrans d'accès (connexion, inscription, PIN oublié) : fond bleu nuit et
/// carte blanche, comme les écrans d'accès de Ngoni Caisse.
class CadreAcces extends StatelessWidget {
  const CadreAcces({
    required this.titre,
    required this.sousTitre,
    required this.children,
    super.key,
  });

  final String titre;
  final String sousTitre;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Kolors.kWhite,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Kolors.heroGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Kolors.kWhite,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Kolors.kPrimaryDark.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        titre,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Kolors.kTextHigh,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Petit trait jaune sous le titre.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Kolors.kJaune,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        sousTitre,
                        style: const TextStyle(
                          color: Kolors.kTextMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Numéro de téléphone avec le pays devant (drapeau et indicatif).
class ChampTelephone extends StatelessWidget {
  const ChampTelephone({
    required this.pays,
    required this.paysChoisi,
    required this.onPays,
    required this.controller,
    super.key,
  });

  final List<Pays> pays;
  final String paysChoisi;
  final ValueChanged<String> onPays;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final courant =
        pays.where((p) => p.code == paysChoisi).firstOrNull ?? pays.first;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d +]'))],
      decoration: InputDecoration(
        labelText: 'Numéro de téléphone',
        prefixIcon: PopupMenuButton<String>(
          tooltip: 'Pays',
          initialValue: courant.code,
          onSelected: onPays,
          itemBuilder: (_) => [
            for (final p in pays)
              PopupMenuItem(value: p.code, child: Text(p.libelle)),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(courant.drapeau, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(
                  '+${courant.indicatif}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Kolors.kTextHigh,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Kolors.kTextMuted),
              ],
            ),
          ),
        ),
      ),
      validator: (v) {
        final chiffres = (v ?? '').replaceAll(RegExp(r'\D'), '');
        return chiffres.length < 7 ? 'Numéro de téléphone invalide' : null;
      },
    );
  }
}

/// PIN de 4 à 6 chiffres.
class ChampPin extends StatefulWidget {
  const ChampPin({
    required this.controller,
    this.label = 'PIN',
    this.onSubmitted,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  State<ChampPin> createState() => _ChampPinState();
}

class _ChampPinState extends State<ChampPin> {
  bool _cache = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: TextInputType.number,
      obscureText: _cache,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: widget.onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        counterText: '',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _cache = !_cache),
          icon: Icon(
            _cache ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator:
          widget.validator ??
          (v) => (v ?? '').length < 4 ? 'Le PIN a 4 à 6 chiffres' : null,
    );
  }
}

/// Bouton principal des écrans d'accès, avec l'attente intégrée.
class BoutonAcces extends StatelessWidget {
  const BoutonAcces({
    required this.label,
    required this.onPressed,
    this.chargement = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool chargement;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: chargement ? null : onPressed,
        child: chargement
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Kolors.kWhite,
                ),
              )
            : Text(label),
      ),
    );
  }
}

void afficherMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
