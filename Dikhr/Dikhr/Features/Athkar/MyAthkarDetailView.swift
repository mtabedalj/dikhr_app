import SwiftUI
import WebKit

/// Full-page reader for a single My Athkar item: renders the item's rich
/// HTML body in a WKWebView and keeps the athkar counter working, tap-for-tap
/// like the list row.
struct MyAthkarDetailView: View {
    @EnvironmentObject private var settings: SettingsStore
    @Binding var item: MyAthkarItem
    /// Persists the change made from this screen (list passes a save closure).
    var afterChange: (() -> Void)? = nil

    @State private var target = ""
    @State private var showTargetField = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                counterCard

                if !item.body.isEmpty {
                    AthkarRichWebView(html: item.body)
                        .frame(minHeight: 220)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.secondarySystemGroupedBackground))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                targetEditing
            }
            .padding()
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Counter (kept interactive, like the original's notes page)

    private var counterCard: some View {
        HStack(spacing: 20) {
            Button {
                tap()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 2)
                    Text("\(ArabicNumberRender.string(item.count))")
                        .font(.title2.bold())
                        .foregroundStyle(.accent)
                }
                .frame(width: 84, height: 84)
            }
            .accessibilityLabel(settings.t("عد التكرار", "Repeat counter"))

            VStack(alignment: .leading, spacing: 6) {
                if item.target > 0 {
                    Text(settings.t("التكرار: \(item.count)/\(item.target)",
                                    "Repeats: \(item.count)/\(item.target)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(min(item.count, item.target)), total: Double(item.target))
                        .tint(.accent)
                } else {
                    Text(settings.t("اضغط الدائرة لتكرار الذكر", "Tap the circle to repeat the athkar"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button(settings.t("تصفير", "Reset")) {
                    item.count = 0
                    afterChange?()
                }
                .font(.caption)
                .disabled(item.count == 0)
            }
            Spacer()
        }
        .padding(14)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var targetEditing: some View {
        HStack {
            Text(settings.t("الهدف", "Target"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("0", text: $target, onCommit: commitTarget)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
            Button(showTargetField ? settings.t("تم", "Done") : settings.t("تعديل", "Edit")) {
                if showTargetField {
                    commitTarget()
                } else {
                    target = item.target > 0 ? "\(item.target)" : ""
                    showTargetField = true
                }
            }
            .font(.caption.bold())
            .buttonStyle(.borderless)
        }
    }

    private func commitTarget() {
        showTargetField = false
        item.target = max(0, Int(target) ?? 0)
        afterChange?()
    }

    private func tap() {
        item.count += 1
        afterChange?()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        StreaksStore.addAthkar(1)
    }
}

/// Read-only WKWebView rendering rich athkar HTML with light/dark support.
struct AthkarRichWebView: UIViewRepresentable {
    var html: String
    var fontSize = 18.0

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        update(webView, context: context)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        update(webView, context: context)
    }

    private func update(_ webView: WKWebView, context: Context) {
        let dark = context.environment.colorScheme == .dark
        let text = dark ? "#f0f0f0" : "#101010"
        let muted = dark ? "#9fb3c8" : "#003976"
        let document = """
        <!DOCTYPE html><html dir="rtl"><head>
        <meta name="viewport" content="width=device-width,initial-scale=1.0">
        <style>
        :root { color-scheme: light dark; }
        body {
            font-family: 'Scheherazade-Regular', -apple-system-body;
            font-size: \(Int(fontSize))px;
            color: \(text);
            padding: 16px;
            word-wrap: break-word;
            line-height: 1.6;
        }
        img, video { max-width: 100%; height: auto; }
        table { border-collapse: collapse; }
        td, th { border: 1px solid rgba(128,128,128,0.6); padding: 5px 10px; }
        a { color: \(muted); }
        blockquote { border-inline-start: 3px solid rgba(128,128,128,0.6);
                     margin-inline-start: 0; padding-inline-start: 12px; color: \(muted); }
        </style></head><body>\(html)</body></html>
        """
        webView.loadHTMLString(document, baseURL: nil)
    }
}