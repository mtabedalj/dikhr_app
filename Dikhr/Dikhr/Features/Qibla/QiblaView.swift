import SwiftUI
import CoreLocation
import CoreMotion

@MainActor
final class QiblaController: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double = 0
    @Published var headingAccuracy: Double = 0
    @Published var location: CLLocation?
    @Published var denied = false

    private let manager = CLLocationManager()
    private let kaaba = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            denied = true
            return
        }
        denied = false
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingHeading()
        manager.stopUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.location = loc
            self.denied = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            // headingHeading is relative to the device's "landscape left" reference on
            // iPads with no compass; trueHeading is absolute.
            self.heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            self.headingAccuracy = newHeading.headingAccuracy
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.denied = (status == .denied || status == .restricted)
            if !self.denied {
                manager.startUpdatingLocation()
                if CLLocationManager.headingAvailable() {
                    manager.startUpdatingHeading()
                }
            }
        }
    }

    /// Great-circle initial bearing from here to the Kaaba, degrees clockwise from true north.
    var qiblaBearing: Double {
        let from = location?.coordinate
            ?? CLLocationCoordinate2D(latitude: DikhrShared.city.lat, longitude: DikhrShared.city.lng)
        return bearing(from: from, to: kaaba)
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let φ1 = from.latitude * .pi / 180
        let φ2 = to.latitude * .pi / 180
        let Δλ = (to.longitude - from.longitude) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let θ = atan2(y, x)
        return ((θ * 180 / .pi) + 360).truncatingRemainder(dividingBy: 360)
    }

    var compassRotation: Angle { .degrees(-heading) }
    var qiblaRotation: Angle { .degrees((qiblaBearing - heading)) }
}

struct QiblaView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var controller = QiblaController()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            if controller.denied {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(settings.t("الموقع غير مُفعّل", "Location Disabled"))
                        .font(.headline)
                    Button(settings.t("فتح الإعدادات", "Open Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                dial
                degreesReadout
            }
            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle(settings.t("اتجاه القبلة", "Qibla Direction"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.12), lineWidth: 2)

            // Cardinal ring (rotates against heading)
            ForEach(0..<32, id: \.self) { tick in
                Rectangle()
                    .fill(Color.secondary.opacity(tick % 8 == 0 ? 0.8 : 0.25))
                    .frame(width: tick % 8 == 0 ? 2.5 : 1, height: tick % 8 == 0 ? 16 : 8)
                    .offset(y: -148)
                    .rotationEffect(.degrees(Double(tick) * 11.25) + controller.compassRotation)
            }

            // Qibla arrow
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 70)
                    .offset(y: -90)
                Text(settings.t("قبلـة", "Qibla"))
                    .font(.caption.bold())
                    .foregroundStyle(.accent)
                    .offset(y: -40)
            }
            .rotationEffect(controller.qiblaRotation)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: controller.qiblaRotation.degrees)

            VStack {
                Image(systemName: "location.north.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .offset(x: 0, y: -130)
        }
        .frame(width: 300, height: 300)
    }

    private var degreesReadout: some View {
        VStack(spacing: 4) {
            Text("\(Int((controller.qiblaBearing - controller.heading).normalizedDegrees))°")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.accent)
            Text(settings.t("درجة عن الشمال", "Degrees from North"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "compass.drawing")
                Text(controller.location != nil
                     ? settings.t("قياس الاتجاه بالبوصلة — أدر الجهاز حتى يشير السهم لأعلى",
                                  "Measuring by compass — turn the device until the arrow points up")
                     : settings.t("بانتظار الموقع…", "Waiting for location…"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

extension Double {
    var normalizedDegrees: Double {
        let v = truncatingRemainder(dividingBy: 360)
        return v < 0 ? v + 360 : v
    }
}