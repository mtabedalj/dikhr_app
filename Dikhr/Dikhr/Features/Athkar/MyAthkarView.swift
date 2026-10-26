import SwiftUI

struct MyAthkarItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var count: Int = 0
    var target: Int = 0
    var isFavorite: Bool = false
}

/// أذكاري: user-authored dhikr with private counters (like the original's
/// My Athkar + Notes feature).
enum MyAthkarStore {
    static func load() -> [MyAthkarItem] {
        guard let data = UserDefaults.standard.data(forKey: "myAthkar"),
              let list = try? JSONDecoder().decode([MyAthkarItem].self, from: data)
        else { return [] }
        return list
    }
    static func save(_ items: [MyAthkarItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: "myAthkar")
        }
    }
}

struct MyAthkarView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var items: [MyAthkarItem] = MyAthkarStore.load()
    @State private var editing: MyAthkarItem?
    @State private var composing = false

    var body: some View {
        List {
            if items.isEmpty {
                Text(settings.t("أضف أذكارك الخاصة، وسجّل تكرارها هنا",
                                "Add your own athkar; track repetitions here"))
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        increment(item, items)
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1.5)
                            Text("\(ArabicNumberRender.string(item.count))")
                                .font(.caption.bold())
                                .foregroundStyle(.accent)
                        }
                        .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    NavigationLink {
                        if let idx = items.firstIndex(where: { $0.id == item.id }) {
                            MyAthkarDetailView(item: $items[idx], afterChange: { MyAthkarStore.save(items) })
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            if !item.body.isEmpty {
                                Text(RichHTML.plainText(item.body))
                                    .font(.athkarBody)
                                    .lineSpacing(4)
                                    .lineLimit(3)
                                    .foregroundStyle(.secondary)
                            }
                            if item.target > 0 {
                                Text(settings.t("التكرار: \(item.count)/\(item.target)",
                                                "Repeats: \(item.count)/\(item.target)"))
                                    .font(.caption2)
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .swipeActions {
                    Button(settings.t("تعديل", "Edit")) {
                        editing = item
                    }
                    .tint(.accent)
                    Button(settings.t("حذف", "Delete"), role: .destructive) {
                        items.removeAll { $0.id == item.id }
                        MyAthkarStore.save(items)
                    }
                }
            }
        }
        .navigationTitle(settings.t("أذكاري", "My Athkar"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    composing = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $composing, onDismiss: { load() }) {
            MyAthkarEditor(item: nil) { saved in
                items.append(saved)
                MyAthkarStore.save(items)
            }
        }
        .sheet(item: $editing, onDismiss: { load() }) { current in
            MyAthkarEditor(item: current) { saved in
                if let idx = items.firstIndex(where: { $0.id == current.id }) {
                    items[idx] = saved
                    MyAthkarStore.save(items)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        items = MyAthkarStore.load()
    }

    private func increment(_ item: MyAthkarItem, _ list: [MyAthkarItem]) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].count += 1
        MyAthkarStore.save(items)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        StreaksStore.addAthkar(1)
    }
}

struct MyAthkarEditor: View {
    @EnvironmentObject private var settings: SettingsStore
    var item: MyAthkarItem?
    var onDone: (MyAthkarItem) -> Void

    @State private var title = ""
    @State private var bodyHTML = ""
    @State private var target = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(settings.t("العنوان", "Title"), text: $title)
                        .bold()
                        .font(.headline)
                        .padding(.vertical, 4)
                    RichEditorField(html: $bodyHTML, placeholder: settings.t("اكتب ذكرك… (نص غني)", "Write your athkar… (rich text)"))
                    HStack(spacing: 8) {
                        Text(settings.t("الهدف (اختياري)", "Target (optional)"))
                            .foregroundStyle(.secondary)
                        TextField("0", text: $target)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    .font(.subheadline)
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(item == nil ? settings.t("ذكر جديد", "New Athkar") : settings.t("تعديل", "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(settings.t("إلغاء", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("حفظ", "Save")) {
                        var saved = item ?? MyAthkarItem(title: "", body: "")
                        saved.title = title.isEmpty ? settings.t("ذكري", "My Athkar") : title
                        saved.body = bodyHTML
                        saved.target = Int(target) ?? saved.target
                        onDone(saved)
                        dismiss()
                    }
                    .disabled(title.isEmpty && RichHTML.plainText(bodyHTML).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let item {
                    title = item.title
                    bodyHTML = item.body
                    target = item.target > 0 ? "\(item.target)" : ""
                }
            }
        }
    }
}

enum ArabicNumberRender {
    static func string(_ n: Int) -> String {
        let arabic = ["٠","١","٢","٣","٤","٥","٦","٧","٨","٩"]
        return String(n).map { $0.isNumber ? arabic[Int(String($0)) ?? 0] ?? "" : String($0) }.joined()
    }
}