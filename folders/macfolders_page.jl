# The pages of the Mac's own folders: Downloads and the Trash show as a list
# of what's in them, the newest first, with a column for the site that a
# download came from and the place that a thing in the Trash came from.
# Pictures and the folder of the screenshots show as a grid of their pictures,
# which a search finds by the words in them. main.jl knows each of these
# folders by where it is (see `mac_kind`). macfile.jl, trash.jl and
# picture_words.jl read what macOS knows of their files, and macfolders.jl
# names their days.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"...
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI focus handled window_of describe
@use "github.com/jkroso/UI.jl/Interface/draw" cursor ishovered open_url rect redraw_in!
@use "github.com/jkroso/UI.jl/Interface/window" system_menu
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/image" image_aspect
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use Colors: @colorant_str, RGBA
@use "../files/pictures" picture thumbnail finder_icon forget_picture photo_place
@use "./folders" => Folders
@use "./zip" => Zips
@use "../blocks/map" => Maps
@use "./macfolders" => Mac
@use "./macfile" => MacFiles
@use "../files/picture_words" => PictureWords
@use "./trash" => Trash
@use "../base" exports...
@use "../shared" open! trash!

# --- the Mac's own folders: Downloads and the Trash ------------------------------------------
#
# Ladder knows four of the Mac's folders by where they are: Downloads,
# Pictures, the folder that the Mac saves screenshots to, and the Trash. A
# click on one in the sidebar shows it in the page its own way, and the sidebar
# lists what it holds. macfile.jl, trash.jl and picture_words.jl read what
# macOS knows of their files, and macfolders.jl names their days.
#
# Downloads and the Trash each show as a list with the newest thing first, in
# the groups of days that the Finder has: Today, Yesterday, Previous 7 Days,
# Previous 30 Days, and then each month. The sidebar lists them newest first too.
#
#   - In Downloads, a file that a browser saved has the site that it came from
#     after its name. Each line has the file's size and when it came.
#   - In the Trash, each line has the folder that the thing was in, and when
#     it went to the Trash. Put Back in the right-click menu, or ⌘⌫, moves it
#     back there, under the name that it had. The Trash's page has no buttons.
#     The Finder writes where each thing was, and a thing that it wrote
#     nothing about can't be put back from here.
#   - A click chooses a line, and ⌘ or ⇧ with a click chooses more. Two
#     clicks, Return or ⌘↓ show what's chosen. ↑ and ↓ go from line to line,
#     and ⌘A chooses every line. ⌘⌫ moves what's chosen to the Trash, and in
#     the Trash it puts what's chosen back, as it does in the Finder. A
#     right-click shows a menu.
#
# Nothing here empties the Trash. The Finder does that.
#
# Any other folder shows the same way with a page of its own that ends with
# `Ladder.DownloadsDirectory`.

"A folder that the page shows as a list of what it holds, the newest first, in groups of days, as the Mac's Downloads folder shows"
@def struct DownloadsDirectory <: AbstractDirectory end
"The Mac's Trash: a list of what it holds, each with the folder that it was in"
@def struct TrashDirectory <: AbstractDirectory end
const ListDirectory = Union{DownloadsDirectory,TrashDirectory}

# What's in one of these folders is a folder or a file like any other
FS.kind(::DownloadsDirectory, path::FSPath) = folder_kind(path)
FS.kind(::TrashDirectory, path::FSPath) = folder_kind(path)

push!(BLOCK_ICONS, "download", "trash", "arrow-counterclockwise", "folder2-open", "images", "camera", "search")
entry_icon(::DownloadsDirectory) = "download"
entry_icon(::TrashDirectory) = "trash"
# The folder of the Mac's Trash is called .Trash, and the Mac calls it the Trash
entry_name(d::TrashDirectory) = string(d.path) == Trash.trash() ? "Trash" : basename(string(d.path))

"The folder that the Mac saves screenshots to, when that isn't its Desktop, and when macOS was asked. It's asked again after 10 seconds."
const SCREENSHOTS = Ref((0.0, ""))

"The folder that the Mac saves screenshots to, or \"\" when that's its Desktop, which shows as a desktop"
screenshots_place() = begin
  at, kept = SCREENSHOTS[]
  time() - at < 10 && return kept
  found = Mac.screenshots()
  found == joinpath(homedir(), "Desktop") && (found = "")
  SCREENSHOTS[] = (time(), found)
  found
end

"The kind of the folder at `path` when it's one of the Mac's own folders, or nothing"
mac_kind(path::AbstractString) = begin
  Sys.isapple() || return nothing
  home = homedir()
  path == joinpath(home, "Downloads") ? DownloadsDirectory :
  path == joinpath(home, "Pictures") ? PicturesDirectory :
  path == Trash.trash() ? TrashDirectory :
  path == screenshots_place() ? ScreenshotsDirectory : nothing
end

"What a line of the list of a folder shows of a folder or a file"
@def struct ListItem
  name::String = ""
  path::String = ""
  folder::Bool = false
  size::Int = 0            # of a file, in bytes
  when::Float64 = 0.0      # when it came into the folder
  site::String = ""        # the site that it was downloaded from, or ""
end

"What's known of each path of a list, with when the file had changed as it was read"
const LIST_FACTS = Dict{String,Tuple{Float64,ListItem}}()

"What the list of a folder shows of the folder or the file at `path`. macOS is asked again when it has changed."
filelist_fact(path::AbstractString) = begin
  st = try stat(path) catch; return ListItem(name=basename(path), path=path) end
  kept = get(LIST_FACTS, path, nothing)
  kept !== nothing && kept[1] == st.mtime && return kept[2]
  length(LIST_FACTS) > 20_000 && empty!(LIST_FACTS)
  folder = isdir(st)
  it = ListItem(name=basename(path), path=path, folder=folder, size=folder ? 0 : Int(st.size),
                when=MacFiles.added(path), site=folder ? "" : MacFiles.site(path))
  LIST_FACTS[path] = (st.mtime, it)
  it
end

