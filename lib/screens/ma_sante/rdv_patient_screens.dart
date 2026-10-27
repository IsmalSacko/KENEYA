import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../compte/compte_api.dart';
import '../../compte/mes_tickets_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/options_serveur.dart';
import '../../file/file_models.dart';
import '../../ma_sante/etablissement_public.dart';
import '../../rdv/rdv_models.dart';
import '../commun/scanner_qr_screen.dart';
import '../file/ticket_carte.dart';
import '../rdv/choix_creneau.dart';

/// Réserver un créneau dans un établissement : l'agenda, le jour, l'heure.
class PrendreRdvScreen extends StatefulWidget {
  const PrendreRdvScreen({
    required this.etablissement,
    required this.agendas,
    super.key,
  });

  final Etablissement etablissement;
  final List<Map<String, dynamic>> agendas;

  @override
  State<PrendreRdvScreen> createState() => _PrendreRdvScreenState();
}

class _PrendreRdvScreenState extends State<PrendreRdvScreen> {
  final _api = CompteApi();
  final _motif = TextEditingController();
  late String _agenda = widget.agendas.first['uuid'].toString();
  CreneauRdv? _creneau;
  bool _envoi = false;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<void> _reserver() async {
    if (_creneau == null) return;
    setState(() => _envoi = true);
    try {
      final data = await _api.reserverRdv(
        agendaUuid: _agenda,
        debut: _creneau!.debut,
        motif: _motif.text.trim(),
      );
      final rdv = RendezVousRdv.fromJson(
        Map<String, dynamic>.from(data['rendez_vous'] as Map),
      );
      if (!mounted) return;
      await afficherRdv(context, rdv);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prendre rendez-vous')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.etablissement.nom,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Kolors.kTextHigh,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.agendas.length > 1) ...[
            const Text(
              'Avec qui ?',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in widget.agendas)
                  ChoiceChip(
                    label: Text(a['nom'].toString()),
                    selected: _agenda == a['uuid'],
                    onSelected: (_) =>
                        setState(() => _agenda = a['uuid'].toString()),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          const Text('Quand ?', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ChoixCreneau(
            key: ValueKey(_agenda),
            charger: (jour) async => (await _api.creneaux(
              _agenda,
              jour,
              jour,
            )).map(CreneauRdv.fromJson).toList(),
            onChoisi: (c) => setState(() => _creneau = c),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _motif,
            decoration: const InputDecoration(labelText: 'Motif (facultatif)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _creneau == null || _envoi ? null : _reserver,
              child: Text(
                _creneau == null
                    ? 'Choisissez une heure'
                    : 'Réserver à ${_creneau!.heure}',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              OptionsServeur.sms
                  ? 'Vous recevrez un rappel par SMS la veille et peu avant.'
                  : 'Votre rendez-vous sera dans « Mes rendez-vous ». Le centre peut vous le rappeler sur WhatsApp.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Kolors.kTextMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le rendez-vous et son QR, à montrer à l'accueil ou à la borne.
Future<void> afficherRdv(BuildContext context, RendezVousRdv r) {
  final quand = r.date;
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CarteMarque(
                child: Column(
                  children: [
                    Text(
                      r.etablissementNom,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Kolors.kWhite.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      quand == null
                          ? r.heure
                          : DateFormat('EEEE d MMMM', 'fr').format(quand),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      r.heure,
                      style: GoogleFonts.poppins(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: Kolors.kJaune,
                      ),
                    ),
                    if (r.agendaNom != null) Text(r.agendaNom!),
                    const SizedBox(height: 6),
                    Text(
                      r.statut == 'demande'
                          ? 'En attente de confirmation'
                          : (r.statut == 'confirme'
                                ? 'Confirmé'
                                : r.statutLabel),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (r.actif && r.qr.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Kolors.kWhite,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(data: r.qr, size: 160),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'À l’arrivée : montrez ce QR, ou scannez l’affiche de l’accueil.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Kolors.kWhite.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Mes rendez-vous : à venir (avec leur QR), puis passés.
class MesRdvScreen extends StatefulWidget {
  const MesRdvScreen({super.key});

  @override
  State<MesRdvScreen> createState() => _MesRdvScreenState();
}

class _MesRdvScreenState extends State<MesRdvScreen> {
  final _api = CompteApi();
  List<RendezVousRdv>? _rdv;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final d = await _api.mesRdv();
      if (mounted) {
        setState(() => _rdv = d.map(RendezVousRdv.fromJson).toList());
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Future<void> _annuler(RendezVousRdv r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: const Text('La place sera proposée à quelqu’un d’autre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.annulerRdv(r.uuid);
      await _charger();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes rendez-vous')),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => jeSuisArrive(context),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text(
                'Je suis arrivé : scanner l’affiche de l’accueil',
              ),
            ),
            const SizedBox(height: 16),
            if (_erreur != null)
              Text(_erreur!, style: const TextStyle(color: Kolors.kRed))
            else if (_rdv == null)
              const Center(child: CircularProgressIndicator())
            else if (_rdv!.isEmpty)
              const Text(
                'Aucun rendez-vous. Trouvez un établissement pour en prendre un.',
                style: TextStyle(color: Kolors.kTextMuted),
              )
            else
              for (final r in _rdv!)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: r.actif
                          ? Kolors.kPrimary
                          : Kolors.kGrayLight,
                      child: Icon(
                        r.actif
                            ? Icons.event_available_rounded
                            : Icons.event_busy_rounded,
                        color: r.actif ? Kolors.kJaune : Kolors.kTextMuted,
                      ),
                    ),
                    title: Text(
                      '${r.date == null ? r.jour : DateFormat('EEE d MMM', 'fr').format(r.date!)} · ${r.heure}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        r.etablissementNom,
                        if (r.agendaNom != null) r.agendaNom!,
                        r.statutLabel,
                      ].join(' · '),
                    ),
                    onTap: () => afficherRdv(context, r),
                    trailing: r.actif
                        ? IconButton(
                            tooltip: 'Annuler',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => _annuler(r),
                          )
                        : null,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// La personne scanne l'affiche de l'accueil : si elle a rendez-vous
/// aujourd'hui, elle entre dans la file et voit son ticket.
Future<void> jeSuisArrive(BuildContext context) async {
  final qr = await scannerQr(
    context,
    titre: 'Je suis arrivé',
    consigne: 'Scannez l’affiche Ngoni Santé de l’accueil',
  );
  if (qr == null || !context.mounted) return;
  try {
    final data = await CompteApi().arrivee(qr);
    final ticket = TicketFile.fromJson(
      Map<String, dynamic>.from(data['ticket'] as Map),
    );
    if (!context.mounted) return;
    context.read<MesTicketsController>().rafraichir();
    await afficherTicket(context, ticket, imprimer: false);
  } on DioException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
    }
  }
}

/// La carte santé : le QR que l'accueil scanne pour retrouver la personne.
class CarteSanteScreen extends StatefulWidget {
  const CarteSanteScreen({super.key});

  @override
  State<CarteSanteScreen> createState() => _CarteSanteScreenState();
}

class _CarteSanteScreenState extends State<CarteSanteScreen> {
  final _api = CompteApi();
  Map<String, dynamic>? _carte;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _api
        .carte()
        .then((c) {
          if (mounted) setState(() => _carte = c);
        })
        .catchError((Object e) {
          if (mounted) {
            setState(
              () => _erreur = e is DioException
                  ? messageErreur(e)
                  : 'Carte indisponible.',
            );
          }
        });
  }

  Future<void> _renouveler() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Carte perdue ?'),
        content: const Text(
          'Un nouveau QR remplace l’ancien, qui ne marchera plus. Réimprimez votre carte ensuite.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nouveau QR'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final c = await _api.renouvelerCarte();
    if (mounted) setState(() => _carte = c);
  }

  @override
  Widget build(BuildContext context) {
    final c = _carte;
    return Scaffold(
      appBar: AppBar(title: const Text('Ma carte santé')),
      body: Center(
        child: c == null
            ? (_erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CarteMarque(
                          child: Column(
                            children: [
                              Text(
                                c['nom'].toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(c['telephone'].toString()),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Kolors.kWhite,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: QrImageView(
                                  data: c['qr'].toString(),
                                  size: 220,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'À l’accueil, montrez ce QR : vous êtes reconnu tout de suite.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Kolors.kWhite.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _renouveler,
                          child: const Text('Carte perdue : nouveau QR'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
