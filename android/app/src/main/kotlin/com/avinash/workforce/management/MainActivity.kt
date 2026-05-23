package com.avinash.workforce.management

import android.Manifest
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import com.google.android.gms.location.*

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL_LOCATION = "com.avinash.workforce.management/location"
        private const val CHANNEL_GEOFENCE = "com.avinash.workforce.management/geofence"
        private const val CHANNEL_ATTENDANCE = "com.avinash.workforce.management/attendance"
        private const val EVENT_CHANNEL_LOCATION = "com.avinash.workforce.management/location_stream"
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var geofencingClient: GeofencingClient
    private var locationEventSink: EventChannel.EventSink? = null
    private var locationCallback: LocationCallback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        geofencingClient = LocationServices.getGeofencingClient(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        setupLocationChannel(flutterEngine)
        setupGeofenceChannel(flutterEngine)
        setupAttendanceChannel(flutterEngine)
        setupLocationEventChannel(flutterEngine)
    }

    // ==================== LOCATION METHOD CHANNEL ====================

    private fun setupLocationChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_LOCATION
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationTracking" -> {
                    val intervalMs = call.argument<Long>("intervalMs") ?: BuildConfig.LOCATION_UPDATE_INTERVAL_MS
                    val fastestIntervalMs = call.argument<Long>("fastestIntervalMs") ?: BuildConfig.LOCATION_FASTEST_INTERVAL_MS
                    startLocationTracking(intervalMs, fastestIntervalMs, result)
                }
                "stopLocationTracking" -> {
                    stopLocationTracking()
                    result.success(true)
                }
                "getLastKnownLocation" -> getLastKnownLocation(result)
                "isLocationPermissionGranted" -> {
                    val fineGranted = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    val bgGranted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                        ContextCompat.checkSelfPermission(
                            this, Manifest.permission.ACCESS_BACKGROUND_LOCATION
                        ) == PackageManager.PERMISSION_GRANTED
                    } else true
                    result.success(mapOf("fine" to fineGranted, "background" to bgGranted))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startLocationTracking(intervalMs: Long, fastestIntervalMs: Long, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }

        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, intervalMs)
            .setMinUpdateIntervalMillis(fastestIntervalMs)
            .setMaxUpdateDelayMillis(intervalMs * 2)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    locationEventSink?.success(mapOf(
                        "latitude" to location.latitude,
                        "longitude" to location.longitude,
                        "accuracy" to location.accuracy,
                        "altitude" to location.altitude,
                        "speed" to location.speed,
                        "bearing" to location.bearing,
                        "timestamp" to location.time
                    ))
                }
            }
        }

        fusedLocationClient.requestLocationUpdates(
            locationRequest,
            locationCallback!!,
            mainLooper
        )

        // Also start foreground service for background tracking
        val serviceIntent = Intent(this, Class.forName("$packageName.services.LocationTrackingService"))
        serviceIntent.putExtra("intervalMs", intervalMs)
        ContextCompat.startForegroundService(this, serviceIntent)

        result.success(true)
    }

    private fun stopLocationTracking() {
        locationCallback?.let { fusedLocationClient.removeLocationUpdates(it) }
        locationCallback = null
        stopService(Intent(this, Class.forName("$packageName.services.LocationTrackingService")))
    }

    private fun getLastKnownLocation(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Location permission not granted", null)
            return
        }
        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
            if (location != null) {
                result.success(mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy,
                    "timestamp" to location.time
                ))
            } else {
                result.success(null)
            }
        }.addOnFailureListener { e ->
            result.error("LOCATION_ERROR", e.message, null)
        }
    }

    // ==================== GEOFENCE CHANNEL ====================

    private fun setupGeofenceChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_GEOFENCE
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "addGeofence" -> {
                    val id = call.argument<String>("id") ?: run { result.error("INVALID", "id required", null); return@setMethodCallHandler }
                    val lat = call.argument<Double>("latitude") ?: run { result.error("INVALID", "latitude required", null); return@setMethodCallHandler }
                    val lng = call.argument<Double>("longitude") ?: run { result.error("INVALID", "longitude required", null); return@setMethodCallHandler }
                    val radius = call.argument<Double>("radius")?.toFloat() ?: BuildConfig.GEOFENCE_RADIUS_METERS
                    addGeofence(id, lat, lng, radius, result)
                }
                "removeGeofence" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    removeGeofences(ids, result)
                }
                "getActiveGeofences" -> {
                    result.success(listOf<String>()) // Return registered geofence IDs
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getGeofencePendingIntent(): PendingIntent {
        val intent = Intent(this, Class.forName("$packageName.receivers.GeofenceBroadcastReceiver"))
        intent.action = "com.avinash.workforce.GEOFENCE_EVENT"
        return PendingIntent.getBroadcast(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
    }

    private fun addGeofence(id: String, lat: Double, lng: Double, radius: Float, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Location permission required for geofencing", null)
            return
        }

        val geofence = Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(lat, lng, radius)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(
                Geofence.GEOFENCE_TRANSITION_ENTER or
                Geofence.GEOFENCE_TRANSITION_EXIT or
                Geofence.GEOFENCE_TRANSITION_DWELL
            )
            .setLoiteringDelay(60000) // 1 minute dwell time
            .build()

        val geofencingRequest = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofence(geofence)
            .build()

        geofencingClient.addGeofences(geofencingRequest, getGeofencePendingIntent())
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { e -> result.error("GEOFENCE_ERROR", e.message, null) }
    }

    private fun removeGeofences(ids: List<String>, result: MethodChannel.Result) {
        geofencingClient.removeGeofences(ids)
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { e -> result.error("GEOFENCE_ERROR", e.message, null) }
    }

    // ==================== ATTENDANCE CHANNEL ====================

    private fun setupAttendanceChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_ATTENDANCE
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAttendanceSync" -> {
                    // Schedule WorkManager periodic sync
                    val workManager = androidx.work.WorkManager.getInstance(applicationContext)
                    val syncRequest = androidx.work.PeriodicWorkRequestBuilder<androidx.work.Worker>(
                        15, java.util.concurrent.TimeUnit.MINUTES
                    ).build()
                    workManager.enqueueUniquePeriodicWork(
                        "attendance_sync",
                        androidx.work.ExistingPeriodicWorkPolicy.KEEP,
                        syncRequest
                    )
                    result.success(true)
                }
                "stopAttendanceSync" -> {
                    androidx.work.WorkManager.getInstance(applicationContext)
                        .cancelUniqueWork("attendance_sync")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ==================== LOCATION EVENT CHANNEL ====================

    private fun setupLocationEventChannel(flutterEngine: FlutterEngine) {
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL_LOCATION
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                locationEventSink = events
            }
            override fun onCancel(arguments: Any?) {
                locationEventSink = null
            }
        })
    }
}
