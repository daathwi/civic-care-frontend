import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ward.dart';
import 'departments_provider.dart';
import 'auth_provider.dart';

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
