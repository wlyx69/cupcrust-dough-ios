import Foundation
import UIKit
import WebKit

/// Receives `window.webkit.messageHandlers.native.postMessage({type:"share", name, mime, data})` from the page
/// (data = base64 of a PDF or PNG the page drew) and opens the system share sheet with it as a file,
/// so WhatsApp and the other apps get a real document/image.
final class ShareBridge: NSObject, WKScriptMessageHandler {
    static let handlerName = "native"
    private weak var viewController: UIViewController?

    init(viewController: UIViewController) {
        self.viewController = viewController
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              (body["type"] as? String) == "share",
              let b64 = body["data"] as? String,
              let data = Data(base64Encoded: b64),
              let rawName = body["name"] as? String else { return }
        // keep the Arabic file name, drop anything that is not safe in a path
        let name = rawName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("share", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        do { try data.write(to: url, options: .atomic) } catch { return }

        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = sheet.popoverPresentationController, let view = viewController?.view {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 90, width: 1, height: 1)
        }
        viewController?.present(sheet, animated: true)
    }
}