# The sidebar lists these folders with the newest thing first, as their page does
entries(e, d::ListDirectory) =
  sort!(invoke(entries, Tuple{Any,AbstractDirectory}, e, d), by=o -> -filelist_fact(string(o.path)).when, alg=MergeSort)

"What the page shows of Downloads or of the Trash: what the folder holds as a list, the newest first"
@def mutable struct FileList <: SemanticUI
  path::String = ""
  trash::Bool = false                         # it's the Trash
  lines::Vector{Any} = Any[]                  # the words over a group of days, or a `ListItem`, in the order that they show
  origins::Dict{String,Trash.Origin} = Dict{String,Trash.Origin}()   # where each thing in the Trash was, by its name there
  read::Float64 = 0.0                         # when the folder was read
  problem::String = ""                        # why the folder can't be read, or ""
  chosen::Set{String} = Set{String}()         # the names of the lines that are chosen
  last::String = ""                           # the name that the last click or key chose
  clicked::Tuple{Float64,String} = (0.0, "")  # the last click on a line: when, and its name
  said::String = ""                           # what went wrong with the last thing that was asked, or ""
  buttons::Dict{Any,PageButton} = Dict{Any,PageButton}()
end

"A click on one of these folders in the sidebar shows it in the page, and the sidebar lists what it holds"
open!(e, d::ListDirectory; record=true) = (open!(e, string(d.path); record); go_folder!(e, string(d.path)))
page_view(e, d::ListDirectory) = (path = string(d.path); node!(() -> FileList(path=path, trash=d isa TrashDirectory), e, (:filelist, path)))

const LIST_ROW_H = 30.0     # how tall a line of the list is, and the words over a group
const LIST_HEAD_H = 118.0   # how tall the part over the list is: the folder's name, and the buttons
"""
How tall the part over the list `v` is. The Trash has no row of buttons, as a
right-click and ⌘⌫ put a thing back. That row is 44 high: a button of 28, and 8
over and under it. When a thing couldn't be put back, the row is there with why.
"""
filelist_head_h(v) = v.trash && isempty(v.said) ? LIST_HEAD_H - 44.0 : LIST_HEAD_H
"The top folder of the disk that the Trash is on. A test names a folder of its own."
const TRASH_DISK = Ref("/")
"The page of the Mac's settings that lets an app read every folder"
const FULL_ACCESS_SETTINGS = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"

"Read the folder of the list `v` again, a second after it was last read"
filelist_read!(e, v::FileList) = begin
  time() - v.read < 1 && v.read > Folders.changed() && return
  v.read = time()
  names = try
    v.problem = ""
    readdir(v.path)
  catch
    v.problem = v.trash ? "macOS doesn't let Ladder read the Trash. Give Ladder Full Disk Access in the Mac's settings, and open Ladder again." :
                          "Ladder can't read this folder."
    String[]
  end
  # The Trash shows all that's in it. Any other folder leaves its hidden files out, and the ones that you ignore, as the sidebar does.
  ignored = Folders.ignored()
  shows(n) = n != ".DS_Store" && n != ".localized" && (v.trash || e.hidden || !left_out(joinpath(v.path, n), ignored))
  items = [filelist_fact(joinpath(v.path, n)) for n in names if shows(n)]
  sort!(items, by=it -> -it.when, alg=MergeSort)
  v.origins = v.trash ? Trash.origins(v.path, disk=TRASH_DISK[]) : Dict{String,Trash.Origin}()
  lines, group = Any[], ""
  for it in items
    g = Mac.day_name(it.when)
    g == group || (push!(lines, g); group = g)
    push!(lines, it)
  end
  v.lines = lines
  intersect!(v.chosen, names)
  nothing
end

"The names of the lines of the list `v` that are chosen, from the top"
filelist_chosen(v::FileList) = String[l.name for l in v.lines if l isa ListItem && l.name in v.chosen]

"Which line of the list `v` the mouse is over, or 0 when it's over none, or over the words of a group"
filelist_under(v::FileList) = begin
  w = window_of(v)
  r = rect(v)
  (w === nothing || r === nothing || !ishovered(v)) && return 0
  i = floor(Int, (num(w.mouse[2]) - num(r.top) - filelist_head_h(v)) / LIST_ROW_H) + 1
  1 <= i <= length(v.lines) && v.lines[i] isa ListItem ? i : 0
end

"The small picture before a name in a list: the Finder's icon, by the path, or nothing until it's made"
const LIST_ICONS = Dict{String,Any}()

"The Finder's icon of the folder or the file at `path`, small. `budget` is how many more this frame can make."
filelist_icon(e, path, budget) = begin
  haskey(LIST_ICONS, path) && return LIST_ICONS[path]
  budget[] > 0 || (redraw_in!(e, 0); return nothing)
  budget[] -= 1
  length(LIST_ICONS) > 20_000 && empty!(LIST_ICONS)
  LIST_ICONS[path] = something(finder_icon(path, 40), Some(nothing))
end

"Line `i` of the list `v`: the words over a group of days, or a folder or a file"
filelist_line(v::FileList, e, i, over, budget) = begin
  it = v.lines[i]
  it isa ListItem || return Row(width(grow=grow), height(px(LIST_ROW_H)), padding(0px, 0px, 5px, 8px), Alignment.End,
                                Box(label(it, 12px, color=colours.dim, weight="Semibold")))
  origin = get(v.origins, it.name, nothing)
  # A thing in the Trash has the name that it had where it was. The Finder can give it another in the Trash.
  name = origin === nothing ? it.name : origin.name
  note = v.trash ? (origin === nothing ? "" : "from " * tilde(origin.folder)) : it.site
  key = filelist_icon(e, it.path, budget)
  picture = key === nothing ? Icon(it.folder ? "folder" : file_icon(it.path), size=15px, color=colours.dim) : Image(key, fixed(20px), height(20px))
  Row(width(grow=grow), height(px(LIST_ROW_H)), padding(8px, 0px), radius(6px), child_gap=10px, clip=true, name="Item",
      background(it.name in v.chosen ? colours.active : over ? colours.hover : clear),
    Box(width(20px), picture),
    Row(width(grow=grow), height(grow=grow), clip=true, child_gap=10px,
      Box(label(name, 13px)), (isempty(note) ? () : (Box(label(note, 12px, color=colours.faint)),))...),
    Box(label(it.folder ? "" : Zips.size_words(it.size), 12px, color=colours.dim)),
    Box(width(84px), Alignment.End, label(Mac.when(it.when), 12px, color=colours.faint)))
