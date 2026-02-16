// ignore_for_file: use_build_context_synchronously

import 'package:dio/dio.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api/api_client.dart';
import '../core/offline/local_store.dart';
import '../core/offline/sync_manager.dart';
import '../core/offline/sync_queue.dart';
import '../services/local_notification_service.dart';

part 'api_module_screen_form.dart';
part 'api_module_screen_view.dart';
part 'api_module_screen_helpers.dart';

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
    this.optionLabels = const <String, String>{},
    this.minValue,
    this.maxValue,
    this.emptyOptionsHint,
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
  final Map<String, String> optionLabels;
  final double? minValue;
  final double? maxValue;
  final String? emptyOptionsHint;
}

class _RelationOption {
  const _RelationOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.raw = const <String, dynamic>{},
  });

  final int id;
  final String label;
  final String? subtitle;
  final Map<String, dynamic> raw;
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
      final parsed = _parseList(response.data);
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
          _error =
              parsed.isEmpty ? 'Hors connexion. Aucune donnee locale disponible.' : null;
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
      final map = Map<String, dynamic>.from(data);
      const knownListKeys = [
        'data',
        'etablissements',
        'users',
        'patients',
        'medicaments',
        'consultations',
        'paiements',
        'ventes_pharmacie',
        'vente_pharmacie_articles',
        'mouvement_stocks',
        'journal_audits',
        'results',
        'items',
      ];

      for (final key in knownListKeys) {
        final value = map[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      for (final value in map.values) {
        if (value is List) {
          final parsed = value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (parsed.isNotEmpty) return parsed;
        }
      }

      return [map];
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
      final response = await ApiClient.dio.post(widget.endpoint, data: normalizedPayload);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Creation reussie.')));
      final createdId = _extractEntityId(response.data);
      await _recordAudit(action: 'creation', targetId: createdId);
      await _notifyAction('Creation', createdId);
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
        await _recordAudit(action: 'creation');
        await _notifyAction('Creation');
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractMessage(e))));
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
      await ApiClient.dio.patch('${widget.endpoint}/$id', data: normalizedPayload);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mise a jour reussie.')));
      await _recordAudit(action: 'modification', targetId: _toInt(id));
      await _notifyAction('Modification', _toInt(id));
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
        await _recordAudit(action: 'modification', targetId: _toInt(id));
        await _notifyAction('Modification', _toInt(id));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractMessage(e))));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Suppression reussie.')));
      await _recordAudit(action: 'suppression', targetId: _toInt(id));
      await _notifyAction('Suppression', _toInt(id));
      await _load();
    } on DioException catch (e) {
      if (ApiClient.isNetworkError(e)) {
        await SyncQueue.enqueue(
          method: 'DELETE',
          path: '${widget.endpoint}/$id',
          cacheInvalidateKey: _cacheKey,
        );
        final next = _items.where((row) => row['id'].toString() != id.toString()).toList();
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
        await _recordAudit(action: 'suppression', targetId: _toInt(id));
        await _notifyAction('Suppression', _toInt(id));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_extractMessage(e))));
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
}
