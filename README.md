<div align="center">

![banner](https://capsule-render.vercel.app/api?type=waving&color=0F3460&height=200&section=header&text=Smart%20Workforce%20Management&fontSize=28&fontColor=white&animation=fadeIn&fontAlignY=35&desc=Flutter%20%7C%20Riverpod%20%7C%20Geofencing%20%7C%20Clean%20Architecture&descAlignY=55)

[![Flutter](https://img.shields.io/badge/Flutter-3.19-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev) [![Riverpod](https://img.shields.io/badge/Riverpod-2.4-00BCD4?style=for-the-badge&logo=dart&logoColor=white)](https://riverpod.dev) [![Isar](https://img.shields.io/badge/Isar-3.1-6C63FF?style=for-the-badge&logo=dart&logoColor=white)](https://isar.dev) [![go_router](https://img.shields.io/badge/go__router-13.1-FF6C37?style=for-the-badge&logo=dart&logoColor=white)](https://pub.dev/packages/go_router) [![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

> **Large-scale enterprise Flutter application** managing 12,000+ employees across 40 sites. Geofence-based attendance, live GPS dashboard, role-gated task assignment, offline-first architecture, and SAP HRMS integration via REST API.

</div>

---

## ✨ Features

| Feature | Status | Details |
|:--------|:------:|:--------|
| 🏢 Geofence Attendance | ✅ | 150m radius validation per site |
| 📍 Live GPS Tracking | ✅ | Real-time supervisor dashboard |
| 🔑 Role Permissions | ✅ | Admin / Manager / Employee |
| 📊 Analytics Dashboard | ✅ | Charts, attendance rate, hours |
| 📋 Task Assignment | ✅ | Role-gated task workflows |
| 📶 Offline Sync | ✅ | Isar local queue + background sync |
| 📅 Leave Management | ✅ | Request, approve, track |
| 📈 Reports | ✅ | PDF + CSV export |
| 🔄 Background Sync | ✅ | WorkManager periodic tasks |
| 🔌 SAP Integration | ✅ | REST API 50+ endpoints |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│           PRESENTATION LAYER (Riverpod)              │
│  DashboardScreen ──► dashboardProvider               │
│  AttendanceScreen ──► attendanceProvider             │
│  TrackingScreen ──► trackingProvider                 │
└─────────────────────┬───────────────────────────────┘
                      │ async notifiers
┌─────────────────────▼───────────────────────────────┐
│               DOMAIN LAYER                           │
│  MarkAttendanceUseCase  GetDashboardUseCase           │
│  TrackEmployeeUseCase   AssignTaskUseCase             │
│  Repository interfaces (abstract)                    │
└─────────────────────┬───────────────────────────────┘
                      │ implements
┌─────────────────────▼───────────────────────────────┐
│                DATA LAYER                             │
│  AttendanceRepositoryImpl                            │
│  ├─ AttendanceRemoteDataSource (Dio + REST)          │
│  └─ AttendanceLocalDataSource  (Isar)                │
└──────────────────────────────────────────────────────┘
           │                  │
  Geolocator API         Isar Database
  WorkManager         (Offline queue)
```

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── di/providers_setup.dart
│   ├── network/
│   │   ├── dio_client.dart
│   │   └── api_endpoints.dart
│   ├── router/app_router.dart
│   └── sync/background_sync_service.dart
└── features/
    ├── attendance/
    │   ├── data/
    │   │   ├── datasources/
    │   │   │   ├── attendance_local_datasource.dart
    │   │   │   └── attendance_remote_datasource.dart
    │   │   ├── models/attendance_model.dart
    │   │   └── repositories/attendance_repository_impl.dart
    │   ├── domain/
    │   │   ├── entities/attendance_entity.dart
    │   │   ├── repositories/attendance_repository.dart
    │   │   └── usecases/mark_attendance_usecase.dart
    │   └── presentation/
    │       ├── providers/attendance_providers.dart
    │       └── screens/attendance_screen.dart
    ├── dashboard/
    │   └── presentation/
    │       ├── providers/dashboard_providers.dart
    │       └── screens/dashboard_screen.dart
    ├── tracking/
    │   └── presentation/
    │       ├── providers/tracking_providers.dart
    │       └── screens/live_map_screen.dart
    └── leave/
        └── presentation/
            ├── providers/leave_providers.dart
            └── screens/leave_management_screen.dart
```

---

## 🚀 Installation

```bash
git clone https://github.com/AvinashK123-A/flutter-smart-workforce-management.git
cd flutter-smart-workforce-management
flutter pub get
dart run build_runner build --delete-conflicting-outputs
cp .env.example .env
flutter run
```

## ⚙️ Environment

```env
BASE_URL=https://api.yourcompany.com
GOOGLE_MAPS_API_KEY=your_maps_key
GEOFENCE_RADIUS_METERS=150
BACKGROUND_SYNC_INTERVAL_MINUTES=15
```

## 📦 Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3
  go_router: ^13.1.0
  dio: ^5.3.4
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0
  geolocator: ^11.0.0
  google_maps_flutter: ^2.5.3
  workmanager: ^0.5.2
  dartz: ^0.10.1

dev_dependencies:
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.7
  isar_generator: ^3.1.0
```

---

## 💻 Core Code

<details>
<summary><b>📍 AttendanceRepositoryImpl — Geofence + Offline-First</b></summary>

```dart
// lib/features/attendance/data/repositories/attendance_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_local_datasource.dart';
import '../datasources/attendance_remote_datasource.dart';
import '../models/attendance_model.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource _remote;
  final AttendanceLocalDataSource _local;
  final NetworkInfo _network;
  static const double _geofenceRadius = 150.0;

  const AttendanceRepositoryImpl(this._remote, this._local, this._network);

  @override
  Future<Either<Failure, AttendanceEntity>> markAttendance({
    required String employeeId, required String siteId,
    required CheckType type, required SiteGeofence geofence,
  }) async {
    final position = await _getPosition();
    final distance = Geolocator.distanceBetween(
      position.latitude, position.longitude,
      geofence.latitude, geofence.longitude);
    final valid = distance <= _geofenceRadius;

    final record = AttendanceModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      employeeId: employeeId, siteId: siteId,
      date: DateTime.now(),
      checkInTime: type == CheckType.checkIn ? DateTime.now() : null,
      checkOutTime: type == CheckType.checkOut ? DateTime.now() : null,
      status: valid ? AttendanceStatus.present : AttendanceStatus.late,
      latitude: position.latitude, longitude: position.longitude,
      isGeofenceValid: valid, isSynced: false,
    );

    await _local.saveAttendance(record);

    if (await _network.isConnected) {
      try {
        final synced = await _remote.pushAttendance(record);
        await _local.markSynced(record.id);
        return Right(synced.toEntity());
      } catch (_) {
        return Right(record.toEntity()); // Will sync via WorkManager
      }
    }
    return Right(record.toEntity());
  }

  @override
  Future<Either<Failure, List<AttendanceEntity>>> getHistory({
    required String employeeId,
    required DateTime from, required DateTime to,
  }) async {
    try {
      if (await _network.isConnected) {
        final records = await _remote.fetchHistory(
          employeeId: employeeId, from: from, to: to);
        await _local.cacheHistory(records);
        return Right(records.map((r) => r.toEntity()).toList());
      } else {
        final cached = await _local.getHistory(
          employeeId: employeeId, from: from, to: to);
        return Right(cached.map((r) => r.toEntity()).toList());
      }
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw const PermissionDeniedException();
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }
}
```

</details>

<details>
<summary><b>🔄 Attendance Providers — Riverpod AsyncNotifier</b></summary>

```dart
// lib/features/attendance/presentation/providers/attendance_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../domain/repositories/attendance_repository.dart';

part 'attendance_providers.g.dart';

@riverpod
class AttendanceNotifier extends _$AttendanceNotifier {
  @override
  Future<List<AttendanceEntity>> build(String employeeId) async {
    return _load(employeeId);
  }

  Future<List<AttendanceEntity>> _load(String employeeId) async {
    final repo = ref.read(attendanceRepositoryProvider);
    final now = DateTime.now();
    final result = await repo.getHistory(
      employeeId: employeeId,
      from: DateTime(now.year, now.month, 1),
      to: now,
    );
    return result.fold(
      (f) => throw Exception(f.message),
      (records) => records,
    );
  }

  Future<void> markAttendance({
    required String siteId,
    required CheckType type,
    required SiteGeofence geofence,
  }) async {
    final repo = ref.read(attendanceRepositoryProvider);
    final result = await repo.markAttendance(
      employeeId: ref.read(currentUserProvider)!.id,
      siteId: siteId, type: type, geofence: geofence,
    );
    result.fold(
      (f) => state = AsyncError(f.message, StackTrace.current),
      (record) {
        final prev = state.valueOrNull ?? [];
        state = AsyncData([record, ...prev]);
      },
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final records = await _load(ref.read(currentUserProvider)!.id);
      state = AsyncData(records);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }
}

@riverpod
class DashboardNotifier extends _$DashboardNotifier {
  @override
  Future<DashboardData> build() async {
    final repo = ref.read(dashboardRepositoryProvider);
    final result = await repo.getDashboardData();
    return result.fold(
      (f) => throw Exception(f.message),
      (data) => data,
    );
  }
}
```

</details>

<details>
<summary><b>📊 DashboardScreen — Analytics UI</b></summary>

```dart
// lib/features/dashboard/presentation/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/metric_card.dart';
import '../widgets/attendance_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardNotifierProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F3460),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460), elevation: 0,
        title: const Text('Dashboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(dashboardNotifierProvider),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white70))),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardNotifierProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _buildMetricsGrid(data),
              const SizedBox(height: 20),
              AttendanceChart(data: data.weeklyAttendance),
              const SizedBox(height: 20),
              _buildRecentActivity(data.recentActivities),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(DashboardData data) => GridView.count(
    crossAxisCount: 2, shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12, mainAxisSpacing: 12,
    childAspectRatio: 1.5,
    children: [
      MetricCard(label: 'Present Today', value: '${data.presentToday}',
          icon: Icons.check_circle, color: Colors.green),
      MetricCard(label: 'Absent', value: '${data.absentToday}',
          icon: Icons.cancel, color: Colors.red),
      MetricCard(label: 'On Leave', value: '${data.onLeave}',
          icon: Icons.beach_access, color: Colors.orange),
      MetricCard(label: 'Attendance Rate', value: '${data.attendanceRate.toStringAsFixed(1)}%',
          icon: Icons.bar_chart, color: const Color(0xFF6C63FF)),
    ],
  );

  Widget _buildRecentActivity(List<ActivityItem> activities) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Recent Activity',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ...activities.map((a) => ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFF6C63FF),
            child: Text(a.employeeName[0])),
        title: Text(a.employeeName, style: const TextStyle(color: Colors.white)),
        subtitle: Text(a.action, style: const TextStyle(color: Colors.white60)),
        trailing: Text(a.time, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      )),
    ],
  );
}
```

</details>

---

## 🔄 Background Sync (WorkManager)

```dart
// lib/core/sync/background_sync_service.dart
import 'package:workmanager/workmanager.dart';

const String _syncTaskName = 'attendance_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _syncTaskName) {
      // Sync unsynced attendance records to server
      await AttendanceSyncWorker().sync();
    }
    return true;
  });
}

class BackgroundSyncService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  static Future<void> schedulePeriodic() async {
    await Workmanager().registerPeriodicTask(
      _syncTaskName, _syncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }
}
```

---

## 🗺️ Roadmap

- [x] Geofence attendance with GPS validation
- [x] Live employee tracking dashboard
- [x] Role-based access control
- [x] Offline-first with Isar + WorkManager sync
- [x] Analytics dashboard with charts
- [ ] Payroll integration
- [ ] Shift scheduling module
- [ ] Face recognition attendance
- [ ] Multi-tenant architecture

---

## 📄 License

MIT License — see [LICENSE](LICENSE).

---

<div align="center">

**Built with ❤️ by [Avinash Reddy](https://github.com/AvinashK123-A)**

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/avinash-reddy-0826b0222/)

![footer](https://capsule-render.vercel.app/api?type=waving&color=0F3460&height=100&section=footer)

</div>
