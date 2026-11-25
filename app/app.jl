# The entry point for the Ladder app. build.jl compiles it with JuliaC.
#
# The code at the top level runs once, while the app is being built. It loads
# UI.jl and Ladder, reads the icons the app uses, and types into a document
# off screen so that code is compiled ahead of time. `main` runs each time the
# app opens.
#
# The app holds a copy of its welcome pages and of the source of each file it
# loaded. When it opens it writes them into its folder in ~/Library/Application
# Support, so the pages and their live blocks work on a Mac without the source.

include("start.jl")

@use ".." build_editor open_editor move_old_folders! run_startup! startup_page STARTUP_FOLDER STARTUP WELCOME restyle! problems pages_dir SIDEBAR_ICONS FILE_ICONS todo_at inbox Agent INSERTS PLAN_ICONS SCHEDULE_ICONS BLOCK_ICONS window! editors settings_editor theme! Update open! level! SOURCE_FILES kinds LAST_RUN Terms
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/abstract" focus window_of
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" load_icon
@use "github.com/jkroso/UI.jl/Interface/draw" frame popups
@use GeometryBasics: Vec2
# What the live blocks of the example pages load. A file that's loaded now is
# in the app. The app can't load a file that it hasn't seen.
@use "github.com/jkroso/UI.jl/Interface/Semantic" => Semantic
@use "github.com/jkroso/UI.jl/Interface/Semantic/ListTree" => ListTree
@use "../pages/widgets" => widgets
@use "../pages/progress" => progress_block
@use "../pages/wall" => wall_view
# The rest of Units.jl, for a page that works out costs in AUD or lengths in feet. Ladder loads only its
# main file. Money.jl needs FixedPointDecimals, so that package is in Ladder's Project.toml.
@use "github.com/jkroso/Units.jl/Money.jl" => money_units
@use "github.com/jkroso/Units.jl/Imperial.jl" => imperial_units
@use "github.com/jkroso/Units.jl/Colloquial.jl" => colloquial_units
@use "github.com/jkroso/Units.jl/Typography.jl" => typography_units
# Julia's own libraries that code from the startup page is likely to use, like the one that talks to a
# server. The app has no source of them, so a library that isn't loaded now can't be loaded later.
import LibCURL, NetworkOptions, Sockets, Dates, Base64, Random, Libdl

building && start_packages()

# Icons are read from UI.jl's Icons folder the first time they're drawn. Reading
# them now keeps them in the app, so it doesn't need that folder.
foreach(load_icon, ["arrow-return-left", "check", "chevron-down", "chevron-right", "chevron-up", "copy", "file-earmark", "file-earmark-text", "folder", "eye", "bell-fill", "bell",
                    "ladder", "layout-sidebar", "pause-fill", "play-fill", "record-fill", "search", "stop-fill", "text-center", "text-left",
                    "text-paragraph", "text-right", "x-lg", SIDEBAR_ICONS..., FILE_ICONS..., PLAN_ICONS..., SCHEDULE_ICONS..., BLOCK_ICONS...])

# The welcome page's text, to type into while the app warms up
const page = read(WELCOME, String)

# --- what the app needs on a Mac without the source ----------------------------
#
# A live block names the code it uses by path, like "github.com/jkroso/UI.jl/Interface/Semantic"
# or "./widgets.jl". Kip turns the path into a file and gives back the module it
# loaded from that file. The app has the modules, but the files are on the Mac
# that built it. So the app keeps the text of each file, writes the files out
# when it opens, and tells Kip which module goes with each one.

const PAGES = dirname(WELCOME)
"The text of each of the app's own pages, by the file's place in the folder of pages. The model, the video, the recording, the plan, the table and the pictures that the pages show are here too, as the bytes of their files."
const pages = Dict(name => read(joinpath(PAGES, name), String)
                   for name in ("welcome.md", "components.md", "julia.md", "settings/settings.md", "settings/code-editor.md", "settings/key-bindings.md", "schedule.md", "counter.md", "widgets.jl", "progress.jl", "wall.jl", "knot.stl", "satellite.glb", "bracket.sc", "session.vt", "knot.mp4", "hello.m4a", "plan.pdf", "costs.csv", "orders.json",
                               "photos/1 footings.png", "photos/2 frame.png", "photos/3 roof.png", "photos/4 bricks.png", "photos/5 window.png", "photos/6 finished.png"))

