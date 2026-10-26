import AppKit
import WebKit

let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]
let app = NSApplication.shared
let delegate = SnapDelegate()
app.delegate = delegate
app.run()

class SnapDelegate: NSObject, NSApplicationDelegate {
    var webview: WKWebView!
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        webview = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 1000), configuration: config)
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        webview.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.webview.takeSnapshot(with: nil) { image, _ in
                guard let image,
                      let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:])
                else { return }
                try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
                print("snapshot saved")
                NSApp.terminate(nil)
            }
        }
    }
}