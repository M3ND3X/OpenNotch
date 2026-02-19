// OverlayWindowManager - Creates and manages NSPanel overlays per display.
// Anchors to top-center, respects safe area (notch).

import AppKit
import SwiftUI

private let overlayDesignScale: CGFloat = 0.83
private let overlayBaseExpandedWidth: CGFloat = 1180
private let overlayExpandedWidth: CGFloat = overlayBaseExpandedWidth * overlayDesignScale
private let overlayExpandedBodyHeight: CGFloat = 178 * overlayDesignScale
private let overlayExpandedSurfaceHeight: CGFloat = 136 * overlayDesignScale
private let overlayTopCornerRadius: CGFloat = os(28)
private let overlayBottomCornerRadius: CGFloat = os(40)

private func os(_ value: CGFloat) -> CGFloat { value * overlayDesignScale }

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class OverlayInteractionState: ObservableObject {
    @Published var hoverPreviewActive: Bool = false
}

@MainActor
final class OverlayWindowManager: ObservableObject {
    private var panels: [String: NSPanel] = [:]
    private var appModel: AppModel?
    private var activationMonitor: Any?
    private var globalActivationMonitor: Any?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private let interactionState = OverlayInteractionState()
    private var didRequestLeaveCollapse = false

    func configure(appModel: AppModel) {
        self.appModel = appModel
        setupScreenObservers()
        createPanelsForCurrentScreens()
        setupActivationZone()
        setupActivationClick()
        setupHotkey()
        setupTrayKeyboard()
    }

