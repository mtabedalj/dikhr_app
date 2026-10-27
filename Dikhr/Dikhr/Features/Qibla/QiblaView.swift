import SwiftUI
import CoreLocation
import MapKit
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
    // Bumped by the bottom button to re-fit the map on the location.
    @State private var fitToken = 0

    var body: some View {
        VStack(spacing: 0) {
            topBar
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
                .frame(maxHeight: .infinity)
            } else if CLLocationManager.headingAvailable() {
                VStack(spacing: 20) {
                    dial
                    degreesReadout
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                // Live capture (/tmp/athkar_live_6b.png — REAL app's قِبلة page
                // on a compass-less device): dark map + green bearing ray +
                // verbatim disclaimer + black bottom bar.
                mapFallback
            }
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    // MARK: top bar — centered white title + top-right dark round back chevron
    // (same style as AthkarSalahPageView's back button; the bar itself is
    // pinned LTR so the chevron lands at the right edge like the capture).

    private var topBar: some View {
        ZStack {
            Text(settings.t("القبلة", "Qibla"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    // MARK: no-compass fallback — dark map with the qibla ray

    /// Current location, falling back to the selected city so the page still
    /// works before (or without) a location fix.
    private var fallbackCoordinate: CLLocationCoordinate2D {
        controller.location?.coordinate
            ?? CLLocationCoordinate2D(latitude: DikhrShared.city.lat, longitude: DikhrShared.city.lng)
    }

    private var mapFallback: some View {
        VStack(spacing: 0) {
            Text(settings.t("هذا الجهاز لا يدعم البوصلة. استخدم الخريطة لمعرفة اتجاه مكة.",
                            "This device has no compass. Use the map to find the direction of Makkah."))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 0.92, green: 0.90, blue: 0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
            QiblaMapView(coordinate: fallbackCoordinate,
                         bearing: controller.qiblaBearing,
                         fitToken: fitToken)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
            Button {
                fitToken += 1
            } label: {
                Text(settings.t("عرض الاتجاه إلى مكة", "Show direction to Makkah"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
            }
            .buttonStyle(.plain)
        }
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

// MARK: - no-compass map (dark MKMapView + bearing ray + location disc)
//
// Live capture ground truth (/tmp/athkar_live_6b.png — the REAL app's qibla
// page reached from the athkar home's القبلة chip, without a working compass):
//   - dark-style Apple Map showing the current area (Dearborn Heights here),
//     rendered by the system MKMapView itself (system attribution/legal text).
//   - a translucent gray circle outline (~55pt) with a small gray dot at its
//     center marking the location.
//   - a bright green ~4pt line from the location toward Makkah — the qibla
//     bearing ray drawn on the map (straight segment long enough to cover the
//     screen).
//   - bottom black bar with centered bold white "عرض الاتجاه إلى مكة", a tap
//     action that recenters the map + re-fits the ray.

/// MapKit annotation for Dikhr's own gray circle-with-dot location marker.
final class QiblaLocationAnnotation: MKPointAnnotation {}

final class QiblaLocationAnnotationView: MKAnnotationView {

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 55, height: 55)
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let circle = rect.insetBy(dx: 1.5, dy: 1.5)
        // Translucent gray disc fill + lighter gray outline.
        ctx.setFillColor(UIColor(white: 0.72, alpha: 0.18).cgColor)
        ctx.fillEllipse(in: circle)
        ctx.setStrokeColor(UIColor(white: 0.85, alpha: 0.55).cgColor)
        ctx.setLineWidth(3)
        ctx.strokeEllipse(in: circle)
        // Small gray dot at the center with a light ring.
        let dot = CGRect(x: rect.midX - 7, y: rect.midY - 7, width: 14, height: 14)
        ctx.setFillColor(UIColor(white: 0.42, alpha: 1).cgColor)
        ctx.fillEllipse(in: dot)
        ctx.setStrokeColor(UIColor(white: 0.92, alpha: 0.8).cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: dot.insetBy(dx: -1, dy: -1))
    }
}

private struct QiblaMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let bearing: Double
    let fitToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var installed: CLLocationCoordinate2D?
        var lastFitToken = -1

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolylineRenderer(polyline: line)
            r.strokeColor = UIColor(red: 0.16, green: 0.82, blue: 0.28, alpha: 1)
            r.lineWidth = 4
            r.lineCap = .round
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is QiblaLocationAnnotation else { return nil }
            return QiblaLocationAnnotationView(annotation: annotation, reuseIdentifier: "QiblaLocation")
        }

        func install(on map: MKMapView, coordinate: CLLocationCoordinate2D, bearing: Double) {
            map.removeOverlays(map.overlays)
            map.removeAnnotations(map.annotations)
            // Straight great-circle segment (300 km) covering the visible screen.
            let dest = destinationCoordinate(from: coordinate, bearingDeg: bearing,
                                             distanceMeters: 300_000)
            let ray = MKGeodesicPolyline(coordinates: [coordinate, dest], count: 2)
            map.addOverlay(ray, level: .aboveRoads)
            let marker = QiblaLocationAnnotation()
            marker.coordinate = coordinate
            map.addAnnotation(marker)
            setRegion(on: map, coordinate: coordinate)
            installed = coordinate
        }

        func setRegion(on map: MKMapView, coordinate: CLLocationCoordinate2D) {
            let span = MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
            map.setRegion(MKCoordinateRegion(center: coordinate, span: span), animated: false)
        }
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        // Dark appearance via trait override; standard dark configuration.
        map.overrideUserInterfaceStyle = .dark
        map.showsUserLocation = false
        map.showsCompass = false
        if let config = map.preferredConfiguration as? MKStandardMapConfiguration {
            config.pointOfInterestFilter = .includingAll
            map.preferredConfiguration = config
        }
        context.coordinator.install(on: map, coordinate: coordinate, bearing: bearing)
        context.coordinator.lastFitToken = fitToken
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        map.delegate = c
        if c.installed == nil
            || abs(c.installed!.latitude - coordinate.latitude) > 0.005
            || abs(c.installed!.longitude - coordinate.longitude) > 0.005 {
            c.install(on: map, coordinate: coordinate, bearing: bearing)
        }
        if c.lastFitToken != fitToken {
            c.lastFitToken = fitToken
            c.setRegion(on: map, coordinate: coordinate)
        }
    }
}

/// Geographic destination point along a bearing (great-circle formula, meters).
private func destinationCoordinate(from: CLLocationCoordinate2D,
                                   bearingDeg: Double,
                                   distanceMeters: Double) -> CLLocationCoordinate2D {
    let R = 6_371_000.0
    let b = bearingDeg * .pi / 180
    let φ1 = from.latitude * .pi / 180
    let λ1 = from.longitude * .pi / 180
    let δ = distanceMeters / R
    let φ2 = asin(sin(φ1) * cos(δ) + cos(φ1) * sin(δ) * cos(b))
    let λ2 = λ1 + atan2(sin(b) * sin(δ) * cos(φ1), cos(δ) - sin(φ1) * sin(φ2))
    return CLLocationCoordinate2D(latitude: φ2 * 180 / .pi, longitude: λ2 * 180 / .pi)
}

extension Double {
    var normalizedDegrees: Double {
        let v = truncatingRemainder(dividingBy: 360)
        return v < 0 ? v + 360 : v
    }
}