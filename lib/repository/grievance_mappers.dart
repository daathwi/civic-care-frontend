import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../core/app_theme.dart';
import '../models/complaint.dart';

ComplaintStatus statusFromApi(String? v) {
  switch (v?.toLowerCase()) {
    case 'pending':
      return ComplaintStatus.incompleteUnassigned;
    case 'assigned':
      return ComplaintStatus.incompleteAssigned;
    case 'inprogress':
      return ComplaintStatus.ongoing;
    case 'escalated':
      return ComplaintStatus.escalated;
    case 'resolved':
      return ComplaintStatus.completed;
    default:
      return ComplaintStatus.incompleteUnassigned;
  }
}

ComplaintCategory categoryFromApi(String? name) {
  if (name == null || name.isEmpty) return ComplaintCategory.other;
  final n = name.toLowerCase();
  // Sanitation & Waste
  if (n.contains('sanitation') ||
      n.contains('waste') ||
      n.contains('bin') ||
      n.contains('carcass') ||
      n.contains('litter')) {
    return ComplaintCategory.sanitation;
  }
  // Engineering (roads, potholes, infra)
  if (n.contains('engineer') ||
      n.contains('road') ||
      n.contains('pothole') ||
      n.contains('street') ||
      n.contains('manhole') ||
      n.contains('waterlogging') ||
      n.contains('wire') ||
      n.contains('pipe') ||
      n.contains('streetlight') ||
      n.contains('crack')) {
    return ComplaintCategory.engineering;
  }
  // Public Health (dengue, stagnant water, mosquitoes)
  if (n.contains('health') ||
      n.contains('dengue') ||
      n.contains('mosquito') ||
      n.contains('stagnant')) {
    return ComplaintCategory.health;
  }
  // Horticulture (grass, trees, plants, garden)
  if (n.contains('horticulture') ||
      n.contains('tree') ||
      n.contains('garden') ||
      n.contains('grass') ||
      n.contains('overgrown') ||
      n.contains('plant') ||
      n.contains('fallen') ||
      n.contains('dry') ||
      n.contains('nature')) {
    return ComplaintCategory.horticulture;
  }
  // Community Assets
  if (n.contains('asset') ||
      n.contains('community') ||
      n.contains('toilet') ||
      n.contains('cremation') ||
      n.contains('center')) {
    return ComplaintCategory.assets;
  }
  return ComplaintCategory.other;
}

/// Map API department name to ComplaintCategory for filtering when using category_dept_id.
ComplaintCategory categoryFromDepartmentName(String? deptName) {
  if (deptName == null || deptName.isEmpty) return ComplaintCategory.other;
  final n = deptName.toLowerCase();
  if (n.contains('sanitation') || n.contains('waste')) {
    return ComplaintCategory.sanitation;
  }
  if (n.contains('engineer') || n.contains('engineering')) {
    return ComplaintCategory.engineering;
  }
  if (n.contains('health')) return ComplaintCategory.health;
  if (n.contains('horticulture')) return ComplaintCategory.horticulture;
  if (n.contains('asset') || n.contains('community')) {
    return ComplaintCategory.assets;
  }
  return ComplaintCategory.other;
}

ComplaintPriority priorityFromApi(String? v) {
  switch (v?.toLowerCase()) {
    case 'high':
      return ComplaintPriority.high;
    case 'low':
      return ComplaintPriority.low;
    default:
      return ComplaintPriority.medium;
  }
}