    private func setupScreenObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.screensDidChange()
            }
        }
    }

    private func screensDidChange() {
        interactionState.hoverPreviewActive = false
        // Remove panels for screens that no longer exist
        for id in panels.keys where id != "screen-0" {
            panels[id]?.orderOut(nil)
            panels[id] = nil
        }
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else {
            for panel in panels.values { panel.orderOut(nil) }
            panels.removeAll()
            return
        }
        let id = "screen-0"
        if panels[id] == nil {
            createPanel(for: mainScreen, screenId: id)
        } else {
            updatePanelPosition(panels[id]!, screen: mainScreen)
        }
        appModel?.dispatch(.screenMetricsChanged(screens: captureScreenMetrics()))
    }

    private func createPanelsForCurrentScreens() {
        // Only create overlay on main screen (the one with menu bar). Multi-monitor can confuse positioning.
        guard let mainScreen = NSScreen.main ?? NSScreen.screens.first else { return }
        createPanel(for: mainScreen, screenId: "screen-0")
        appModel?.dispatch(.screenMetricsChanged(screens: captureScreenMetrics()))
    }

    private func createPanel(for screen: NSScreen, screenId: String) {
        let panel = OverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        // Use SwiftUI rounded shadow only; NSPanel shadow creates a square outline frame.
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false
        panel.acceptsMouseMovedEvents = true
        panel.hidesOnDeactivate = false

        let hostingView = NSHostingView(rootView: OverlayHostView(appModel: appModel!, interactionState: interactionState))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        if let frameView = panel.contentView?.superview {
            frameView.wantsLayer = true
            frameView.layer?.backgroundColor = NSColor.clear.cgColor
            frameView.layer?.borderWidth = 0
            frameView.layer?.borderColor = NSColor.clear.cgColor
            frameView.layer?.cornerRadius = 0
            frameView.layer?.masksToBounds = false
        }

        updatePanelPosition(panel, screen: screen)
        panel.makeKeyAndOrderFront(nil)

        panels[screenId] = panel
    }

    private func updatePanelPosition(_ panel: NSPanel, screen: NSScreen) {
        let frame = screen.frame
        let safeTop = screen.safeAreaInsets.top
        // Height extends into notch area so pill sits behind it.
        let width: CGFloat = overlayExpandedWidth
        let height: CGFloat = overlayExpandedBodyHeight + safeTop
        let x = frame.midX - width / 2
        // Position so panel top aligns with screen top (behind notch)
        let y = frame.maxY - height
        let fixedSize = NSSize(width: width, height: height)
        panel.contentMinSize = fixedSize
        panel.contentMaxSize = fixedSize
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func captureScreenMetrics() -> [ScreenMetrics] {
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

    private func setupActivationZone() {
        activationMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(event)
            return event
        }
        globalActivationMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseMove(event)
            }
        }
    }

    private func activationZoneRect(screen: NSScreen, settings: SettingsModel) -> NSRect {
        let frame = screen.frame
        let safeTop = screen.safeAreaInsets.top
        let baseWidth = CGFloat(settings.handlerWidth) + CGFloat(settings.notchWidthFineTune)
        let activationWidth = max(100, min(300, baseWidth))
        let activationHeight: CGFloat = safeTop > 0 ? safeTop : CGFloat(settings.handlerHeight)
        return NSRect(
            x: frame.midX - activationWidth / 2,
            y: frame.maxY - activationHeight,
            width: activationWidth,
            height: activationHeight
        )
    }

    private func handleMouseMove(_ event: NSEvent) {
        guard let screen = NSScreen.main, let appModel = appModel else { return }
        let location = NSEvent.mouseLocation
        let topZone = activationZoneRect(screen: screen, settings: appModel.snapshot.settings)
        let isExpanded = appModel.snapshot.expansionProgress > 0.01

        if isExpanded {
            if interactionState.hoverPreviewActive {
                interactionState.hoverPreviewActive = false
            }
            guard let panel = panels["screen-0"] else { return }
            if !panel.frame.contains(location) {
                if !didRequestLeaveCollapse {
                    didRequestLeaveCollapse = true
                    appModel.dispatch(.hoverExited(screenId: "screen-0"))
                }
            } else {
                didRequestLeaveCollapse = false
            }
            return
        }

        didRequestLeaveCollapse = false
        let shouldPreview = topZone.contains(location)
        if interactionState.hoverPreviewActive != shouldPreview {
            interactionState.hoverPreviewActive = shouldPreview
        }
    }

    private func setupActivationClick() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self else { return event }
            return self.handleMouseDown(event)
        }
    }

    private func handleMouseDown(_ event: NSEvent) -> NSEvent? {
        guard let screen = NSScreen.main, let appModel = appModel else { return event }
        let isExpanded = appModel.snapshot.expansionProgress > 0.01
        guard !isExpanded else { return event }

        let location = NSEvent.mouseLocation
        let topZone = activationZoneRect(screen: screen, settings: appModel.snapshot.settings)
        guard topZone.contains(location) else { return event }

        interactionState.hoverPreviewActive = false
        appModel.dispatch(.toggleOverlay)
        return nil
    }

    private func setupHotkey() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.characters == "n" {
                Task { @MainActor in
                    self?.appModel?.dispatch(.toggleOverlay)
                }
                return nil
            }
            return event
        }
    }

    private func setupTrayKeyboard() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let appModel = self.appModel else { return event }
            let expanded = appModel.snapshot.expansionProgress > 0
            let onTray = appModel.snapshot.activeSurface == "Tray"
            guard expanded && onTray else { return event }

            if event.keyCode == 51 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                let selected = appModel.snapshot.tray.selectedIds
                if !selected.isEmpty {
                    appModel.dispatch(.trayRemove(itemIds: selected))
                    return nil
                }
            }
            if event.modifierFlags.contains(.command) && event.characters?.lowercased() == "a" {
                appModel.dispatch(.traySelectAll)
                return nil
            }
            if event.modifierFlags.contains(.command) && event.characters?.lowercased() == "c" {
                let selected = appModel.snapshot.tray.selectedIds
                if !selected.isEmpty {
                    appModel.dispatch(.trayCopy)
                    return nil
                }
            }
            return event
        }
    }

    deinit {
        if let monitor = activationMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalActivationMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        panels.removeAll()
    }
}

