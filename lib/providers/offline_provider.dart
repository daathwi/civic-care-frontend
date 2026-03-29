import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/offline_storage.dart';
import 'connectivity_provider.dart';

/// True when we have connectivity, false when offline. Defaults to true when unknown.
final isOnlineProvider = Provider<bool>((ref) {
  final async = ref.watch(connectivityProvider);
  return async.valueOrNull ?? true;
});

final offlineStorageProvider = Provider<OfflineStorage>((ref) {
  return OfflineStorage();
});

/// Number of pending sync items.
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final storage = ref.read(offlineStorageProvider);
  final queue = await storage.getSyncQueue();
  final hasLocalClockIn = await storage.getLocalClockIn() != null;
  return queue.length + (hasLocalClockIn ? 1 : 0);
});
