part of 'api_module_screen.dart';


extension _ApiModuleScreenView on _ApiModuleScreenState {
  Widget _buildDesktopTable() {
    final columns = _collectColumns();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Card(
          margin: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            key: const ValueKey('desktop-table'),
            padding: const EdgeInsets.all(12),
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 28,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 66,
              columns: [
                for (final c in columns) DataColumn(label: Text(_displayLabelForKey(c))),
                const DataColumn(label: Text('Actions')),
              ],
              rows: _items.map((item) {
                return DataRow(
                  cells: [
                    for (final c in columns) DataCell(Text(_cellValueForColumn(c, item[c], item))),
                    DataCell(
                      PopupMenuButton<String>(
                        tooltip: 'Actions',
                        onSelected: (value) {
                          if (value == 'update') _update(item);
                          if (value == 'delete') _delete(item);
                        },
                        itemBuilder: (context) => [
                          if (widget.allowUpdate)
                            const PopupMenuItem<String>(
                              value: 'update',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Modifier'),
                                ],
                              ),
                            ),
                          if (widget.allowDelete)
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18),
                                  SizedBox(width: 8),
                                  Text('Supprimer'),
                                ],
                              ),
                            ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.more_horiz, size: 18),
                              SizedBox(width: 6),
                              Text('Actions'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    final columns = _collectColumns();
    return ListView.builder(
      key: const ValueKey('mobile-list'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isVentePharmacie = widget.endpoint == '/ventes-pharmacie';
        final card = isVentePharmacie
            ? _buildVentePharmacieCard(item)
            : _buildGenericCard(context, item, columns);
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 180 + (index * 20)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 8),
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: card,
          ),
        );
      },
    );
  }

