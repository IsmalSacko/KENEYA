import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/etablissement_controller.dart';
import '../controllers/medicament_controller.dart';
import '../controllers/patient_controller.dart';
import '../controllers/user_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<PatientController>().fetchPatients();
      if (!mounted) return;
      await context.read<MedicamentController>().fetchMedicaments();
      if (!mounted) return;
      await context.read<EtablissementController>().fetchEtablissements();
      if (!mounted) return;
      await context.read<UserController>().fetchUsers();
    });
  }

  Future<void> _refresh() async {
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
    final auth = context.watch<AuthController>();
    final patientCtrl = context.watch<PatientController>();
    final medicamentCtrl = context.watch<MedicamentController>();
    final etablissementCtrl = context.watch<EtablissementController>();
    final userCtrl = context.watch<UserController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keneya+'),
        actions: [
          IconButton(
            onPressed: auth.loading ? null : () => auth.logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Deconnexion',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Bienvenue ${auth.currentUser?.name ?? ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _SectionCard(
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
            const SizedBox(height: 16),
            _SectionCard(
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
                          ? const Icon(Icons.warning_amber, color: Colors.orange)
                          : null,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
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
                      subtitle: Text('${e.type} | ${e.telephone ?? '-'}'),
                      trailing: Icon(
                        e.actif ? Icons.check_circle : Icons.cancel,
                        color: e.actif ? Colors.green : Colors.red,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
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
          ],
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
