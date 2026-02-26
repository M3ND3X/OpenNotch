//! OpenNotch - Notch-anchored overlay hub for macOS
//!
//! SwiftUI host; business logic in Rust via UniFFI.

import SwiftUI
import Quartz
import AppKit

enum SettingsSection: String, CaseIterable, Hashable {
    case general
    case gestures
    case liveActivities
    case nook
    case tray
    case dropArea
    case license
    case about
}

extension SettingsSection {
    var title: String {
        switch self {
        case .general: return "General"
        case .gestures: return "Gestures"
        case .liveActivities: return "Live Activities"
        case .nook: return "Nook"
        case .tray: return "Tray"
        case .dropArea: return "Drop Area"
        case .license: return "License"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .gestures: return "hand.point.up.left.fill"
        case .liveActivities: return "clock.arrow.circlepath"
        case .nook: return "figure.stand"
        case .tray: return "rectangle.dashed"
        case .dropArea: return "square.and.arrow.down.on.square"
        case .license: return "key.fill"
        case .about: return "ellipsis.circle.fill"
        }
    }
}

@main
struct OpenNotchApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var overlayManager = OverlayWindowManager()

    var body: some Scene {
        WindowGroup {
            ContentView(appModel: appModel)
                .frame(minWidth: 400, minHeight: 300)
                .onAppear {
                    overlayManager.configure(appModel: appModel)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 400)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    appModel.openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        Settings {
            PreferencesView(appModel: appModel)
        }
    }
}

/// Default empty snapshot for initial state
private func defaultUiSnapshot() -> UiSnapshot {
    UiSnapshot(
        expansionProgress: 0,
        reducedMotion: false,
        activeSurface: "Nook",
        nook: NookViewModel(widgets: []),
        tray: TrayViewModel(items: [], selectedIds: []),
        settings: SettingsModel(
            startAtLogin: false,
            hotkey: "⌘⇧N",
            showInFullscreen: "on_notched",
            mediaSource: "system",
            preferRoundButtons: true,
            translucentNotchBackground: false,
            alwaysOpenOnHover: false,
            disableHaptics: false,
            preventCloseOnMouseLeave: true,
            lockWhileTyping: false,
            contentPadding: 12,
            notchWidthFineTune: 0,
            notchHeightFineTune: 0,
            handlerEnable: true,
            handlerWidth: 184,
            handlerHeight: 8,
            transparentHandler: false,
            demoMode: false,
            hoverDelayMs: 200,
            gestureSensitivity: 1.0,
            reducedMotion: false,
            appearOnAllSpaces: true,
            enabledDisplays: [],
            allowGesturesOnHover: true,
            openCloseVerticalGestures: true,
            controlMediaHorizontal: true,
            invertMediaGestures: false,
            liveActivitiesEnable: true,
            liveActivitiesHideInNonNotched: false,
            liveActivitiesInactivityTimeout: 10,
            liveActivitiesEnableInteractive: true,
            liveActivitiesEnableQuickPeek: true,
            liveActivitiesUnhideAutomatically: true,
            liveActivitiesShowSongChange: false,
            liveActivitiesHudReplacementEnable: false,
            liveActivitiesHudDisableColors: false,
            liveActivitiesHudShowAllScreens: false,
            liveActivitiesAlbumCornerRadius: 5,
            liveActivitiesEffectType: "audio_spectrograph",
            liveActivitiesColoredEffects: true,
            liveActivitiesActivitiesEnabled: ["media", "files_tray", "calendar", "notes", "new_update"],
            nookEnable: true,
            nookShowDividers: true,
            trayEphemeral: true,
            trayMaxItems: 50,
            trayWidth: 11,
            dropAreaWidth: 11,
            dropAreaPipelinesEnabled: ["compress_images", "zip_unzip"],
            widgetsEnabled: [],
            widgetsOrder: []
        ),
        permissions: PermissionStatus(calendar: false, camera: false, automation: false)
    )
}

/// Holds AppCore and drives UI from snapshot
@MainActor
final class AppModel: ObservableObject {
    private var core: AppCore?
    @Published var snapshot: UiSnapshot = defaultUiSnapshot()
    @Published var errorMessage: String?
    @Published var selectedSettingsSection: SettingsSection = .general
    @Published var latestMediaStateJson: String = "{}"
    private var fallbackSettingsWindow: NSWindow?

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
            .appendingPathComponent("OpenNotch")
            .path

