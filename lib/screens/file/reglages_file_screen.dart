import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../common/utils/kcolors.dart';
import '../../caisse/caisse_models.dart';
import '../../caisse/caisse_service.dart';
import '../../controllers/auth_controller.dart';
import 'package:provider/provider.dart';
import '../../common/widgets/formulaire.dart';
import '../../file/file_models.dart';
import '../../file/file_service.dart';
import '../../rdv/rdv_service.dart';

/// Régler la file : les services (et leur lettre), les salles, et les
/// écrans et bornes de l'établissement.
class ReglagesFileScreen extends StatefulWidget {
  const ReglagesFileScreen({super.key});

  @override
  State<ReglagesFileScreen> createState() => _ReglagesFileScreenState();
}

class _ReglagesFileScreenState extends State<ReglagesFileScreen> {
  final _service = FileService();
  List<ServiceFile> _services = [];
  List<Map<String, dynamic>> _appareils = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final services = await _service.services();
      final appareils = await _service.appareils();
      if (!mounted) return;
      setState(() {
        _services = services;
        _appareils = appareils;
      });
    } on DioException {
      _dire('Chargement impossible. Vérifiez la connexion.');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _faire(Future<void> Function() action) async {
    try {
      await action();
      await _charger();
    } on DioException catch (e) {
      final data = e.response?.data;
      _dire(
        data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Enregistrement impossible.',
      );
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _editerService([ServiceFile? s]) async {
    final donnees = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _EditionService(service: s),
      ),
    );
    if (donnees == null) return;
    await _faire(
      () => s == null
          ? _service.creerService(donnees)
          : _service.modifierService(s.uuid, donnees),
    );
  }

  Future<void> _ajouterSalle(ServiceFile s) async {
    final nom = await _demanderTexte(
      'Nouvelle salle pour ${s.nom}',
      'ex. Salle 2',
    );
    if (nom == null) return;
    await _faire(() => _service.creerSalle(s.uuid, nom));
  }

  Future<void> _ajouterAppareil(String mode) async {
    final nom = await _demanderTexte(
      mode == 'ecran' ? 'Nouvel écran de salle' : 'Nouvelle borne',
      mode == 'ecran' ? 'ex. Télé salle d’attente' : 'ex. Borne de l’entrée',
    );
    if (nom == null) return;
    try {
      final data = await _service.creerAppareil(mode: mode, nom: nom);
      await _charger();
      if (mounted) await _montrerCode(data);
    } on DioException {
      _dire('Création impossible.');
    }
  }

  Future<void> _montrerCode(Map<String, dynamic> data) {
    final code = data['code'].toString();
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appairer l’appareil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sur l’écran ou la borne, ouvrez Ngoni Santé, touchez « Écran ou borne d’établissement », puis scannez ce QR ou tapez le code. Valable 10 minutes.',
              ),
              const SizedBox(height: 14),
              QrImageView(data: data['qr'].toString(), size: 180),
              SelectableText(
                code,
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: Kolors.kPrimary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            child: const Text('Copier le code'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _afficheAccueil() async {
    try {
      final data = await RdvService().qrAccueil();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(data['etablissement'].toString()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(data: data['qr'].toString(), size: 240),
                const SizedBox(height: 10),
                const Text(
                  'Vous avez rendez-vous ? Scannez ce QR avec Ngoni Santé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } on DioException {
      _dire('Affiche indisponible. Vérifiez la connexion.');
    }
  }

  Future<String?> _demanderTexte(String titre, String exemple) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: exemple),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              Navigator.pop(ctx, v.isEmpty ? null : v);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Régler la file')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _titre('Services'),
                  for (final s in _services) _carteService(s),
                  OutlinedButton.icon(
                    onPressed: () => _editerService(),
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un service'),
                  ),
                  const SizedBox(height: 24),
                  _titre('Affiche de l’accueil'),
                  const Text(
                    'Imprimez ce QR et collez-le à l’accueil : en le scannant avec l’app, le patient qui a rendez-vous signale son arrivée et entre dans la file.',
                    style: TextStyle(color: Kolors.kTextMuted),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _afficheAccueil,
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text('Voir l’affiche'),
                  ),
                  const SizedBox(height: 24),
                  _titre('Écrans et bornes'),
                  const Text(
                    'Un écran (télé, tablette) affiche les appels dans la salle d’attente. Une borne donne les tickets à l’entrée.',
                    style: TextStyle(color: Kolors.kTextMuted),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (final a in _appareils)
                          ListTile(
                            leading: Icon(
                              a['mode'] == 'ecran'
                                  ? Icons.tv_rounded
                                  : Icons.confirmation_number_rounded,
                              color: Kolors.kPrimary,
                            ),
                            title: Text(a['nom'].toString()),
                            subtitle: Text(
                              a['appaire_at'] == null
                                  ? 'En attente d’appairage'
                                  : (a['mode'] == 'ecran'
                                        ? 'Écran de salle'
                                        : 'Borne'),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) async {
                                final uuid = a['uuid'].toString();
                                if (v == 'code') {
                                  final data = await _service.nouveauCode(uuid);
                                  if (mounted) await _montrerCode(data);
                                } else {
                                  await _faire(
                                    () => _service.retirerAppareil(uuid),
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'code',
                                  child: Text('Nouveau code'),
                                ),
                                PopupMenuItem(
                                  value: 'retirer',
                                  child: Text('Retirer'),
                                ),
                              ],
                            ),
                          ),
                        if (_appareils.isEmpty)
                          const ListTile(title: Text('Aucun appareil.')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _ajouterAppareil('ecran'),
                        icon: const Icon(Icons.tv_rounded),
                        label: const Text('Ajouter un écran'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _ajouterAppareil('borne'),
                        icon: const Icon(Icons.confirmation_number_rounded),
                        label: const Text('Ajouter une borne'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _titre(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Kolors.kTextHigh,
      ),
    ),
  );

  Widget _carteService(ServiceFile s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: s.actif
                      ? Kolors.kPrimary
                      : Kolors.kGrayLight,
                  child: Text(
                    s.prefixe,
                    style: const TextStyle(
                      color: Kolors.kJaune,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.nom,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${s.actif ? 'Ouvert' : 'Fermé'} · ${s.dureeMoyenne} min par patient'
                        '${s.ticketDistance ? ' · ticket à distance' : ''}',
                        style: const TextStyle(color: Kolors.kTextMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editerService(s),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final p in s.salles)
                  InputChip(
                    label: Text(p.nom),
                    onDeleted: () =>
                        _faire(() => _service.supprimerSalle(p.uuid)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Salle'),
                  onPressed: () => _ajouterSalle(s),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditionService extends StatefulWidget {
  const _EditionService({this.service});

  final ServiceFile? service;

  @override
  State<_EditionService> createState() => _EditionServiceState();
}

class _EditionServiceState extends State<_EditionService> {
  late final _nom = TextEditingController(text: widget.service?.nom);
  late final _prefixe = TextEditingController(text: widget.service?.prefixe);
  late final _duree = TextEditingController(
    text: '${widget.service?.dureeMoyenne ?? 10}',
  );
  late bool _actif = widget.service?.actif ?? true;
  late bool _distance = widget.service?.ticketDistance ?? true;
  late String? _tarif = widget.service?.tarifUuid;
  List<Tarif> _tarifs = [];

  @override
  void initState() {
    super.initState();
    if (context.read<AuthController>().aModule('caisse')) {
      CaisseService()
          .tarifs()
          .then((t) {
            if (mounted) {
              setState(() => _tarifs = t.where((x) => x.actif).toList());
            }
          })
          .catchError((Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFormulaire(
      titre: Text(
        widget.service == null ? 'Nouveau service' : 'Modifier le service',
      ),
      corps: Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nom,
            decoration: const InputDecoration(labelText: 'Nom (ex. Pédiatrie)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _prefixe,
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Lettre des tickets (ex. B)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _duree,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Minutes par patient (estimation de départ)',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ouvert'),
            value: _actif,
            onChanged: (v) => setState(() => _actif = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ticket depuis le téléphone'),
            value: _distance,
            onChanged: (v) => setState(() => _distance = v),
          ),
          if (_tarifs.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _tarifs.any((t) => t.uuid == _tarif)
                  ? _tarif
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Acte facturé à chaque ticket',
                helperText:
                    'Ex. la consultation : le patient arrive à la caisse avec son montant.',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Aucun')),
                for (final t in _tarifs)
                  DropdownMenuItem(
                    value: t.uuid,
                    child: Text(
                      '${t.nom} · ${formatMontant(t.prix, context.read<AuthController>().devise)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _tarif = v),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'nom': _nom.text.trim(),
            'prefixe': _prefixe.text.trim().toUpperCase(),
            'duree_moyenne_min': int.tryParse(_duree.text) ?? 10,
            'actif': _actif,
            'ticket_distance': _distance,
            if (_tarifs.isNotEmpty) 'tarif_uuid': _tarif,
          }),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
