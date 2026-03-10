import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/field_worker.dart';
import '../models/user_models.dart';
import '../repository/worker_repository.dart';
import 'auth_provider.dart';

final workerRepositoryProvider = Provider<WorkerRepository>((ref) => WorkerRepository());

/// Set when loadWorkers() fails so UI can show error and retry.
final fieldWorkerLoadErrorProvider = StateProvider<String?>((ref) => null);

Department _deptFromApi(String? name) {
  if (name == null || name.isEmpty) return Department.sanitation;
  final n = name.toLowerCase();
  if (n.contains('sanitation') || n.contains('waste')) return Department.sanitation;
  if (n.contains('engineer')) return Department.engineering;
  if (n.contains('health')) return Department.publicHealth;
  if (n.contains('horticulture')) return Department.horticulture;
  return Department.sanitation;
}

String _str(dynamic v) => v == null ? '' : (v is String ? v : v.toString());

FieldWorker _workerFromApi(Map<String, dynamic> m) {
  final id = _str(m['id']);
  final name = _str(m['name']);
  final designation = _str(m['designation']);
  final phone = _str(m['phone']);
  final lastActiveWard = _str(m['last_active_ward']);
  final rating = (m['rating'] is num) ? (m['rating'] as num).toDouble() : 0.0;
  final tasksCompleted = m['tasks_completed'] is int ? m['tasks_completed'] as int : 0;
  final tasksActive = m['tasks_active'] is int ? m['tasks_active'] as int : 0;
  final statusStr = (m['status'] as String?)?.toLowerCase();
  final status = statusStr == 'onduty' ? FieldWorkerStatus.onDuty : FieldWorkerStatus.offDuty;
  final deptName = m['department_name'] as String?;
  final lastActiveLat = (m['last_active_lat'] is num) ? (m['last_active_lat'] as num).toDouble() : null;
  final lastActiveLng = (m['last_active_lng'] is num) ? (m['last_active_lng'] as num).toDouble() : null;
  return FieldWorker(
    id: id,
    name: name,
    designation: designation,
    phone: phone,
    department: _deptFromApi(deptName),
    lastActiveWard: lastActiveWard,
    rating: rating,
    tasksCompleted: tasksCompleted,
    tasksActive: tasksActive,
    status: status,
    lastActiveLat: lastActiveLat,
    lastActiveLng: lastActiveLng,
  );
}

class FieldWorkerNotifier extends Notifier<List<FieldWorker>> {
  @override
  List<FieldWorker> build() => [];

  Future<void> loadWorkers() async {
    ref.read(fieldWorkerLoadErrorProvider.notifier).state = null;
    try {
      final token = ref.read(authProvider).accessToken;
      final user = ref.read(effectiveUserProvider) ?? ref.read(authProvider).user;
      final departmentId = user?.departmentId;
      final wardId = user?.wardId;
      final res = await ref.read(workerRepositoryProvider).list(
        accessToken: token,
        limit: 100,
        department: departmentId,
        wardId: wardId,
      );
      final raw = res['items'];
      final items = raw is List ? raw : <dynamic>[];
      final list = <FieldWorker>[];
      for (final e in items) {
        try {
          if (e is Map<String, dynamic>) {
            list.add(_workerFromApi(e));
          } else if (e is Map) {
            list.add(_workerFromApi(Map<String, dynamic>.from(e)));
          }
        } catch (_) {}
      }
      state = list;
    } catch (e) {
      ref.read(fieldWorkerLoadErrorProvider.notifier).state =
          e.toString().length > 200 ? '${e.toString().substring(0, 200)}…' : e.toString();
      state = state;
    }
  }

  void updateStatus(String id, FieldWorkerStatus status) {
    state = [
      for (final w in state)
        if (w.id == id) w.copyWith(status: status) else w,
    ];
  }
}

final fieldWorkerProvider =
    NotifierProvider<FieldWorkerNotifier, List<FieldWorker>>(FieldWorkerNotifier.new);
