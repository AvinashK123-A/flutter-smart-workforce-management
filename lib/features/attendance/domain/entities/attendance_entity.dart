import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

class AttendanceEntity extends Equatable {
  final String id;
  final String employeeId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final Position? checkInLocation;
  final Position? checkOutLocation;
  final String? checkInNotes;
  final String? checkOutNotes;
  final AttendanceStatus status;
  final bool isLate;
  final bool hasOvertime;
  final bool isGeofenceVerified;
  final String? shiftId;
  final Map<String, dynamic>? metadata;

  const AttendanceEntity({
    required this.id,
    required this.employeeId,
    required this.checkInTime,
    this.checkOutTime,
    this.checkInLocation,
    this.checkOutLocation,
    this.checkInNotes,
    this.checkOutNotes,
    required this.status,
    this.isLate = false,
    this.hasOvertime = false,
    this.isGeofenceVerified = false,
    this.shiftId,
    this.metadata,
  });

  bool get isActive => checkOutTime == null;

  double get hoursWorked {
    if (checkOutTime == null) return 0;
    return checkOutTime!.difference(checkInTime).inMinutes / 60;
  }

  Duration get duration {
    final end = checkOutTime ?? DateTime.now();
    return end.difference(checkInTime);
  }

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  AttendanceEntity copyWith({
    String? id,
    String? employeeId,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    Position? checkInLocation,
    Position? checkOutLocation,
    String? checkInNotes,
    String? checkOutNotes,
    AttendanceStatus? status,
    bool? isLate,
    bool? hasOvertime,
    bool? isGeofenceVerified,
    String? shiftId,
    Map<String, dynamic>? metadata,
  }) {
    return AttendanceEntity(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      checkInLocation: checkInLocation ?? this.checkInLocation,
      checkOutLocation: checkOutLocation ?? this.checkOutLocation,
      checkInNotes: checkInNotes ?? this.checkInNotes,
      checkOutNotes: checkOutNotes ?? this.checkOutNotes,
      status: status ?? this.status,
      isLate: isLate ?? this.isLate,
      hasOvertime: hasOvertime ?? this.hasOvertime,
      isGeofenceVerified: isGeofenceVerified ?? this.isGeofenceVerified,
      shiftId: shiftId ?? this.shiftId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
    id, employeeId, checkInTime, checkOutTime,
    status, isLate, hasOvertime, isGeofenceVerified,
  ];
}

enum AttendanceStatus { present, absent, late, halfDay, holiday, leave, weekend }

class EmployeeEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String department;
  final String designation;
  final String? photoUrl;
  final String managerId;
  final EmployeeRole role;
  final bool isActive;
  final DateTime joinedAt;

  const EmployeeEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.designation,
    this.photoUrl,
    required this.managerId,
    required this.role,
    required this.isActive,
    required this.joinedAt,
  });

  @override
  List<Object?> get props => [id, name, email, department, role, isActive];
}

enum EmployeeRole { admin, manager, employee, contractor }