        try? FileManager.default.createDirectory(
            atPath: appSupport,
            withIntermediateDirectories: true
        )

        let deviceId = "default"
        let screens = Self.captureScreenMetrics()

        core = AppCore(
            appSupportDir: appSupport,
            deviceId: deviceId,
            initialScreenMetrics: screens
        )

        refreshSnapshot()
        Task { @MainActor in
            CalendarProvider.fetchAndDispatch(appModel: self)
            MediaProvider.fetchAndDispatch(appModel: self)
            CameraProvider.fetchAndDispatch(appModel: self)
            VolumeProvider.fetchAndDispatch(appModel: self)
        }
    }

    func dispatch(_ cmd: Command) {
        guard let core = core else { return }
        let effects = core.dispatch(cmd: cmd)
        for effect in effects {
            executeEffect(effect)
        }
        refreshSnapshot()
    }

    func refreshSnapshot() {
        if let core = core {
            snapshot = core.snapshot()
        }
    }

    func cacheMediaStateJson(_ json: String) {
        latestMediaStateJson = json
    }

    func openSettingsWindow(section: SettingsSection = .general) {
        selectedSettingsSection = section
        NSApp.activate(ignoringOtherApps: true)

        if let window = fallbackSettingsWindow {
            window.setContentSize(NSSize(width: 1040, height: 760))
            window.minSize = NSSize(width: 1040, height: 760)
            window.maxSize = NSSize(width: 1040, height: 760)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: PreferencesView(appModel: self))
        let window = NSWindow(contentViewController: hosting)
        window.title = "OpenNotch Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 1040, height: 760))
        window.minSize = NSSize(width: 1040, height: 760)
        window.maxSize = NSSize(width: 1040, height: 760)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        fallbackSettingsWindow = window
    }

    private func executeEffect(_ effect: Effect) {
        switch effect {
        case .none:
            break
        case .openUrl(let url):
            if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
            }
        case .showQuickLook(let paths):
            let urls = paths.map { URL(fileURLWithPath: $0) }
            if !urls.isEmpty {
                QuickLookHelper.shared.update(urls: urls)
                QuickLookHelper.shared.showPanel()
            }
        case .revealInFinder(let path):
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        case .copyToPasteboard(let paths):
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects(paths.map { NSURL(fileURLWithPath: $0) as NSURL })
        case .shareItems(let itemIds):
            let urls = itemIds.map { URL(fileURLWithPath: $0) }
            if !urls.isEmpty, let view = NSApp.keyWindow?.contentView {
                let picker = NSSharingServicePicker(items: urls)
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            }
        case .renameFile(let oldPath, let newPath):
            let src = URL(fileURLWithPath: oldPath)
            let dst = URL(fileURLWithPath: newPath)
            try? FileManager.default.moveItem(at: src, to: dst)
        case .requestPermission:
            break
        case .runShortcut(let name):
            ShortcutsProvider.runShortcut(name: name)
        }
    }

    private static func captureScreenMetrics() -> [ScreenMetrics] {
        NSScreen.screens.enumerated().map { index, screen in
            let frame = screen.frame
            let safeArea = screen.safeAreaInsets
            return ScreenMetrics(
                screenId: "screen-\(index)",
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.width,
                height: frame.height,
                safeAreaTop: safeArea.top,
                safeAreaLeft: safeArea.left,
                safeAreaRight: safeArea.right,
                safeAreaBottom: safeArea.bottom
            )
        }
    }
}

struct ContentView: View {
    @ObservedObject var appModel: AppModel

    private var expansionAnimation: Animation {
        appModel.snapshot.reducedMotion
            ? .linear(duration: 0.15)
            : .spring(response: 0.35, dampingFraction: 0.8)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("OpenNotch")
                .font(.title)
                .fontWeight(.bold)

            Text("Rust + SwiftUI bridge working")
                .foregroundStyle(.secondary)

            Text("Expansion: \(Int(appModel.snapshot.expansionProgress * 100))%")
            Text("Surface: \(appModel.snapshot.activeSurface)")

            HStack {
                Button("Toggle Overlay") {
                    withAnimation(expansionAnimation) {
                        appModel.dispatch(.toggleOverlay)
                    }
                }
                Button("Toggle Surface") {
                    appModel.dispatch(.toggleSurface)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(expansionAnimation, value: appModel.snapshot.expansionProgress)
    }
}