"The `user/repo/file` that a file Kip got from GitHub has there, or nothing for any other file. A file of Ladder's own has a place too, so that the app can show the code that draws a thing."
place(path) = begin
  ladder = realpath(dirname(@__DIR__))
  startswith(path, ladder * "/") && return joinpath("jkroso", "Ladder", relpath(path, ladder))
  if startswith(path, Kip.refs * "/")
    # Kip keeps a copy of each commit at refs/user/repo/commit
    user, repo, _, rest... = splitpath(relpath(path, Kip.refs))
    return joinpath(user, repo, rest...)
  end
  # A repo that's linked to a folder on this Mac is used from that folder
  for user in readdir(Kip.repos), repo in readdir(joinpath(Kip.repos, user))
    dir = joinpath(Kip.repos, user, repo)
    ispath(dir) || continue
    dir = realpath(dir)
    startswith(path, dir * "/") && return joinpath(user, repo, relpath(path, dir))
  end
  nothing
end

"Each file Kip loaded from a GitHub repo: where it is on this Mac, its place in the repo and its text"
const sources = [(path, place(path), read(path, String)) for path in keys(Kip.modules)
                 if isabspath(path) && isfile(path) && place(path) !== nothing]
"The registered packages that were loaded by a GitHub path, as `user/repo`"
const packages = [joinpath(m[1], m[2]) for m in (match(r"^github\.com/([^/]+)/([^/@]+)", k) for k in keys(Kip.modules)) if m !== nothing]
"The Julia files that the pages load, and where each one was when the app was built"
const code_files = Dict(name => realpath(joinpath(PAGES, name)) for name in ("widgets.jl", "progress.jl", "wall.jl"))

"The text of the `ladder` command for the terminal, which shows a file or what a pipe sends: see plugin/bin/ladder"
const ladder_command = read(joinpath(dirname(@__DIR__), "plugin", "bin", "ladder"), String)

"Ladder's folder for its own files"
support() = joinpath(homedir(), "Library", "Application Support", "Ladder")

"Write `text` to `file` unless it holds that already"
put(file, text) = (isfile(file) && read(file, String) == text) || (mkpath(dirname(file)); write(file, text))

"""
Write the pages and the source files into `dir`, and tell Kip to look there.
Returns the path of the welcome page. A page you changed is kept until a newer
version of the app has a page that's different from the one it wrote. A page
that an older version wrote, and this version doesn't have, is deleted unless
you changed it.
"""
unpack(dir) = begin
  repos = joinpath(dir, "source")
  for (old, at, text) in sources
    file = joinpath(repos, at)
    put(file, text)
    Kip.modules[realpath(file)] = Kip.modules[old]
    # A method names its file as it was on the Mac that built the app. This says where the file is here.
    SOURCE_FILES[old] = realpath(file)
  end
  # Kip loads a registered package by name if its folder has a Project.toml with a name
  foreach(p -> put(joinpath(repos, p, "Project.toml"), "name = \"$(splitext(basename(p))[1])\"\n"), packages)
  setglobal!(Kip, :repos, repos)
  setglobal!(Kip, :refs, joinpath(dir, "refs"))
  # A file that the app wasn't built with, like one that defines a kind of block, is loaded from its
  # source. Kip compiles such a file with a Julia that the app doesn't have, so it's told not to try.
  ENV["KIP_FROZEN"] = "1"
  # Kip gives the file's module `using Kip`, which looks for a package called Kip. This folder says
  # that it's the Kip that's in the app already. It says the same of every other package that the
  # app has, so code that the startup page loads can use each of them by its name.
  env = joinpath(dir, "env")
  deps = sort!(unique!(["$(id.name) = \"$(id.uuid)\"" for id in keys(Base.loaded_modules) if id.uuid !== nothing]))
  put(joinpath(env, "Project.toml"), "[deps]\n" * join(deps, "\n") * "\n")
  env in LOAD_PATH || push!(LOAD_PATH, env)
  # Julia looks for a package's name in the active project first. That was Ladder's own project on
  # the Mac that built the app, and its file isn't on this Mac. So the app's own list is the active one.
  Base.set_active_project(joinpath(env, "Project.toml"))
  # For a line like `@use Dates`, Kip looks first in the folder that the app was started in, which can
  # be any folder, and one that the app may not read. The app's own list is the place to look.
  setglobal!(Kip, :initial_pwd, env)
  welcome = joinpath(dir, "Welcome")
  for (name, text) in pages
    file, was = joinpath(welcome, name), joinpath(dir, "written", name)
    # Leave a page alone if you changed it and this version's page is the one it wrote before
    (isfile(file) && isfile(was) && read(was, String) == text) && continue
    put(file, text)
    put(was, text)
  end
  # A page that moved, like a page of the settings, leaves the place that an older version wrote it to
  for (folder, _, names) in walkdir(joinpath(dir, "written")), n in names
    was = joinpath(folder, n)
    name = relpath(was, joinpath(dir, "written"))
    haskey(pages, name) && continue
    file = joinpath(welcome, name)
    (!isfile(file) || read(file) == read(was)) && (rm(file, force=true); rm(was))
  end
  for (name, file) in code_files
    Kip.modules[realpath(joinpath(welcome, name))] = Kip.modules[file]
    # The code of a block of the welcome pages shows in the copy that's beside those pages, which a save loads again
    SOURCE_FILES[file] = realpath(joinpath(welcome, name))
  end
  # The command for the terminal is in a folder that the user's PATH can name, as the welcome page says
  command = joinpath(dir, "bin", "ladder")
  put(command, ladder_command)
  chmod(command, 0o755)
  pages_dir[] = welcome
  joinpath(welcome, "welcome.md")