// Premium design tokens matching the provided reference.
private let overlayBackgroundGradient = LinearGradient(
    colors: [
        Color(red: 0.11, green: 0.11, blue: 0.12),
        Color(red: 0.05, green: 0.05, blue: 0.06)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
private let expandedSurfaceHeight: CGFloat = overlayExpandedSurfaceHeight
private let activeTabPill = Color(white: 0.88)
private let inactiveTabText = Color.white.opacity(0.52)
private let contentLightGray = Color.white.opacity(0.66)

struct OverlayHostView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var interactionState: OverlayInteractionState

    private var collapsedNotchWidth: CGFloat {
        let w = CGFloat(appModel.snapshot.settings.handlerWidth) + CGFloat(appModel.snapshot.settings.notchWidthFineTune)
        return max(100, min(300, w))
    }

    private var collapsedNotchHeight: CGFloat {
        let baseHeight =
            CGFloat(appModel.snapshot.settings.handlerHeight)
            + CGFloat(appModel.snapshot.settings.notchHeightFineTune)
            + os(30)
        return max(os(28), min(os(58), baseHeight))
    }

    private var collapsedNotchCornerRadius: CGFloat {
        max(os(13), collapsedNotchHeight * 0.48)
    }

    private var collapsedNotchOpacity: Double {
        appModel.snapshot.settings.transparentHandler ? 0 : 0.65
    }

    private var expansionProgress: CGFloat {
        CGFloat(appModel.snapshot.expansionProgress)
    }

    private var hoverPreviewScaleBoost: CGFloat {
        (interactionState.hoverPreviewActive && expansionProgress < 0.001) ? 1.20 : 1.0
    }

    private var hoverPreviewLift: CGFloat {
        0
    }

    private var hoverPreviewOpacityBoost: Double {
        (interactionState.hoverPreviewActive && expansionProgress < 0.001) ? 0.02 : 0.0
    }

    private var hoverPreviewShadowOpacity: Double {
        (interactionState.hoverPreviewActive && expansionProgress < 0.001) ? 0.5 : 0.34
    }

    private var collapsedNotchView: some View {
        RoundedRectangle(cornerRadius: collapsedNotchCornerRadius, style: .continuous)
            .fill(Color.black.opacity(0.995))
            .frame(width: collapsedNotchWidth, height: collapsedNotchHeight)
            .shadow(color: .black.opacity(hoverPreviewShadowOpacity), radius: os(16), x: 0, y: os(7))
    }

    private var expansionAnimation: Animation {
        appModel.snapshot.reducedMotion
            ? .linear(duration: 0.15)
            : .spring(response: 0.4, dampingFraction: 0.75)
    }

    private func openSettings() {
        appModel.openSettingsWindow(section: .general)
    }

    private var overlayContainer: some View {
        VStack(spacing: 0) {
            HStack(spacing: os(16)) {
                TabButton(
                    title: "Nook",
                    icon: "figure.stand",
                    isSelected: appModel.snapshot.activeSurface == "Nook"
                ) {
                    if appModel.snapshot.activeSurface != "Nook" {
                        appModel.dispatch(.toggleSurface)
                    }
                }
                TabButton(
                    title: "Tray",
                    icon: "tray.fill",
                    isSelected: appModel.snapshot.activeSurface == "Tray"
                ) {
                    if appModel.snapshot.activeSurface != "Tray" {
                        appModel.dispatch(.toggleSurface)
                    }
                }
                Spacer()
                Button { openSettings() } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: os(17), weight: .semibold))
                        .foregroundStyle(contentLightGray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, os(22))
            .padding(.top, os(13))
            .padding(.bottom, os(11))

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(height: 1)
                .padding(.horizontal, os(20))
                .padding(.bottom, os(3))

            Group {
                if appModel.snapshot.activeSurface == "Nook" {
                    NookView(appModel: appModel)
                } else {
                    TrayView(appModel: appModel)
                }
            }
            .frame(maxWidth: .infinity, minHeight: expandedSurfaceHeight, maxHeight: expandedSurfaceHeight, alignment: .top)
        }
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: overlayTopCornerRadius,
                    bottomLeading: overlayBottomCornerRadius,
                    bottomTrailing: overlayBottomCornerRadius,
                    topTrailing: overlayTopCornerRadius
                ),
                style: .continuous
            )
                .fill(overlayBackgroundGradient)
        )
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: overlayTopCornerRadius,
                    bottomLeading: overlayBottomCornerRadius,
                    bottomTrailing: overlayBottomCornerRadius,
                    topTrailing: overlayTopCornerRadius
                ),
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.55), radius: os(34), x: 0, y: os(14))
    }

    var body: some View {
        ZStack(alignment: .top) {
            overlayContainer
                .opacity(Double(expansionProgress))
                .scaleEffect(
                    x: 0.95 + (0.05 * expansionProgress),
                    y: 0.93 + (0.07 * expansionProgress),
                    anchor: .top
                )

            collapsedNotchView
                .scaleEffect(hoverPreviewScaleBoost, anchor: .top)
                .offset(y: hoverPreviewLift)
                .opacity((1 - Double(expansionProgress)) * (collapsedNotchOpacity + hoverPreviewOpacityBoost))
        }
        .animation(expansionAnimation, value: expansionProgress)
        .animation(expansionAnimation, value: interactionState.hoverPreviewActive)
        .accessibilityLabel("OpenNotch overlay")
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: os(8)) {
                Image(systemName: icon)
                    .font(.system(size: os(14), weight: .semibold))
                Text(title)
                    .font(.system(size: os(15), weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .black : inactiveTabText)
            .padding(.horizontal, os(18))
            .padding(.vertical, os(9))
            .background(
                Capsule()
                    .fill(isSelected ? activeTabPill : (isHovered ? Color.white.opacity(0.08) : Color.clear))
            )
            .scaleEffect(isHovered && !isSelected ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
