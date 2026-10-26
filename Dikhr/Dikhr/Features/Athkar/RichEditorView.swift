import SwiftUI
import WebKit

// WKWebView-backed rich-text editor for My Athkar, built on the
// RichEditorView page (Resources/Editor/RichEditorPage.html +
// RichEditorScript.js), which is the RichEditorView editor bundled by the
// original app — see Resources/Editor/ATTRIBUTION.txt.
//
// The page exposes the classic `RE.*` JavaScript API (RE.setBold,
// RE.setOrderedList, RE.setTextColor, RE.insertLink, …) and signals events
// ("ready", "input", "focus", "blur") by navigating to a custom
// `re-callback://` URL; the pending event queue is then drained with
// `RE.getCommandQueue()`.

enum RichEditorCommand {
    case bold
    case italic
    case underline
    case strikethrough
    case listOrdered
    case listUnordered
    case indent
    case outdent
    case justifyLeft
    case justifyCenter
    case justifyRight
    case insertLink(url: String, text: String?)
    case textColor(UIColor)
    case undo
    case redo
    case clearFormat
    case blur

    var javaScript: String {
        switch self {
        case .bold:                       return "RE.setBold()"
        case .italic:                     return "RE.setItalic()"
        case .underline:                  return "RE.setUnderline()"
        case .strikethrough:              return "RE.setStrikeThrough()"
        case .listOrdered:                return "RE.setOrderedList()"
        case .listUnordered:              return "RE.setUnorderedList()"
        case .indent:                     return "RE.setIndent()"
        case .outdent:                    return "RE.setOutdent()"
        case .justifyLeft:                return "RE.setJustifyLeft()"
        case .justifyCenter:              return "RE.setJustifyCenter()"
        case .justifyRight:               return "RE.setJustifyRight()"
        case .insertLink(let url, let text):
            let target = RichEditorCommand.jsEscaped(text ?? url)
            return "RE.insertLink(\(RichEditorCommand.jsEscaped(url)), \(target), '')"
        case .textColor(let color):
            return "RE.setTextColor('\(RichEditorCommand.hexString(color))')"
        case .undo:                       return "RE.undo()"
        case .redo:                       return "RE.redo()"
        case .clearFormat:                return "RE.removeFormat()"
        case .blur:                       return "RE.blurFocus()"
        }
    }

    static func jsEscaped(_ s: String) -> String {
        guard let data = try? JSONEncoder().encode(s),
              let json = String(data: data, encoding: .utf8) else { return "''" }
        return json
    }

    static func hexString(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let value = (Int(r * 255) << 16) | (Int(g * 255) << 8) | Int(b * 255)
        return String(format: "#%06X", value)
    }
}

/// Owns the editor's WKWebView. Hold one per editing session (e.g. a
/// @StateObject inside the sheet) so the SwiftUI toolbar can drive it.
@MainActor
final class RichEditorController: NSObject, ObservableObject {
    /// Fired whenever the user types (carrying the fresh innerHTML).
    var onInput: ((String) -> Void)?

    let webView: WKWebView
    private var ready = false
    private var loadedPage = false
    private var queuedHTML: String?
    private var queuedPlaceholder: String?

    init(frame: CGRect = .zero) {
        let webView = WKWebView(frame: frame, configuration: WKWebViewConfiguration())
        self.webView = webView
        super.init()
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInset = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
    }