end

"""
Draw every part of each page in `dir`, and fail if a live block on one shows an
error. An editor only runs the blocks that are on screen, so this scrolls down
each page a screen at a time.
"""
check_pages(dir) = begin
  for name in ("welcome.md", "components.md", "julia.md", "settings/settings.md", "settings/code-editor.md", "settings/key-bindings.md", "schedule.md", "counter.md")
    empty!(problems)
    e = build_editor(joinpath(dir, name))
    w = Window(e, title="check", size=(1100px, 800px))
    frame(w)
    for top in 0:600:ceil(Int, e.scroll.content_height.value)
      e.scroll.offset = px(top)
      frame(w); frame(w)
    end
    isempty(problems) || error("A live block in $name failed: ", join(unique(problems), "\n"))
  end
  # A `result` block, like the welcome page's wall, runs its code in a task, and the last task
  # stays in LAST_RUN. Julia can't write a task into the app, so the build failed with "Task cannot be serialized".
  run = LAST_RUN[]
  run === nothing || (try wait(run) catch end; LAST_RUN[] = nothing)
  nothing
end

# An email for the warm-up, with the kinds of thing that email is made of: a table in a table, cells over two
# columns, a button, a float, a list, a picture that's written into it, and CSS for a narrow window
const WARM_EMAIL = """
<html><head><style>
body { margin: 0; background: #f4f4f4; font-family: -apple-system, 'Helvetica Neue', Arial, sans-serif }
.card { background: white; border: 1px solid #ddd; border-radius: 8px; box-shadow: 0 2px 6px rgba(0,0,0,.15) }
.btn { display: inline-block; background: linear-gradient(#2a7de1, #0a5cc2); color: white; padding: 10px 22px; border-radius: 6px; text-decoration: none }
h1 { font-size: 22px; margin: 0 0 12px } .muted { color: #777; font-size: 12px; line-height: 150% }
@media (max-width: 480px) { .wide { display: none } }
</style></head><body bgcolor="#f4f4f4">
<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding: 20px">
<table class="card" width="560" cellpadding="16" cellspacing="0" style="max-width: 100%"><tr><td colspan="2">
<h1>Your order has shipped 🎉</h1>
<p>Hello <b>Sam</b>, your order <a href="https://example.com/o/1">#1042</a> is on its way.<br>It should arrive by <i>Friday</i>, and you can <u>track it</u> at any time. <s>Thursday</s> <code>AB-12</code> x<sup>2</sup></p>
<img align="right" width="40" height="30" hspace="6" alt="A box" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAADCAIAAAA2iEnWAAAAFElEQVR4nGM8EaDBwMDAxAAGUAoAGLQBRuAULBsAAAAASUVORK5CYII=">
<ul><li>Timber screws, a box of 500</li><li>Decking oil, 4 L</li></ul><ol type="a"><li>First</li><li>Second</li></ol>
<blockquote style="border-left: 2px solid #ccc; margin: 0 0 0 8px; padding-left: 8px">A note from the shop, which is long enough to go onto a second line of the email when the window is narrow.</blockquote>
<pre>one  two</pre><hr></td></tr>
<tr bgcolor="#eef"><th align="left" width="70%">Item</th><th align="right">Price</th></tr>
<tr><td style="border-bottom: 1px dashed #ddd">Screws <span style="display:inline-block; padding: 2px 6px; background: #eee; border-radius: 3px">new</span></td><td align="right" valign="top">\$48.00</td></tr>
<tr><td colspan="2" align="center"><a class="btn" href="https://example.com/track">Track your order</a>
<div style="float: left; width: 80px; height: 20px; background: #cde"></div><div style="overflow: hidden; opacity: 0.8; position: relative">Beside it<span style="position: absolute; top: 0; right: 0">●</span></div>
<p class="muted wide" style="clear: both; text-align: center">You got this email because you ordered from us.</p></td></tr>
</table></td></tr></table></body></html>
"""

