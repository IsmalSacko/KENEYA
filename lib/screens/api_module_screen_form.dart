// ignore_for_file: use_build_context_synchronously

part of 'api_module_screen.dart';

extension _ApiModuleScreenForm on _ApiModuleScreenState {
  Future<Map<String, dynamic>?> _showFormDialog({
    required String title,
    required List<ModuleField> fields,
    Map<String, dynamic>? initial,
  }) async {
    final relationOptions = <String, List<_RelationOption>>{};
    for (final f in fields.where((e) => e.type == ModuleFieldType.relation)) {
      relationOptions[f.key] = await _fetchRelationOptions(f);
    }

    final formKey = GlobalKey<FormState>();
    final textControllers = <String, TextEditingController>{};
    final values = <String, dynamic>{};

    for (final f in fields) {
      final initialValue = initial?[f.key];
      if (f.type == ModuleFieldType.select ||
          f.type == ModuleFieldType.boolean ||
          f.type == ModuleFieldType.relation) {
        if (initialValue != null) {
          values[f.key] = initialValue;
        } else if (f.type == ModuleFieldType.select && f.options.length == 1) {
          values[f.key] = f.options.first;
        } else if (f.type == ModuleFieldType.relation) {
          final options = relationOptions[f.key] ?? const <_RelationOption>[];
          if (options.length == 1) {
            values[f.key] = options.first.id;
          } else if (!f.required) {
            values[f.key] = -1;
          } else {
            values[f.key] = null;
          }
        } else {
          values[f.key] = null;
        }
      } else {
        textControllers[f.key] = TextEditingController(
          text: initialValue == null ? '' : initialValue.toString(),
        );
      }
    }

    if (!context.mounted) return null;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 680,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.endpoint == '/etablissements') ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          label: const Text('Utiliser ma position'),
                          onPressed: () async {
                            final pos =
                                await GeolocationService.currentPosition();
                            if (pos == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Position indisponible (permission refusée ou GPS désactivé).',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                            textControllers['latitude']?.text = pos.latitude
                                .toStringAsFixed(7);
                            textControllers['longitude']?.text = pos.longitude
                                .toStringAsFixed(7);
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    for (final f in fields) ...[
                      if (_isVisible(f, values))
                        _buildField(
                          field: f,
                          textControllers: textControllers,
                          values: values,
                          relationOptions: relationOptions,
                          setModalState: setModalState,
                          refreshRelationOptions: (field) async {
                            final refreshed = await _fetchRelationOptions(field);
                            setModalState(() => relationOptions[field.key] = refreshed);
                          },
                        ),
                      if (_isVisible(f, values)) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final payload = <String, dynamic>{};
                for (final f in fields) {
                  if (!_isVisible(f, values)) continue;
                  switch (f.type) {
                    case ModuleFieldType.text:
                    case ModuleFieldType.date:
                      final v = textControllers[f.key]!.text.trim();
                      if (v.isNotEmpty) {
                        payload[f.key] = v;
                      }
                    case ModuleFieldType.number:
                      final v = textControllers[f.key]!.text.trim();
                      if (v.isNotEmpty) {
                        payload[f.key] = int.tryParse(v) ?? v;
                      }
                    case ModuleFieldType.decimal:
                      final v = textControllers[f.key]!.text.trim();
                      if (v.isNotEmpty) {
                        payload[f.key] = double.tryParse(v) ?? v;
                      }
                    case ModuleFieldType.select:
                    case ModuleFieldType.boolean:
                    case ModuleFieldType.relation:
                      final v = values[f.key];
                      if (v != null &&
                          v.toString().isNotEmpty &&
                          !(f.type == ModuleFieldType.relation && v == -1)) {
                        payload[f.key] = v;
                      }
                  }
                }
                Navigator.of(context).pop(payload);
              },
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isVisible(ModuleField field, Map<String, dynamic> values) {
    if (field.visibleWhenKey == null) return true;
    final current = values[field.visibleWhenKey];
    return current?.toString() == field.visibleWhenValue;
  }

  Future<List<_RelationOption>> _fetchRelationOptions(ModuleField field) async {
    final endpoint = field.relationEndpoint;
    if (endpoint == null || endpoint.isEmpty) return const <_RelationOption>[];
    try {
      final response = await ApiClient.dio.get(endpoint);
      final list = _parseList(response.data);
      final options = _buildRelationOptions(list, field);
      if (options.isNotEmpty) return options;
    } catch (_) {
      // fallback to cache
    }

    final cacheKeys = _relationCacheKeysForEndpoint(endpoint);
    for (final key in cacheKeys) {
      final cached = LocalStore.read<dynamic>(key);
      final list = _parseList(cached);
      final options = _buildRelationOptions(list, field);
      if (options.isNotEmpty) return options;
    }
    return const <_RelationOption>[];
  }

  List<String> _relationCacheKeysForEndpoint(String endpoint) {
    switch (endpoint) {
      case '/patients':
        return const ['cache_patients', 'cache_module_/patients'];
      case '/medicaments':
        return const ['cache_medicaments_all', 'cache_module_/medicaments'];
      case '/etablissements/users':
        return const ['cache_users', 'cache_module_/etablissements/users'];
      case '/consultations':
        return const ['cache_module_/consultations'];
      case '/ventes-pharmacie':
        return const ['cache_module_/ventes-pharmacie'];
      default:
        return ['cache_module_$endpoint'];
    }
  }

  List<_RelationOption> _buildRelationOptions(
    List<Map<String, dynamic>> raw,
    ModuleField field,
  ) {
    final filtered = raw.where((item) {
      if (field.relationFilterKey == null) return true;
      final current = item[field.relationFilterKey];
      return current?.toString() == field.relationFilterValue;
    });

    return filtered
        .map((item) {
          final id = int.tryParse('${item['id']}');
          if (id == null) return null;
          final label = _relationOptionLabel(field: field, item: item, id: id);
          final subtitle = _relationOptionSubtitle(field: field, item: item);
          return _RelationOption(id: id, label: label, subtitle: subtitle, raw: item);
        })
        .whereType<_RelationOption>()
        .toList();
  }

  String _relationOptionLabel({
    required ModuleField field,
    required Map<String, dynamic> item,
    required int id,
  }) {
    if (field.key == 'consultation_id' && field.relationEndpoint == '/consultations') {
      final motif = item['motif']?.toString().trim();
      if (motif != null && motif.isNotEmpty) {
        return 'Consultation #$id - $motif';
      }
      return 'Consultation #$id';
    }
    if (field.key == 'vente_pharmacie_id' &&
        field.relationEndpoint == '/ventes-pharmacie') {
      final patient = item['patient'];
      String? patientName;
      if (patient is Map) {
        patientName = patient['nom']?.toString().trim();
      }
      if (patientName != null && patientName.isNotEmpty) {
        return 'Vente #$id - $patientName';
      }
      return 'Vente #$id - Client de passage';
    }

    final labelKey = field.relationLabelKey ?? 'name';
    return (item[labelKey] ?? 'ID $id').toString();
  }

  String? _relationOptionSubtitle({
    required ModuleField field,
    required Map<String, dynamic> item,
  }) {
    if (field.key == 'consultation_id' && field.relationEndpoint == '/consultations') {
      final montant = item['montant']?.toString();
      return montant == null ? null : '$montant FCFA';
    }
    if (field.key == 'vente_pharmacie_id' &&
        field.relationEndpoint == '/ventes-pharmacie') {
      final montant = item['montant_total']?.toString();
      final mode = item['mode_paiement']?.toString();
      final modeLabel =
          const {
            'espece': 'Especes',
            'orange': 'Orange Money',
            'wave': 'Wave',
            'moov': 'Moov Money',
          }[mode] ??
          mode;
      if (montant != null && modeLabel != null) {
        return '$montant FCFA - $modeLabel';
      }
      if (montant != null) return '$montant FCFA';
      return modeLabel;
    }

    final subtitleKey = field.relationSubtitleKey;
    return subtitleKey == null ? null : item[subtitleKey]?.toString();
  }

  void _syncPaiementMontantFromSource({
    required String sourceFieldKey,
    required int? selectedId,
    required List<_RelationOption> options,
    required Map<String, TextEditingController> textControllers,
  }) {
    if (widget.endpoint != '/paiements') return;
    if (sourceFieldKey != 'consultation_id' && sourceFieldKey != 'vente_pharmacie_id') {
      return;
    }
    if (selectedId == null || selectedId == -1) return;

    final amountController = textControllers['montant'];
    if (amountController == null) return;

    final selected = options
        .where((o) => o.id == selectedId)
        .cast<_RelationOption?>()
        .firstWhere((o) => o != null, orElse: () => null);
    if (selected == null) return;

    final sourceAmount =
        sourceFieldKey == 'consultation_id' ? selected.raw['montant'] : selected.raw['montant_total'];
    if (sourceAmount == null) return;

    final amountText = sourceAmount.toString().trim();
    if (amountText.isEmpty) return;
    amountController.text = amountText;
  }

  Widget _buildField({
    required ModuleField field,
    required Map<String, TextEditingController> textControllers,
    required Map<String, dynamic> values,
    required Map<String, List<_RelationOption>> relationOptions,
    required void Function(void Function()) setModalState,
    required Future<void> Function(ModuleField field) refreshRelationOptions,
  }) {
    switch (field.type) {
      case ModuleFieldType.text:
      case ModuleFieldType.date:
        return TextFormField(
          controller: textControllers[field.key],
          decoration: InputDecoration(labelText: field.label),
          validator: (v) {
            if (!field.required) return null;
            return (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;
          },
        );
      case ModuleFieldType.number:
        return TextFormField(
          controller: textControllers[field.key],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: field.label),
          validator: (v) {
            if (!field.required && (v == null || v.trim().isEmpty)) {
              return null;
            }
            if (v == null || int.tryParse(v.trim()) == null) {
              return 'Nombre entier attendu';
            }
            final parsed = int.parse(v.trim());
            if (field.minValue != null && parsed < field.minValue!) {
              return 'Valeur minimum: ${field.minValue!.toStringAsFixed(0)}';
            }
            if (field.maxValue != null && parsed > field.maxValue!) {
              return 'Valeur maximum: ${field.maxValue!.toStringAsFixed(0)}';
            }
            return null;
          },
        );
      case ModuleFieldType.decimal:
        return TextFormField(
          controller: textControllers[field.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: field.label),
          validator: (v) {
            if (!field.required && (v == null || v.trim().isEmpty)) {
              return null;
            }
            if (v == null || double.tryParse(v.trim()) == null) {
              return 'Nombre decimal attendu';
            }
            final parsed = double.parse(v.trim());
            if (field.minValue != null && parsed < field.minValue!) {
              return 'Valeur minimum: ${field.minValue}';
            }
            if (field.maxValue != null && parsed > field.maxValue!) {
              return 'Valeur maximum: ${field.maxValue}';
            }
            return null;
          },
        );
      case ModuleFieldType.select:
        return DropdownButtonFormField<String>(
          initialValue: values[field.key]?.toString(),
          isExpanded: true,
          decoration: InputDecoration(labelText: field.label),
          items: field.options
              .map(
                (o) => DropdownMenuItem<String>(
                  value: o,
                  child: Text(field.optionLabels[o] ?? o),
                ),
              )
              .toList(),
          onChanged: (v) => setModalState(() => values[field.key] = v),
          validator: (v) {
            if (!field.required) return null;
            return (v == null || v.isEmpty) ? 'Champ obligatoire' : null;
          },
        );
      case ModuleFieldType.boolean:
        final current = values[field.key] == true;
        return SwitchListTile(
          value: current,
          onChanged: (v) => setModalState(() => values[field.key] = v),
          title: Text(field.label),
          contentPadding: EdgeInsets.zero,
        );
      case ModuleFieldType.relation:
        final opts = relationOptions[field.key] ?? const <_RelationOption>[];
        final current =
            values[field.key] is int ? values[field.key] as int : int.tryParse('${values[field.key]}');
        final entries = <DropdownMenuItem<int>>[
          if (!field.required)
            const DropdownMenuItem<int>(
              value: -1,
              child: Text('Aucun (client de passage)'),
            ),
          ...opts.map(
            (o) => DropdownMenuItem<int>(
              value: o.id,
              child: Text(o.subtitle == null ? o.label : '${o.label} (${o.subtitle})'),
            ),
          ),
        ];
        final relationHint = opts.isEmpty ? field.emptyOptionsHint : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: current ?? (field.required ? null : -1),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: field.label,
                helperText: relationHint,
                suffixIcon: opts.length > 12
                    ? IconButton(
                        tooltip: 'Voir tout',
                        onPressed: () async {
                          final picked = await _showRelationPickerDialog(
                            title: field.label,
                            options: opts,
                            allowEmpty: !field.required,
                            currentValue: current ?? (field.required ? null : -1),
                          );
                          if (picked != null) {
                            setModalState(() {
                              values[field.key] = picked;
                              _syncPaiementMontantFromSource(
                                sourceFieldKey: field.key,
                                selectedId: picked,
                                options: opts,
                                textControllers: textControllers,
                              );
                            });
                          }
                        },
                        icon: const Icon(Icons.list_alt_outlined),
                      )
                    : null,
              ),
              items: entries,
              onChanged: (v) => setModalState(() {
                values[field.key] = v;
                _syncPaiementMontantFromSource(
                  sourceFieldKey: field.key,
                  selectedId: v,
                  options: opts,
                  textControllers: textControllers,
                );
              }),
              validator: (v) {
                if (field.required && opts.isEmpty) {
                  return 'Aucune option disponible pour ce champ.';
                }
                if (!field.required) return null;
                return v == null ? 'Champ obligatoire' : null;
              },
            ),
            if (opts.isEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await refreshRelationOptions(field);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Rafraichir options'),
                  ),
                  if (widget.endpoint == '/ventes-pharmacie' &&
                      field.relationEndpoint == '/medicaments')
                    TextButton.icon(
                      onPressed: () async {
                        final created = await _showQuickCreateMedicamentDialog();
                        if (created) {
                          await refreshRelationOptions(field);
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter medicament'),
                    ),
                ],
              ),
          ],
        );
    }
  }

  Future<int?> _showRelationPickerDialog({
    required String title,
    required List<_RelationOption> options,
    required bool allowEmpty,
    required int? currentValue,
  }) async {
    final queryCtrl = TextEditingController();
    var query = '';
    return showDialog<int>(
      context: context,
      builder: (context) {
        final screen = MediaQuery.sizeOf(context);
        final maxHeight = screen.height * 0.72;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filtered = options.where((o) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return o.label.toLowerCase().contains(q) ||
                  (o.subtitle?.toLowerCase().contains(q) ?? false) ||
                  o.id.toString().contains(q);
            }).toList();
            return AlertDialog(
              title: Text('$title - Voir tout'),
              content: SizedBox(
                width: 560,
                height: maxHeight,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    TextField(
                      controller: queryCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setStateDialog(() => query = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length + (allowEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (allowEmpty && index == 0) {
                            final selected = (currentValue ?? -1) == -1;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onTap: () => Navigator.of(context).pop(-1),
                              title: const Text('Aucun (client de passage)'),
                              trailing: selected
                                  ? const Icon(Icons.check_circle, size: 20)
                                  : const Icon(Icons.circle_outlined, size: 20),
                            );
                          }
                          final actualIndex = allowEmpty ? index - 1 : index;
                          final option = filtered[actualIndex];
                          final selected = currentValue == option.id;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onTap: () => Navigator.of(context).pop(option.id),
                            title: Text(option.label),
                            subtitle: option.subtitle == null ? null : Text(option.subtitle!),
                            trailing: selected
                                ? const Icon(Icons.check_circle, size: 20)
                                : const Icon(Icons.circle_outlined, size: 20),
                          );
                        },
                      ),
                    ),
                  ],
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
      },
    );
  }

  Future<bool> _showQuickCreateMedicamentDialog() async {
    final formKey = GlobalKey<FormState>();
    final nomCtrl = TextEditingController();
    final prixCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    final seuilCtrl = TextEditingController(text: '5');

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau medicament'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: prixCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prix unitaire'),
                  validator: (v) {
                    final parsed = double.tryParse(v?.trim() ?? '');
                    if (parsed == null) return 'Nombre decimal attendu';
                    if (parsed < 0) return 'Valeur minimum: 0';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock initial'),
                  validator: (v) {
                    final parsed = int.tryParse(v?.trim() ?? '');
                    if (parsed == null) return 'Nombre entier attendu';
                    if (parsed < 0) return 'Valeur minimum: 0';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: seuilCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Seuil alerte'),
                  validator: (v) {
                    final parsed = int.tryParse(v?.trim() ?? '');
                    if (parsed == null) return 'Nombre entier attendu';
                    if (parsed < 0) return 'Valeur minimum: 0';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop({
                'nom': nomCtrl.text.trim(),
                'prix_unitaire': double.parse(prixCtrl.text.trim()),
                'stock': int.parse(stockCtrl.text.trim()),
                'seuil_alerte': int.parse(seuilCtrl.text.trim()),
                'actif': true,
              });
            },
            child: const Text('Creer'),
          ),
        ],
      ),
    );
    if (payload == null) return false;

    try {
      await ApiClient.dio.post('/medicaments', data: payload);
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Medicament cree avec succes.')));
      return true;
    } on DioException catch (e) {
      if (ApiClient.isNetworkError(e)) {
        await SyncQueue.enqueue(
          method: 'POST',
          path: '/medicaments',
          payload: payload,
          cacheInvalidateKey: 'cache_medicaments_all',
        );
        await SyncManager.instance.syncNow();
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hors connexion: creation du medicament en attente de synchronisation.',
            ),
          ),
        );
        return true;
      }
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractMessage(e))));
      return false;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erreur de creation.')));
      return false;
    }
  }
}

