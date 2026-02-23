import 'dart:async';
import 'package:flutter/material.dart';
import 'package:keneya_plus/controllers/patient_controller.dart';

class PatientsTab extends StatefulWidget {
  const PatientsTab({
    super.key,
    required this.patientCtrl,
    required this.onRefresh,
  });

  final PatientController patientCtrl;
  final Future<void> Function() onRefresh;

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _adresseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitPatient() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await widget.patientCtrl.createPatient(
      nom: _nomCtrl.text.trim(),
      telephone: _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
      adresse: _adresseCtrl.text.trim().isEmpty
          ? null
          : _adresseCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      _nomCtrl.clear();
      _telCtrl.clear();
      _adresseCtrl.clear();
      final text = widget.patientCtrl.lastActionQueued
          ? 'Hors connexion: patient en attente de synchronisation.'
          : 'Patient ajoute.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.patientCtrl.error ?? 'Echec creation patient.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientCtrl = widget.patientCtrl;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1000;

    final formCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom du patient'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Champ obligatoire'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telephone (optionnel)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _adresseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Adresse (optionnel)',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: patientCtrl.loading ? null : _submitPatient,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Ajouter patient'),
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
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: patientCtrl.patients.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                if (patientCtrl.loading && patientCtrl.patients.isEmpty) {
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
              return ListTile(
                title: Text(p.nom),
                subtitle: Text('${p.telephone ?? '-'}\n${p.adresse ?? '-'}'),
                isThreeLine: true,
              );
            },
          ),
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
