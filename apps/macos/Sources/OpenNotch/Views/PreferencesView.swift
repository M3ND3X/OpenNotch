// PreferencesView - Settings UI. All edits via dispatch(Command::UpdateSetting).
// Matches OpenNotch design: General, Gestures, Live Activities, Nook, Tray, Drop Area, License, About.

import SwiftUI

struct PreferencesView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedSection: SettingsSection = .general

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    Button {
                        selectedSection = section
                        appModel.selectedSettingsSection = section
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(section.title)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(width: 100, height: 56)
                        .foregroundStyle(selectedSection == section ? Color.blue : Color.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedSection == section ? Color.white.opacity(0.11) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            Group {
                switch selectedSection {
                case .general:
                    GeneralSettingsView(appModel: appModel)
                case .gestures:
                    GesturesSettingsView(appModel: appModel)
                case .liveActivities:
                    LiveActivitiesSettingsView(appModel: appModel)
                case .nook:
                    NookSettingsView(appModel: appModel)
                case .tray:
                    TraySettingsView(appModel: appModel)
                case .dropArea:
                    DropAreaSettingsView(appModel: appModel)
                case .license:
                    LicenseSettingsView(appModel: appModel)
                case .about:
                    AboutSettingsView(appModel: appModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 1040, height: 760)
        .onAppear {
            selectedSection = appModel.selectedSettingsSection
        }
        .onChange(of: appModel.selectedSettingsSection) { _, newValue in
            if selectedSection != newValue {
                selectedSection = newValue
            }
        }
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Launch at login:").font(.headline)
                    Toggle("Launch at login", isOn: genBool("start_at_login", get: { $0.startAtLogin }))
                }

                Group {
                    Text("Display Behavior:").font(.headline)
                    HStack {
                        Text("Show in fullscreen:")
                        Picker("", selection: genString("show_in_fullscreen", get: { $0.showInFullscreen })) {
                            Text("On notched screens").tag("on_notched")
                            Text("Always").tag("always")
                            Text("Never").tag("never")
                        }
                        .pickerStyle(.menu)
                    }
                    HStack {
                        Text("Media source:")
                        Picker("", selection: genString("media_source", get: { $0.mediaSource })) {
                            Text("System").tag("system")
                        }
                        .pickerStyle(.menu)
                    }
                }

                Group {
                    Text("Notch-specific Settings:").font(.headline)
                    Toggle("Prefer round buttons", isOn: genBool("prefer_round_buttons", get: { $0.preferRoundButtons }))
                    Text("Use capsules instead of rounded rectangles for buttons.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Translucent notch background (experimental)", isOn: genBool("translucent_notch_background", get: { $0.translucentNotchBackground }))
                    Toggle("Always open on hover", isOn: genBool("always_open_on_hover", get: { $0.alwaysOpenOnHover }))
                    Text("This will disable some of OpenNotch's gestures.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Disable haptics", isOn: genBool("disable_haptics", get: { $0.disableHaptics }))
                }

                Group {
                    Text("Typing effects:").font(.headline)
                    Toggle("Prevent from closing on mouse leave", isOn: genBool("prevent_close_on_mouse_leave", get: { $0.preventCloseOnMouseLeave }))
                    Toggle("Lock while typing", isOn: genBool("lock_while_typing", get: { $0.lockWhileTyping }))
                }

                Group {
                    Text("Content padding:").font(.headline)
                    SliderWithFieldU32(appModel: appModel, key: "content_padding", get: { $0.contentPadding }, range: 0...24)
                }

                Group {
                    Text("Notch fine tune:").font(.headline)
                    Text("OpenNotch tries its best to guess your notch size, but sometimes it can be a bit off. Here you can fine tune it. It has to be exactly the same of your notch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("Width:")
                        SliderWithFieldI32(appModel: appModel, key: "notch_width_fine_tune", get: { $0.notchWidthFineTune }, range: -20...20)
                    }
                    HStack {
                        Text("Height:")
                        SliderWithFieldI32(appModel: appModel, key: "notch_height_fine_tune", get: { $0.notchHeightFineTune }, range: -20...20)
                    }
                }

                Group {
                    Text("Handler (no-notch screens):").font(.headline)
                    Toggle("Enable", isOn: genBool("handler_enable", get: { $0.handlerEnable }))
                    HStack {
                        Text("Width:")
                        SliderWithFieldU32(appModel: appModel, key: "handler_width", get: { $0.handlerWidth }, range: 100...300)
                    }
                    HStack {
                        Text("Height:")
                        SliderWithFieldU32(appModel: appModel, key: "handler_height", get: { $0.handlerHeight }, range: 4...24)
                    }
                    Toggle("Transparent handler", isOn: genBool("transparent_handler", get: { $0.transparentHandler }))
                    Text("Will only show up on mouse hover.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Group {
                    Text("Others:").font(.headline)
                    Toggle("Demo mode", isOn: genBool("demo_mode", get: { $0.demoMode }))
                    Text("Prevents OpenNotch from hiding when idle. Useful for screen recordings (this has no effect on non-notched screens).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Reset all settings") {
                        appModel.dispatch(.resetSettings)
                    }
                    Text("This will reset everything except your license.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Quit OpenNotch") {
                        NSApplication.shared.terminate(nil)
                    }
                    Text("You can also right click it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func genBool(_ key: String, get: @escaping (SettingsModel) -> Bool) -> Binding<Bool> {
        Binding(
            get: { get(appModel.snapshot.settings) },
            set: { appModel.dispatch(.updateSetting(key: key, value: .bool(value: $0))) }
        )
    }

    private func genString(_ key: String, get: @escaping (SettingsModel) -> String) -> Binding<String> {
        Binding(
            get: { get(appModel.snapshot.settings) },
            set: { appModel.dispatch(.updateSetting(key: key, value: .stringValue(value: $0))) }
        )
    }
}

// MARK: - Gestures

struct GesturesSettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Allow gestures when hovering the notch", isOn: gestBinding("allow_gestures_on_hover", { $0.allowGesturesOnHover }))
                Toggle("Open/close notch with vertical gestures", isOn: gestBinding("open_close_vertical_gestures", { $0.openCloseVerticalGestures }))
                Toggle("Control media with horizontal gestures", isOn: gestBinding("control_media_horizontal", { $0.controlMediaHorizontal }))
                Toggle("Invert media gestures actions", isOn: gestBinding("invert_media_gestures", { $0.invertMediaGestures }))
                Text("If on, a left swipe will start the next song, if off, the previous one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func gestBinding(_ key: String, _ get: @escaping (SettingsModel) -> Bool) -> Binding<Bool> {
        Binding(
            get: { get(appModel.snapshot.settings) },
            set: { appModel.dispatch(.updateSetting(key: key, value: .bool(value: $0))) }
        )
    }
}

// MARK: - Live Activities

struct LiveActivitiesSettingsView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedSubTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $selectedSubTab) {
                Text("General").tag(0)
                Text("Customize activities").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedSubTab == 0 {
                LiveActivitiesGeneralView(appModel: appModel)
            } else {
                LiveActivitiesCustomizeView(appModel: appModel)
            }
        }
    }
}