    func load(placeholder: String) {
        queuedPlaceholder = placeholder
        guard let url = Self.editorPageURL() else { return }
        loadedPage = true
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    var hasLoadedPage: Bool { loadedPage }

    static func editorPageURL() -> URL? {
        if let url = Bundle.main.url(forResource: "RichEditorPage", withExtension: "html", subdirectory: "Editor") {
            return url
        }
        // The bundle may have flattened the Editor folder.
        return Bundle.main.url(forResource: "RichEditorPage", withExtension: "html")
    }

    func run(_ command: RichEditorCommand) {
        evaluate(command.javaScript)
    }

    func setHTML(_ html: String) {
        if ready {
            evaluate("RE.setHtml(\(RichEditorCommand.jsEscaped(html)))")
        } else {
            queuedHTML = html
        }
    }

    func getHTML(_ completion: @escaping (String?) -> Void) {
        webView.evaluateJavaScript("RE.getHtml()") { result, _ in
            completion(result as? String)
        }
    }

    private func evaluate(_ js: String) {
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Sends the queued initial content once the page reports "ready".
    private func applyReadyState() {
        ready = true
        if let placeholder = queuedPlaceholder {
            evaluate("RE.setPlaceholderText(\(RichEditorCommand.jsEscaped(placeholder)))")
            queuedPlaceholder = nil
        }
        if let html = queuedHTML {
            queuedHTML = nil
            evaluate("RE.setHtml(\(RichEditorCommand.jsEscaped(html)))")
        }
    }
}

extension RichEditorController: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView,
                             decidePolicyFor navigationAction: WKNavigationAction,
                             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.request.url?.scheme == "re-callback" {
            decisionHandler(.cancel)
            MainActor.assumeIsolated { [weak self] in
                self?.drainCallbackQueue()
            }
            return
        }
        decisionHandler(.allow)
    }
}

private extension RichEditorController {
    /// Reads the queued event names ("ready", "input", "focus", "blur")
    /// that the page accumulated before navigating to re-callback://.
    func drainCallbackQueue() {
        webView.evaluateJavaScript("RE.getCommandQueue()") { [weak self] result, _ in
            guard let self, let events = result as? [String] else { return }
            Task { @MainActor in self.handle(events: events) }
        }
    }

    func handle(events: [String]) {
        for event in events {
            switch event {
            case "ready":
                applyReadyState()
            case "input":
                getHTML { [weak self] html in
                    guard let self, let html else { return }
                    self.onInput?(html)
                }
            default:
                break
            }
        }
    }
}

// MARK: - SwiftUI representable

/// The editor content area. `html` is bound both ways: the page reports
/// edits through the `RE.*` callback queue; external binding changes are
/// pushed with `RE.setHtml` only when they differ from the last synced
/// value, so user typing does not feed back into the page.
struct RichEditorViewRepresentable: UIViewRepresentable {
    @Binding var html: String
    var placeholder: String = ""
    var controller: RichEditorController?

