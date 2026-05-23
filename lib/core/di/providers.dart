import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

import '../network/dio_client.dart';
import '../router/app_router.dart';
import '../storage/local_storage.dart';
import '../services/background_location_service.dart';
import '../services/geofence_service.dart';
import '../../features/attendance/data/datasources/attendance_remote_datasource.dart';
import '../../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/attendance/domain/usecases/check_in_usecase.dart';
import '../../features/attendance/domain/usecases/check_out_usecase.dart';
import '../../features/attendance/domain/usecases/get_attendance_history_usecase.dart';
import '../../features/attendance/presentation/notifiers/attendance_notifier.dart';
import '../../features/location/data/datasources/location_datasource.dart';
import '../../features/location/data/repositories/location_repository_impl.dart';
import '../../features/location/domain/repositories/location_repository.dart';
import '../../features/location/presentation/notifiers/location_notifier.dart';
import '../../features/employees/data/datasources/employee_remote_datasource.dart';
import '../../features/employees/data/repositories/employee_repository_impl.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/employees/presentation/notifiers/employee_notifier.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/notifiers/auth_notifier.dart';

// Firebase
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

// Theme
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// Router
final appRouterProvider = Provider<AppRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider.notifier);
  return AppRouter(authNotifier: authNotifier);
});

// Network
final dioClientProvider = Provider<DioClient>((ref) => DioClient());
final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);

// Storage
final localStorageProvider = Provider<LocalStorage>((ref) => LocalStorageImpl());

// Services
final backgroundLocationServiceProvider = Provider<BackgroundLocationService>(
  (ref) => BackgroundLocationService(),
);
final geofenceServiceProvider = Provider<GeofenceService>(
  (ref) => GeofenceService(),
);

// Auth
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl(
  firebaseAuth: ref.watch(firebaseAuthProvider),
));
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(
  repository: ref.watch(authRepositoryProvider),
));

// Attendance
final attendanceRemoteDataSourceProvider = Provider<AttendanceRemoteDataSource>(
  (ref) => AttendanceRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
    dio: ref.watch(dioProvider),
  ),
);
final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepositoryImpl(
    remoteDataSource: ref.watch(attendanceRemoteDataSourceProvider),
    localStorage: ref.watch(localStorageProvider),
  ),
);
final checkInUseCaseProvider = Provider((ref) => CheckInUseCase(ref.watch(attendanceRepositoryProvider)));
final checkOutUseCaseProvider = Provider((ref) => CheckOutUseCase(ref.watch(attendanceRepositoryProvider)));
final getAttendanceHistoryUseCaseProvider = Provider((ref) => GetAttendanceHistoryUseCase(ref.watch(attendanceRepositoryProvider)));

final attendanceNotifierProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>(
  (ref) => AttendanceNotifier(
    checkIn: ref.watch(checkInUseCaseProvider),
    checkOut: ref.watch(checkOutUseCaseProvider),
    getHistory: ref.watch(getAttendanceHistoryUseCaseProvider),
    locationService: ref.watch(backgroundLocationServiceProvider),
    geofenceService: ref.watch(geofenceServiceProvider),
  ),
);

// Location
final locationDataSourceProvider = Provider<LocationDataSource>(
  (ref) => LocationDataSourceImpl(),
);
final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepositoryImpl(
    dataSource: ref.watch(locationDataSourceProvider),
    firestore: ref.watch(firestoreProvider),
  ),
);
final locationNotifierProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(
    repository: ref.watch(locationRepositoryProvider),
  ),
);

// Employees
final employeeRemoteDataSourceProvider = Provider<EmployeeRemoteDataSource>(
  (ref) => EmployeeRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  ),
);
final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => EmployeeRepositoryImpl(
    remoteDataSource: ref.watch(employeeRemoteDataSourceProvider),
  ),
);
final employeeNotifierProvider = StateNotifierProvider<EmployeeNotifier, EmployeeState>(
  (ref) => EmployeeNotifier(
    repository: ref.watch(employeeRepositoryProvider),
  ),
);
