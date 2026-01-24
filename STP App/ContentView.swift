import SwiftUI
import PhotosUI
import MapKit
import CoreLocation
import UserNotifications

// MARK: - App Icon Generator
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Orange gradient background
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.4, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Route line decoration
            Path { path in
                path.move(to: CGPoint(x: size * 0.1, y: size * 0.7))
                path.addCurve(
                    to: CGPoint(x: size * 0.9, y: size * 0.3),
                    control1: CGPoint(x: size * 0.3, y: size * 0.5),
                    control2: CGPoint(x: size * 0.7, y: size * 0.5)
                )
            }
            .stroke(Color.white.opacity(0.3), lineWidth: size * 0.04)

            VStack(spacing: size * 0.02) {
                // Bicycle icon
                Image(systemName: "bicycle")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(.white)

                // STP text
                Text("STP")
                    .font(.system(size: size * 0.22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                // Year
                Text("2026")
                    .font(.system(size: size * 0.08, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Location pins decoration
            VStack {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: size * 0.06))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "flag.checkered")
                        .font(.system(size: size * 0.06))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(size * 0.08)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }

    @MainActor
    func generateIcon() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}

// Function to save app icon to photo library
@MainActor
func saveAppIcon() {
    let iconView = AppIconView(size: 1024)
    if let image = iconView.generateIcon() {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        print("✅ App icon saved to photo library!")
    }
}

// MARK: - User Profile Model
class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()

    @AppStorage("userName") var name: String = "Rider Name"
    @AppStorage("userLocation") var location: String = "Seattle, WA"
    @AppStorage("userBibNumber") var bibNumber: String = "#4521"
    @AppStorage("stpCount") var stpCount: Int = 2
    @AppStorage("rideType") var rideType: String = "Two-Day"
    @AppStorage("emergencyContactName") var emergencyContactName: String = "Jane Doe"
    @AppStorage("emergencyContactPhone") var emergencyContactPhone: String = "(555) 123-4567"
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("checkpointAlerts") var checkpointAlerts: Bool = true
    @AppStorage("weatherAlerts") var weatherAlerts: Bool = true
    @AppStorage("friendUpdates") var friendUpdates: Bool = false
    @AppStorage("distanceUnit") var distanceUnit: String = "Miles"
    @AppStorage("darkMode") var darkMode: Bool = false
    @AppStorage("gpsUpdateInterval") var gpsUpdateInterval: Int = 300 // 5 minutes default (in seconds)
    @AppStorage("riderType") var riderType: String = "Two-Day"

    @Published var profileImage: UIImage? = nil

    private let profileImageKey = "profileImage"

    init() {
        loadProfileImage()
    }

    func saveProfileImage(_ image: UIImage?) {
        profileImage = image
        if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(data, forKey: profileImageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: profileImageKey)
        }
    }

    func loadProfileImage() {
        if let data = UserDefaults.standard.data(forKey: profileImageKey),
           let image = UIImage(data: data) {
            profileImage = image
        }
    }

    // Distance formatting helpers
    func formatDistance(_ miles: Double) -> String {
        if distanceUnit == "Kilometers" {
            let km = miles * 1.60934
            return String(format: "%.1f km", km)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }

    func formatDistanceInt(_ miles: Int) -> String {
        if distanceUnit == "Kilometers" {
            let km = Double(miles) * 1.60934
            return "\(Int(km)) km"
        } else {
            return "\(miles) mi"
        }
    }

    var distanceAbbrev: String {
        distanceUnit == "Kilometers" ? "km" : "mi"
    }
}

