import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../storage/token_storage.dart';
import 'local_store.dart';
import 'offline_mirror.dart';
import 'sync_api.dart';
import 'sync_queue.dart';

class SyncManager {
  SyncManager._();

  static final SyncManager instance = SyncManager._();

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool _syncing = false;

  Future<void> init() async {
    _updatePendingCount();
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        unawaited(syncNow());
      }
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(syncNow());
    });

    final initial = await Connectivity().checkConnectivity();
    final online = initial.any((r) => r != ConnectivityResult.none);
    if (online) {
      await syncNow();
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _timer?.cancel();
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final queue = SyncQueue.getAll();
      if (queue.isEmpty) {
        _updatePendingCount();
        await _pullChanges();
        return;
      }
      queue.sort((a, b) {
        final aPath = (a['path'] ?? '').toString();
        final bPath = (b['path'] ?? '').toString();
        if (aPath == '/register' && bPath != '/register') return -1;
        if (bPath == '/register' && aPath != '/register') return 1;
        final aAt = (a['createdAt'] ?? '').toString();
        final bAt = (b['createdAt'] ?? '').toString();
        return aAt.compareTo(bAt);
      });

      final kept = <Map<String, dynamic>>[];

      for (final item in queue) {
        final method = (item['method'] ?? 'GET').toString().toUpperCase();
        final path = (item['path'] ?? '').toString();
        final payload = item['payload'];
        final attempts = (item['attempts'] as int? ?? 0) + 1;

        if (path.isEmpty) continue;

        try {
          final response = await ApiClient.dio.request<dynamic>(
            path,
            data: payload,
            options: Options(method: method),
          );
          await _onSyncedSuccess(path: path, response: response);
        } on DioException catch (e) {
          // Keep queued when still offline, otherwise retry later up to limit.
          final networkIssue = ApiClient.isNetworkError(e);
          if (networkIssue || attempts < 5) {
            final updated = Map<String, dynamic>.from(item);
            updated['attempts'] = attempts;
            kept.add(updated);
          }
        } catch (_) {
          if (attempts < 5) {
            final updated = Map<String, dynamic>.from(item);
            updated['attempts'] = attempts;
            kept.add(updated);
          }
        }
      }

      await SyncQueue.replaceAll(kept);
      _updatePendingCount();

      // Après avoir poussé les écritures locales, récupérer les changements
      // serveur pour alimenter le miroir hors-ligne (voir OfflineMirror).
      await _pullChanges();
    } finally {
      _syncing = false;
    }
  }

  /// Pull delta des changements serveur vers le miroir local. Silencieux :
  /// réessaie au prochain cycle en cas d'erreur réseau.
  Future<void> _pullChanges() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) return; // non authentifié

    try {
      final result = await SyncApi.pull(
        lastPulledRev: OfflineMirror.lastPulledRev,
      );

      final changes = result['changes'];
      if (changes is Map) {
        await OfflineMirror.applyPull(Map<String, dynamic>.from(changes));
      }

      final rev = result['server_rev'];
      final parsed = rev is int ? rev : int.tryParse(rev?.toString() ?? '');
      if (parsed != null) {
        await OfflineMirror.setLastPulledRev(parsed);
      }
    } on DioException catch (_) {
      // Ignoré : nouvelle tentative au prochain cycle de synchro.
    } catch (_) {
      // Idem.
    }
  }

  void _updatePendingCount() {
    pendingCount.value = SyncQueue.getAll().length;
  }

  Future<void> _onSyncedSuccess({
    required String path,
    required Response<dynamic> response,
  }) async {
    if (path != '/register') return;

    final data = response.data;
    if (data is! Map) return;
    final token = (data['access_token'] ?? '').toString();
    if (token.isEmpty) return;

    await TokenStorage.saveToken(token);
    await LocalStore.remove('offline_provisional_profile');
  }
}
