# The parts that the page of a folder is made of: its title, its rows, its
# notes and its buttons, the icon of each kind of file, and the menu of a file.
# main.jl's pages of folders use them, and so can the page of a kind of folder
# in a file of its own. host.jl names what they ask of the window.
#
#     page_row!(e, (:downloads, path), path, "plan.pdf", "file-earmark-pdf", "2 Nov")
#     page_note(e, :downloads, "Nothing has been downloaded yet.")

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"...
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI Theme handled window_of describe
@use "github.com/jkroso/UI.jl/Interface/draw" cursor ishovered show_menu! viewport MouseScroll
@use "github.com/jkroso/UI.jl/Interface/objc" cls msg nsstring jstring with_pool
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/image" image_aspect
@use Colors: @colorant_str, RGBA
@use "./eml" => Eml
@use "./folders" => Folders
@use "./markdown" front_matter
@use "./look" exports...
@use "./host" exports...
@use "./pictures" picture
@use "github.com/jkroso/URI.jl/FS" => FS FSObject
@use "./remote" => Remote

export own!, node!, MARKDOWN, window_size, PICTURES, MODELS, TERMINALS, CHATS, SOUNDS, VIDEOS, ZIPS, TABLES,
       MAC_PICTURES, DOCUMENTS, FONTS, CODE, file_icon, SERIES_LIGHT, SERIES_DARK, series_colours, trouble,
       held_keys, only_held, unmodified, HELD, commas, file_menu, ignore_item, menu_theme, drawn_menu!,
       workspace, url_path, opener, app_name, PAGE_TITLES, first_answer, email_title, page_title, DESIGNS,
       PageRow, PAGE_ROW_H, page_row!, page_heading, page_note, PageButton, page_button!, git_colour,
       favourite_item, ishidden, left_out, on_screen, whole_picture, MEDIA_CACHE, media_dir, tilde, title,
       held, not_pictures, picture_key, SETTINGS_FILE, settings_file, BROWSER_FOLDER, browser_folder, path_of,
       HOME, home_folder, KEY_KEEPER, PAGE_GETTER, TRUE_PATHS, truepath, PASSING

"A node that belongs to `e` and is kept for as long as `e` is"
own!(e, node) = (node.parent === nothing && setfield!(node, :parent, e); node)

node!(make, e, key) = get!(() -> own!(e, make()), e.nodes, key)

# A book review, as a blog's site tool reads it, is Markdown with a header that says the book's title
const MARKDOWN = (".md", ".markdown", ".mdx", ".review")

window_size(e) = something(viewport(e), e.size)

const PICTURES = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")

const MODELS = (".stl", ".3mf", ".glb", ".gltf")   # the files of 3D models that the viewer reads

const TERMINALS = (".vt",)   # the files that keep what a terminal shows: see "a terminal's file"

const CHATS = (".chat",)     # the files that keep a session of an agent: see "a session's file"

# The sound and the video files that macOS plays
const SOUNDS = (".mp3", ".m4a", ".wav", ".aif", ".aiff", ".aac", ".flac", ".caf")

const VIDEOS = (".mp4", ".mov", ".m4v")

const ZIPS = (".zip", ".jar")

const TABLES = (".csv", ".tsv")

# The pictures that macOS reads and Skia doesn't
const MAC_PICTURES = (".heic", ".heif", ".tif", ".tiff", ".svg", ".ico", ".icns", ".psd")

# The files whose first page the Finder can show
const DOCUMENTS = (".rtf", ".rtfd", ".doc", ".docx", ".pages", ".key", ".numbers", ".xls", ".xlsx", ".ppt", ".pptx", ".odt", ".epub")

const FONTS = (".ttf", ".otf", ".ttc", ".woff", ".woff2")

const CODE = (".jl", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".py", ".rb", ".rs", ".go", ".c", ".h", ".cc", ".cpp", ".hpp", ".swift",
              ".kt", ".java", ".sh", ".zsh", ".css", ".less", ".scss", ".mk", ".html", ".json", ".jsonl", ".toml", ".yml", ".yaml", ".xml", ".sql", ".lua")

