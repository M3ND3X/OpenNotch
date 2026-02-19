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
    @StateObject private var notesModel = NookNotesModel()

    private var nook: NookViewModel { appModel.snapshot.nook }
    private var widgets: [WidgetViewModel] {
        nook.widgets.filter { $0.id != "placeholder" }
    }

    private var showDividers: Bool {
        appModel.snapshot.settings.nookShowDividers
    }

    private var enabledWidgetIds: Set<String> {
        let enabled = appModel.snapshot.settings.widgetsEnabled
        return enabled.isEmpty ? Set(widgets.map(\.id)) : Set(enabled)
    }

    private var supplementalWidgets: [WidgetViewModel] {
        return widgets.filter {
            ($0.id == "notes" || $0.id == "calendar") && enabledWidgetIds.contains($0.id)
        }
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

                dividerOrSpacer

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

                dividerOrSpacer

                MirrorButton(
                    style: .hero,
                    isLivePreview: mirrorCamera.isRunning,
                    previewSession: mirrorCamera.session,
                    action: toggleMirrorPreview
                )
                    .frame(width: ns(144))
                    .frame(minHeight: ns(108))

                ForEach(supplementalWidgets, id: \.id) { widget in
                    dividerOrSpacer
                    if widget.id == "calendar" {
                        CalendarSupplementView(widget: widget)
                    } else {
                        NotesSupplementView(notesModel: notesModel)
                    }
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

    @ViewBuilder
    private var dividerOrSpacer: some View {
        if showDividers {
            verticalDivider
        } else {
            Spacer().frame(width: ns(18))
        }
    }
}

private struct NotesSupplementView: View {
    @ObservedObject var notesModel: NookNotesModel
    @State private var isHovered = false

    private var titleBinding: Binding<String> {
        Binding(
            get: { notesModel.currentTitle },
            set: { notesModel.updateCurrentTitle($0) }
        )
    }

    private var bodyBinding: Binding<Data> {
        Binding(
            get: { notesModel.currentRTFData },
            set: { notesModel.updateCurrentRTF($0) }
        )
    }

    private var activeNoteTitle: String {
        let title = notesModel.currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return "Untitled" }
        return title
    }

    var body: some View {
        HStack(spacing: ns(8)) {
            VStack(alignment: .leading, spacing: ns(6)) {
                TextField("Untitled", text: titleBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: ns(22), weight: .bold, design: .rounded))
                    .foregroundStyle(contentPrimary)
                    .lineLimit(1)

                NoteRichTextEditor(
                    rtfData: bodyBinding,
                    onAttach: { notesModel.attach(textView: $0) },
                    onSelectionChange: { notesModel.refreshFormattingState() }
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: ns(8)) {
                    Circle().fill(Color.blue).frame(width: ns(10), height: ns(10))
                    Spacer()
                    HStack(spacing: ns(6)) {
                        formatButton(symbol: "A", active: false) {
                            notesModel.clearFormatting()
                        }
                        formatButton(symbol: "B", active: notesModel.formatting.bold) {
                            notesModel.toggleBold()
                        }
                        formatButton(symbol: "I", active: notesModel.formatting.italic) {
                            notesModel.toggleItalic()
                        }
                        formatButton(symbol: "U", active: notesModel.formatting.underline) {
                            notesModel.toggleUnderline()
                        }
                    }
                }
            }
            .padding(ns(12))
            .frame(width: ns(214), height: ns(108), alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ns(18), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ns(18), style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: ns(0.8))
                    )
            )

            VStack(spacing: ns(7)) {
                Text("\(notesModel.currentIndex + 1)")
                    .font(.system(size: ns(10), weight: .semibold))
                    .foregroundStyle(contentMuted)

                sideRailButton(icon: "triangle.fill") {
                    notesModel.rotate(by: -1)
                }
                sideRailButton(icon: "diamond.fill") {
                    notesModel.rotate(by: 1)
                }
                sideRailButton(icon: "square.fill") {
                    notesModel.addNote()
                }

                Text(activeNoteTitle)
                    .font(.system(size: ns(7), weight: .semibold))
                    .foregroundStyle(contentMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: ns(44), alignment: .center)
            }
            .frame(width: ns(46), height: ns(108))
            .background(
                RoundedRectangle(cornerRadius: ns(14), style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: ns(14), style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: ns(0.8))
                    )
            )
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.18), value: isHovered)
    }

    @ViewBuilder
    private func formatButton(symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: ns(13), weight: .bold))
                .foregroundStyle(active ? Color.white : contentSecondary)
                .frame(width: ns(26), height: ns(26))
                .background(
                    Circle()
                        .fill(active ? Color.white.opacity(0.22) : Color.white.opacity(0.09))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sideRailButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: ns(10), weight: .bold))
                .foregroundStyle(Color.blue.opacity(0.95))
                .frame(width: ns(24), height: ns(24))
                .background(
                    RoundedRectangle(cornerRadius: ns(9), style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}

struct CalendarSupplementView: View {
    let widget: WidgetViewModel

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: Date())
    }

    private var eventCount: Int {
        Int(widget.compactContent.split(separator: " ").first ?? "") ?? 0
    }

    private var statusText: String {
        if eventCount == 0 { return "Nothing for today" }
        if eventCount == 1 { return "1 upcoming event" }
        return "\(eventCount) upcoming events"
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func dayAbbr(for date: Date, isToday: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = isToday ? "EEE" : "EEEEE"
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("d")
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ns(8)) {
            HStack(alignment: .center, spacing: ns(10)) {
                Text(monthTitle)
                    .font(.system(size: ns(28), weight: .bold, design: .rounded))
                    .foregroundStyle(contentPrimary)

                Spacer(minLength: ns(6))

                HStack(spacing: ns(8)) {
                    ForEach(weekDates, id: \.self) { date in
                        let isToday = Calendar.current.isDateInToday(date)
                        VStack(spacing: ns(1)) {
                            Text(dayAbbr(for: date, isToday: isToday))
                                .font(.system(size: ns(8), weight: .bold))
                                .foregroundStyle(contentMuted)
                            Text(dayNumber(for: date))
                                .font(.system(size: ns(13), weight: isToday ? .bold : .semibold))
                                .foregroundStyle(isToday ? Color.blue : contentSecondary)
                        }
                    }
                }
            }

            Spacer(minLength: ns(2))

            VStack(spacing: ns(4)) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: ns(15), weight: .semibold))
                    .foregroundStyle(contentMuted)
                Text(statusText)
                    .font(.system(size: ns(13), weight: .semibold))
                    .foregroundStyle(contentSecondary)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ns(10))
        .padding(.vertical, ns(6))
        .frame(width: ns(250), height: ns(108), alignment: .leading)
    }
}

