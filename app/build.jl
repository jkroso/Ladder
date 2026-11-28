# Build Ladder as a standalone Mac app with JuliaC:
#
#     julia --project=. app/build.jl
#
# It writes build/Ladder.app, signed with your Developer ID certificate if your
# keychain has one. Add `--install` to copy it into /Applications too. See
# bundle.jl for what the build needs and the settings it takes. To make a
# release that other Macs open, run release.jl.
#
# Ladder isn't trimmed (JuliaC's trim_mode). A sheet and a live block run Julia
# code that the app has never seen, and a trimmed app can't compile new code.
#
# icon.jl draws the app's icon, icon.png.
#
# release.jl includes this file and calls `Build.build_ladder`.

module Build

using Kip
@use "./facts" => Facts
@use "../files/transcribe" => Transcribe
@use "../blocks/map" => Maps
@use "../web/hiddenpage" => Hidden

include("bundle.jl")

"""
Build Ladder into `build/Ladder.app` and return `(; app, version)`.
With `install=true`, copy the built app into /Applications.
`releasing`, `signer` and `packages` default to `Bundle`'s settings from the
`APP_*` environment variables and the packages Kip finds.
"""
function build_ladder(; install::Bool=false,
                        releasing::Bool=Bundle.is_releasing(),
                        signer::AbstractString=Bundle.default_signer(),
                        packages=Bundle.find_packages())
  version = Facts.app_version()
  # macOS asks before the app can read your Desktop, Documents and Downloads
  # folders, and shows this reason
  reason = "Ladder opens the Markdown files in it, and saves a file when you press ⌘S."
  # The program that writes down what's said in a recording goes in the app, beside Ladder's own. See transcribe.jl.
  transcriber = joinpath(mktempdir(), "transcribe")
  Transcribe.compile(transcriber)
  # The program that makes the picture of a map goes beside it. See map.jl.
  mapper = joinpath(mktempdir(), "map")
  Maps.compile(mapper)
  # The program that holds the pages of a site that you're signed in to goes beside them. See hiddenpage.jl.
  hider = joinpath(mktempdir(), "hiddenpage")
  Hidden.compile(hider)
  # CFBundleDocumentTypes tells macOS that the app opens Markdown files, so the Finder lists it under Open With.
  # Its rank is Alternate, so it doesn't take Markdown files from another app until you ask it to on the settings page.
  app = Bundle.build_app(
    name=Facts.APP_NAME,
    program=Facts.PROGRAM,
    id=Facts.APP_ID,
    version=version,
    entry=Facts.ENTRY_FILE,
    icon=Facts.ICON_FILE,
    helpers=[transcriber, mapper, hider],
    releasing=releasing,
    signer=signer,
    packages=packages,
    plist="""
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
          $(releasing ? "" : "<key>$(Facts.BUILT_HERE_KEY)</key><true/>")
          """)
  install && Bundle.install(app)
  (; app, version)
end

end

if abspath(PROGRAM_FILE) == @__FILE__
  Build.build_ladder(install="--install" in ARGS)
end
