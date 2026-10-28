import 'package:flutter/material.dart';

import '../../ma_sante/maps_launcher.dart';
import '../../ma_sante/etablissement_public.dart';
import '../../common/utils/kcolors.dart';
import 'booking_screen.dart';
import 'prendre_ticket_sheet.dart';
import 'rdv_patient_screens.dart';
import '../../compte/compte_api.dart';
import '../../compte/compte_controller.dart';
import 'package:provider/provider.dart';

class EtablissementDetailScreen extends StatelessWidget {
  const EtablissementDetailScreen({super.key, required this.etablissement});

  final Etablissement etablissement;

  IconData get _icon => switch (etablissement.type) {
    'pharmacie' => Icons.local_pharmacy_rounded,
    'cabinet' => Icons.medical_services_rounded,
    _ => Icons.local_hospital_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = etablissement;

    return Scaffold(
      appBar: AppBar(title: Text(e.nom, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                height: 64,
                width: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_icon, color: scheme.primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.nom,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.typeLabel,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (e.distanceKm != null)
                Text(
                  e.distanceKm! < 1
                      ? '${(e.distanceKm! * 1000).round()} m'
                      : '${e.distanceKm!.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (e.adresse?.isNotEmpty == true)
            _InfoRow(icon: Icons.place_rounded, label: e.adresse!),
          if (e.telephone?.isNotEmpty == true)
            _InfoRow(
              icon: Icons.call_rounded,
              label: e.telephone!,
              onTap: () => MapsLauncher.call(e.telephone!),
            ),
          const SizedBox(height: 24),
          if (e.hasCoordinates)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () =>
                  MapsLauncher.openItinerary(e.latitude!, e.longitude!),
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Itinéraire (Google Maps)'),
            ),
          if (e.aFile) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Kolors.kJaune,
                foregroundColor: Kolors.kPrimaryDark,
              ),
              onPressed: () => prendreTicket(context, e),
              icon: const Icon(Icons.confirmation_number_rounded),
              label: const Text('Prendre un ticket'),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _prendreRdv(context, e),
            icon: const Icon(Icons.event_available_rounded),
            label: const Text('Prendre rendez-vous'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14.5)),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

/// Créneaux en ligne si l'établissement a des agendas ; sinon une demande
/// à une date souhaitée, que l'établissement confirmera.
Future<void> _prendreRdv(BuildContext context, Etablissement e) async {
  List<Map<String, dynamic>> agendas = [];
  if (context.read<CompteController>().connecte) {
    try {
      agendas = await CompteApi().agendas(e.uuid);
    } catch (_) {}
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => agendas.isEmpty
          ? BookingScreen(etablissement: e)
          : PrendreRdvScreen(etablissement: e, agendas: agendas),
    ),
  );
}