private struct NookNoteItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var rtfData: Data
}

private struct NoteFormattingState {
    var bold = false
    var italic = false
    var underline = false
}

@MainActor
private final class NookNotesModel: ObservableObject {
    @Published private(set) var notes: [NookNoteItem] = []
    @Published private(set) var currentIndex: Int = 0
    @Published var formatting = NoteFormattingState()

    private weak var activeTextView: NSTextView?
    private let storageKey = "OpenNotch.NookNotes.v1"

    init() {
        load()
    }

    var currentTitle: String {
        guard notes.indices.contains(currentIndex) else { return "" }
        return notes[currentIndex].title
    }

    var currentRTFData: Data {
        guard notes.indices.contains(currentIndex) else { return Self.defaultRTFData() }
        return notes[currentIndex].rtfData
    }

    func updateCurrentTitle(_ title: String) {
        guard notes.indices.contains(currentIndex) else { return }
        notes[currentIndex].title = title
        persist()
    }

    func updateCurrentRTF(_ data: Data) {
        guard notes.indices.contains(currentIndex) else { return }
        notes[currentIndex].rtfData = data
        persist()
    }

    func addNote() {
        notes.append(
            NookNoteItem(
                id: UUID(),
                title: "Note \(notes.count + 1)",
                rtfData: Self.defaultRTFData()
            )
        )
        currentIndex = max(0, notes.count - 1)
        persist()
        applyCurrentNoteToTextView()
        refreshFormattingState()
    }