IconData iconFromApi(String? iconName) {
  switch (iconName?.toLowerCase()) {
    case 'assignment_turned_in':
    case 'assignment':
      return Icons.assignment_turned_in;
    case 'assignment_ind_rounded':
    case 'assignment_ind':
      return Icons.assignment_ind_rounded;
    case 'person_add':
    case 'person':
      return Icons.person_add;
    case 'engineering':
    case 'build':
      return Icons.engineering_rounded;
    case 'check_circle':
    case 'verified':
    case 'check_circle_outline_rounded':
      return Icons.check_circle_outline_rounded;
    case 'update_rounded':
    case 'update':
      return Icons.update_rounded;
    case 'info_outline':
    case 'info':
    case 'article_outlined':
      return Icons.article_outlined;
    case 'schedule_rounded':
    case 'schedule':
      return Icons.schedule_rounded;
    case 'rate_review':
      return Icons.rate_review;
    case 'local_shipping':
      return Icons.local_shipping;
    case 'cleaning_services':
      return Icons.cleaning_services;
    case 'report_problem':
      return Icons.report_problem;
    case 'bolt':
      return Icons.bolt;
    default:
      return Icons.info_outline;
  }
}

/// Picks a distinct icon from event title when backend sends no/unknown icon_name.
IconData iconFromEventTitle(String? title) {
  if (title == null || title.isEmpty) return Icons.info_outline;
  final t = title.toLowerCase();
  if (t.contains('registered') ||
      t.contains('created') ||
      t.contains('complaint')) {
    return Icons.article_outlined;
  }
  if (t.contains('assigned') || t.contains('assignment')) {
    return Icons.assignment_ind_rounded;
  }
  if (t.contains('resolved') || t.contains('completed')) {
    return Icons.check_circle_outline_rounded;
  }
  if (t.contains('in progress') ||
      t.contains('inprogress') ||
      t.contains('ongoing')) {
    return Icons.update_rounded;
  }
  if (t.contains('pending')) return Icons.schedule_rounded;
  return Icons.info_outline;
}

String _eventDescriptionFallback(String? description, String? title) {
  if (description != null &&
      description.isNotEmpty &&
      description.toLowerCase() != 'string') {
    return description;
  }
  if (title == null || title.isEmpty) return 'Status update';
  final t = title.toLowerCase();
  if (t.contains('registered') || t.contains('created')) {
    return 'Ticket created.';
  }
  if (t.contains('assigned')) return 'Ticket assigned to a field assistant.';
  if (t.contains('resolved') || t.contains('completed')) {
    return 'Ticket marked as resolved.';
  }
  if (t.contains('in progress') || t.contains('inprogress')) {
    return 'Status updated to in progress.';
  }
  if (t.contains('pending')) return 'Status set to pending.';
  return 'Status updated.';
}

/// Accent color for timeline icon circle by event type (Teal Green).
Color eventAccentColor(String? title) {
  return AppTheme.primary;
}

double _parseDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

