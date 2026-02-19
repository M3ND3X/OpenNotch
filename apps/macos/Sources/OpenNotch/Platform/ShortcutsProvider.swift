// ShortcutsProvider - Runs shortcuts via Process. Effect::RunShortcut handled in EffectsExecutor.

import Foundation

enum ShortcutsProvider {
    static func runShortcut(name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        try? process.run()
        process.waitUntilExit()
    }
}
