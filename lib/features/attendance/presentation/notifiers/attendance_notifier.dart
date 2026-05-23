import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/attendance_entity.dart';
import '../../domain/usecases/check_in_usecase.dart';
import '../../domain/usecases/check_out_usecase.dart';
import '../../domain/usecases/get_attendance_history_usecase.dart';
import '../../../../core/services/background_location_service.dart';
import '../../../../core/services/geofence_service.dart';

class AttendanceState extends Equatable {
  final bool isLoading;
  final bool isCheckedIn;
  final AttendanceEntity? currentSession;
  final List<AttendanceEntity> history;
  final String? errorMessage;
  final bool isWithinGeofence;
  final Position? currentPosition;
  final AttendanceSummary? summary;

  const AttendanceState({
    this.isLoading = false,
    this.isCheckedIn = false,
    this.currentSession,
    this.history = const [],
    this.errorMessage,
    this.isWithinGeofence = false,
    this.currentPosition,
    this.summary,
  });

  AttendanceState copyWith({
    bool? isLoading,
    bool? isCheckedIn,
    AttendanceEntity? currentSession,
    List<AttendanceEntity>? history,
    String? errorMessage,
    bool? isWithinGeofence,
    Position? currentPosition,
    AttendanceSummary? summary,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      currentSession: clearSession ? null : (currentSession ?? this.currentSession),
      history: history ?? this.history,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isWithinGeofence: isWithinGeofence ?? this.isWithinGeofence,
      currentPosition: currentPosition ?? this.currentPosition,
      summary: summary ?? this.summary,
    );
  }

  @override
  List<Object?> get props => [
    isLoading, isCheckedIn, currentSession, history,
    errorMessage, isWithinGeofence, currentPosition, summary,
  ];
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final CheckInUseCase checkIn;
  final CheckOutUseCase checkOut;
  final GetAttendanceHistoryUseCase getHistory;
  final BackgroundLocationService locationService;
  final GeofenceService geofenceService;

  AttendanceNotifier({
    required this.checkIn,
    required this.checkOut,
    required this.getHistory,
    required this.locationService,
    required this.geofenceService,
  }) : super(const AttendanceState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkCurrentSession();
    await _startLocationTracking();
    await loadHistory();
  }

  Future<void> _checkCurrentSession() async {
    state = state.copyWith(isLoading: true);
    // Check if there's an active check-in session
    state = state.copyWith(isLoading: false);
  }

  Future<void> _startLocationTracking() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        state = state.copyWith(currentPosition: position);
        _checkGeofenceStatus(position);
      });
    } catch (e) {
      state = state.copyWith(errorMessage: 'Location tracking failed: $e');
    }
  }

  void _checkGeofenceStatus(Position position) {
    final isWithin = geofenceService.isWithinWorkplace(position);
    state = state.copyWith(isWithinGeofence: isWithin);
  }

  Future<void> performCheckIn({String? notes}) async {
    if (!state.isWithinGeofence) {
      state = state.copyWith(errorMessage: 'You must be within office premises to check in');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final result = await checkIn(CheckInParams(
      location: state.currentPosition,
      notes: notes,
    ));

    result.fold(
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
      (attendance) => state = state.copyWith(
        isLoading: false,
        isCheckedIn: true,
        currentSession: attendance,
      ),
    );
  }

  Future<void> performCheckOut({String? notes}) async {
    if (!state.isCheckedIn || state.currentSession == null) {
      state = state.copyWith(errorMessage: 'No active check-in session found');
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final result = await checkOut(CheckOutParams(
      attendanceId: state.currentSession!.id,
      location: state.currentPosition,
      notes: notes,
    ));

    result.fold(
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
      (attendance) => state = state.copyWith(
        isLoading: false,
        isCheckedIn: false,
        clearSession: true,
        history: [attendance, ...state.history],
      ),
    );
  }

  Future<void> loadHistory({int page = 1, DateTime? from, DateTime? to}) async {
    state = state.copyWith(isLoading: true);
    final result = await getHistory(GetAttendanceHistoryParams(
      page: page,
      limit: 30,
      from: from ?? DateTime.now().subtract(const Duration(days: 30)),
      to: to ?? DateTime.now(),
    ));

    result.fold(
      (failure) => state = state.copyWith(isLoading: false, errorMessage: failure.message),
      (items) {
        final summary = _calculateSummary(items);
        state = state.copyWith(
          isLoading: false,
          history: items,
          summary: summary,
        );
      },
    );
  }

  AttendanceSummary _calculateSummary(List<AttendanceEntity> records) {
    final totalDays = records.length;
    final presentDays = records.where((r) => r.checkOutTime != null).length;
    final totalHours = records.fold<double>(0, (sum, r) => sum + r.hoursWorked);
    final avgHours = totalDays > 0 ? totalHours / totalDays : 0.0;
    final lateDays = records.where((r) => r.isLate).length;
    final overtimeDays = records.where((r) => r.hasOvertime).length;

    return AttendanceSummary(
      totalDays: totalDays,
      presentDays: presentDays,
      totalHoursWorked: totalHours,
      averageHoursPerDay: avgHours,
      lateDays: lateDays,
      overtimeDays: overtimeDays,
    );
  }

  void clearError() => state = state.copyWith(clearError: true);
}

class AttendanceSummary extends Equatable {
  final int totalDays;
  final int presentDays;
  final double totalHoursWorked;
  final double averageHoursPerDay;
  final int lateDays;
  final int overtimeDays;

  const AttendanceSummary({
    required this.totalDays,
    required this.presentDays,
    required this.totalHoursWorked,
    required this.averageHoursPerDay,
    required this.lateDays,
    required this.overtimeDays,
  });

  double get attendancePercentage =>
      totalDays > 0 ? (presentDays / totalDays) * 100 : 0;

  @override
  List<Object?> get props => [totalDays, presentDays, totalHoursWorked, averageHoursPerDay, lateDays, overtimeDays];
}
