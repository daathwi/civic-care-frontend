import 'package:flutter/material.dart';
import '../core/app_theme.dart';

enum UserRole { citizen, fieldManager, fieldAssistant, admin }

class Department {
  final String id;
  final String name;
  final String shortCode;
  final Color primaryColor; // Restored for Hot Reload support
  final IconData icon;
  final String managerTitle; // e.g. "Executive Engineer"
  final String managerTitleShort; // e.g. "EE"
  final String assistantTitle; // e.g. "Junior Engineer"
  final String jurisdictionLabel; // e.g. "Cluster" or "Ward"

  const Department({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.primaryColor,
    required this.icon,
    required this.managerTitle,
    required this.managerTitleShort,
    required this.assistantTitle,
    required this.jurisdictionLabel,
  });

  // ── Singleton department instances ──────────────────────────────────────────

  static const Department sanitation = Department(
    id: 'sanitation',
    name: 'Sanitation & Waste',
    shortCode: 'SW',
    primaryColor: AppTheme.primary,
    icon: Icons.delete_outline_rounded,
    managerTitle: 'Sanitary Inspector',
    managerTitleShort: 'SI',
    assistantTitle: 'Field Worker',
    jurisdictionLabel: 'Ward',
  );

  static const Department engineering = Department(
    id: 'engineering',
    name: 'Engineering',
    shortCode: 'ENG',
    primaryColor: AppTheme.primary,
    icon: Icons.construction_rounded,
    managerTitle: 'Assistant Engineer',
    managerTitleShort: 'AE',
    assistantTitle: 'Junior Engineer',
    jurisdictionLabel: 'Cluster of wards',
  );

  static const Department publicHealth = Department(
    id: 'health',
    name: 'Public Health',
    shortCode: 'PH',
    primaryColor: AppTheme.primary,
    icon: Icons.health_and_safety_rounded,
    managerTitle: 'Public Health Inspector',
    managerTitleShort: 'PHI',
    assistantTitle: 'Health Worker',
    jurisdictionLabel: 'Ward',
  );

  static const Department horticulture = Department(
    id: 'horticulture',
    name: 'Horticulture',
    shortCode: 'HRT',
    primaryColor: AppTheme.primary,
    icon: Icons.nature_rounded,
    managerTitle: 'Section Officer',
    managerTitleShort: 'S.O.',
    assistantTitle: 'Gardener',
    jurisdictionLabel: 'Ward',
  );

  static const List<Department> all = [
    sanitation,
    engineering,
    publicHealth,
    horticulture,
  ];
}

class UserProfile {
  final String id;
  final String name;
  final String? email;
  final String ward;
  final String phone;
  final String? address;
  final UserRole role;
  final Department? department;

  /// Department UUID from API (worker_profile.department_id). Used for list API filters.
  final String? departmentId;

  /// Ward UUID from API (for citizens or staff). Used for list API filters.
  final String? wardId;

  /// Zone UUID from API (for citizens). Used for list API filters.
  final String? zoneId;

  /// Worker stats (only if isStaff)
  final int tasksCompleted;
  final int tasksActive;

  const UserProfile({
    required this.id,
    required this.name,
    this.email,
    required this.ward,
    required this.phone,
    this.address,
    required this.role,
    this.department,
    this.departmentId,
    this.wardId,
    this.zoneId,
    this.tasksCompleted = 0,
    this.tasksActive = 0,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? ward,
    String? phone,
    String? address,
    UserRole? role,
    Department? department,
    String? departmentId,
    String? wardId,
    String? zoneId,
    int? tasksCompleted,
    int? tasksActive,
    bool clearDepartment = false,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      ward: ward ?? this.ward,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role ?? this.role,
      department: clearDepartment ? null : (department ?? this.department),
      departmentId: clearDepartment
          ? null
          : (departmentId ?? this.departmentId),
      wardId: wardId ?? this.wardId,
      zoneId: zoneId ?? this.zoneId,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      tasksActive: tasksActive ?? this.tasksActive,
    );
  }

  bool get isStaff =>
      role == UserRole.fieldManager ||
      role == UserRole.fieldAssistant ||
      role == UserRole.admin;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'ward': ward,
      'phone': phone,
      'address': address,
      'role': role.toString().split('.').last,
      'department_id': departmentId,
      'ward_id': wardId,
      'zone_id': zoneId,
      'tasks_completed': tasksCompleted,
      'tasks_active': tasksActive,
      'department_name': department?.name,
    };
  }
}
