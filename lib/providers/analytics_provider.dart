import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/analytics_repository.dart';
import '../models/user_models.dart';
import 'auth_provider.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(),
);

/// Department analytics for a specific ward. Pass wardId from citizen's login.
/// Returns empty list when wardId is null or fetch fails.
final wardDepartmentAnalyticsProvider =
    FutureProvider.family<List<DepartmentAnalyticsItem>, String?>((ref, wardId) async {
  if (wardId == null || wardId.isEmpty) return [];
  final token = ref.read(authProvider).accessToken;
  if (token == null || token.isEmpty) return [];
  try {
    return await ref.read(analyticsRepositoryProvider).getDepartmentAnalytics(
          accessToken: token,
          wardId: wardId,
        );
  } catch (_) {
    return [];
  }
});

/// Department detail (daily time series with resolved/pending/escalated) for a department.
/// Params: (departmentId, month, year). For citizens, passes their ward_id.
final departmentDetailProvider =
    FutureProvider.family<Map<String, dynamic>, ({String id, int month, int year})>(
  (ref, params) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) return {};
    final user = ref.read(authProvider).user;
    final wardId = user?.wardId;
    try {
      return await ref.read(analyticsRepositoryProvider).getDepartmentDetail(
            accessToken: token,
            departmentId: params.id,
            wardId: wardId,
            month: params.month,
            year: params.year,
          );
    } catch (_) {
      return {};
    }
  },
);

/// Department analytics for all departments (overall, no ward/zone filter).
final overallDepartmentAnalyticsProvider =
    FutureProvider<List<DepartmentAnalyticsItem>>((ref) async {
  final token = ref.read(authProvider).accessToken;
  if (token == null || token.isEmpty) return [];
  try {
    return await ref.read(analyticsRepositoryProvider).getDepartmentAnalytics(
          accessToken: token,
        );
  } catch (_) {
    return [];
  }
});

/// Ward performance comparison (WPI) for citizen portal. zone_id optional.
final wardAnalyticsProvider =
    FutureProvider.family<List<WardAnalyticsItem>, String?>((ref, zoneId) async {
  final token = ref.read(authProvider).accessToken;
  if (token == null || token.isEmpty) return [];
  try {
    return await ref.read(analyticsRepositoryProvider).getWardAnalytics(
          accessToken: token,
          zoneId: zoneId,
        );
  } catch (_) {
    return [];
  }
});

/// Worker analytics for manager portal. Params: departmentId, wardId, fromDate, toDate.
final workerAnalyticsProvider =
    FutureProvider.family<List<WorkerAnalyticsItem>, ({String? departmentId, String? wardId, DateTime? fromDate, DateTime? toDate})>(
  (ref, params) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) return [];
    try {
      return await ref.read(analyticsRepositoryProvider).getWorkerAnalytics(
            accessToken: token,
            departmentId: params.departmentId,
            wardId: params.wardId,
            fromDate: params.fromDate,
            toDate: params.toDate,
          );
    } catch (_) {
      return [];
    }
  },
);

/// Single worker detail analytics.
final workerDetailAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, ({String workerId, DateTime? fromDate, DateTime? toDate})>(
  (ref, params) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) return {};
    try {
      return await ref.read(analyticsRepositoryProvider).getWorkerDetailAnalytics(
            accessToken: token,
            workerId: params.workerId,
            fromDate: params.fromDate,
            toDate: params.toDate,
          );
    } catch (_) {
      return {};
    }
  },
);

/// Escalation Priority Score (EPS) ranked list of escalated grievances.
/// Params: optional wardId and zoneId for filtering.
final escalationPriorityProvider =
    FutureProvider.family<List<EscalationPriorityItem>, ({String? wardId, String? zoneId})>(
  (ref, params) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) return [];
    try {
      return await ref.read(analyticsRepositoryProvider).getEscalationPriorityList(
            accessToken: token,
            wardId: params.wardId,
            zoneId: params.zoneId,
          );
    } catch (_) {
      return [];
    }
  },
);

/// Civic Impact Score — loaded only from backend `GET /analytics/cis/{userId}` (snapshot, `legacy=false`).
final userCisProvider = FutureProvider<CisResult?>((ref) async {
  final token = ref.read(authProvider).accessToken;
  final user = ref.read(authProvider).user;
  if (token == null || token.isEmpty || user == null) return null;

  try {
    return await ref.read(analyticsRepositoryProvider).getCivicImpactScore(
          accessToken: token,
          userId: user.id,
        );
  } catch (_) {
    return null;
  }
});