end

describe(v::FileList) = begin
  e = editor(v)
  filelist_read!(e, v)
  redraw_in!(e, 1)   # the folder is read again each second, so a new file gets its line
  n = length(v.lines)
  _, high = window_size(e)
  # Only the lines that are in the window are made, and a few more above and below
  lo = clamp(floor(Int, (num(e.scroll.offset) - num(page_top(e)) - num(LIVE_GAP) - filelist_head_h(v)) / LIST_ROW_H) - 6, 0, n)
  hi = min(n, lo + ceil(Int, num(high) / LIST_ROW_H) + 12)
  over = filelist_under(v)
  budget = Ref(6)
  things = count(l -> l isa ListItem, v.lines)
  names = filelist_chosen(v)
  about = (things == 1 ? "1 thing" : "$(commas(things)) things") * (isempty(names) ? "" : "  ·  $(length(names)) chosen")
  some = !isempty(names)
  buttons = v.trash ? () :
    (page_button!(v, :open, _ -> filelist_open!(v, filelist_chosen(v)), icon="box-arrow-up-right", words="Open", off=!some),
     page_button!(v, :trash, _ -> filelist_trash!(v, filelist_chosen(v)), icon="trash", words="Move to Trash", off=!some),
     page_button!(v, :finder, _ -> show_in_finder(v.path), icon="folder2-open", words="Show in Finder"))
  access = isempty(v.problem) || !v.trash ? () :
    (page_button!(v, :access, _ -> (open_url(FULL_ACCESS_SETTINGS); nothing), words="Open the Mac's settings"),)
  Column(width(grow=grow), Alignment.Start, name="List",
    Column(width(grow=grow), height(px(filelist_head_h(v))), Alignment.Start, justify=Alignment.Start, clip=true,
      page_title(v.trash ? "trash" : "download", v.trash ? "Trash" : basename(v.path), about),
      (isempty(buttons) && isempty(v.said) ? () :
        (Row(padding(8px, 0px), child_gap=8px, buttons...,
             (isempty(v.said) ? () : (Box(label(v.said, 12px, color=git_colour(:deleted))),))...),))...),
    (isempty(v.problem) ? () : (page_note(v.problem), Row(padding(8px, 6px), access...)))...,
    (isempty(v.problem) && n == 0 ? (page_note(v.trash ? "The Trash is empty." : "This folder is empty."),) : ())...,
    spacer(px(LIST_ROW_H * lo)), [filelist_line(v, e, i, i == over, budget) for i in lo+1:hi]..., spacer(px(LIST_ROW_H * (n - hi))))
end

cursor(::FileList) = :arrow

"Show the things of the list `v` that are called `names`, as a link to each would"
filelist_open!(v::FileList, names) = (e = editor(v); foreach(n -> open_folder!(e, joinpath(v.path, n)), names); nothing)

"Move the things of the list `v` that are called `names` to the Trash, and keep the keyboard on the list"
filelist_trash!(v::FileList, names) = begin
  e = editor(v)
  foreach(n -> trash!(e, joinpath(v.path, n)), names)
  v.read = 0.0
  e.buf.path == v.path && focus(v)
  nothing
end

"Put the things of the Trash that are called `names` back where they were. One that the Finder wrote nothing about stays, and so does one whose folder is gone."
filelist_put_back!(v::FileList, names) = begin
  e = editor(v)
  v.said = ""
  for n in names
    origin = get(v.origins, n, nothing)
    origin === nothing && (v.said = "The Finder kept no note of where $n was."; continue)
    try
      Trash.put_back!(joinpath(v.path, n), origin)
    catch err
      v.said = trouble(err)
    end
  end
  v.read = 0.0
  list_files!(e)
  nothing
end

"Choose the line of the list `v` that's `by` lines from the one that was chosen last, and scroll so that it shows. With `more`, the lines that were chosen stay chosen."
filelist_step!(v::FileList, by, more=false) = begin
  e = editor(v)
  at = findall(l -> l isa ListItem, v.lines)
  isempty(at) && return
  from = findfirst(i -> v.lines[i].name == v.last, at)
  k = from === nothing ? (by > 0 ? 1 : length(at)) : clamp(from + by, 1, length(at))
  it = v.lines[at[k]]
  more || empty!(v.chosen)
  push!(v.chosen, it.name)
  v.last = it.name
  top = page_top(e) + LIVE_GAP + px(filelist_head_h(v) + LIST_ROW_H * (at[k] - 1))
  scroll_into_view!(e.scroll, top - px(LIST_ROW_H), top + px(2LIST_ROW_H))
  nothing
end

onkey(v::FileList, ev::KeyPress{Keys.mouse_left}) = begin
  w = ev.window
  focus(v)
  i = filelist_under(v)
  i == 0 && (empty!(v.chosen); v.clicked = (0.0, ""); return handled)
  it = v.lines[i]
  cmd, shift, none = only_held(w, Keys.cmd), only_held(w, Keys.shft), unmodified(w)
  t, last = v.clicked
  if time() - t < 0.4 && last == it.name && none
    v.clicked = (0.0, "")
    filelist_open!(v, [it.name])
    return handled
  end
  if cmd
    it.name in v.chosen ? delete!(v.chosen, it.name) : push!(v.chosen, it.name)
  elseif shift && !isempty(v.last)
    # Every line from the one that was chosen last to this one
    a = something(findfirst(l -> l isa ListItem && l.name == v.last, v.lines), i)
    foreach(l -> l isa ListItem && push!(v.chosen, l.name), v.lines[min(a, i):max(a, i)])
  else
    v.chosen = Set([it.name])
  end
  v.last = it.name
  v.clicked = !none ? (0.0, "") : (time(), it.name)
  handled
