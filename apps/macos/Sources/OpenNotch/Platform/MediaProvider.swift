// MediaProvider - best-effort system now-playing polling + media key transport controls.

import Foundation
import AppKit
import MediaPlayer

enum MediaTransportCommand {
    case playPause
    case next
    case previous
}

private struct MediaSnapshot: Codable, Equatable {
    var title: String
    var artist: String
    var album: String
    var app: String
    var isPlaying: Bool
    var positionSeconds: Double
    var durationSeconds: Double
    var artworkPath: String?
}

@MainActor
enum MediaProvider {
    private static weak var appModel: AppModel?
    private static var timer: Timer?
    private static var isPolling = false
    private static var lastPayload: String = "{}"
    private static var musicPlayerInfoObservers: [NSObjectProtocol] = []
    private static var cachedMusicSnapshot: MediaSnapshot?
    private static var cachedMusicSnapshotDate: Date?
    private static var pendingRefreshAgain = false
    private static var lastArtworkIdentifier: String?
    private static var lastArtworkPath: String?
    private static let pollingInterval: TimeInterval = 1.0
    private static let cachedMusicSnapshotTTL: TimeInterval = 8.0

    static func fetchAndDispatch(appModel: AppModel) {
        self.appModel = appModel
        startMusicPlayerInfoObserversIfNeeded()
        startPollingIfNeeded()
        pollOnce()
    }

    /// Call when the Nook overlay is shown so now-playing is refreshed immediately (e.g. Apple Music).
    static func requestRefresh(appModel: AppModel) {
        self.appModel = appModel
        startMusicPlayerInfoObserversIfNeeded()
        startPollingIfNeeded()
        pollOnce()
    }

    static func send(_ command: MediaTransportCommand) {
        switch command {
        case .playPause:
            postMediaKey(16) // NX_KEYTYPE_PLAY
        case .next:
            postMediaKey(17) // NX_KEYTYPE_NEXT
        case .previous:
            postMediaKey(18) // NX_KEYTYPE_PREVIOUS
        }
    }

