import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/utils/kcolors.dart';
import '../../rdv/rdv_models.dart';

/// Choisir un jour (les 7 prochains, ou « Autre date… » jusqu'à
/// [horizonJours]) puis une heure libre. Sert à l'accueil comme au patient ;
/// [charger] lit les créneaux du jour choisi.
class ChoixCreneau extends StatefulWidget {
  const ChoixCreneau({
    required this.charger,
    required this.onChoisi,
    this.depart,
    this.horizonJours = 365,
    super.key,
  });

  final Future<List<CreneauRdv>> Function(String jour) charger;
  final ValueChanged<CreneauRdv?> onChoisi;
  final DateTime? depart;

  /// Jusqu'où l'agenda prend des rendez-vous.
  final int horizonJours;

  @override
  State<ChoixCreneau> createState() => _ChoixCreneauState();
}

class _ChoixCreneauState extends State<ChoixCreneau> {
  late DateTime _jour = widget.depart ?? DateTime.now();
  List<CreneauRdv>? _creneaux;
  CreneauRdv? _choisi;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  // Pas de rechargement à chaque reconstruction du parent : sa fonction
  // [charger] est recréée à chaque fois, et choisir une heure le reconstruit.
  // Un autre agenda passe une autre clé, qui recrée ce widget.

  Future<void> _charger() async {
    setState(() {
      _creneaux = null;
      _choisi = null;
      _erreur = null;
    });
    widget.onChoisi(null);
    try {
      final c = await widget.charger(DateFormat('yyyy-MM-dd').format(_jour));
      if (mounted) setState(() => _creneaux = c);
    } catch (_) {
      if (mounted) {
        setState(() => _erreur = 'Impossible de charger les heures libres.');
      }
    }
  }

  /// Un jour plus loin que la semaine : le calendrier.
  Future<void> _autreDate() async {
    final aujourdhui = DateUtils.dateOnly(DateTime.now());
    final choix = await showDatePicker(
      context: context,
      initialDate: _jour.isBefore(aujourdhui)
          ? aujourdhui
          : (_jour.isAfter(aujourdhui.add(Duration(days: widget.horizonJours)))
                ? aujourdhui
                : _jour),
      firstDate: aujourdhui,
      lastDate: aujourdhui.add(Duration(days: widget.horizonJours)),
      helpText: 'Jour du rendez-vous',
    );
    if (choix == null || !mounted) return;
    setState(() => _jour = choix);
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final aujourdhui = DateTime.now();
    final jours = List.generate(
      7,
      (i) => DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day + i),
    );
    // Le jour choisi au calendrier, hors de la semaine, garde sa puce.
    if (!jours.any((j) => DateUtils.isSameDay(j, _jour))) {
      jours.add(DateUtils.dateOnly(_jour));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final j in jours)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat('EEE', 'fr').format(j)),
                        Text(
                          '${j.day}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    selected: DateUtils.isSameDay(j, _jour),
                    onSelected: (_) {
                      setState(() => _jour = j);
                      _charger();
                    },
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('Autre date…'),
                onPressed: _autreDate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_erreur != null)
          Text(_erreur!, style: const TextStyle(color: Kolors.kRed))
        else if (_creneaux == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_creneaux!.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Plus d’heure libre ce jour-là. Essayez un autre jour.',
              style: TextStyle(color: Kolors.kTextMuted),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _creneaux!)
                ChoiceChip(
                  label: Text(c.heure),
                  selected: _choisi == c,
                  onSelected: (_) {
                    setState(() => _choisi = c);
                    widget.onChoisi(c);
                  },
                ),
            ],
          ),
      ],
    );
  }
}