"The icon for the file at `path`. It says what kind of file it is, from the end of the file's name."
file_icon(path) = begin
  ext = lowercase(splitext(path)[2])
  ext in MARKDOWN || ext == ".txt" ? "file-earmark-text" :
  ext in PICTURES || ext in MAC_PICTURES ? "file-earmark-image" :
  ext in SOUNDS ? "file-earmark-music" :
  ext in VIDEOS ? "file-earmark-play" :
  ext in MODELS || ext in DESIGNS ? "box" :
  ext in TERMINALS ? "terminal" :
  ext in CHATS ? "chat-text" :
  ext == ".pdf" ? "file-earmark-pdf" :
  ext in ZIPS ? "file-earmark-zip" :
  ext in TABLES ? "file-earmark-spreadsheet" :
  ext in FONTS ? "file-earmark-font" :
  ext in DOCUMENTS ? "file-earmark-richtext" :
  ext in CODE ? "file-earmark-code" : "file-earmark"
end

# The colours of the columns of numbers, in the order that a chart uses them. Each one can be told from
# the one before it by a reader who doesn't see every colour. The first eight are for a light page.
const SERIES_LIGHT = [colorant"#2a78d6", colorant"#eb6834", colorant"#1baf7a", colorant"#eda100",
                      colorant"#e87ba4", colorant"#008300", colorant"#6250d6", colorant"#e34948"]

const SERIES_DARK = [colorant"#3987e5", colorant"#d95926", colorant"#199e70", colorant"#c98500",
                     colorant"#d55181", colorant"#0ca30c", colorant"#9085e9", colorant"#e66767"]

series_colours() = dark_page() ? SERIES_DARK : SERIES_LIGHT

"What went wrong, as a block shows it"
trouble(err) = sprint(showerror, err isa LoadError ? err.error : err)

"The keys of ⌃, ⌘, ⌥ and ⇧ that are down in the window `w`"
held_keys(w::Window) = w.keys & HELD

"""
True when the keys of ⌃, ⌘, ⌥ and ⇧ that are down are `keys` and no others,
like `Keys.cmd` for ⌘ alone. It takes a window, the event of a key, a click or
the wheel, or a part of a window. Each key and click that does something else
with ⌃, ⌘, ⌥ or ⇧ held asks this, so each does it only with the keys that it's
for. A key that holds all four, like a hyper key, does none of those things.
"""
only_held(w::Window, keys::Keys) = held_keys(w) == keys

only_held(ev::Union{KeyPress,KeyRelease,MouseScroll,Typed}, keys::Keys) = only_held(ev.window, keys)

only_held(node, keys::Keys) = (w = window_of(node); w === nothing ? keys == Keys(0) : only_held(w, keys))

"True when no key of ⌃, ⌘, ⌥ and ⇧ is down: in a window, with a key's event, or in the window of a part"
unmodified(x) = only_held(x, Keys(0))

const HELD = Keys.ctrl | Keys.cmd | Keys.opt | Keys.shft

commas(n::Int) = replace(string(n), r"(?<=\d)(?=(\d{3})+$)" => ",")

"""
The items of the menu of the file or the folder at `path`, as `system_menu`
takes them. "-" is a line between two groups. A file has an item that opens it
in the app that the Mac uses for it, unless that's Ladder.
"""
file_menu(path) = begin
  isdir(path) && return ["New Page", "New Folder", "New Terminal", "New Agent Session", "-", "Open in New Window", favourite_item(path), "-", "Rename", "Duplicate", "-",
                         "Copy Path", "Show in Finder", "-", ignore_item(path), "Move to Trash"]
  app = opener(path)
  outside = isempty(app) || app_name(app) == "Ladder" ? String[] : ["Open in $(app_name(app))"]
  ["Open in New Window", outside..., "-", "Rename", "Duplicate", "-", "Copy Path", "Copy Link", "Show in Finder", "-", ignore_item(path), "Move to Trash"]
