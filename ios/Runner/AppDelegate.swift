import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import CoreLocation
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {

    private let kLocationChannel = "com.avinash.workforce.management/location"
    private let kGeofenceChannel = "com.avinash.workforce.management/geofence"
    private let kDeepLinkChannel = "com.avinash.workforce.management/deeplink"
    private let kLocationEventChannel = "com.avinash.workforce.management/location_stream"

    private var locationManager: CLLocationManager!
    private var locationEventSink: FlutterEventSink?
    private var deepLinkChannel: FlutterMethodChannel?
    private var geofenceChannel: FlutterMethodChannel?
    private var pendingDeepLink: String?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()

        // Initialize Google Maps
        let mapsKey = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String ?? ""
        GMSServices.provideAPIKey(mapsKey)

        // Setup location manager
        setupLocationManager()

        if let controller = window?.rootViewController as? FlutterViewController {
            setupLocationChannel(controller: controller)
            setupGeofenceChannel(controller: controller)
            setupDeepLinkChannel(controller: controller)
            setupLocationEventChannel(controller: controller)
        }

        GeneratedPluginRegistrant.register(with: self)
        configurePushNotifications(application: application)
        Messaging.messaging().delegate = self

        // Handle launch from geofence region notification
        if let notification = launchOptions?[.localNotification] {
            NSLog("[AppDelegate] Launched from geofence notification: %@", String(describing: notification))
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Location Manager Setup

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // meters
        locationManager.pausesLocationUpdatesAutomatically = false
        // CRITICAL: Required for background location
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationEventSink?([
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "speed": location.speed,
            "bearing": location.course,
            "timestamp": location.timestamp.timeIntervalSince1970 * 1000
        ])
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("[AppDelegate] Location error: %@", error.localizedDescription)
        locationEventSink?(FlutterError(
            code: "LOCATION_ERROR",
            message: error.localizedDescription,
            details: nil
        ))
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        NSLog("[AppDelegate] Location auth status: %d", status.rawValue)
    }

    // Geofence events
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        NSLog("[AppDelegate] Entered geofence: %@", region.identifier)
        geofenceChannel?.invokeMethod("onGeofenceEnter", arguments: ["regionId": region.identifier])
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        NSLog("[AppDelegate] Exited geofence: %@", region.identifier)
        geofenceChannel?.invokeMethod("onGeofenceExit", arguments: ["regionId": region.identifier])
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        NSLog("[AppDelegate] Geofence monitoring failed: %@", error.localizedDescription)
    }

    // MARK: - Location Channel

    private func setupLocationChannel(controller: FlutterViewController) {
        FlutterMethodChannel(
            name: kLocationChannel,
            binaryMessenger: controller.binaryMessenger
        ).setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "startLocationTracking":
                self.locationManager.startUpdatingLocation()
                result(true)
            case "stopLocationTracking":
                self.locationManager.stopUpdatingLocation()
                result(true)
            case "requestLocationPermission":
                self.locationManager.requestAlwaysAuthorization()
                result(true)
            case "getLastKnownLocation":
                if let location = self.locationManager.location {
                    result([
                        "latitude": location.coordinate.latitude,
                        "longitude": location.coordinate.longitude,
                        "accuracy": location.horizontalAccuracy,
                        "timestamp": location.timestamp.timeIntervalSince1970 * 1000
                    ])
                } else {
                    result(nil)
                }
            case "isLocationPermissionGranted":
                let status = CLLocationManager.authorizationStatus()
                result([
                    "whenInUse": status == .authorizedWhenInUse || status == .authorizedAlways,
                    "always": status == .authorizedAlways
                ])
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Geofence Channel

    private func setupGeofenceChannel(controller: FlutterViewController) {
        geofenceChannel = FlutterMethodChannel(
            name: kGeofenceChannel,
            binaryMessenger: controller.binaryMessenger
        )
        geofenceChannel?.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            switch call.method {
            case "addGeofence":
                guard let args = call.arguments as? [String: Any],
                      let id = args["id"] as? String,
                      let lat = args["latitude"] as? Double,
                      let lng = args["longitude"] as? Double else {
                    result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                    return
                }
                let radius = args["radius"] as? Double ?? 50.0
                self.addGeofence(id: id, lat: lat, lng: lng, radius: radius, result: result)
            case "removeGeofence":
                let ids = (call.arguments as? [String: Any])?["ids"] as? [String] ?? []
                self.removeGeofences(ids: ids, result: result)
            case "getMonitoredRegions":
                let ids = self.locationManager.monitoredRegions.map { $0.identifier }
                result(ids)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func addGeofence(id: String, lat: Double, lng: Double, radius: Double, result: @escaping FlutterResult) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            result(FlutterError(code: "GEOFENCE_UNAVAILABLE", message: "Region monitoring not available", details: nil))
            return
        }

        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let region = CLCircularRegion(center: coordinate, radius: radius, identifier: id)
        region.notifyOnEntry = true
        region.notifyOnExit = true

        locationManager.startMonitoring(for: region)
        result(true)
    }

    private func removeGeofences(ids: [String], result: @escaping FlutterResult) {
        for region in locationManager.monitoredRegions {
            if ids.contains(region.identifier) {
                locationManager.stopMonitoring(for: region)
            }
        }
        result(true)
    }

    // MARK: - Location Event Channel (Stream)

    private func setupLocationEventChannel(controller: FlutterViewController) {
        FlutterEventChannel(
            name: kLocationEventChannel,
            binaryMessenger: controller.binaryMessenger
        ).setStreamHandler(LocationStreamHandler(appDelegate: self))
    }

    // MARK: - Deep Link Channel

    private func setupDeepLinkChannel(controller: FlutterViewController) {
        deepLinkChannel = FlutterMethodChannel(
            name: kDeepLinkChannel,
            binaryMessenger: controller.binaryMessenger
        )
        deepLinkChannel?.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getInitialLink":
                result(self?.pendingDeepLink)
                self?.pendingDeepLink = nil
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        deepLinkChannel?.invokeMethod("onDeepLink", arguments: url.absoluteString)
        return true
    }

    // MARK: - Push Notifications

    private func configurePushNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }
        application.registerForRemoteNotifications()
    }

    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    // MARK: - Location Event Sink (accessed by stream handler)
    func setLocationEventSink(_ sink: FlutterEventSink?) {
        locationEventSink = sink
    }
}

// MARK: - Location Stream Handler
class LocationStreamHandler: NSObject, FlutterStreamHandler {
    weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        appDelegate?.setLocationEventSink(events)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        appDelegate?.setLocationEventSink(nil)
        return nil
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        NSLog("[AppDelegate] FCM Token refreshed")
    }
}
