import '../core/api_client.dart';
import '../models/user_models.dart';

/// Worker performance analytics from GET /analytics/workers.
class WorkerAnalyticsItem {
  final String id;
  final String name;
  final String? departmentName;
  final String? wardName;
  final String designation;
  final String status;
  final Map<String, dynamic> metrics;
  final Map<String, String> period;

  WorkerAnalyticsItem({
    required this.id,
    required this.name,
    this.departmentName,
    this.wardName,
    required this.designation,
    required this.status,
    required this.metrics,
    required this.period,
  });

  factory WorkerAnalyticsItem.fromJson(Map<String, dynamic> json) {
    final m = json['metrics'] as Map<String, dynamic>? ?? {};
    final p = json['period'] as Map<String, dynamic>? ?? {};
    return WorkerAnalyticsItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      departmentName: json['department_name'] as String?,
      wardName: json['ward_name'] as String?,
      designation: json['designation'] as String? ?? '',
      status: json['status'] as String? ?? 'offDuty',
      metrics: m,
      period: p.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
    );
  }

  int get tasksCompleted => (metrics['tasks_completed'] as num?)?.toInt() ?? 0;
  int get tasksActive => (metrics['tasks_active'] as num?)?.toInt() ?? 0;
  double? get rating => (metrics['rating'] as num?)?.toDouble();
  int get ratingsCount => (metrics['ratings_count'] as num?)?.toInt() ?? 0;
  int get periodResolved => (metrics['period_resolved'] as num?)?.toInt() ?? 0;
  int get periodSlaOk => (metrics['period_sla_ok'] as num?)?.toInt() ?? 0;
  double get slaRate => (metrics['sla_rate'] as num?)?.toDouble() ?? 1.0;
  int get reopenCount => (metrics['reopen_count'] as num?)?.toInt() ?? 0;
  int get escalatedCount => (metrics['escalated_count'] as num?)?.toInt() ?? 0;
  double? get avgResolutionHours => (metrics['avg_resolution_hours'] as num?)?.toDouble();
  double? get periodAvgRating => (metrics['period_avg_rating'] as num?)?.toDouble();
  int get periodRatingsCount => (metrics['period_ratings_count'] as num?)?.toInt() ?? 0;
  int get daysPresent => (metrics['days_present'] as num?)?.toInt() ?? 0;
  double get attendanceRate => (metrics['attendance_rate'] as num?)?.toDouble() ?? 0.0;
  double? get avgHoursPerDay => (metrics['avg_hours_per_day'] as num?)?.toDouble();
}

/// Department performance analytics item from GET /analytics/departments.
class DepartmentAnalyticsItem {
  final String id;
  final String name;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> scores;
  final String performance;

  DepartmentAnalyticsItem({
    required this.id,
    required this.name,
    required this.metrics,
    required this.scores,
    required this.performance,
  });

  factory DepartmentAnalyticsItem.fromJson(Map<String, dynamic> json) {
    return DepartmentAnalyticsItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      metrics: json['metrics'] as Map<String, dynamic>? ?? {},
      scores: json['scores'] as Map<String, dynamic>? ?? {},
      performance: json['performance'] as String? ?? 'Average',
    );
  }

  double get dpi => (scores['dpi'] as num?)?.toDouble() ?? 0;
  int get total => (metrics['total'] as num?)?.toInt() ?? 0;
  int get resolved => (metrics['resolved'] as num?)?.toInt() ?? 0;
}

/// Ward performance analytics item from GET /analytics/wards.
class WardAnalyticsItem {
  final String id;
  final String name;
  final int? number;
  final String? zoneName;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> scores;
  final String performance;

  WardAnalyticsItem({
    required this.id,
    required this.name,
    this.number,
    this.zoneName,
    required this.metrics,
    required this.scores,
    required this.performance,
  });

  factory WardAnalyticsItem.fromJson(Map<String, dynamic> json) {
    return WardAnalyticsItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      number: json['number'] as int?,
      zoneName: json['zone_name'] as String?,
      metrics: json['metrics'] as Map<String, dynamic>? ?? {},
      scores: json['scores'] as Map<String, dynamic>? ?? {},
      performance: json['performance'] as String? ?? 'Average',
    );
  }

  double get wpi => (scores['wpi'] as num?)?.toDouble() ?? 0;
  /// Ward index from department DPI average; same as [wpi] unless API adds explicit dpi.
  double get dpi => (scores['dpi'] as num?)?.toDouble() ?? wpi;
  int get total => (metrics['total'] as num?)?.toInt() ?? 0;
  int get resolved => (metrics['resolved'] as num?)?.toInt() ?? 0;
  int get pending => (metrics['pending'] as num?)?.toInt() ?? 0;
  int get escalated => (metrics['escalated'] as num?)?.toInt() ?? 0;
}

/// Escalation Priority Score item from GET /analytics/grievances/escalation-priority.
class EscalationPriorityItem {
  final String id;
  final String title;
  final String status;
  final String priority;
  final String wardName;
  final String? wardId;
  final DateTime? createdAt;
  final double ageHours;
  final int reopenCount;
  final int upvotes;
  final int downvotes;
  final Map<String, dynamic> eps;
  final String escalationLevel;

  EscalationPriorityItem({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.wardName,
    this.wardId,
    this.createdAt,
    required this.ageHours,
    required this.reopenCount,
    required this.upvotes,
    required this.downvotes,
    required this.eps,
    required this.escalationLevel,
  });

