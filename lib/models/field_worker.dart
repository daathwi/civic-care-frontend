import 'user_models.dart';

enum FieldWorkerStatus { onDuty, offDuty }

class FieldWorker {
  final String id;
  final String name;
  final String designation;
  final String phone;
  final Department department;
  final String lastActiveWard;
  final double rating;
  final int tasksCompleted;
  final int tasksActive;
  final FieldWorkerStatus status;
  final double? lastActiveLat;
  final double? lastActiveLng;

  const FieldWorker({
    required this.id,
    required this.name,
    required this.designation,
    required this.phone,
    required this.department,
    required this.lastActiveWard,
    required this.rating,
    this.tasksCompleted = 0,
    this.tasksActive = 0,
    this.status = FieldWorkerStatus.onDuty,
    this.lastActiveLat,
    this.lastActiveLng,
  });

  FieldWorker copyWith({
    FieldWorkerStatus? status,
    int? tasksActive,
    int? tasksCompleted,
    double? lastActiveLat,
    double? lastActiveLng,
  }) {
    return FieldWorker(
      id: id,
      name: name,
      designation: designation,
      phone: phone,
      department: department,
      lastActiveWard: lastActiveWard,
      rating: rating,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      tasksActive: tasksActive ?? this.tasksActive,
      status: status ?? this.status,
      lastActiveLat: lastActiveLat ?? this.lastActiveLat,
      lastActiveLng: lastActiveLng ?? this.lastActiveLng,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldWorker &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
