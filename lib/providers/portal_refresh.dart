import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/complaint.dart';
import 'analytics_provider.dart';
import 'attendance_provider.dart';
import 'auth_provider.dart';
import 'complaint_provider.dart';
import 'departments_provider.dart';
import 'field_worker_provider.dart';
import 'message_provider.dart';
import 'offline_provider.dart';
import 'ward_provider.dart';
import 'weather_provider.dart';

/// Shared cache invalidation used by all portals.
void _invalidateShared(WidgetRef ref) {
  ref.invalidate(profileDetailsProvider);
  ref.invalidate(departmentsProvider);
  ref.invalidate(allCategoriesProvider);
  ref.invalidate(categoriesForDepartmentProvider);
  ref.invalidate(pendingSyncCountProvider);
}

/// Citizen portal: ward feed, history, escalations, insights, messages, profile, etc.
Future<void> refreshCitizenPortal(WidgetRef ref) async {
  _invalidateShared(ref);
  ref.invalidate(userCisProvider);
  ref.invalidate(wardWeatherProvider);
  ref.invalidate(currentUserWardProvider);
  ref.invalidate(wardDetailsProvider);
  ref.invalidate(wardAnalyticsProvider);
  ref.invalidate(overallDepartmentAnalyticsProvider);
  ref.invalidate(conversationsProvider);
  ref.invalidate(colleaguesProvider);

  await ref.read(complaintProvider.notifier).loadGrievances(limit: 100);
  final uid = ref.read(effectiveUserProvider)?.id;
  if (uid != null) {
    await ref.read(userHistoryProvider.notifier).loadGrievances(
          reporterId: uid,
          limit: 100,
        );
  }
  await ref.read(citizenEscalationsProvider.notifier).loadGrievances(
        limit: 100,
        status: ComplaintStatus.escalated,
      );
}

/// Manager portal: dashboard KPIs, grievance list, workforce, escalations, analytics.
Future<void> refreshManagerPortal(WidgetRef ref) async {
  _invalidateShared(ref);
  ref.invalidate(wardWeatherProvider);
  ref.invalidate(wardDepartmentAnalyticsProvider);
  ref.invalidate(wardAnalyticsProvider);
  ref.invalidate(overallDepartmentAnalyticsProvider);
  ref.invalidate(departmentDetailProvider);
  ref.invalidate(workerAnalyticsProvider);
  ref.invalidate(workerDetailAnalyticsProvider);

  await ref.read(complaintProvider.notifier).loadGrievances(limit: 100);
  await ref.read(fieldWorkerProvider.notifier).loadWorkers();
  final mg = ref.read(managerGrievancesProvider);
  await ref.read(managerGrievancesProvider.notifier).loadGrievances(
        limit: 100,
        status: mg.filterStatus,
      );
}

/// Worker portal: tasks, attendance, escalations, worker analytics.
Future<void> refreshWorkerPortal(WidgetRef ref) async {
  _invalidateShared(ref);
  ref.invalidate(wardWeatherProvider);
  ref.invalidate(workerAnalyticsProvider);
  ref.invalidate(workerDetailAnalyticsProvider);

  final uid = ref.read(authProvider).user?.id;
  if (uid != null) {
    final c = ref.read(complaintProvider);
    await ref.read(complaintProvider.notifier).loadGrievances(
          workerId: uid,
          status: c.filterStatus,
          limit: 100,
        );
    await ref.read(workerEscalationsProvider.notifier).loadGrievances(
          workerId: uid,
          status: ComplaintStatus.escalated,
          limit: 100,
        );
  }
  await ref.read(attendanceProvider.notifier).fetchStatus();
}
