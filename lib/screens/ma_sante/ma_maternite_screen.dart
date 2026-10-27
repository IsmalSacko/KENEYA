import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../compte/compte_api.dart';
import '../../core/api/api_client.dart';
import '../../maternite/maternite_models.dart';
import '../dossier/dossier_widgets.dart';
import '../maternite/carnet_screen.dart';
import '../maternite/grossesse_screen.dart';

/// Sa grossesse (semaines, terme, prochaine CPN) et le carnet de vaccination
/// de ses enfants : il ne se perd plus.
class MaMaterniteScreen extends StatefulWidget {
  const MaMaterniteScreen({super.key});

  @override
  State<MaMaterniteScreen> createState() => _MaMaterniteScreenState();
}

class _MaMaterniteScreenState extends State<MaMaterniteScreen> {
  Grossesse? _grossesse;
  List<CarnetEnfant>? _enfants;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    CompteApi()
        .maMaternite()
        .then((m) {
          if (!mounted) return;
          final g = m['grossesse'];
          final e = m['enfants'];
          setState(() {
            _grossesse = g is Map
                ? Grossesse.fromJson(Map<String, dynamic>.from(g))
                : null;
            _enfants = [
              if (e is List)
                for (final x in e.whereType<Map>())
                  CarnetEnfant.fromJson(Map<String, dynamic>.from(x)),
            ];
          });
        })
        .catchError((Object e) {
          if (mounted) {
            setState(
              () => _erreur = e is DioException
                  ? messageErreur(e)
                  : 'Indisponible.',
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final enfants = _enfants;
    final g = _grossesse;
    return Scaffold(
      appBar: AppBar(title: const Text('Grossesse et enfants')),
      body: enfants == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (g != null) ...[
                  CarteMarque(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${g.semaines} semaines',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Kolors.kJaune,
                          ),
                        ),
                        Text(
                          'Terme prévu le ${dateCourte(DateTime.tryParse(g.dpa))}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (g.prochainRdv != null)
                          Text(
                            'Prochaine consultation le ${dateCourte(DateTime.tryParse(g.prochainRdv!))}',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final c in g.cpn.reversed) CarteCpn(c),
                ],
                if (g == null && enfants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text(
                      'Votre grossesse et le carnet de vaccination de vos enfants apparaissent ici dès que la maternité les note.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Kolors.kTextMuted),
                    ),
                  ),
                for (final e in enfants) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                    child: Text(
                      e.enfant.nom,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CarnetVaccins(e),
                ],
              ],
            ),
    );
  }
}
