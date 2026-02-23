part of 'api_module_screen.dart';

extension _ApiModuleScreenHelpers on _ApiModuleScreenState {
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
      final typeClient = out.remove('type_client')?.toString();
      if (typeClient == 'passage') {
        out.remove('patient_id'); //
        out.remove('patient_nom');
        out.remove('patient_telephone');
        out.remove('patient_adresse');
      } else if (typeClient == 'enregistre') {
        out.remove('patient_nom');
        out.remove('patient_telephone');
        out.remove('patient_adresse');
      } else if (typeClient == 'nouveau') {
        out.remove('patient_id');
      }
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

  String _extractPatientLabel(Map<String, dynamic> item) {
    final patient = item['patient'];
    if (patient is Map) {
      final p = Map<String, dynamic>.from(patient);
      final nom = p['nom']?.toString().trim();
      final tel = p['telephone']?.toString().trim();
      if (nom != null && nom.isNotEmpty && tel != null && tel.isNotEmpty) {
        return '$nom ($tel)';
      }
      if (nom != null && nom.isNotEmpty) return nom;
    }
    return 'Client de passage';
  }

  String _extractArticleName(Map<String, dynamic> article) {
    final med = article['medicament'];
    if (med is Map) {
      final nom = med['nom']?.toString().trim();
      if (nom != null && nom.isNotEmpty) return nom;
    }
    return 'Medicament';
  }

  List<String> _collectColumns() {
    final ordered = <String>[];
    const excluded = {
      'etablissement_id',
      'reference_locale',
      'created_at',
      'updated_at',
      'pivot',
    };

    if (_items.any((e) => e.containsKey('id'))) {
      ordered.add('id');
    }
    for (final field in widget.fields) {
      if (_items.any((item) => item.containsKey(field.key))) {
        ordered.add(field.key);
      }
    }
    for (final item in _items) {
      for (final key in item.keys) {
        if (excluded.contains(key)) continue;
        final value = item[key];
        if (value is Map || value is List) continue;
        if (!ordered.contains(key)) ordered.add(key);
      }
      if (ordered.length >= 8) break;
    }
    if (ordered.length > 8) return ordered.take(8).toList();
    return ordered;
  }

  String _cellValueForColumn(
    String key,
    dynamic value, [
    Map<String, dynamic>? row,
  ]) {
    if (widget.endpoint == '/paiements') {
      if (key == 'source_type') {
        final raw = value?.toString() ?? '';
        if (raw.toLowerCase().contains('consultation')) {
          return 'Consultation';
        }
        if (raw.toLowerCase().contains('vente')) {
          return 'Vente pharmacie';
        }
      }
      if (key == 'source_id' && row != null) {
        final source = row['source'];
        if (source is Map) {
          final s = Map<String, dynamic>.from(source);
          final sourceTypeRaw =
              row['source_type']?.toString().toLowerCase() ?? '';
          if (sourceTypeRaw.contains('consultation')) {
            final motif = s['motif']?.toString().trim();
            if (motif != null && motif.isNotEmpty) {
              return motif;
            }
            final id = s['id']?.toString();
            return id == null ? 'Consultation' : 'Consultation #$id';
          }
          if (sourceTypeRaw.contains('vente')) {
            final montant = s['montant_total'];
            final mode = s['mode_paiement']?.toString();
            final modeLabel =
                const {
                  'espece': 'Especes',
                  'orange': 'Orange Money',
                  'wave': 'Wave',
                  'moov': 'Moov Money',
                }[mode] ??
                mode;
            if (montant != null) {
              return '$montant FCFA${modeLabel == null ? '' : ' - $modeLabel'}';
            }
            final id = s['id']?.toString();
            return id == null ? 'Vente pharmacie' : 'Vente #$id';
          }
        }
      }
    }

    final field = widget.fields.cast<ModuleField?>().firstWhere(
      (f) => f?.key == key,
      orElse: () => null,
    );
    if (field != null && field.type == ModuleFieldType.boolean) {
      final boolValue = value == true || value == 1 || value?.toString() == '1';
      if (key == 'actif') return boolValue ? 'Actif' : 'Inactif';
      return boolValue ? 'Oui' : 'Non';
    }
    if (field != null &&
        field.type == ModuleFieldType.select &&
        field.optionLabels.isNotEmpty) {
      final raw = value?.toString();
      return field.optionLabels[raw] ?? (raw ?? '-');
    }
    return _cellValue(value);
  }