"The markup that makes a line of the warm-up's page draw another way: inline code that runs, inline code, a formula, links, a picture, bold, struck words, HTML, a table's cells and a to-do box"
const LINE_MARKS = ("!`", "`", "\$", "[[", "](", "![", "**", "~~", "<", "|", "[ ]", "[x]")

"""
Open a copy of the welcome page in a throwaway folder and send input to a
window that isn't on screen. While the app is built this compiles the code it
runs. `--self-test` runs it again inside the finished app, to check that code
is all still there.
"""
warm_up() = begin
  dir = mktempdir()
  write(joinpath(dir, "welcome.md"), page)
  write(joinpath(dir, "notes.md"), "# Notes\n\nSome text.\n")
  e = build_editor(joinpath(dir, "welcome.md"))
  # A word that's spelt wrong adds items to the page's menu, and the clicks below count on where its items are
  e.spelling = false
  w = window!(e, title="warm up", size=(1100px, 800px))
  hold(keys) = foreach(k -> (w.keys |= k), keys)
  release(keys) = foreach(k -> (w.keys ⊻= k), keys)
  press(k, mods...) = (hold(mods); onkey(w, KeyPress{k}(0, w)); onkey(w, KeyRelease{k}(0, w)); release(mods); frame(w))
  mouse(x, y) = (pos = Vec2{px}(px(x), px(y)); onmouse(w, MouseMove(pos, w)); w.mouse = pos; frame(w))
  click(x, y) = begin
    mouse(x, y)
    hold((Keys.mouse_left,)); onkey(w, KeyPress{Keys.mouse_left}(0, w))
    release((Keys.mouse_left,)); onkey(w, KeyRelease{Keys.mouse_left}(0, w))
    frame(w)
  end
  right_click(x, y) = begin
    mouse(x, y)
    hold((Keys.mouse_right,)); onkey(w, KeyPress{Keys.mouse_right}(0, w))
    release((Keys.mouse_right,)); onkey(w, KeyRelease{Keys.mouse_right}(0, w))
    frame(w)
  end
  frame(w)
  # Each set of colours and each font
  for theme in (:paper, :night, :sepia), font in ("Helvetica Neue", "Charter")
    e.theme, e.font = theme, font
    restyle!(e)
    frame(w)
  end
  # Down the whole page a line at a time: through the table, the code, the live blocks and the sheet
  typed = Set{Any}()
  for _ in 1:length(e.buf.lines)
    press(Keys.down)
    # Type, go to the next cell and back, select and undo, in whatever the caret is in. That's done in the first
    # line of each kind. Another line like it compiles nothing more, and the typing in every line was most of the
    # time that a build took, since a build runs this four times.
    i = e.buf.caret[1]
    line, text = kinds(e.buf)[i], e.buf.lines[i]
    like = (line.kind, line.level, line.lang, map(mark -> occursin(mark, text), LINE_MARKS))
    like in typed && continue
    push!(typed, like)
    press(Keys.a); press(Keys.backspace)
    press(Keys.tab); press(Keys.tab, Keys.shft)
    press(Keys.right, Keys.shft); press(Keys.left)
    press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd)
  end
  # A new line at the end, a list and a new sheet
  press(Keys.down, Keys.cmd); press(Keys.enter)
  foreach(press, (Keys.minus, Keys.space, Keys.a, Keys.enter, Keys.enter))
  foreach(press, (Keys.tilde, Keys.tilde, Keys.tilde, Keys.s, Keys.h, Keys.e, Keys.e, Keys.t, Keys.enter))
  foreach(press, (Keys.a, Keys.tab, Keys.var"2", Keys.enter, Keys.b, Keys.tab, Keys.a, Keys.enter, Keys.enter))
  # Select everything, copy nothing, make it bold and undo
  press(Keys.a, Keys.cmd); press(Keys.b, Keys.cmd); press(Keys.z, Keys.cmd); press(Keys.escape)
  # Bigger and smaller text, the sidebar and the file finder
  press(Keys.equal, Keys.cmd); press(Keys.minus, Keys.cmd); press(Keys.var"0", Keys.cmd)
  press(Keys.backslash, Keys.cmd); press(Keys.backslash, Keys.cmd)
  # The sidebar with the keyboard: the headings of each file, then Return on a heading and on a file
  press(Keys.backslash, Keys.cmd, Keys.shft)
  for _ in 1:2
    press(Keys.right); press(Keys.down); press(Keys.right); press(Keys.down); press(Keys.left); press(Keys.left); press(Keys.down)
  end
  press(Keys.up); press(Keys.right); press(Keys.down); press(Keys.enter)
  press(Keys.backslash, Keys.cmd, Keys.shft); press(Keys.up); press(Keys.enter)
  # A click on a name in the sidebar, and on the arrow beside it
  click(60, 88); click(19, 88)
  # The menu of a file: open it and click away, then rename the file and change your mind
  right_click(60, 88); click(700, 500)
  right_click(60, 88); click(80, 104)
  press(Keys.a); press(Keys.escape); press(Keys.escape)
  # The menu of the page: open it and click away, then add a block of each kind from its Insert menu.
  # Ladder draws the menu, 28px for each item. `pick` clicks the item with the name it's given, where
  # the menu is: a menu that would run off the bottom of the window moves up, an item that's grey isn't
  # in it, and the items above Insert change. A recording is left out, since it would record from the
  # microphone while the app is built.
  items() = only(p for p in popups(w) if p.key == :menu).content.items
  pick(name) = begin
    menu = only(p for p in popups(w) if p.key == :menu)
    k = findfirst(in((name, name * "  ›")), menu.content.items)
    k === nothing && error("The menu has no item called $name. Its items are ", join(menu.content.items, ", "))
    click(540, round(Int, menu.scene.top.value) + 1 + 28(k - 1) + 14)
  end
  right_click(500, 300); click(900, 600)
  blocks = [x[1] for x in INSERTS if x isa Tuple]
  for block in blocks
    block == "Recording" && continue
    right_click(500, 300); pick("Insert")
    # Front Matter is grey in a page that has it
    block in items() || (click(900, 600); continue)
    pick(block)
    # Type in the new block, press Return and type again, then undo it all
    press(Keys.a); press(Keys.enter); press(Keys.b)
    press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd)
  end
  # A line that holds a sound file shows a player, with a button that transcribes it. Every Mac has this sound.
  press(Keys.down, Keys.cmd); press(Keys.enter)
  foreach(c -> ontype(e, Typed(c, w)), "![A sound](/System/Library/Sounds/Glass.aiff)")
  press(Keys.enter)
  press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd)
  # A to-do item, then a click on its box to tick it
  right_click(500, 300); pick("Insert"); pick("To-do")
  press(Keys.a); press(Keys.up, Keys.cmd)
  x = e.origin[1] + 6px
  y = findfirst(y -> todo_at(e, (x, px(y))) !== nothing, 80:4:780)
  y === nothing || click(x.value, (80:4:780)[y])
  press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd); press(Keys.z, Keys.cmd)
  # Select All from the menu. Nothing here cuts, copies or pastes, so the clipboard stays as it was.
  right_click(500, 300); pick("Select All"); press(Keys.escape)
  press(Keys.backslash, Keys.cmd)
  frame(w)
  press(Keys.o, Keys.cmd); press(Keys.n); press(Keys.escape)
  # The command palette: its list, then the chip of its first command, Autosave, which is a switch. Space turns the switch
  # and runs nothing. Esc empties the bar, and Esc again closes it, so the page and the settings are as they were.
  press(Keys.p, Keys.cmd, Keys.shft); press(Keys.down); press(Keys.up); press(Keys.enter); press(Keys.space); press(Keys.escape); press(Keys.escape)
  # The project picker, then the page drawn for paper. A window that isn't on the screen shows no print panel.
  press(Keys.p, Keys.cmd); press(Keys.escape)
  press(Keys.p, Keys.cmd, Keys.opt)
  # The settings window. A setting that changes there changes in this window too, and ⌘W closes the settings window.
  press(Keys.comma, Keys.cmd)
  settings = settings_editor()
  sw = window_of(settings)
  frame(sw)
  was = e.theme
  theme!(settings, :night); frame(sw); frame(w)
  e.theme == :night || error("A change to a setting in the settings window didn't reach the other window")
  theme!(settings, was); frame(sw); frame(w)
  sw.keys |= Keys.cmd; onkey(sw, KeyPress{Keys.w}(0, sw))
  settings_editor() === nothing || error("⌘W didn't close the settings window")
  # The mouse over the top bar's buttons, and a click and a drag on the page
  foreach(x -> mouse(x, 22), (50, 550, 1000, 1075))
  press(Keys.up, Keys.cmd)
  click(400, 200); click(400, 200); click(500, 400)
  # Something else changes the file while the page has a change that isn't saved, and the page keeps both
  press(Keys.down, Keys.cmd); press(Keys.enter)
  file = e.buf.path
  write(file, "A line from outside\n\n" * read(file, String))
  frame(w)
  e.buf.lines[1] == "A line from outside" || error("The page didn't take a change that was made to its file")
  # An agent waits for the page, and ⌘Return sends it. This process stands in for the agent's
  # script, and the files that the two talk through go in a folder of their own.
  Agent.place[] = mktempdir()
  write(joinpath(Agent.place[], "$(getpid()).wait"), realpath(file) * "\nthe agent\n")
  delete!(e.nodes, :agents)
  frame(w)
  press(Keys.enter, Keys.cmd)
  isfile(joinpath(Agent.place[], "$(getpid()).sent")) || error("The page wasn't sent to the agent that waited for it")
  rm(Agent.place[], recursive=true)
  Agent.place[] = ""
  delete!(e.nodes, :agents)
  # The app's own update: a look for a newer version, and a download that finds no file. Both read this
  # folder, so nothing goes over a network, and they leave the app and its own folder alone.
  write(joinpath(dir, "latest.txt"), "version=2.0.0\nfile=none.zip\nsha256=$(repeat('0', 64))\n")
  u = Update.Updater(dir, v"1.0.0", feed="file://" * joinpath(dir, "latest.txt"), dir=joinpath(dir, "update"), rule="anchor apple", register="/usr/bin/true")
  Update.tick!(u)
  Update.finish!(u)
  u.newest == v"2.0.0" || error("The app didn't read which version is the newest")
  (u.staged === nothing && startswith(Update.says(u), "The download of Ladder 2.0.0 stopped.")) || error("A download with no file didn't fail: ", Update.says(u))
  Update.label(u) == "Get Ladder 2.0.0" || error("The app didn't offer the newer version after its download failed")
  Update.quit!(u) && error("A quit started an update with no new version ready")
  # An email as it was sent: its HTML laid out as a page, once as a page of today's kind and once as an old one,
  # with the mouse over it, a drag that selects its words, a bigger text size, and its words a level down. It
  # asks the web for nothing, and nothing is copied.
  for (name, doctype) in (("new.eml", "<!DOCTYPE html>"), ("old.eml", ""))
    mail = joinpath(dir, name)
    write(mail, "From: Sam Lee <sam@example.com>\r\nTo: you@example.com\r\nSubject: Warm up\r\nDate: Sat, 14 Nov 2026 09:32:00 +1100\r\n" *
                "MIME-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\n\r\n" * doctype * WARM_EMAIL)
    open!(e, mail)
    e.plain && level!(e)
    frame(w); frame(w)
    sent = e.nodes[:sent_email]
    (sent.shown !== nothing && length(sent.shown.shot.links) == 2 && !isempty(sent.shown.shot.words)) || error("An email wasn't laid out as it was sent")
    mouse(400, 300); mouse(500, 420)
    hold((Keys.mouse_left,)); onkey(w, KeyPress{Keys.mouse_left}(0, w)); mouse(650, 470)
    release((Keys.mouse_left,)); onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frame(w)
    press(Keys.a, Keys.cmd); press(Keys.escape)
    press(Keys.equal, Keys.cmd); press(Keys.var"0", Keys.cmd)
    level!(e); frame(w); level!(e); frame(w)
  end
  # The app is built with the list of windows as the warm-up leaves it, so it must leave none
  close(w)
  isempty(editors) || error("A window that closed is still in the list of the windows that are open")
  rm(dir, recursive=true)