end

"The item of a file's menu that leaves the file or the folder at `path` out of Ladder's lists, or shows it again"
ignore_item(path) = Folders.isignored(path) ? "Stop Ignoring" : "Ignore"

# A menu's text is 13/12 of its theme's size. This size makes it 13px, the size of a file's name in the sidebar.
"The colours and the text size of a menu that floats over the window"
menu_theme() = Theme(size=12px, surface=colours.float, text=colours.ink, dim=colours.dim, line=colours.line,
                     hover=colours.hover, select=colours.active, family=SANS)

"""
Show `items` as a menu that Ladder draws, for a window that macOS has no menu
for. They're the items that `system_menu` takes. An item that opens a menu
shows that menu in this one's place.
"""
drawn_menu!(w, items, act; off=(), ticked=(), path=(), at=(w.mouse[1], w.mouse[2])) = begin
  isoff(i) = (path..., i) in off || (isempty(path) && i in off)
  shown = [(i, entry) for (i, entry) in enumerate(items) if entry != "-" && !isoff(i)]
  # An item with a tick, like the way that a desktop is sorted now, has the tick before its name
  names = [entry isa Pair ? first(entry) * "  ›" : (path..., i) in ticked ? "✓ " * entry : entry for (i, entry) in shown]
  show_menu!(w, names, at[1], at[2], 170px, theme=menu_theme(), item_height=28px, lift=3.0, onselect=k -> begin
    k in eachindex(shown) || return
    i, entry = shown[k]
    entry isa Pair ? drawn_menu!(w, last(entry), act; off, ticked, path=(path..., i), at) : act(path..., i)
  end)
end

workspace() = msg(cls("NSWorkspace"), "sharedWorkspace")

"The file path of an NSURL, or an empty string for none"
url_path(url::Ptr{Cvoid}) = url == C_NULL ? "" : jstring(msg(url, "path"))

"""
The app that opens the file at `path` when you double-click the file in the
Finder: where that app is, or an empty string when macOS has no app for the file.
"""
opener(path) = begin
  (Sys.isapple() && isfile(path)) || return ""
  # The top bar asks in each frame, and macOS looks through its list of apps each time
  got = get(OPENERS, path, nothing)
  got !== nothing && time() - got[2] < 5 && return got[1]
  app = with_pool(() -> url_path(msg(workspace(), "URLForApplicationToOpenURL:", msg(cls("NSURL"), "fileURLWithPath:", nsstring(path)))))
  OPENERS[path] = (app, time())
  app
end

"The app that `opener` last found for each file, and when it asked macOS"
const OPENERS = Dict{String,Tuple{String,Float64}}()

"The name of the app at `path`, like Ladder for /Applications/Ladder.app"
app_name(path) = splitext(basename(path))[1]

"What the top bar calls the page that shows: `f(e)` gives the words, or nothing to leave the file's name"
const PAGE_TITLES = Dict{Symbol,Any}()

"What the first function of `table` that has an answer gives for `args`, or nothing when none has one"
first_answer(table, args...) = begin
  for f in values(table)
    found = f(args...)
    found === nothing || return found
  end
  nothing
end

"What the top bar calls an email file: its subject. It's nothing for any other page."
email_title(e) = begin
  b = e.buf
  (b.view == :markdown && Eml.isemail(b.path) && front_matter(b.lines) > 0) || return nothing
  said, _ = Eml.fields(b.lines)
  haskey(said, "subject") || return nothing
  isempty(said["subject"]) ? "No subject" : said["subject"]
end

"What the top bar calls the page that shows, when that isn't its file's name: what code from the startup page calls it, or an email's subject"
page_title(e) = something(first_answer(PAGE_TITLES, e), email_title(e), Some(nothing))

const DESIGNS = (".sc", ".solidcraft")

