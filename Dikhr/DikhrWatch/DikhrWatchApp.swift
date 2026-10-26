import SwiftUI
import WatchKit

@main
struct DikhrWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchCounterView()
            WatchPrayerTimesView()
        }
        .tabViewStyle(.page)
    }
}

/// Tasbih counter for the watch (matches the original's watch widget/counter).
struct WatchCounterView: View {
    @State private var counters: [SavedCounter] = DikhrShared.loadCounters()
    @State private var currentIndex = 0
    @State private var pulse = false

    private var current: SavedCounter? { counters.indices.contains(currentIndex) ? counters[currentIndex] : nil }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    persist { $0.count = 0 }
                    WKInterfaceHelper.haptic(.notification)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                Spacer()
                if counters.count > 1 {
                    Button {
                        currentIndex = (currentIndex + 1) % counters.count
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 4)

            Spacer()
            Text("\(current?.count ?? 0)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(pulse ? Color.orange : Color.green)
                .animation(.easeOut(duration: 0.15), value: pulse)
            Text(current.map { $0.target > 0 ? "من \($0.target)" : "" } ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()

            Button {
                withAnimation(.spring(duration: 0.2)) {
                    increment()
                }
                WKInterfaceHelper.haptic(.click)
                pulse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { pulse = false }
            } label: {
                Text("عدَّ")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func persist(_ transform: (inout SavedCounter) -> Void) {
        guard let id = current?.id,
              let idx = counters.firstIndex(where: { $0.id == id }) else { return }
        transform(&counters[idx])
        DikhrShared.saveCounters(counters)
    }

    private func increment() {
        persist { $0.count += 1 }
    }
}

/// Next-prayer view for the watch.
struct WatchPrayerTimesView: View {
    @State private var times: PrayerTimes?

    var body: some View {
        List {
            if let t = times {
                prayerRow("الفجر", t.fajr)
                prayerRow("الشروق", t.sunrise)
                prayerRow("الظهر", t.dhuhr)
                prayerRow("العصر", t.asr)
                prayerRow("المغرب", t.maghrib)
                prayerRow("العشاء", t.isha)
            } else {
                Text("بانتظار المواقيت…").font(.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .onAppear(perform: compute)
        .containerBackground(for: .navigation) { Color.black.opacity(0) }
    }

    private func compute() {
        let city = DikhrShared.city
        let method = DikhrMethodLoader.method(id: DikhrShared.methodID)
        times = PrayerTimesEngine.calculate(method: method, lat: city.lat, lng: city.lng, date: Date(), timeZone: .current)
    }

    private func prayerRow(_ name: String, _ date: Date) -> some View {
        HStack {
            Text(name).font(.footnote)
            Spacer()
            Text(date, format: .dateTime.hour().minute())
                .font(.footnote.bold())
                .monospacedDigit()
                .foregroundStyle(.green)
        }
    }
}

/// Watch haptics helper.
enum WKInterfaceHelper {
    static func haptic(_ style: WKHapticType) {
        WKInterfaceDevice.current().play(style)
    }
}