end

"Show the menu of the line of the list `v` that has `it`. When more than one line is chosen, the menu is for them all."
filelist_menu!(v::FileList, w, it::ListItem) = begin
  e = editor(v)
  names = filelist_chosen(v)
  items = v.trash ? ["Put Back", "-", "Open", "Show in Finder"] :
          length(names) > 1 ? ["Open", "-", "Move to Trash"] : ["Open", "-", file_menu(it.path)...]
  act(i) = begin
    item = get(items, i, "")
    item == "Open" ? filelist_open!(v, names) :
    item == "Put Back" ? filelist_put_back!(v, names) :
    item == "Move to Trash" ? filelist_trash!(v, names) : file_act!(e, it.path, item)
    nothing
  end
  off = v.trash && !any(n -> haskey(v.origins, n), names) ? [1] : Int[]
  system_menu(w, items, act; off) || drawn_menu!(w, items, act; off)
  nothing
end

onkey(v::FileList, ev::KeyPress{Keys.mouse_right}) = begin
  focus(v)
  i = filelist_under(v)
  i == 0 && return handled
  it = v.lines[i]
  it.name in v.chosen || (v.chosen = Set([it.name]); v.last = it.name)
  filelist_menu!(v, ev.window, it)
  handled
end

onkey(v::FileList, ev::KeyPress{K}) where K = begin
  w = ev.window
  cmd, shift, none = only_held(w, Keys.cmd), only_held(w, Keys.shft), unmodified(w)
  names = filelist_chosen(v)
  if (K == Keys.down && cmd) || (K == Keys.enter && none)
    filelist_open!(v, names)
  elseif K in (Keys.backspace, Keys.delete) && cmd
    v.trash ? filelist_put_back!(v, names) : filelist_trash!(v, names)
  elseif K == Keys.a && cmd
    v.chosen = Set(l.name for l in v.lines if l isa ListItem)
  elseif (none || shift) && K in (Keys.up, Keys.down)
    filelist_step!(v, K == Keys.down ? 1 : -1, shift)
  else
    return nothing   # any other key is the window's, like the one that goes back
  end
  redraw_in!(v, 0)
  handled
end

# --- the Mac's own folders: Pictures and the screenshots ------------------------------------
#
# The Pictures folder shows its pictures as a grid, the newest first, with the
# month over each group. The folders in it come first, and each shows the same
# way when it's opened. The folder that the Mac saves screenshots to, and a
# folder called Screenshots in Pictures, show their pictures by the day. Files
# that aren't pictures come last.
#
#   - The field over the grid leaves only the pictures that have what's typed
#     in it: in their names, or in the words that the picture shows, like the
#     text of a screenshot. macOS reads the words of each picture, on a second
#     thread, the first time that something is typed. It takes a part of a
#     second for each picture, and the grid fills as they're read. A file keeps
#     what was read, so each picture is read once.
#   - A click chooses a picture, and ⌘ or ⇧ with a click chooses more. Two
#     clicks, Return or ⌘↓ show what's chosen: a picture in the page, and a
#     folder as its own grid. The arrows go from picture to picture, ⌘A
#     chooses them all, and ⌘⌫ moves what's chosen to the Trash. A right-click
#     shows the menu that the sidebar has for the file.
#
#   - When photos of the Pictures folder say where they were taken, a map
#     over the grid has a dot for each one. A camera or a phone writes the
#     place into the photo's file. A click on a dot chooses its photo, and the
#     grid scrolls to it. The map is Apple's, as a `map` block's is, so the
#     first time it needs the network. A folder of screenshots has no map.
#
# A grid makes a small picture of each file when the file first shows, a few
# in each frame, and forgets the ones that it hasn't shown for a while. So a
# folder of thousands of photos opens at once and takes little memory.
#
# Any other folder shows the same way with a page of its own that ends with
# `Ladder.PicturesDirectory` or `Ladder.ScreenshotsDirectory`.

"A folder that the page shows as a grid of its pictures, the newest first, with the month over each group"
@def struct PicturesDirectory <: AbstractDirectory end
"A folder of screenshots: a grid of its pictures, the newest first, with the day over each group"
@def struct ScreenshotsDirectory <: AbstractDirectory end
const GridDirectory = Union{PicturesDirectory,ScreenshotsDirectory}

# A folder of pictures holds folders of pictures, and one that's called Screenshots holds screenshots
FS.kind(::PicturesDirectory, path::FSPath) = begin
  k = folder_kind(path)
  k === FS.Directory || return k
  lowercase(basename(string(path))) == "screenshots" ? ScreenshotsDirectory : PicturesDirectory
end
FS.kind(::ScreenshotsDirectory, path::FSPath) = (k = folder_kind(path); k === FS.Directory ? ScreenshotsDirectory : k)

entry_icon(::PicturesDirectory) = "images"
entry_icon(::ScreenshotsDirectory) = "camera"

"One square of a grid of pictures: a folder, a picture, or another file"
@def struct Tile
  name::String = ""
  path::String = ""
  kind::Symbol = :picture   # :folder, :picture, or :other for a file that isn't a picture
  when::Float64 = 0.0       # when it last changed, which for a photo is when it was taken
end

