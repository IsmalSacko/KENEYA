import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
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
    final isFrench = Localizations.localeOf(context).languageCode == 'fr';
    final auth = context.watch<AuthController>();
    final patientCtrl = context.watch<PatientController>();
    final medicamentCtrl = context.watch<MedicamentController>();
    final etablissementCtrl = context.watch<EtablissementController>();
    final userCtrl = context.watch<UserController>();

    final tabTitles = isFrench
        ? ['Accueil', 'Patients', 'Utilisateurs', 'Ressources', 'Profil']
        : ['Home', 'Patients', 'Users', 'Resources', 'Profile'];
    final compactNavLabels = isFrench
        ? ['Accueil', 'Patients', 'Utilis.', 'Ress.', 'Profil']
        : ['Home', 'Patients', 'Users', 'Res.', 'Profile'];
    final bottomNavLabels = shouldUseCompactNavLabels
        ? compactNavLabels
        : tabTitles;

    final pages = [
      DashboardTab(
        auth: auth,
        patientCtrl: patientCtrl,
        medicamentCtrl: medicamentCtrl,
        etablissementCtrl: etablissementCtrl,
        userCtrl: userCtrl,
        onRefresh: _refreshAll,
      ),
      PatientsTab(
        patientCtrl: patientCtrl,
        onRefresh: () => context.read<PatientController>().fetchPatients(),
      ),
      UsersTab(userCtrl: userCtrl),
      const ModulesTab(),
      const ProfileTab(),
    ];

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
        Expanded(child: pages[_tabIndex]),
      ],
    );

    if (isDesktop || isTablet) {
      return Scaffold(
        appBar: AppBar(title: Text(tabTitles[_tabIndex])),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tabIndex,
              onDestinationSelected: (value) =>
                  setState(() => _tabIndex = value),
              labelType: isDesktop
                  ? NavigationRailLabelType.all
                  : NavigationRailLabelType.selected,
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text(tabTitles[0]),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text(tabTitles[1]),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_add_alt_outlined),
                  selectedIcon: Icon(Icons.person_add_alt_1),
                  label: Text(tabTitles[2]),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.widgets_outlined),
                  selectedIcon: Icon(Icons.widgets),
                  label: Text(tabTitles[3]),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_circle_outlined),
                  selectedIcon: Icon(Icons.account_circle),
                  label: Text(tabTitles[4]),
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
      appBar: AppBar(title: Text(tabTitles[_tabIndex])),
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (value) => setState(() => _tabIndex = value),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: bottomNavLabels[0],
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: bottomNavLabels[1],
          ),
          NavigationDestination(
            icon: Icon(Icons.person_add_alt_outlined),
            selectedIcon: Icon(Icons.person_add_alt_1),
            label: bottomNavLabels[2],
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets),
            label: bottomNavLabels[3],
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: bottomNavLabels[4],
          ),
        ],
      ),
    );
  }
}
