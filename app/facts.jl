# The facts about the Ladder app: its name, bundle identifier, paths and the
# files that go into it. Shared by app/bundle.jl, app/build.jl, app/icon.jl,
# app/app.jl, release.jl and update.jl.

const ROOT = normpath(joinpath(@__DIR__, ".."))

const APP_NAME = "Ladder"
const PROGRAM = "ladder"
const APP_ID = "com.jkroso.ladder"
const REPO = "jkroso/Ladder"
const BUILT_HERE_KEY = "LadderBuiltHere"
const MIN_MACOS = "12.0"
const LSREGISTER = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

const BUILD_DIR_NAME = "build"
const BUILD_DIR = joinpath(ROOT, BUILD_DIR_NAME)
const VERSION_FILE = joinpath(ROOT, "VERSION")

# The files in app/ and plugin/ that go into the built app
const ENTRY_FILE = joinpath(@__DIR__, "app.jl")
const ICON_FILE = joinpath(@__DIR__, "icon.png")
const STARTER_FILE = joinpath(@__DIR__, "starter.c")
const ENTITLEMENTS_FILE = joinpath(@__DIR__, "entitlements.plist")
const CLI_FILE = joinpath(ROOT, "plugin", "bin", PROGRAM)

# The welcome pages, live-block code files and assets packed into the app
const WELCOME_PAGES = (
  "welcome.md", "components.md", "julia.md",
  "settings/settings.md", "settings/code-editor.md", "settings/terminal.md", "settings/key-bindings.md",
  "schedule.md", "counter.md",
)
const WELCOME_CODE = ("widgets.jl", "progress.jl", "wall.jl")
const WELCOME_ASSETS = (
  "knot.stl", "satellite.glb", "bracket.sc", "session.vt",
  "knot.mp4", "hello.m4a", "plan.pdf", "costs.csv", "orders.json",
  "photos/1 footings.png", "photos/2 frame.png", "photos/3 roof.png",
  "photos/4 bricks.png", "photos/5 window.png", "photos/6 finished.png",
)
const WELCOME_FILES = (WELCOME_PAGES..., WELCOME_CODE..., WELCOME_ASSETS...)

"Read Ladder's version from the VERSION file"
app_version() = strip(read(VERSION_FILE, String))

"The zip file for a release of `version`"
zip_file(version) = joinpath(BUILD_DIR, "$APP_NAME-$version.zip")

"Ladder's folder in ~/Library/Application Support"
support_dir() = joinpath(homedir(), "Library", "Application Support", APP_NAME)