"What the page shows of a folder of pictures: a grid of them, in groups of months or of days"
@def mutable struct TilesView <: SemanticUI
  path::String = ""
  days::Bool = false                          # a group is a day, as for screenshots, and not a month
  tiles::Vector{Tile} = Tile[]                # what the folder holds, as it was last read
  read::Float64 = 0.0                         # when it was read
  problem::String = ""                        # why the folder can't be read, or ""
  made::Any = nothing                         # what `lines` was made for: the tiles, the width and what's typed in the field
  lines::Vector{Any} = Any[]                  # the words over a group, or the tiles of one row of the grid
  tops::Vector{Float64} = Float64[]           # where each line starts, from the top of the grid
  tall::Float64 = 0.0                         # how tall the grid is
  side::Float64 = 140.0                       # how wide and tall a square is
  chosen::Set{String} = Set{String}()         # the names of the squares that are chosen
  last::String = ""                           # the name that the last click or key chose
  clicked::Tuple{Float64,String} = (0.0, "")  # the last click on a square: when, and its name
  field::Any = nothing                        # the text field over the grid
  wide::Float64 = 0.0                         # how wide the grid is
  placed::Int = 0                             # how many of the folder's photos are known to say where they were taken
  spots::Dict{String,Any} = Dict{String,Any}()   # the latitude and the longitude of each photo that shows and says where it was taken, by its name
  map_asked::Any = nothing                    # how wide the map is, and since when
  pins::Vector{Tuple{String,Float64,Float64}} = Tuple{String,Float64,Float64}[]   # each dot of the map as it was last drawn: its photo, and where it is on the map
end

open!(e, d::GridDirectory; record=true) = (open!(e, string(d.path); record); go_folder!(e, string(d.path)))
page_view(e, d::GridDirectory) = (path = string(d.path); node!(() -> TilesView(path=path, days=d isa ScreenshotsDirectory), e, (:tiles, path)))
page_fills(e, ::GridDirectory) = true

const TILE_SIDE = 140.0      # the least that a square is wide and tall
const TILE_GAP = 6.0         # between two squares
const TILE_HEAD_H = 36.0     # how tall the words over a group are
const TILES_HEAD_H = 118.0   # how tall the part over the grid is: the folder's name, and the field
const TILE_PIXELS = 320      # how many pixels the small picture of a file has along its longer side
const TILES_KEPT = 400       # how many small pictures stay in memory

"Read the folder of the grid `v` again, 2 seconds after it was last read"
tiles_read!(e, v::TilesView) = begin
  time() - v.read < 2 && v.read > Folders.changed() && return
  v.read = time()
  names = try
    v.problem = ""
    readdir(v.path)
  catch
    v.problem = "Ladder can't read this folder."
    String[]
  end
  tiles = Tile[]
  ignored = Folders.ignored()
  for n in names
    (n == ".DS_Store" || n == ".localized" || (!e.hidden && left_out(joinpath(v.path, n), ignored))) && continue
    path = joinpath(v.path, n)
    st = try stat(path) catch; continue end
    ext = lowercase(splitext(n)[2])
    # A folder that the Finder shows as one file, like the library of the Photos app, is a file here too
    kind = isdir(st) ? (isempty(ext) ? :folder : :other) : ext in PICTURES || ext in MAC_PICTURES || ext in VIDEOS ? :picture : :other
    push!(tiles, Tile(name=n, path=path, kind=kind, when=st.mtime))
  end
  v.tiles = tiles
  intersect!(v.chosen, names)
  nothing
end

"What's typed in the field over the grid `v`, in small letters"
tiles_query(v::TilesView) = v.field === nothing ? "" : lowercase(strip(v.field.text))

"""
Lay the squares of the grid `v` out in a space `wide` wide: the folders, then
the pictures in groups by when they changed, the newest first, then the other
files. Each line is the words over a group or one row of squares.
"""
tiles_lay!(v::TilesView, wide) = begin
  query = tiles_query(v)
  # The words of more pictures can have been read since the last time
  key = (v.tiles, wide, query, isempty(query) ? 0 : PictureWords.version[], v.placed)
  v.made !== nothing && v.made[1] === key[1] && v.made[2:5] == key[2:5] && return
  v.made = key
  v.wide = wide
  cols = max(1, floor(Int, (wide + TILE_GAP) / (TILE_SIDE + TILE_GAP)))
  v.side = (wide - TILE_GAP * (cols - 1)) / cols
  shown = isempty(query) ? v.tiles : filter(t -> occursin(query, lowercase(t.name)) || tile_says(t, query), v.tiles)
  lines, tops, y = Any[], Float64[], 0.0
  group(words, tiles) = begin
    isempty(tiles) && return
    push!(lines, words); push!(tops, y); y += TILE_HEAD_H
    for row in Iterators.partition(tiles, cols)
      push!(lines, collect(row)); push!(tops, y); y += v.side + TILE_GAP
    end
  end
  pictures = sort!(filter(t -> t.kind == :picture, shown), by=t -> -t.when, alg=MergeSort)
  # The photos that say where they were taken have a map, over everything else
  empty!(v.spots)
  for t in pictures
    kept = get(TILE_PLACES, t.path, nothing)
    kept !== nothing && kept[1] == t.when && kept[2] !== nothing && (v.spots[t.name] = kept[2])
  end
  if !isempty(v.spots)
    n = length(v.spots)
    push!(lines, n == 1 ? "Where 1 photo was taken" : "Where $(commas(n)) photos were taken"); push!(tops, y); y += TILE_HEAD_H
    push!(lines, :map); push!(tops, y); y += TILES_MAP_H + 2TILE_GAP
  end
  group("Folders", sort!(filter(t -> t.kind == :folder, shown), by=t -> lowercase(t.name)))
  words(t) = v.days ? Mac.date_name(t.when) : Mac.month_name(t.when)
  i = 1
  while i <= length(pictures)
    j = i
    while j < length(pictures) && words(pictures[j+1]) == words(pictures[i])
      j += 1
    end
    group(words(pictures[i]), pictures[i:j])
    i = j + 1
  end
  group("Other files", sort!(filter(t -> t.kind == :other, shown), by=t -> lowercase(t.name)))
  v.lines, v.tops, v.tall = lines, tops, y
  nothing
end

"True when the picture `t` shows the words `query`. A picture whose words macOS hasn't read yet is read soon, and it's false until then."
tile_says(t::Tile, query) = begin
  (t.kind == :picture && lowercase(splitext(t.name)[2]) in (PICTURES..., MAC_PICTURES...)) || return false
  text = PictureWords.words(t.path, t.when)
  text !== nothing && occursin(query, text)
