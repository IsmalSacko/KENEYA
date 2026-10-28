import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:keneya_plus/common/utils/kcolors.dart';
import 'package:keneya_plus/common/utils/roles.dart';
import 'package:keneya_plus/screens/home/tabs/aujourdhui_tab.dart';
import 'package:keneya_plus/screens/file/file_tab.dart';
import 'package:keneya_plus/screens/patients/patients_tab.dart';
import 'package:keneya_plus/screens/labo/labo_tab.dart';
import 'package:keneya_plus/screens/maternite/maternite_tab.dart';
import 'package:keneya_plus/screens/hospitalisation/hospit_tab.dart';
import 'package:keneya_plus/screens/presence/entree_tab.dart';
import 'package:keneya_plus/screens/rdv/rdv_tab.dart';
import 'package:keneya_plus/screens/caisse/caisse_tab.dart';
import 'package:keneya_plus/screens/pharmacie/pharmacie_tab.dart';
import 'package:keneya_plus/screens/pharmacie/vendre_screen.dart';
import 'package:provider/provider.dart';

import '../../core/offline/sync_manager.dart';
import 'menu_etablissement.dart';
import 'ouvrir_onglet.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/etablissement_controller.dart';
import '../../controllers/medicament_controller.dart';
import '../../controllers/patient_controller.dart';
import '../../controllers/user_controller.dart';
import '../../common/widgets/feuille.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  int _tabIndex = 0;

  /// L'onglet choisi, retenu par son nom : quand un module s'allume ou
  /// s'éteint, la liste change, mais on reste sur le même onglet.
  String? _ongletChoisi;
  late final VoidCallback _pendingListener;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      setState(() {
        _isOffline = results.every((r) => r == ConnectivityResult.none);
      });
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      final wasOffline = _isOffline;
      final nowOffline = results.every((r) => r == ConnectivityResult.none);
      setState(() {
        _isOffline = nowOffline;
      });
      if (wasOffline && !nowOffline) {
        _refreshAll();
      }
    });

    _pendingListener = () {
      if (!mounted) return;
      if (SyncManager.instance.pendingCount.value == 0 && !_isOffline) {
        _refreshAll();
      }
    };
    SyncManager.instance.pendingCount.addListener(_pendingListener);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshAll();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    SyncManager.instance.pendingCount.removeListener(_pendingListener);
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await context.read<PatientController>().fetchPatients();
    if (!mounted) return;
    await context.read<MedicamentController>().fetchMedicaments();
    if (!mounted) return;
    await context.read<EtablissementController>().fetchEtablissements();
    if (!mounted) return;
    await context.read<UserController>().fetchUsers();
  }

  /// Les onglets qui ne tiennent pas dans la barre du bas.
  Future<void> _plus(List<_NavTab> onglets, int debut) async {
    final choix = await feuille<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = debut; i < onglets.length; i++)
                ListTile(
                  leading: Icon(onglets[i].icon),
                  title: Text(onglets[i].title),
                  selected: i == _tabIndex,
                  onTap: () => Navigator.pop(ctx, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (choix != null) _choisir(onglets, choix);
  }

  void _choisir(List<_NavTab> onglets, int index) => setState(() {
    _tabIndex = index;
    _ongletChoisi = onglets[index].title;
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1000;
    final isTablet = screenWidth >= 700 && screenWidth < 1000;
    final shouldUseCompactNavLabels = screenWidth < 480;
    final auth = context.watch<AuthController>();

    // L'onglet "Utilisateurs" (gestion du personnel) n'est visible que pour les
    // administrateurs (instance ou établissement).
    // Droits du membre (Ngoni Santé) ; repli sur le rôle tant qu'une
    // session 3.x n'a pas encore reçu ses droits.
    final sansDroits = auth.permissions.isEmpty;
    final canManageUsers = sansDroits
        ? AppRoles.canAdministerEtablissement(auth.currentUser?.role)
        : auth.peut('equipe.gerer');
    final peutRegler = auth.peut('etablissement.regler');
    final voitRdv =
        auth.aModule('rdv') &&
        (auth.peut('rdv.voir') || auth.peut('rdv.gerer'));
    final voitPharmacie =
        auth.aModule('pharmacie') &&
        (auth.peut('pharmacie.delivrer') || auth.peut('stock.gerer'));
    final voitCaisse =
        auth.aModule('caisse') &&
        (auth.peut('caisse.encaisser') || auth.peut('caisse.rapports'));
    final voitFile =
        auth.aModule('file') &&
        ['file.emettre', 'file.appeler', 'file.gerer'].any(auth.peut);
    final voitPatients =
        auth.peut('patients.voir') || auth.peut('dossier.lire');
    final voitMaternite =
        auth.aModule('maternite') && auth.peut('maternite.suivre');
    final voitHospit =
        auth.aModule('hospitalisation') &&
        (auth.peut('hospitalisation.gerer') || auth.peut('soins.administrer'));
    final voitEntree =
        (auth.aModule('badges') &&
            (auth.peut('badges.gerer') || auth.peut('file.emettre'))) ||
        (auth.aModule('hospitalisation') &&
            (auth.peut('file.emettre') || auth.peut('hospitalisation.gerer')));
    final voitLabo =
        auth.aModule('labo') &&
        (auth.peut('labo.saisir') || auth.peut('labo.valider'));

    final navTabs = <_NavTab>[
      // Une officine est un commerce : on ouvre sur la caisse de vente.
      if (auth.estOfficine &&
          auth.aModule('pharmacie') &&
          auth.peut('pharmacie.delivrer'))
        const _NavTab(
          title: 'Vendre',
          shortLabel: 'Vendre',
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          page: VendreScreen(onglet: true),
        ),
      _NavTab(
        title: 'Accueil',
        shortLabel: 'Accueil',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        page: const AujourdhuiTab(),
      ),
      if (voitFile)
        _NavTab(
          title: 'File d’attente',
          shortLabel: 'File',
          icon: Icons.groups_2_outlined,
          selectedIcon: Icons.groups_2,
          page: const FileTab(),
        ),
      if (voitPatients)
        _NavTab(
          title: 'Patients',
          shortLabel: 'Patients',
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          page: const PatientsTab(),
        ),
      if (voitLabo)
        _NavTab(
          title: 'Laboratoire',
          shortLabel: 'Labo',
          icon: Icons.science_outlined,
          selectedIcon: Icons.science,
          page: const LaboTab(),
        ),
      if (voitMaternite)
        _NavTab(
          title: 'Maternité',
          shortLabel: 'Matern.',
          icon: Icons.pregnant_woman_outlined,
          selectedIcon: Icons.pregnant_woman,
          page: const MaterniteTab(),
        ),
      if (voitHospit)
        _NavTab(
          title: 'Hospitalisation',
          shortLabel: 'Hospit.',
          icon: Icons.bed_outlined,
          selectedIcon: Icons.bed,
          page: const HospitTab(),
        ),
      if (voitEntree)
        _NavTab(
          title: 'Entrée',
          shortLabel: 'Entrée',
          icon: Icons.door_front_door_outlined,
          selectedIcon: Icons.door_front_door,
          page: const EntreeTab(),
        ),
      if (voitRdv)
        _NavTab(
          title: 'Rendez-vous',
          shortLabel: 'RDV',
          icon: Icons.event_note_outlined,
          selectedIcon: Icons.event_note,
          page: const RdvTab(),
        ),
      if (voitCaisse)
        _NavTab(
          title: 'Caisse',
          shortLabel: 'Caisse',
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          page: const CaisseTab(),
        ),
      if (voitPharmacie)
        _NavTab(
          // Dans une officine, la pharmacie c'est le stock : on vend ailleurs.
          title: auth.estOfficine ? 'Stock' : 'Pharmacie',
          shortLabel: auth.estOfficine ? 'Stock' : 'Pharma.',
          icon: Icons.local_pharmacy_outlined,
          selectedIcon: Icons.local_pharmacy,
          page: const PharmacieTab(),
        ),
    ];
    // Le métier de chacun d'abord : ses onglets à lui viennent en tête, le
    // reste passe sous « Plus ». Équipe, réglages et profil sont dans le menu
    // de l'établissement, en haut.
    final ordre = _ordreDuRole(auth.currentUser?.role);
    int rang(_NavTab t) {
      if (t.title == 'Vendre') return -2;
      if (t.title == 'Accueil') return -1;
      final i = ordre.indexOf(t.title);
      return i < 0 ? ordre.length : i;
    }

    final rangs = {for (var i = 0; i < navTabs.length; i++) navTabs[i]: i};
    navTabs.sort((a, b) {
      final r = rang(a).compareTo(rang(b));
      return r != 0 ? r : rangs[a]!.compareTo(rangs[b]!);
    });
    final estAdmin = AppRoles.canAdministerEtablissement(
      auth.currentUser?.role,
    );
    final acces = AccesGestion(
      equipe: canManageUsers,
      reglages: peutRegler,
      rapport:
          auth.aFonction('rapport') &&
          (auth.peut('stats.voir') ||
              auth.peut('caisse.rapports') ||
              peutRegler),
      abonnement: estAdmin,
    );

    // Le rôle peut changer le nombre d'onglets : on borne l'index courant.
    final retenu = navTabs.indexWhere((t) => t.title == _ongletChoisi);
    final safeIndex = navTabs.isEmpty
        ? 0
        : (retenu >= 0 ? retenu : _tabIndex.clamp(0, navTabs.length - 1));

    final content = Column(
      children: [
        if (!auth.etablissementValide)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Kolors.kJauneDoux,
            child: const Text(
              'En attente de vérification par Ngoni Santé : configurez tout, les patients verront votre établissement une fois vérifié.',
            ),
          ),
        BandeauAbonnement(admin: estAdmin),
        if (_isOffline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Kolors.kJauneDoux,
            child: const Text(
              'Mode hors connexion actif. Les modifications seront synchronisées automatiquement.',
            ),
          ),
        ValueListenableBuilder<int>(
          valueListenable: SyncManager.instance.pendingCount,
          builder: (context, pending, _) {
            if (pending == 0) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Kolors.kSecondaryLight,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$pending opération(s) en attente de synchronisation.',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => SyncManager.instance.syncNow(),
                    icon: const Icon(Icons.sync),
                    label: const Text('Synchroniser'),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(
          child: OuvrirOnglet(
            ouvrirOnglet: (titre) {
              final i = navTabs.indexWhere((t) => t.title == titre);
              if (i >= 0) _choisir(navTabs, i);
            },
            child: navTabs[safeIndex].page,
          ),
        ),
      ],
    );

    final appBar = AppBar(
      centerTitle: false,
      titleSpacing: 12,
      title: BoutonEtablissement(acces: acces),
    );

    if (isDesktop || isTablet) {
      final visibles = isDesktop ? 6 : 5;
      final avecPlus = navTabs.length > visibles + 1;
      final rail = avecPlus ? navTabs.take(visibles).toList() : navTabs;
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            // Beaucoup d'onglets : le rail défile au lieu de déborder.
            LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: safeIndex < rail.length
                          ? safeIndex
                          : rail.length,
                      onDestinationSelected: (value) => value < rail.length
                          ? _choisir(navTabs, value)
                          : _plus(navTabs, rail.length),
                      // Peu d'onglets désormais : leurs noms restent visibles.
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final t in rail)
                          NavigationRailDestination(
                            icon: Icon(t.icon),
                            selectedIcon: Icon(t.selectedIcon),
                            label: Text(t.title),
                          ),
                        if (avecPlus)
                          NavigationRailDestination(
                            icon: const Icon(Icons.more_horiz_rounded),
                            label: Text(
                              safeIndex >= rail.length
                                  ? navTabs[safeIndex].title
                                  : 'Plus',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: content,
      // Au téléphone, 4 onglets au plus ; les autres sous « Plus ».
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex < _visibles
            ? safeIndex
            : (navTabs.length > _visibles + 1 ? _visibles : safeIndex),
        onDestinationSelected: (value) {
          if (navTabs.length > _visibles + 1 && value == _visibles) {
            _plus(navTabs, _visibles);
          } else {
            _choisir(navTabs, value);
          }
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final t
              in navTabs.length > _visibles + 1
                  ? navTabs.take(_visibles)
                  : navTabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: shouldUseCompactNavLabels ? t.shortLabel : t.title,
            ),
          if (navTabs.length > _visibles + 1)
            NavigationDestination(
              icon: const Icon(Icons.more_horiz_rounded),
              label: safeIndex >= _visibles
                  ? navTabs[safeIndex].shortLabel
                  : 'Plus',
            ),
        ],
      ),
    );
  }
}

/// Onglets visibles dans la barre du bas d'un téléphone.
const _visibles = 4;

/// Les onglets du métier, dans l'ordre où on s'en sert.
List<String> _ordreDuRole(String? role) => switch (role) {
  AppRoles.accueil => ['File d’attente', 'Patients', 'Rendez-vous', 'Entrée'],
  AppRoles.medecin || AppRoles.infirmier => [
    'File d’attente',
    'Patients',
    'Rendez-vous',
    'Hospitalisation',
    'Laboratoire',
  ],
  AppRoles.sageFemme => [
    'Maternité',
    'File d’attente',
    'Patients',
    'Rendez-vous',
  ],
  AppRoles.laborantin => ['Laboratoire', 'File d’attente', 'Patients'],
  AppRoles.caissier => ['Caisse', 'File d’attente', 'Patients'],
  AppRoles.pharmacien => ['Stock', 'Pharmacie', 'Caisse'],
  _ => ['File d’attente', 'Patients', 'Caisse', 'Rendez-vous'],
};

/// Description d'un onglet de navigation de l'accueil.
class _NavTab {
  const _NavTab({
    required this.title,
    required this.shortLabel,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String title;
  final String shortLabel;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}
