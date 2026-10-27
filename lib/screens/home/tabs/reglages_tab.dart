import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../common/utils/kcolors.dart';
import '../../../compte/compte_models.dart';
import '../../../controllers/auth_controller.dart';
import '../../../services/reglages_service.dart';

/// Réglages de l'établissement : ses modules, et ce que chaque rôle peut y
/// faire. Réservé au droit `etablissement.regler`.
class ReglagesTab extends StatefulWidget {
  const ReglagesTab({super.key});

  @override
  State<ReglagesTab> createState() => _ReglagesTabState();
}

class _ReglagesTabState extends State<ReglagesTab> {
  final _service = ReglagesService();
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permissions = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final data = await _service.droits();
      _roles = _maps(data['roles']);
      _permissions = _maps(data['permissions']);
    } on DioException {
      _erreur = 'Impossible de charger les réglages. Vérifiez la connexion.';
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _basculerModule(String module, bool actif) async {
    final auth = context.read<AuthController>();
    final id = auth.currentUser?.etablissementId;
    if (id == null) return;
    final modules = {...auth.modules};
    actif ? modules.add(module) : modules.remove(module);
    try {
      await _service.modules(id, modules.toList());
      await auth.refreshCurrentUser();
      await _charger();
    } on DioException {
      if (mounted) _message('Enregistrement impossible.');
    }
  }

  void _message(String texte) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texte)));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _titre('Modules de l’établissement'),
          const Text(
            'Un module coupé disparaît des écrans et ses droits ne s’appliquent plus.',
            style: TextStyle(color: Kolors.kTextMuted),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final entree in libellesModules.entries)
                  SwitchListTile(
                    title: Text(entree.value),
                    value: auth.aModule(entree.key),
                    onChanged: (v) => _basculerModule(entree.key, v),
                  ),
              ],
            ),
          ),
          if (auth.aModule('pharmacie')) ...[
            const SizedBox(height: 20),
            _titre('Vente'),
            Card(
              child: SwitchListTile(
                title: const Text('Caisse séparée'),
                subtitle: const Text(
                  'Le vendeur prépare le panier, le client paie au caissier puis récupère ses produits. Sinon, le vendeur encaisse lui-même.',
                ),
                value: auth.caisseSeparee,
                onChanged: (v) async {
                  final id = auth.currentUser?.etablissementId;
                  if (id == null) return;
                  try {
                    await _service.regler(id, {'caisse_separee': v});
                    await auth.refreshCurrentUser();
                  } on DioException {
                    if (mounted) _message('Enregistrement impossible.');
                  }
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          _titre('Droits par rôle'),
          if (_chargement)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erreur != null)
            Text(_erreur!, style: const TextStyle(color: Kolors.kRed))
          else
            Card(
              child: Column(
                children: [
                  for (final role in _roles)
                    ListTile(
                      title: Text(role['label'].toString()),
                      subtitle: Text(
                        role['modifiable'] == true
                            ? '${(role['permissions'] as List).length} droits'
                            : 'Tous les droits (non modifiable)',
                      ),
                      trailing: role['modifiable'] == true
                          ? const Icon(Icons.chevron_right_rounded)
                          : const Icon(Icons.lock_outline_rounded),
                      onTap: role['modifiable'] == true
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _DroitsRoleScreen(
                                    role: role,
                                    permissions: _permissions,
                                  ),
                                ),
                              );
                              _charger();
                            }
                          : null,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _titre(String texte) => Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 2),
    child: Text(
      texte,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Kolors.kTextHigh,
      ),
    ),
  );
}

class _DroitsRoleScreen extends StatefulWidget {
  const _DroitsRoleScreen({required this.role, required this.permissions});

  final Map<String, dynamic> role;
  final List<Map<String, dynamic>> permissions;

  @override
  State<_DroitsRoleScreen> createState() => _DroitsRoleScreenState();
}

class _DroitsRoleScreenState extends State<_DroitsRoleScreen> {
  final _service = ReglagesService();
  late final Set<String> _choisis = {
    ...(widget.role['permissions'] as List).map((e) => e.toString()),
  };
  bool _envoi = false;

  String get _role => widget.role['role'].toString();

  Future<void> _enregistrer() async {
    setState(() => _envoi = true);
    try {
      await _service.enregistrerDroits(_role, _choisis.toList());
      if (mounted) Navigator.of(context).pop();
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enregistrement impossible.')),
        );
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _parDefaut() async {
    setState(() => _envoi = true);
    try {
      await _service.droitsParDefaut(_role);
      if (mounted) Navigator.of(context).pop();
    } on DioException {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Groupés par module ; le socle d'abord.
    final groupes = <String?, List<Map<String, dynamic>>>{};
    for (final p in widget.permissions) {
      groupes.putIfAbsent(p['module'] as String?, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role['label'].toString()),
        actions: [
          TextButton(
            onPressed: _envoi ? null : _parDefaut,
            child: const Text(
              'Par défaut',
              style: TextStyle(color: Kolors.kJaune),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final groupe in groupes.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                groupe.key == null
                    ? 'Socle'
                    : (libellesModules[groupe.key] ?? groupe.key!),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Kolors.kPrimary,
                ),
              ),
            ),
            Card(
              child: Column(
                children: [
                  for (final p in groupe.value)
                    CheckboxListTile(
                      title: Text(p['label'].toString()),
                      subtitle: p['disponible'] == true
                          ? null
                          : const Text('Module non activé'),
                      value: _choisis.contains(p['code']),
                      onChanged: (v) => setState(() {
                        final code = p['code'].toString();
                        v == true ? _choisis.add(code) : _choisis.remove(code);
                      }),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _envoi ? null : _enregistrer,
              child: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
    : <Map<String, dynamic>>[];