end

"The squares of the grid `v` in the order that they show"
tiles_shown(v::TilesView) = Tile[t for l in v.lines if l isa Vector for t in l]

"The small picture of each file of a grid, by its path: when the file had changed, the picture's key or nothing, and when it last showed"
const TILE_PICTURES = Dict{String,Tuple{Float64,Any,Float64}}()

"""
The small picture of the file `t` of a grid: the picture itself, or the
Finder's icon for a folder or another file. It's nothing until it's made.
`budget` is how many more this frame can make. The pictures that haven't
shown for the longest are forgotten when there are more than `TILES_KEPT`.
"""
tile_picture(e, t::Tile, budget) = begin
  kept = get(TILE_PICTURES, t.path, nothing)
  if kept !== nothing && kept[1] == t.when
    TILE_PICTURES[t.path] = (kept[1], kept[2], time())
    return kept[2]
  end
  budget[] > 0 || (redraw_in!(e, 0); return nothing)
  budget[] -= 1
  key = t.kind == :picture ? something(thumbnail(t.path, TILE_PIXELS), finder_icon(t.path, 128), Some(nothing)) :
                             something(finder_icon(t.path, 128), Some(nothing))
  if length(TILE_PICTURES) >= TILES_KEPT
    old = sort!(collect(TILE_PICTURES), by=p -> p[2][3])[1:TILES_KEPT÷4]
    for (path, (_, k, _)) in old
      # An icon is small and shared with the lists, so only a picture of a file's own is forgotten
      k isa String && startswith(k, "thumbnail") && forget_picture(k)
      delete!(TILE_PICTURES, path)
    end
  end
  TILE_PICTURES[t.path] = (t.when, key, time())
  key
end

"One square of the grid `v`: a picture fills it, and a folder or another file has its icon with its name under it"
tile_box(v::TilesView, e, t::Tile, budget) = begin
  s = v.side
  chosen = t.name in v.chosen
  key = tile_picture(e, t, budget)
  inner = s - 6
  face = if t.kind == :picture && key !== nothing
    # The picture covers the square, and what doesn't fit is cut off at two sides
    shape = image_aspect(key)
    wide, tall = shape >= 1 ? (inner * shape, inner) : (inner, inner / shape)
    # The picture keeps its size in the square, which is smaller, and the square cuts it
    Stack(fixed(px(inner)), height(px(inner)), Alignment.Start, clip=true,
      Image(key, width(min=px(wide), preferred=px(wide)), height(min=px(tall), preferred=px(tall)),
            offset_x=px((inner - wide) / 2), offset_y=px((inner - tall) / 2)))
  elseif t.kind == :picture
    Box(fixed(px(inner)), height(px(inner)), radius(5px), background(colours.chip))
  else
    icon = 0.5inner
    # A name that's too long for the square starts at its left edge, so that its start shows
    long = num(measure(Face(SANS, "", 12px, colours.ink, false), t.name)) > inner - 12
    Column(fixed(px(inner)), height(px(inner)), radius(5px), child_gap=8px, clip=true, justify=Alignment.Center,
           background(chosen ? colours.active : colours.chip),
      key === nothing ? Icon(t.kind == :folder ? "folder" : file_icon(t.path), size=px(0.4inner), color=colours.dim) :
                        Image(key, fixed(px(icon)), height(px(icon))),
      Row(fixed(px(inner - 12)), height(18px), clip=true, justify=long ? Alignment.Start : Alignment.Center, Box(label(t.name, 12px))))
  end
  Box(fixed(px(s)), height(px(s)), radius(7px), background(chosen ? colours.accent : clear), face)
end

"Where each photo of a grid was taken, by its path: when its file had changed, and its latitude and longitude, or nothing when the file doesn't say"
const TILE_PLACES = Dict{String,Tuple{Float64,Any}}()
# What reads where a photo was taken. A test puts a function of its own here.
const TILE_PLACER = Ref{Function}(photo_place)
const TILES_MAP_H = Float64(Maps.TALL)   # how tall the map over a grid is

"""
Read where the photos of the grid `v` were taken, no more than 40 files in a
frame, so that a folder of thousands of photos doesn't hold the window up. A
folder of screenshots isn't read: a screenshot has no place.
"""
tiles_places!(e, v::TilesView) = begin
  v.days && return
  budget, placed = 40, 0
  for t in v.tiles
    t.kind == :picture || continue
    kept = get(TILE_PLACES, t.path, nothing)
    if kept === nothing || kept[1] != t.when
      budget > 0 || (redraw_in!(e, 0); continue)
      budget -= 1
      length(TILE_PLACES) > 50_000 && empty!(TILE_PLACES)
      kept = TILE_PLACES[t.path] = (t.when, try TILE_PLACER[](t.path) catch; nothing end)
    end
    kept[2] === nothing || (placed += 1)
  end
  v.placed = placed
  nothing
end