end

"""
Show a terminal's file in a window that isn't on screen. While the app is
built, the file has text and no shell runs, so this compiles the code that
reads the text and draws it. With `shell`, the file is empty, so a shell
starts in it, and this types a line and waits for what the shell writes.
`--self-test` does that inside the finished app, to check that a program runs
there and that its output is read.
"""
check_terminal(; shell=false) = begin
  dir = mktempdir()
  path = joinpath(dir, "work.vt")
  write(path, shell ? "" : "\e[1;31mred\e[0m \e[4munder\e[0m ╭─╮ ║ ░ 界 é\r\nplain")
  was = Terms.USUAL[]
  Terms.USUAL[] = ["/bin/sh"]   # a shell that reads none of the settings of whoever builds the app
  e = build_editor(path)
  w = window!(e, title="terminal", size=(700px, 400px))
  frame(w); frame(w)
  v = e.nodes[(:term, path)]
  wrote = !shell
  if shell
    foreach(c -> ontype(w, Typed(c, w)), "echo ok-\$((40+2))")
    onkey(w, KeyPress{Keys.enter}(0, w))
    began = time()
    while !wrote && time() - began < 10
      sleep(0.02)
      frame(w)
      wrote = occursin("ok-42", Terms.Screens.words(v.term))
    end
  end
  close(w)
  Terms.USUAL[] = was
  rm(dir, recursive=true)
  wrote || error("A shell in a terminal's file wrote nothing")
  isempty(editors) || error("A window that closed is still in the list of the windows that are open")
