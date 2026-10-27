import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../ma_sante/booking.dart';
import '../../ma_sante/local_bookings.dart';
import '../../common/utils/kcolors.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => MyRequestsScreenState();
}

class MyRequestsScreenState extends State<MyRequestsScreen> {
  List<Booking> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Rechargé aussi quand l'onglet devient visible (voir RootScreen).
  Future<void> reload() async {
    setState(() => _loading = true);
    final items = await LocalBookings.all();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes demandes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? _empty()
          : RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _localNotice(),
                  const SizedBox(height: 12),
                  for (final b in _items) ...[
                    _BookingCard(booking: b),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _empty() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.event_note_rounded, size: 52, color: Colors.black26),
        SizedBox(height: 12),
        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Aucune demande pour le moment.\nTrouvez un établissement et prenez rendez-vous.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _localNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Kolors.kSecondaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Kolors.kPrimary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Suivi enregistré sur cet appareil. La synchronisation en ligne arrivera avec les comptes patients.',
              style: TextStyle(fontSize: 12, color: Kolors.kTextHigh),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(booking.dateSouhaitee);
    final dateLabel = date != null
        ? DateFormat('EEEE d MMMM yyyy · HH:mm', 'fr').format(date)
        : booking.dateSouhaitee;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.etablissementNom,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _StatutChip(),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.event_rounded,
                  size: 16,
                  color: Colors.black45,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(dateLabel, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (booking.motif?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes_rounded,
                    size: 16,
                    color: Colors.black45,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking.motif!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatutChip extends StatelessWidget {
  const _StatutChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Kolors.kJauneDoux,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'En attente',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Kolors.kGold,
        ),
      ),
    );
  }
}