struct LiveActivitiesGeneralView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable live activities", isOn: laBool("live_activities_enable", { $0.liveActivitiesEnable }))
                Toggle("Hide in non notched screens", isOn: laBool("live_activities_hide_in_non_notched", { $0.liveActivitiesHideInNonNotched }))

                Group {
                    Text("Inactivity timeout:").font(.headline)
                    SliderWithFieldU32(appModel: appModel, key: "live_activities_inactivity_timeout", get: { $0.liveActivitiesInactivityTimeout }, range: 1...60)
                    Text("Tweak the time (in seconds) that live activities take to go away after they become inactive (like when music pauses).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Group {
                    Text("Interactivity:").font(.headline)
                    Toggle("Enable interactive activities", isOn: laBool("live_activities_enable_interactive", { $0.liveActivitiesEnableInteractive }))
                    Text("Allow some activities to interact with mouse click.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Enable Quick Peek", isOn: laBool("live_activities_enable_quick_peek", { $0.liveActivitiesEnableQuickPeek }))
                    Text("If enabled, some live activities will show a short info on mouse hover.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Unhide Automatically", isOn: laBool("live_activities_unhide_automatically", { $0.liveActivitiesUnhideAutomatically }))
                    Text("If enabled, live activities that have been dismissed (by swiping up) will automatically return.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Show song change", isOn: laBool("live_activities_show_song_change", { $0.liveActivitiesShowSongChange }))
                    Text("Show when a song changes while playing media via quick peek.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Group {
                    Text("HUD replacement:").font(.headline)
                    Toggle("Enable", isOn: laBool("live_activities_hud_replacement_enable", { $0.liveActivitiesHudReplacementEnable }))
                    Text("This setting requires you to provide OpenNotch with accessibility permissions. *Includes code from MediaKeyTap (MIT License) © 2016 Nicholas Hurden*")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Disable colors on audio HUD replacement", isOn: laBool("live_activities_hud_disable_colors", { $0.liveActivitiesHudDisableColors }))
                    Toggle("Show in all screens", isOn: laBool("live_activities_hud_show_all_screens", { $0.liveActivitiesHudShowAllScreens }))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func laBool(_ key: String, _ get: @escaping (SettingsModel) -> Bool) -> Binding<Bool> {
        Binding(
            get: { get(appModel.snapshot.settings) },
            set: { appModel.dispatch(.updateSetting(key: key, value: .bool(value: $0))) }
        )
    }
}

struct LiveActivitiesCustomizeView: View {
    @ObservedObject var appModel: AppModel

    private static let activities: [(id: String, label: String, icon: String, comingSoon: Bool)] = [
        ("media", "Media", "music.note", false),
        ("files_tray", "Files Tray", "folder", false),
        ("calendar", "Calendar", "calendar", false),
        ("notes", "Notes", "note.text", false),
        ("new_update", "New Update", "arrow.down.circle", false),
        ("bluetooth", "Bluetooth", "headphones", true),
        ("battery", "Battery", "battery.100", true),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Self.activities, id: \.id) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .frame(width: 24, alignment: .leading)
                        Text(item.label)
                        if item.comingSoon {
                            Text("Coming soon...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !item.comingSoon {
                            Toggle("", isOn: activityBinding(item.id))
                                .labelsHidden()
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func activityBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { appModel.snapshot.settings.liveActivitiesActivitiesEnabled.contains(id) },
            set: { enabled in
                var list = appModel.snapshot.settings.liveActivitiesActivitiesEnabled
                if enabled {
                    if !list.contains(id) { list.append(id) }
                } else {
                    list.removeAll { $0 == id }
                }
                appModel.dispatch(.updateSetting(key: "live_activities_activities_enabled", value: .stringList(value: list)))
            }
        )
    }
}

// MARK: - Nook

struct NookSettingsView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedSubTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $selectedSubTab) {
                Text("General").tag(0)
                Text("Customize widgets").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedSubTab == 0 {
                NookGeneralView(appModel: appModel)
            } else {
                NookCustomizeView(appModel: appModel)
            }
        }
    }
}

