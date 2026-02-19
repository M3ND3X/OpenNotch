// NookView - Premium OpenNotch overlay: empty state + widget strip (pixel-perfect).

import SwiftUI
import AppKit
import AVFoundation

private let nookDesignScale: CGFloat = 0.83
private func ns(_ value: CGFloat) -> CGFloat { value * nookDesignScale }

private let contentPrimary = Color.white.opacity(0.95)
private let contentSecondary = Color.white.opacity(0.67)
private let contentMuted = Color.white.opacity(0.45)
private let shortcutButtonBg = Color(red: 0.33, green: 0.33, blue: 0.35)
private let mirrorCircleBg = Color.white.opacity(0.12)
private let widgetCardBg = Color.white.opacity(0.09)
private let widgetTitleGray = Color.white.opacity(0.62)

struct NookView: View {
    @ObservedObject var appModel: AppModel
    @StateObject private var mirrorCamera = MirrorCameraController()

    private var nook: NookViewModel { appModel.snapshot.nook }
    private var widgets: [WidgetViewModel] {
        nook.widgets.filter { $0.id != "placeholder" }
    }

    private var supplementalWidgets: [WidgetViewModel] {
        widgets.filter { $0.id == "notes" || $0.id == "calendar" }
    }

    // Match the reference empty state whenever media is idle.
    private var shouldShowReferenceEmptyState: Bool {
        guard !widgets.isEmpty else { return true }
        guard let media = widgets.first(where: { $0.id == "media" || $0.compactTitle.lowercased().contains("now playing") }) else {
            return true
        }
        let content = media.compactContent.trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty || content == "—" || content == "-"
    }

    private func openSettings() {
        appModel.openSettingsWindow(section: .nook)
    }

    private func openMusicApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openYouTube() {
        NSApp.activate(ignoringOtherApps: true)
        if let url = URL(string: "https://www.youtube.com") {
            NSWorkspace.shared.open(url)
        }
    }

    private func toggleMirrorPreview() {
        appModel.dispatch(.widgetAction(widgetId: "camera", action: "mirror"))
        mirrorCamera.toggle()
    }

    var body: some View {
        Group {
            if shouldShowReferenceEmptyState {
                emptyState
            } else {
                widgetStrip
            }
        }
        .padding(.horizontal, ns(20))
        .padding(.vertical, ns(12))
        .frame(maxWidth: .infinity)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
        .onDisappear {
            mirrorCamera.stop()
        }
    }

    private var widgetStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ns(14)) {
                ForEach(Array(widgets.prefix(6)), id: \.id) { widget in
                    WidgetCard(widget: widget, appModel: appModel)
                }
                MirrorButton(
                    style: .compact,
                    isLivePreview: mirrorCamera.isRunning,
                    previewSession: mirrorCamera.session,
                    action: toggleMirrorPreview
                )
            }
            .padding(.horizontal, ns(4))
        }
        .frame(height: ns(112))
    }

    /// Reference empty state: media prompt + shortcuts + mirror circle.
    private var emptyState: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                VStack(spacing: ns(8)) {
                    Text("No app seems to be running")
                        .font(.system(size: ns(14), weight: .semibold))
                        .foregroundStyle(contentSecondary)
                    Text("Wanna open one?")
                        .font(.system(size: ns(17), weight: .bold))
                        .foregroundStyle(contentPrimary)
                    HStack(spacing: ns(14)) {
                        AppSuggestionButton(kind: .music, action: openMusicApp)
                        AppSuggestionButton(kind: .youtube, action: openYouTube)
                    }
                    .padding(.top, ns(8))
                }
                .frame(width: ns(280))
                .frame(minHeight: ns(108))

                verticalDivider

                VStack(spacing: ns(12)) {
                    Image(systemName: "sparkles")
                        .font(.system(size: ns(22), weight: .regular))
                        .foregroundStyle(contentSecondary)
                    Text("Choose your shortcuts\nin settings.")
                        .font(.system(size: ns(15), weight: .semibold))
                        .foregroundStyle(contentMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Choose Shortcuts") {
                        openSettings()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: ns(14), weight: .bold))
                    .foregroundStyle(contentPrimary)
                    .padding(.horizontal, ns(18))
                    .padding(.vertical, ns(8))
                    .background(
                        RoundedRectangle(cornerRadius: ns(10), style: .continuous)
                            .fill(shortcutButtonBg)
                    )
                }
                .frame(width: ns(240))
                .frame(minHeight: ns(108))

                verticalDivider

                MirrorButton(
                    style: .hero,
                    isLivePreview: mirrorCamera.isRunning,
                    previewSession: mirrorCamera.session,
                    action: toggleMirrorPreview
                )
                    .frame(width: ns(144))
                    .frame(minHeight: ns(108))

                ForEach(supplementalWidgets, id: \.id) { widget in
                    verticalDivider
                    SupplementalNookWidgetCard(widget: widget, appModel: appModel)
                }
            }
            .padding(.horizontal, ns(4))
        }
        .frame(minHeight: ns(116))
        .padding(.vertical, ns(2))
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1)
            .padding(.vertical, ns(10))
            .padding(.horizontal, ns(24))
    }
}