    func rotate(by delta: Int) {
        guard !notes.isEmpty else { return }
        currentIndex = (currentIndex + delta + notes.count) % notes.count
        applyCurrentNoteToTextView()
        refreshFormattingState()
    }

    func attach(textView: NSTextView) {
        activeTextView = textView
        applyCurrentNoteToTextView()
        refreshFormattingState()
    }

    func refreshFormattingState() {
        guard let textView = activeTextView else {
            formatting = NoteFormattingState()
            return
        }
        let attrs = currentAttributes(in: textView)
        let font = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 12, weight: .medium)
        let traits = NSFontManager.shared.traits(of: font)
        formatting = NoteFormattingState(
            bold: traits.contains(.boldFontMask),
            italic: traits.contains(.italicFontMask),
            underline: (attrs[.underlineStyle] as? Int ?? 0) != 0
        )
    }

    func toggleBold() {
        toggleFontTrait(.boldFontMask)
    }

    func toggleItalic() {
        toggleFontTrait(.italicFontMask)
    }

    func toggleUnderline() {
        guard let textView = activeTextView else { return }
        let selected = textView.selectedRange()

        if selected.length == 0 {
            var attrs = textView.typingAttributes
            let enabled = (attrs[.underlineStyle] as? Int ?? 0) != 0
            attrs[.underlineStyle] = enabled ? 0 : NSUnderlineStyle.single.rawValue
            textView.typingAttributes = attrs
        } else if let storage = textView.textStorage {
            let attrs = storage.attributes(at: selected.location, effectiveRange: nil)
            let enabled = (attrs[.underlineStyle] as? Int ?? 0) != 0
            storage.beginEditing()
            storage.addAttribute(
                .underlineStyle,
                value: enabled ? 0 : NSUnderlineStyle.single.rawValue,
                range: selected
            )
            storage.endEditing()
        }

        updateCurrentFromTextView()
        refreshFormattingState()
    }

    func clearFormatting() {
        guard let textView = activeTextView else { return }
        let manager = NSFontManager.shared
        let selected = textView.selectedRange()

        let stripTraits: (NSFont) -> NSFont = { font in
            let noBold = manager.convert(font, toNotHaveTrait: .boldFontMask)
            return manager.convert(noBold, toNotHaveTrait: .italicFontMask)
        }

        if selected.length == 0 {
            var attrs = textView.typingAttributes
            let current = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: ns(12), weight: .medium)
            attrs[.font] = stripTraits(current)
            attrs[.underlineStyle] = 0
            textView.typingAttributes = attrs
        } else if let storage = textView.textStorage {
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: selected, options: []) { value, range, _ in
                let base = (value as? NSFont) ?? NSFont.systemFont(ofSize: ns(12), weight: .medium)
                storage.addAttribute(.font, value: stripTraits(base), range: range)
            }
            storage.addAttribute(.underlineStyle, value: 0, range: selected)
            storage.endEditing()
        }

        updateCurrentFromTextView()
        refreshFormattingState()
    }

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        guard let textView = activeTextView else { return }
        let manager = NSFontManager.shared
        let selected = textView.selectedRange()

        if selected.length == 0 {
            var attrs = textView.typingAttributes
            let current = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 12, weight: .medium)
            let hasTrait = manager.traits(of: current).contains(trait)
            let converted = hasTrait ? manager.convert(current, toNotHaveTrait: trait) : manager.convert(current, toHaveTrait: trait)
            attrs[.font] = converted
            textView.typingAttributes = attrs
        } else if let storage = textView.textStorage {
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: selected, options: []) { value, range, _ in
                let base = (value as? NSFont) ?? NSFont.systemFont(ofSize: 12, weight: .medium)
                let hasTrait = manager.traits(of: base).contains(trait)
                let converted = hasTrait ? manager.convert(base, toNotHaveTrait: trait) : manager.convert(base, toHaveTrait: trait)
                storage.addAttribute(.font, value: converted, range: range)
            }
            storage.endEditing()
        }

        updateCurrentFromTextView()
        refreshFormattingState()
    }

    private func applyCurrentNoteToTextView() {
        guard
            let textView = activeTextView,
            notes.indices.contains(currentIndex)
        else { return }

        let data = notes[currentIndex].rtfData
        let attributed = (try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )) ?? NSAttributedString(string: "")
        textView.textStorage?.setAttributedString(attributed)
    }

    private func updateCurrentFromTextView() {
        guard
            let textView = activeTextView,
            notes.indices.contains(currentIndex)
        else { return }
        let range = NSRange(location: 0, length: textView.attributedString().length)
        let data = textView.attributedString().rtf(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        notes[currentIndex].rtfData = data
        persist()
    }

    private func currentAttributes(in textView: NSTextView) -> [NSAttributedString.Key: Any] {
        let selected = textView.selectedRange()
        if selected.length > 0, let storage = textView.textStorage, storage.length > 0, selected.location < storage.length {
            return storage.attributes(at: selected.location, effectiveRange: nil)
        }
        return textView.typingAttributes
    }

    private func load() {
        if
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([NookNoteItem].self, from: data),
            !decoded.isEmpty
        {
            notes = decoded
            currentIndex = 0
            return
        }
        notes = [
            NookNoteItem(
                id: UUID(),
                title: "Dads",
                rtfData: Self.defaultRTFData()
            )
        ]
        currentIndex = 0
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static func defaultRTFData() -> Data {
        let base = NSAttributedString(string: "")
        return base.rtf(
            from: NSRange(location: 0, length: base.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }
}

private struct NoteRichTextEditor: NSViewRepresentable {
    @Binding var rtfData: Data
    let onAttach: (NSTextView) -> Void
    let onSelectionChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(rtfData: $rtfData, onSelectionChange: onSelectionChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isRichText = true
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.allowsUndo = true
        textView.textColor = NSColor.white.withAlphaComponent(0.9)
        textView.font = NSFont.systemFont(ofSize: ns(12), weight: .medium)
        textView.insertionPointColor = .white
        textView.textContainerInset = NSSize(width: 0, height: 1)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.delegate = context.coordinator

        context.coordinator.apply(data: rtfData, to: textView)
        onAttach(textView)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.applyIfNeeded(data: rtfData, to: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var rtfData: Data
        private let onSelectionChange: () -> Void
        private var isProgrammatic = false
        private var lastSerialized = Data()

        init(rtfData: Binding<Data>, onSelectionChange: @escaping () -> Void) {
            _rtfData = rtfData
            self.onSelectionChange = onSelectionChange
        }

        func applyIfNeeded(data: Data, to textView: NSTextView) {
            guard data != lastSerialized else { return }
            apply(data: data, to: textView)
        }

        func apply(data: Data, to textView: NSTextView) {
            isProgrammatic = true
            defer { isProgrammatic = false }
            let attributed = (try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )) ?? NSAttributedString(string: "")
            textView.textStorage?.setAttributedString(attributed)
            lastSerialized = data
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammatic else { return }
            guard let textView = notification.object as? NSTextView else { return }
            let range = NSRange(location: 0, length: textView.attributedString().length)
            let data = textView.attributedString().rtf(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            lastSerialized = data
            if rtfData != data {
                rtfData = data
            }
            onSelectionChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            onSelectionChange()
        }
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
