# A folder that's a desktop, its menus, and the browser folder as a desktop of your favourite sites
#
# A folder can show in the page as a desktop does: its folders and files are
# icons on a wallpaper. The Mac's own Desktop folder is the one it's made for,
# and any folder becomes a desktop with a page of its own, the file `.ladder`
# in it, that ends with this block:
#
#     ```julia
#     Ladder.DesktopDirectory
#     ```
#
# A desktop in Ladder starts as a copy of the Mac's desktop. It has the Mac's
# wallpaper, and its icons have the size, the names and the order that the
# Finder gives the icons of the Mac's desktop. desktop.jl reads those, and
# works out where each icon goes: the first at the top right, the next ones
# down, and each new column to the left.
#
# The Finder takes no place and no order for an icon from another app. So what
# you change here is Ladder's own, and the Mac's desktop stays as it is. A
# right-click on the wallpaper shows the ways to lay the icons out, as it does
# on the Mac: Sort By, with None and Snap to Grid, Clean Up and Clean Up By.
# With None or Snap to Grid, you drag an icon to where you want it, and Ladder
# keeps its place, for each folder, beside the settings. A sorted desktop puts
# a dragged icon back, as the Finder does. An icon that you drop on a folder
# goes into that folder, however the desktop is sorted.
#
# A click chooses an icon, and ⌘ or ⇧ with a click chooses one more. A drag
# from the wallpaper chooses the icons that its box touches. Two clicks open
# an icon as a link to it would: a file shows in the page, and a folder in the
# sidebar. A right-click on an icon shows the menu that the sidebar has for
# it. While the desktop has the keyboard, the arrows go from icon to icon,
# Return renames the one that's chosen, ⌘↓ opens what's chosen, ⌘⌫ moves it to
# the Trash, and ⌘A chooses every icon.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" cursor open_url redraw_in! rect
@use "github.com/jkroso/UI.jl/Interface/image" image_aspect image_source
@use "github.com/jkroso/UI.jl/Interface/window" system_menu
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "../files/pictures" picture thumbnail finder_icon
@use "../markdown" words
@use "../blocks/spreadsheet" moved
@use "../blocks/linkcard" => Cards
@use "./desktop" => Desks
@use "./folders" => Folders
@use "./sites" => Sites
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS AbstractDirectory
@use Colors: RGBA
@use "../base" exports...
@use "../additions" exports...
@use "../blocks/linkcard_view" exports...
@use "../files/file_view" exports...
@use "../blocks/sheet_view" exports...
@use "../blocks/schedule_view" exports...
@use "../blocks/gallery_view" exports...

export DesktopDirectory, AbstractDesktop, DesktopView, DESKTOPS, FINDER_LOOK, WALLPAPER, DESKTOP_PICTURES,
       DESKTOP_NAMES, DESKTOP_BLUE, DESKTOP_SHADE, DESKTOP_PLAIN, ICON_PAD, desktop!, desktop_file,
       desktop_kept, desktop_keep!, desktop_look, wallpaper_key, desktop_names, desktop_read!,
       desktop_picture, desktop_face, name_lines, name_room, NAME_SHADOWS, name_line, icon_face, desktop_icon,
       wallpaper_part, desktop_band, desktop_note, desktop_at, icon_at, focus_desktop!, desktop_open!,
       desktop_enter!, desktop_remove!, takes_drops, desktop_moved!, DESKTOP_SORTS, DESKTOP_ORDERS,
       DESKTOP_CLEANS, DESKTOP_MENU, desktop_sort, desktop_freeze!, desktop_sort!, desktop_clean!,
       desktop_new!, WALLPAPER_SETTINGS, desktop_menu!, icon_menu!, desktop_trash!, desktop_step!,
       BrowserDirectory, favourites_file, SitesView, SITE_PICTURES, site_picture, SITE_TILES, sites_changed!,
       edit_favourites!, SITES_SORTS, SITES_MENU, favourite_name, is_favourite, favourite_bar

"A folder that the page shows as a desktop: an icon for each folder and file in it, on the Mac's wallpaper"
@def struct DesktopDirectory <: AbstractDirectory end

# A desktop holds what any folder holds, so each folder in it can have a page and a kind of its own
FS.kind(::DesktopDirectory, path::FSPath) = folder_kind(path)

push!(BLOCK_ICONS, "display", "folder-fill", "file-earmark-fill")
entry_icon(::DesktopDirectory) = "display"

"A click on a desktop in the sidebar shows it in the page, and the sidebar lists what it holds"
open!(e, d::DesktopDirectory; record=true) = (open!(e, string(d.path); record); go_folder!(e, string(d.path)))

page_view(e, d::DesktopDirectory) = desktop!(e, string(d.path))
page_fills(e, ::DesktopDirectory) = true
page_covers(e, ::DesktopDirectory) = true

"""
A page of icons on a wallpaper, as the Mac's desktop is. Each kind has the same
fields as `DesktopView`, and methods for what its icons are and do:
`desktop_names`, `icon_face`, `desktop_open!`, `desktop_enter!`,
`desktop_remove!`, `takes_drops`, `desktop_menu!` and `icon_menu!`. The rest, like
where each icon goes, a drag and the arrow keys, is the same for each kind.
"""
abstract type AbstractDesktop <: SemanticUI end

"What the page shows of a folder that's a desktop"
@def mutable struct DesktopView <: AbstractDesktop
  path::String = ""
  names::Vector{String} = String[]                 # the folders and files that have an icon, as the folder was last read
  read::Float64 = 0.0                              # when it was read
  area::NTuple{2,Float64} = (0.0, 0.0)             # how wide and tall the desktop was in the last frame
  spots::Dict{String,NTuple{2,Float64}} = Dict{String,NTuple{2,Float64}}()   # the middle of each icon, from the desktop's top left corner
  chosen::Set{String} = Set{String}()              # the names of the icons that are chosen
  press::Any = nothing                             # where the mouse button went down: (name, place, more, chosen before), with "" for the wallpaper
  moved::NTuple{2,Float64} = (0.0, 0.0)            # how far the mouse has gone since
  dragging::Bool = false                           # the chosen icons follow the mouse
  over::String = ""                                # the folder that the dragged icons are over
  clicked::Tuple{Float64,String} = (0.0, "")       # the last click on an icon: when, and its name
