import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../compte/compte_controller.dart';
import '../../compte/compte_models.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../services/etablissement_service.dart';
import '../compte/cadre_acces.dart';

/// L'établissement ouvert : son nom et ses coordonnées (ce que voient les
/// patients), et sa suppression par la personne qui l'a créé.
class EtablissementInfosScreen extends StatefulWidget {
  const EtablissementInfosScreen({super.key});

  @override
  State<EtablissementInfosScreen> createState() =>
      _EtablissementInfosScreenState();
}

class _EtablissementInfosScreenState extends State<EtablissementInfosScreen> {
  final _service = EtablissementService();
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _adresse = TextEditingController();
  final _responsable = TextEditingController();
  final _autorisation = TextEditingController();
  bool _chargement = true;
  bool _envoi = false;
  String? _erreur;

  int? get _id => context.read<AuthController>().currentUser?.etablissementId;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _adresse.dispose();
    _responsable.dispose();
    _autorisation.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final id = _id;
    if (id == null) return;
    try {
      final e = await _service.getOne(id);
      String v(String cle) => (e[cle] ?? '').toString();
      _nom.text = v('nom');
      _telephone.text = v('telephone');
      _adresse.text = v('adresse');
      _responsable.text = v('responsable');
      _autorisation.text = v('autorisation');
    } on DioException catch (e) {
      _erreur = ApiClient.isNetworkError(e)
          ? 'Pas de connexion internet.'
          : messageErreur(e);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _enregistrer() async {
    final id = _id;
    if (id == null || !_formKey.currentState!.validate()) return;
    setState(() => _envoi = true);
    final compte = context.read<CompteController>();
    try {
      String? t(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      await _service.update(id, {
        'nom': _nom.text.trim(),
        'telephone': t(_telephone),
        'adresse': t(_adresse),
        'responsable': t(_responsable),
        'autorisation': t(_autorisation),
      });
      // Le nouveau nom dans « Mes espaces » et la barre du haut.
      await compte.rafraichir();
      if (!mounted) return;
      Navigator.of(context).pop();
      afficherMessage(context, 'Établissement enregistré.');
    } on DioException catch (e) {
      if (mounted) afficherMessage(context, messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _supprimer(Espace espace) async {
    final compte = context.read<CompteController>();
    final auth = context.read<AuthController>();
    final navigator = Navigator.of(context);
    final nom = await showDialog<String>(
      context: context,
      builder: (_) => _ConfirmerSuppression(nom: espace.etablissementNom),
    );
    if (nom == null || !mounted) return;
    final ok = await compte.supprimerEtablissement(espace, nom, auth);
    if (!mounted) return;
    if (ok) {
      navigator.popUntil((route) => route.isFirst);
      afficherMessage(context, '${espace.etablissementNom} est supprimé.');
    } else {
      afficherMessage(context, compte.erreur ?? 'Suppression impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final compte = context.watch<CompteController>();
    final espace = compte.espaceOuvert;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon établissement')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_erreur != null) ...[
                    Text(_erreur!, style: const TextStyle(color: Kolors.kRed)),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _nom,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom de l’établissement',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().length < 2 ? 'Indiquez le nom' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telephone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _adresse,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      hintText: 'ex. Hamdallaye ACI 2000, rue 405',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _responsable,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Responsable (nom et titre)',
                      prefixIcon: Icon(Icons.person_pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _autorisation,
                    decoration: const InputDecoration(
                      labelText: 'N° d’autorisation, d’agrément ou d’ordre',
                      prefixIcon: Icon(Icons.verified_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  BoutonAcces(
                    label: 'Enregistrer',
                    chargement: _envoi,
                    onPressed: _enregistrer,
                  ),
                  if (espace != null && espace.proprietaire) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Supprimer l’établissement',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Kolors.kRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tout est effacé pour de bon : patients, dossiers, ventes, stock, équipe et abonnement. Votre « Ma santé » et vos autres établissements restent.',
                      style: TextStyle(color: Kolors.kTextMuted),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Kolors.kRed,
                        side: const BorderSide(color: Kolors.kRed),
                      ),
                      onPressed: compte.chargement
                          ? null
                          : () => _supprimer(espace),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Supprimer définitivement'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Le nom retapé : on ne supprime pas tout un établissement par erreur.
class _ConfirmerSuppression extends StatefulWidget {
  const _ConfirmerSuppression({required this.nom});

  final String nom;

  @override
  State<_ConfirmerSuppression> createState() => _ConfirmerSuppressionState();
}

class _ConfirmerSuppressionState extends State<_ConfirmerSuppression> {
  final _saisie = TextEditingController();

  bool get _identique =>
      _saisie.text.trim().toLowerCase() == widget.nom.trim().toLowerCase();

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Supprimer pour de bon ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Toutes les données de « ${widget.nom} » seront effacées, sans retour possible. Retapez son nom pour confirmer.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _saisie,
            autofocus: true,
            decoration: InputDecoration(hintText: widget.nom),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Kolors.kRed),
          onPressed: _identique
              ? () => Navigator.of(context).pop(_saisie.text)
              : null,
          child: const Text('Supprimer'),
        ),
      ],
    );
  }
}
