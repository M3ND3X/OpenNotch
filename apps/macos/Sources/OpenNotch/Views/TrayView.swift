// TrayView - File shelf with drag-drop, selection, list rendering.
// Swift: onDrop → TrayAddPayload → dispatch(TrayAddItems)

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import QuickLookThumbnailing

private let trayDesignScale: CGFloat = 0.83
private func ts(_ value: CGFloat) -> CGFloat { value * trayDesignScale }

struct TrayView: View {
    @ObservedObject var appModel: AppModel
    @State private var isDropTargeted = false
    private static let acceptedDropTypes: [UTType] = [
        .fileURL,
        .item,
        .data,
        .url,
        .plainText,
        .text
    ]

    private var expansionAnimation: Animation {
        appModel.snapshot.reducedMotion
            ? .linear(duration: 0.15)
            : .spring(response: 0.35, dampingFraction: 0.8)
    }

    var body: some View {
        let tray = appModel.snapshot.tray

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: ts(24), style: .continuous)
                .fill(Color.black.opacity(0.24))

            RoundedRectangle(cornerRadius: ts(24), style: .continuous)
                .stroke(
                    isDropTargeted ? Color.white.opacity(0.34) : Color.white.opacity(0.15),
                    style: StrokeStyle(
                        lineWidth: ts(3),
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [ts(10), ts(12)]
                    )
                )

