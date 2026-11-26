# Build Ladder as a standalone Mac app with JuliaC:
#
#     julia --project=. app/build.jl
#
# It writes build/Ladder.app, signed with your Developer ID certificate if your
# keychain has one. Add `--install` to copy it into /Applications too. See bundle.jl for what the build needs and the
# settings it takes. To make a release that other Macs open, run release.jl.
#
# Ladder isn't trimmed (JuliaC's trim_mode). A sheet and a live block run Julia
# code that the app has never seen, and a trimmed app can't compile new code.
#
# icon.jl draws the app's icon, icon.png.

# release.jl includes bundle.jl itself, to check a few things before the build
@isdefined(build_app) || include("bundle.jl")

"Ladder's version, from the VERSION file"
const version = strip(read(joinpath(root, "VERSION"), String))

# macOS asks before the app can read your Desktop, Documents and Downloads
# folders, and shows this reason
reason = "Ladder opens the Markdown files in it, and saves a file when you press ⌘S."
# The program that writes down what's said in a recording goes in the app, beside Ladder's own. See transcribe.jl.
@use "../transcribe" => Transcribe
const transcriber = joinpath(mktempdir(), "transcribe")
Transcribe.compile(transcriber)
# The program that makes the picture of a map goes beside it. See map.jl.
@use "../map" => Maps
const mapper = joinpath(mktempdir(), "map")
Maps.compile(mapper)
# CFBundleDocumentTypes tells macOS that the app opens Markdown files, so the Finder lists it under Open With.
# Its rank is Alternate, so it doesn't take Markdown files from another app until you ask it to on the settings page.
const app = build_app(name="Ladder", program="ladder", id="com.jkroso.ladder", version=version,
          entry=joinpath(@__DIR__, "app.jl"), icon=joinpath(@__DIR__, "icon.png"), helpers=[transcriber, mapper], plist="""
            <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
            <key>NSDesktopFolderUsageDescription</key><string>$reason</string>
            <key>NSDocumentsFolderUsageDescription</key><string>$reason</string>
            <key>NSDownloadsFolderUsageDescription</key><string>$reason</string>
            <key>NSMicrophoneUsageDescription</key><string>Ladder records from the microphone when you insert a recording.</string>
            <key>CFBundleDocumentTypes</key>
            <array>
              <dict>
                <key>CFBundleTypeName</key><string>Markdown Document</string>
                <key>CFBundleTypeRole</key><string>Editor</string>
                <key>LSHandlerRank</key><string>Alternate</string>
                <key>LSItemContentTypes</key>
                <array><string>net.daringfireball.markdown</string></array>
              </dict>
            </array>
          $(releasing ? "" : "<key>LadderBuiltHere</key><true/>")
          """)