// MARK: - Route Map View (with polyline)
struct RouteMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let checkpoints: [STPCheckpoint]
    let showsUserLocation: Bool
    var onCheckpointTapped: ((STPCheckpoint) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.setRegion(region, animated: false)

        // Enable map interactions
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true

        // Show map controls
        mapView.showsCompass = true
        mapView.showsScale = true

        #if targetEnvironment(macCatalyst)
        // Mac Catalyst supports trackpad/mouse scroll wheel zoom natively
        mapView.showsZoomControls = true
        #endif

        // Add route polyline
        let coordinates = checkpoints.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        // Add checkpoint annotations
        for checkpoint in checkpoints {
            let annotation = CheckpointAnnotation(checkpoint: checkpoint)
            mapView.addAnnotation(annotation)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.showsUserLocation = showsUserLocation
        if mapView.region.center.latitude != region.center.latitude ||
           mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteMapView

        init(_ parent: RouteMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemOrange
                renderer.lineWidth = 4
                renderer.lineDashPattern = nil
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil // Use default blue dot
            }

            guard let checkpointAnnotation = annotation as? CheckpointAnnotation else {
                return nil
            }

            let identifier = "CheckpointMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            } else {
                annotationView?.annotation = annotation
            }

            let checkpoint = checkpointAnnotation.checkpoint
            switch checkpoint.type {
            case .start:
                annotationView?.markerTintColor = .systemOrange
                annotationView?.glyphImage = UIImage(systemName: "flag.fill")
            case .restStop:
                annotationView?.markerTintColor = .systemGreen
                annotationView?.glyphImage = UIImage(systemName: "fork.knife")
            case .miniStop:
                annotationView?.markerTintColor = .systemBlue
                annotationView?.glyphImage = UIImage(systemName: "cup.and.saucer.fill")
            case .finish:
                annotationView?.markerTintColor = .systemOrange
                annotationView?.glyphImage = UIImage(systemName: "flag.checkered")
            }

            return annotationView
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let checkpointAnnotation = view.annotation as? CheckpointAnnotation else { return }
            parent.onCheckpointTapped?(checkpointAnnotation.checkpoint)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

class CheckpointAnnotation: NSObject, MKAnnotation {
    let checkpoint: STPCheckpoint
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
    }
    var title: String? { checkpoint.name }
    var subtitle: String? { "Mile \(Int(checkpoint.mile))" }

    init(checkpoint: STPCheckpoint) {
        self.checkpoint = checkpoint
    }
}

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    private var notifiedCheckpoints: Set<UUID> = [] // Track which checkpoints we've notified about

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied")
                }
            }
        }
    }

    func checkProximityAndNotify(userLocation: CLLocationCoordinate2D, checkpoints: [STPCheckpoint], alertsEnabled: Bool) {
        guard alertsEnabled else { return }

        let userCL = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

        for checkpoint in checkpoints {
            let checkpointLocation = CLLocation(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
            let distanceMeters = userCL.distance(from: checkpointLocation)
            let distanceMiles = distanceMeters / 1609.34

            // Alert when within 1 mile and haven't already notified for this checkpoint
            if distanceMiles <= 1.0 && !notifiedCheckpoints.contains(checkpoint.id) {
                sendCheckpointNotification(checkpoint: checkpoint, distance: distanceMiles)
                notifiedCheckpoints.insert(checkpoint.id)
            }

            // Reset notification if user moves away (more than 3 miles)
            if distanceMiles > 3.0 && notifiedCheckpoints.contains(checkpoint.id) {
                notifiedCheckpoints.remove(checkpoint.id)
            }
        }
    }

    private func sendCheckpointNotification(checkpoint: STPCheckpoint, distance: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Checkpoint Ahead!"
        content.body = "\(checkpoint.name) is \(UserProfileManager.shared.formatDistance(distance)) away"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "checkpoint-\(checkpoint.id)",
            content: content,
            trigger: nil // Send immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error)")
            } else {
                print("📍 Sent notification for \(checkpoint.name)")
            }
        }
    }

    func resetNotifications() {
        notifiedCheckpoints.removeAll()
    }

    // TEST: Send a test notification
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Checkpoint Ahead!"
        content.body = "Spanaway Middle School is 0.8 mi away"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test-notification",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test notification error: \(error)")
            } else {
                print("✅ Test notification sent!")
            }
        }
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var updateTimer: Timer?
    private var isGettingInitialLocation = true
    private let notificationManager = NotificationManager.shared

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastUpdated: Date?

    var updateInterval: TimeInterval = 300 // Default 5 minutes
    var checkpoints: [STPCheckpoint] = []
    var checkpointAlertsEnabled: Bool = true

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update when moved 10 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
        print("🔧 LocationManager initialized, status: \(authorizationStatus.rawValue)")
    }

    func requestPermission() {
        print("🔧 Requesting location permission...")
        // First request "When In Use", then upgrade to "Always"
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func startTracking() {
        guard updateInterval > 0 else {
            print("🔧 GPS is disabled (interval = 0)")
            stopTracking()
            return
        }

        print("🔧 Starting location tracking with interval: \(updateInterval)s")
        print("🔧 Current authorization: \(locationManager.authorizationStatus.rawValue)")
        isGettingInitialLocation = true

        // Request a single location first
        locationManager.requestLocation()

        // Also start continuous updates
        locationManager.startUpdatingLocation()

        // Set up update timer for periodic updates
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            print("🔧 Timer triggered - requesting location update")
            self?.locationManager.requestLocation()
        }
    }

    func stopTracking() {
        print("🔧 Stopping location tracking")
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Update on main thread to ensure UI updates
        DispatchQueue.main.async { [weak self] in
            self?.userLocation = location.coordinate
            self?.lastUpdated = Date()

            // Check for nearby checkpoints and send notifications
            if let self = self, !self.checkpoints.isEmpty {
                self.notificationManager.checkProximityAndNotify(
                    userLocation: location.coordinate,
                    checkpoints: self.checkpoints,
                    alertsEnabled: self.checkpointAlertsEnabled
                )
            }
        }

        // Print location to console for debugging
        print("📍 GPS Location Updated:")
        print("   Latitude: \(location.coordinate.latitude)")
        print("   Longitude: \(location.coordinate.longitude)")
        print("   Accuracy: \(location.horizontalAccuracy)m")
        print("   Time: \(Date())")

        // After getting initial location, switch to significant location changes for battery
        if isGettingInitialLocation {
            isGettingInitialLocation = false
            // For background mode, keep updates running but reduce frequency
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                if self.locationManager.authorizationStatus == .authorizedAlways {
                    print("🔧 Background mode: keeping location updates active")
                    // Keep running for background notifications
                } else {
                    print("🔧 Foreground only: switching to timer-based updates")
                    self.locationManager.stopUpdatingLocation()
                }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = manager.authorizationStatus
            print("🔧 Authorization changed to: \(manager.authorizationStatus.rawValue)")

            if manager.authorizationStatus == .authorizedWhenInUse {
                print("🔧 When In Use granted - requesting Always for background updates")
                // Request upgrade to Always for background location
                manager.requestAlwaysAuthorization()
                self?.startTracking()
            } else if manager.authorizationStatus == .authorizedAlways {
                print("🔧 Always permission granted - starting background tracking")
                self?.startTracking()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")

        // If location unknown, try again
        if let clError = error as? CLError, clError.code == .locationUnknown {
            print("🔧 Location unknown, retrying...")
            locationManager.startUpdatingLocation()
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @State private var showingProfile = false
    @StateObject private var userProfile = UserProfileManager.shared
    @StateObject private var locationManager = LocationManager()
    @State private var hasRequestedPermission = false

    var body: some View {
        Group {
            if locationManager.authorizationStatus == .notDetermined && !hasRequestedPermission {
                LocationPermissionView(locationManager: locationManager, hasRequestedPermission: $hasRequestedPermission)
            } else {
                MainAppView(showingProfile: $showingProfile, userProfile: userProfile, locationManager: locationManager)
            }
        }
        .environmentObject(userProfile)
        .environmentObject(locationManager)
        .preferredColorScheme(userProfile.darkMode ? .dark : nil)
    }
}

// MARK: - Location Permission View
struct LocationPermissionView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var hasRequestedPermission: Bool
    @State private var isRequestingPermission = false
    @State private var permissionDenied = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 120, height: 120)
                Image(systemName: "location.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }

            // Title and description
            VStack(spacing: 16) {
                Text(permissionDenied ? "Location Access Denied" : "Enable Location")
                    .font(.title)
                    .fontWeight(.bold)

                Text(permissionDenied ?
                     "Location access was denied. Please enable it in Settings to use GPS features like finding nearby checkpoints." :
                     "STP App needs your location to show your position on the route, find nearby checkpoints, and track your progress from Seattle to Portland.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                PermissionFeatureRow(icon: "map.fill", title: "Route Tracking", description: "See your position on the STP route")
                PermissionFeatureRow(icon: "mappin.circle.fill", title: "Nearest Stops", description: "Find checkpoints closest to you")
                PermissionFeatureRow(icon: "location.circle.fill", title: "Live Updates", description: "Track your progress in real-time")
            }
            .padding(.horizontal, 32)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if permissionDenied {
                    // Show Open Settings button if permission was denied
                    Button(action: {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .cornerRadius(14)
                    }
                } else {
                    Button(action: {
                        isRequestingPermission = true
                        locationManager.requestPermission()

                        // If status doesn't change within 2 seconds, permission was likely already denied
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            if locationManager.authorizationStatus == .notDetermined {
                                // Dialog didn't appear - might have been denied before or restricted
                                isRequestingPermission = false
                                permissionDenied = true
                            } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                                permissionDenied = true
                                isRequestingPermission = false
                            }
                        }
                    }) {
                        HStack {
                            if isRequestingPermission {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isRequestingPermission ? "Waiting for Permission..." : "Allow Location Access")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRequestingPermission ? .orange.opacity(0.7) : .orange)
                        .cornerRadius(14)
                    }
                    .disabled(isRequestingPermission)
                }

                Button(action: {
                    hasRequestedPermission = true
                }) {
                    Text(permissionDenied ? "Continue Without GPS" : "Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Check if permission was already denied
            let status = locationManager.authorizationStatus
            if status == .denied || status == .restricted {
                permissionDenied = true
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            print("🔧 Permission view saw status change: \(newStatus.rawValue)")
            if newStatus == .denied || newStatus == .restricted {
                permissionDenied = true
                isRequestingPermission = false
            } else if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                // Permission granted - transition to main app
                hasRequestedPermission = true
            }
        }
    }
}

struct PermissionFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Main App View
struct MainAppView: View {
    @Binding var showingProfile: Bool
    @ObservedObject var userProfile: UserProfileManager
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        TabView {
            HomeView(showingProfile: $showingProfile, userProfile: userProfile)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            RouteView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Route")
                }

            AchievementsView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Achievements")
                }

            PhotosView()
                .tabItem {
                    Image(systemName: "text.bubble.fill")
                    Text("Feed")
                }

            SettingsTabView(userProfile: userProfile)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .tint(.orange)
        .sheet(isPresented: $showingProfile) {
            ProfileView(userProfile: userProfile)
        }
        .onAppear {
            // Set up checkpoints for location-based notifications
            locationManager.checkpoints = stpCheckpoints
            locationManager.checkpointAlertsEnabled = UserProfileManager.shared.checkpointAlerts

            // Load GPS update interval from settings
            locationManager.updateInterval = TimeInterval(UserProfileManager.shared.gpsUpdateInterval)

            // Request notification permission if alerts are enabled
            if UserProfileManager.shared.checkpointAlerts {
                NotificationManager.shared.requestPermission()
            }

            // TEST: Send test notification after 3 seconds
            NotificationManager.shared.requestPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                NotificationManager.shared.sendTestNotification()
            }

            // Start tracking immediately if permission already granted
            if locationManager.authorizationStatus == .authorizedWhenInUse ||
               locationManager.authorizationStatus == .authorizedAlways {
                // Request immediate location update
                locationManager.startTracking()
            }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @Binding var showingProfile: Bool
    @ObservedObject var userProfile: UserProfileManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var showingHelp = false
    @State private var showingFAQ = false
    @State private var showingEmergency = false
    @State private var selectedCheckpoint: STPCheckpoint?

    // Calculate distance in miles between two coordinates
    func distanceInMiles(from: CLLocationCoordinate2D, to: STPCheckpoint) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let distanceMeters = fromLocation.distance(from: toLocation)
        return distanceMeters / 1609.34 // Convert to miles
    }

    // Get nearest checkpoints sorted by distance
    var nearestCheckpoints: [(checkpoint: STPCheckpoint, distance: Double)] {
        guard let userLocation = locationManager.userLocation else {
            return []
        }
        return stpCheckpoints
            .map { checkpoint in
                (checkpoint: checkpoint, distance: distanceInMiles(from: userLocation, to: checkpoint))
            }
            .sorted { $0.distance < $1.distance }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Nearest Stop Card
                    if let nearest = nearestCheckpoints.first {
                        StatusCard(icon: "location.fill", title: "Nearest Stop", value: nearest.checkpoint.name.components(separatedBy: " - ").last ?? nearest.checkpoint.name, subvalue: "\(userProfile.formatDistance(nearest.distance)) away", color: .blue)
                            .padding(.horizontal)
                    } else {
                        StatusCard(icon: "location.fill", title: "Nearest Stop", value: "Loading...", subvalue: "Enable GPS", color: .blue)
                            .padding(.horizontal)
                    }

                    // Weather & Conditions
                    HStack(spacing: 12) {
                        WeatherCard(temp: "62°", condition: "Partly Cloudy", icon: "cloud.sun.fill", wind: "8 mph NW")
                    }
                    .padding(.horizontal)

                    // Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            QuickActionButton(icon: "cross.circle.fill", title: "Emergency", color: .red) {
                                showingEmergency = true
                            }
                            QuickActionButton(icon: "wrench.fill", title: "Bike Help", color: .blue) {
                                // Bike support
                            }
                            QuickActionButton(icon: "car.fill", title: "SAG", color: .purple) {
                                // SAG wagon
                            }
                            QuickActionButton(icon: "fork.knife", title: "Food Stop", color: .orange) {
                                // Food stops
                            }
                            QuickActionButton(icon: "questionmark.circle.fill", title: "Help", color: .gray) {
                                showingHelp = true
                            }
                            QuickActionButton(icon: "text.book.closed.fill", title: "FAQ", color: .teal) {
                                showingFAQ = true
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Nearest Stops (GPS-based)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Nearest Stops")
                                .font(.headline)
                            Spacer()
                            if locationManager.userLocation != nil {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 6, height: 6)
                                    Text("GPS")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Button(action: { locationManager.requestPermission() }) {
                                    Text("Enable GPS")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)

                        if nearestCheckpoints.isEmpty {
                            HStack {
                                Image(systemName: "location.slash")
                                    .foregroundStyle(.secondary)
                                Text("Enable GPS to see nearest stops")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(Array(nearestCheckpoints.prefix(3).enumerated()), id: \.element.checkpoint.id) { index, item in
                                    NearestStopRow(
                                        checkpoint: item.checkpoint,
                                        distance: item.distance,
                                        isNearest: index == 0
                                    ) {
                                        selectedCheckpoint = item.checkpoint
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Your Achievements
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Achievements")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                BadgeItem(icon: "figure.outdoor.cycle", title: "Started", color: .green)
                                BadgeItem(icon: "50.circle.fill", title: "50 Miles", color: .blue)
                                BadgeItem(icon: "sunrise.fill", title: "Early Bird", color: .orange)
                                BadgeItem(icon: "mountain.2.fill", title: "Hill Climber", color: .purple, locked: true)
                                BadgeItem(icon: "100.circle.fill", title: "Century", color: .red, locked: true)
                                BadgeItem(icon: "flag.checkered", title: "Finisher", color: .yellow, locked: true)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("STP 2026")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingProfile = true }) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .sheet(isPresented: $showingHelp) {
                HelpView()
            }
            .sheet(isPresented: $showingFAQ) {
                FAQView()
            }
            .sheet(isPresented: $showingEmergency) {
                EmergencyView()
            }
            .sheet(item: $selectedCheckpoint) { checkpoint in
                CheckpointDetailView(checkpoint: checkpoint)
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                print("🏠 HomeView appeared")
                print("🏠 Authorization status: \(locationManager.authorizationStatus.rawValue)")
                print("🏠 User location: \(String(describing: locationManager.userLocation))")
                print("🏠 Nearest checkpoints count: \(nearestCheckpoints.count)")

                // Try to start tracking if authorized
                if locationManager.authorizationStatus == .authorizedWhenInUse ||
                   locationManager.authorizationStatus == .authorizedAlways {
                    print("🏠 Starting tracking from HomeView...")
                    locationManager.startTracking()
                }
            }
            .onChange(of: locationManager.userLocation?.latitude) { _, newLat in
                print("🏠 Location changed! New lat: \(String(describing: newLat))")
            }
        }
    }
}

// MARK: - Nearest Stop Row
struct NearestStopRow: View {
    let checkpoint: STPCheckpoint
    let distance: Double
    let isNearest: Bool
    let onTap: () -> Void

    var typeColor: Color {
        switch checkpoint.type {
        case .start: return .orange
        case .restStop: return .green
        case .miniStop: return .blue
        case .finish: return .orange
        }
    }

    var typeIcon: String {
        switch checkpoint.type {
        case .start: return "flag.fill"
        case .restStop: return "fork.knife"
        case .miniStop: return "cup.and.saucer.fill"
        case .finish: return "flag.checkered"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(typeColor)
                        .frame(width: 40, height: 40)
                    Image(systemName: typeIcon)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(checkpoint.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if isNearest {
                            Text("NEAREST")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green)
                                .cornerRadius(4)
                        }
                    }
                    Text(UserProfileManager.shared.formatDistanceInt(Int(checkpoint.mile)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(UserProfileManager.shared.formatDistance(distance))
                        .font(.headline)
                        .foregroundStyle(isNearest ? .green : .primary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(isNearest ? Color.green.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isNearest ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct StatusCard: View {
    let icon: String
    let title: String
    let value: String
    let subvalue: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(subvalue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeatherCard: View {
    let temp: String
    let condition: String
    let icon: String
    let wind: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading) {
                Text(temp)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(condition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                HStack {
                    Image(systemName: "wind")
                    Text(wind)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("Good riding conditions")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct CheckpointRow: View {
    let name: String
    let mile: Double
    let amenities: [String]
    let isNext: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isNext ? .orange : Color(.systemGray4))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(isNext ? .semibold : .regular)
                    if isNext {
                        Text("NEXT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange)
                            .foregroundStyle(.white)
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 8) {
                    Text("Mile \(String(format: "%.1f", mile))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        ForEach(amenities, id: \.self) { amenity in
                            Image(systemName: amenityIcon(amenity))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    func amenityIcon(_ amenity: String) -> String {
        switch amenity {
        case "food": return "fork.knife"
        case "water": return "drop.fill"
        case "restroom": return "toilet.fill"
        case "bike": return "wrench.fill"
        case "medical": return "cross.fill"
        default: return "circle.fill"
        }
    }
}

// MARK: - STP Checkpoint Model
struct STPCheckpoint: Identifiable {
    let id = UUID()
    let name: String
    let mile: Double
    let type: CheckpointType
    let saturdayHours: String?
    let sundayHours: String?
    let amenities: [String]
    let location: String
    let notes: String
    let latitude: Double
    let longitude: Double

    enum CheckpointType {
        case start, restStop, miniStop, finish
    }
}

// Official STP 2026 Checkpoints
let stpCheckpoints: [STPCheckpoint] = [
    STPCheckpoint(name: "Seattle - UW Stadium", mile: 0, type: .start,
                  saturdayHours: "4:45-7:15 AM", sundayHours: nil,
                  amenities: ["restroom", "bag drop"],
                  location: "Parking Lot E-18, University of Washington",
                  notes: "Packet pickup Friday 6-9 PM or Saturday morning. Arrive early for best start position.",
                  latitude: 47.65592, longitude: -122.30085),
    STPCheckpoint(name: "Seward Park", mile: 10, type: .miniStop,
                  saturdayHours: "5:15-8:30 AM", sundayHours: nil,
                  amenities: ["bike support", "restroom"],
                  location: "Seward Park, Seattle",
                  notes: "No host services. Mechanic and restrooms available.",
                  latitude: 47.54888, longitude: -122.25748),
    STPCheckpoint(name: "IKEA Renton", mile: 19, type: .restStop,
                  saturdayHours: "5:30-9 AM", sundayHours: "Closed",
                  amenities: ["free food", "water", "restroom", "medical", "bike support"],
                  location: "IKEA, Renton, WA",
                  notes: "First major rest stop. Free food and full services.",
                  latitude: 47.44362, longitude: -122.22777),
    STPCheckpoint(name: "Puyallup - Kalles Junior High", mile: 42, type: .miniStop,
                  saturdayHours: "6 AM-12 PM", sundayHours: nil,
                  amenities: ["food purchase", "water", "restroom"],
                  location: "Kalles Junior High School, Puyallup, WA",
                  notes: "Food and drinks available for purchase.",
                  latitude: 47.18681, longitude: -122.28800),
    STPCheckpoint(name: "Spanaway Middle School", mile: 55, type: .restStop,
                  saturdayHours: "7 AM-2 PM", sundayHours: "Closed",
                  amenities: ["free food", "water", "restroom", "medical", "bike support"],
                  location: "Spanaway Middle School, Spanaway, WA",
                  notes: "Full-service rest stop with free food.",
                  latitude: 47.11504, longitude: -122.42719),
    STPCheckpoint(name: "McKenna Elementary", mile: 71, type: .miniStop,
                  saturdayHours: "8 AM-2 PM", sundayHours: nil,
                  amenities: ["food purchase", "water", "restroom"],
                  location: "McKenna Elementary School, McKenna, WA",
                  notes: "Standard mini-stop services.",
                  latitude: 46.93872, longitude: -122.55434),
    STPCheckpoint(name: "Yelm City Park", mile: 74, type: .miniStop,
                  saturdayHours: "8 AM-2 PM", sundayHours: nil,
                  amenities: ["restroom"],
                  location: "Yelm City Park, Yelm, WA",
                  notes: "Porta-potties only. Limited services.",
                  latitude: 46.94024, longitude: -122.60936),
    STPCheckpoint(name: "Rainier Mini Stop", mile: 77, type: .miniStop,
                  saturdayHours: "9 AM-3 PM", sundayHours: nil,
                  amenities: ["food purchase", "water", "restroom"],
                  location: "Rainier, WA",
                  notes: "New for 2025! Mini stop with food and drinks for purchase.",
                  latitude: 46.88994, longitude: -122.68747),
    STPCheckpoint(name: "Tenino City Park", mile: 88, type: .miniStop,
                  saturdayHours: "9 AM-4 PM", sundayHours: nil,
                  amenities: ["food purchase", "water", "restroom"],
                  location: "Tenino City Park, Tenino, WA",
                  notes: "Standard mini-stop services.",
                  latitude: 46.85553, longitude: -122.85245),
    STPCheckpoint(name: "Centralia College (Midpoint)", mile: 101, type: .miniStop,
                  saturdayHours: "10 AM-7 PM", sundayHours: "6-9 AM",
                  amenities: ["food purchase", "water", "medical", "bike support", "overnight"],
                  location: "Centralia College, Centralia, WA",
                  notes: "Official midpoint! Medical and mechanical support. Two-day riders stay overnight here.",
                  latitude: 46.71534, longitude: -122.96060),
    STPCheckpoint(name: "Chehalis Recreation Park", mile: 109, type: .restStop,
                  saturdayHours: "9:30 AM-2 PM", sundayHours: "6-10 AM (Mini-Stop)",
                  amenities: ["free food", "water", "restroom", "medical", "bike support"],
                  location: "Chehalis Recreation Park, Chehalis, WA",
                  notes: "REST STOP Saturday with free food & full services. Operates as MINI-STOP Sunday with limited services.",
                  latitude: 46.65003, longitude: -122.95552),
    STPCheckpoint(name: "Vader", mile: 129, type: .miniStop,
                  saturdayHours: "10 AM-5 PM", sundayHours: "6 AM-12 PM",
                  amenities: ["free food", "water", "restroom"],
                  location: "Vader, WA",
                  notes: "Famous for free Vader Taters! Small town stop with local hospitality.",
                  latitude: 46.40181, longitude: -122.96883),
    STPCheckpoint(name: "Castle Rock High School", mile: 138, type: .miniStop,
                  saturdayHours: nil, sundayHours: "6 AM-3 PM",
                  amenities: ["water", "restroom", "food purchase"],
                  location: "Castle Rock High School, Castle Rock, WA",
                  notes: "Sunday only. Running tap water, porta-potties, limited baked goods for sale.",
                  latitude: 46.28244, longitude: -122.91883),
    STPCheckpoint(name: "Lexington - Riverside Park", mile: 147, type: .restStop,
                  saturdayHours: "1-6 PM", sundayHours: "8 AM-2 PM",
                  amenities: ["free food", "water", "restroom", "medical", "bike support"],
                  location: "Riverside Park, Lexington, WA",
                  notes: "Full-service rest stop. Great place to refuel for the final push.",
                  latitude: 46.19102, longitude: -122.90493),
    STPCheckpoint(name: "Goble Tavern", mile: 163, type: .miniStop,
                  saturdayHours: "1-6 PM", sundayHours: "10 AM-4 PM",
                  amenities: ["food purchase", "water"],
                  location: "Goble Tavern, Goble, OR",
                  notes: "Welcome to Oregon! Local tavern stop.",
                  latitude: 46.01355, longitude: -122.87558),
    STPCheckpoint(name: "St. Helens Elementary", mile: 177, type: .restStop,
                  saturdayHours: "2-6 PM", sundayHours: "9 AM-5 PM",
                  amenities: ["free food", "water", "restroom", "medical", "bike support"],
                  location: "St. Helens Elementary School, St. Helens, OR",
                  notes: "Last major rest stop before Portland. Full services available.",
                  latitude: 45.85506, longitude: -122.83817),
    STPCheckpoint(name: "Scappoose", mile: 188, type: .miniStop,
                  saturdayHours: "2-6 PM", sundayHours: "9 AM-5 PM",
                  amenities: ["water", "food purchase"],
                  location: "NW Boat Basin Rd, Scappoose, OR",
                  notes: "Free tap water hauled in. Other items may be for sale. Almost there!",
                  latitude: 45.68283, longitude: -122.87401),
    STPCheckpoint(name: "Portland - Holladay Park", mile: 206, type: .finish,
                  saturdayHours: "4-10 PM", sundayHours: "10 AM-6 PM",
                  amenities: ["finisher meal", "merchandise", "bag pickup"],
                  location: "Holladay Park, Portland, OR",
                  notes: "Congratulations, you made it! Finisher meal, merchandise pickup, and luggage retrieval available.",
                  latitude: 45.53076, longitude: -122.65358)
]

// MARK: - Route View
struct RouteView: View {
    @State private var selectedFilter: RouteFilter = .all
    @EnvironmentObject var locationManager: LocationManager
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 46.5, longitude: -122.6),
        span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 1.5)
    )
    @State private var selectedCheckpoint: STPCheckpoint?

    enum RouteFilter: String, CaseIterable {
        case all = "All Stops"
        case restStops = "Rest Stops"
        case miniStops = "Mini Stops"
    }

    var filteredCheckpoints: [STPCheckpoint] {
        switch selectedFilter {
        case .all:
            return stpCheckpoints
        case .restStops:
            return stpCheckpoints.filter { $0.type == .restStop || $0.type == .start || $0.type == .finish }
        case .miniStops:
            return stpCheckpoints.filter { $0.type == .miniStop }
        }
    }

    // Find the nearest checkpoint based on GPS
    var nearestCheckpointId: UUID? {
        guard let userLocation = locationManager.userLocation else { return nil }
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

        var nearestId: UUID?
        var nearestDistance: Double = .infinity

        for checkpoint in stpCheckpoints {
            let checkpointLocation = CLLocation(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
            let distance = userCLLocation.distance(from: checkpointLocation)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestId = checkpoint.id
            }
        }
        return nearestId
    }

    // Get distance to a checkpoint in miles
    func distanceToCheckpoint(_ checkpoint: STPCheckpoint) -> Double? {
        guard let userLocation = locationManager.userLocation else { return nil }
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let checkpointLocation = CLLocation(latitude: checkpoint.latitude, longitude: checkpoint.longitude)
        return userCLLocation.distance(from: checkpointLocation) / 1609.34
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Interactive Map with Route Line
                    ZStack(alignment: .topTrailing) {
                        RouteMapView(
                            region: $mapRegion,
                            checkpoints: stpCheckpoints,
                            showsUserLocation: locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways,
                            onCheckpointTapped: { checkpoint in
                                selectedCheckpoint = checkpoint
                            }
                        )
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Location status indicator
                        VStack(alignment: .trailing, spacing: 4) {
                            if locationManager.authorizationStatus == .notDetermined {
                                Button(action: { locationManager.requestPermission() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                        Text("Enable GPS")
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                }
                            } else if locationManager.userLocation != nil {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                    Text("GPS Active")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            }

                            // Center on user location button
                            if locationManager.userLocation != nil {
                                Button(action: {
                                    if let location = locationManager.userLocation {
                                        withAnimation {
                                            mapRegion.center = location
                                            mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                                        }
                                    }
                                }) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.blue)
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }

                            // Reset to full route button
                            Button(action: {
                                withAnimation {
                                    mapRegion = MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(latitude: 46.5, longitude: -122.6),
                                        span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 1.5)
                                    )
                                }
                            }) {
                                Image(systemName: "map")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.orange)
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }

                            // Zoom controls
                            VStack(spacing: 0) {
                                Button(action: {
                                    withAnimation {
                                        mapRegion.span = MKCoordinateSpan(
                                            latitudeDelta: max(mapRegion.span.latitudeDelta / 2, 0.01),
                                            longitudeDelta: max(mapRegion.span.longitudeDelta / 2, 0.01)
                                        )
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.primary)
                                        .frame(width: 32, height: 32)
                                }

                                Divider()
                                    .frame(width: 24)

                                Button(action: {
                                    withAnimation {
                                        mapRegion.span = MKCoordinateSpan(
                                            latitudeDelta: min(mapRegion.span.latitudeDelta * 2, 90),
                                            longitudeDelta: min(mapRegion.span.longitudeDelta * 2, 180)
                                        )
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.primary)
                                        .frame(width: 32, height: 32)
                                }
                            }
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                    .onAppear {
                        if locationManager.authorizationStatus == .authorizedWhenInUse ||
                           locationManager.authorizationStatus == .authorizedAlways {
                            locationManager.startTracking()
                        }
                    }
                    .sheet(item: $selectedCheckpoint) { checkpoint in
                        CheckpointDetailView(checkpoint: checkpoint)
                            .presentationDetents([.medium, .large])
                    }

                    // Route Stats
                    HStack(spacing: 12) {
                        RouteStatCard(title: "Total Distance", value: UserProfileManager.shared.formatDistanceInt(206), icon: "arrow.left.and.right")
                        RouteStatCard(title: "Elevation Gain", value: "4,800 ft", icon: "mountain.2.fill")
                    }
                    .padding(.horizontal)

                    // Stop Type Legend
                    HStack(spacing: 16) {
                        LegendItem(color: .green, label: "Rest Stop (Free Food)")
                        LegendItem(color: .blue, label: "Mini Stop (Food for Purchase)")
                    }
                    .font(.caption)
                    .padding(.horizontal)

                    // Filter
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(RouteFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // All Checkpoints
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Checkpoints")
                                .font(.headline)
                            Spacer()
                            Text("\(filteredCheckpoints.count) stops")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 0) {
                            ForEach(Array(filteredCheckpoints.enumerated()), id: \.element.id) { index, checkpoint in
                                STPCheckpointRow(
                                    checkpoint: checkpoint,
                                    isLast: index == filteredCheckpoints.count - 1,
                                    isNearest: checkpoint.id == nearestCheckpointId,
                                    distanceMiles: distanceToCheckpoint(checkpoint)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Route")
        }
    }
}

// MARK: - Checkpoint Map Marker
struct CheckpointMapMarker: View {
    let checkpoint: STPCheckpoint
    let onTap: () -> Void

    var markerColor: Color {
        switch checkpoint.type {
        case .start: return .orange
        case .restStop: return .green
        case .miniStop: return .blue
        case .finish: return .orange
        }
    }

    var markerIcon: String {
        switch checkpoint.type {
        case .start: return "flag.fill"
        case .restStop: return "fork.knife"
        case .miniStop: return "cup.and.saucer.fill"
        case .finish: return "flag.checkered"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(markerColor)
                        .frame(width: 32, height: 32)
                        .shadow(color: markerColor.opacity(0.4), radius: 4, y: 2)
                    Image(systemName: markerIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
                // Pointer triangle
                Triangle()
                    .fill(markerColor)
                    .frame(width: 12, height: 8)
                    .offset(y: -2)
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

struct STPCheckpointRow: View {
    let checkpoint: STPCheckpoint
    var isLast: Bool = false
    var isNearest: Bool = false
    var distanceMiles: Double? = nil
    @State private var showingDetail = false

    var typeColor: Color {
        switch checkpoint.type {
        case .start: return .orange
        case .restStop: return .green
        case .miniStop: return .blue
        case .finish: return .orange
        }
    }

    var typeIcon: String {
        switch checkpoint.type {
        case .start: return "flag.fill"
        case .restStop: return "fork.knife"
        case .miniStop: return "cup.and.saucer.fill"
        case .finish: return "flag.checkered"
        }
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: 12) {
                // Timeline indicator
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(isNearest ? .green : typeColor)
                            .frame(width: isNearest ? 32 : 28, height: isNearest ? 32 : 28)
                        Image(systemName: isNearest ? "location.fill" : typeIcon)
                            .font(.system(size: isNearest ? 14 : 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    if !isLast {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: 2, height: isNearest ? 46 : 50)
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(checkpoint.name)
                                .font(isNearest ? .headline : .subheadline)
                                .fontWeight(isNearest ? .bold : .semibold)
                                .foregroundStyle(.primary)
                            if isNearest {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                    Text("NEAREST STOP")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                    if let distance = distanceMiles {
                                        Text("• \(UserProfileManager.shared.formatDistance(distance)) away")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                }
                                .foregroundStyle(.green)
                            }
                        }
                        Spacer()
                        Text(UserProfileManager.shared.formatDistanceInt(Int(checkpoint.mile)))
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isNearest ? Color.green.opacity(0.2) : typeColor.opacity(0.2))
                            .foregroundStyle(isNearest ? .green : typeColor)
                            .cornerRadius(8)
                    }

                    // Hours preview
                    if let satHours = checkpoint.saturdayHours {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("Sat: \(satHours)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // Tap for more hint
                    Text("Tap for details")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 8)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            CheckpointDetailView(checkpoint: checkpoint)
        }
    }
}

// MARK: - Checkpoint Detail View
struct CheckpointDetailView: View {
    @Environment(\.dismiss) var dismiss
    let checkpoint: STPCheckpoint

    var typeColor: Color {
        switch checkpoint.type {
        case .start: return .orange
        case .restStop: return .green
        case .miniStop: return .blue
        case .finish: return .orange
        }
    }

    var typeLabel: String {
        switch checkpoint.type {
        case .start: return "Start Line"
        case .restStop: return "Rest Stop"
        case .miniStop: return "Mini Stop"
        case .finish: return "Finish Line"
        }
    }

    var typeDescription: String {
        switch checkpoint.type {
        case .start: return "The official start of STP at University of Washington"
        case .restStop: return "Full-service stop with free food, medical staff, and bike mechanics"
        case .miniStop: return "Quick stop with food and drinks available for purchase"
        case .finish: return "Congratulations! You made it to Portland!"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(typeColor)
                                .frame(width: 80, height: 80)
                            Image(systemName: checkpointIcon)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: 8) {
                            Text(checkpoint.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 12) {
                                Label("Mile \(Int(checkpoint.mile))", systemImage: "mappin.circle.fill")
                                Text("•")
                                Text(typeLabel)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        Text(typeDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)

                    // Location Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Location", systemImage: "mappin.and.ellipse")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Image(systemName: "building.2.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(checkpoint.location)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text("\(String(format: "%.5f", checkpoint.latitude)), \(String(format: "%.5f", checkpoint.longitude))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)

                                Button(action: {
                                    // Open in Maps with coordinates
                                    if let url = URL(string: "maps://?ll=\(checkpoint.latitude),\(checkpoint.longitude)&q=\(checkpoint.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Label("Open in Maps", systemImage: "arrow.up.right.square")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Notes Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Notes", systemImage: "note.text")
                            .font(.headline)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            Text(checkpoint.notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Hours Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Hours of Operation", systemImage: "clock.fill")
                            .font(.headline)

                        VStack(spacing: 8) {
                            if let satHours = checkpoint.saturdayHours {
                                HoursRow(day: "Saturday", hours: satHours, isOpen: satHours != "Closed")
                            }
                            if let sunHours = checkpoint.sundayHours {
                                HoursRow(day: "Sunday", hours: sunHours, isOpen: sunHours != "Closed" && sunHours != "Limited")
                            } else if checkpoint.saturdayHours != nil {
                                HoursRow(day: "Sunday", hours: "Closed", isOpen: false)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Amenities Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Available Services", systemImage: "checkmark.circle.fill")
                            .font(.headline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(checkpoint.amenities, id: \.self) { amenity in
                                AmenityCard(amenity: amenity)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // What to Expect Section
                    if checkpoint.type == .restStop || checkpoint.type == .start || checkpoint.type == .finish {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("What to Expect", systemImage: "info.circle.fill")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                if checkpoint.type == .restStop {
                                    ExpectationRow(icon: "fork.knife", text: "Free food and sports drinks")
                                    ExpectationRow(icon: "toilet", text: "Honey Bucket restrooms on site")
                                    ExpectationRow(icon: "cross.fill", text: "Full medical staff available")
                                    ExpectationRow(icon: "wrench.fill", text: "Bike mechanics for repairs")
                                } else if checkpoint.type == .start {
                                    ExpectationRow(icon: "ticket", text: "Packet pickup available")
                                    ExpectationRow(icon: "bag.fill", text: "Bag drop-off service")
                                    ExpectationRow(icon: "figure.wave", text: "Arrive early for best start position")
                                } else if checkpoint.type == .finish {
                                    ExpectationRow(icon: "trophy.fill", text: "Finisher meal included")
                                    ExpectationRow(icon: "tshirt", text: "Merchandise pickup")
                                    ExpectationRow(icon: "bag.fill", text: "Luggage retrieval")
                                    ExpectationRow(icon: "bus.fill", text: "Bus and bike truck loading")
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Distance Info
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Distance", systemImage: "arrow.left.and.right")
                            .font(.headline)

                        HStack(spacing: 16) {
                            DistanceCard(
                                label: "From Start",
                                value: UserProfileManager.shared.formatDistanceInt(Int(checkpoint.mile)),
                                icon: "flag.fill"
                            )
                            DistanceCard(
                                label: "To Finish",
                                value: UserProfileManager.shared.formatDistanceInt(206 - Int(checkpoint.mile)),
                                icon: "flag.checkered"
                            )
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Stop Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    var checkpointIcon: String {
        switch checkpoint.type {
        case .start: return "flag.fill"
        case .restStop: return "fork.knife"
        case .miniStop: return "cup.and.saucer.fill"
        case .finish: return "flag.checkered"
        }
    }
}

struct HoursRow: View {
    let day: String
    let hours: String
    let isOpen: Bool

    var body: some View {
        HStack {
            Text(day)
                .fontWeight(.medium)
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(isOpen ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(hours)
                    .foregroundStyle(isOpen ? .primary : .secondary)
            }
        }
    }
}

struct AmenityCard: View {
    let amenity: String

    var icon: String {
        switch amenity.lowercased() {
        case "free food": return "fork.knife"
        case "food purchase": return "dollarsign.circle"
        case "water": return "drop.fill"
        case "restroom": return "toilet"
        case "medical": return "cross.fill"
        case "bike support": return "wrench.fill"
        case "overnight": return "moon.fill"
        case "bag drop": return "bag.fill"
        case "finisher meal": return "trophy.fill"
        case "merchandise": return "tshirt"
        case "bag pickup": return "bag.fill"
        default: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch amenity.lowercased() {
        case "free food": return .green
        case "food purchase": return .blue
        case "water": return .cyan
        case "restroom": return .purple
        case "medical": return .red
        case "bike support": return .orange
        case "overnight": return .indigo
        case "bag drop", "bag pickup": return .brown
        case "finisher meal": return .yellow
        case "merchandise": return .pink
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(amenity.capitalized)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ExpectationRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct DistanceCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AmenityBadge: View {
    let amenity: String

    var icon: String {
        switch amenity.lowercased() {
        case "free food": return "fork.knife"
        case "food purchase": return "dollarsign.circle"
        case "water": return "drop.fill"
        case "restroom": return "toilet"
        case "medical": return "cross.fill"
        case "bike support": return "wrench.fill"
        case "overnight": return "moon.fill"
        case "bag drop": return "bag.fill"
        case "finisher meal": return "trophy.fill"
        case "merchandise": return "tshirt.fill"
        case "bag pickup": return "bag.fill"
        default: return "circle.fill"
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
}

struct RouteStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Achievements View
struct AchievementsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Progress Summary
                    VStack(spacing: 16) {
                        HStack {
                            Text("Your Progress")
                                .font(.headline)
                            Spacer()
                            Text("6 of 13 Badges")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 12)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.orange)
                                    .frame(width: geometry.size.width * 0.46, height: 12)
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // STP Year Badges
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("STP Finisher")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                YearBadge(year: "2023", subtitle: "STP 2023", detail: "206 Miles", imageName: "stp_2023", earned: true)
                                YearBadge(year: "2024", subtitle: "STP 2024", detail: "206 Miles", imageName: "stp_2024", earned: true)
                                YearBadge(year: "2025", subtitle: "STP 2025", detail: "206 Miles", imageName: "stp_2025", earned: true)
                                YearBadge(year: "2026", subtitle: "STP 2026", detail: "206 Miles", imageName: "stp_2026", earned: true)
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Earned Badges
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Earned")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            AchievementBadge(icon: "figure.outdoor.cycle", title: "First Pedal", subtitle: "Start the ride", color: .green, earned: true)
                            AchievementBadge(icon: "50.circle.fill", title: "Halfway", subtitle: "Reach mile 103", color: .blue, earned: true)
                            AchievementBadge(icon: "flag.checkered", title: "Finisher", subtitle: "Complete 206 miles", color: .yellow, earned: true)
                        }
                        .padding(.horizontal)
                    }

                    // Locked Badges
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Locked")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            AchievementBadge(icon: "star.fill", title: "One Day", subtitle: "Finish in one day", color: .pink, earned: false)
                            AchievementBadge(icon: "repeat", title: "Veteran", subtitle: "Complete 2+ STPs", color: .brown, earned: false)
                            AchievementBadge(icon: "sunrise.fill", title: "Early Bird", subtitle: "Finish before noon", color: .orange, earned: false)
                            AchievementBadge(icon: "moon.stars.fill", title: "Night Owl", subtitle: "Ride after sunset", color: .indigo, earned: false)
                            AchievementBadge(icon: "figure.walk", title: "Rest Stop", subtitle: "Check in at all stops", color: .mint, earned: false)
                            AchievementBadge(icon: "hand.thumbsup.fill", title: "Supporter", subtitle: "Cheer 10 riders", color: .cyan, earned: false)
                        }
                        .padding(.horizontal)
                    }

                    // Milestones
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Milestones")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            MilestoneRow(title: "First Rest Stop", location: "Renton - Mile 18.3", completed: true)
                            MilestoneRow(title: "Quarter Way", location: "Mile 51.5", completed: true)
                            MilestoneRow(title: "Halfway Point", location: "Centralia - Mile 103", completed: false, isNext: true)
                            MilestoneRow(title: "Three Quarters", location: "Mile 154.5", completed: false)
                            MilestoneRow(title: "Finish Line", location: "Portland - Mile 206", completed: false)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Achievements")
        }
    }
}

struct AchievementBadge: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let earned: Bool
    var progress: Double? = nil

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(earned ? color.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 70, height: 70)

                if let progress = progress, !earned {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, lineWidth: 4)
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                }

                Image(systemName: earned ? icon : (progress != nil ? icon : "lock.fill"))
                    .font(.title2)
                    .foregroundStyle(earned ? color : (progress != nil ? color.opacity(0.6) : .gray))
            }

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(earned ? .primary : .secondary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct YearBadge: View {
    let year: String
    let subtitle: String
    let detail: String
    let imageName: String
    let earned: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if earned {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemGray4), Color(.systemGray5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    VStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                        Text(year)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(earned ? .orange : Color(.systemGray3), lineWidth: 3)
            )
            .shadow(color: earned ? .orange.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)

            Text(subtitle)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(earned ? .primary : .secondary)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 110)
    }
}

struct MilestoneRow: View {
    let title: String
    let location: String
    let completed: Bool
    var isNext: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(completed ? .green : (isNext ? .orange : Color(.systemGray4)))
                    .frame(width: 32, height: 32)

                if completed {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                } else if isNext {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(isNext ? .semibold : .regular)
                    if isNext {
                        Text("NEXT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange)
                            .foregroundStyle(.white)
                            .cornerRadius(4)
                    }
                }
                Text(location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Photos View
struct PhotosView: View {
    @State private var selectedStop = "All Stops"
    @State private var showingCamera = false
    let stops = ["All Stops", "Seattle", "Renton", "Puyallup", "Spanaway", "Yelm", "Centralia"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Post Photo Button
                    Button(action: { showingCamera = true }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Share a photo from the ride")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(.orange)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Rest Stop Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(stops, id: \.self) { stop in
                                StopFilterChip(title: stop, isSelected: selectedStop == stop) {
                                    selectedStop = stop
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Photo Feed
                    VStack(spacing: 20) {
                        PhotoPost(
                            username: "Sarah M.",
                            bib: "#4522",
                            location: "Puyallup Rest Stop",
                            timeAgo: "12 min ago",
                            caption: "Made it to Puyallup! 50 miles down, feeling strong 💪",
                            likes: 24,
                            comments: 5,
                            colorIndex: 0
                        )

                        PhotoPost(
                            username: "Mike C.",
                            bib: "#4523",
                            location: "On the road",
                            timeAgo: "28 min ago",
                            caption: "Beautiful views on the way to Spanaway!",
                            likes: 18,
                            comments: 3,
                            colorIndex: 1
                        )

                        PhotoPost(
                            username: "Team Cascade",
                            bib: "Group",
                            location: "Renton Rest Stop",
                            timeAgo: "1 hr ago",
                            caption: "Team photo at Renton! 🚴‍♂️🚴‍♀️🚴‍♂️",
                            likes: 45,
                            comments: 12,
                            isGroupPhoto: true,
                            colorIndex: 2
                        )

                        PhotoPost(
                            username: "Alex T.",
                            bib: "#3892",
                            location: "Seattle Start",
                            timeAgo: "3 hrs ago",
                            caption: "And we're off! STP 2025 here we go! 🎉",
                            likes: 89,
                            comments: 21,
                            colorIndex: 3
                        )

                        PhotoPost(
                            username: "Jordan L.",
                            bib: "#5102",
                            location: "Puyallup Rest Stop",
                            timeAgo: "18 min ago",
                            caption: "Refueling with some amazing banana bread from the volunteers!",
                            likes: 32,
                            comments: 8,
                            colorIndex: 4
                        )

                        PhotoPost(
                            username: "Emma W.",
                            bib: "#4520",
                            location: "On the road",
                            timeAgo: "45 min ago",
                            caption: "That hill was no joke but we made it!",
                            likes: 56,
                            comments: 14,
                            colorIndex: 5
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingCamera = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                NewPostView()
            }
        }
    }
}

struct StopFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? .orange : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct PhotoPost: View {
    let username: String
    let bib: String
    let location: String
    let timeAgo: String
    let caption: String
    let likes: Int
    let comments: Int
    var isGroupPhoto: Bool = false
    let colorIndex: Int

    let colors: [Color] = [.orange, .blue, .green, .purple, .pink, .teal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: isGroupPhoto ? "person.3.fill" : "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(isGroupPhoto ? .orange : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(username)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(bib)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Photo Placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(colors[colorIndex % colors.count].opacity(0.2))
                .frame(height: 250)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo.fill")
                            .font(.largeTitle)
                        Text("Photo")
                            .font(.caption)
                    }
                    .foregroundStyle(colors[colorIndex % colors.count])
                )

            // Caption
            Text(caption)
                .font(.subheadline)

            // Actions
            HStack(spacing: 24) {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                        Text("\(likes)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text("\(comments)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.thumbsup")
                        Text("Cheer")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct NewPostView: View {
    @Environment(\.dismiss) var dismiss
    @State private var caption = ""
    @State private var selectedLocation = "Current Location"
    let locations = ["Current Location", "Seattle Start", "Renton", "Puyallup", "Spanaway", "On the Road"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Photo Area
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                        .frame(height: 300)

                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.orange)
                        Text("Tap to take a photo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Location Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(locations, id: \.self) { location in
                                StopFilterChip(title: location, isSelected: selectedLocation == location) {
                                    selectedLocation = location
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Caption
                VStack(alignment: .leading, spacing: 8) {
                    Text("Caption")
                        .font(.headline)
                        .padding(.horizontal)

                    TextField("Share your ride experience...", text: $caption, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                Spacer()

                // Post Button
                Button(action: { dismiss() }) {
                    Text("Post to Feed")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.top)
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userProfile: UserProfileManager
    @State private var showingEditProfile = false
    @State private var showingNotifications = false
    @State private var showingSettings = false
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            if let image = userProfile.profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundStyle(.orange)
                            }

                            Text(userProfile.bibNumber)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }

                        Text(userProfile.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(userProfile.location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Label(ordinalSTP(userProfile.stpCount), systemImage: "bicycle")
                            Text("•")
                            Label(userProfile.rideType, systemImage: userProfile.rideType == "One-Day" ? "sun.max" : "moon.stars")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Ride Stats
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(userProfile.stpCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("STPs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("68.5")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Miles Today")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            Text("6")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Badges")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Badges
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Badges Earned")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                BadgeItem(icon: "figure.outdoor.cycle", title: "Started", color: .green)
                                BadgeItem(icon: "50.circle.fill", title: "50 Miles", color: .blue)
                                BadgeItem(icon: "sunrise.fill", title: "Early Bird", color: .orange)
                                BadgeItem(icon: "camera.fill", title: "Photog", color: .purple)
                                BadgeItem(icon: "person.2.fill", title: "Team Player", color: .pink)
                                BadgeItem(icon: "star.fill", title: "2023 STP", color: .yellow)
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Emergency Contact
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Emergency Contact")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack {
                            Image(systemName: "phone.circle.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text(userProfile.emergencyContactName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(userProfile.emergencyContactPhone)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: { showingEditProfile = true }) {
                                Text("Edit")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Options
                    VStack(spacing: 12) {
                        Button(action: { showingEditProfile = true }) {
                            ProfileOptionRow(icon: "pencil", title: "Edit Profile", color: .blue)
                        }
                        .buttonStyle(.plain)

                        Button(action: { showingNotifications = true }) {
                            ProfileOptionRow(icon: "bell.fill", title: "Notifications", color: .red)
                        }
                        .buttonStyle(.plain)

                        Button(action: { showingSettings = true }) {
                            ProfileOptionRow(icon: "gearshape.fill", title: "Settings", color: .gray)
                        }
                        .buttonStyle(.plain)

                        Button(action: { showingShareSheet = true }) {
                            ProfileOptionRow(icon: "square.and.arrow.up", title: "Share My Progress", color: .orange)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(userProfile: userProfile)
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsSettingsView(userProfile: userProfile)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(userProfile: userProfile)
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareProgressView(userProfile: userProfile)
            }
        }
    }

    func ordinalSTP(_ count: Int) -> String {
        let suffix: String
        switch count {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
        return "\(count)\(suffix) STP"
    }
}

struct ProfileOptionRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Badge Item
struct BadgeItem: View {
    let icon: String
    let title: String
    let color: Color
    var locked: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(locked ? Color(.systemGray4) : color.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: locked ? "lock.fill" : icon)
                    .font(.title2)
                    .foregroundStyle(locked ? .gray : color)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(locked ? .secondary : .primary)
        }
    }
}

// MARK: - Help View
struct HelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HelpCard(icon: "cross.circle.fill", title: "Medical Emergency", description: "Call 911 or find nearest medical tent", color: .red)
                    HelpCard(icon: "wrench.fill", title: "Bike Mechanical", description: "Find bike support or request SAG", color: .blue)
                    HelpCard(icon: "car.fill", title: "Request SAG Wagon", description: "Get a ride to the next checkpoint", color: .purple)
                    HelpCard(icon: "phone.fill", title: "Call Event Support", description: "(206) 555-0STP", color: .green)
                    HelpCard(icon: "map.fill", title: "I'm Lost", description: "Get directions back to the route", color: .orange)
                    HelpCard(icon: "person.fill.questionmark", title: "Find a Rider", description: "Locate someone in your group", color: .teal)
                }
                .padding()
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct HelpCard: View {
    let icon: String
    let title: String
    let description: String
    var color: Color = .blue

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Emergency View
struct EmergencyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "cross.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text("Emergency Assistance")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Your current location will be shared with emergency services")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Call 911")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "cross.fill")
                            Text("Medical Tent")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "car.fill")
                            Text("Request SAG Wagon")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 8) {
                    Text("Event Support Line")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("(206) 555-0STP")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.top, 40)
            .navigationTitle("Emergency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - FAQ View
struct FAQView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    FAQItem(question: "What is the STP route?", answer: "The Seattle to Portland Bicycle Classic covers 206 miles from the University of Washington in Seattle to Holladay Park in Portland, Oregon.")
                    FAQItem(question: "Where are the rest stops?", answer: "There are staffed rest stops every 10-15 miles with water, food, restrooms, and bike support. Major stops include Spanaway, Yelm, Centralia, and St. Helens.")
                    FAQItem(question: "What if I can't finish?", answer: "SAG (Support and Gear) wagons patrol the route and can give you a ride to the next checkpoint or finish. Use the Help button to request one.")
                    FAQItem(question: "How do I find my group?", answer: "Use the Riders tab to see your riding group's location and progress. You can also search for riders by name or bib number.")
                    FAQItem(question: "What's the cutoff time?", answer: "Two-day riders should reach Centralia by 7 PM on Day 1. One-day riders should reach Portland by 10 PM. SAG support ends at these times.")
                    FAQItem(question: "Where do I sleep overnight?", answer: "Two-day riders stay at Centralia College. Your gear truck will have your overnight bag waiting for you.")
                }
                .padding()
            }
            .navigationTitle("FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }

            if isExpanded {
                Text(answer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userProfile: UserProfileManager

    @State private var name: String = ""
    @State private var location: String = ""
    @State private var bibNumber: String = ""
    @State private var stpCount: Int = 1
    @State private var rideType: String = "Two-Day"
    @State private var emergencyContactName: String = ""
    @State private var emergencyContactPhone: String = ""

    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    let rideTypes = ["One-Day", "Two-Day"]

    var body: some View {
        NavigationStack {
            Form {
                // Profile Photo Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let image = userProfile.profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundStyle(.orange)
                            }

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text("Change Photo")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }

                            if userProfile.profileImage != nil {
                                Button("Remove Photo") {
                                    userProfile.saveProfileImage(nil)
                                }
                                .font(.caption)
                                .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // Personal Info
                Section("Personal Information") {
                    TextField("Name", text: $name)
                    TextField("Location", text: $location)
                    TextField("Bib Number", text: $bibNumber)
                }

                // Ride Info
                Section("Ride Information") {
                    Stepper("STP Count: \(stpCount)", value: $stpCount, in: 1...50)
                    Picker("Ride Type", selection: $rideType) {
                        ForEach(rideTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                }

                // Emergency Contact
                Section("Emergency Contact") {
                    TextField("Contact Name", text: $emergencyContactName)
                    TextField("Phone Number", text: $emergencyContactPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadProfile()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        userProfile.saveProfileImage(image)
                    }
                }
            }
        }
    }

    func loadProfile() {
        name = userProfile.name
        location = userProfile.location
        bibNumber = userProfile.bibNumber
        stpCount = userProfile.stpCount
        rideType = userProfile.rideType
        emergencyContactName = userProfile.emergencyContactName
        emergencyContactPhone = userProfile.emergencyContactPhone
    }

    func saveProfile() {
        userProfile.name = name
        userProfile.location = location
        userProfile.bibNumber = bibNumber
        userProfile.stpCount = stpCount
        userProfile.rideType = rideType
        userProfile.emergencyContactName = emergencyContactName
        userProfile.emergencyContactPhone = emergencyContactPhone
    }
}

// MARK: - Notifications Settings View
struct NotificationsSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userProfile: UserProfileManager

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Notifications", isOn: $userProfile.notificationsEnabled)
                } footer: {
                    Text("Turn off to disable all notifications from STP App")
                }

                Section("Ride Alerts") {
                    Toggle("Checkpoint Alerts", isOn: $userProfile.checkpointAlerts)
                        .disabled(!userProfile.notificationsEnabled)
                    Toggle("Weather Alerts", isOn: $userProfile.weatherAlerts)
                        .disabled(!userProfile.notificationsEnabled)
                }

                Section {
                    Toggle("Friend Updates", isOn: $userProfile.friendUpdates)
                        .disabled(!userProfile.notificationsEnabled)
                } header: {
                    Text("Social")
                } footer: {
                    Text("Get notified when friends reach checkpoints")
                }

                Section {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(.orange)
                        Text("Notification Preview")
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "flag.fill")
                                .foregroundStyle(.green)
                            Text("Checkpoint Alert")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Text("You're 2 miles from Spanaway Park!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Settings Tab View (for bottom tab bar)
struct SettingsTabView: View {
    @ObservedObject var userProfile: UserProfileManager
    @EnvironmentObject var locationManager: LocationManager

    let distanceUnits = ["Miles", "Kilometers"]
    let riderTypes = ["One-Day", "Two-Day"]
    let gpsOptions: [(String, Int)] = [
        ("Off", 0),
        ("Every 30 seconds", 30),
        ("Every 1 minute", 60),
        ("Every 5 minutes", 300),
        ("Every 10 minutes", 600)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Ride Type") {
                    Picker("Rider Type", selection: $userProfile.riderType) {
                        ForEach(riderTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if userProfile.riderType == "One-Day" {
                        Text("You're riding Seattle to Portland in one day! All checkpoints shown.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("You're riding over two days with an overnight stop in Centralia.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("GPS Location") {
                    Picker("Update Frequency", selection: $userProfile.gpsUpdateInterval) {
                        ForEach(gpsOptions, id: \.1) { option in
                            Text(option.0).tag(option.1)
                        }
                    }

                    if userProfile.gpsUpdateInterval == 0 {
                        Text("GPS is disabled. Nearest stop features won't work.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("GPS updates every \(gpsIntervalText). Uses battery.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Display") {
                    Picker("Distance Unit", selection: $userProfile.distanceUnit) {
                        ForEach(distanceUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }

                    Toggle("Dark Mode", isOn: $userProfile.darkMode)
                }

                Section("Notifications") {
                    Toggle("Checkpoint Alerts", isOn: $userProfile.checkpointAlerts)

                    if userProfile.checkpointAlerts {
                        Text("You'll get notified when you're within 1 mile of a checkpoint.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Weather Alerts", isOn: $userProfile.weatherAlerts)

                    if userProfile.weatherAlerts {
                        Text("Coming soon - get alerts for rain or severe weather on the route.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: userProfile.checkpointAlerts) { _, newValue in
                    locationManager.checkpointAlertsEnabled = newValue
                    if newValue {
                        NotificationManager.shared.requestPermission()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://cascade.org/stp")!) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(.blue)
                            Text("STP Website")
                                .foregroundStyle(.primary)
                        }
                    }

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.gray)
                            Text("Privacy Policy")
                                .foregroundStyle(.primary)
                        }
                    }

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.gray)
                            Text("Terms of Service")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onChange(of: userProfile.gpsUpdateInterval) { _, newValue in
            // Update location manager when GPS setting changes
            if newValue == 0 {
                locationManager.stopTracking()
            } else {
                locationManager.updateInterval = TimeInterval(newValue)
                locationManager.startTracking()
            }
        }
    }

    var gpsIntervalText: String {
        switch userProfile.gpsUpdateInterval {
        case 30: return "30 seconds"
        case 60: return "1 minute"
        case 300: return "5 minutes"
        case 600: return "10 minutes"
        default: return "\(userProfile.gpsUpdateInterval) seconds"
        }
    }
}

// MARK: - Settings View (for sheet presentation)
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userProfile: UserProfileManager

    let distanceUnits = ["Miles", "Kilometers"]

    var body: some View {
        NavigationStack {
            Form {
                // App Icon Preview at top
                Section {
                    VStack(spacing: 12) {
                        AppIconView(size: 120)
                        Text("STP App Icon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(action: {
                            saveAppIcon()
                        }) {
                            Label("Export to Photos", systemImage: "square.and.arrow.down")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section("Display") {
                    Picker("Distance Unit", selection: $userProfile.distanceUnit) {
                        ForEach(distanceUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }

                    Toggle("Dark Mode", isOn: $userProfile.darkMode)
                }

                Section("Data") {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Export Ride Data")
                                .foregroundStyle(.primary)
                        }
                    }

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundStyle(.green)
                            Text("Sync with Health App")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.gray)
                            Text("Privacy Policy")
                                .foregroundStyle(.primary)
                        }
                    }

                    Button(action: {}) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.gray)
                            Text("Terms of Service")
                                .foregroundStyle(.primary)
                        }
                    }
                }

            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Share Progress View
struct ShareProgressView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var userProfile: UserProfileManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview Card
                VStack(spacing: 16) {
                    HStack {
                        if let image = userProfile.profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundStyle(.orange)
                        }

                        VStack(alignment: .leading) {
                            Text(userProfile.name)
                                .font(.headline)
                            Text("STP 2026 • \(userProfile.bibNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    VStack(spacing: 8) {
                        Text("68.5 miles")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("33% Complete")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 12)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.orange)
                                    .frame(width: geometry.size.width * 0.33, height: 12)
                            }
                        }
                        .frame(height: 12)
                    }

                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.green)
                        Text("Seattle")
                        Spacer()
                        Text("Portland")
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)

                Text("Share your progress with friends and family!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Share Options
                VStack(spacing: 12) {
                    ShareButton(icon: "message.fill", title: "Messages", color: .green)
                    ShareButton(icon: "camera.fill", title: "Instagram Story", color: .purple)
                    ShareButton(icon: "square.and.arrow.up", title: "More Options", color: .blue)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Share Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ShareButton: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.white)
                    .frame(width: 30)
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding()
            .background(color)
            .cornerRadius(12)
        }
    }
}

#Preview {
    ContentView()
}
