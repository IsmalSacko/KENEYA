// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/offline/local_store.dart';
import '../core/offline/sync_manager.dart';
import '../core/offline/sync_queue.dart';

enum ModuleFieldType { text, number, decimal, select, date, boolean, relation }

class ModuleField {
  const ModuleField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const <String>[],
    this.relationEndpoint,
    this.relationLabelKey,
    this.relationSubtitleKey,
    this.relationFilterKey,
    this.relationFilterValue,
    this.visibleWhenKey,
    this.visibleWhenValue,
  });

  final String key;
  final String label;
  final ModuleFieldType type;
  final bool required;
  final List<String> options;
  final String? relationEndpoint;
  final String? relationLabelKey;
  final String? relationSubtitleKey;
  final String? relationFilterKey;
  final String? relationFilterValue;
  final String? visibleWhenKey;
  final String? visibleWhenValue;
}

class _RelationOption {
  const _RelationOption({required this.id, required this.label, this.subtitle});

  final int id;
  final String label;
  final String? subtitle;
}

class ApiModuleScreen extends StatefulWidget {
  const ApiModuleScreen({
    super.key,
    required this.title,
    required this.endpoint,
    required this.fields,
    this.allowCreate = true,
    this.allowUpdate = true,
    this.allowDelete = true,
  });

  final String title;
  final String endpoint;
  final List<ModuleField> fields;
  final bool allowCreate;
  final bool allowUpdate;
  final bool allowDelete;

  @override
  State<ApiModuleScreen> createState() => _ApiModuleScreenState();
}