"""
A line of a folder's own page that a click acts on, like the name of a file
that has changes. It's darker while the mouse is over it. The view that it
belongs to gives it what it shows and does, in each frame.
"""
@def mutable struct PageRow <: SemanticUI
  act::Any = nothing   # what a click does, a function of the window, or nothing for a line that only shows
  parts::Any = ()      # what the line shows, from the left
end

const PAGE_ROW_H = 28px

describe(r::PageRow) =
  Row(width(grow=grow), height(PAGE_ROW_H), padding(8px, 0px), radius(6px), child_gap=8px, clip=true, name="Line",
      background(r.act !== nothing && ishovered(r) ? colours.hover : clear), r.parts...)

cursor(r::PageRow) = r.act === nothing ? :arrow : :hand

onkey(r::PageRow, ev::KeyPress{Keys.mouse_left}) = r.act === nothing ? nothing : (r.act(ev.window); handled)

"The line of the view `v` that's kept under `key`, with what a click on it does and what it shows now"
page_row!(v, key, act, parts...) = begin
  length(v.rows) > 4000 && empty!(v.rows)
  r = get!(() -> own!(v, PageRow()), v.rows, key)
  r.act, r.parts = act, parts
  r
end

"The words over a part of a folder's own page"
page_heading(s) = Box(width(grow=grow), height(30px), padding(8px, 0px), Alignment.Start,
                      Row(height(grow=grow), Box(label(s, 12px, color=colours.dim, weight="Semibold"))))

"A line of a folder's own page that only says something, like that a list is empty"
page_note(s) = Box(width(grow=grow), height(PAGE_ROW_H), padding(8px, 0px), Alignment.Start,
                   Row(height(grow=grow), Box(label(s, 13px, color=colours.faint))))

"""
A button of a folder's own page, like the one that unpacks a zip file. The
view that it belongs to gives it what it shows and does, in each frame.
"""
@def mutable struct PageButton <: SemanticUI
  act::Any = nothing   # what a click does, a function of the window
  icon::String = ""
  words::String = ""
  off::Bool = false    # it does nothing now, and shows that
end

describe(b::PageButton) =
  Box(height(28px), padding(11px, 0px), radius(6px), name="Button",
      background(b.off ? clear : ishovered(b) ? colours.active : colours.hover),
    Row(child_gap=6px,
      (isempty(b.icon) ? () : (Icon(b.icon, size=13px, color=b.off ? colours.faint : colours.dim),))...,
      Box(label(b.words, 12px, color=b.off ? colours.faint : colours.ink, weight="Medium"))))

cursor(b::PageButton) = b.off ? :arrow : :hand

onkey(b::PageButton, ev::KeyPress{Keys.mouse_left}) = (b.off || b.act === nothing || b.act(ev.window); handled)

"The button of the view `v` that's kept under `key`, with what a click on it does and what it shows now"
page_button!(v, key, act; icon="", words="", off=false) = begin
  b = get!(() -> own!(v, PageButton()), v.buttons, key)
  b.act, b.icon, b.words, b.off = act, icon, words, off
  b
end

"""
The name of a folder at the top of its own page, with an icon before it and a
line of words under it, like what it holds. The path to the folder is in the
top bar, so it isn't under the name. With no words, there's no line.
"""
page_title(icon, name, about) =
  Column(width(grow=grow), Alignment.Start, padding(8px, 0px, 14px, 8px), child_gap=13px,   # the name's box ends at its baseline, so its p, g and y use about 5px of this
    Row(child_gap=10px, Icon(icon, size=22px, color=colours.dim), Box(label(name, 24px, weight="Bold"))),
    (isempty(about) ? () : (Box(label(about, 13px, color=colours.dim)),))...)

"The colour of a change: green for a file that's new, red for one that's gone or in two forms, and the colour of a number for any other"
git_colour(kind) = kind in (:new, :added) ? colours.string : kind in (:deleted, :clash) ? series_colours()[8] : colours.number

"The item of a folder's menu that makes it a favourite, or takes it off the favourites"
favourite_item(path) = Folders.isfavourite(path) ? "Remove from Favourites" : "Add to Favourites"

