import SwiftUI
import WatchKit

/// Tasbih counter page. Shares the saved counters with the phone through the
/// app group (DikhrShared) and reports taps to the phone via WatchConnectivity.
struct WatchCounterView: View {
    @ObservedObject private var receiver = WatchSessionReceiver.shared
    @State private var counters: [SavedCounter] = DikhrShared.loadCounters()
    @State private var currentIndex = 0
    @State private var pulse = false
    @State private var showReset = false

    private var current: SavedCounter? { counters.indices.contains(currentIndex) ? counters[currentIndex] : nil }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    showReset = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)

                Spacer()

                if counters.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            currentIndex = (currentIndex + 1) % counters.count
                        }
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 4)

            Spacer()

            VStack(spacing: 2) {
                Text(current?.name ?? "العدّاد")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(current?.count ?? 0)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(pulse ? WatchTheme.accent : Color.white)
                    .animation(.easeOut(duration: 0.15), value: pulse)
                if let target = current?.target, target > 0 {
                    Text("من \(target)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .watchCountersChanged)) { _ in
                counters = DikhrShared.loadCounters()
                clampIndex()
            }
            .onAppear {
                counters = DikhrShared.loadCounters()
                clampIndex()
            }
            .confirmationDialog("تصفير العدّاد؟", isPresented: $showReset, titleVisibility: .visible) {
                Button("تصفير", role: .destructive) {
                    persist { $0.count = 0 }
                    WKInterfaceHelper.haptic(.notification)
                }
            }

            Spacer()

            Button {
                increment()
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

    private func clampIndex() {
        if currentIndex >= counters.count { currentIndex = max(0, counters.count - 1) }
    }

    private func persist(_ transform: (inout SavedCounter) -> Void) {
        guard let id = current?.id,
              let idx = counters.firstIndex(where: { $0.id == id }) else { return }
        transform(&counters[idx])
        DikhrShared.saveCounters(counters)
        receiver.sendCounterUpdate(counters)
    }

    private func increment() {
        persist { $0.count += 1 }
    }
}