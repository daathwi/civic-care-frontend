import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/complaint.dart';
import '../models/user_models.dart';
import '../core/api_client.dart';
import '../repository/grievance_mappers.dart';
import '../repository/grievance_repository.dart';
import 'auth_provider.dart';
import 'departments_provider.dart';
import 'offline_provider.dart';

final grievanceRepositoryProvider = Provider<GrievanceRepository>(
  (ref) => GrievanceRepository(),
);

// ── State ────────────────────────────────────────────────────────────────────

/// Default page size when calling the list endpoint (matches backend default).
const int kGrievancePageLimit = 10;

class GrievanceState {
  final List<Complaint> complaints;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  /// Total count from last list API response (for "Load more").
  final int total;

  /// If set, the server filter reporter_id is used.
  final String? filterReporterId;

  /// If set, the server filter worker_id is used.
  final String? filterWorkerId;

  /// If set, the server filter status is used.
  final ComplaintStatus? filterStatus;

  const GrievanceState({
    this.complaints = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.total = 0,
    this.filterReporterId,
    this.filterWorkerId,
    this.filterStatus,
  });

  bool get hasMore => total > complaints.length;

  GrievanceState copyWith({
    List<Complaint>? complaints,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    int? total,
    String? filterReporterId,
    String? filterWorkerId,
    ComplaintStatus? filterStatus,
  }) {
    return GrievanceState(
      complaints: complaints ?? this.complaints,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      total: total ?? this.total,
      filterReporterId: filterReporterId ?? this.filterReporterId,
      filterWorkerId: filterWorkerId ?? this.filterWorkerId,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────
class ComplaintNotifier extends Notifier<GrievanceState> {
  @override
  GrievanceState build() => const GrievanceState();

  String? get _token => ref.read(authProvider).accessToken;

  GrievanceRepository get _repo => ref.read(grievanceRepositoryProvider);

  /// Department UUID -> name from GET /departments for resolving category_dept_id.
  Future<Map<String, String>> _deptIdToName() async {
    try {
      final list = await ref.read(departmentsProvider.future);
      final map = <String, String>{};
      for (final e in list) {
        if (e['id'] != null && e['name'] != null) {
          map[e['id'] as String] = e['name'] as String;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Load first page of grievances.
  Future<void> loadGrievances({
    int? limit,
    String? wardId,
    String? reporterId,
    String? workerId,
    ComplaintStatus? status,
  }) async {
    final pageLimit = limit ?? kGrievancePageLimit;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      filterReporterId: reporterId,
      filterWorkerId: workerId,
      filterStatus: status, // Persist for loadMore
    );
    try {
      final isOnline = ref.read(isOnlineProvider);
      if (!isOnline && workerId != null && workerId.isNotEmpty) {
        final storage = ref.read(offlineStorageProvider);
        final cached = await storage.readWorkerTasksCache(
          workerId: workerId,
          status: status != null ? _statusToApi(status) : null,
        );
        if (cached != null) {
          final deptIdToName = await _deptIdToName();
          final items = cached['items'] is List ? cached['items'] as List : <dynamic>[];
          final total = cached['total'] is int ? cached['total'] as int : items.length;
          final list = <Complaint>[];
          for (final e in items) {
            try {
              final map = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
              list.add(complaintFromApi(map, deptIdToName: deptIdToName));
            } catch (_) {}
          }
          state = state.copyWith(complaints: list, isLoading: false, total: total);
          return;
        }
      }
      final deptIdToName = await _deptIdToName();
      final res = await _listPage(
        skip: 0,
        limit: pageLimit,
        wardIdOverride: wardId,
        reporterIdOverride: reporterId,
        workerIdOverride: workerId,
        statusOverride: status,
      );
      final items = res['items'] is List ? res['items'] as List : <dynamic>[];
      final total = res['total'] is int ? res['total'] as int : items.length;
      final list = <Complaint>[];
      for (final e in items) {
        try {
          final map = e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map);
          list.add(complaintFromApi(map, deptIdToName: deptIdToName));
        } catch (_) {}
      }
      state = state.copyWith(complaints: list, isLoading: false, total: total);
      if (workerId != null && workerId.isNotEmpty) {
        ref.read(offlineStorageProvider).cacheWorkerTasks(
          workerId: workerId,
          status: status != null ? _statusToApi(status) : null,
          apiResponse: res,
        );
      }
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().length > 120
            ? '${e.toString().substring(0, 120)}…'
            : e.toString(),
      );
    } finally {
      if (state.isLoading) state = state.copyWith(isLoading: false);
    }
  }

  /// Fetches next page and appends to list.
  Future<void> loadMoreGrievances({String? wardId}) async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final deptIdToName = await _deptIdToName();
      final skip = state.complaints.length;
      final res = await _listPage(
        skip: skip,
        limit: kGrievancePageLimit,
        wardIdOverride: wardId,
        reporterIdOverride: state.filterReporterId,
        workerIdOverride: state.filterWorkerId,
        statusOverride: state.filterStatus,
      );
      final items = res['items'] as List<dynamic>? ?? [];
      final total = res['total'] as int? ?? state.total;
      final newList = [
        ...state.complaints,
        ...items.map(
          (e) => complaintFromApi(
            Map<String, dynamic>.from(e as Map),
            deptIdToName: deptIdToName,
          ),
        ),
      ];
      state = state.copyWith(
        complaints: newList,
        isLoadingMore: false,
        total: total,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.userMessage);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// List API filter params: use IDs only (ward_id, category_dept). No client-side filtering.
  String? get _wardIdParam {
    final user = ref.read(effectiveUserProvider);
    if (user == null) return null;
    final id = user.wardId;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  String? get _categoryDeptParam {
    final user = ref.read(effectiveUserProvider);
    if (user == null) return null;
    final id = user.departmentId;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<Map<String, dynamic>> _listPage({
    required int skip,
    required int limit,
    String? wardIdOverride,
    String? reporterIdOverride,
    String? workerIdOverride,
    ComplaintStatus? statusOverride,
  }) async {
    final user = ref.read(authProvider).user;
    final isStaff =
        user?.role == UserRole.fieldManager ||
        user?.role == UserRole.fieldAssistant;

    // Priority: Explicit Override > Automatically Derived ID
    // If we are filtering by reporter (History), we don't want to restrict by ward unless explicitly requested.
    final wardId =
        wardIdOverride ?? (reporterIdOverride != null ? null : _wardIdParam);

    // SAFEGUARD: If citizen feed and no wardId resolved yet, return empty to prevent global unfiltered feed.
    if (!isStaff && wardId == null && reporterIdOverride == null) {
      return {'items': [], 'total': 0, 'pages': 0};
    }

    final reporterId = reporterIdOverride ?? state.filterReporterId;
    // Only use explicitly-passed workerId override; never use sticky state filter
    // so manager portal never accidentally sends worker_id.
    final workerId = workerIdOverride;

    return _repo.list(
      accessToken: _token,
      skip: skip,
      limit: limit,
      wardId: wardId,
      reporterId: reporterId,
      workerId: workerId,
      status: statusOverride != null ? _statusToApi(statusOverride) : null,
      categoryDept: isStaff ? _categoryDeptParam : null,
    );
  }

  Future<String?> addComplaint({
    required String title,
    String? description,
    required double lat,
    required double lng,
    String? address,
    ComplaintPriority priority = ComplaintPriority.medium,
    String? departmentId,
    String? categoryId,
    String? wardId,
    File? photoFile,
    File? audioFile,
    bool isSensitive = false,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) return 'Not logged in';
    try {
      List<String> mediaUrls = [];
      if (photoFile != null) {
        final url = await _repo.uploadGrievancePhoto(
          accessToken: token,
          file: photoFile,
        );
        if (url.isNotEmpty) mediaUrls.add(url);
      }
      if (audioFile != null) {
        final url = await _repo.uploadGrievanceAudio(
          accessToken: token,
          file: audioFile,
        );
        if (url.isNotEmpty) mediaUrls.add(url);
      }

      final res = await _repo.create(
        accessToken: token,
        title: title,
        description: description,
        lat: lat,
        lng: lng,
        address: address,
        priority: priority == ComplaintPriority.high
            ? 'high'
            : priority == ComplaintPriority.low
            ? 'low'
            : 'medium',
        departmentId: departmentId,
        categoryId: categoryId,
        wardId: wardId,
        mediaUrls: mediaUrls,
        isSensitive: isSensitive,
      );
      final deptIdToName = await _deptIdToName();
      final c = complaintFromApi(res, deptIdToName: deptIdToName);
      state = state.copyWith(
        complaints: [c, ...state.complaints],
        total: state.total + 1,
      );
      return null;
    } on ApiException catch (e) {
      return e.userMessage;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> upvote(String id) async {
    final token = _token;
    if (token == null) return;
    try {
      await _repo.vote(id, accessToken: token, voteType: 1);
      final detail = await _repo.get(id, accessToken: token);
      final deptIdToName = await _deptIdToName();
      _replaceById(complaintFromApi(detail, deptIdToName: deptIdToName));
    } catch (_) {}
  }

  Future<void> downvote(String id) async {
    final token = _token;
    if (token == null) return;
    try {
      await _repo.vote(id, accessToken: token, voteType: -1);
      final detail = await _repo.get(id, accessToken: token);
      final deptIdToName = await _deptIdToName();
      _replaceById(complaintFromApi(detail, deptIdToName: deptIdToName));
    } catch (_) {}
  }

  Future<String?> addComment(String complaintId, String text) async {
    final token = _token;
    if (token == null || text.trim().isEmpty) return 'Not logged in';
    final trimmed = text.trim();
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      await ref.read(offlineStorageProvider).addToSyncQueue({
        'type': 'add_comment',
        'complaint_id': complaintId,
        'text': trimmed,
      });
      final user = ref.read(authProvider).user;
      final comment = Comment(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: user?.id ?? '',
        userName: user?.name ?? 'You',
        text: trimmed,
        timestamp: DateTime.now(),
      );
      addCommentLocal(complaintId, comment);
      return null;
    }
    try {
      final res = await _repo.addComment(
        complaintId,
        accessToken: token,
        text: trimmed,
      );
      final comment = Comment(
        id: res['id'] as String,
        userId: res['user_id'] as String,
        userName: res['user_name'] as String,
        text: res['text'] as String,
        timestamp:
            DateTime.tryParse(res['created_at'] as String) ?? DateTime.now(),
      );
      addCommentLocal(complaintId, comment);
      return null;
    } on ApiException catch (e) {
      return e.userMessage;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> assignWorker(
    String complaintId,
    String workerId,
    String workerName,
    String contact,
  ) async {
    final token = _token;
    if (token == null) return 'Not logged in';
    try {
      final res = await _repo.assign(
        complaintId,
        accessToken: token,
        workerId: workerId,
      );
      final deptIdToName = await _deptIdToName();
      _replaceById(complaintFromApi(res, deptIdToName: deptIdToName));
      return null;
    } on ApiException catch (e) {
      return e.userMessage;
    } catch (e) {
      return e.toString();
    }
  }

  String _statusToApi(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.completed:
        return 'resolved';
      case ComplaintStatus.incompleteAssigned:
        return 'assigned';
      case ComplaintStatus.incompleteUnassigned:
        return 'pending';
      case ComplaintStatus.ongoing:
        return 'inprogress';
      case ComplaintStatus.escalated:
        return 'escalated';
    }
  }

  Future<String?> updateStatus(
    String complaintId,
    ComplaintStatus newStatus,
    String note, {
    String? resolutionImagePath,
  }) async {
    final token = _token;
    if (token == null) return 'Not logged in';
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      await ref.read(offlineStorageProvider).addToSyncQueue({
        'type': 'update_status',
        'complaint_id': complaintId,
        'status': _statusToApi(newStatus),
        'note': note.isEmpty ? null : note,
        'resolution_image_path': resolutionImagePath,
      });
      final workerId = ref.read(authProvider).user?.id;
      if (workerId != null) {
        await ref.read(offlineStorageProvider).updateCachedComplaintStatus(
          workerId: workerId,
          complaintId: complaintId,
          newStatus: _statusToApi(newStatus),
        );
      }
      final idx = state.complaints.indexWhere((c) => c.id == complaintId);
      if (idx >= 0) {
        final updated = state.complaints[idx].copyWith(
          status: newStatus,
          resolutionImagePath: resolutionImagePath ?? state.complaints[idx].resolutionImagePath,
        );
        _replaceById(updated);
      }
      return null;
    }
    try {
      String? resolutionUrl;
      if (resolutionImagePath != null && resolutionImagePath.isNotEmpty) {
        final file = File(resolutionImagePath);
        if (await file.exists()) {
          resolutionUrl = await _repo.uploadResolutionPhoto(
            accessToken: token,
            file: file,
          );
        }
      }

      final res = await _repo.update(
        complaintId,
        accessToken: token,
        status: _statusToApi(newStatus),
        note: note.isEmpty ? null : note,
        resolutionImageUrl: resolutionUrl,
      );
      final deptIdToName = await _deptIdToName();
      _replaceById(complaintFromApi(res, deptIdToName: deptIdToName));
      return null;
    } on ApiException catch (e) {
      return e.userMessage;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> refreshGrievanceDetail(String grievanceId) async {
    try {
      final detail = await _repo.get(grievanceId, accessToken: _token);
      final deptIdToName = await _deptIdToName();
      _replaceById(complaintFromApi(detail, deptIdToName: deptIdToName));
    } catch (_) {}
  }

  /// Ensures a complaint is in the list so addCommentLocal can find it.
  /// Call when opening task detail from a screen that may use a different provider.
  void ensureComplaintInList(Complaint c) {
    final list = state.complaints;
    if (list.any((x) => x.id == c.id)) return;
    state = state.copyWith(complaints: [...list, c]);
  }

  void addCommentLocal(String grievanceId, Comment comment) {
    final list = state.complaints;
    final index = list.indexWhere((c) => c.id == grievanceId);
    if (index == -1) return;

    final updated = list[index].copyWith(
      comments: [...list[index].comments, comment],
    );

    state = state.copyWith(
      complaints: [
        for (int i = 0; i < list.length; i++)
          if (i == index) updated else list[i],
      ],
    );
  }

  void _replaceById(Complaint c) {
    final list = List<Complaint>.from(state.complaints);
    final idx = list.indexWhere((x) => x.id == c.id);
    if (idx != -1) {
      list[idx] = c;
    } else {
      list.add(c);
    }
    state = state.copyWith(complaints: list);
  }

  /// Rate a resolved grievance (1-5 stars). Returns null on success, error string on failure.
  Future<String?> rateGrievance(String grievanceId, int rating) async {
    try {
      final detail = await _repo.rate(
        grievanceId,
        accessToken: _token,
        rating: rating,
      );
      final deptIdToName = await _deptIdToName();
      _replaceById(complaintFromApi(detail, deptIdToName: deptIdToName));
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final complaintProvider = NotifierProvider<ComplaintNotifier, GrievanceState>(
  ComplaintNotifier.new,
);

/// Separate provider for User History to prevent polluting the Community Feed state.
final userHistoryProvider = NotifierProvider<ComplaintNotifier, GrievanceState>(
  ComplaintNotifier.new,
);

/// Separate provider for Manager portal list to prevent clobbering Dashboard KPIs.
final managerGrievancesProvider =
    NotifierProvider<ComplaintNotifier, GrievanceState>(
      ComplaintNotifier.new,
    );

/// Citizen portal: escalated grievances (status=escalated) so Feed tab keeps its own data.
final citizenEscalationsProvider =
    NotifierProvider<ComplaintNotifier, GrievanceState>(
      ComplaintNotifier.new,
    );

/// Worker portal: escalated tasks assigned to me. Isolated from complaintProvider
/// so Escalations tab does not show stale "my tasks" data from Dashboard.
final workerEscalationsProvider =
    NotifierProvider<ComplaintNotifier, GrievanceState>(
      ComplaintNotifier.new,
    );

/// Convenience selectors for backward compat.
final complaintListProvider = Provider<List<Complaint>>((ref) {
  return ref.watch(complaintProvider).complaints;
});

final userWardProvider = Provider<String>((ref) {
  final effectiveUser = ref.watch(effectiveUserProvider);
  return effectiveUser?.ward ?? 'Unknown Ward';
});

final userNameProvider = Provider<String>((ref) {
  final effectiveUser = ref.watch(effectiveUserProvider);
  return effectiveUser?.name ?? 'Guest';
});