# --- the files that a page of a folder lists -----------------------------------------

"True when the file or folder at `path` is a hidden one: its name starts with a dot"
ishidden(path) = startswith(basename(path), '.')

"""
True when Ladder's lists leave out the file or the folder at `path`, unless
they show the hidden files: its name starts with a dot, or you chose to ignore
it. `ignored` is what you ignore, for a caller that asks of many paths.
"""
left_out(path, ignored=Folders.ignored()) = ishidden(path) || Folders.isignored(path, ignored)

"True in a window that's on the screen. A window that a test makes isn't."
on_screen(node) = (w = window_of(node); w !== nothing && !isempty(w.glfw))

"True when `file` holds a picture that Ladder can draw"
whole_picture(file) = try image_aspect(file) > 0 catch; false end

const MEDIA_CACHE = Ref("")   # the folder a test keeps the copies in, in place of the one in the Mac's caches

"The folder that keeps the copies of the videos and the sounds from the web"
media_dir() = isempty(MEDIA_CACHE[]) ? joinpath(homedir(), "Library", "Caches", "Ladder", "media") : MEDIA_CACHE[]

"`path` with ~ for the home folder, as the sidebar writes it"
tilde(path::AbstractString) = (home = homedir(); path == home ? "~" : startswith(path, home * "/") ? "~" * path[length(home)+1:end] : String(path))

"The name of the file at `path` without its ending"
title(path) = splitext(basename(path))[1]

# --- the folders and the files of Ladder and of a test ----------------------------------

held(node, key) = (w = window_of(node); w !== nothing && key in w.keys)

# The files that turned out not to be pictures, and when each last changed, so that each is tried once
const not_pictures = Dict{String,Float64}()

"The key, for an Image, of the picture in the file at `path`, or nothing if the file isn't a picture"
picture_key(path) = begin
  isfile(path) || return nothing
  get(not_pictures, path, -1.0) == mtime(path) && return nothing
  key = lowercase(splitext(path)[2]) in PICTURES ? path : picture(path)
  ok = key !== nothing && try image_aspect(key) > 0 catch; false end
  ok ? key : (not_pictures[path] = mtime(path); nothing)
end

"The file of Ladder's settings that a test gives, so that it doesn't change yours, or \"\" for the usual one"
const SETTINGS_FILE = Ref("")

settings_file() = isempty(SETTINGS_FILE[]) ? joinpath(homedir(), "Library", "Application Support", "Ladder", "settings") : SETTINGS_FILE[]

"The browser folder of a test, or \"\" for ~/Browser"
const BROWSER_FOLDER = Ref("")

"The folder that keeps each page and file that Ladder gets from the web, at its place on its site"
browser_folder() = isempty(BROWSER_FOLDER[]) ? joinpath(home_folder(), "Browser") : BROWSER_FOLDER[]

"The path of the file or the folder `o` as text, with no / at its end"
path_of(o::FSObject) = (path = string(o.path); length(path) > 1 ? String(rstrip(path, '/')) : path)

"The home folder that ⌘⇧H opens: the Mac's, unless a test names one of its own"
const HOME = Ref("")

home_folder() = isempty(HOME[]) ? homedir() : HOME[]

"What keeps a key in the Keychain. A test puts its own function here, so that it leaves the Keychain alone."
const KEY_KEEPER = Ref{Function}(keep_key)

"What gets a page from a web server: `Remote.curl`. A test puts its own function here, so that it uses no network."
const PAGE_GETTER = Ref{Function}(Remote.curl)

# An agent names its page by the path that has no links in it. Each file's path of that kind is found once.
const TRUE_PATHS = Dict{String,String}()

truepath(path) = get!(() -> ispath(path) ? realpath(path) : abspath(path), TRUE_PATHS, path)

# The folders that macOS keeps temporary files in, and empties by itself
const PASSING = ("/private/var/folders/", "/var/folders/", "/private/tmp/", "/tmp/")
