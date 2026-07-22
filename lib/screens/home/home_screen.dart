import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:keneya_plus/common/utils/roles.dart';
import 'package:keneya_plus/screens/home/tabs/dashboard_tab.dart';
import 'package:keneya_plus/screens/home/tabs/modules_tab.dart';
import 'package:keneya_plus/screens/home/tabs/patients_tab.dart';
import 'package:keneya_plus/screens/home/tabs/profile_tab_state.dart';
import 'package:keneya_plus/screens/home/tabs/users_tab.dart';
import 'package:provider/provider.dart';

import '../../core/offline/sync_manager.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/etablissement_controller.dart';
import '../../controllers/medicament_controller.dart';
import '../../controllers/patient_controller.dart';
import '../../controllers/user_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1000;
    final isTablet = screenWidth >= 700 && screenWidth < 1000;
    final shouldUseCompactNavLabels = screenWidth < 480;
    final auth = context.watch<AuthController>();
    final patientCtrl = context.watch<PatientController>();
    final medicamentCtrl = context.watch<MedicamentController>();
    final etablissementCtrl = context.watch<EtablissementController>();
    final userCtrl = context.watch<UserController>();

    // L'onglet "Utilisateurs" (gestion du personnel) n'est visible que pour les
    // administrateurs (instance ou établissement).
    final canManageUsers = AppRoles.canAdministerEtablissement(
      auth.currentUser?.role,
    );

    final navTabs = <_NavTab>[
      _NavTab(
        title: 'Accueil',
        shortLabel: 'Accueil',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        page: DashboardTab(
          auth: auth,
          patientCtrl: patientCtrl,
          medicamentCtrl: medicamentCtrl,
          etablissementCtrl: etablissementCtrl,
          userCtrl: userCtrl,
          onRefresh: _refreshAll,
        ),
      ),
      _NavTab(
        title: 'Patients',
        shortLabel: 'Patients',
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        page: PatientsTab(
          patientCtrl: patientCtrl,
          onRefresh: () => context.read<PatientController>().fetchPatients(),
        ),
      ),
      if (canManageUsers)
        _NavTab(
          title: 'Utilisateurs',
          shortLabel: 'Utilis.',
          icon: Icons.person_add_alt_outlined,
          selectedIcon: Icons.person_add_alt_1,
          page: UsersTab(userCtrl: userCtrl),
        ),
      _NavTab(
        title: 'Ressources',
        shortLabel: 'Ress.',
        icon: Icons.widgets_outlined,
        selectedIcon: Icons.widgets,
        page: const ModulesTab(),
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
            color: Colors.orange.withValues(alpha: 0.14),
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
              color: Colors.blue.withValues(alpha: 0.10),
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
        appBar: AppBar(title: Text(navTabs[safeIndex].title)),
        body: Row(
          children: [
            NavigationRail(
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
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(navTabs[safeIndex].title)),
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (value) => setState(() => _tabIndex = value),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [
          for (final t in navTabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: shouldUseCompactNavLabels ? t.shortLabel : t.title,
            ),
        ],
      ),
    );
  }
}

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
