import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../ma_sante/public_api.dart';
import '../../ma_sante/etablissement_public.dart';
import '../../services/geolocation_service.dart';
import 'etablissement_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final PublicApi _api = PublicApi();
  final TextEditingController _searchCtrl = TextEditingController();

  Position? _pos;
  List<Etablissement> _items = [];
  bool _loading = true;
  String? _error;
  String? _typeFilter; // profil ; null = tous
  bool _mapView = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      _pos = await GeolocationService.currentPosition();
    } catch (_) {
      _pos = null;
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.search(
        lat: _pos?.latitude,
        lng: _pos?.longitude,
        profil: _typeFilter,
        query: _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Impossible de charger les établissements. Vérifiez votre connexion.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services de santé'),
        actions: [
          IconButton(
            tooltip: _mapView ? 'Vue liste' : 'Vue carte',
            onPressed: () => setState(() => _mapView = !_mapView),
            icon: Icon(_mapView ? Icons.view_list_rounded : Icons.map_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          _filters(),
          const SizedBox(height: 4),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _load(),
        decoration: InputDecoration(
          hintText: 'Rechercher un cabinet, une pharmacie…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _load,
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    Widget chip(String label, String? value) {
      final selected = _typeFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            setState(() => _typeFilter = value);
            _load();
          },
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('Tous', null),
          chip('Centres de santé', 'centre_sante'),
          chip('Cabinets', 'cabinet_medical'),
          chip('Pharmacies', 'pharmacie'),
          chip('Cliniques', 'clinique'),
          chip('Laboratoires', 'laboratoire'),
          chip('Maternités', 'maternite'),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _message(Icons.wifi_off_rounded, _error!);
    }
    if (_items.isEmpty) {
      return _message(
        Icons.location_off_rounded,
        'Aucun établissement trouvé.',
      );
    }
    return _mapView ? _map() : _list();
  }

  Widget _message(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _EtablissementCard(
          etablissement: _items[i],
          onTap: () => _openDetail(_items[i]),
        ),
      ),
    );
  }

  Widget _map() {
    final withCoords = _items.where((e) => e.hasCoordinates).toList();
    final LatLng center = _pos != null
        ? LatLng(_pos!.latitude, _pos!.longitude)
        : (withCoords.isNotEmpty
              ? LatLng(withCoords.first.latitude!, withCoords.first.longitude!)
              : const LatLng(12.6392, -8.0029)); // Bamako par défaut

    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 12),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.ismaeldev.keneya',
        ),
        MarkerLayer(
          markers: [
            if (_pos != null)
              Marker(
                point: LatLng(_pos!.latitude, _pos!.longitude),
                width: 22,
                height: 22,
                child: const _UserDot(),
              ),
            for (final e in withCoords)
              Marker(
                point: LatLng(e.latitude!, e.longitude!),
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: () => _openDetail(e),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _openDetail(Etablissement e) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EtablissementDetailScreen(etablissement: e),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
    );
  }
}

class _EtablissementCard extends StatelessWidget {
  const _EtablissementCard({required this.etablissement, required this.onTap});
  final Etablissement etablissement;
  final VoidCallback onTap;

  IconData get _icon => switch (etablissement.type) {
    'pharmacie' => Icons.local_pharmacy_rounded,
    'cabinet' => Icons.medical_services_rounded,
    _ => Icons.local_hospital_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etablissement.nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      etablissement.adresse?.isNotEmpty == true
                          ? '${etablissement.typeLabel} · ${etablissement.adresse}'
                          : etablissement.typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (etablissement.distanceKm != null) ...[
                const SizedBox(width: 8),
                _DistanceChip(km: etablissement.distanceKm!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  const _DistanceChip({required this.km});
  final double km;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = km < 1
        ? '${(km * 1000).round()} m'
        : '${km.toStringAsFixed(1)} km';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me_rounded, size: 13, color: scheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
