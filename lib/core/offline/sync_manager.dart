import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'sync_queue.dart';

class SyncManager {
  SyncManager._();

  static final SyncManager instance = SyncManager._();

  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  StreamSubscription<List<ConnectivityResult>>? _subscription;
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

    final initial = await Connectivity().checkConnectivity();
    final online = initial.any((r) => r != ConnectivityResult.none);
    if (online) {
      await syncNow();
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;

    try {
      final queue = SyncQueue.getAll();
      if (queue.isEmpty) {
        _updatePendingCount();
        return;
      }

      final kept = <Map<String, dynamic>>[];

      for (final item in queue) {
        final method = (item['method'] ?? 'GET').toString().toUpperCase();
        final path = (item['path'] ?? '').toString();
        final payload = item['payload'];
        final attempts = (item['attempts'] as int? ?? 0) + 1;

        if (path.isEmpty) continue;

        try {
          await ApiClient.dio.request<dynamic>(
            path,
            data: payload,
            options: Options(method: method),
          );
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
    } finally {
      _syncing = false;
    }
  }

  void _updatePendingCount() {
    pendingCount.value = SyncQueue.getAll().length;
  }
}