            if tray.items.isEmpty {
                VStack(spacing: ts(8)) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: ts(24), weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.44))
                    Text("Drop files, URLs, or text here")
                        .font(.system(size: ts(13), weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: ts(20)) {
                        ForEach(tray.items, id: \.id) { item in
                            TrayItemTile(
                                item: item,
                                appModel: appModel,
                                onTap: { addToSelection in
                                    appModel.dispatch(.traySelect(itemId: item.id, addToSelection: addToSelection))
                                }
                            )
                        }
                    }
                    .padding(.horizontal, ts(20))
                    .padding(.vertical, ts(16))
                }
            }
        }
        .padding(.horizontal, ts(8))
        .padding(.vertical, ts(6))
        .frame(maxWidth: .infinity, minHeight: ts(104), maxHeight: ts(104), alignment: .top)
        .accessibilityLabel("Tray - drop zone for files and links")
        .onDrop(of: Self.acceptedDropTypes, isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .animation(expansionAnimation, value: tray.items.count)
        .animation(.easeInOut(duration: 0.14), value: isDropTargeted)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        var filePaths: [String] = []
        var urls: [String] = []
        var textItems: [String] = []
        let collectQueue = DispatchQueue(label: "OpenNotch.TrayDropCollect")

        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            Self.resolveDropItem(from: provider) { resolved in
                defer { group.leave() }
                guard let resolved else { return }
                collectQueue.sync {
                    switch resolved {
                    case .filePath(let path):
                        if !filePaths.contains(path) { filePaths.append(path) }
                    case .url(let value):
                        if !urls.contains(value) { urls.append(value) }
                    case .text(let value):
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { textItems.append(trimmed) }
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

    private enum ResolvedDropItem {
        case filePath(String)
        case url(String)
        case text(String)
    }

    private static func resolveDropItem(
        from provider: NSItemProvider,
        completion: @escaping (ResolvedDropItem?) -> Void
    ) {
        resolveFilePath(from: provider) { filePath in
            if let filePath {
                completion(.filePath(filePath))
                return
            }

            resolveURL(from: provider) { url in
                if let url {
                    completion(.url(url))
                    return
                }

                resolveText(from: provider) { text in
                    if let text {
                        if let path = normalizedFilePath(from: text) {
                            completion(.filePath(path))
                            return
                        }
                        if let link = normalizedURLString(from: text) {
                            completion(.url(link))
                            return
                        }
                        completion(.text(text))
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }

    private static func resolveFilePath(from provider: NSItemProvider, completion: @escaping (String?) -> Void) {
        var candidateTypeIds: [String] = [UTType.fileURL.identifier]
        candidateTypeIds.append(contentsOf: provider.registeredTypeIdentifiers)
        for fallback in [UTType.item.identifier, UTType.data.identifier] where !candidateTypeIds.contains(fallback) {
            candidateTypeIds.append(fallback)
        }

        tryLoadFilePath(
            from: provider,
            typeIds: candidateTypeIds,
            index: 0,
            completion: completion
        )
    }

    private static func tryLoadFilePath(
        from provider: NSItemProvider,
        typeIds: [String],
        index: Int,
        completion: @escaping (String?) -> Void
    ) {
        guard index < typeIds.count else {
            completion(nil)
            return
        }

        let typeId = typeIds[index]
        guard provider.hasItemConformingToTypeIdentifier(typeId) else {
            tryLoadFilePath(from: provider, typeIds: typeIds, index: index + 1, completion: completion)
            return
        }

        provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeId) { url, _, _ in
            let inPlacePath = (url?.isFileURL == true) ? url?.path : nil
            if let inPlacePath, !isTemporaryImportedPath(inPlacePath) {
                completion(inPlacePath)
                return
            }

            let resolveFromObjectOrItem: (String?) -> Void = { objectPath in
                if let objectPath, !isTemporaryImportedPath(objectPath) {
                    completion(objectPath)
                    return
                }
                if
                    let objectPath,
                    let persisted = persistTemporaryImportedPath(
                        objectPath,
                        suggestedName: provider.suggestedName
                    )
                {
                    completion(persisted)
                    return
                }

                let fallbackPath = objectPath ?? inPlacePath
                provider.loadFileRepresentation(forTypeIdentifier: typeId) { fileURL, _ in
                    if let fileURL, fileURL.isFileURL {
                        let fileRepPath = fileURL.path
                        if !isTemporaryImportedPath(fileRepPath) {
                            completion(fileRepPath)
                        } else {
                            if
                                let persisted = persistTemporaryImportedPath(
                                    fileRepPath,
                                    suggestedName: provider.suggestedName
                                )
                            {
                                completion(persisted)
                                return
                            }
                            if
                                let fallbackPath,
                                let persistedFallback = persistTemporaryImportedPath(
                                    fallbackPath,
                                    suggestedName: provider.suggestedName
                                )
                            {
                                completion(persistedFallback)
                                return
                            }
                            completion(fallbackPath ?? fileRepPath)
                        }
                    } else if let fallbackPath {
                        if
                            let persisted = persistTemporaryImportedPath(
                                fallbackPath,
                                suggestedName: provider.suggestedName
                            )
                        {
                            completion(persisted)
                            return
                        }
                        completion(fallbackPath)
                    } else {
                        tryLoadFilePath(from: provider, typeIds: typeIds, index: index + 1, completion: completion)
                    }
                }
            }

            if provider.canLoadObject(ofClass: NSURL.self) {
                provider.loadObject(ofClass: NSURL.self) { object, _ in
                    if let nsurl = object as? NSURL {
                        let bridged = nsurl as URL
                        if bridged.isFileURL {
                            resolveFromObjectOrItem(bridged.path)
                            return
                        }
                    }
                    if let objectURL = object as? URL, objectURL.isFileURL {
                        resolveFromObjectOrItem(objectURL.path)
                        return
                    }
                    provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                        resolveFromObjectOrItem(Self.extractFilePath(from: item))
                    }
                }
            } else {
                provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                    resolveFromObjectOrItem(Self.extractFilePath(from: item))
                }
            }
        }
    }

    private static func resolveURL(from provider: NSItemProvider, completion: @escaping (String?) -> Void) {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else {
            completion(nil)
            return
        }

        if provider.canLoadObject(ofClass: NSURL.self) {
            provider.loadObject(ofClass: NSURL.self) { object, _ in
                if let nsurl = object as? NSURL {
                    completion((nsurl as URL).absoluteString)
                    return
                }
                if let url = object as? URL {
                    completion(url.absoluteString)
                    return
                }
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    completion(Self.extractURLString(from: item))
                }
            }
        } else {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                completion(Self.extractURLString(from: item))
            }
        }
    }

    private static func resolveText(from provider: NSItemProvider, completion: @escaping (String?) -> Void) {
        let plainTextId = UTType.plainText.identifier
        let textId = UTType.text.identifier
        guard
            provider.hasItemConformingToTypeIdentifier(plainTextId)
            || provider.hasItemConformingToTypeIdentifier(textId)
        else {
            completion(nil)
            return
        }

        if provider.canLoadObject(ofClass: NSString.self) {
            provider.loadObject(ofClass: NSString.self) { object, _ in
                if let nsstring = object as? NSString {
                    completion(nsstring as String)
                    return
                }
                if let text = object as? String {
                    completion(text)
                    return
                }
                provider.loadItem(forTypeIdentifier: plainTextId, options: nil) { item, _ in
                    if let value = item as? String {
                        completion(value)
                    } else {
                        provider.loadItem(forTypeIdentifier: textId, options: nil) { fallback, _ in
                            completion(fallback as? String)
                        }
                    }
                }
            }
        } else {
            provider.loadItem(forTypeIdentifier: plainTextId, options: nil) { item, _ in
                if let value = item as? String {
                    completion(value)
                } else {
                    provider.loadItem(forTypeIdentifier: textId, options: nil) { fallback, _ in
                        completion(fallback as? String)
                    }
                }
            }
        }
    }

    private static func extractFilePath(from item: NSSecureCoding?) -> String? {
        if let url = item as? URL {
            return url.isFileURL ? url.path : nil
        }
        if let nsurl = item as? NSURL {
            let url = nsurl as URL
            return url.isFileURL ? url.path : nil
        }
        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
            return url.isFileURL ? url.path : nil
        }
        if let text = item as? String, let url = URL(string: text), url.isFileURL {
            return url.path
        }
        return nil
    }

    private static func extractURLString(from item: NSSecureCoding?) -> String? {
        if let url = item as? URL {
            return url.absoluteString
        }
        if let nsurl = item as? NSURL {
            return (nsurl as URL).absoluteString
        }
        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
            return url.absoluteString
        }
        if let text = item as? String, let url = URL(string: text) {
            return url.absoluteString
        }
        return nil
    }

    private static func normalizedFilePath(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.isFileURL {
            let path = url.path
            return FileManager.default.fileExists(atPath: path) ? path : nil
        }

        let expanded = (trimmed as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return nil }
        return FileManager.default.fileExists(atPath: expanded) ? expanded : nil
    }

    private static func normalizedURLString(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), !url.isFileURL else { return nil }
        return url.absoluteString
    }

    private static func isTemporaryImportedPath(_ path: String) -> Bool {
        let lower = path.lowercased()
        if lower.hasSuffix(".tmp") {
            return true
        }
        return lower.contains("/private/var/folders/") || lower.contains("/var/folders/")
    }

    private static func persistTemporaryImportedPath(
        _ sourcePath: String,
        suggestedName: String?
    ) -> String? {
        guard isTemporaryImportedPath(sourcePath) else { return sourcePath }
        let sourceURL = URL(fileURLWithPath: sourcePath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }

        let fileManager = FileManager.default
        guard
            let appSupportRoot = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else { return nil }

        let importsDir = appSupportRoot
            .appendingPathComponent("OpenNotch", isDirectory: true)
            .appendingPathComponent("TrayImports", isDirectory: true)
        do {
            try fileManager.createDirectory(at: importsDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let fallbackName = sourceURL.lastPathComponent
        let sanitizedName = sanitizeFilename(suggestedName, fallback: fallbackName)
        let destinationURL = uniqueDestinationURL(in: importsDir, preferredName: sanitizedName)

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL.path
        } catch {
            return nil
        }
    }

    private static func sanitizeFilename(_ raw: String?, fallback: String) -> String {
        let proposed = (raw?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? raw! : fallback
        let cleaned = proposed
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cleaned.isEmpty ? "imported-item" : cleaned
    }

    private static func uniqueDestinationURL(in directory: URL, preferredName: String) -> URL {
        let stem = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        var candidate = directory.appendingPathComponent(preferredName, isDirectory: false)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            let indexed = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
            candidate = directory.appendingPathComponent(indexed, isDirectory: false)
            index += 1
        }

        return candidate
    }
}