  factory EscalationPriorityItem.fromJson(Map<String, dynamic> json) {
    return EscalationPriorityItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
      wardName: json['ward_name'] as String? ?? '—',
      wardId: json['ward_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      ageHours: (json['age_hours'] as num?)?.toDouble() ?? 0.0,
      reopenCount: (json['reopen_count'] as num?)?.toInt() ?? 0,
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
      eps: json['eps'] as Map<String, dynamic>? ?? {},
      escalationLevel: json['escalation_level'] as String? ?? 'Low',
    );
  }

  double get epsTotal => (eps['total'] as num?)?.toDouble() ?? 0.0;
  double get epsAge => (eps['escalation_age'] as num?)?.toDouble() ?? 0.0;
  double get epsReopen => (eps['reopen_frequency'] as num?)?.toDouble() ?? 0.0;
  double get epsVotes => (eps['net_votes_impact'] as num?)?.toDouble() ?? 0.0;
  double get epsSeverity => (eps['severity_level'] as num?)?.toDouble() ?? 0.0;
}

class AnalyticsRepository {
  AnalyticsRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// GET /analytics/wards — ward performance comparison (WPI). zone_id optional.
  Future<List<WardAnalyticsItem>> getWardAnalytics({
    required String accessToken,
    String? zoneId,
  }) async {
    final params = <String, String>{};
    if (zoneId != null && zoneId.isNotEmpty) params['zone_id'] = zoneId;

    final res = await _client.withToken(accessToken).get(
          '/analytics/wards',
          queryParameters: params.isEmpty ? null : params,
        );
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json;
    if (data is! List) return [];
    return data
        .map((e) => WardAnalyticsItem.fromJson(e))
        .toList();
  }

  /// GET /analytics/departments — ward_id, zone_id optional for filtering.
  Future<List<DepartmentAnalyticsItem>> getDepartmentAnalytics({
    required String accessToken,
    String? wardId,
    String? zoneId,
  }) async {
    final params = <String, String>{};
    if (wardId != null && wardId.isNotEmpty) params['ward_id'] = wardId;
    if (zoneId != null && zoneId.isNotEmpty) params['zone_id'] = zoneId;

    final res = await _client.withToken(accessToken).get(
          '/analytics/departments',
          queryParameters: params.isEmpty ? null : params,
        );
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json;
    if (data is! List) return [];
    return data
        .map((e) => DepartmentAnalyticsItem.fromJson(e))
        .toList();
  }

  /// GET /analytics/workers — worker performance analytics.
  Future<List<WorkerAnalyticsItem>> getWorkerAnalytics({
    required String accessToken,
    String? departmentId,
    String? wardId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final params = <String, String>{};
    if (departmentId != null && departmentId.isNotEmpty) params['department_id'] = departmentId;
    if (wardId != null && wardId.isNotEmpty) params['ward_id'] = wardId;
    if (fromDate != null) params['from_date'] = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
    if (toDate != null) params['to_date'] = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';

    final res = await _client.withToken(accessToken).get(
          '/analytics/workers',
          queryParameters: params.isEmpty ? null : params,
        );
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json;
    if (data is! List) return [];
    return data
        .map((e) => WorkerAnalyticsItem.fromJson(e))
        .toList();
  }

  /// GET /analytics/workers/{id} — single worker detail analytics.
  Future<Map<String, dynamic>> getWorkerDetailAnalytics({
    required String accessToken,
    required String workerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final params = <String, String>{};
    if (fromDate != null) params['from_date'] = '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}';
    if (toDate != null) params['to_date'] = '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}';

    final res = await _client.withToken(accessToken).get(
          '/analytics/workers/$workerId',
          queryParameters: params.isEmpty ? null : params,
        );
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json;
    return data is Map<String, dynamic> ? data : {};
  }

  /// GET /analytics/departments/{id}/detail — daily time_series (resolved/pending/escalated) for a month.
  Future<Map<String, dynamic>> getDepartmentDetail({
    required String accessToken,
    required String departmentId,
    String? wardId,
    String? zoneId,
    required int month,
    required int year,
  }) async {
    final params = <String, String>{
      'month': month.toString(),
      'year': year.toString(),
    };
    if (wardId != null && wardId.isNotEmpty) params['ward_id'] = wardId;
    if (zoneId != null && zoneId.isNotEmpty) params['zone_id'] = zoneId;

    final res = await _client.withToken(accessToken).get(
          '/analytics/departments/$departmentId/detail',
          queryParameters: params,
        );
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json;
    return data is Map<String, dynamic> ? data : {};
  }

  /// GET /analytics/grievances/escalation-priority — EPS ranked list of escalated grievances.
  Future<List<EscalationPriorityItem>> getEscalationPriorityList({
    required String accessToken,
    String? wardId,
    String? zoneId,
  }) async {
    final params = <String, String>{};
    if (wardId != null && wardId.isNotEmpty) params['ward_id'] = wardId;
    if (zoneId != null && zoneId.isNotEmpty) params['zone_id'] = zoneId;

    final res = await _client.withToken(accessToken).get(
          '/analytics/grievances/escalation-priority',
          queryParameters: params.isEmpty ? null : params,
        );
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json;
    if (data is! List) return [];
    return data
        .map((e) => EscalationPriorityItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /analytics/cis/{userId} — Civic Impact Score from backend snapshots (not legacy live calc).
  Future<CisResult> getCivicImpactScore({
    required String accessToken,
    required String userId,
  }) async {
    final res = await _client.withToken(accessToken).get(
          '/analytics/cis/$userId',
          queryParameters: const {'legacy': 'false'},
        );
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json;
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object for CIS result');
    }
    return CisResult.fromJson(data);
  }
}