struct SupplementalNookWidgetCard: View {
    let widget: WidgetViewModel
    @ObservedObject var appModel: AppModel
    @State private var isHovered = false

    var body: some View {
        Button {
            appModel.dispatch(.widgetAction(widgetId: widget.id, action: "tap"))
        } label: {
            Group {
                if widget.id == "calendar" {
                    CalendarSupplementView(widget: widget)
                } else {
                    NotesSupplementView(widget: widget)
                }
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

struct NotesSupplementView: View {
    let widget: WidgetViewModel
    private let cardBg = LinearGradient(
        colors: [Color.white.opacity(0.11), Color.white.opacity(0.07)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(alignment: .leading, spacing: ns(8)) {
            Text(widget.compactTitle)
                .font(.system(size: ns(13), weight: .bold))
                .foregroundStyle(contentPrimary)
            Text(widget.compactContent)
                .font(.system(size: ns(12), weight: .medium))
                .foregroundStyle(contentSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            HStack(spacing: ns(8)) {
                Circle().fill(Color.blue).frame(width: ns(10), height: ns(10))
                Spacer()
                HStack(spacing: ns(6)) {
                    ForEach(["bold", "italic", "underline"], id: \.self) { symbol in
                        Image(systemName: "textformat.\(symbol)")
                            .font(.system(size: ns(10), weight: .bold))
                            .foregroundStyle(contentSecondary)
                            .frame(width: ns(18), height: ns(18))
                            .background(Circle().fill(Color.white.opacity(0.09)))
                    }
                }
            }
        }
        .padding(ns(12))
        .frame(width: ns(210), height: ns(108), alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ns(18), style: .continuous)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: ns(18), style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: ns(0.8))
                )
        )
    }
}

struct CalendarSupplementView: View {
    let widget: WidgetViewModel

    private var days: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        let calendar = Calendar.current
        let now = Date()
        return (-2...2).compactMap {
            guard let d = calendar.date(byAdding: .day, value: $0, to: now) else { return nil }
            return formatter.string(from: d).uppercased()
        }
    }

    private var dayNumbers: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("d")
        let calendar = Calendar.current
        let now = Date()
        return (-2...2).compactMap {
            guard let d = calendar.date(byAdding: .day, value: $0, to: now) else { return nil }
            return formatter.string(from: d)
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ns(10)) {
            Text(monthTitle)
                .font(.system(size: ns(18), weight: .bold))
                .foregroundStyle(contentPrimary)
            HStack(spacing: ns(10)) {
                ForEach(Array(zip(days.indices, days)), id: \.0) { idx, day in
                    VStack(spacing: ns(2)) {
                        Text(day)
                            .font(.system(size: ns(9), weight: .bold))
                            .foregroundStyle(contentMuted)
                        Text(dayNumbers[idx])
                            .font(.system(size: ns(15), weight: idx == 2 ? .bold : .semibold))
                            .foregroundStyle(idx == 2 ? Color.blue : contentSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
            Text(widget.compactContent == "0 events" ? "Nothing for today" : widget.compactContent)
                .font(.system(size: ns(12), weight: .semibold))
                .foregroundStyle(contentSecondary)
        }
        .padding(ns(12))
        .frame(width: ns(230), height: ns(108), alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ns(18), style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: ns(18), style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: ns(0.8))
                )
        )
    }
}

struct WidgetCard: View {
    let widget: WidgetViewModel
    @ObservedObject var appModel: AppModel
    @State private var isHovered = false

    var body: some View {
        Button {
            appModel.dispatch(.widgetAction(widgetId: widget.id, action: "tap"))
        } label: {
            VStack(alignment: .leading, spacing: ns(6)) {
                Text(widget.compactTitle)
                    .font(.system(size: ns(12), weight: .medium))
                    .foregroundStyle(widgetTitleGray)
                Text(widget.compactContent)
                    .font(.system(size: ns(12), weight: .regular))
                    .foregroundStyle(contentSecondary)
                    .lineLimit(2)
            }
            .frame(minWidth: ns(110), maxWidth: ns(142), alignment: .leading)
            .padding(ns(14))
            .background(
                RoundedRectangle(cornerRadius: ns(16), style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.12) : widgetCardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: ns(16), style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: ns(0.8))
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

struct MirrorButton: View {
    enum Style {
        case hero
        case compact
    }

    var style: Style = .hero
    var isLivePreview: Bool = false
    var previewSession: AVCaptureSession? = nil
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            if style == .compact {
                VStack(spacing: ns(10)) {
                    ZStack {
                        if isLivePreview, let previewSession {
                            MirrorCameraPreview(session: previewSession)
                                .frame(width: ns(90), height: ns(90))
                        } else {
                            Circle()
                                .fill(isHovered ? Color.white.opacity(0.16) : mirrorCircleBg)
                                .frame(width: ns(90), height: ns(90))
                            Image(systemName: "web.camera.fill")
                                .font(.system(size: ns(27), weight: .medium))
                                .foregroundStyle(contentSecondary)
                        }
                    }
                    Text(isLivePreview ? "Live" : "Mirror")
                        .font(.system(size: ns(13), weight: .regular))
                        .foregroundStyle(contentSecondary)
                }
                .scaleEffect(isHovered ? 1.04 : 1)
            } else {
                VStack(spacing: ns(6)) {
                    if isLivePreview, let previewSession {
                        MirrorCameraPreview(session: previewSession)
                            .frame(width: ns(112), height: ns(112))
                    } else {
                        Image(systemName: "web.camera.fill")
                            .font(.system(size: ns(38), weight: .medium))
                        Text("Mirror")
                            .font(.system(size: ns(40 / 3), weight: .semibold))
                    }
                }
                .foregroundStyle(contentSecondary)
                .frame(width: ns(112), height: ns(112))
                .background(
                    Group {
                        if !isLivePreview {
                            Circle()
                                .fill(isHovered ? Color.white.opacity(0.16) : mirrorCircleBg)
                        }
                    }
                )
                .scaleEffect(isHovered ? 1.04 : 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

private struct MirrorCameraPreview: View {
    let session: AVCaptureSession

    var body: some View {
        MirrorCameraPreviewRepresentable(session: session)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: ns(1))
            )
    }
}

private struct MirrorCameraPreviewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> MirrorPreviewNSView {
        let view = MirrorPreviewNSView()
        view.setSession(session)
        return view
    }

    func updateNSView(_ nsView: MirrorPreviewNSView, context: Context) {
        nsView.setSession(session)
    }
}

private final class MirrorPreviewNSView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }

    func setSession(_ session: AVCaptureSession) {
        if previewLayer.session !== session {
            previewLayer.session = session
        }
    }
}

private final class MirrorCameraController: ObservableObject {
    @Published private(set) var isRunning = false
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "OpenNotch.MirrorCameraQueue")
    private var isConfigured = false

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.startSession()
                }
            }
        default:
            return
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.configureSessionIfNeeded()
            guard !self.session.isRunning else {
                DispatchQueue.main.async {
                    self.isRunning = true
                }
                return
            }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .high

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        session.commitConfiguration()
        isConfigured = true
    }
}

struct AppSuggestionButton: View {
    enum Kind {
        case music
        case youtube
    }

    let kind: Kind
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: ns(14), style: .continuous)
                    .fill(backgroundStyle)
                    .overlay(
                        RoundedRectangle(cornerRadius: ns(14), style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: ns(0.8))
                    )
                Image(systemName: iconName)
                    .font(.system(size: ns(kind == .music ? 26 : 20), weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: ns(56), height: ns(56))
            .shadow(color: .black.opacity(0.28), radius: ns(5), x: 0, y: ns(2))
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch kind {
        case .music: return "music.note"
        case .youtube: return "play.fill"
        }
    }

    private var backgroundStyle: LinearGradient {
        switch kind {
        case .music:
            return LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.46, blue: 0.62),
                    Color(red: 0.95, green: 0.04, blue: 0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .youtube:
            return LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.18, blue: 0.16),
                    Color(red: 0.92, green: 0.04, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
