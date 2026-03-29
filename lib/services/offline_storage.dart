import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Offline cache and sync queue. Uses SharedPreferences.
class OfflineStorage {
  OfflineStorage([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;
  static const _prefix = 'civiccare_offline_';
  static const _workerTasksKey = '${_prefix}worker_tasks';
  static const _syncQueueKey = '${_prefix}sync_queue';
  static const _localClockInKey = '${_prefix}local_clock_in';

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Cache worker tasks. Key: workerId|status (status can be empty for "all").
  Future<void> cacheWorkerTasks({
    required String workerId,
    String? status,
    required Map<String, dynamic> apiResponse,
  }) async {
    final key = '${_workerTasksKey}_${workerId}_${status ?? "all"}';
    await (await _storage).setString(key, jsonEncode(apiResponse));
  }

  /// Read cached worker tasks. Returns null if not found or parse error.
  Future<Map<String, dynamic>?> readWorkerTasksCache({
    required String workerId,
    String? status,
  }) async {
    final key = '${_workerTasksKey}_${workerId}_${status ?? "all"}';
    final raw = (await _storage).getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Store local clock-in when offline (timestamp, lat, lng).
  Future<void> setLocalClockIn({
    required String clockInTime,
    required double lat,
    required double lng,
  }) async {
    await (await _storage).setString(
      _localClockInKey,
      jsonEncode({
        'clock_in_time': clockInTime,
        'lat': lat,
        'lng': lng,
      }),
    );
  }

  /// Read local clock-in. Returns null if none.
  Future<Map<String, dynamic>?> getLocalClockIn() async {
    final raw = (await _storage).getString(_localClockInKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Clear local clock-in (after successful sync).
  Future<void> clearLocalClockIn() async {
    await (await _storage).remove(_localClockInKey);
  }

  /// Add item to sync queue.
  Future<void> addToSyncQueue(Map<String, dynamic> item) async {
    final list = await getSyncQueue();
    list.add(item);
    await (await _storage).setString(_syncQueueKey, jsonEncode(list));
  }

  /// Get sync queue.
  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final raw = (await _storage).getString(_syncQueueKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>? ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Replace sync queue (after processing).
  Future<void> setSyncQueue(List<Map<String, dynamic>> list) async {
    await (await _storage).setString(_syncQueueKey, jsonEncode(list));
  }

  /// Clear sync queue.
  Future<void> clearSyncQueue() async {
    await (await _storage).remove(_syncQueueKey);
  }

  /// Update cached complaint when status changes offline.
  Future<void> updateCachedComplaintStatus({
    required String workerId,
    required String complaintId,
    required String newStatus,
  }) async {
    for (final status in [null, 'pending', 'assigned', 'inprogress', 'resolved', 'escalated']) {
      final key = '${_workerTasksKey}_${workerId}_${status ?? "all"}';
      final raw = (await _storage).getString(key);
      if (raw == null) continue;
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>?;
        if (data == null) continue;
        final items = data['items'] as List<dynamic>? ?? [];
        var updated = false;
        for (var i = 0; i < items.length; i++) {
          final m = items[i] as Map<String, dynamic>;
          if ((m['id'] as String? ?? '') == complaintId) {
            m['status'] = newStatus;
            updated = true;
            break;
          }
        }
        if (updated) {
          await (await _storage).setString(key, jsonEncode(data));
        }
      } catch (_) {}
    }
  }
}