class _ApiModuleScreenState extends State<ApiModuleScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String get _cacheKey => 'cache_module_${widget.endpoint}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiClient.dio.get(widget.endpoint);
      final data = response.data;
      final parsed = _parseList(data);
      await LocalStore.write(_cacheKey, parsed);
      setState(() => _items = parsed);
    } on DioException catch (e) {
      if (ApiClient.isNetworkError(e)) {
        final cached = LocalStore.read<List<dynamic>>(_cacheKey) ?? <dynamic>[];
        final parsed = cached
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() {
          _items = parsed;
          _error = parsed.isEmpty
              ? 'Hors connexion. Aucune donnee locale disponible.'
              : null;
        });
      } else {
        setState(() => _error = _extractMessage(e));
      }
    } catch (_) {
      setState(() => _error = 'Erreur de chargement.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      if (data['etablissements'] is List) {
        return (data['etablissements'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [Map<String, dynamic>.from(data)];
    }
    return <Map<String, dynamic>>[];
  }

  String _extractMessage(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
    return e.message ?? 'Erreur API';
  }

  Future<void> _create() async {
    final payload = await _showFormDialog(
      title: 'Nouveau ${widget.title}',
      fields: widget.fields,
    );
    if (payload == null) return;
    final normalizedPayload = _normalizePayload(payload);

    try {
      await ApiClient.dio.post(widget.endpoint, data: normalizedPayload);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Creation reussie.')));
      await _load();
    } on DioException catch (e) {
      if (ApiClient.isNetworkError(e)) {
        await SyncQueue.enqueue(
          method: 'POST',
          path: widget.endpoint,
          payload: normalizedPayload,
          cacheInvalidateKey: _cacheKey,
        );
        final optimistic = Map<String, dynamic>.from(normalizedPayload);
        optimistic['id'] = -DateTime.now().millisecondsSinceEpoch;
        setState(() => _items = [optimistic, ..._items]);
        await LocalStore.write(_cacheKey, _items);
        await SyncManager.instance.syncNow();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hors connexion: creation en file d\'attente. Synchronisation automatique.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_extractMessage(e))));
    }
  }

  Future<void> _update(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;

    final payload = await _showFormDialog(
      title: 'Modifier #$id',
      fields: widget.fields,
      initial: item,
    );
    if (payload == null) return;
    final normalizedPayload = _normalizePayload(payload);

    try {
      await ApiClient.dio.patch(
        '${widget.endpoint}/$id',
        data: normalizedPayload,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mise a jour reussie.')));
      await _load();
    } on DioException catch (e) {
      if (ApiClient.isNetworkError(e)) {
        await SyncQueue.enqueue(
          method: 'PATCH',
          path: '${widget.endpoint}/$id',
          payload: normalizedPayload,
          cacheInvalidateKey: _cacheKey,
        );
        final next = _items.map((row) {
          if (row['id'].toString() != id.toString()) return row;
          final updated = Map<String, dynamic>.from(row);
          updated.addAll(normalizedPayload);
          return updated;
        }).toList();
        setState(() => _items = next);
        await LocalStore.write(_cacheKey, next);
        await SyncManager.instance.syncNow();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hors connexion: modification en file d\'attente. Synchronisation automatique.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_extractMessage(e))));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text('Supprimer l\'element #$id ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiClient.dio.delete('${widget.endpoint}/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Suppression reussie.')));
      await _load();
    } on DioException catch (e) {
      if (ApiClient.isNetworkError(e)) {
        await SyncQueue.enqueue(
          method: 'DELETE',
          path: '${widget.endpoint}/$id',
          cacheInvalidateKey: _cacheKey,
        );
        final next = _items
            .where((row) => row['id'].toString() != id.toString())
            .toList();
        setState(() => _items = next);
        await LocalStore.write(_cacheKey, next);
        await SyncManager.instance.syncNow();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Hors connexion: suppression en file d\'attente. Synchronisation automatique.',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_extractMessage(e))));
    }
  }

  Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload) {
    final out = Map<String, dynamic>.from(payload);

    if (widget.endpoint == '/paiements') {
      final consultationId = out.remove('consultation_id');
      final venteId = out.remove('vente_pharmacie_id');
      if (out['source_type'] == 'consultation' && consultationId != null) {
        out['source_id'] = consultationId;
      } else if (out['source_type'] == 'vente_pharmacie' && venteId != null) {
        out['source_id'] = venteId;
      }
    }

    if (widget.endpoint == '/ventes-pharmacie') {
      final medicamentId = out.remove('article_medicament_id');
      final quantite = out.remove('article_quantite');
      if (medicamentId != null && quantite != null) {
        out['articles'] = [
          {'medicament_id': medicamentId, 'quantite': quantite},
        ];
      }
    }
    return out;
  }

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
        values[f.key] = initialValue;
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
                    for (final f in fields) ...[
                      if (_isVisible(f, values))
                        _buildField(
                          field: f,
                          textControllers: textControllers,
                          values: values,
                          relationOptions: relationOptions,
                          setModalState: setModalState,
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
                      if (v != null && v.toString().isNotEmpty) {
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
      final filtered = list.where((item) {
        if (field.relationFilterKey == null) return true;
        return item[field.relationFilterKey] == field.relationFilterValue;
      });
      return filtered
          .map((item) {
            final id = int.tryParse('${item['id']}');
            if (id == null) return null;
            final labelKey = field.relationLabelKey ?? 'name';
            final label = (item[labelKey] ?? 'ID $id').toString();
            final subtitleKey = field.relationSubtitleKey;
            final subtitle = subtitleKey == null
                ? null
                : item[subtitleKey]?.toString();
            return _RelationOption(id: id, label: label, subtitle: subtitle);
          })
          .whereType<_RelationOption>()
          .toList();
    } catch (_) {
      return const <_RelationOption>[];
    }
  }

  Widget _buildField({
    required ModuleField field,
    required Map<String, TextEditingController> textControllers,
    required Map<String, dynamic> values,
    required Map<String, List<_RelationOption>> relationOptions,
    required void Function(void Function()) setModalState,
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
            return null;
          },
        );
      case ModuleFieldType.select:
        return DropdownButtonFormField<String>(
          initialValue: values[field.key]?.toString(),
          decoration: InputDecoration(labelText: field.label),
          items: field.options
              .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
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
        final current = values[field.key] is int
            ? values[field.key] as int
            : int.tryParse('${values[field.key]}');
        return DropdownButtonFormField<int>(
          initialValue: current,
          decoration: InputDecoration(labelText: field.label),
          items: opts
              .map(
                (o) => DropdownMenuItem<int>(
                  value: o.id,
                  child: Text(
                    o.subtitle == null ? o.label : '${o.label} (${o.subtitle})',
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setModalState(() => values[field.key] = v),
          validator: (v) {
            if (field.required && opts.isEmpty) {
              return 'Aucune option disponible pour ce champ.';
            }
            if (!field.required) return null;
            return v == null ? 'Champ obligatoire' : null;
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          if (widget.allowCreate)
            IconButton(onPressed: _create, icon: const Icon(Icons.add)),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _items.isEmpty
            ? const Center(child: Text('Aucune donnee.'))
            : isDesktop
            ? _buildDesktopTable()
            : _buildMobileList(),
      ),
      floatingActionButton: widget.allowCreate
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            )
          : null,
    );
  }

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
                for (final c in columns) DataColumn(label: Text(c)),
                const DataColumn(label: Text('Actions')),
              ],
              rows: _items.map((item) {
                return DataRow(
                  cells: [
                    for (final c in columns)
                      DataCell(Text(_cellValue(item[c]))),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
    return ListView.builder(
      key: const ValueKey('mobile-list'),
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 180 + (index * 20)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in item.entries.take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${entry.key}: ${_cellValue(entry.value)}'),
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
                      if (widget.allowUpdate && widget.allowDelete)
                        const SizedBox(width: 8),
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

  List<String> _collectColumns() {
    final keys = <String>{'id'};
    for (final item in _items) {
      keys.addAll(item.keys);
      if (keys.length > 8) break;
    }
    final list = keys.toList();
    if (list.length > 8) return list.take(8).toList();
    return list;
  }

  String _cellValue(dynamic value) {
    if (value == null) return '-';
    if (value is Map || value is List) {
      final encoded = jsonEncode(value);
      return encoded.length > 80 ? '${encoded.substring(0, 80)}...' : encoded;
    }
    final text = value.toString();
    return text.length > 80 ? '${text.substring(0, 80)}...' : text;
  }
}