"""
The map over the grid `v`, with a dot where each photo that shows was taken.
It's as wide as the grid, to the hundred px below, so a window that changes
its size asks Apple's maps for few pictures. The picture is asked for when the
width has stayed for half a second.
"""
tiles_map(v::TilesView, e) = begin
  wide = max(300, 100 * floor(Int, v.wide / 100))
  tall = round(Int, TILES_MAP_H)
  a = Maps.around(collect(values(v.spots)), 15, wide, tall)
  zoom = Maps.fit(a.zoom, wide, tall)
  centre = Maps.rounded(a.centre)
  (v.map_asked === nothing || v.map_asked[1] != wide) && (v.map_asked = (wide, time()))
  stayed = time() - v.map_asked[2] >= 0.5
  # A window that isn't on a screen, like a test's, doesn't start the program that asks Apple's maps
  runs = on_screen(v) || Maps.HELPER[] !== Maps.run_program
  ask(start) = Maps.picture!(media_dir(), centre, zoom, wide, tall, dark_page(); start)
  p = ask(runs && stayed)
  # A file that was cut short is no picture. It's taken away, and made again later.
  p.state == :there && !whole_picture(p.file) && (Maps.spoiled!(p.file); p = ask(false))
  stayed || redraw_in!(e, 0.5)
  isfinite(p.wait) && redraw_in!(e, max(p.wait, 0.05))
  key = p.state == :there ? picture(p.file) : nothing
  empty!(v.pins)
  for (name, at) in v.spots
    x, y = Maps.point(at, centre, zoom, wide, tall)
    (0 <= x <= wide && 0 <= y <= tall) && push!(v.pins, (name, x, y))
  end
  # The dots of the photos that are chosen are bigger, and drawn last, over the others
  sort!(v.pins, by=pin -> pin[1] in v.chosen)
  dot((name, x, y)) = (r = name in v.chosen ? 8.0 : 5.5;
    Box(fixed(px(2r)), height(px(2r)), radius(px(r)), background(colours.accent), border(2px, :solid, RGBA(1, 1, 1, 0.95)),
        offset_x=px(x - r), offset_y=px(y - r)))
  face = key === nothing ?
    Box(fixed(px(wide)), height(px(tall)), background(colours.chip),
        Box(label(isempty(p.problem) ? (runs ? "Drawing the map…" : "The map shows in a window that's on the screen.") : p.problem, 13px, color=colours.dim))) :
    Image(key, fixed(px(wide)), height(px(tall)))
  Stack(fixed(px(wide)), height(px(tall)), Alignment.Start, clip=true, name="Map", face, map(dot, v.pins)...)
end

"The photo whose dot on the map of the grid `v` the mouse is over, or nothing"
tiles_pin_under(v::TilesView) = begin
  w = window_of(v)
  r = rect(v)
  i = findfirst(==(:map), v.lines)
  (w === nothing || r === nothing || i === nothing || !ishovered(v)) && return nothing
  x, y = num(w.mouse[1]) - num(r.left), num(w.mouse[2]) - num(r.top) - TILES_HEAD_H - v.tops[i]
  best, least = nothing, 10.0
  for (name, px_, py_) in v.pins
    d = hypot(px_ - x, py_ - y)
    d <= least && ((best, least) = (name, d))
  end
  best
end

"Scroll the page so that the square of the photo called `name` shows in the grid `v`"
tiles_reveal!(v::TilesView, name) = begin
  e = editor(v)
  i = findfirst(l -> l isa Vector && any(t -> t.name == name, l), v.lines)
  i === nothing && return
  top = page_top(e) + LIVE_GAP + px(TILES_HEAD_H + v.tops[i])
  scroll_into_view!(e.scroll, top - px(TILE_HEAD_H), top + px(v.side + 2TILE_GAP))
  nothing
end

"Line `i` of the grid `v`: the words over a group, the map, or a row of squares"
tiles_line(v::TilesView, e, i, budget) = begin
  l = v.lines[i]
  l === :map && return Row(width(grow=grow), height(px(TILES_MAP_H + 2TILE_GAP)), Alignment.Start, tiles_map(v, e))
  l isa Vector || return Row(width(grow=grow), height(px(TILE_HEAD_H)), padding(0px, 0px, 8px, 2px), Alignment.End,
                             Box(label(l, 13px, color=colours.dim, weight="Semibold")))
  Row(width(grow=grow), height(px(v.side + TILE_GAP)), Alignment.Start, child_gap=px(TILE_GAP), [tile_box(v, e, t, budget) for t in l]...)
end

"The text field over the grid `v`, to leave only the pictures that have what's typed, in their names or in the words that they show"
tiles_field(v::TilesView) = begin
  v.field === nothing && (v.field = own!(v, TextInput(placeholder="Find by name, or by words in a picture", font_family=SANS, font_size=13px,
                                                      look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))))
  v.field
end

describe(v::TilesView) = begin
  e = editor(v)
  tiles_read!(e, v)
  redraw_in!(e, 2)   # the folder is read again, so a new picture gets its square
  wide = max(num(e.width), TILE_SIDE)
  tiles_places!(e, v)
  # With nothing typed, nobody asks for the words of the pictures that still wait
  isempty(tiles_query(v)) && v.made !== nothing && !isempty(v.made[3]) && PictureWords.stop_reading!()
  tiles_lay!(v, wide)
  waits = isempty(tiles_query(v)) ? 0 : PictureWords.reading()
  waits > 0 && redraw_in!(e, 0.2)   # the grid fills as the pictures are read
  n = length(v.lines)
  _, high = window_size(e)
  # Only the lines that are in the window are made, and one more above and below
  from = num(e.scroll.offset) - num(page_top(e)) - num(LIVE_GAP) - TILES_HEAD_H
  lo = clamp(searchsortedlast(v.tops, from) - 1, 0, n)
  hi = clamp(searchsortedlast(v.tops, from + num(high)) + 1, lo, n)
  above = lo == 0 ? 0.0 : v.tops[lo+1]
  below = hi == n ? 0.0 : v.tall - v.tops[hi+1]
  budget = Ref(3)
  pictures, folders = count(t -> t.kind == :picture, v.tiles), count(t -> t.kind == :folder, v.tiles)
  shown = length(tiles_shown(v))
  about = join([(pictures == 1 ? "1 picture" : "$(commas(pictures)) pictures");
                (folders == 0 ? String[] : [folders == 1 ? "1 folder" : "$folders folders"]);
                (isempty(tiles_query(v)) ? String[] : ["$shown with “$(strip(v.field.text))”"]);
                (waits == 0 ? String[] : [waits == 1 ? "reading the words of 1 more picture" : "reading the words of $waits more pictures"]);
                (isempty(v.chosen) ? String[] : ["$(length(v.chosen)) chosen"])], "  ·  ")
  Column(fixed(px(wide)), Alignment.Start, name="Pictures",
    Column(width(grow=grow), height(px(TILES_HEAD_H)), Alignment.Start, clip=true,
      page_title(v.days ? "camera" : "images", basename(v.path), about),
      Row(padding(8px, 0px),
        Row(fixed(320px), height(28px), padding(9px, 0px), radius(6px), child_gap=7px, background(colours.hover),
          Icon("search", size=12px, color=colours.dim), tiles_field(v)))),
    (isempty(v.problem) ? () : (page_note(v.problem),))...,
    (isempty(v.problem) && n == 0 ? (page_note(isempty(v.tiles) ? "This folder is empty." : waits > 0 ? "No name has that in it. Ladder is still reading the pictures." :
                                               "No name has that in it, and no picture shows it."),) : ())...,
    spacer(px(above)), [tiles_line(v, e, i, budget) for i in lo+1:hi]..., spacer(px(below)))