/// Coerce API id (UUID string or number) to String for Complaint/assignments.
String _idStr(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

Comment commentFromApi(Map<String, dynamic> m) {
  return Comment(
    id: m['id'] as String? ?? '',
    userId: m['user_id'] as String? ?? '',
    userName: m['user_name'] as String? ?? '',
    text: m['text'] as String? ?? '',
    timestamp: _parseDate(m['created_at']),
  );
}

ComplaintEvent eventFromApi(Map<String, dynamic> m) {
  final title = m['title'] as String? ?? '';
  final iconName = m['icon_name'] as String?;
  final rawDesc = m['description'] as String?;
  final t = title.toLowerCase();
  IconData icon;
  if (t.contains('resolved') || t.contains('completed')) {
    icon = Icons.check_circle_outline_rounded;
  } else if (iconName != null && iconName.toString().trim().isNotEmpty) {
    icon = iconFromApi(iconName);
  } else {
    icon = iconFromEventTitle(title);
  }
  return ComplaintEvent(
    id: m['id'] as String? ?? '',
    title: title,
    description: _eventDescriptionFallback(rawDesc, title),
    timestamp: _parseDate(m['created_at']),
    icon: icon,
  );
}

/// [deptIdToName] optional map: department UUID -> department name (from GET /departments).
/// When provided, [category_dept_id] is resolved to set [Complaint.departmentDisplayName] and category.
Complaint complaintFromApi(
  Map<String, dynamic> m, {
  Map<String, String>? deptIdToName,
}) {
  List<Comment> comments = [];
  List<ComplaintEvent> events = [];
  try {
    final cList = m['comments'] as List<dynamic>?;
    if (cList != null) {
      comments = cList
          .map((e) => commentFromApi(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  } catch (_) {}
  try {
    final eList = m['events'] as List<dynamic>?;
    if (eList != null) {
      events = eList
          .map((e) => eventFromApi(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  } catch (_) {}

  final wardName = m['ward_name'] as String?;
  final wardNum = m['ward_number'];
  final ward = (wardName != null && wardName.isNotEmpty)
      ? wardName
      : 'Ward ${wardNum ?? ''}'.trim();
  final wardDisplay = ward.isEmpty ? 'Unknown' : ward;

  final categoryName = m['category_name'] as String?;
  final categoryDeptId = m['category_dept_id'] == null
      ? null
      : _idStr(m['category_dept_id']);
  String? departmentDisplayName;
  ComplaintCategory category = categoryFromApi(categoryName);
  if (deptIdToName != null &&
      categoryDeptId != null &&
      categoryDeptId.isNotEmpty) {
    departmentDisplayName = deptIdToName[categoryDeptId];
    if (departmentDisplayName != null && departmentDisplayName.isNotEmpty) {
      category = categoryFromDepartmentName(departmentDisplayName);
    }
  }

  String? audioUrl;
  try {
    final mediaList = m['media'] as List<dynamic>?;
    if (mediaList != null) {
      final audioMedia = mediaList.firstWhere(
        (e) => (e as Map)['type'] == 'audio',
        orElse: () => null,
      );
      if (audioMedia != null) {
        audioUrl = toFullPhotoUrl(audioMedia['media_url'] as String?);
      }
    }
    if (audioUrl == null && m['audio_url'] != null) {
      audioUrl = toFullPhotoUrl(m['audio_url'] as String?);
    }
  } catch (_) {}

  return Complaint(
    id: _idStr(m['id']),
    title: m['title'] as String? ?? '',
    description: m['description'] as String? ?? '',
    imagePath: toFullPhotoUrl(m['image_url'] as String?),
    latitude: _parseDouble(m['lat']),
    longitude: _parseDouble(m['lng']),
    address: m['address'] as String? ?? '',
    status: statusFromApi(m['status'] as String?),
    category: category,
    subCategory: categoryName ?? 'Other',
    priority: priorityFromApi(m['priority'] as String?),
    date: _parseDate(m['created_at']),
    ward: wardDisplay,
    userName: m['reporter_name'] as String? ?? '',
    upvotes: m['upvotes_count'] is int ? m['upvotes_count'] as int : 0,
    downvotes: m['downvotes_count'] is int ? m['downvotes_count'] as int : 0,
    comments: comments,
    assignedTo: m['assigned_to_name'] as String?,
    assignedToId: m['assigned_to_id'] == null
        ? null
        : _idStr(m['assigned_to_id']),
    workerContact: m['worker_contact'] as String?,
    assignedByName: m['assigned_by_name'] as String?,
    assignedByPhone: m['assigned_by_phone'] as String?,
    resolutionImagePath: toFullPhotoUrl(
      (m['resolution_media_url'] as String?) ??
          (m['resolution_image_url'] as String?),
    ),
    audioPath: audioUrl,
    assignedAt: m['assigned_at'] != null ? DateTime.tryParse(m['assigned_at'] as String)?.toLocal() : null,
    isSensitive: m['is_sensitive'] as bool? ?? false,
    events: events,
    reporterId: m['reporter_id'] != null ? _idStr(m['reporter_id']) : null,
    reporterPhone: m['reporter_phone'] as String?,
    citizenRating: m['citizen_rating'] as int?,
    reopenCount: m['reopen_count'] as int? ?? 0,
    departmentDisplayName: departmentDisplayName,
  );
}
