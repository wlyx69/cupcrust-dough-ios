import Foundation
import UIKit
import WebKit

/// Receives `window.webkit.messageHandlers.native.postMessage({type:"share", name, mime, data, files})` from the page.
/// `files` is an array of `{name, mime, data}` (data = base64 of a PDF or PNG the page drew); older pages send a
/// single `name`/`data` pair instead. Every file is written to a temp folder and handed to the system share sheet,
/// so WhatsApp and the other apps get real documents/images (several at once when there is one per supplier).
final class ShareBridge: NSObject, WKScriptMessageHandler {
    static let handlerName = "native"
    private weak var viewController: UIViewController?

    init(viewController: UIViewController) {
        self.viewController = viewController
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], (body["type"] as? String) == "share" else { return }
        var items: [[String: Any]] = []
        if let list = body["files"] as? [[String: Any]], !list.isEmpty { items = list } else { items = [body] }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("share", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var urls: [URL] = []
        for item in items {
            guard let b64 = item["data"] as? String, let data = Data(base64Encoded: b64), let rawName = item["name"] as? String else { continue }
            // keep the Arabic file name, drop anything that is not safe in a path
            let name = rawName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            let url = dir.appendingPathComponent(name)
            if (try? data.write(to: url, options: .atomic)) != nil { urls.append(url) }
        }
        guard !urls.isEmpty else { return }

        let sheet = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        if let pop = sheet.popoverPresentationController, let view = viewController?.view {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 90, width: 1, height: 1)
        }
        viewController?.present(sheet, animated: true)
    }
}