struct NookGeneralView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable nook", isOn: nookBinding("nook_enable"))
                Text("If disabled, clicking on the notch won't do anything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Show dividers between widgets", isOn: nookBinding("nook_show_dividers"))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nookBinding(_ key: String) -> Binding<Bool> {
        switch key {
        case "nook_enable":
            return Binding(
                get: { appModel.snapshot.settings.nookEnable },
                set: { appModel.dispatch(.updateSetting(key: key, value: .bool(value: $0))) }
            )
        case "nook_show_dividers":
            return Binding(
                get: { appModel.snapshot.settings.nookShowDividers },
                set: { appModel.dispatch(.updateSetting(key: key, value: .bool(value: $0))) }
            )
        default:
            return .constant(false)
        }
    }
}

struct NookCustomizeView: View {
    @ObservedObject var appModel: AppModel

    private static let widgets: [(id: String, label: String, icon: String, comingSoon: Bool)] = [
        ("calendar", "Calendar", "calendar", false),
        ("media", "Media Player", "music.note", false),
        ("shortcuts", "Shortcuts", "sparkles", false),
        ("camera", "Mirror", "camera.fill", false),
        ("notes", "Notes", "note.text", false),
        ("quick_apps", "Quick Apps", "square.grid.2x2", true),
        ("todos", "To-dos", "checklist", true),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Self.widgets, id: \.id) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .frame(width: 24, alignment: .leading)
                        Text(item.label)
                        if item.comingSoon {
                            Text("Coming soon...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !item.comingSoon {
                            Toggle("", isOn: widgetBinding(item.id))
                                .labelsHidden()
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func widgetBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: {
                let enabled = appModel.snapshot.settings.widgetsEnabled
                if enabled.isEmpty { return true }
                return enabled.contains(id)
            },
            set: { on in
                var list = appModel.snapshot.settings.widgetsEnabled
                if list.isEmpty {
                    list = Self.widgets.filter { !$0.comingSoon }.map(\.id)
                }
                if on {
                    if !list.contains(id) { list.append(id) }
                } else {
                    list.removeAll { $0 == id }
                }
                appModel.dispatch(.updateSetting(key: "widgets_enabled", value: .stringList(value: list)))
            }
        )
    }
}

// MARK: - Tray

struct TraySettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Width:")
                    SliderWithFieldU32(appModel: appModel, key: "tray_width", get: { $0.trayWidth }, range: 5...20)
                }
                Toggle("Ephemeral (clear on quit)", isOn: Binding(
                    get: { appModel.snapshot.settings.trayEphemeral },
                    set: { appModel.dispatch(.updateSetting(key: "tray_ephemeral", value: .bool(value: $0))) }
                ))
                HStack {
                    Text("Max items")
                    TextField("", value: Binding(
                        get: { Int(appModel.snapshot.settings.trayMaxItems) },
                        set: { appModel.dispatch(.updateSetting(key: "tray_max_items", value: .u32(value: UInt32($0)))) }
                    ), format: .number)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Drop Area

struct DropAreaSettingsView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedSubTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $selectedSubTab) {
                Text("General").tag(0)
                Text("Customize pipelines").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedSubTab == 0 {
                DropAreaGeneralView(appModel: appModel)
            } else {
                DropAreaCustomizeView(appModel: appModel)
            }
        }
    }
}

