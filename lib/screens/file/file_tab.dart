import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/offline/local_store.dart';
import '../../file/file_models.dart';
import '../../file/file_service.dart';
import '../../core/api/api_client.dart';
import '../../rdv/rdv_service.dart';
import '../commun/scanner_qr_screen.dart';
import '../caisse/visite_screen.dart';
import 'donner_ticket_sheet.dart';
import 'ticket_carte.dart';
import 'reglages_file_screen.dart';
import 'stats_file_screen.dart';

/// La file d'attente au poste de travail : la salle ou le guichet appelle
/// le suivant, sert, termine, transfère. La liste se met à jour toute seule.
class FileTab extends StatefulWidget {
  const FileTab({super.key});

  @override
  State<FileTab> createState() => _FileTabState();
}

class _FileTabState extends State<FileTab> {
  static const _clePoste = 'file_poste';
  static const _cleCourant = 'file_ticket_courant';

  final _service = FileService();
  Timer? _minuteur;

  List<ServiceFile> _services = [];
  List<TicketFile> _tickets = [];
  bool _chargement = true;
  bool _action = false;
  String? _erreur;

  /// Mon poste : les services que j'appelle, et ma salle.
  List<String> _mesServices = [];
  String? _maSalle;

  /// Le ticket que je suis en train de recevoir.
  String? _courant;

