import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../ma_sante/public_api.dart';
import '../../core/offline/uuid.dart';
import '../../ma_sante/booking.dart';
import '../../ma_sante/etablissement_public.dart';
import '../../ma_sante/local_bookings.dart';
import '../../compte/compte_controller.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.etablissement});

  final Etablissement etablissement;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();
  final PublicApi _api = PublicApi();

  DateTime? _date;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // La personne connectée prend rendez-vous pour elle par défaut.
    final personne = context.read<CompteController>().personne;
    if (personne != null) {
      _nomCtrl.text = personne.nom;
      _telCtrl.text = personne.telephone;
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (day == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _date = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      _snack('Choisissez une date et une heure.');
      return;
    }
    if (_date!.isBefore(DateTime.now())) {
      _snack('La date doit être dans le futur.');
      return;
    }

    setState(() => _submitting = true);
    final uuid = uuidV4();
    try {
      await _api.book(
        uuid: uuid,
        etablissementUuid: widget.etablissement.uuid,
        patientNom: _nomCtrl.text.trim(),
        patientTelephone: _telCtrl.text.trim(),
        dateSouhaitee: _date!,
        motif: _motifCtrl.text.trim(),
      );

      await LocalBookings.add(
        Booking(
          uuid: uuid,
          etablissementNom: widget.etablissement.nom,
          patientNom: _nomCtrl.text.trim(),
          dateSouhaitee: _date!.toIso8601String(),
          statut: 'demande',
          creeLe: DateTime.now().toIso8601String(),
          motif: _motifCtrl.text.trim(),
        ),
      );

      if (!mounted) return;
      await _showSuccess();
    } on DioException catch (e) {
      _snack(_apiMessage(e) ?? 'Échec de l’envoi. Réessayez.');
    } catch (_) {
      _snack('Échec de l’envoi. Réessayez.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccess() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 44,
        ),
        title: const Text('Demande envoyée'),
        content: const Text(
          'Votre demande de rendez-vous a été transmise à l’établissement. '
          'Vous la retrouverez dans « Mes rendez-vous ». L’établissement la confirmera.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // ferme le dialog
              Navigator.of(context).pop(); // revient au détail
            },
            child: const Text('Terminé'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _apiMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date == null
        ? 'Choisir une date et une heure'
        : DateFormat('EEEE d MMMM yyyy · HH:mm', 'fr').format(_date!);

    return Scaffold(
      appBar: AppBar(title: const Text('Prendre rendez-vous')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.etablissement.nom,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nomCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Prénom et nom'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Téléphone requis' : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date souhaitée',
                  prefixIcon: Icon(Icons.event_rounded),
                ),
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    color: _date == null ? Colors.black54 : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _motifCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motif (facultatif)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Envoi…' : 'Envoyer la demande'),
            ),
          ],
        ),
      ),
    );
  }
}