    private static func startPollingIfNeeded() {
        guard timer == nil else { return }
        let newTimer = Timer(timeInterval: pollingInterval, repeats: true) { _ in
            Task { @MainActor in
                pollOnce()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private static func pollOnce() {
        guard appModel != nil else { return }
        if isPolling {
            pendingRefreshAgain = true
            return
        }
        isPolling = true
        pendingRefreshAgain = false

        Task.detached(priority: .utility) {
            let snapshot = await MainActor.run {
                queryNowPlaying()
            }
            await MainActor.run {
                isPolling = false
                applySnapshot(snapshot)
                if pendingRefreshAgain {
                    pendingRefreshAgain = false
                    pollOnce()
                }
            }
        }
    }

    private static func encode(_ snapshot: MediaSnapshot?) -> String {
        guard let snapshot else { return "{}" }
        guard let data = try? JSONEncoder().encode(snapshot) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func queryMediaRemote() -> MediaSnapshot? {
        let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        guard handle != nil else { return nil }

        typealias MRMediaRemoteGetNowPlayingInfoType = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
        typealias MRMediaRemoteGetNowPlayingApplicationPlaybackStateType = @convention(c) (DispatchQueue, @escaping (Int) -> Void) -> Void

        guard let symInfo = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo"),
              let symState = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPlaybackState") else {
            return nil
        }

        let MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(symInfo, to: MRMediaRemoteGetNowPlayingInfoType.self)
        let MRMediaRemoteGetNowPlayingApplicationPlaybackState = unsafeBitCast(symState, to: MRMediaRemoteGetNowPlayingApplicationPlaybackStateType.self)

        let group = DispatchGroup()
        var infoResult: [String: Any] = [:]
        var stateResult: Int = 0

        group.enter()
        MRMediaRemoteGetNowPlayingInfo(DispatchQueue.global(qos: .default)) { result in
            if let r = result {
                infoResult = r
            }
            group.leave()
        }

        group.enter()
        MRMediaRemoteGetNowPlayingApplicationPlaybackState(DispatchQueue.global(qos: .default)) { result in
            stateResult = result
            group.leave()
        }

        _ = group.wait(timeout: .now() + 1.0)

        // State: 1 is playing, 2 is paused, 0 is stopped/unknown
        if stateResult == 0 { return nil }

        let title = (infoResult["kMRMediaRemoteNowPlayingInfoTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if title.isEmpty { return nil }

        let artist = (infoResult["kMRMediaRemoteNowPlayingInfoArtist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let album = (infoResult["kMRMediaRemoteNowPlayingInfoAlbum"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let duration = (infoResult["kMRMediaRemoteNowPlayingInfoDuration"] as? Double) ?? 0
        let position = (infoResult["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double) ?? 0

        var artworkPathToUse: String? = lastArtworkPath
        var artworkIdentifier = infoResult["kMRMediaRemoteNowPlayingInfoArtworkIdentifier"] as? String
        if artworkIdentifier == nil {
            artworkIdentifier = "\(title.hashValue)-\(artist.hashValue)"
        }
        
        if artworkIdentifier != lastArtworkIdentifier {
            lastArtworkIdentifier = artworkIdentifier
            if let artworkData = infoResult["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                let tempDir = FileManager.default.temporaryDirectory
                let safeName = artworkIdentifier?.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_") ?? "now_playing"
                let fileURL = tempDir.appendingPathComponent("opennotch_nowplaying_art_\(safeName).jpg")
                do {
                    try artworkData.write(to: fileURL, options: .atomic)
                    artworkPathToUse = fileURL.path
                    lastArtworkPath = artworkPathToUse
                } catch {
                    print("🎵 MediaProvider: Failed to write artwork data: \(error)")
                }
            } else {
                lastArtworkPath = nil
                artworkPathToUse = nil
            }
        }

        // Usually it also has the application bundle identifier if we query another API, but we'll default to "Now Playing"
        let app = (infoResult["kMRMediaRemoteNowPlayingApplicationDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Now Playing"

        return MediaSnapshot(
            title: title,
            artist: artist,
            album: album,
            app: app.isEmpty ? "Now Playing" : app,
            isPlaying: stateResult == 1,
            positionSeconds: position,
            durationSeconds: duration,
            artworkPath: artworkPathToUse
        )
    }

    private static func queryNowPlaying() -> MediaSnapshot? {
        // Use MediaRemote private API as it works perfectly across all apps (Music, Safari, Chrome, Spotify)
        // and provides artwork data without permission prompts!
        if let mr = queryMediaRemote() { return mr }

        if let cached = validCachedMusicSnapshot() {
            return cached
        }

        // Prefer Music app (AppleScript) when available so Apple Music shows in Nook immediately
        if let music = queryMusic() { return music }
        if let system = queryNowPlayingInfoCenter() { return system }
        if let spotify = querySpotify() { return spotify }

        let chromeLikeApps = ["Google Chrome", "Brave Browser", "Microsoft Edge", "Arc", "Chromium"]
        for app in chromeLikeApps {
            if let browser = queryChromiumBased(browserName: app) {
                return browser
            }
        }

        if let safari = querySafari() { return safari }
        return nil
    }

    private static func queryNowPlayingInfoCenter() -> MediaSnapshot? {
        guard let info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return nil }
        let title = (info[MPMediaItemPropertyTitle] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }

        let artist = (info[MPMediaItemPropertyArtist] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let album = (info[MPMediaItemPropertyAlbumTitle] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let duration = (info[MPMediaItemPropertyPlaybackDuration] as? NSNumber)?.doubleValue ?? 0
        let position = (info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? NSNumber)?.doubleValue ?? 0
        let rate = (info[MPNowPlayingInfoPropertyPlaybackRate] as? NSNumber)?.doubleValue ?? 0
        let app = (info["kMRMediaRemoteNowPlayingApplicationDisplayName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let appName = (app?.isEmpty == false) ? app! : "Now Playing"

        return MediaSnapshot(
            title: title,
            artist: artist,
            album: album,
            app: appName,
            isPlaying: rate > 0.01,
            positionSeconds: position,
            durationSeconds: duration,
            artworkPath: nil
        )
    }

    private static func applySnapshot(_ snapshot: MediaSnapshot?) {
        guard let appModel else { return }
        let payload = encode(snapshot)
        appModel.cacheMediaStateJson(payload)
        guard payload != lastPayload else { return }
        lastPayload = payload
        appModel.dispatch(.mediaStateReceived(stateJson: payload))
    }

    private static func validCachedMusicSnapshot() -> MediaSnapshot? {
        guard let snapshot = cachedMusicSnapshot else { return nil }
        guard let updatedAt = cachedMusicSnapshotDate else { return nil }
        guard Date().timeIntervalSince(updatedAt) <= cachedMusicSnapshotTTL else { return nil }
        return snapshot
    }

    private static func startMusicPlayerInfoObserversIfNeeded() {
        guard musicPlayerInfoObservers.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        let observer = center.addObserver(forName: nil, object: nil, queue: .main) { notification in
            Task { @MainActor in
                let rawName = notification.name.rawValue.lowercased()
                let looksLikeMusicPlayerInfo =
                    (rawName.contains("music") || rawName.contains("itunes")) &&
                    (rawName.contains("playerinfo") || rawName.contains("nowplaying"))
                guard looksLikeMusicPlayerInfo else { return }

                let parsed = parseMusicPlayerInfo(notification.userInfo)
                cachedMusicSnapshot = parsed
                cachedMusicSnapshotDate = parsed == nil ? nil : Date()
                applySnapshot(parsed)
            }
        }
        musicPlayerInfoObservers.append(observer)
    }

    private static func parseMusicPlayerInfo(_ userInfo: [AnyHashable: Any]?) -> MediaSnapshot? {
        guard let userInfo else { return nil }

        let state = anyString(in: userInfo, keys: ["Player State", "state"])?.lowercased() ?? ""
        let playbackRate = anyDouble(
            in: userInfo,
            keys: [
                "Playback Rate",
                "kMRMediaRemoteNowPlayingInfoPlaybackRate",
            ]
        ) ?? 0

        if state == "stopped" || state == "stopping" {
            return nil
        }

        let title = anyString(
            in: userInfo,
            keys: [
                "Name",
                "Title",
                "title",
                "kMRMediaRemoteNowPlayingInfoTitle",
            ]
        ) ?? ""
        guard !title.isEmpty else { return nil }

        let artist = anyString(
            in: userInfo,
            keys: [
                "Artist",
                "artist",
                "kMRMediaRemoteNowPlayingInfoArtist",
            ]
        ) ?? ""
        let album = anyString(
            in: userInfo,
            keys: [
                "Album",
                "album",
                "kMRMediaRemoteNowPlayingInfoAlbum",
            ]
        ) ?? ""
        let position = anyDouble(
            in: userInfo,
            keys: [
                "Player Position",
                "Elapsed Time",
                "kMRMediaRemoteNowPlayingInfoElapsedTime",
            ]
        ) ?? 0
        let totalTimeRaw = anyDouble(
            in: userInfo,
            keys: [
                "Total Time",
                "Duration",
                "kMRMediaRemoteNowPlayingInfoDuration",
            ]
        ) ?? 0
        let duration = totalTimeRaw > 1000 ? (totalTimeRaw / 1000.0) : totalTimeRaw

        return MediaSnapshot(
            title: title,
            artist: artist,
            album: album,
            app: "Music",
            isPlaying: state == "playing" || playbackRate > 0.01,
            positionSeconds: position,
            durationSeconds: duration,
            artworkPath: nil
        )
    }

    private static func anyString(in userInfo: [AnyHashable: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = userInfo[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func anyDouble(in userInfo: [AnyHashable: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = userInfo[key] as? NSNumber {
                return value.doubleValue
            }
            if let value = userInfo[key] as? String, let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }
        return nil
    }

    private static func queryMusic() -> MediaSnapshot? {
        let script = """
        tell application "Music"
            if not running then return ""
            try
                set ps to (player state as text)
            on error
                return ""
            end try
            if ps is not "playing" and ps is not "paused" then return ""
            set tName to ""
            set tArtist to ""
            set tAlbum to ""
            set tPos to 0
            set tDur to 0
            try
                set tName to (name of current track)
            end try
            try
                set tArtist to (artist of current track)
            end try
            try
                set tAlbum to (album of current track)
            end try
            try
                set tPos to (player position)
            end try
            try
                set tDur to (duration of current track)
            end try
            return ps & "||" & tName & "||" & tArtist & "||" & tAlbum & "||" & (tPos as text) & "||" & (tDur as text)
        end tell
        """

        guard let raw = runAppleScript(script), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "||")
        guard parts.count >= 6 else { return nil }
        let title = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return MediaSnapshot(
            title: title,
            artist: parts[2].trimmingCharacters(in: .whitespacesAndNewlines),
            album: parts[3].trimmingCharacters(in: .whitespacesAndNewlines),
            app: "Music",
            isPlaying: parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "playing",
            positionSeconds: Double(parts[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            durationSeconds: Double(parts[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            artworkPath: nil
        )
    }

    private static func querySpotify() -> MediaSnapshot? {
        let script = """
        tell application "Spotify"
            if not running then return ""
            try
                set ps to (player state as text)
            on error
                return ""
            end try
            if ps is not "playing" and ps is not "paused" then return ""
            set tName to ""
            set tArtist to ""
            set tAlbum to ""
            set tDur to 0
            set tPos to 0
            try
                set tName to (name of current track)
            end try
            try
                set tArtist to (artist of current track)
            end try
            try
                set tAlbum to (album of current track)
            end try
            try
                set tDur to (duration of current track)
            end try
            try
                set tPos to (player position)
            end try
            return ps & "||" & tName & "||" & tArtist & "||" & tAlbum & "||" & (tPos as text) & "||" & (tDur as text)
        end tell
        """

        guard let raw = runAppleScript(script), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "||")
        guard parts.count >= 6 else { return nil }
        let title = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return MediaSnapshot(
            title: title,
            artist: parts[2].trimmingCharacters(in: .whitespacesAndNewlines),
            album: parts[3].trimmingCharacters(in: .whitespacesAndNewlines),
            app: "Spotify",
            isPlaying: parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "playing",
            positionSeconds: Double(parts[4].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            durationSeconds: Double(parts[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            artworkPath: nil
        )
    }

    private static func queryChromiumBased(browserName: String) -> MediaSnapshot? {
        let escapedBrowserName = browserName.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "\(escapedBrowserName)"
            if not running then return ""
            if (count of windows) is 0 then return ""
            set t to ""
            set u to ""
            try
                set t to title of active tab of front window
                set u to URL of active tab of front window
            on error
                return ""
            end try
            if u is missing value then return ""
            if u does not contain "youtube.com" and u does not contain "music.youtube.com" and u does not contain "soundcloud.com" and u does not contain "spotify.com" and u does not contain "apple.music.com" then return ""
            return t & "||" & u
        end tell
        """

        guard let raw = runAppleScript(script), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "||")
        guard parts.count >= 2 else { return nil }
        let title = cleanBrowserTitle(parts[0])
        guard !title.isEmpty else { return nil }
        return MediaSnapshot(
            title: title,
            artist: browserName,
            album: "",
            app: browserName,
            isPlaying: true,
            positionSeconds: 0,
            durationSeconds: 0,
            artworkPath: nil
        )
    }

    private static func querySafari() -> MediaSnapshot? {
        let script = """
        tell application "Safari"
            if not running then return ""
            if (count of windows) is 0 then return ""
            set t to ""
            set u to ""
            try
                set t to name of current tab of front window
                set u to URL of current tab of front window
            on error
                return ""
            end try
            if u is missing value then return ""
            if u does not contain "youtube.com" and u does not contain "music.youtube.com" and u does not contain "soundcloud.com" and u does not contain "spotify.com" and u does not contain "apple.music.com" then return ""
            return t & "||" & u
        end tell
        """

        guard let raw = runAppleScript(script), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "||")
        guard parts.count >= 2 else { return nil }
        let title = cleanBrowserTitle(parts[0])
        guard !title.isEmpty else { return nil }
        return MediaSnapshot(
            title: title,
            artist: "Safari",
            album: "",
            app: "Safari",
            isPlaying: true,
            positionSeconds: 0,
            durationSeconds: 0,
            artworkPath: nil
        )
    }

    private static func cleanBrowserTitle(_ raw: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = title.range(of: " - YouTube", options: .caseInsensitive) {
            title = String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return title
    }

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let descriptor = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return descriptor.stringValue
    }

    private static func postMediaKey(_ keyCode: Int32) {
        let keyDownData = Int((keyCode << 16) | (0xA << 8))
        let keyUpData = Int((keyCode << 16) | (0xB << 8))

        let down = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xA00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: keyDownData,
            data2: -1
        )
        let up = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xB00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: keyUpData,
            data2: -1
        )
        down?.cgEvent?.post(tap: .cghidEventTap)
        up?.cgEvent?.post(tap: .cghidEventTap)
    }
}
