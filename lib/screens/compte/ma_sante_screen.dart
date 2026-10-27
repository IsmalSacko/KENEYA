import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../compte/compte_controller.dart';
import '../../compte/mes_tickets_controller.dart';
import '../../controllers/auth_controller.dart';
import '../ma_sante/mes_visites_screen.dart';
import '../pharmacie/ordonnance_screens.dart';
import '../ma_sante/rdv_patient_screens.dart';
import '../file/ticket_carte.dart';
import '../ma_sante/search_screen.dart';
import '../ma_sante/mon_dossier_screen.dart';
import '../ma_sante/ma_maternite_screen.dart';
import 'creer_etablissement_screen.dart';
import 'espaces_sheet.dart';

/// L'espace « Ma santé » : toujours là, pour tout le monde. Les espaces pro
/// de la personne s'ouvrent d'ici.
class MaSanteScreen extends StatelessWidget {
  const MaSanteScreen({super.key});

  Future<void> _deconnexion(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous devrez entrer votre numéro et votre PIN pour revenir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    context.read<MesTicketsController>().arreter();
    await context.read<CompteController>().deconnexion(
      context.read<AuthController>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compte = context.watch<CompteController>();
    final personne = compte.personne!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma santé'),
        actions: [
          const BoutonEspaces(),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _deconnexion(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: compte.rafraichir,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CarteMarque(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour${personne.prenom.isEmpty ? '' : ', ${personne.prenom}'} !',
                          style: GoogleFonts.poppins(
                            color: Kolors.kWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          personne.telephone,
                          style: TextStyle(
                            color: Kolors.kWhite.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AvatarMarque(Icons.favorite_rounded, size: 54),
                ],
              ),
            ),
            const _MesTickets(),
            const SizedBox(height: 20),
            const _Titre('Mes services'),
            _Tuile(
              icone: Icons.search_rounded,
              titre: 'Trouver un établissement',
              texte: 'Cabinets, pharmacies, centres de santé près de vous.',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
            ),
            _Tuile(
              icone: Icons.event_note_rounded,
              titre: 'Mes rendez-vous',
              texte: 'Vos rendez-vous, leur QR, et « je suis arrivé ».',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MesRdvScreen())),
            ),
            _Tuile(
              icone: Icons.folder_shared_rounded,
              titre: 'Mon dossier',
              texte: 'Consultations, allergies, et qui peut le voir.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MonDossierScreen()),
              ),
            ),
            _Tuile(
              icone: Icons.child_friendly_rounded,
              titre: 'Grossesse et enfants',
              texte: 'Suivi de grossesse, carnet de vaccination.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MaMaterniteScreen()),
              ),
            ),
            _Tuile(
              icone: Icons.medication_rounded,
              titre: 'Mes ordonnances',
              texte: 'À montrer à la pharmacie : le QR suffit.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MesOrdonnancesScreen()),
              ),
            ),
            _Tuile(
              icone: Icons.receipt_long_rounded,
              titre: 'Mes paiements',
              texte: 'Ce qui a été fait et payé à chaque visite.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MesVisitesScreen()),
              ),
            ),
            _Tuile(
              icone: Icons.qr_code_2_rounded,
              titre: 'Ma carte santé',
              texte: 'Le QR qui vous fait reconnaître à l’accueil.',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CarteSanteScreen()),
              ),
            ),
            const SizedBox(height: 20),
            const _Titre('Espace pro'),
            for (final espace in compte.espaces)
              _Tuile(
                icone: Icons.local_hospital_rounded,
                titre: espace.etablissementNom,
                texte: '${espace.roleLabel} · ${espace.profilLabel}',
                onTap: espace.actif
                    ? () => ouvrirEspace(context, espace)
                    : null,
              ),
            _Tuile(
              icone: Icons.add_business_rounded,
              titre: 'Créer mon établissement',
              texte: 'Cabinet, pharmacie, centre de santé, clinique…',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreerEtablissementScreen(),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text(
                'Vous travaillez dans un établissement ? Demandez à son responsable de vous ajouter avec votre numéro : il apparaîtra ici.',
                style: TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
              ),
            ),
            if (compte.chargement)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
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
}

class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.icone,
    required this.titre,
    required this.texte,
    required this.onTap,
  });

  final IconData icone;
  final String titre;
  final String texte;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Kolors.kSurface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Kolors.kBorder),
              boxShadow: Kolors.softShadow(),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Kolors.kSecondaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icone, color: Kolors.kPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Kolors.kTextHigh,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        onTap == null ? 'Accès désactivé' : texte,
                        style: const TextStyle(
                          color: Kolors.kTextMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Kolors.kTextMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Les tickets en cours de la personne, suivis en direct.
class _MesTickets extends StatefulWidget {
  const _MesTickets();

  @override
  State<_MesTickets> createState() => _MesTicketsState();
}

class _MesTicketsState extends State<_MesTickets> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MesTicketsController>().rafraichir(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mes = context.watch<MesTicketsController>();
    final enCours = mes.enCours;
    if (enCours.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const _Titre('Mes tickets'),
        for (final t in enCours) ...[
          TicketCarte(ticket: t, qr: false),
          if (t.enAttente)
            TextButton(
              onPressed: () => mes.annuler(t),
              child: const Text('Je ne viendrai pas : annuler ce ticket'),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
