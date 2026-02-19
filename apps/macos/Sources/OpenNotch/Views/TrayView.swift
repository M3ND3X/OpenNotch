// TrayView - File shelf with drag-drop, selection, list rendering.
// Swift: onDrop → TrayAddPayload → dispatch(TrayAddItems)

import SwiftUI
import UniformTypeIdentifiers

private let trayDesignScale: CGFloat = 0.83
private func ts(_ value: CGFloat) -> CGFloat { value * trayDesignScale }

struct TrayView: View {
    @ObservedObject var appModel: AppModel

    private var expansionAnimation: Animation {
        appModel.snapshot.reducedMotion
            ? .linear(duration: 0.15)
            : .spring(response: 0.35, dampingFraction: 0.8)
    }

    var body: some View {
        let tray = appModel.snapshot.tray

        VStack(spacing: ts(8)) {
            if tray.items.isEmpty {
                VStack(spacing: ts(8)) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: ts(32)))
                        .foregroundStyle(.tertiary)
                    Text("Drop files, URLs, or text here")
                        .font(.system(size: ts(13)))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: ts(80))
                .contentShape(Rectangle())
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ts(8)) {
                        ForEach(tray.items, id: \.id) { item in
                            TrayItemRow(
                                item: item,
                                appModel: appModel,
                                onTap: { addToSelection in
                                    appModel.dispatch(.traySelect(itemId: item.id, addToSelection: addToSelection))
                                }
                            )
                        }
                    }
                    .padding(.horizontal, ts(4))
                }
                .frame(maxHeight: ts(80))
            }
        }
        .padding(ts(12))
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Tray - drop zone for files and links")
        .onDrop(of: [.fileURL, .url, .plainText, .text], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .animation(expansionAnimation, value: tray.items.count)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var filePaths: [String] = []
        var urls: [String] = []
        var textItems: [String] = []

        let group = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        filePaths.append(url.path)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url.absoluteString)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let text = item as? String {
                        textItems.append(text)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            let payload = TrayAddPayload(
                filePaths: filePaths,
                urls: urls,
                textItems: textItems
            )
            if !filePaths.isEmpty || !urls.isEmpty || !textItems.isEmpty {
                appModel.dispatch(.trayAddItems(payload: payload))
            }
        }

        return true
    }
}

struct TrayItemRow: View {
    let item: TrayItemViewModel
    @ObservedObject var appModel: AppModel
    let onTap: (Bool) -> Void

    var body: some View {
        Button {
            let addToSelection = NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.command)
            onTap(addToSelection)
        } label: {
            HStack(spacing: ts(6)) {
                Image(systemName: iconName)
                    .font(.system(size: ts(14)))
                    .foregroundStyle(.secondary)
                Text(item.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.system(size: ts(12)))
            }
            .padding(.horizontal, ts(8))
            .padding(.vertical, ts(6))
            .frame(maxWidth: ts(140), alignment: .leading)
            .background(item.isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
            .cornerRadius(ts(6))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if item.itemType == "file" {
                Button("Quick Look") {
                    appModel.dispatch(.trayQuickLook(itemIds: [item.id]))
                }
                Button("Reveal in Finder") {
                    appModel.dispatch(.trayRevealInFinder(itemId: item.id))
                }
                Button("Copy") {
                    appModel.dispatch(.traySelect(itemId: item.id, addToSelection: false))
                    appModel.dispatch(.trayCopy)
                }
                Divider()
                Button("Share...") {
                    appModel.dispatch(.trayShare(itemIds: [item.id]))
                }
            }
            Divider()
            Button("Remove", role: .destructive) {
                appModel.dispatch(.trayRemove(itemIds: [item.id]))
            }
        }
    }

    private var iconName: String {
        switch item.itemType {
        case "file": return "doc"
        case "url": return "link"
        case "text": return "text.quote"
        default: return "doc"
        }
    }
}