end

"What Ladder keeps of each desktop, by its folder's path. Each window that shows the folder has the same one."
const DESKTOPS = Dict{String,Desks.Kept}()
"How the Finder shows the Mac's desktop, and when it was asked. It's asked again after 3 seconds."
const FINDER_LOOK = Ref((0.0, Desks.Look()))
"The Mac's wallpaper: when macOS was asked for it, its file, and the key of its picture or nothing"
const WALLPAPER = Ref{Tuple{Float64,String,Any}}((0.0, "", nothing))
"The picture of each icon, by its path: when the file had changed, and the picture's key or nothing"
const DESKTOP_PICTURES = Dict{String,Tuple{Float64,Any}}()
"The lines of each name under an icon, by the name, the width and the size of the text"
const DESKTOP_NAMES = Dict{Tuple{String,Float64,Float64},Vector{String}}()

const DESKTOP_BLUE = RGBA(0.16, 0.42, 0.87, 1.0)     # behind the name of a chosen icon, as in the Finder
const DESKTOP_SHADE = RGBA(0.0, 0.0, 0.0, 0.3)       # behind a chosen icon
const DESKTOP_PLAIN = RGBA(0.23, 0.32, 0.45, 1.0)    # the desktop, when the Mac names no wallpaper
const ICON_PAD = 4.0                                 # round an icon's picture, inside the box that's dark while it's chosen

"The view of the desktop that's the folder at `path`"
desktop!(e, path) = node!(() -> DesktopView(path=path), e, (:desktop, path))

"The file that keeps the places of the icons of the desktop of the folder `dir`. It's in a folder beside the file of the settings."
desktop_file(dir) = joinpath(dirname(settings_file()), "desktops", Desks.filename(dir))

"What Ladder keeps of the desktop of the folder `dir`"
desktop_kept(dir) = get!(() -> Desks.load(desktop_file(dir)), DESKTOPS, dir)

"Write what Ladder keeps of the desktop of `dir` to its file, if this editor keeps settings, and draw each window again"
desktop_keep!(e, dir) = begin
  e.remember && Desks.save(desktop_file(dir), desktop_kept(dir))
  foreach(o -> redraw_in!(o, 0), editors)
  nothing
end

"How the icons of the desktop of `dir` look: as the Finder shows the Mac's desktop, sorted as you chose in Ladder"
desktop_look(dir) = begin
  at, _ = FINDER_LOOK[]
  time() - at > 3 && (FINDER_LOOK[] = (time(), Desks.looker[]()))
  Desks.look(desktop_kept(dir), FINDER_LOOK[][2])
end

"How the icons of the desktop `v` look"
desktop_look(v::DesktopView) = desktop_look(v.path)

"The key of the picture of the Mac's wallpaper, or nothing when macOS names none. macOS is asked again after 3 seconds, so a new wallpaper shows here too."
wallpaper_key() = begin
  at, file, key = WALLPAPER[]
  time() - at > 3 || return key
  file = Desks.papers[]()
  # The picture is no bigger than a screen needs. A wallpaper can have many times the pixels.
  key = isfile(file) ? something(thumbnail(file, 2560), picture(file), Some(nothing)) : nothing
  WALLPAPER[] = (time(), file, key)
  key
end

"""
The folders and files of the desktop `v` that have an icon: the ones that the
Finder shows, apart from those that you ignore, and the hidden and ignored ones
too when the sidebar shows those
"""
desktop_names(e, v::DesktopView) = begin
  found = try readdir(v.path) catch; String[] end
  ignored = Folders.ignored()
  shows(n) = n != ".DS_Store" && (e.hidden || !(Desks.facts(joinpath(v.path, n)).hidden || Folders.isignored(joinpath(v.path, n), ignored)))
  String[n for n in found if shows(n) && ispath(joinpath(v.path, n))]
end

"Read the folder of the desktop `v` again, a second after it was last read. An icon whose file left is no longer chosen, and its place is forgotten."
desktop_read!(e, v::AbstractDesktop) = begin
  time() - v.read < 1 && v.read > Folders.changed() && return
  v.read = time()
  v.names = desktop_names(e, v)
  intersect!(v.chosen, v.names)
  k = desktop_kept(v.path)
  # A folder that can't be read for a moment, like a disk that left, keeps its places
  isempty(v.names) || (Desks.prune!(k, v.names) && desktop_keep!(e, v.path))
  nothing
end

