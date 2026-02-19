// QuickLookHelper - QLPreviewPanel data source for tray Quick Look.

import AppKit
import Quartz

final class QuickLookHelper: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLookHelper()

    private var urls: [URL] = []

    func update(urls: [URL]) {
        self.urls = urls
    }

    func showPanel() {
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index >= 0, index < urls.count else { return nil }
        return urls[index] as QLPreviewItem
    }
}