    init(html: Binding<String>, placeholder: String = "", controller: RichEditorController? = nil) {
        _html = html
        self.placeholder = placeholder
        self.controller = controller
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator {
        var parent: RichEditorViewRepresentable
        var editor: RichEditorController
        var lastSynced: String?

        @MainActor
        init(_ parent: RichEditorViewRepresentable) {
            self.parent = parent
            editor = parent.controller ?? RichEditorController()
            editor.onInput = { [weak self] html in
                guard let self, html != lastSynced else { return }
                lastSynced = html
                self.parent.html = html
            }
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let coordinator = context.coordinator
        let editor = coordinator.editor
        if !editor.hasLoadedPage {
            editor.load(placeholder: placeholder)
            editor.setHTML(html)
            coordinator.lastSynced = html
        } else if coordinator.lastSynced == nil {
            // Re-mounted with an already-loaded controller: re-sync from the page.
            editor.getHTML { [weak coordinator] pageHTML in
                guard let coordinator else { return }
                MainActor.assumeIsolated {
                    if coordinator.lastSynced == nil, let pageHTML {
                        coordinator.lastSynced = pageHTML
                        coordinator.parent.html = pageHTML
                    }
                }
            }
        }
        return editor.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let editor = context.coordinator.editor
        if html != context.coordinator.lastSynced {
            editor.setHTML(html)
            context.coordinator.lastSynced = html
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.editor.onInput = nil
    }
}

// MARK: - Toolbar (mirrors the original toolbar pngs with SF Symbols)

/// Toolbar row of SF-symbol buttons mirroring the original RichEditorView
/// toolbar pngs: undo/redo/bold/italic/underline/strikethrough/
/// justify_left|center|right/ordered_list/unordered_list/indent/outdent/
/// insert_link/text_color/clear.
struct RichEditorToolbar: View {
    @ObservedObject var editor: RichEditorController

    @State private var showLinkDialog = false
    @State private var linkURL = ""

    private let colors: [(UIColor, String, Color)] = [
        (UIColor(red: 0.05, green: 0.07, blue: 0.08, alpha: 1), "أسود", Color.primary),
        (UIColor(red: 0.82, green: 0.20, blue: 0.18, alpha: 1), "حمراء", Color.red),
        (UIColor(red: 0.00, green: 0.56, blue: 0.62, alpha: 1), "تركوازي", Color(red: 0.0, green: 0.56, blue: 0.62)),
        (UIColor(red: 0.00, green: 0.58, blue: 0.42, alpha: 1), "خضراء", Color.green),
        (UIColor(red: 0.90, green: 0.45, blue: 0.05, alpha: 1), "برتقالية", Color.orange),
        (UIColor(red: 0.45, green: 0.25, blue: 0.65, alpha: 1), "بنفسجية", Color.purple),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                button("arrow.uturn.backward", "تراجع", .undo)
                button("arrow.uturn.forward", "إعادة", .redo)
                divider
                button("bold", "عريض", .bold)
                button("italic", "مائل", .italic)
                button("underline", "تسطير", .underline)
                button("strikethrough", "مشطوب", .strikethrough)
                divider
                button("list.number", "قائمة مرقمة", .listOrdered)
                button("list.bullet", "قائمة نقطية", .listUnordered)
                divider
                button("arrow.left.to.line", "زيادة المسافة", .indent)
                button("arrow.right.to.line", "تقليل المسافة", .outdent)
                divider
                button("text.justify.leading", "محاذاة يسار", .justifyLeft)
                button("text.justify.center", "توسيط", .justifyCenter)
                button("text.justify.trailing", "محاذاة يمين", .justifyRight)
                divider
                colorMenu
                Menu {
                    Button {
                        showLinkDialog = true
                    } label: { Label("إدراج رابط", systemImage: "link") }
                } label: {
                    Image(systemName: "link")
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("إدراج رابط")
                button("eraser", "إزالة التنسيق", .clearFormat)
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 44)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
        .alert("إدراج رابط", isPresented: $showLinkDialog) {
            TextField("https://…", text: $linkURL)
            Button("إدراج") {
                var url = linkURL.trimmingCharacters(in: .whitespaces)
                if !url.isEmpty, !url.contains("://") { url = "https://" + url }
                editor.run(.insertLink(url: url, text: url))
                linkURL = ""
            }
            Button("إلغاء", role: .cancel) { linkURL = "" }
        } message: {
            Text("حدّد النص أولًا، ثم أدرج الرابط ليعمل عليه")
        }
    }

    private var divider: some View {
        Capsule()
            .fill(.separator)
            .frame(width: 1, height: 22)
            .padding(.horizontal, 2)
    }

    private func button(_ system: String, _ label: String, _ command: RichEditorCommand) -> some View {
        Button {
            editor.run(command)
        } label: {
            Image(systemName: system)
                .frame(width: 34, height: 34)
        }
        .accessibilityLabel(label)
    }

    private var colorMenu: some View {
        Menu {
            ForEach(colors, id: \.1) { color in
                Button {
                    editor.run(.textColor(color.0))
                } label: {
                    Label("لون \(color.1)", systemImage: "circle.fill")
                }
            }
        } label: {
            Image(systemName: "character.colorbox")
                .frame(width: 34, height: 34)
        }
        .accessibilityLabel("لون النص")
    }
}

// MARK: - HTML helpers

enum RichHTML {
    /// Stripped text for compact list-row display. Legacy items store plain
    /// text; those pass through untouched.
    static func plainText(_ html: String) -> String {
        guard html.contains("<") else { return html }
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                  data: data,
                  options: [
                      .documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue,
                  ],
                  documentAttributes: nil)
        else { return html }
        return attributed.string
    }
}

// MARK: - Ready-made editor field (toolbar + content box)

struct RichEditorField: View {
    @Binding var html: String
    var placeholder: String = "اكتب ذكرك…"
    @StateObject private var editor = RichEditorController()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            RichEditorToolbar(editor: editor)
            RichEditorViewRepresentable(html: $html, placeholder: placeholder, controller: editor)
                .frame(minHeight: 180)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemGroupedBackground) : Color(UIColor.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(.separator, lineWidth: 0.5)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}