"The picture of the icon of the folder or the file at `path`: the picture itself for a picture or a PDF file, or the Finder's icon. `budget` is how many more pictures this frame can make, so that a big folder doesn't hold the window up."
desktop_picture(e, path, look, budget) = begin
  at = isdir(path) ? 0.0 : mtime(path)
  kept = get(DESKTOP_PICTURES, path, nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  budget[] > 0 || (redraw_in!(e, 0); return kept === nothing ? nothing : kept[2])
  budget[] -= 1
  side = round(Int, 2look.icon)   # two pixels to the px, for a screen that has them
  ext = lowercase(splitext(path)[2])
  preview = look.previews && isfile(path) && (ext in PICTURES || ext in MAC_PICTURES || ext == ".pdf")
  key = something(preview ? thumbnail(path, side) : nothing, finder_icon(path, side), Some(nothing))
  length(DESKTOP_PICTURES) > 5000 && empty!(DESKTOP_PICTURES)
  DESKTOP_PICTURES[path] = (at, key)
  key
end

"The text of an icon's name"
desktop_face(look) = Face(SANS, "Medium", px(look.text), RGBA(1, 1, 1, 1), false)

"""
The name under an icon, as one line or two that are no wider than `wide`. The
first line ends where a word of the name ends, when one ends on it. A name
that's too long for two lines loses the middle of its second line.
"""
name_lines(name, wide, look) = get!(DESKTOP_NAMES, (String(name), Float64(wide), look.text)) do
  face = desktop_face(look)
  fits(s) = num(measure(face, s)) <= wide
  fits(name) && return [String(name)]
  chars = collect(name)
  # The second line has three characters or more, so that the end of a name isn't alone on it
  n = min(something(findlast(k -> fits(String(chars[1:k])), eachindex(chars)), 1), max(1, length(chars) - 3))
  # The first line ends after a space, a hyphen, a dot or a line under the words, when it has one that's not near its start
  gap = findlast(k -> chars[k] in (' ', '-', '.', '_'), 1:n)
  cut = gap !== nothing && gap > n ÷ 3 ? gap : n
  head, rest = String(rstrip(String(chars[1:cut]))), collect(lstrip(String(chars[cut+1:end])))
  fits(String(rest)) && return [head, String(rest)]
  for keep in length(rest)-1:-1:2
    s = String(rest[1:keep÷2]) * "…" * String(rest[end-(keep-keep÷2)+1:end])
    fits(s) && return [head, s]
  end
  [head, "…"]
end

"How wide the lines of a name under an icon can be"
name_room(look) = Desks.cell(look)[1] - 12

# Where the dark copies of a name are, beside the white one, and how dark each is. Together they make a
# soft dark edge round the letters, so that white words read on a wallpaper that's nearly white.
const NAME_SHADOWS = ((0, 1, 0.8), (0, 2, 0.35), (1, 0, 0.5), (-1, 0, 0.5), (0, -1, 0.4), (1, 1, 0.4), (-1, 1, 0.4))

"One line of an icon's name: white, with dark copies under it so that it reads on any wallpaper"
name_line(s, look, chosen) = begin
  words(color) = Text(s, size=px(look.text), family=SANS, subfamily="Medium", color=color, wrap=WrapMode.none)
  white = Box(words(RGBA(1, 1, 1, 1)))
  # The name of a chosen icon is on blue, and needs no dark edge
  Box(height(px(look.text + 5)), padding(4px, 0px), radius(4px), (chosen ? (background(DESKTOP_BLUE),) : ())...,
    chosen ? white : Stack([Box(offset_x=px(x), offset_y=px(y), words(RGBA(0, 0, 0, dark))) for (x, y, dark) in NAME_SHADOWS]..., white))
end

"""
The picture of the icon of the folder or the file called `name` on the desktop
`v`, as big as `look` says. `budget` is how many more pictures this frame can make.
"""
icon_face(e, v::DesktopView, name, look, budget) = begin
  path = joinpath(v.path, name)
  side = look.icon
  key = desktop_picture(e, path, look, budget)
  key === nothing && return Icon(isdir(path) ? "folder-fill" : "file-earmark-fill", size=px(0.8side), color=RGBA(1, 1, 1, 0.9))   # the Finder's picture isn't made yet, or this isn't a Mac
  shape = image_aspect(key)
  Image(key, fixed(px(shape >= 1 ? side : side * shape)), height(px(shape >= 1 ? side / shape : side)))
end

"The icon called `name` on the desktop `v`, with its middle at `at`"
desktop_icon(v::AbstractDesktop, e, look, name, at, budget) = begin
  path = joinpath(v.path, name)
  side = look.icon
  chosen = name in v.chosen
  x, y = v.dragging && chosen ? at .+ v.moved : at
  face = icon_face(e, v, name, look, budget)
  box = side + 2ICON_PAD
  picture = Box(fixed(px(box)), height(px(box)), radius(7px), (chosen || name == v.over ? (background(DESKTOP_SHADE),) : ())..., face)
  wide = Desks.cell(look)[1] - 4
  # While the file is renamed, a text field with its name is where the name was
  words = renaming(e, :desktop) == path ?
    Box(fixed(px(wide)), height(22px), padding(5px, 0px), radius(4px), Alignment.Start, background(colours.bg),
        border(1px, :solid, colours.accent), renamer(e)) :
    Column(Alignment.Center, [name_line(s, look, chosen) for s in name_lines(name, name_room(look), look)]...)
  Column(fixed(px(wide)), Alignment.Center, child_gap=3px, offset_x=px(x - wide / 2), offset_y=px(y - side / 2 - ICON_PAD), picture, words)
end

"The wallpaper of a desktop that's `w` wide and `h` tall. The picture covers the desktop, and what doesn't fit is cut off at two sides."
wallpaper_part(w, h) = begin
  key = wallpaper_key()
  key === nothing && return Box(fixed(px(w)), height(px(h)), background(DESKTOP_PLAIN))
  shape = image_aspect(key)
  wide, tall = w / h > shape ? (w, w / shape) : (h * shape, h)
  Image(key, fixed(px(wide)), height(px(tall)), offset_x=px((w - wide) / 2), offset_y=px((h - tall) / 2))
end

"The box that a drag from the wallpaper draws, as its left, top, right and bottom, or nothing"
desktop_band(v::AbstractDesktop) = begin
  p = v.press
  (p === nothing || !isempty(p.name) || v.moved == (0.0, 0.0)) && return nothing
  a, b = p.at, p.at .+ v.moved
  (min(a[1], b[1]), min(a[2], b[2]), max(a[1], b[1]), max(a[2], b[2]))
end

describe(v::AbstractDesktop) = begin
  e = editor(v)
  win = window_of(e)
  w, h = num.(page_room(e))
  v.area = (w, h)
  look = desktop_look(v)
  desktop_read!(e, v)
  # The button can come up where the window doesn't hear it, like over a menu
  v.press === nothing || win === nothing || Keys.mouse_left in win.keys || drop!(v)
  v.spots = Desks.places(v.path, v.names, v.area, look, desktop_kept(v.path))
  redraw_in!(e, 1)   # the folder is read again each second, so a new file gets its icon
  budget = Ref(4)
  # The icons that are dragged are drawn last, over the others
  order = sort(v.names, by=n -> v.dragging && n in v.chosen)
  band = desktop_band(v)
  Stack(fixed(px(w)), height(px(h)), Alignment.Start, clip=true, name="Desktop",
    wallpaper_part(w, h),
    (isempty(v.names) ? desktop_note(v, w, h) : ())...,
    [desktop_icon(v, e, look, n, v.spots[n], budget) for n in order]...,
    (band === nothing ? () : (Box(fixed(px(band[3] - band[1])), height(px(band[4] - band[2])), offset_x=px(band[1]), offset_y=px(band[2]),
                                  background(RGBA(1, 1, 1, 0.16)), border(1px, :solid, RGBA(1, 1, 1, 0.65))),))...)
end

cursor(::AbstractDesktop) = :arrow

"What the desktop `v` shows in its middle when it has no icons: nodes, or `()`. A folder's desktop shows only its wallpaper."
desktop_note(v::AbstractDesktop, w, h) = ()

"Where `pos`, a place in the window, is on the desktop `v`, from the desktop's top left corner. It's nothing until the desktop has been drawn."
desktop_at(v::AbstractDesktop, pos) = begin
  r = rect(v)
  r === nothing ? nothing : (num(pos[1]) - num(r.left), num(pos[2]) - num(r.top))
end

"The name of the icon of the desktop `v` that's at `at`, on its picture or on its name, or nothing. `but` are names to pass over."
icon_at(v::AbstractDesktop, at; but=()) = begin
  look = desktop_look(v)
  half = look.icon / 2 + ICON_PAD
  for name in reverse(v.names)
    name in but && continue
    s = get(v.spots, name, nothing)
    s === nothing && continue
    dx, dy = at[1] - s[1], at[2] - s[2]
    abs(dx) <= half && abs(dy) <= half && return name
    lines = length(name_lines(name, name_room(look), look))
    abs(dx) <= name_room(look) / 2 && half < dy <= half + 3 + lines * (look.text + 5) && return name
  end
  nothing
end

"Give the keyboard to the desktop that the page shows, or to the text when it shows none"
focus_desktop!(e) = (v = get(e.nodes, (:desktop, e.buf.path), nothing); v isa AbstractDesktop ? focus(v) : focus(e))

"Open the icon called `name` of the desktop `v` in the page, as the Finder does: a file shows its page, and a folder its own page or a list of what's in it"
desktop_open!(v::DesktopView, name) = (open_folder!(editor(v), joinpath(v.path, name)); nothing)

"What Return does to the icon called `name` of the desktop `v`, when it's the one that's chosen: it renames its file, as in the Finder"
desktop_enter!(v::DesktopView, name) = rename!(editor(v), joinpath(v.path, name), at=:desktop)

"What ⌘⌫ does to the icons of the desktop `v` that are called `names`: their files go to the Trash"
desktop_remove!(v::DesktopView, names) = desktop_trash!(v, names)

"True when icons that are dropped on the icon called `name` of the desktop `v` go into it, as they go into a folder"
takes_drops(v::DesktopView, name) = isdir(joinpath(v.path, name))
takes_drops(::AbstractDesktop, name) = false

onkey(v::AbstractDesktop, ev::KeyPress{Keys.mouse_left}) = begin
  w = ev.window
  at = desktop_at(v, w.mouse)
  at === nothing && return handled
  focus(v)   # a name that was being typed is given to its file, since the field lost the keyboard
  name = icon_at(v, at)
  more = only_held(w, Keys.cmd) || only_held(w, Keys.shft)
  v.moved, v.dragging, v.over = (0.0, 0.0), false, ""
  t, last = v.clicked
  # A click with ⌘ or ⇧, or on the wallpaper, isn't the first of the two clicks that open an icon
  v.clicked = name === nothing || more ? (0.0, "") : (time(), name)
  if name === nothing
    more || empty!(v.chosen)
    v.press = (name="", at=at, more=more, before=copy(v.chosen))
    return handled
  end
  if time() - t < 0.4 && last == name && !more
    # Two clicks open the icon
    v.clicked, v.press = (0.0, ""), nothing
    desktop_open!(v, name)
    return handled
  end
  if more
    name in v.chosen ? delete!(v.chosen, name) : push!(v.chosen, name)
  elseif !(name in v.chosen)
    empty!(v.chosen)
    push!(v.chosen, name)
  end
  v.press = (name=name, at=at, more=more, before=copy(v.chosen))
  handled
end

# Each move of a drag comes here, since the button went down on the desktop
onmouse(v::AbstractDesktop, ev::MouseMove) = begin
  p = v.press
  (p === nothing || !(Keys.mouse_left in ev.window.keys)) && return nothing
  at = desktop_at(v, ev.position)
  at === nothing && return handled
  v.moved = at .- p.at
  if isempty(p.name)
    # A drag from the wallpaper chooses the icons that its box touches, with the ones that ⌘ kept
    l, t, r, b = something(desktop_band(v), (at..., at...))
    half = desktop_look(v).icon / 2
    touched = [n for (n, s) in v.spots if s[1] + half >= l && s[1] - half <= r && s[2] + half >= t && s[2] - half <= b]
    v.chosen = union(p.more ? p.before : Set{String}(), touched)
  elseif v.dragging || hypot(v.moved...) > 4
    v.dragging = true
    under = icon_at(v, at, but=v.chosen)
    v.over = under !== nothing && takes_drops(v, under) ? under : ""
  end
  redraw_in!(v, 0)
  handled
end

onkey(v::AbstractDesktop, ::KeyRelease{Keys.mouse_left}) = (drop!(v); handled)

"""
End the drag of the desktop `v`. Icons that were dropped on a folder go into
it. On a desktop that nothing sorts, the others stay where they were dropped,
and Ladder keeps their places. A sorted desktop puts them back.
"""
drop!(v::AbstractDesktop) = begin
  p = v.press
  p === nothing && return
  e = editor(v)
  v.press = nothing
  if v.dragging
    look = desktop_look(v)
    if !isempty(v.over)
      into = joinpath(v.path, v.over)
      for name in collect(v.chosen)
        # A folder keeps what it has under that name
        ispath(joinpath(into, name)) || move!(e, joinpath(v.path, name), joinpath(into, name))
      end
      empty!(v.chosen)
      v.read = 0.0
    elseif look.order == :none
      k = desktop_kept(v.path)
      for name in v.chosen
        haskey(v.spots, name) && Desks.place!(k, name, v.spots[name] .+ v.moved, v.area, look)
      end
      desktop_keep!(e, v.path)
    end
  elseif !isempty(p.name) && !p.more && length(v.chosen) > 1
    # A click on one of several chosen icons, with no drag, chooses only that one
    v.chosen = Set([p.name])
  end
  v.dragging, v.over, v.moved = false, "", (0.0, 0.0)
  redraw_in!(v, 0)
  nothing
end

"An icon of a desktop keeps its place when its file gets a new name, and stays chosen. Its place is forgotten when the file leaves the desktop's folder."
desktop_moved!(e, old, new) = begin
  dir, was, now = dirname(old), basename(old), basename(new)
  stays = dirname(new) == dir
  v = get(e.nodes, (:desktop, dir), nothing)
  if v isa DesktopView
    was in v.chosen && (delete!(v.chosen, was); stays && push!(v.chosen, now))
    v.read = 0.0
  end
  k = get(DESKTOPS, dir, nothing)
  k === nothing && return
  place = pop!(k.places, was, nothing)
  place === nothing && return
  stays && (k.places[now] = place)
  desktop_keep!(e, dir)
end

# --- the menus of a desktop ------------------------------------------------------------------

"The ways to sort a desktop, as its menu names them, in the menu's order"
const DESKTOP_SORTS = ["None", "Snap to Grid", "-", "Name", "Kind", "Date Modified", "Date Created", "Size"]
"The order that each name of the menu stands for"
const DESKTOP_ORDERS = Dict("Name" => :name, "Kind" => :kind, "Date Modified" => :changed, "Date Created" => :made, "Size" => :size)
"The ways to clean a desktop up once, in the menu's order"
const DESKTOP_CLEANS = ["Name", "Kind", "Date Modified", "Date Created", "Size"]
"The menu of a desktop, for a right-click on its wallpaper"
const DESKTOP_MENU = Any["New Folder", "New Page", "-", "Sort By" => DESKTOP_SORTS, "Clean Up", "Clean Up By" => DESKTOP_CLEANS, "-",
                         "Change Wallpaper…", "Show in Finder"]

"What the menu of the desktop of `dir` calls the way that it's sorted now"
desktop_sort(dir) = begin
  look = desktop_look(dir)
  look.order == :none ? (look.snap ? "Snap to Grid" : "None") : only(n for (n, o) in DESKTOP_ORDERS if o == look.order)
end

"Keep each icon of the desktop `v` where it is now, so that it stays there when nothing sorts the desktop"
desktop_freeze!(v::AbstractDesktop) = begin
  k = desktop_kept(v.path)
  foreach(((name, at),) -> k.places[name] = Desks.share(at, v.area), v.spots)
  k
end

"""
Sort the desktop `v` as `choice` says, one of `DESKTOP_SORTS`. With None or
Snap to Grid the icons stay where the last order put them, as they do in the
Finder, and from then on each stays where you put it.
"""
desktop_sort!(v::AbstractDesktop, choice) = begin
  e = editor(v)
  k = desktop_kept(v.path)
  if choice in ("None", "Snap to Grid")
    desktop_look(v).order == :none || desktop_freeze!(v)
    k.order, k.snap = :none, choice == "Snap to Grid"
  elseif haskey(DESKTOP_ORDERS, choice)
    k.order = DESKTOP_ORDERS[choice]
  end
  desktop_keep!(e, v.path)
end

"""
Put the icons of the desktop `v` in the cells of the grid, once. With an
`order`, they fill the grid in that order. Without one, each goes to the cell
that's nearest to it, or to the first free cell when another icon has that one.
"""
desktop_clean!(v::AbstractDesktop, order=nothing) = begin
  e = editor(v)
  look = desktop_look(v)
  look.order == :none || return
  k = desktop_kept(v.path)
  g = Desks.grid(v.area, look)
  if order === nothing
    taken = NTuple{2,Float64}[]
    # The icons nearest the top right take their cells first
    for name in sort(collect(keys(v.spots)), by=n -> (-v.spots[n][1], v.spots[n][2]))
      at = Desks.nearest(g, v.spots[name])
      any(t -> Desks.meets(g, at, t), taken) && (at = Desks.free(g, taken))
      push!(taken, at)
      k.places[name] = Desks.share(at, v.area)
    end
  else
    for (i, name) in enumerate(Desks.sorted(v.path, v.names, order))
      k.places[name] = Desks.share(Desks.spot(g, i), v.area)
    end
  end
  desktop_keep!(e, v.path)
end

"Make a new folder or a new page on the desktop `v`, with its icon at `at` when nothing sorts the desktop. Its name is a text field under the icon, to type the name it should have."
desktop_new!(v::DesktopView, kind::Symbol, at) = begin
  e = editor(v)
  path = kind == :folder ? free_path(e, v.path, "Untitled") : free_path(e, v.path, "Untitled", ".md")
  try kind == :folder ? mkdir(path) : touch(path) catch; return end   # the disk said no
  look = desktop_look(v)
  if look.order == :none
    Desks.place!(desktop_kept(v.path), basename(path), at, v.area, look)
    desktop_keep!(e, v.path)
  end
  v.read = 0.0
  v.chosen = Set([basename(path)])
  list_files!(e)
  rename!(e, path, at=:desktop, new=kind)
  nothing
end

"The page of the Mac's settings that has the wallpaper"
const WALLPAPER_SETTINGS = "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"

"Show the menu of the desktop `v`, for a right-click on its wallpaper at `at`"
desktop_menu!(v::DesktopView, w, at) = begin
  sorts = findfirst(x -> x isa Pair && first(x) == "Sort By", DESKTOP_MENU)
  cleans = findfirst(x -> x isa Pair && first(x) == "Clean Up By", DESKTOP_MENU)
  act(i, j=0) = begin
    name = DESKTOP_MENU[i] isa Pair ? first(DESKTOP_MENU[i]) : DESKTOP_MENU[i]
    name == "New Folder" ? desktop_new!(v, :folder, at) :
    name == "New Page" ? desktop_new!(v, :page, at) :
    name == "Sort By" ? desktop_sort!(v, get(DESKTOP_SORTS, j, "")) :
    name == "Clean Up" ? desktop_clean!(v) :
    name == "Clean Up By" ? desktop_clean!(v, get(DESKTOP_ORDERS, get(DESKTOP_CLEANS, j, ""), :name)) :
    name == "Change Wallpaper…" ? (open_url(WALLPAPER_SETTINGS); nothing) :
    name == "Show in Finder" ? show_in_finder(v.path) : nothing
  end
  # The way that the desktop is sorted now has a tick. A sorted desktop has nothing to clean up, as in the Finder.
  ticked = [(sorts, findfirst(==(desktop_sort(v.path)), DESKTOP_SORTS))]
  off = desktop_look(v).order == :none ? Int[] : [cleans - 1, cleans]
  system_menu(w, DESKTOP_MENU, act; off, ticked) || drawn_menu!(w, DESKTOP_MENU, act; off, ticked)
  nothing
end

"""
Show the menu of the icon called `name` of the desktop `v`: the menu that the
sidebar has for the folder or the file, under an item that opens it. When more
than one icon is chosen, the menu is for them all.
"""
icon_menu!(v::DesktopView, w, name) = begin
  e = editor(v)
  path = joinpath(v.path, name)
  names = sort!(collect(v.chosen))
  items = length(names) > 1 ? ["Open", "-", "Move to Trash"] : ["Open", "-", file_menu(path)...]
  act(i) = begin
    item = get(items, i, "")
    item == "Open" ? foreach(n -> desktop_open!(v, n), names) :
    item == "Move to Trash" ? desktop_trash!(v, names) : file_act!(e, path, item, at=:desktop)
    nothing
  end
  system_menu(w, items, act) || drawn_menu!(w, items, act)
  nothing
end

"Move the icons of the desktop `v` that are called `names` to the Trash, and keep the keyboard on the desktop"
desktop_trash!(v::DesktopView, names) = begin
  e = editor(v)
  foreach(n -> trash!(e, joinpath(v.path, n)), names)
  v.read = 0.0
  e.buf.path == v.path && focus(v)
  nothing
end

onkey(v::AbstractDesktop, ev::KeyPress{Keys.mouse_right}) = begin
  w = ev.window
  at = desktop_at(v, w.mouse)
  at === nothing && return handled
  focus(v)
  name = icon_at(v, at)
  if name === nothing
    empty!(v.chosen)
    desktop_menu!(v, w, at)
  else
    name in v.chosen || (v.chosen = Set([name]))
    icon_menu!(v, w, name)
  end
  handled
end

"""
Choose the icon of the desktop `v` that's nearest to the chosen one in the
direction (`dx`, `dy`), as an arrow key does. With no icon chosen, it's the
first one of the desktop's order.
"""
desktop_step!(v::AbstractDesktop, dx, dy) = begin
  isempty(v.names) && return
  from = length(v.chosen) == 1 ? get(v.spots, only(v.chosen), nothing) : nothing
  if from === nothing
    look = desktop_look(v)
    v.chosen = Set([first(look.order == :none ? sort(v.names, by=n -> (-v.spots[n][1], v.spots[n][2])) : Desks.sorted(v.path, v.names, look.order))])
    return
  end
  best, least = nothing, Inf
  for (name, at) in v.spots
    along = (at[1] - from[1]) * dx + (at[2] - from[2]) * dy
    across = abs((at[1] - from[1]) * dy) + abs((at[2] - from[2]) * dx)
    along > 1 || continue
    # An icon straight ahead comes before a nearer one that's off to the side
    far = along + 3across
    far < least && ((best, least) = (name, far))
  end
  best === nothing || (v.chosen = Set([best]))
  nothing
end

onkey(v::AbstractDesktop, ev::KeyPress{K}) where K = begin
  w = ev.window
  e = editor(v)
  cmd, none = only_held(w, Keys.cmd), unmodified(w)
  names = sort!(collect(v.chosen))
  if K == Keys.down && cmd
    foreach(n -> desktop_open!(v, n), names)
  elseif K in (Keys.backspace, Keys.delete) && cmd
    desktop_remove!(v, names)
  elseif K == Keys.a && cmd
    v.chosen = Set(v.names)
  elseif K == Keys.enter && none && length(names) == 1
    desktop_enter!(v, only(names))
  elseif none && K in (Keys.left, Keys.right, Keys.up, Keys.down)
    desktop_step!(v, (K == Keys.right) - (K == Keys.left), (K == Keys.down) - (K == Keys.up))
  else
    return nothing   # any other key is the window's, like the one that goes back
  end
  redraw_in!(v, 0)
  handled
end

# --- the browser folder: a desktop of your favourite sites ------------------------------------
#
# The browser folder, ~/web, has a globe for its icon, and its page is a
# desktop of the sites that you chose as favourites, in place of its folders
# and files. Each site is an icon on the Mac's wallpaper, with its name under
# it. The icon is the one that the site has for a phone's home screen, or else
# the small one that its pages name, on a white tile. A site with neither has
# the first letter of its name, on a tile of a colour of its own.
#
# The star in the top bar of a page from the web makes the page a favourite,
# and a click on the full star takes it off. Add to Favourites and Remove from
# Favourites in the command palette do the same. Ladder keeps the favourites
# in a page of your own, Favourites.md at the top of the browser folder, so you
# can change their names and their order there: see sites.jl. Edit Favourites,
# in the menu of the desktop, shows that page.
#
# The icons are laid out, chosen and dragged as on any desktop. Sort By has
# only None, Snap to Grid and Name, since a site has no kind, size or date. Two
# clicks on an icon, or Return, go to the site in the window. ⌘⌫, and Remove
# from Favourites in an icon's menu, take a site off the list.

"The browser folder, whose page is a desktop of your favourite sites. The folder of each site in it is of the kind that it would be anywhere else."
@def struct BrowserDirectory <: AbstractDirectory end
FS.kind(::BrowserDirectory, path::FSPath) = folder_kind(path)

push!(BLOCK_ICONS, "globe", "star", "star-fill")
entry_icon(::BrowserDirectory) = "globe"

"A click on the browser folder in the sidebar shows its desktop in the page, and the sidebar lists what it holds"
open!(e, d::BrowserDirectory; record=true) = (open!(e, string(d.path); record); go_folder!(e, string(d.path)))

page_view(e, d::BrowserDirectory) = (path = string(d.path); node!(() -> SitesView(path=path), e, (:desktop, path)))
page_fills(e, ::BrowserDirectory) = true
page_covers(e, ::BrowserDirectory) = true

"The page that keeps your favourite sites"
favourites_file() = joinpath(browser_folder(), Sites.NAME)

"What the page shows of the browser folder: an icon for each favourite site, on the Mac's wallpaper. It has the fields of a `DesktopView`."
@def mutable struct SitesView <: AbstractDesktop
  path::String = ""
  names::Vector{String} = String[]                 # the names of the sites, as Favourites.md was last read
  read::Float64 = 0.0
  area::NTuple{2,Float64} = (0.0, 0.0)
  spots::Dict{String,NTuple{2,Float64}} = Dict{String,NTuple{2,Float64}}()
  chosen::Set{String} = Set{String}()
  press::Any = nothing
  moved::NTuple{2,Float64} = (0.0, 0.0)
  dragging::Bool = false
  over::String = ""
  clicked::Tuple{Float64,String} = (0.0, "")
  sites::Dict{String,String} = Dict{String,String}()   # the web address of each site, by its name
end

"The names of the favourite sites, in the order of Favourites.md. The view `v` keeps the address of each."
desktop_names(e, v::SitesView) = begin
  sites = Sites.list(favourites_file())
  v.sites = Dict(s.name => s.address for s in sites)
  String[s.name for s in sites]
end

"""
How the icons of the sites look: as on the Mac's desktop. A site has no kind,
size or date, so a desktop of sites that the Mac's desktop would sort by one
of those is sorted by name.
"""
desktop_look(v::SitesView) = begin
  l = desktop_look(v.path)
  l.order in (:none, :name) ? l : Desks.Look(order=:name, snap=l.snap, icon=l.icon, gap=l.gap, text=l.text, previews=l.previews)
end

"The picture of each site's icon that Ladder has found, by the address of the site's home page"
const SITE_PICTURES = Dict{String,String}()

"""
The key of the picture of the icon of the site of `address`, or nothing while
Ladder has none. It's the site's icon for a phone's home screen,
apple-touch-icon.png, when the site has one: it's big and sharp. Else it's the
icon that the site's home page names, or its favicon.ico. Ladder gets each
once, and keeps it with the pictures of the link cards.
"""
site_picture(e, address) = begin
  Cards.isaddress(address) || return nothing
  home = Cards.origin(address) * "/"
  kept = get(SITE_PICTURES, home, nothing)
  kept === nothing || return kept
  ask = online(e)
  file, coming = Cards.picture!(home * "apple-touch-icon.png", cards_dir(); ask)
  big = file === nothing ? nothing : picture_key(file)
  big === nothing || return (SITE_PICTURES[home] = big)
  card, reading = Cards.lookup!(home, cards_dir(); ask)
  file, getting = Cards.picture!(isempty(card.icon) ? home * "favicon.ico" : card.icon, cards_dir(); ask)
  (coming || reading || getting) && redraw_in!(e, 0.2)   # look again soon
  small = file === nothing ? nothing : picture_key(file)
  # The small icon shows until Ladder knows that the site has no big one
  small === nothing || coming || (SITE_PICTURES[home] = small)
  small
end

"The colours of the tiles of the sites that have no icon. A site has the same one each time, by its name."
const SITE_TILES = (RGBA(0.89, 0.33, 0.27, 1.0), RGBA(0.95, 0.58, 0.18, 1.0), RGBA(0.31, 0.65, 0.35, 1.0), RGBA(0.16, 0.6, 0.65, 1.0),
                    RGBA(0.23, 0.47, 0.85, 1.0), RGBA(0.48, 0.36, 0.8, 1.0), RGBA(0.82, 0.32, 0.56, 1.0), RGBA(0.45, 0.47, 0.5, 1.0))

"The tile of the site called `name`: its icon on white, or the first letter of its name on a colour of its own"
icon_face(e, v::SitesView, name, look, budget) = begin
  side = look.icon
  key = site_picture(e, get(v.sites, name, ""))
  corner = px(0.22side)
  tile(colour, part) = Box(fixed(px(side)), height(px(side)), radius(corner), Alignment.Center, justify=Alignment.Center, clip=true, background(colour), part)
  if key === nothing
    colour = SITE_TILES[mod(Int(hash(Sites.host(get(v.sites, name, name))) % 1024), length(SITE_TILES)) + 1]
    # A Box of its own keeps the letter as wide as it is, so it's in the tile's middle
    return tile(colour, Box(label(uppercase(string(first(name))), px(0.45side), color=RGBA(1, 1, 1, 1), weight="Semibold")))
  end
  src = image_source(key)
  shape = src.width / max(src.height, 1)
  # An icon that's sharp at the tile's size fills it. A small one is in its middle, at half the size.
  fill = min(src.width, src.height) >= 1.5side
  room = fill ? side : side / 2
  # The tile's clip is square, so an icon that fills it rounds its own corners
  tile(RGBA(1, 1, 1, 1), Image(key, fixed(px(shape >= 1 ? room : room * shape)), height(px(shape >= 1 ? room / shape : room)), (fill ? (radius(corner),) : ())...))
end

"With no favourite sites, the desktop says how to add one"
desktop_note(v::SitesView, w, h) =
  (Box(fixed(px(w)), height(px(h)), Alignment.Center, justify=Alignment.Center, name="Note",
     Column(Alignment.Center, padding(18px, 12px), radius(10px), child_gap=6px, background(RGBA(0, 0, 0, 0.45)),
       Box(label("Your favourite sites show here.", 15px, color=RGBA(1, 1, 1, 1), weight="Semibold")),
       Box(label("To add a site, click the star in the top bar of one of its pages.", 13px, color=RGBA(1, 1, 1, 0.85))))),)

"Go to the site called `name` of the desktop `v`, in the window. What isn't a page of Markdown or HTML opens in your browser, as a link does."
desktop_open!(v::SitesView, name) = begin
  address = get(v.sites, name, "")
  isempty(address) || get_page!(editor(v), address, else_browser=true)
  nothing
end

"Return goes to the chosen site"
desktop_enter!(v::SitesView, name) = desktop_open!(v, name)

"⌘⌫ takes the chosen sites off the favourites"
desktop_remove!(v::SitesView, names) = begin
  e = editor(v)
  foreach(n -> haskey(v.sites, n) && Sites.remove!(favourites_file(), v.sites[n]), names)
  sites_changed!()
  e.buf.path == v.path && focus(v)
  nothing
end

"Draw each window again, as Favourites.md changed"
sites_changed!() = foreach(o -> redraw_in!(o, 0), editors)

"""
Read the names of the favourite sites again. `Sites.list` reads Favourites.md
only when it has changed, so this is on each frame, and a change there shows
at once. A site that went is no longer chosen, and its place is forgotten.
"""
desktop_read!(e, v::SitesView) = begin
  names = desktop_names(e, v)
  names == v.names && return
  v.names = names
  intersect!(v.chosen, names)
  k = desktop_kept(v.path)
  isempty(names) || (Desks.prune!(k, names) && desktop_keep!(e, v.path))
  nothing
end

"Show Favourites.md, where you change the names and the order of the favourite sites. Ladder makes it when it isn't there."
edit_favourites!(e) = begin
  file = favourites_file()
  isfile(file) || try mkpath(dirname(file)); write(file, Sites.TOP) catch; return e end
  show_path!(e, file)
end

# The menu of the wallpaper of the desktop of sites
const SITES_SORTS = ["None", "Snap to Grid", "-", "Name"]
const SITES_MENU = Any["Edit Favourites", "-", "Sort By" => SITES_SORTS, "Clean Up", "Clean Up By Name", "-", "Change Wallpaper…", "Show in Finder"]

"Show the menu of the desktop of sites `v`, for a right-click on its wallpaper"
desktop_menu!(v::SitesView, w, at) = begin
  e = editor(v)
  look = desktop_look(v)
  act(i, j=0) = begin
    name = SITES_MENU[i] isa Pair ? first(SITES_MENU[i]) : SITES_MENU[i]
    name == "Edit Favourites" ? (edit_favourites!(e); nothing) :
    name == "Sort By" ? desktop_sort!(v, get(SITES_SORTS, j, "")) :
    name == "Clean Up" ? desktop_clean!(v) :
    name == "Clean Up By Name" ? desktop_clean!(v, :name) :
    name == "Change Wallpaper…" ? (open_url(WALLPAPER_SETTINGS); nothing) :
    name == "Show in Finder" ? show_in_finder(v.path) : nothing
  end
  sorts = findfirst(x -> x isa Pair, SITES_MENU)
  now = look.order == :none ? (look.snap ? "Snap to Grid" : "None") : "Name"
  ticked = [(sorts, findfirst(==(now), SITES_SORTS))]
  # A sorted desktop has nothing to clean up, as in the Finder
  off = look.order == :none ? Int[] : [sorts + 1, sorts + 2]
  system_menu(w, SITES_MENU, act; off, ticked) || drawn_menu!(w, SITES_MENU, act; off, ticked)
  nothing
end

"Show the menu of the site called `name` of the desktop `v`. When more than one site is chosen, the menu is for them all."
icon_menu!(v::SitesView, w, name) = begin
  e = editor(v)
  names = sort!(collect(v.chosen))
  items = length(names) > 1 ? ["Open", "-", "Remove from Favourites"] : ["Open", "Copy Address", "-", "Remove from Favourites"]
  act(i) = begin
    item = get(items, i, "")
    item == "Open" ? foreach(n -> desktop_open!(v, n), names) :
    item == "Copy Address" ? copy_text!(e, get(v.sites, name, "")) :
    item == "Remove from Favourites" ? desktop_remove!(v, names) : nothing
    nothing
  end
  system_menu(w, items, act) || drawn_menu!(w, items, act)
  nothing
end

"""
The name that a favourite gets for the page from the web that `e` shows. A
site's home page gives the name of its site, when it says one, and any other
page its title. Else it's the page's first heading, or the name of its computer.
"""
favourite_name(e) = begin
  path, address = e.buf.path, web_address(e.buf.path)
  if lowercase(splitext(path)[2]) in HTMLS
    c = try Cards.card(read(path), address) catch; Cards.Card(address) end
    home = Cards.path(address) in ("", "/")
    name = home && !isempty(c.site) ? c.site : c.title
    isempty(name) || return name
  end
  for line in e.buf.lines[1:min(end, 60)]
    m = match(r"^(?:title:\s*|#\s+)(\S.*?)\s*$", line)
    m === nothing || return String(strip(m[1], ['"', '\'']))
  end
  Sites.host(address)
end

"True when the page from the web that `e` shows is a favourite"
is_favourite(e) = in_browser(e.buf.path) && Sites.isfavourite(favourites_file(), web_address(e.buf.path))

"""
Add to Favourites: put the page from the web that shows on the desktop of the
browser folder, with its title for its name. Ladder writes it at the end of
Favourites.md.
"""
add_to_favourites!(e) = begin
  in_browser(e.buf.path) || return e
  address, name = web_address(e.buf.path), favourite_name(e)
  added = try Sites.add!(favourites_file(), name, address) catch; false end
  sites_changed!()
  say_result!(e, added ? "$name is a favourite now. It shows in the browser folder." : "This page is a favourite already.")
end
add_command!(add_to_favourites!, title="Put the page from the web that shows on the browser folder's desktop of favourite sites", kind=:look)

"Remove from Favourites: take the page from the web that shows off the desktop of the browser folder"
remove_from_favourites!(e) = begin
  in_browser(e.buf.path) || return e
  gone = try Sites.remove!(favourites_file(), web_address(e.buf.path)) catch; false end
  sites_changed!()
  gone ? say_result!(e, "This page isn't a favourite now.") : e
end
add_command!(remove_from_favourites!, title="Take the page from the web that shows off the browser folder's desktop of favourite sites", kind=:look)

works_here(e, ::Val{:add_to_favourites}) = in_browser(e.buf.path) && !is_favourite(e)
works_here(e, ::Val{:remove_from_favourites}) = is_favourite(e)
"""
The star in the top bar of a page from the web. It's full while the page is a
favourite, and a click takes it off. While it's empty, a click makes the page
a favourite.
"""
favourite_bar(e) = begin
  in_browser(e.buf.path) || return ()
  b = button(e, :favourite, "star")
  b.icon = is_favourite(e) ? "star-fill" : "star"
  (b,)
end
BAR_PARTS[:favourite] = favourite_bar
BUTTONS[:favourite] = (
  run=e -> is_favourite(e) ? remove_from_favourites!(e) : add_to_favourites!(e),
  tip=e -> is_favourite(e) ? "A favourite site. Click to take it off the browser folder's desktop" :
                             "Click to put this page on the browser folder's desktop of favourite sites",
  off=e -> false,
  strong=false)
