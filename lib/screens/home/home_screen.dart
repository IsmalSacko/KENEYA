import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:keneya_plus/common/utils/kcolors.dart';
import 'package:keneya_plus/common/utils/roles.dart';
import 'package:keneya_plus/screens/home/tabs/aujourdhui_tab.dart';
import 'package:keneya_plus/screens/home/tabs/profile_tab_state.dart';
import 'package:keneya_plus/screens/home/tabs/reglages_tab.dart';
import 'package:keneya_plus/screens/file/file_tab.dart';
import 'package:keneya_plus/screens/patients/patients_tab.dart';
import 'package:keneya_plus/screens/labo/labo_tab.dart';
import 'package:keneya_plus/screens/maternite/maternite_tab.dart';
import 'package:keneya_plus/screens/hospitalisation/hospit_tab.dart';
import 'package:keneya_plus/screens/presence/entree_tab.dart';
import 'package:keneya_plus/screens/rdv/rdv_tab.dart';
import 'package:keneya_plus/screens/caisse/caisse_tab.dart';
import 'package:keneya_plus/screens/pharmacie/pharmacie_tab.dart';
import 'package:keneya_plus/screens/home/tabs/users_tab.dart';
import 'package:provider/provider.dart';

import '../../core/offline/sync_manager.dart';
import '../compte/espaces_sheet.dart';
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
  Future<void> _plus(List<_NavTab> onglets) async {
    final choix = await feuille<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = _visibles; i < onglets.length; i++)
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
    if (choix != null) setState(() => _tabIndex = choix);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1000;
    final isTablet = screenWidth >= 700 && screenWidth < 1000;
    final shouldUseCompactNavLabels = screenWidth < 480;
    final auth = context.watch<AuthController>();
    final userCtrl = context.watch<UserController>();

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
          title: 'Pharmacie',
          shortLabel: 'Pharma.',
          icon: Icons.local_pharmacy_outlined,
          selectedIcon: Icons.local_pharmacy,
          page: const PharmacieTab(),
        ),
      if (canManageUsers)
        _NavTab(
          title: 'Utilisateurs',
          shortLabel: 'Utilis.',
          icon: Icons.person_add_alt_outlined,
          selectedIcon: Icons.person_add_alt_1,
          page: UsersTab(userCtrl: userCtrl),
        ),
      if (peutRegler)
        _NavTab(
          title: 'Réglages',
          shortLabel: 'Réglages',
          icon: Icons.tune_outlined,
          selectedIcon: Icons.tune,
          page: const ReglagesTab(),
        ),
      _NavTab(
        title: 'Profil',
        shortLabel: 'Profil',
        icon: Icons.account_circle_outlined,
        selectedIcon: Icons.account_circle,
        page: const ProfileTab(),
      ),
    ];

    // Le rôle peut changer le nombre d'onglets : on borne l'index courant.
    final safeIndex = navTabs.isEmpty
        ? 0
        : _tabIndex.clamp(0, navTabs.length - 1);

    final content = Column(
      children: [
        if (_isOffline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Kolors.kJauneDoux,
            child: const Text(
              'Mode hors connexion actif. Les modifications seront synchronisees automatiquement.',
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
                      '$pending operation(s) en attente de synchronisation.',
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
        Expanded(child: navTabs[safeIndex].page),
      ],
    );

    if (isDesktop || isTablet) {
      return Scaffold(
        appBar: AppBar(
          title: Text(navTabs[safeIndex].title),
          actions: const [BoutonEspaces()],
        ),
        body: Row(
          children: [
            // Beaucoup d'onglets : le rail défile au lieu de déborder.
            LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: safeIndex,
                      onDestinationSelected: (value) =>
                          setState(() => _tabIndex = value),
                      labelType: isDesktop
                          ? NavigationRailLabelType.all
                          : NavigationRailLabelType.selected,
                      destinations: [
                        for (final t in navTabs)
                          NavigationRailDestination(
                            icon: Icon(t.icon),
                            selectedIcon: Icon(t.selectedIcon),
                            label: Text(t.title),
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
      appBar: AppBar(
        title: Text(navTabs[safeIndex].title),
        actions: const [BoutonEspaces()],
      ),
      body: content,
      // Au téléphone, 4 onglets au plus ; les autres sous « Plus ».
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex < _visibles
            ? safeIndex
            : (navTabs.length > _visibles + 1 ? _visibles : safeIndex),
        onDestinationSelected: (value) {
          if (navTabs.length > _visibles + 1 && value == _visibles) {
            _plus(navTabs);
          } else {
            setState(() => _tabIndex = value);
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
