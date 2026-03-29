import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ward.dart';
import 'departments_provider.dart';
import 'auth_provider.dart';
import 'field_worker_provider.dart';

/// Fetches details for a specific ward by ID.
final wardDetailsProvider = FutureProvider.family<Ward, String>((ref, wardId) async {
  final repo = ref.watch(wardsRepositoryProvider);
  return await repo.getWard(wardId);
});

/// Current user's ward details, if available.
final currentUserWardProvider = FutureProvider<Ward?>((ref) async {
  final userProfile = ref.watch(authProvider).user;
  if (userProfile == null || userProfile.wardId == null) return null;
  
  return await ref.watch(wardDetailsProvider(userProfile.wardId!).future);
});

/// Field managers ([WorkerProfile] role `fieldManager`) for a ward — GET /workers?ward_id=… (public), filtered client-side.
final fieldManagersForWardProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, wardId) async {
  final repo = ref.watch(workerRepositoryProvider);
  final token = ref.watch(authProvider).accessToken;
  final data = await repo.list(accessToken: token, wardId: wardId, limit: 100);
  final raw = data['items'];
  final items = raw is List
      ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
  return items.where((e) => (e['role'] as String?) == 'fieldManager').toList();
});