end

cursor(::TilesView) = :arrow

"The square of the grid `v` that the mouse is over, or nothing"
tile_under(v::TilesView) = begin
  w = window_of(v)
  r = rect(v)
  (w === nothing || r === nothing || !ishovered(v)) && return nothing
  x, y = num(w.mouse[1]) - num(r.left), num(w.mouse[2]) - num(r.top) - TILES_HEAD_H
  i = searchsortedlast(v.tops, y)
  (1 <= i <= length(v.lines) && v.lines[i] isa Vector) || return nothing
  (y - v.tops[i] <= v.side && x >= 0) || return nothing
  k = floor(Int, x / (v.side + TILE_GAP)) + 1
  (k <= length(v.lines[i]) && x - (k - 1) * (v.side + TILE_GAP) <= v.side) ? v.lines[i][k] : nothing
end

"Show the squares of the grid `v` that are called `names`: a picture in the page, and a folder as a grid of its own"
tiles_open!(v::TilesView, names) = (e = editor(v); foreach(n -> show_path!(e, joinpath(v.path, n)), names); nothing)

"Move the squares of the grid `v` that are called `names` to the Trash, and keep the keyboard on the grid"
tiles_trash!(v::TilesView, names) = begin
  e = editor(v)
  foreach(n -> trash!(e, joinpath(v.path, n)), names)
  v.read = 0.0
  e.buf.path == v.path && focus(v)
  nothing
end

"The names of the squares of the grid `v` that are chosen, in the order that they show"
tiles_chosen(v::TilesView) = String[t.name for t in tiles_shown(v) if t.name in v.chosen]

onkey(v::TilesView, ev::KeyPress{Keys.mouse_left}) = begin
  w = ev.window
  focus(v)
  # A click on a dot of the map chooses its photo, and the grid scrolls to it
  pin = tiles_pin_under(v)
  if pin !== nothing
    v.chosen, v.last, v.clicked = Set([pin]), pin, (0.0, "")
    tiles_reveal!(v, pin)
    return handled
  end
  t = tile_under(v)
  t === nothing && (empty!(v.chosen); v.clicked = (0.0, ""); return handled)
  cmd, shift, none = only_held(w, Keys.cmd), only_held(w, Keys.shft), unmodified(w)
  at, last = v.clicked
  if time() - at < 0.4 && last == t.name && none
    v.clicked = (0.0, "")
    tiles_open!(v, [t.name])
    return handled
  end
  if cmd
    t.name in v.chosen ? delete!(v.chosen, t.name) : push!(v.chosen, t.name)
  elseif shift && !isempty(v.last)
    all = tiles_shown(v)
    a, b = findfirst(x -> x.name == v.last, all), findfirst(x -> x.name == t.name, all)
    a === nothing || foreach(x -> push!(v.chosen, x.name), all[min(a, b):max(a, b)])
  else
    v.chosen = Set([t.name])
  end
  v.last = t.name
  v.clicked = !none ? (0.0, "") : (time(), t.name)
  handled
end

onkey(v::TilesView, ev::KeyPress{Keys.mouse_right}) = begin
  focus(v)
  t = tile_under(v)
  t === nothing && return handled
  t.name in v.chosen || (v.chosen = Set([t.name]); v.last = t.name)
  e = editor(v)
  names = tiles_chosen(v)
  items = length(names) > 1 ? ["Open", "-", "Move to Trash"] : ["Open", "-", file_menu(t.path)...]
  act(i) = begin
    item = get(items, i, "")
    item == "Open" ? tiles_open!(v, names) : item == "Move to Trash" ? tiles_trash!(v, names) : file_act!(e, t.path, item)
    nothing
  end
  system_menu(ev.window, items, act) || drawn_menu!(ev.window, items, act)
  handled
end

"Choose the square of the grid `v` that's `by` squares on from the one that was chosen last, and scroll so that it shows"
tiles_step!(v::TilesView, by, more=false) = begin
  e = editor(v)
  all = tiles_shown(v)
  isempty(all) && return
  from = findfirst(t -> t.name == v.last, all)
  k = from === nothing ? 1 : clamp(from + by, 1, length(all))
  more || empty!(v.chosen)
  push!(v.chosen, all[k].name)
  v.last = all[k].name
  tiles_reveal!(v, v.last)
  nothing
end

onkey(v::TilesView, ev::KeyPress{K}) where K = begin
  w = ev.window
  cmd, shift, none = only_held(w, Keys.cmd), only_held(w, Keys.shft), unmodified(w)
  names = tiles_chosen(v)
  cols = max(1, floor(Int, (max(num(editor(v).width), TILE_SIDE) + TILE_GAP) / (TILE_SIDE + TILE_GAP)))
  if (K == Keys.down && cmd) || (K == Keys.enter && none)
    tiles_open!(v, names)
  elseif K in (Keys.backspace, Keys.delete) && cmd
    tiles_trash!(v, names)
  elseif K == Keys.a && cmd
    v.chosen = Set(t.name for t in tiles_shown(v))
  elseif (none || shift) && K in (Keys.left, Keys.right, Keys.up, Keys.down)
    tiles_step!(v, K == Keys.left ? -1 : K == Keys.right ? 1 : K == Keys.up ? -cols : cols, shift)
  else
    return nothing   # any other key is the window's, like the one that goes back
  end
  redraw_in!(v, 0)
  handled
end