  /// Carte générique moderne pour un enregistrement (tous modules sauf ventes).
  Widget _buildGenericCard(
    BuildContext context,
    Map<String, dynamic> item,
    List<String> columns,
  ) {
    final scheme = Theme.of(context).colorScheme;
    const titleCandidates = [
      'nom',
      'name',
      'libelle',
      'titre',
      'motif',
      'action',
      'reference',
    ];
    String? titleKey;
    for (final k in titleCandidates) {
      if (columns.contains(k) &&
          (item[k]?.toString().trim().isNotEmpty ?? false)) {
        titleKey = k;
        break;
      }
    }
    final title = titleKey != null
        ? _cellValueForColumn(titleKey, item[titleKey], item)
        : (item['id'] != null ? '#${item['id']}' : '—');
    final statusKeys = columns
        .where((c) => c == 'actif' || c == 'statut' || c == 'statut_sync')
        .toList();
    final subtitleKeys = columns
        .where((c) => c != 'id' && c != titleKey && !statusKeys.contains(c))
        .take(3)
        .toList();
    final icon = _iconForItem(item);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2ECE7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0E9F6E),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF0B3D2E),
                      ),
                    ),
                    for (final c in subtitleKeys)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${_displayLabelForKey(c)}: ${_cellValueForColumn(c, item[c], item)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF4B6358),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.allowUpdate || widget.allowDelete) _actionsMenu(item),
            ],
          ),
          if (statusKeys.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in statusKeys) _statusChip(c, item[c], item),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionsMenu(Map<String, dynamic> item) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, color: Color(0xFF4B6358)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'itineraire') _openItinerary(item);
        if (value == 'update') _update(item);
        if (value == 'delete') _delete(item);
      },
      itemBuilder: (context) => [
        if (_canRouteTo(item))
          const PopupMenuItem<String>(
            value: 'itineraire',
            child: Row(
              children: [
                Icon(Icons.directions_rounded, size: 18, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text('Itinéraire', style: TextStyle(color: Color(0xFF2563EB))),
              ],
            ),
          ),
        if (widget.allowUpdate)
          const PopupMenuItem<String>(
            value: 'update',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 10),
                Text('Modifier'),
              ],
            ),
          ),
        if (widget.allowDelete)
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                SizedBox(width: 10),
                Text('Supprimer', style: TextStyle(color: Color(0xFFDC2626))),
              ],
            ),
          ),
      ],
    );
  }

  /// Vrai pour un établissement géolocalisé (affiche l'action « Itinéraire »).
  bool _canRouteTo(Map<String, dynamic> item) {
    if (widget.endpoint != '/etablissements') return false;
    final lat = double.tryParse(item['latitude']?.toString() ?? '');
    final lng = double.tryParse(item['longitude']?.toString() ?? '');
    return lat != null && lng != null;
  }

  /// Ouvre Google Maps en itinéraire vers l'établissement.
  Future<void> _openItinerary(Map<String, dynamic> item) async {
    final lat = double.tryParse(item['latitude']?.toString() ?? '');
    final lng = double.tryParse(item['longitude']?.toString() ?? '');
    if (lat == null || lng == null) return;

    final ok = await GeolocationService.openItinerary(lat, lng);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la carte.')),
      );
    }
  }

  /// Icône adaptée au module (et au type pour les établissements).
  IconData _iconForItem(Map<String, dynamic> item) {
    if (widget.endpoint == '/etablissements') {
      final type = item['type']?.toString();
      if (type == 'pharmacie') return Icons.local_pharmacy_rounded;
      if (type == 'cabinet') return Icons.medical_services_rounded;
      return Icons.local_hospital_rounded;
    }
    switch (widget.endpoint) {
      case '/patients':
        return Icons.person_rounded;
      case '/medicaments':
        return Icons.medication_rounded;
      case '/consultations':
        return Icons.medical_services_rounded;
      case '/paiements':
        return Icons.payments_rounded;
      case '/mouvement-stocks':
        return Icons.swap_vert_rounded;
      case '/journal-audits':
        return Icons.history_rounded;
      case '/vente-pharmacie-articles':
        return Icons.inventory_2_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  Widget _statusChip(String key, dynamic raw, Map<String, dynamic> item) {
    final label = _cellValueForColumn(key, raw, item);
    bool positive;
    if (key == 'actif') {
      positive = raw == true || raw == 1 || raw == '1' || raw == 'true';
    } else if (key == 'statut_sync') {
      positive = raw != 'en_attente';
    } else if (key == 'statut') {
      positive = raw == 'payee';
    } else {
      positive = true;
    }
    final color =
        positive ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVentePharmacieCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '-';
    final modeRaw = item['mode_paiement']?.toString();
    final modeLabel =
        const {
          'espece': 'Especes',
          'orange': 'Orange Money',
          'wave': 'Wave',
          'moov': 'Moov Money',
        }[modeRaw] ??
        '-';
    final statutRaw = item['statut_sync']?.toString();
    final statutLabel = statutRaw == 'en_attente' ? 'En attente' : 'Synchronise';
    final montant = (item['montant_total'] is num)
        ? (item['montant_total'] as num).toDouble()
        : double.tryParse('${item['montant_total']}');
    final montantLabel =
        montant == null ? '-' : '${NumberFormat.decimalPattern('fr_FR').format(montant)} FCFA';
    final patientLabel = _extractPatientLabel(item);
    final articlesCount = item['articles'] is List ? (item['articles'] as List).length : 0;

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
                    'Vente #$id',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  montantLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Client: $patientLabel'),
            const SizedBox(height: 4),
            Text('Mode paiement: $modeLabel'),
            const SizedBox(height: 4),
            Text('Articles: $articlesCount'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (statutRaw == 'en_attente' ? Colors.orange : Colors.green)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Statut: $statutLabel',
                style: TextStyle(
                  color: statutRaw == 'en_attente' ? Colors.orange.shade900 : Colors.green.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showVenteDetails(item),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Voir details'),
                ),
                if (widget.allowUpdate)
                  OutlinedButton(
                    onPressed: () => _update(item),
                    child: const Text('Modifier'),
                  ),
                if (widget.allowDelete)
                  OutlinedButton(
                    onPressed: () => _delete(item),
                    child: const Text('Supprimer'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVenteDetails(Map<String, dynamic> item) {
    final articles = item['articles'] is List
        ? (item['articles'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final screen = MediaQuery.sizeOf(context);
    final isLarge = screen.width >= 700;
    final limited = articles.take(4).toList();

    final detailsBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vente #${item['id']}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text('Client: ${_extractPatientLabel(item)}'),
        Text(
          'Mode paiement: ${_cellValueForColumn('mode_paiement', item['mode_paiement'])}',
        ),
        const SizedBox(height: 10),
        const Text('Articles', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (articles.isEmpty)
          const Text('Aucun article')
        else ...[
          for (final a in limited)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '- ${_extractArticleName(a)} x ${a['quantite'] ?? '-'} (${_cellValue(a['prix_total'])})',
              ),
            ),
          if (articles.length > limited.length)
            TextButton(
              onPressed: () => _showAllArticles(articles),
              child: Text('Voir tout (${articles.length})'),
            ),
        ],
      ],
    );

    if (isLarge) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Details vente'),
          content: SizedBox(
            width: 640,
            height: screen.height * 0.70,
            child: SingleChildScrollView(child: detailsBody),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      return;
    }

    final estimatedRows = 5 + limited.length + (articles.length > limited.length ? 1 : 0);
    final dynamicHeightFactor = (0.28 + (estimatedRows * 0.05)).clamp(0.45, 0.82);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          alignment: Alignment.bottomCenter,
          heightFactor: dynamicHeightFactor,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.viewPaddingOf(context).bottom + 12),
            child: SingleChildScrollView(child: detailsBody),
          ),
        ),
      ),
    );
  }

  void _showAllArticles(List<Map<String, dynamic>> articles) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final screen = MediaQuery.sizeOf(context);
        return AlertDialog(
          title: const Text('Tous les articles'),
          content: SizedBox(
            width: 520,
            height: screen.height * 0.65,
            child: ListView.builder(
              itemCount: articles.length,
              itemBuilder: (context, index) {
                final a = articles[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(_extractArticleName(a)),
                  subtitle: Text('Quantite: ${a['quantite'] ?? '-'}'),
                  trailing: Text(_cellValue(a['prix_total'])),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }
}
