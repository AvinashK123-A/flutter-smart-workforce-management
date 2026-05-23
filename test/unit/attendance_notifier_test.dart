import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_smart_workforce_management/core/errors/failures.dart';
import 'package:flutter_smart_workforce_management/core/services/background_location_service.dart';
import 'package:flutter_smart_workforce_management/core/services/geofence_service.dart';
import 'package:flutter_smart_workforce_management/features/attendance/domain/entities/attendance_entity.dart';
import 'package:flutter_smart_workforce_management/features/attendance/domain/usecases/check_in_usecase.dart';
import 'package:flutter_smart_workforce_management/features/attendance/domain/usecases/check_out_usecase.dart';
import 'package:flutter_smart_workforce_management/features/attendance/domain/usecases/get_attendance_history_usecase.dart';
import 'package:flutter_smart_workforce_management/features/attendance/presentation/notifiers/attendance_notifier.dart';

import 'attendance_notifier_test.mocks.dart';

@GenerateMocks([CheckInUseCase, CheckOutUseCase, GetAttendanceHistoryUseCase,
  BackgroundLocationService, GeofenceService])
void main() {
  late MockCheckInUseCase mockCheckIn;
  late MockCheckOutUseCase mockCheckOut;
  late MockGetAttendanceHistoryUseCase mockGetHistory;
  late MockBackgroundLocationService mockLocationService;
  late MockGeofenceService mockGeofenceService;

  final tAttendance = AttendanceEntity(
    id: 'att_001',
    employeeId: 'emp_001',
    checkInTime: DateTime(2024, 1, 1, 9, 0),
    status: AttendanceStatus.present,
    isGeofenceVerified: true,
  );

  setUp(() {
    mockCheckIn = MockCheckInUseCase();
    mockCheckOut = MockCheckOutUseCase();
    mockGetHistory = MockGetAttendanceHistoryUseCase();
    mockLocationService = MockBackgroundLocationService();
    mockGeofenceService = MockGeofenceService();

    when(mockGetHistory(any)).thenAnswer((_) async => Right([tAttendance]));
    when(mockGeofenceService.isWithinWorkplace(any)).thenReturn(false);
  });

  AttendanceNotifier createNotifier() => AttendanceNotifier(
    checkIn: mockCheckIn,
    checkOut: mockCheckOut,
    getHistory: mockGetHistory,
    locationService: mockLocationService,
    geofenceService: mockGeofenceService,
  );

  group('AttendanceNotifier', () {
    test('initial state is not loading and not checked in', () {
      final notifier = createNotifier();
      expect(notifier.state.isLoading, false);
      expect(notifier.state.isCheckedIn, false);
    });

    group('performCheckIn', () {
      test('does not check in when outside geofence', () async {
        final notifier = createNotifier();
        notifier.state = notifier.state.copyWith(isWithinGeofence: false);

        await notifier.performCheckIn();

        expect(notifier.state.isCheckedIn, false);
        expect(notifier.state.errorMessage, isNotNull);
      });

      test('checks in successfully when within geofence', () async {
        when(mockCheckIn(any)).thenAnswer((_) async => Right(tAttendance));

        final notifier = createNotifier();
        notifier.state = notifier.state.copyWith(isWithinGeofence: true);

        await notifier.performCheckIn();

        expect(notifier.state.isCheckedIn, true);
        expect(notifier.state.currentSession, tAttendance);
        verifyNever(mockCheckOut(any));
      });

      test('sets error on check-in failure', () async {
        when(mockCheckIn(any)).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Check-in failed')),
        );

        final notifier = createNotifier();
        notifier.state = notifier.state.copyWith(isWithinGeofence: true);

        await notifier.performCheckIn();

        expect(notifier.state.isCheckedIn, false);
        expect(notifier.state.errorMessage, 'Check-in failed');
      });
    });

    group('performCheckOut', () {
      test('does not check out when not checked in', () async {
        final notifier = createNotifier();
        await notifier.performCheckOut();

        expect(notifier.state.errorMessage, isNotNull);
        verifyNever(mockCheckOut(any));
      });

      test('checks out successfully', () async {
        final checkedOutAttendance = tAttendance.copyWith(
          checkOutTime: DateTime(2024, 1, 1, 18, 0),
          status: AttendanceStatus.present,
        );
        when(mockCheckOut(any)).thenAnswer((_) async => Right(checkedOutAttendance));

        final notifier = createNotifier();
        notifier.state = notifier.state.copyWith(
          isCheckedIn: true,
          currentSession: tAttendance,
        );

        await notifier.performCheckOut();

        expect(notifier.state.isCheckedIn, false);
        expect(notifier.state.currentSession, null);
      });
    });

    group('loadHistory', () {
      test('loads attendance history successfully', () async {
        when(mockGetHistory(any)).thenAnswer((_) async => Right([tAttendance]));

        final notifier = createNotifier();
        await notifier.loadHistory();

        expect(notifier.state.history, [tAttendance]);
        expect(notifier.state.isLoading, false);
      });

      test('sets error on history load failure', () async {
        when(mockGetHistory(any)).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Network error')),
        );

        final notifier = createNotifier();
        await notifier.loadHistory();

        expect(notifier.state.errorMessage, 'Network error');
        expect(notifier.state.isLoading, false);
      });
    });

    test('clearError clears error state', () {
      final notifier = createNotifier();
      notifier.state = notifier.state.copyWith(errorMessage: 'Some error');

      notifier.clearError();

      expect(notifier.state.errorMessage, null);
    });
  });
}
