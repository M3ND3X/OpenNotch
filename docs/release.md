# Release and Distribution

## Code Signing and Notarization

For distribution outside the Mac App Store:

1. **Developer ID**: Obtain an Apple Developer ID from the Apple Developer Program.

2. **Code Sign** the app:
   ```bash
   codesign --force --deep --sign "Developer ID Application: Your Name" \
     --options runtime \
     apps/macos/.build/release/OpenNotch
   ```

3. **Create a DMG** (optional):
   ```bash
   hdiutil create -volname OpenNotch -srcfolder apps/macos/.build/release/OpenNotch.app \
     -ov -format UDZO OpenNotch.dmg
   ```

4. **Notarize** with Apple:
   ```bash
   xcrun notarytool submit OpenNotch.dmg --apple-id your@email.com \
     --team-id TEAMID --password @keychain:AC_PASSWORD
   xcrun stapler staple OpenNotch.dmg
   ```

## Homebrew Cask

To distribute via Homebrew:

1. Create a cask in [homebrew-cask](https://github.com/Homebrew/homebrew-cask).
2. Use the notarized DMG URL as the download.
3. Example cask structure:
   ```ruby
   cask "opennotch" do
     version "0.1.0"
     sha256 "..."

     url "https://github.com/m3nd3x/OpenNotch/releases/download/v#{version}/OpenNotch.dmg"
     name "OpenNotch"
     desc "Notch-anchored overlay hub for macOS"
     homepage "https://github.com/m3nd3x/OpenNotch"

     app "OpenNotch.app"
   end
   ```
