import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../common/whatsapp.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/offline/local_store.dart';
import '../../file/file_models.dart';
import '../../file/file_service.dart';
import '../../core/api/api_client.dart';
import '../../rdv/rdv_service.dart';
import '../commun/scanner_qr_screen.dart';
import '../caisse/visite_screen.dart';
import '../../common/widgets/confirmer.dart';
import '../../common/widgets/feuille.dart';
import '../dossier/dossier_screen.dart';
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
      // Premier passage sur cet appareil : tous les services, pour que
      // personne en attente ne soit caché ; chacun réduit ensuite à son poste.
      final connus = _services.map((s) => s.uuid).toSet();
      _mesServices = _mesServices.where(connus.contains).toList();
      if (_mesServices.isEmpty && _services.isNotEmpty) {
        _mesServices = [for (final s in _services) s.uuid];
        _maSalle = _services.first.salles.firstOrNull?.uuid;
        await _memoriserPoste();
      }
      _erreur = null;
      await _rafraichir();
    } on DioException catch (e) {
      _erreur = messageErreur(
        e,
        defaut: 'Impossible de charger la file. Vérifiez la connexion.',
      );
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

  /// « Pédiatrie 2 · Labo 1 » : ce qui attend hors de mon poste.
  String get _ailleurs => [
    for (final x in _services)
      if (!_mesServices.contains(x.uuid))
        (
          x.nom,
          _tickets.where((t) => t.enAttente && t.serviceUuid == x.uuid).length,
        ),
  ].where((e) => e.$2 > 0).map((e) => '${e.$1} ${e.$2}').join(' · ');

  /// Appelés ou en cours, à tous les postes, sauf celui que je reçois.
  List<TicketFile> get _appeles => _tickets
      .where((t) => (t.appele || t.enService) && t.uuid != _ticketCourant?.uuid)
      .toList();

  /// Les absents (à rappeler) d'abord, puis ceux qui sont passés.
  List<TicketFile> get _clos => [
    ..._tickets.where((t) => t.absent),
    ..._tickets.where((t) => !t.enCours).toList().reversed,
  ];

  List<TicketFile> get _enAttente => _tickets
      .where((t) => t.enAttente && _mesServices.contains(t.serviceUuid))
      .toList();

  Future<void> _faire(Future<void> Function() action) async {
    setState(() => _action = true);
    try {
      await action();
      await _rafraichir();
    } on DioException catch (e) {
      _dire(messageErreur(e, defaut: 'Action impossible. Réessayez.'));
      // Un autre poste a peut-être déjà terminé ce ticket : la liste à jour.
      await _rafraichir();
    } finally {
      if (mounted) setState(() => _action = false);
    }
  }

  /// Le patient se présente avec son ticket : on termine le ticket en cours
  /// et on le prend, sans attendre son tour.
  Future<void> _prendre(TicketFile t) => _faire(() async {
    final courant = _ticketCourant;
    if (courant != null && courant.uuid != t.uuid) {
      await _service.action(courant.uuid, 'terminer');
    }
    await _service.action(t.uuid, 'servir', salleUuid: _maSalle);
    _courant = t.uuid;
    await LocalStore.write(_cleCourant, _courant);
  });

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

  /// Terminer, absent… sur un ticket appelé depuis un autre poste (ou un
  /// autre appareil), qui serait resté bloqué sinon.
  Future<void> _surTicket(TicketFile t, String action) => _faire(() async {
    await _service.action(t.uuid, action, salleUuid: _maSalle);
    if (t.uuid == _courant && (action == 'terminer' || action == 'absent')) {
      _courant = null;
      await LocalStore.remove(_cleCourant);
    }
  });

  Future<void> _absent(TicketFile t) async {
    final ok = await confirmer(
      context,
      titre: '${t.code} absent ?',
      texte:
          'Le ticket passe dans « Absents et terminés du jour ». Vous pourrez le rappeler s’il revient.',
      action: 'Absent',
    );
    if (ok) await _surTicket(t, 'absent');
  }

  /// Je reprends ce ticket à mon poste : il devient mon patient en cours.
  Future<void> _reprendre(TicketFile t) async {
    setState(() => _courant = t.uuid);
    await LocalStore.write(_cleCourant, t.uuid);
  }

  /// Le patient absent revient : on le rappelle, à mon poste.
  Future<void> _rappeler(TicketFile t) => _faire(() async {
    await _service.action(t.uuid, 'rappeler', salleUuid: _maSalle);
    _courant = t.uuid;
    await LocalStore.write(_cleCourant, _courant);
  });

  Future<void> _annuler(TicketFile t) async {
    final ok = await confirmer(
      context,
      titre: 'Annuler le ticket ${t.code} ?',
      texte: 'Le patient sort de la file.',
      action: 'Annuler le ticket',
      danger: true,
    );
    if (ok) await _surTicket(t, 'annuler');
  }

  Future<void> _changerPriorite(TicketFile t) async {
    final choix = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Priorité de ${t.code}'),
        children: [
          for (final e in libellesPriorite.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Row(
                children: [
                  Icon(
                    e.key == t.priorite
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 20,
                    color: Kolors.kPrimary,
                  ),
                  const SizedBox(width: 10),
                  Text(e.value),
                ],
              ),
            ),
        ],
      ),
    );
    if (choix == null || choix == t.priorite) return;
    await _faire(() => _service.priorite(t.uuid, choix));
  }

  /// Ce qu'on fait d'un patient qui attend : le prendre tout de suite (il
  /// est devant le guichet), changer sa priorité, l'envoyer ailleurs, ou
  /// l'enlever de la file.
  Future<void> _menuAttente(TicketFile t) async {
    final auth = context.read<AuthController>();
    final appelle = auth.peut('file.appeler');
    final choix = await feuille<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                '${t.code}${t.nom?.isNotEmpty == true ? ' · ${t.nom}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${t.serviceNom} · ${t.prioriteLabel}'),
            ),
            if (appelle)
              ListTile(
                leading: const Icon(Icons.how_to_reg_rounded),
                title: const Text('Prendre maintenant'),
                onTap: () => Navigator.pop(ctx, 'prendre'),
              ),
            ListTile(
              leading: const Icon(Icons.priority_high_rounded),
              title: const Text('Changer la priorité'),
              onTap: () => Navigator.pop(ctx, 'priorite'),
            ),
            if (appelle)
              ListTile(
                leading: const Icon(Icons.alt_route_rounded),
                title: const Text('Envoyer vers un autre service'),
                onTap: () => Navigator.pop(ctx, 'transferer'),
              ),
            if (appelle)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Kolors.kRed),
                title: const Text(
                  'Annuler le ticket',
                  style: TextStyle(color: Kolors.kRed),
                ),
                onTap: () => Navigator.pop(ctx, 'annuler'),
              ),
          ],
        ),
      ),
    );
    switch (choix) {
      case 'prendre':
        await _prendre(t);
      case 'priorite':
        await _changerPriorite(t);
      case 'transferer':
        await _transferer(t);
      case 'annuler':
        await _annuler(t);
    }
  }

  Future<void> _transferer([TicketFile? ticket]) async {
    final t = ticket ?? _ticketCourant;
    if (t == null) return;
    final autres = _services
        .where((s) => s.uuid != t.serviceUuid && s.actif)
        .toList();
    if (autres.isEmpty) {
      await aucunServiceOuvert(
        context,
        texte:
            'Aucun autre service n’est ouvert : créez-en ou ouvrez-en un dans « Régler la file » (laboratoire, caisse, pharmacie…).',
      );
      return;
    }
    final vers = await showDialog<ServiceFile>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Envoyer ${t.code} vers…'),
        children: [
          for (final s in autres)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, s),
              child: Text(s.nom),
            ),
        ],
      ),
    );
    if (vers == null) return;
    await _faire(() async {
      final nouveau = await _service.transferer(t.uuid, vers.uuid);
      if (t.uuid == _courant) {
        _courant = null;
        await LocalStore.remove(_cleCourant);
      }
      _dire('${t.code} devient ${nouveau.code} à ${vers.nom}.');
    });
  }

  /// Le patient montre son QR : rendez-vous (il entre dans la file, priorité
  /// rendez-vous) ou carte santé (on choisit son service).
  Future<void> _scanner() async {
    final qr = await scannerQr(
      context,
      consigne: 'QR du rendez-vous, de la carte santé ou du ticket du patient',
    );
    if (qr == null || !mounted) return;
    final rdv = RdvService();
    try {
      var reponse = await rdv.scanner(qr);
      // Le ticket du patient : on le prend tout de suite, même hors de son tour.
      if (reponse['type'] == 'ticket' && reponse['ticket'] is Map && mounted) {
        final t = TicketFile.fromJson(
          Map<String, dynamic>.from(reponse['ticket'] as Map),
        );
        final prendre = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Ticket ${t.code}'),
            content: Text(
              [
                if (t.nom != null && t.nom!.isNotEmpty) t.nom!,
                t.serviceNom,
                t.statutLabel,
              ].join(' · '),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Fermer'),
              ),
              if ((t.statut == 'emis' || t.statut == 'appele') &&
                  context.read<AuthController>().peut('file.appeler'))
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Le prendre maintenant'),
                ),
            ],
          ),
        );
        if (prendre == true) await _prendre(t);
        return;
      }
      if (reponse['type'] == 'carte' && mounted) {
        final personne = Map<String, dynamic>.from(reponse['personne'] as Map);
        if (!_services.any((s) => s.actif)) {
          await aucunServiceOuvert(
            context,
            texte:
                'Carte de ${personne['nom']} reconnue, mais aucun service n’est ouvert pour lui donner un ticket.',
          );
          return;
        }
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _chargement = true);
                  _charger();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
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
              label: const Text('Scanner le QR du patient'),
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
          if (peutAppeler && _appeles.isNotEmpty) ...[
            const SizedBox(height: 20),
            _titre('Appelés · en cours (${_appeles.length})'),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'À tous les postes : touchez pour terminer, noter absent ou le reprendre ici.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final t in _appeles)
                    _LigneTicket(
                      ticket: t,
                      enCours: true,
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Que faire de ${t.code} ?',
                        onSelected: (a) => switch (a) {
                          'reprendre' => _reprendre(t),
                          'absent' => _absent(t),
                          _ => _surTicket(t, a),
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'reprendre',
                            child: Text('Reprendre à mon poste'),
                          ),
                          const PopupMenuItem(
                            value: 'terminer',
                            child: Text('Terminer'),
                          ),
                          if (t.appele)
                            const PopupMenuItem(
                              value: 'absent',
                              child: Text('Absent'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
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
          // Ce qui attend dans les autres services, d'après la file à jour.
          if (_ailleurs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Ailleurs : $_ailleurs',
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
                children: [
                  for (final t in _enAttente)
                    _LigneTicket(
                      ticket: t,
                      onTap: peutAppeler || peutEmettre
                          ? () => _menuAttente(t)
                          : null,
                    ),
                ],
              ),
            ),
          if (_clos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                shape: const Border(),
                leading: const Icon(Icons.history_rounded),
                title: Text(
                  'Absents et terminés du jour (${_clos.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children: [
                  for (final t in _clos)
                    _LigneTicket(
                      ticket: t,
                      clos: true,
                      trailing: t.absent && peutAppeler
                          ? TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 40),
                              ),
                              onPressed: _action ? null : () => _rappeler(t),
                              child: const Text('Rappeler'),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _titre(String texte) => Text(
    texte,
    style: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Kolors.kTextHigh,
    ),
  );

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
                if (courant.telephone != null && courant.telephone!.isNotEmpty)
                  _BoutonClair(
                    'WhatsApp',
                    Icons.chat_rounded,
                    () => envoyerWhatsApp(
                      context,
                      courant.telephone!,
                      'Ngoni Santé : c’est à vous ! Ticket ${courant.code}'
                      '${courant.salle == null ? '' : ', ${courant.salle}'} (${courant.serviceNom}).',
                    ),
                  ),
                if (courant.appele)
                  _BoutonClair(
                    'Absent',
                    Icons.person_off_rounded,
                    () => _absent(courant),
                  ),
                _BoutonClair(
                  'Terminer',
                  Icons.check_circle_outline_rounded,
                  () => _sur('terminer'),
                ),
                // Le médecin ouvre le dossier du patient appelé, sans passer
                // par la facture.
                if (courant.visiteUuid != null &&
                    context.read<AuthController>().peut('consultation.faire'))
                  _BoutonClair(
                    'Consulter',
                    Icons.medical_services_rounded,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DossierScreen(visiteUuid: courant.visiteUuid!),
                      ),
                    ),
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
                  () => _transferer(),
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
  const _LigneTicket({
    required this.ticket,
    this.onTap,
    this.trailing,
    this.enCours = false,
    this.clos = false,
  });

  final TicketFile ticket;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Appelé ou en cours : on montre la salle.
  final bool enCours;

  /// Absent, terminé, annulé, transféré : on montre où il en est.
  final bool clos;

  @override
  Widget build(BuildContext context) {
    final couleur = switch (ticket.priorite) {
      'urgence' => Kolors.kRed,
      'rdv' => Kolors.kPrimaryLight,
      'prioritaire' => Kolors.kGold,
      _ => Kolors.kTextMuted,
    };
    final detail = enCours || clos
        ? [ticket.serviceNom, ?ticket.salle, ticket.statutLabel].join(' · ')
        : '${ticket.serviceNom}'
              '${ticket.attenteMin == null ? '' : ' · environ ${ticket.attenteMin} min'}';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: clos && !ticket.absent
            ? Kolors.kGrayLight
            : Kolors.kSecondaryLight,
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
      subtitle: Text(detail),
      trailing:
          trailing ??
          (ticket.prioritaire && !clos
              ? Text(
                  ticket.prioriteLabel,
                  style: TextStyle(color: couleur, fontWeight: FontWeight.w800),
                )
              : onTap != null
              ? const Icon(Icons.more_vert_rounded)
              : null),
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
