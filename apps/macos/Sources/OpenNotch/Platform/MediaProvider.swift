// MediaProvider - AppleScript/ScriptingBridge for Music. Stub for now.

import Foundation

enum MediaProvider {
    @MainActor
    static func fetchAndDispatch(appModel: AppModel) {
        // TODO: AppleScript for Music.app now playing
        appModel.dispatch(.mediaStateReceived(stateJson: "{}"))
    }
}