  String _displayLabelForKey(String key) {
    final field = widget.fields.cast<ModuleField?>().firstWhere(
      (f) => f?.key == key,
      orElse: () => null,
    );
    if (field != null) return field.label;
    const labels = {
      'id': 'ID',
      'source_type': 'Type source',
      'source_id': 'Source',
      'mode_paiement': 'Mode paiement',
      'montant_total': 'Montant total',
      'prix_unitaire': 'Prix unitaire',
      'prix_total': 'Prix total',
      'vente_pharmacie_id': 'Vente pharmacie',
      'medicament_id': 'Medicament',
      'patient_id': 'Patient',
      'user_id': 'Utilisateur',
      'type_cible': 'Type cible',
      'id_cible': 'ID cible',
      'statut_sync': 'Statut sync',
    };
    if (labels.containsKey(key)) return labels[key]!;
    return key
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _cellValue(dynamic value) {
    if (value == null) return '-';
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final nom = map['nom']?.toString().trim();
      if (nom != null && nom.isNotEmpty) {
        final tel = map['telephone']?.toString().trim();
        return tel == null || tel.isEmpty ? nom : '$nom ($tel)';
      }
      final name = map['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      if (map['id'] != null) return '#${map['id']}';
      final encoded = jsonEncode(value);
      return encoded.length > 80 ? '${encoded.substring(0, 80)}...' : encoded;
    }
    if (value is List) {
      return '${value.length} element(s)';
    }
    final text = value.toString();
    return text.length > 80 ? '${text.substring(0, 80)}...' : text;
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  int? _extractEntityId(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final direct = _toInt(map['id']);
      if (direct != null) return direct;
      const nestedKeys = [
        'vente',
        'article',
        'paiement',
        'consultation',
        'patient',
        'medicament',
        'journal',
        'etablissement',
        'user',
      ];
      for (final key in nestedKeys) {
        final nested = map[key];
        if (nested is Map) {
          final id = _toInt(nested['id']);
          if (id != null) return id;
        }
      }
    }
    return null;
  }

  String _targetTypeForAudit() {
    final path = widget.endpoint.replaceAll('/', '');
    final singular = path.endsWith('s')
        ? path.substring(0, path.length - 1)
        : path;
    return singular
        .split('-')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join();
  }

  Future<void> _recordAudit({required String action, int? targetId}) async {
    if (widget.endpoint == '/journal-audits') return;
    final payload = <String, dynamic>{
      'action':
          '${action}_${widget.endpoint.replaceAll('/', '').replaceAll('-', '_')}',
      'type_cible': _targetTypeForAudit(),
      'id_cible': targetId,
    };

    try {
      await ApiClient.dio.post('/journal-audits', data: payload);
    } on DioException catch (e) {
      if (ApiClient.isNetworkError(e)) {
        await SyncQueue.enqueue(
          method: 'POST',
          path: '/journal-audits',
          payload: payload,
          cacheInvalidateKey: 'cache_module_/journal-audits',
        );
      }
    } catch (_) {
      // Best effort audit
    }
  }

  Future<void> _notifyAction(String action, [int? id]) async {
    final module = widget.title;
    final idSuffix = id == null ? '' : ' (#$id)';
    try {
      await LocalNotificationService.show(
        title: '$action $module',
        body: '$action effectuee sur $module$idSuffix.',
      );
    } catch (_) {
      // Notification can fail on unsupported platform.
    }
  }
}