  @override
  void initState() {
    super.initState();
    final poste = LocalStore.read<Map<String, dynamic>>(_clePoste);
    if (poste != null) {
      _mesServices = ((poste['services'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      _maSalle = poste['salle']?.toString();
    }
    _courant = LocalStore.read<String>(_cleCourant);
    _charger();
    _minuteur = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _rafraichir(),
    );
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      _services = await _service.services();
      // Premier passage : on propose tous les services, et la première salle.
      final connus = _services.map((s) => s.uuid).toSet();
      _mesServices = _mesServices.where(connus.contains).toList();
      if (_mesServices.isEmpty && _services.isNotEmpty) {
        _mesServices = [_services.first.uuid];
        _maSalle = _services.first.salles.firstOrNull?.uuid;
        await _memoriserPoste();
      }
      await _rafraichir();
    } on DioException {
      _erreur = 'Impossible de charger la file. Vérifiez la connexion.';
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _rafraichir() async {
    try {
      final tickets = await _service.tickets();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _erreur = null;
      });
    } on DioException {
      // On garde l'affichage ; nouvel essai dans 5 s.
    }
  }

  Future<void> _memoriserPoste() => LocalStore.write(_clePoste, {
    'services': _mesServices,
    'salle': _maSalle,
  });

  TicketFile? get _ticketCourant {
    final t = _tickets.where((t) => t.uuid == _courant).firstOrNull;
    return t != null && (t.appele || t.enService) ? t : null;
  }

  List<TicketFile> get _enAttente => _tickets
      .where((t) => t.enAttente && _mesServices.contains(t.serviceUuid))
      .toList();

  Future<void> _faire(Future<void> Function() action) async {
    setState(() => _action = true);
    try {
      await action();
      await _rafraichir();
    } on DioException catch (e) {
      final data = e.response?.data;
      _dire(
        data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Action impossible. Vérifiez la connexion.',
      );
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }

  /// « Suivant » : termine le ticket en cours, puis appelle le prochain.
  Future<void> _suivant() => _faire(() async {
    final courant = _ticketCourant;
    if (courant != null) await _service.action(courant.uuid, 'terminer');
    final t = await _service.appeler(
      services: _mesServices,
      salleUuid: _maSalle,
    );
    _courant = t?.uuid;
    await LocalStore.write(_cleCourant, _courant);
    if (t == null) _dire('Personne en attente.');
  });

  Future<void> _sur(String action) => _faire(() async {
    final courant = _ticketCourant;
    if (courant == null) return;
    await _service.action(courant.uuid, action, salleUuid: _maSalle);
    if (action == 'terminer' || action == 'absent') {
      _courant = null;
      await LocalStore.remove(_cleCourant);
    }
  });

  Future<void> _transferer() async {
    final courant = _ticketCourant;
    if (courant == null) return;
    final vers = await showDialog<ServiceFile>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Envoyer ${courant.code} vers…'),
        children: [
          for (final s in _services.where(
            (s) => s.uuid != courant.serviceUuid && s.actif,
          ))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, s),
              child: Text(s.nom),
            ),
        ],
      ),
    );
    if (vers == null) return;
    await _faire(() async {
      final nouveau = await _service.transferer(courant.uuid, vers.uuid);
      _courant = null;
      await LocalStore.remove(_cleCourant);
      _dire('${courant.code} devient ${nouveau.code} à ${vers.nom}.');
    });
  }

  /// Le patient montre son QR : rendez-vous (il entre dans la file, priorité
  /// rendez-vous) ou carte santé (on choisit son service).
  Future<void> _scanner() async {
    final qr = await scannerQr(
      context,
      consigne: 'QR du rendez-vous ou de la carte santé du patient',
    );
    if (qr == null || !mounted) return;
    final rdv = RdvService();
    try {
      var reponse = await rdv.scanner(qr);
      if (reponse['type'] == 'carte' && mounted) {
        final personne = Map<String, dynamic>.from(reponse['personne'] as Map);
        final service = await showDialog<ServiceFile>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text('Ticket pour ${personne['nom']}'),
            children: [
              for (final s in _services.where((s) => s.actif))
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, s),
                  child: Text(s.nom),
                ),
            ],
          ),
        );
        if (service == null) return;
        reponse = await rdv.scanner(qr, serviceUuid: service.uuid);
      }
      final t = reponse['ticket'];
      if (t is Map && mounted) {
        await afficherTicket(
          context,
          TicketFile.fromJson(Map<String, dynamic>.from(t)),
        );
      }
      _rafraichir();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _choisirPoste() async {
    final choix = await showDialog<(List<String>, String?)>(
      context: context,
      builder: (_) => _ChoixPoste(
        services: _services,
        choisis: _mesServices,
        salle: _maSalle,
      ),
    );
    if (choix == null) return;
    setState(() {
      _mesServices = choix.$1;
      _maSalle = choix.$2;
    });
    await _memoriserPoste();
  }

  void _dire(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (_chargement) return const Center(child: CircularProgressIndicator());
    if (_erreur != null && _services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_erreur!, textAlign: TextAlign.center),
        ),
      );
    }

    final peutAppeler = auth.peut('file.appeler');
    final peutEmettre = auth.peut('file.emettre');
    final nomsServices = _services
        .where((s) => _mesServices.contains(s.uuid))
        .map((s) => s.nom)
        .join(', ');
    final salle = _services
        .expand((s) => s.salles)
        .where((p) => p.uuid == _maSalle)
        .firstOrNull;

    return RefreshIndicator(
      onRefresh: _rafraichir,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mon poste : ${nomsServices.isEmpty ? '—' : nomsServices}'
                  '${salle == null ? '' : ' · ${salle.nom}'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Kolors.kTextHigh,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _choisirPoste,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Changer'),
              ),
              if (auth.peut('file.gerer') || auth.peut('stats.voir'))
                IconButton(
                  tooltip: 'Chiffres du jour',
                  icon: const Icon(Icons.bar_chart_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatsFileScreen()),
                  ),
                ),
              if (auth.peut('file.gerer'))
                IconButton(
                  tooltip: 'Régler la file',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReglagesFileScreen(),
                      ),
                    );
                    _charger();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (peutAppeler) _carteAppel(),
          if (peutEmettre) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _scanner,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scanner un rendez-vous ou une carte santé'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () async {
                await donnerTicket(context, _services);
                _rafraichir();
              },
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('Donner un ticket'),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'En attente (${_enAttente.length})',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Kolors.kTextHigh,
            ),
          ),
          // Ce qui attend dans les autres services : l'accueil compte tout.
          if (_services.any(
            (x) => !_mesServices.contains(x.uuid) && x.enAttente > 0,
          ))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Ailleurs : ${[for (final x in _services)
                  if (!_mesServices.contains(x.uuid) && x.enAttente > 0) '${x.nom} ${x.enAttente}'].join(' · ')}',
                style: const TextStyle(color: Kolors.kTextMuted),
              ),
            ),
          const SizedBox(height: 8),
          if (_enAttente.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Personne n’attend pour le moment.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            )
          else
            Card(
              child: Column(
                children: [for (final t in _enAttente) _LigneTicket(ticket: t)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _carteAppel() {
    final courant = _ticketCourant;
    return CarteMarque(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (courant == null)
            Text(
              _enAttente.isEmpty
                  ? 'Personne en attente'
                  : '${_enAttente.length} en attente · prochain : ${_enAttente.first.code}',
              style: TextStyle(color: Kolors.kWhite.withValues(alpha: 0.9)),
            )
          else ...[
            Row(
              children: [
                Text(
                  courant.code,
                  style: GoogleFonts.poppins(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: Kolors.kJaune,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courant.nom?.isNotEmpty == true
                            ? courant.nom!
                            : courant.serviceNom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${courant.statutLabel} · ${courant.prioriteLabel}'
                        '${courant.appels > 1 ? ' · appelé ${courant.appels} fois' : ''}',
                        style: TextStyle(
                          color: Kolors.kWhite.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (courant.appele)
                  _BoutonClair(
                    'Il est là',
                    Icons.how_to_reg_rounded,
                    () => _sur('servir'),
                  ),
                _BoutonClair(
                  'Rappeler',
                  Icons.campaign_rounded,
                  () => _sur('rappeler'),
                ),
                if (courant.appele)
                  _BoutonClair(
                    'Absent',
                    Icons.person_off_rounded,
                    () => _sur('absent'),
                  ),
                if (courant.visiteUuid != null)
                  _BoutonClair(
                    'Facture',
                    Icons.receipt_long_rounded,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VisiteScreen(uuid: courant.visiteUuid!),
                      ),
                    ),
                  ),
                _BoutonClair(
                  'Envoyer vers…',
                  Icons.alt_route_rounded,
                  _transferer,
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Kolors.kJaune,
                foregroundColor: Kolors.kPrimaryDark,
              ),
              onPressed: _action || _mesServices.isEmpty ? null : _suivant,
              icon: _action
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.skip_next_rounded),
              label: Text(
                courant == null
                    ? 'Appeler le suivant'
                    : 'Terminer et appeler le suivant',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoutonClair extends StatelessWidget {
  const _BoutonClair(this.label, this.icone, this.onTap);

  final String label;
  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Kolors.kWhite,
        side: BorderSide(color: Kolors.kWhite.withValues(alpha: 0.6)),
        // Le thème étire les boutons sur toute la largeur : ici, côte à côte.
        minimumSize: const Size(0, 44),
      ),
      onPressed: onTap,
      icon: Icon(icone, size: 18),
      label: Text(label),
    );
  }
}

class _LigneTicket extends StatelessWidget {
  const _LigneTicket({required this.ticket});

  final TicketFile ticket;

  @override
  Widget build(BuildContext context) {
    final couleur = switch (ticket.priorite) {
      'urgence' => Kolors.kRed,
      'rdv' => Kolors.kPrimaryLight,
      'prioritaire' => Kolors.kGold,
      _ => Kolors.kTextMuted,
    };
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Kolors.kSecondaryLight,
        child: Text(
          ticket.code,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Kolors.kPrimary,
          ),
        ),
      ),
      title: Text(ticket.nom?.isNotEmpty == true ? ticket.nom! : ticket.code),
      subtitle: Text(
        '${ticket.serviceNom}'
        '${ticket.attenteMin == null ? '' : ' · environ ${ticket.attenteMin} min'}',
      ),
      trailing: ticket.prioritaire
          ? Text(
              ticket.prioriteLabel,
              style: TextStyle(color: couleur, fontWeight: FontWeight.w800),
            )
          : null,
    );
  }
}

/// Choix des services appelés et de la salle de ce poste.
class _ChoixPoste extends StatefulWidget {
  const _ChoixPoste({
    required this.services,
    required this.choisis,
    required this.salle,
  });

  final List<ServiceFile> services;
  final List<String> choisis;
  final String? salle;

  @override
  State<_ChoixPoste> createState() => _ChoixPosteState();
}

class _ChoixPosteState extends State<_ChoixPoste> {
  late final Set<String> _choisis = {...widget.choisis};
  late String? _salle = widget.salle;

  @override
  Widget build(BuildContext context) {
    final salles = widget.services
        .where((s) => _choisis.contains(s.uuid))
        .expand((s) => s.salles.where((p) => p.actif))
        .toList();
    return AlertDialog(
      title: const Text('Mon poste'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'J’appelle les patients de :',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final s in widget.services.where((s) => s.actif))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${s.nom} (${s.prefixe})'),
                value: _choisis.contains(s.uuid),
                onChanged: (v) => setState(
                  () => v == true
                      ? _choisis.add(s.uuid)
                      : _choisis.remove(s.uuid),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Dans la salle :',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            RadioGroup<String?>(
              groupValue: _salle,
              onChanged: (v) => setState(() => _salle = v),
              child: Column(
                children: [
                  for (final p in salles)
                    RadioListTile<String?>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.nom),
                      value: p.uuid,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _choisis.isEmpty
              ? null
              : () => Navigator.pop(context, (
                  _choisis.toList(),
                  salles.any((p) => p.uuid == _salle) ? _salle : null,
                )),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
