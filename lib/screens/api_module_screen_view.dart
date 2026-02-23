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
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final isVentePharmacie = widget.endpoint == '/ventes-pharmacie';
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 180 + (index * 20)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) => Opacity(opacity: value, child: child),
          child: isVentePharmacie
              ? _buildVentePharmacieCard(item)
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in columns.take(6))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${_displayLabelForKey(c)}: ${_cellValueForColumn(c, item[c], item)}',
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (widget.allowUpdate)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _update(item),
                                  child: const Text('Modifier'),
                                ),
                              ),
                            if (widget.allowUpdate && widget.allowDelete) const SizedBox(width: 8),
                            if (widget.allowDelete)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _delete(item),
                                  child: const Text('Supprimer'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
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