end

warm_up()
check_pages(PAGES)
check_terminal()

if building
  relocate!()
  # Skia's calls were compiled with the old path, so compile them again
  warm_up()
  check_pages(PAGES)
end

"""
Run the code of a startup page that the app has never seen, and fail if it
fails. The code loads a file from its source, uses two of Julia's libraries
by their names, and reads Ladder itself, as code that adds to Ladder does.
It also loads a file of Units.jl that Ladder itself doesn't load, Money.jl.
"""
check_startup(dir) = begin
  was = STARTUP_FOLDER[]
  STARTUP_FOLDER[] = joinpath(dir, "startup")
  mkpath(STARTUP_FOLDER[])
  write(joinpath(STARTUP_FOLDER[], "more.jl"), "@use Dates: Date\nday() = Date(2026, 11, 18)\n")
  write(startup_page(), "# Home\n\n```julia\n@use \"./more\" day\n@use LibCURL: curl_version\n" *
                        "@use \"github.com/jkroso/Units.jl\" week hr\n@use \"github.com/jkroso/Units.jl/Money.jl\" AUD\n" *
                        "const said = (string(day()), unsafe_string(curl_version()), Ladder.startup_page(), string(convert(AUD/hr, 168AUD/week)))\n```\n")
  m = run_startup!()
  STARTUP_FOLDER[] = was
  isempty(STARTUP[][1]) || error("The code of a startup page failed: ", STARTUP[][1])
  said = Base.invokelatest(getglobal, m, :said)
  said[1] == "2026-11-18" || error("The code of a startup page gave the wrong day")
  said[4] == "1.00 AUD/hr" || error("The code of a startup page gave the wrong wage: ", said[4])
end

"The app's self-test: the pages as the app writes them out, the code of a startup page, then some typing, then a shell in a terminal's file"
self_test() = begin
  dir = mktempdir()
  check_pages(dirname(unpack(dir)))
  check_startup(dir)
  warm_up()
  check_terminal(shell=true)
  rm(dir, recursive=true)
end

"Open the file or folder named in `args`, or the startup page"
open_ladder(args) = begin
  move_old_folders!()   # before the pages are written into the app's folder
  unpack(support())     # the startup page links to these pages
  # The window opens the files that macOS asks for: one you double-clicked to start the app, and any after that
  Opened.listen()
  inbox[] = Opened.files
  Opened.wake[] = Libdl.dlsym(Libdl.dlopen(GLFW.libglfw), :glfwPostEmptyEvent)
  open_editor(args)
end

function (@main)(args::Vector{String})
  run_app(open_ladder, args, self_test)
end
