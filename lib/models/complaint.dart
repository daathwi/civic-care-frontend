import 'package:flutter/material.dart';

enum ComplaintStatus {
  completed,
  incompleteAssigned,
  incompleteUnassigned,
  ongoing,
  escalated,
}

enum ComplaintCategory {
  sanitation,
  engineering,
  health,
  horticulture,
  assets,
  other,
}

enum ComplaintPriority { low, medium, high }

const Map<ComplaintCategory, List<String>> subCategories = {
  ComplaintCategory.sanitation: [
    'Overflowing Bin',
    'Carcass (Animal Death)',
    'Industrial Waste',
    'Litter',
  ],
  ComplaintCategory.engineering: [
    'Pothole',
    'Deep Cracks',
    'Missing Manhole',
    'Waterlogging',
    'Broken public infra',
    'Live wire',
    'Broken pipes',
    'Non-Functional Streetlight',
  ],
  ComplaintCategory.health: [
    'Stagnant Water (Dengue risk)',
    'Stray Animal Aggression',
  ],
  ComplaintCategory.horticulture: [
    'Fallen trees',
    'Overgrown grass',
    'Dry plants',
  ],
  ComplaintCategory.assets: [
    'Dirty community centers',
    'Non-functional cremation furnaces',
    'Public Toilets',
  ],
  ComplaintCategory.other: ['Other'],
};

extension ComplaintCategoryExt on ComplaintCategory {
  String get label {
    switch (this) {
      case ComplaintCategory.sanitation:
        return 'Sanitation & Waste';
      case ComplaintCategory.engineering:
        return 'Engineering';
      case ComplaintCategory.health:
        return 'Public Health';
      case ComplaintCategory.horticulture:
        return 'Horticulture';
      case ComplaintCategory.assets:
        return 'Community Assets';
      case ComplaintCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ComplaintCategory.sanitation:
        return Icons.delete_outline_rounded;
      case ComplaintCategory.engineering:
        return Icons.construction_rounded;
      case ComplaintCategory.health:
        return Icons.health_and_safety_rounded;
      case ComplaintCategory.horticulture:
        return Icons.nature_rounded;
      case ComplaintCategory.assets:
        return Icons.foundation_rounded;
      case ComplaintCategory.other:
        return Icons.more_horiz_rounded;
    }
  }
}

extension ComplaintStatusExt on ComplaintStatus {
  String get label {
    switch (this) {
      case ComplaintStatus.completed:
        return 'Resolved';
      case ComplaintStatus.incompleteAssigned:
        return 'Assigned';
      case ComplaintStatus.incompleteUnassigned:
        return 'Pending';
      case ComplaintStatus.ongoing:
        return 'IN PROGRESS';
      case ComplaintStatus.escalated:
        return 'ESCALATED';
    }
  }

  int get colorValue {
    switch (this) {
      case ComplaintStatus.escalated:
        return 0xFFFF0000; // Red
      default:
        return 0xFF008080; // Teal Green
    }
  }

  IconData get icon {
    switch (this) {
      case ComplaintStatus.completed:
        return Icons.check_circle_outline_rounded;
      case ComplaintStatus.incompleteAssigned:
        return Icons.assignment_ind_rounded;
      case ComplaintStatus.incompleteUnassigned:
        return Icons.pending_actions_rounded;
      case ComplaintStatus.ongoing:
        return Icons.engineering_rounded;
      case ComplaintStatus.escalated:
        return Icons.warning_rounded;
    }
  }
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.timestamp,
  });
}

class ComplaintEvent {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;

  ComplaintEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    this.icon = Icons.info_outline,
  });
}

class Complaint {
  final String id;
  final String title;
  final String description;
  final String imagePath;
  final double latitude;
  final double longitude;
  final String address;
  final ComplaintStatus status;
  final ComplaintCategory category;
  final String subCategory;
  final ComplaintPriority priority;
  final DateTime date;
  final String ward;
  final String userName;
  final int upvotes;
  final int downvotes;
  final List<Comment> comments;
  final String? assignedTo;
  final String? assignedToId;
  final String? workerContact;
  final String? assignedByName;
  final String? assignedByPhone;
  final DateTime? assignedAt;
  final String? resolutionImagePath;
  final String? audioPath;
  final bool isSensitive;
  final List<ComplaintEvent> events;
  final String? reporterId;
  final String? reporterPhone;
  final int? citizenRating;
  final int reopenCount;

  /// Department name resolved from API (category_dept_id). Shown as first tag when set.
  final String? departmentDisplayName;

  Complaint({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    this.address = '',
    required this.status,
    this.category = ComplaintCategory.other,
    this.subCategory = 'Other',
    this.priority = ComplaintPriority.medium,
    required this.date,
    required this.ward,
    required this.userName,
    this.upvotes = 0,
    this.downvotes = 0,
    List<Comment>? comments,
    this.assignedTo,
    this.assignedToId,
    this.workerContact,
    this.assignedByName,
    this.assignedByPhone,
    this.assignedAt,
    this.resolutionImagePath,
    this.audioPath,
    this.isSensitive = false,
    List<ComplaintEvent>? events,
    this.reporterId,
    this.reporterPhone,
    this.citizenRating,
    this.reopenCount = 0,
    this.departmentDisplayName,
  }) : events = events ?? const [],
       comments = comments ?? const [];

  Complaint copyWith({
    String? id,
    String? title,
    String? description,
    String? imagePath,
    double? latitude,
    double? longitude,
    String? address,
    ComplaintStatus? status,
    ComplaintCategory? category,
    String? subCategory,
    ComplaintPriority? priority,
    DateTime? date,
    String? ward,
    String? userName,
    int? upvotes,
    int? downvotes,
    List<Comment>? comments,
    String? assignedTo,
    String? assignedToId,
    String? workerContact,
    String? assignedByName,
    String? assignedByPhone,
    DateTime? assignedAt,
    String? resolutionImagePath,
    String? audioPath,
    bool? isSensitive,
    List<ComplaintEvent>? events,
    String? reporterId,
    String? reporterPhone,
    int? citizenRating,
    int? reopenCount,
    String? departmentDisplayName,
  }) {
    return Complaint(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      status: status ?? this.status,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      priority: priority ?? this.priority,
      date: date ?? this.date,
      ward: ward ?? this.ward,
      userName: userName ?? this.userName,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      comments: comments ?? this.comments,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToId: assignedToId ?? this.assignedToId,
      workerContact: workerContact ?? this.workerContact,
      assignedByName: assignedByName ?? this.assignedByName,
      assignedByPhone: assignedByPhone ?? this.assignedByPhone,
      assignedAt: assignedAt ?? this.assignedAt,
      resolutionImagePath: resolutionImagePath ?? this.resolutionImagePath,
      audioPath: audioPath ?? this.audioPath,
      isSensitive: isSensitive ?? this.isSensitive,
      events: events ?? this.events,
      reporterId: reporterId ?? this.reporterId,
      reporterPhone: reporterPhone ?? this.reporterPhone,
      citizenRating: citizenRating ?? this.citizenRating,
      reopenCount: reopenCount ?? this.reopenCount,
      departmentDisplayName:
          departmentDisplayName ?? this.departmentDisplayName,
    );
  }
}
