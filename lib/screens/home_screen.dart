import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/offline/sync_manager.dart';
import '../controllers/auth_controller.dart';
import '../controllers/etablissement_controller.dart';
import '../controllers/medicament_controller.dart';
import '../controllers/patient_controller.dart';
import '../controllers/user_controller.dart';
import 'modules/consultations_screen.dart';
import 'modules/etablissements_screen.dart';
import 'modules/journal_audits_screen.dart';
import 'modules/medicaments_screen.dart';
import 'modules/mouvements_stock_screen.dart';
import 'modules/paiements_screen.dart';
import 'modules/vente_articles_screen.dart';
import 'modules/ventes_pharmacie_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  int _tabIndex = 0;

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
      setState(() {
        _isOffline = results.every((r) => r == ConnectivityResult.none);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshAll();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;
    final auth = context.watch<AuthController>();
    final patientCtrl = context.watch<PatientController>();
    final medicamentCtrl = context.watch<MedicamentController>();
    final etablissementCtrl = context.watch<EtablissementController>();
    final userCtrl = context.watch<UserController>();

    final tabTitles = [
      'Accueil',
      'Patients',
      'Utilisateurs',
      'Ressources',
      'Profil',
    ];

    final pages = [
      _DashboardTab(
        auth: auth,
        patientCtrl: patientCtrl,
        medicamentCtrl: medicamentCtrl,
        etablissementCtrl: etablissementCtrl,
        userCtrl: userCtrl,
        onRefresh: _refreshAll,
      ),
      _PatientsTab(
        patientCtrl: patientCtrl,
        onRefresh: () => context.read<PatientController>().fetchPatients(),
      ),
      _UsersTab(userCtrl: userCtrl),
      const _ModulesTab(),
      _ProfileTab(auth: auth),
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
              child: Text(
                '$pending operation(s) en attente de synchronisation.',
              ),
            );
          },
        ),
        Expanded(child: pages[_tabIndex]),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        appBar: AppBar(title: Text(tabTitles[_tabIndex])),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _tabIndex,
              onDestinationSelected: (value) =>
                  setState(() => _tabIndex = value),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Accueil'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Patients'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_add_alt_outlined),
                  selectedIcon: Icon(Icons.person_add_alt_1),
                  label: Text('Utilisateurs'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.widgets_outlined),
                  selectedIcon: Icon(Icons.widgets),
                  label: Text('Ressources'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_circle_outlined),
                  selectedIcon: Icon(Icons.account_circle),
                  label: Text('Profil'),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_add_alt_outlined),
            selectedIcon: Icon(Icons.person_add_alt_1),
            label: 'Utilisateurs',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets),
            label: 'Ressources',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.auth,
    required this.patientCtrl,
    required this.medicamentCtrl,
    required this.etablissementCtrl,
    required this.userCtrl,
    required this.onRefresh,
  });

  final AuthController auth;
  final PatientController patientCtrl;
  final MedicamentController medicamentCtrl;
  final EtablissementController etablissementCtrl;
  final UserController userCtrl;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final cardWidth = wide
              ? (constraints.maxWidth - 48) / 2
              : constraints.maxWidth;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Bienvenue ${auth.currentUser?.name ?? ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _SectionCard(
                      title: 'Patients',
                      loading: patientCtrl.loading,
                      error: patientCtrl.error,
                      emptyMessage: 'Aucun patient.',
                      children: patientCtrl.patients
                          .take(5)
                          .map(
                            (p) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.nom),
                              subtitle: Text(p.telephone ?? '-'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SectionCard(
                      title: 'Medicaments',
                      loading: medicamentCtrl.loading,
                      error: medicamentCtrl.error,
                      emptyMessage: 'Aucun medicament.',
                      children: medicamentCtrl.medicaments
                          .take(5)
                          .map(
                            (m) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(m.nom),
                              subtitle: Text(
                                'Stock: ${m.stock} | Prix: ${m.prixUnitaire}',
                              ),
                              trailing: m.stock <= m.seuilAlerte
                                  ? const Icon(
                                      Icons.warning_amber,
                                      color: Colors.orange,
                                    )
                                  : null,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SectionCard(
                      title: 'Etablissements',
                      loading: etablissementCtrl.loading,
                      error: etablissementCtrl.error,
                      emptyMessage: 'Aucun etablissement.',
                      children: etablissementCtrl.etablissements
                          .take(5)
                          .map(
                            (e) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(e.nom),
                              subtitle: Text(
                                '${e.type} | ${e.telephone ?? '-'}',
                              ),
                              trailing: Icon(
                                e.actif ? Icons.check_circle : Icons.cancel,
                                color: e.actif ? Colors.green : Colors.red,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _SectionCard(
                      title: 'Utilisateurs',
                      loading: userCtrl.loading,
                      error: userCtrl.error,
                      emptyMessage: 'Aucun utilisateur.',
                      children: userCtrl.users
                          .take(5)
                          .map(
                            (u) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(u.name),
                              subtitle: Text('${u.role} | ${u.telephone}'),
                              trailing: Icon(
                                u.actif ? Icons.check_circle : Icons.cancel,
                                color: u.actif ? Colors.green : Colors.red,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PatientsTab extends StatelessWidget {
  const _PatientsTab({required this.patientCtrl, required this.onRefresh});

  final PatientController patientCtrl;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: patientCtrl.patients.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            if (patientCtrl.loading) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (patientCtrl.error != null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(patientCtrl.error!),
              );
            }
            if (patientCtrl.patients.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Aucun patient disponible.'),
              );
            }
            return const SizedBox.shrink();
          }

          final p = patientCtrl.patients[index - 1];
          return Card(
            child: ListTile(
              title: Text(p.nom),
              subtitle: Text('${p.telephone ?? '-'}\n${p.adresse ?? '-'}'),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab({required this.userCtrl});

  final UserController userCtrl;

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String _role = 'admin';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await widget.userCtrl.createUser(
      name: _nameCtrl.text.trim(),
      telephone: _phoneCtrl.text.trim(),
      role: _role,
      pin: _pinCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _pinCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Utilisateur ajoute.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.userCtrl.error ?? 'Echec creation utilisateur.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;

    final formCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Champ obligatoire'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telephone'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 8 || t.length > 20) {
                    return 'Telephone invalide (8 a 20 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'medecin', child: Text('Medecin')),
                  DropdownMenuItem(
                    value: 'pharmacien',
                    child: Text('Pharmacien'),
                  ),
                  DropdownMenuItem(value: 'caissier', child: Text('Caissier')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _role = v);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'PIN'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 4 || t.length > 6) {
                    return 'PIN invalide (4 a 6 caracteres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.userCtrl.loading ? null : _submit,
                  child: const Text('Ajouter utilisateur'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final listCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: widget.userCtrl.loading && widget.userCtrl.users.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : widget.userCtrl.users.isEmpty
            ? const Text('Aucun utilisateur.')
            : Column(
                children: widget.userCtrl.users
                    .map(
                      (u) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(u.name),
                        subtitle: Text('${u.role} | ${u.telephone}'),
                      ),
                    )
                    .toList(),
              ),
      ),
    );

    if (!isDesktop) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [formCard, const SizedBox(height: 12), listCard],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            children: [formCard],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            children: [listCard],
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nom: ${auth.currentUser?.name ?? '-'}'),
                const SizedBox(height: 6),
                Text('Telephone: ${auth.currentUser?.telephone ?? '-'}'),
                const SizedBox(height: 6),
                Text('Role: ${auth.currentUser?.role ?? '-'}'),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: auth.loading ? null : () => auth.logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Se deconnecter'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModulesTab extends StatelessWidget {
  const _ModulesTab();

  @override
  Widget build(BuildContext context) {
    final modules = <_ModuleItem>[
      const _ModuleItem(
        title: 'Consultations',
        subtitle: 'Suivi des consultations medicales',
        icon: Icons.medical_information_outlined,
        builder: ConsultationsScreen.new,
      ),
      const _ModuleItem(
        title: 'Medicaments',
        subtitle: 'Catalogue et suivi des stocks',
        icon: Icons.medication_outlined,
        builder: MedicamentsScreen.new,
      ),
      const _ModuleItem(
        title: 'Mouvements Stock',
        subtitle: 'Entrees, sorties et ajustements',
        icon: Icons.inventory_2_outlined,
        builder: MouvementsStockScreen.new,
      ),
      const _ModuleItem(
        title: 'Paiements',
        subtitle: 'Reglement consultations et ventes',
        icon: Icons.payments_outlined,
        builder: PaiementsScreen.new,
      ),
      const _ModuleItem(
        title: 'Ventes Pharmacie',
        subtitle: 'Operations de vente pharmacie',
        icon: Icons.point_of_sale_outlined,
        builder: VentesPharmacieScreen.new,
      ),
      const _ModuleItem(
        title: 'Articles Vente',
        subtitle: 'Lignes detaillees de vente',
        icon: Icons.receipt_long_outlined,
        builder: VenteArticlesScreen.new,
      ),
      const _ModuleItem(
        title: 'Journal Audits',
        subtitle: 'Historique des actions',
        icon: Icons.history_outlined,
        builder: JournalAuditsScreen.new,
      ),
      const _ModuleItem(
        title: 'Etablissements',
        subtitle: 'Gestion des structures',
        icon: Icons.local_hospital_outlined,
        builder: EtablissementsScreen.new,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1200
            ? 4
            : width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: width >= 900 ? 1.55 : 1.30,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final module = modules[index];
            return _ModuleCard(
              title: module.title,
              subtitle: module.subtitle,
              icon: module.icon,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => module.builder()),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ModuleItem {
  const _ModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function({Key? key}) builder;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, const Color(0xFFF4F7FF)],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Ouvrir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final bool loading;
  final String? error;
  final String emptyMessage;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.loading,
    required this.error,
    required this.emptyMessage,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (loading) {
      child = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(error!),
      );
    } else if (children.isEmpty) {
      child = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(emptyMessage),
      );
    } else {
      child = Column(children: children);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
