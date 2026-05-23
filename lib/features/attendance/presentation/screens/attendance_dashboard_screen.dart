import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../notifiers/attendance_notifier.dart';
import '../widgets/attendance_status_card.dart';
import '../widgets/geofence_map_widget.dart';
import '../widgets/attendance_summary_card.dart';
import '../widgets/recent_attendance_list.dart';

class AttendanceDashboardScreen extends ConsumerStatefulWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  ConsumerState<AttendanceDashboardScreen> createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState
    extends ConsumerState<AttendanceDashboardScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceNotifierProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        centerTitle: false,
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.pushNamed(context, '/attendance/history'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => Navigator.pushNamed(context, '/attendance/analytics'),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        child: RefreshIndicator(
          onRefresh: () => ref.read(attendanceNotifierProvider.notifier).loadHistory(),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildTodayStatus(context, state),
                    const SizedBox(height: 16),
                    _buildGeofenceMap(context, state),
                    const SizedBox(height: 16),
                    if (state.summary != null)
                      AttendanceSummaryCard(summary: state.summary!),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final record = state.history[index];
                    return RecentAttendanceList(attendance: record);
                  },
                  childCount: state.history.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayStatus(BuildContext context, AttendanceState state) {
    final now = DateTime.now();
    final formatter = DateFormat('EEEE, MMM d');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatter.format(now),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.isCheckedIn ? 'Currently Working' : 'Not Checked In',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: state.isWithinGeofence
                      ? Colors.green
                      : Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.isWithinGeofence
                          ? Icons.location_on
                          : Icons.location_off,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      state.isWithinGeofence ? 'In Office' : 'Outside',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.currentSession != null) ...[
            const SizedBox(height: 16),
            Text(
              'Working for: ${state.currentSession!.formattedDuration}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: state.isCheckedIn ? 'Check Out' : 'Check In',
                  onPressed: state.isCheckedIn
                      ? () => ref.read(attendanceNotifierProvider.notifier).performCheckOut()
                      : () => ref.read(attendanceNotifierProvider.notifier).performCheckIn(),
                  isLoading: state.isLoading,
                  icon: state.isCheckedIn ? Icons.logout : Icons.login,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceMap(BuildContext context, AttendanceState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GeofenceMapWidget(
        currentPosition: state.currentPosition,
        isWithinGeofence: state.isWithinGeofence,
      ),
    );
  }
}
