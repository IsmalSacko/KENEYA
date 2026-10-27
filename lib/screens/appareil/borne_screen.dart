import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../common/utils/kcolors.dart';
import '../../file/appareil_api.dart';
import '../../file/file_models.dart';
import '../../file/impression_ticket.dart';
import '../../core/api/api_client.dart';
import '../commun/scanner_qr_screen.dart';
import '../file/ticket_carte.dart';
import 'sortie_appareil.dart';

/// La borne de l'entrée : « Prenez votre ticket ». Trois touches au plus,
/// pour quelqu'un qui n'a jamais vu l'appareil.
class BorneScreen extends StatefulWidget {
  const BorneScreen({required this.onQuitter, super.key});

  final VoidCallback onQuitter;

  @override
  State<BorneScreen> createState() => _BorneScreenState();
}

enum _Etape { service, priorite, telephone, ticket }

class _BorneScreenState extends State<BorneScreen> {
  List<Map<String, dynamic>> _services = [];
  _Etape _etape = _Etape.service;
  String? _service;
  bool _prioritaire = false;
  final _telephone = TextEditingController();
  TicketFile? _ticket;
  bool _envoi = false;
  String? _erreur;
  Timer? _retour;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _charger();
  }

  @override
  void dispose() {
    _retour?.cancel();
    _telephone.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final services = await AppareilApi.services();
      if (mounted) setState(() => _services = services);
    } on DioException catch (e) {
      if (AppareilApi.estRevoque(e)) {
        await AppareilApi.oublier();
        widget.onQuitter();
        return;
      }
      if (mounted) setState(() => _erreur = 'Pas de connexion internet.');
      Future.delayed(const Duration(seconds: 10), _charger);
    }
  }

  void _recommencer() {
    _retour?.cancel();
    _telephone.clear();
    setState(() {
      _etape = _Etape.service;
      _service = null;
      _prioritaire = false;
      _ticket = null;
      _erreur = null;
    });
  }

  /// Le patient montre le QR de son rendez-vous : il entre dans la file.
  Future<void> _rendezVous() async {
    final qr = await scannerQr(
      context,
      titre: 'Votre rendez-vous',
      consigne: 'Montrez le QR de votre rendez-vous à la caméra',
    );
    if (qr == null || !mounted) return;
    setState(() => _envoi = true);
    try {
      final ticket = await AppareilApi.scanRdv(qr);
      setState(() {
        _ticket = ticket;
        _etape = _Etape.ticket;
      });
      if (ImpressionTicket.imprimanteChoisie != null) {
        ImpressionTicket.imprimer(ticket);
      }
      _retour = Timer(const Duration(seconds: 20), _recommencer);
    } on DioException catch (e) {
      setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _emettre() async {
    setState(() => _envoi = true);
    try {
      final ticket = await AppareilApi.emettre(
        serviceUuid: _service!,
        prioritaire: _prioritaire,
        telephone: _telephone.text.trim(),
      );
      setState(() {
        _ticket = ticket;
        _etape = _Etape.ticket;
      });
      if (ImpressionTicket.imprimanteChoisie != null) {
        ImpressionTicket.imprimer(ticket);
      }
      _retour = Timer(const Duration(seconds: 20), _recommencer);
    } on DioException {
      setState(() => _erreur = 'Le ticket n’a pas pu être donné. Réessayez.');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Kolors.kOffWhite,
      body: SortieAppareil(
        onQuitter: widget.onQuitter,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: switch (_etape) {
                  _Etape.service => _choixService(),
                  _Etape.priorite => _choixPriorite(),
                  _Etape.telephone => _choixTelephone(),
                  _Etape.ticket => _vueTicket(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titre(String texte, [String? sous]) => Column(
    children: [
      Text(
        texte,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: Kolors.kPrimary,
        ),
      ),
      if (sous != null) ...[
        const SizedBox(height: 8),
        Text(
          sous,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Kolors.kTextMuted),
        ),
      ],
      const SizedBox(height: 24),
    ],
  );

  Widget _grandBouton(String texte, VoidCallback onTap, {bool jaune = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        height: 76,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: jaune ? Kolors.kJaune : Kolors.kPrimary,
            foregroundColor: jaune ? Kolors.kPrimaryDark : Kolors.kWhite,
            textStyle: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          onPressed: _envoi ? null : onTap,
          child: Text(texte),
        ),
      ),
    );
  }

  Widget _choixService() {
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          (AppareilApi.config?['etablissement'] ?? '').toString(),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Kolors.kTextMuted),
        ),
        const SizedBox(height: 8),
        _titre('Prenez votre ticket', 'Touchez le service où vous allez.'),
        if (_erreur != null)
          Text(
            _erreur!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Kolors.kRed),
          ),
        _grandBouton('J’ai un rendez-vous', _rendezVous, jaune: true),
        const SizedBox(height: 10),
        for (final s in _services)
          _grandBouton(s['nom'].toString(), () {
            setState(() {
              _service = s['uuid'].toString();
              _etape = _Etape.priorite;
            });
          }),
      ],
    );
  }

  Widget _choixPriorite() {
    return ListView(
      shrinkWrap: true,
      children: [
        _titre(
          'Êtes-vous prioritaire ?',
          'Femme enceinte, personne âgée, personne handicapée.',
        ),
        _grandBouton('Oui, je suis prioritaire', () {
          setState(() {
            _prioritaire = true;
            _etape = _Etape.telephone;
          });
        }, jaune: true),
        _grandBouton('Non', () => setState(() => _etape = _Etape.telephone)),
        TextButton(onPressed: _recommencer, child: const Text('Retour')),
      ],
    );
  }

  Widget _choixTelephone() {
    return ListView(
      shrinkWrap: true,
      children: [
        _titre(
          'Être prévenu par SMS ?',
          'Laissez votre numéro : un SMS vous dira quand votre tour approche.',
        ),
        TextField(
          controller: _telephone,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 2),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d +]')),
          ],
          decoration: const InputDecoration(hintText: 'Votre numéro'),
        ),
        const SizedBox(height: 18),
        if (_erreur != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _erreur!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Kolors.kRed),
            ),
          ),
        _grandBouton('Prendre mon ticket', _emettre, jaune: true),
        TextButton(onPressed: _recommencer, child: const Text('Retour')),
      ],
    );
  }

  Widget _vueTicket() {
    return ListView(
      shrinkWrap: true,
      children: [
        TicketCarte(ticket: _ticket!),
        const SizedBox(height: 16),
        const Text(
          'Gardez ce numéro. Il s’affichera sur l’écran quand ce sera votre tour.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Kolors.kTextMuted),
        ),
        const SizedBox(height: 16),
        if (ImpressionTicket.imprimanteChoisie == null)
          TextButton.icon(
            onPressed: () => imprimerTicket(context, _ticket!),
            icon: const Icon(Icons.print_rounded),
            label: const Text('Imprimer (choisir l’imprimante de la borne)'),
          ),
        _grandBouton('Terminé', _recommencer),
      ],
    );
  }
}
