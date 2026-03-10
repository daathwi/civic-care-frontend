import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/wards_repository.dart';

final wardsRepositoryProvider = Provider<WardsRepository>(
  (ref) => WardsRepository(),
);

/// All departments from API (GET /departments). Admin-created departments show up here.
final departmentsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final repo = ref.watch(wardsRepositoryProvider);
  final list = await repo.listDepartments();
  return list
      .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
      .toList();
});

/// All grievance categories from API (GET /categories).
final allCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  try {
    final repo = ref.watch(wardsRepositoryProvider);
    final list = await repo.listAllCategories();
    return list
        .map(
          (e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{},
        )
        .toList();
  } catch (e, stack) {
    debugPrint('Error fetching all categories: $e');
    debugPrint('$stack');
    rethrow;
  }
});

/// Categories for a given department. Filters from [allCategoriesProvider].
/// Pass department UUID; returns empty list if id is null or empty.
final categoriesForDepartmentProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>((
      ref,
      departmentId,
    ) async {
      if (departmentId == null || departmentId.isEmpty) return [];

      // Wait for the full list from the allCategoriesProvider
      final allCategories = await ref.watch(allCategoriesProvider.future);

      return allCategories.where((c) => c['dept_id'] == departmentId).toList();
    });