struct DropAreaGeneralView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Width:")
                    SliderWithFieldU32(appModel: appModel, key: "drop_area_width", get: { $0.dropAreaWidth }, range: 5...20)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DropAreaCustomizeView: View {
    @ObservedObject var appModel: AppModel

    private static let pipelines: [(id: String, label: String, icon: String, comingSoon: Bool)] = [
        ("compress_images", "Compress images", "photo", false),
        ("zip_unzip", "Zip / Unzip files", "doc.zipper", false),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Soon you'll be able to compress images, zip/unzip files and much more by dragging and dropping files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Pipelines:")
                    .font(.headline)
                    .padding(.top, 8)

                ForEach(Self.pipelines, id: \.id) { item in
                    HStack {
                        Image(systemName: item.icon)
                            .frame(width: 24, alignment: .leading)
                        Text(item.label)
                        if item.comingSoon {
                            Text("Coming soon...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !item.comingSoon {
                            Toggle("", isOn: pipelineBinding(item.id))
                                .labelsHidden()
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pipelineBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { appModel.snapshot.settings.dropAreaPipelinesEnabled.contains(id) },
            set: { enabled in
                var list = appModel.snapshot.settings.dropAreaPipelinesEnabled
                if enabled {
                    if !list.contains(id) { list.append(id) }
                } else {
                    list.removeAll { $0 == id }
                }
                appModel.dispatch(.updateSetting(key: "drop_area_pipelines_enabled", value: .stringList(value: list)))
            }
        )
    }
}

// MARK: - License

struct LicenseSettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("License")
                    .font(.headline)
                Text("License management coming soon.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - About

struct AboutSettingsView: View {
    @ObservedObject var appModel: AppModel

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev"
        return "v\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Image(systemName: "lamp.desk.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OpenNotch")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(appVersion)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("A premium notch layer for macOS built with Rust + SwiftUI.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Product")
                        .font(.headline)
                    Text("OpenNotch focuses on smooth notch interactions, customizable Nook + Tray surfaces, and first-class macOS integration.")
                        .foregroundStyle(.secondary)
                    Text("Core stack: Rust domain logic + SwiftUI/AppKit host.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Support")
                        .font(.headline)
                    Text("For feature requests and bug reports, use the OpenNotch project issue tracker.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Helpers

struct SliderWithFieldU32: View {
    @ObservedObject var appModel: AppModel
    let key: String
    let get: (SettingsModel) -> UInt32
    let range: ClosedRange<Double>

    init(appModel: AppModel, key: String, get: @escaping (SettingsModel) -> UInt32, range: ClosedRange<Double>) {
        self.appModel = appModel
        self.key = key
        self.get = get
        self.range = range
    }

    private var valueBinding: Binding<UInt32> {
        Binding(
            get: { get(appModel.snapshot.settings) },
            set: { appModel.dispatch(.updateSetting(key: key, value: .u32(value: $0))) }
        )
    }

    var body: some View {
        HStack {
            Slider(
                value: Binding(
                    get: { Double(get(appModel.snapshot.settings)) },
                    set: { appModel.dispatch(.updateSetting(key: key, value: .u32(value: UInt32($0)))) }
                ),
                in: range
            )
            TextField("", value: valueBinding, format: .number)
                .frame(width: 50)
        }
    }
}

struct SliderWithFieldI32: View {
    @ObservedObject var appModel: AppModel
    let key: String
    let get: (SettingsModel) -> Int32
    let range: ClosedRange<Double>

    init(appModel: AppModel, key: String, get: @escaping (SettingsModel) -> Int32, range: ClosedRange<Double>) {
        self.appModel = appModel
        self.key = key
        self.get = get
        self.range = range
    }

    private var valueBinding: Binding<Int32> {
        Binding(
            get: { get(appModel.snapshot.settings) },
            set: { appModel.dispatch(.updateSetting(key: key, value: .i32(value: $0))) }
        )
    }

    var body: some View {
        HStack {
            Slider(
                value: Binding(
                    get: { Double(get(appModel.snapshot.settings)) },
                    set: { appModel.dispatch(.updateSetting(key: key, value: .i32(value: Int32($0)))) }
                ),
                in: range
            )
            TextField("", value: valueBinding, format: .number)
                .frame(width: 50)
        }
    }
}
