import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../caisse/caisse_service.dart';
import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../common/widgets/formulaire.dart';

/// Les tarifs de l'établissement, et le rapport de caisse du jour.
class TarifsScreen extends StatefulWidget {
  const TarifsScreen({super.key});

  @override
  State<TarifsScreen> createState() => _TarifsScreenState();
}

class _TarifsScreenState extends State<TarifsScreen> {
  final _service = CaisseService();
  List<Tarif> _tarifs = [];
  Map<String, dynamic>? _rapport;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  String get _devise => context.read<AuthController>().devise;

  Future<void> _charger() async {
    try {
      final t = await _service.tarifs();
      Map<String, dynamic>? r;
      if (mounted && context.read<AuthController>().peut('caisse.rapports')) {
        r = await _service.rapport();
      }
      if (mounted) {
        setState(() {
          _tarifs = t;
          _rapport = r;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  Future<void> _editer([Tarif? t]) async {
    final nom = TextEditingController(text: t?.nom);
    final prix = TextEditingController(
      text: t == null
          ? ''
          : formatMontant(t.prix, _devise).replaceAll(RegExp(r'[^\d,]'), ''),
    );
    var categorie = t?.categorie ?? 'consultation';
    final donnees = await formulaire<Map<String, dynamic>>(
      context,
      titre: Text(t == null ? 'Nouveau tarif' : 'Modifier le tarif'),
      corps: (ctx, setD) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nom,
            decoration: const InputDecoration(
              labelText: 'Acte (ex. Consultation générale)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: prix,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d ,.]')),
            ],
            decoration: InputDecoration(labelText: 'Prix ($_devise)'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: categorie,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: [
              for (final c in libellesCategories.entries)
                DropdownMenuItem(value: c.key, child: Text(c.value)),
            ],
            onChanged: (v) => setD(() => categorie = v ?? categorie),
          ),
        ],
      ),
      actions: (ctx, setD) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            final p = lireMontant(prix.text, _devise);
            if (nom.text.trim().isEmpty || p == null) return;
            Navigator.pop(ctx, {
              'nom': nom.text.trim(),
              'prix': p,
              'categorie': categorie,
            });
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
    if (donnees == null) return;
    try {
      await _service.enregistrerTarif(donnees, uuid: t?.uuid);
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
    final r = _rapport;
    return Scaffold(
      appBar: AppBar(title: const Text('Tarifs et rapport')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editer(),
        icon: const Icon(Icons.add),
        label: const Text('Tarif'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (r != null) ...[
            Text(
              'Aujourd’hui',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['visites']} visites · facturé ${formatMontant((r['facture'] as num).toInt(), _devise)}',
                    ),
                    Text(
                      'Encaissé ${formatMontant((r['encaisse'] as num).toInt(), _devise)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Kolors.kSuccess,
                      ),
                    ),
                    Text(
                      'Impayé ${formatMontant((r['impaye'] as num).toInt(), _devise)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Kolors.kGold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final m in (r['par_moyen'] as List).cast<Map>())
                      Text(
                        '${libellesMoyens[m['moyen']] ?? m['moyen']} : ${formatMontant((m['total'] as num).toInt(), _devise)} (${m['nombre']})',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Tarifs',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Card(
            child: Column(
              children: [
                if (_tarifs.isEmpty)
                  const ListTile(
                    title: Text('Aucun tarif. Ajoutez vos actes et leur prix.'),
                  ),
                for (final t in _tarifs)
                  ListTile(
                    title: Text(t.nom),
                    subtitle: Text(
                      libellesCategories[t.categorie] ?? t.categorie,
                    ),
                    trailing: Text(
                      formatMontant(t.prix, _devise),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => _editer(t),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
