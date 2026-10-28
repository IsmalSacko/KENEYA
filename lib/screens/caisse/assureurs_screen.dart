import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../caisse/caisse_service.dart';
import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../common/widgets/formulaire.dart';

/// Les assureurs (taux, plafond) et le bordereau du mois de chacun.
class AssureursScreen extends StatefulWidget {
  const AssureursScreen({super.key});

  @override
  State<AssureursScreen> createState() => _AssureursScreenState();
}

class _AssureursScreenState extends State<AssureursScreen> {
  final _service = CaisseService();
  List<Assureur>? _liste;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final l = await _service.assureurs();
      if (mounted) setState(() => _liste = l);
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _editer([Assureur? a]) async {
    final devise = context.read<AuthController>().devise;
    final nom = TextEditingController(text: a?.nom);
    final taux = TextEditingController(text: a == null ? '' : '${a.taux}');
    final plafond = TextEditingController(
      text: a?.plafond == null ? '' : '${a!.plafond}',
    );
    var actif = a?.actif ?? true;
    final ok = await formulaire<bool>(
      context,
      titre: Text(a == null ? 'Nouvel assureur' : a.nom),
      corps: (ctx, setState) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nom,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nom (ex. AMO, mutuelle…)',
            ),
          ),
          TextField(
            controller: taux,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Part prise en charge (%)',
            ),
          ),
          TextField(
            controller: plafond,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Plafond par visite ($devise, facultatif)',
            ),
          ),
          if (a != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Actif'),
              value: actif,
              onChanged: (v) => setState(() => actif = v),
            ),
        ],
      ),
      actions: (ctx, setState) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Enregistrer'),
        ),
      ],
    );
    if (ok != true) return;
    try {
      await _service.enregistrerAssureur({
        'nom': nom.text.trim(),
        'taux': int.tryParse(taux.text),
        'plafond': int.tryParse(plafond.text),
        if (a != null) 'actif': actif,
      }, uuid: a?.uuid);
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  /// Le mois à réclamer : celui-ci ou un des 11 précédents.
  Future<String?> _choisirMois() {
    final maintenant = DateTime.now();
    final mois = [
      for (var i = 0; i < 12; i++)
        DateTime(maintenant.year, maintenant.month - i),
    ];
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Bordereau de quel mois ?'),
        children: [
          for (final m in mois)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(ctx, DateFormat('yyyy-MM').format(m)),
              child: Text(DateFormat.yMMMM('fr').format(m)),
            ),
        ],
      ),
    );
  }

  /// Le bordereau en CSV (point-virgule, comme le serveur), à envoyer.
  Future<void> _partager(
    Assureur a,
    String mois,
    List<Map> lignes,
    Map<String, dynamic> b,
  ) async {
    String c(Object? v) => '"${'${v ?? ''}'.replaceAll('"', '""')}"';
    final csv = StringBuffer(
      'Date;Patient;N° assuré;Total;Taux %;Part assureur (${b['devise']})\n',
    );
    for (final l in lignes) {
      csv.writeln(
        [
          l['date'],
          l['patient'],
          l['numero_assure'],
          l['total'],
          l['taux'],
          l['part_assureur'],
        ].map(c).join(';'),
      );
    }
    csv.writeln(';;;;Total;${b['total']}');
    final nom =
        'Bordereau-${a.nom.replaceAll(RegExp(r'[^\w-]+'), '-')}-$mois.csv';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode('\uFEFF$csv')),
            mimeType: 'text/csv',
            name: nom,
          ),
        ],
        fileNameOverrides: [nom],
        text: 'Bordereau ${a.nom} · $mois',
      ),
    );
  }

  Future<void> _bordereau(Assureur a) async {
    final mois = await _choisirMois();
    if (mois == null) return;
    final Map<String, dynamic> b;
    try {
      b = await _service.bordereau(a.uuid, mois);
    } on DioException catch (e) {
      _dire(messageErreur(e));
      return;
    }
    if (!mounted) return;
    final devise = '${b['devise']}';
    final lignes = (b['lignes'] as List).whereType<Map>().toList();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text('${a.nom} · $mois'),
            actions: [
              if (lignes.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _partager(a, mois, lignes, b),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Envoyer (CSV)'),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'À réclamer : ${formatMontant(int.tryParse('${b['total']}') ?? 0, devise)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (lignes.isEmpty)
                const Text('Aucune visite couverte ce mois-ci.'),
              for (final l in lignes)
                Card(
                  child: ListTile(
                    dense: true,
                    title: Text('${l['patient'] ?? ''}'),
                    subtitle: Text(
                      '${l['date']} · N° ${l['numero_assure'] ?? '—'} · ${l['taux']} % de ${formatMontant(int.tryParse('${l['total']}') ?? 0, devise)}',
                    ),
                    trailing: Text(
                      formatMontant(
                        int.tryParse('${l['part_assureur']}') ?? 0,
                        devise,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devise = context.watch<AuthController>().devise;
    final l = _liste;
    return Scaffold(
      appBar: AppBar(title: const Text('Assureurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editer(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel assureur'),
      ),
      body: l == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (l.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text(
                      'Aucun assureur. « Nouvel assureur » pour ajouter l’AMO ou une mutuelle.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Kolors.kTextMuted),
                    ),
                  ),
                for (final a in l)
                  Card(
                    child: ListTile(
                      title: Text(
                        a.nom,
                        style: TextStyle(
                          color: a.actif ? null : Kolors.kTextMuted,
                        ),
                      ),
                      subtitle: Text(
                        [
                          '${a.taux} % pris en charge',
                          if (a.plafond != null)
                            'plafond ${formatMontant(a.plafond!, devise)}',
                        ].join(' · '),
                      ),
                      trailing: TextButton(
                        onPressed: () => _bordereau(a),
                        child: const Text('Bordereau'),
                      ),
                      onTap: () => _editer(a),
                    ),
                  ),
              ],
            ),
    );
  }
}
