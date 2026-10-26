import SwiftUI
import UIKit

struct CounterView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var counters: [SavedCounter] = CounterStore.load()
    @State private var selectedIndex = 0
    @State private var showManage = false
    @State private var lastTapAt = Date.distantPast
    @StateObject private var voice = VoiceCounterController()

    private var current: SavedCounter? { counters.indices.contains(selectedIndex) ? counters[selectedIndex] : nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Picker(settings.t("العداد", "Counter"), selection: $selectedIndex) {
                    if counters.isEmpty {
                        Text(settings.t("لا عدادات", "No counters")).tag(0)
                    } else {
                        ForEach(Array(counters.enumerated()), id: \.offset) { idx, counter in
                            Text(counter.name).tag(idx)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Spacer()

                if let counter = current {
                    ZStack {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.15), lineWidth: 12)
                        Circle()
                            .trim(from: 0, to: progress(counter))
                            .stroke(Color.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.15), value: counter.count)
                        VStack(spacing: 6) {
                            Text("\(counter.count)")
                                .font(.system(size: 84, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentShape(Rectangle())
                                .onTapGesture { increment() }
                            Text(counter.target > 0 ? settings.t("من \(counter.target)", "of \(counter.target)")
                                                    : settings.t("حرة", "Free"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 280, height: 280)
                    .contentShape(Circle())
                    .onTapGesture { increment() }
                    // Original evidence: 'للتصفير اضغط مطولًا ٣ ثوان'
                    // ("Press and hold 3 seconds to reset") /
                    // '• اضغط ضغطة مطولة على العداد لتصفيره.'
                    .onLongPressGesture(minimumDuration: 3) {
                        guard counter.count != 0 else { return }
                        withAnimation { setCount(counter, 0) }
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }

                    HStack(spacing: 16) {
                        Button(settings.t("تصفير", "Reset")) {
                            withAnimation { setCount(counter, 0) }
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                        .buttonStyle(.bordered)
                        Text(settings.t("للتصفير اضغط مطولًا ٣ ثوان", "Press and hold 3 seconds to reset"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Button {
                            showManage = true
                        } label: {
                            Label(settings.t("العدادات", "Counters"), systemImage: "list.bullet")
                        }
                        .buttonStyle(.bordered)
                    }
                    LiveCounterToggle { current ?? counters.first }
                } else {
                    Text(settings.t("لا عدادات بعد", "No counters yet"))
                        .foregroundStyle(.secondary)
                    Button(settings.t("إضافة عداد", "Add Counter")) { showManage = true }
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .navigationTitle(settings.t("العداد", "Counter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            if let c = current {
                                voice.onDhikrDetected = {
                                    DispatchQueue.main.async {
                                        if let c = self.current {
                                            self.setCount(c, c.count + 1)
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    }
                                }
                                voice.toggle(dhikrName: c.name)
                            }
                        } label: {
                            Image(systemName: voice.isListening ? "mic.fill" : "mic")
                                .foregroundStyle(voice.isListening ? Color.red : Color.accentColor)
                        }
                        Button {
                            if let c = current { withAnimation { setCount(c, c.count + 1) } }
                        } label: { Image(systemName: "plus.circle") }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if voice.isListening || voice.liveTranscript.isEmpty == false {
                    VStack(spacing: 4) {
                        Label(settings.t("عدّاد الصوت يعمل — ردّد بصوت واضح",
                                         "Voice counter active — recite audibly"), systemImage: "waveform")
                            .font(.footnote.bold())
                            .foregroundStyle(.red)
                        if !voice.liveTranscript.isEmpty {
                            Text(voice.liveTranscript)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        if let err = voice.errorText {
                            Text(err).font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.thinMaterial))
                    .padding(.bottom, 6)
                }
            }
            .sheet(isPresented: $showManage) {
                ManageCountersView(counters: $counters)
            }
        }
    }

    private func progress(_ counter: SavedCounter) -> CGFloat {
        guard counter.target > 0 else { return 0 }
        return CGFloat(min(counter.count, counter.target)) / CGFloat(counter.target)
    }

    private func increment() {
        guard let counter = current else { return }
        withAnimation(.spring(duration: 0.2)) { setCount(counter, counter.count + 1) }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        lastTapAt = Date()
    }

    private func setCount(_ counter: SavedCounter, _ value: Int) {
        guard let idx = counters.firstIndex(where: { $0.id == counter.id }) else { return }
        counters[idx].count = value
        CounterStore.save(counters)
        NotificationCenter.default.post(name: Notification.Name("dikhr-counter-changed"), object: nil)
    }
}

struct ManageCountersView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Binding var counters: [SavedCounter]
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var newTarget = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(settings.t("عداد جديد", "New Counter")) {
                    TextField(settings.t("الاسم (مثال: سبحان الله)", "Name (e.g. SubhanAllah)"), text: $newName)
                    TextField(settings.t("الهدف (اختياري)", "Target (optional)"), text: $newTarget)
                        .keyboardType(.numberPad)
                    Button(settings.t("إضافة", "Add")) {
                        let t = Int(newTarget) ?? 0
                        let existing = Set(counters.map(\.name))
                        var name = newName.isEmpty ? settings.t("تسبيح", "Tasbih") : newName
                        var n = 2
                        while existing.contains(name) {
                            name = "\(newName.isEmpty ? settings.t("تسبيح", "Tasbih") : newName) \(n)"
                            n += 1
                        }
                        counters.append(SavedCounter(name: name, count: 0, target: t))
                        CounterStore.save(counters)
                        newName = ""
                        newTarget = ""
                    }
                    .disabled(newName.isEmpty && newTarget.isEmpty)
                }
                Section(settings.t("العدادات المحفوظة", "Saved Counters")) {
                    ForEach($counters) { $counter in
                        HStack {
                            TextField(settings.t("الاسم", "Name"), text: $counter.name)
                                .onChange(of: counter) { _ in CounterStore.save(counters) }
                            Spacer()
                            Text("\(counter.count)")
                                .monospacedDigit()
                                .bold()
                            if counter.target > 0 {
                                Text("/ \(counter.target)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { idx in
                        counters.remove(atOffsets: idx)
                        CounterStore.save(counters)
                    }
                }
            }
            .navigationTitle(settings.t("إدارة العدادات", "Manage Counters"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("تم", "Done")) { dismiss() }
                }
            }
        }
    }
}