struct TrayItemTile: View {
    let item: TrayItemViewModel
    @ObservedObject var appModel: AppModel
    let onTap: (Bool) -> Void
    private var isFileBacked: Bool { item.itemType == "file" || item.itemType == "folder" }

    var body: some View {
        VStack(spacing: ts(7)) {
            iconView
                .frame(width: ts(44), height: ts(44))

            Text(item.displayName)
                .lineLimit(1)
                .truncationMode(.middle)
                .font(.system(size: ts(12.5), weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(maxWidth: ts(112))
        }
        .frame(width: ts(110), height: ts(74), alignment: .top)
        .padding(.horizontal, ts(6))
        .padding(.vertical, ts(6))
        .background(
            RoundedRectangle(cornerRadius: ts(12), style: .continuous)
                .fill(item.isSelected ? Color.white.opacity(0.09) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: ts(12), style: .continuous))
        .onTapGesture {
            let addToSelection = NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.command)
            onTap(addToSelection)
        }
        .onDrag {
            if !item.isSelected {
                appModel.dispatch(.traySelect(itemId: item.id, addToSelection: false))
            }
            return dragProvider
        }
        .contextMenu {
            if isFileBacked {
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

    @ViewBuilder
    private var iconView: some View {
        if isFileBacked, !item.sourceValue.isEmpty {
            TrayFilePreviewIcon(path: item.sourceValue, fallbackSystemName: iconName)
        } else {
            Image(systemName: iconName)
                .font(.system(size: ts(24), weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
        }
    }

    private var dragProvider: NSItemProvider {
        switch item.itemType {
        case "file", "folder":
            if !item.sourceValue.isEmpty {
                let url = URL(fileURLWithPath: item.sourceValue)
                return fileSystemDragProvider(for: url)
            }
            return NSItemProvider(object: item.displayName as NSString)
        case "url":
            if let url = URL(string: item.sourceValue), !item.sourceValue.isEmpty {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider(object: item.displayName as NSString)
        case "text":
            if !item.sourceValue.isEmpty {
                return NSItemProvider(object: item.sourceValue as NSString)
            }
            return NSItemProvider(object: item.displayName as NSString)
        default:
            return NSItemProvider(object: item.displayName as NSString)
        }
    }

    private func fileSystemDragProvider(for url: URL) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = url.lastPathComponent

        provider.registerItem(forTypeIdentifier: UTType.fileURL.identifier, loadHandler: { completion, _, _ in
            completion?(url as NSURL, nil)
        })

        let isDirectory = isDirectoryURL(url)
        let typeIdentifier = isDirectory ? UTType.folder.identifier : UTType.item.identifier
        provider.registerFileRepresentation(
            forTypeIdentifier: typeIdentifier,
            fileOptions: [],
            visibility: .all
        ) { completion in
            completion(url, false, nil)
            return nil
        }

        return provider
    }

    private func isDirectoryURL(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }

    private var iconName: String {
        switch item.itemType {
        case "file": return "doc.fill"
        case "folder": return "folder.fill"
        case "url": return "link"
        case "text": return "text.quote"
        default: return "doc"
        }
    }
}

private struct TrayFilePreviewIcon: View {
    let path: String
    let fallbackSystemName: String
    @StateObject private var loader: TrayThumbnailLoader

    init(path: String, fallbackSystemName: String) {
        self.path = path
        self.fallbackSystemName = fallbackSystemName
        _loader = StateObject(wrappedValue: TrayThumbnailLoader(path: path))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSystemName)
                    .font(.system(size: ts(24), weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .onChange(of: path) { _, newPath in
            loader.load(path: newPath)
        }
    }
}

@MainActor
private final class TrayThumbnailLoader: ObservableObject {
    @Published var image: NSImage?
    private static let cache = NSCache<NSString, NSImage>()
    private var activePath: String

    init(path: String) {
        activePath = path
        load(path: path)
    }

    func load(path: String) {
        activePath = path
        guard !path.isEmpty else {
            image = nil
            return
        }

        let cacheKeyString = path
        if let cached = Self.cache.object(forKey: cacheKeyString as NSString) {
            image = cached
            return
        }

        if isDirectory(path: path) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            Self.cache.setObject(icon, forKey: cacheKeyString as NSString)
            image = icon
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: URL(fileURLWithPath: path),
            size: CGSize(width: 128, height: 128),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.activePath == path else { return }
                let cacheKey = cacheKeyString as NSString

                if let representation {
                    let thumb = representation.nsImage
                    Self.cache.setObject(thumb, forKey: cacheKey)
                    self.image = thumb
                } else {
                    let fallback = NSWorkspace.shared.icon(forFile: path)
                    Self.cache.setObject(fallback, forKey: cacheKey)
                    self.image = fallback
                }
            }
        }
    }

    private func isDirectory(path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }
}
