import SwiftUI
import CoreLocation

/// App-wide location tracking: prayer times, alarms and the widget all follow
/// the user's location when available, falling back to the chosen city.
/// Each fix is snapped to the nearest bundled city for a real Arabic name.
@MainActor
final class LocationController: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationController()

    struct Fix: Equatable {
        var latitude: Double
        var longitude: Double
        var cityName: String
        var country: String
        var tag: String = ""
    }

    @Published var fix: Fix?
    @Published var denied = false

    private let manager = CLLocationManager()
    private var lastGeocoded: Fix?
    private let geocoder = CLGeocoder()

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        applyAuthorizationStatus(manager.authorizationStatus, manager)
    }

    func start() {
        applyAuthorizationStatus(manager.authorizationStatus, manager)
    }

    private func applyAuthorizationStatus(_ status: CLAuthorizationStatus, _ manager: CLLocationManager) {
        denied = (status == .denied || status == .restricted)
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if !denied {
            manager.startUpdatingLocation()
        }
    }

    private var pendingGeocode = false

    private func handle(_ coordinate: CLLocationCoordinate2D) {
        // 1) Instant: nearest bundled city (MENA/Europe list — many places fall
        //    through). 2) Authoritative: real reverse geocoding in the device
        //    locale (the original relies on CLGeocoder the same way).
        let nearest = SettingsStore.nearestCity(latitude: coordinate.latitude,
                                                longitude: coordinate.longitude)
        publish(coordinate: coordinate,
                city: nearest?.name ?? DikhrStrings.tr("موقعك الحالي", "Your location"),
                country: nearest?.country ?? "",
                tag: nearest?.tag ?? "")
        geocodeLatest(coordinate)
    }

    private func geocodeLatest(_ coordinate: CLLocationCoordinate2D) {
        guard !pendingGeocode else { return }
        pendingGeocode = true
        let geocoder = geocoder
        geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude,
                                                   longitude: coordinate.longitude)) { [weak self] placemarks, _ in
            Task { @MainActor in
                self?.pendingGeocode = false
                guard let place = placemarks?.first else { return }
                let city = place.locality ?? place.subLocality ?? place.name ?? DikhrStrings.tr("موقعك الحالي", "Your location")
                self?.publish(coordinate: coordinate, city: city,
                              country: place.country ?? "",
                              tag: "")
            }
        }
    }

    private func publish(coordinate: CLLocationCoordinate2D, city: String, country: String, tag: String) {
        let named = Fix(latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        cityName: city,
                        country: country,
                        tag: tag)
        if lastGeocoded == named { return }
        lastGeocoded = named
        self.fix = named
        NotificationCenter.default.post(name: .dikhrLocationNamed, object: named)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        let coordinate = latest.coordinate
        Task { @MainActor in handle(coordinate) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in applyAuthorizationStatus(status, manager) }
    }
}

extension Notification.Name {
    static let dikhrLocationNamed = Notification.Name("dikhr-location-named")
}