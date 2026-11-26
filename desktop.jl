# What a desktop is, apart from the window that shows it. A desktop is a folder
# whose folders and files show as icons on a wallpaper, as the Mac's own
# desktop shows the Desktop folder. main.jl draws it and takes the mouse. This
# file says where each icon goes.
#
# The icons look as the Finder's settings for the Mac's desktop say: how big
# they are, how far apart, and how they're sorted. `finder_look` reads those,
# and `wallpaper` gives the picture behind the Mac's desktop. The Finder keeps
# no place for an icon of a sorted desktop, and it takes no place and no order
# from another app. So Ladder works out the grid as the Finder does: the first
# icon goes at the top right, the next ones go down, and each new column is to
# the left of the last.
#
#     look = finder_look()                                  # Look(order=:kind, icon=64.0, ...)
#     places(dir, names, (1200.0, 800.0), look, Kept())     # "House" => (1133.0, 44.0), ...
#
# What you choose in Ladder is kept for each folder, as a `Kept`: how it's
# sorted, and where you put each icon while nothing sorts them. A place is
# kept as a share of the desktop's width and height, so an icon in the middle
# stays in the middle when the window changes its size.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/UI.jl/Interface/objc" cls msg nsstring jstring with_pool
@use "./macfile" resource date_of

const AppKit = "/System/Library/Frameworks/AppKit.framework/AppKit"
const Object = Ptr{Cvoid}
const Spot = NTuple{2,Float64}   # across and down, from the top left corner

"The ways that a desktop sorts its icons. With `:none`, each icon stays where you put it."
const ORDERS = (:none, :name, :kind, :changed, :made, :size)

"""
How a desktop shows its icons. `order` is one of `ORDERS`. With `snap`, an icon
that you put somewhere goes to the nearest cell of the grid. `icon` is how wide
and tall an icon is, `gap` is the space between two icons, and `text` is the
size of the names. With `previews`, a picture's icon is the picture.
"""
@def struct Look
  order::Symbol = :name
  snap::Bool = false
  icon::Float64 = 64.0
  gap::Float64 = 54.0
  text::Float64 = 12.0
  previews::Bool = true
end

# What the Finder's settings call each way to sort. Ladder has no date that a file was added or last
# opened, so those two sort by the nearest date that it has.
const FINDER_ORDERS = Dict("none" => :none, "grid" => :none, "name" => :name, "kind" => :kind, "size" => :size,
                           "dateModified" => :changed, "dateLastOpened" => :changed, "dateCreated" => :made, "dateAdded" => :made)

"How the Finder shows the icons of the Mac's own desktop. On another system, or when the Finder has no settings yet, it's the usual look."
finder_look() = begin
  Sys.isapple() || return Look()
  try
    with_pool() do
      defaults = msg(msg(msg(cls("NSUserDefaults"), "alloc"), "initWithSuiteName:", nsstring("com.apple.finder")), "autorelease")
      all = msg(defaults, "dictionaryForKey:", nsstring("DesktopViewSettings"))
      set = all == C_NULL ? C_NULL : msg(all, "objectForKey:", nsstring("IconViewSettings"))
      set == C_NULL && return Look()
      said(key) = (v = msg(set, "objectForKey:", nsstring(key)); v == C_NULL ? "" : jstring(msg(v, "description")))
      number(key, usual, least, most) = clamp(something(tryparse(Float64, said(key)), usual), least, most)
      by = said("arrangeBy")
      Look(order=get(FINDER_ORDERS, by, :name), snap=by == "grid", icon=number("iconSize", 64.0, 16.0, 128.0),
           gap=number("gridSpacing", 54.0, 10.0, 100.0), text=number("textSize", 12.0, 10.0, 16.0), previews=said("showIconPreview") != "0")
    end
  catch
    Look()
  end
end

"The file of the picture behind the Mac's own desktop, or \"\" when macOS doesn't name one"
wallpaper() = begin
  Sys.isapple() || return ""
  try
    Base.Libc.Libdl.dlopen(AppKit)
    with_pool() do
      screen = msg(cls("NSScreen"), "mainScreen")
      screen == C_NULL && return ""
      url = msg(msg(cls("NSWorkspace"), "sharedWorkspace"), "desktopImageURLForScreen:", screen)
      url == C_NULL ? "" : jstring(msg(url, "path"))
    end
  catch
    ""
  end
end

# What reads the Finder's settings and the wallpaper. A test puts functions of its own here, so it doesn't depend on the Mac that runs it.
const looker = Ref{Function}(finder_look)
const papers = Ref{Function}(wallpaper)

# --- what the Finder knows of a file -------------------------------------------------------

"What a desktop needs to know of a folder or a file to sort it: what the Finder calls its kind, when it was made and changed, and how big it is"
@def struct Facts
  kind::String = ""
  made::Float64 = 0.0
  changed::Float64 = 0.0
  size::Int = 0
  folder::Bool = false
  hidden::Bool = false
end

# The facts of each path, with the time that the file had changed when they were read
const known = Dict{String,Tuple{Float64,Facts}}()

"""
The facts of the folder or the file at `path`. They're read again when it has
changed. macOS says what kind of file it is, in the words that the Finder
shows, like Folder or PNG image. Another system gives the end of the file's name.
"""
facts(path::AbstractString) = begin
  st = stat(path)
  kept = get(known, path, nothing)
  kept !== nothing && kept[1] == st.mtime && return kept[2]
  folder = isdir(st)
  kind = folder ? "Folder" : (ext = splitext(path)[2]; isempty(ext) ? "Document" : uppercase(ext[2:end]) * " file")
  made, hidden = st.ctime, startswith(basename(path), '.')
  if Sys.isapple()
    try
      with_pool() do
        said = resource(path, "NSURLLocalizedTypeDescriptionKey")
        said == C_NULL || (kind = jstring(said))
        date = date_of(path, "NSURLCreationDateKey")
        date === nothing || (made = date)
        flag = resource(path, "NSURLIsHiddenKey")
        flag == C_NULL || (hidden = jstring(msg(flag, "description")) == "1")
      end
    catch
      # macOS didn't say, so the facts are the ones that any system gives
    end
  end
  f = Facts(kind=kind, made=made, changed=st.mtime, size=folder ? 0 : Int(st.size), folder=folder, hidden=hidden)
  length(known) > 20_000 && empty!(known)
  known[path] = (st.mtime, f)
  f
end

# --- the order of the icons ----------------------------------------------------------------

"""
A key that puts names in the order that the Finder does. Capitals don't count,
and digits count as a number, so `Plan 2` comes before `Plan 10`.
"""
name_key(name::AbstractString) =
  [isdigit(first(m.match)) ? (0, something(tryparse(Int128, m.match), Int128(0)), "") : (1, Int128(0), lowercase(m.match))
   for m in eachmatch(r"\d+|\D+", name)]

"""
`names`, which are in the folder `dir`, in the order that `order` gives a
desktop. The newest comes first by a date, and the biggest file by size, with
the folders after the files, since a folder has no size here. Two that are the
same in that way are in the order of their names.
"""
sorted(dir, names, order::Symbol) = begin
  f(n) = facts(joinpath(dir, n))
  by = order == :kind ? (n -> (lowercase(f(n).kind), name_key(n))) :
       order == :changed ? (n -> (-f(n).changed, name_key(n))) :
       order == :made ? (n -> (-f(n).made, name_key(n))) :
       order == :size ? (n -> (f(n).folder, -f(n).size, name_key(n))) : name_key
  sort(collect(String, names), by=by)
end

# --- the grid ------------------------------------------------------------------------------

# The Finder's grid on a desktop with icons of 64 and a space of 54 has columns 124 apart and rows 112 apart
"How wide and how tall a cell of the grid is"
cell(l::Look) = (l.icon + l.gap + 6, l.icon + l.gap - 6)

"""
The grid of a desktop: how many rows it has, where the middle of the icon of
its first cell is, and how far apart its columns and rows are. The first cell
is at the top right, the cells of a column go down, and each column after the
first is to the left of the one before.
"""
struct Grid
  rows::Int
  first::Spot
  step::Spot
end

const EDGE = 5.0   # between the first column's cells and the right edge of the desktop
const TOP = 12.0   # between the first row's icons and the top of the desktop

"The grid of a desktop that's `size` wide and tall, for icons that look as `l` says"
grid(size::Spot, l::Look) = begin
  w, h = cell(l)
  Grid(max(1, floor(Int, (size[2] - TOP) / h)), (size[1] - EDGE - w / 2, TOP + l.icon / 2), (w, h))
end

"The middle of the icon in the cell of the grid at `col` and `row`, each from 1"
spot(g::Grid, col::Integer, row::Integer) = (g.first[1] - (col - 1) * g.step[1], g.first[2] + (row - 1) * g.step[2])
"The middle of the icon in cell `k` of the grid, in the order that a sorted desktop fills the cells"
spot(g::Grid, k::Integer) = spot(g, (k - 1) ÷ g.rows + 1, (k - 1) % g.rows + 1)

"The middle of the icon in the cell that's nearest to `at`"
nearest(g::Grid, at::Spot) = begin
  col = max(1, round(Int, (g.first[1] - at[1]) / g.step[1]) + 1)
  row = clamp(round(Int, (at[2] - g.first[2]) / g.step[2]) + 1, 1, g.rows)
  spot(g, col, row)
end

"True when an icon at `a` would lie over an icon at `b`"
meets(g::Grid, a::Spot, b::Spot) = abs(a[1] - b[1]) < g.step[1] / 2 && abs(a[2] - b[2]) < g.step[2] / 2

"The middle of the icon in the first cell that has no icon of `taken` over it"
free(g::Grid, taken) = begin
  k = 1
  while any(t -> meets(g, spot(g, k), t), taken)
    k += 1
  end
  spot(g, k)
end

"`at`, moved so that an icon there is all in a desktop of `size`"
within(size::Spot, l::Look, at::Spot) = begin
  half = l.icon / 2 + 4
  (clamp(at[1], half, max(half, size[1] - half)), clamp(at[2], half, max(half, size[2] - half - 2l.text)))
end

# --- what Ladder keeps of a desktop --------------------------------------------------------

"""
What Ladder keeps of a desktop: how it's sorted and whether its icons go to the
grid, once you choose those in Ladder, and where you put each icon. Until you
choose, `order` and `snap` are nothing, and the desktop is sorted as the Mac's
own. A place is a share of the desktop's width and of its height, by the
icon's name.
"""
@def mutable struct Kept
  order::Union{Symbol,Nothing} = nothing
  snap::Union{Bool,Nothing} = nothing
  places::Dict{String,Spot} = Dict{String,Spot}()
end

"How a desktop shows its icons: as the Finder shows the Mac's desktop, with what you chose in Ladder in place of the Finder's order"
look(k::Kept, finder::Look) =
  Look(order=something(k.order, finder.order), snap=something(k.snap, finder.snap), icon=finder.icon, gap=finder.gap,
       text=finder.text, previews=finder.previews)

"The name of the file that keeps the desktop of the folder `dir`"
filename(dir::AbstractString) = (name = replace(strip(dir, '/'), '/' => '%'); isempty(name) ? "%" : last(name, 200))

"What the file at `path` keeps of a desktop. A file that isn't there, or a line that can't be read, keeps nothing."
load(path::AbstractString) = begin
  k = Kept()
  isfile(path) || return k
  for line in eachline(path)
    key, value = (split(line, '=', limit=2)..., "")[1:2]
    if key == "order"
      Symbol(value) in ORDERS && (k.order = Symbol(value))
    elseif key == "snap"
      k.snap = value == "true"
    elseif key == "at"
      # The name comes last, because a name can have a space in it
      parts = split(value, ' ', limit=3)
      length(parts) == 3 || continue
      x, y = tryparse(Float64, parts[1]), tryparse(Float64, parts[2])
      (x === nothing || y === nothing || isempty(parts[3])) || (k.places[String(parts[3])] = (x, y))
    end
  end
  k
end

"Write what `k` keeps of a desktop to the file at `path`. It's false when the file can't be written."
save(path::AbstractString, k::Kept) = begin
  lines = String[]
  k.order === nothing || push!(lines, "order=$(k.order)")
  k.snap === nothing || push!(lines, "snap=$(k.snap)")
  for name in sort!(collect(keys(k.places)))
    x, y = k.places[name]
    push!(lines, "at=$(round(x, digits=5)) $(round(y, digits=5)) $name")
  end
  try
    mkpath(dirname(path))
    write(path, join(lines, "\n") * "\n")
    true
  catch
    false
  end
end

# --- where each icon goes ------------------------------------------------------------------

"Where `at` is on a desktop of `size`, as a share of its width and of its height"
share(at::Spot, size::Spot) = (at[1] / max(size[1], 1.0), at[2] / max(size[2], 1.0))

"""
The middle of the icon of each of `names`, which are in the folder `dir`, on a
desktop that's `size` wide and tall. A sorted desktop fills the grid in its
order. With no order, each icon is where `k` keeps it, and an icon that has no
place yet takes the first free cell of the grid.
"""
places(dir, names, size::Spot, l::Look, k::Kept) = begin
  g = grid(size, l)
  out = Dict{String,Spot}()
  if l.order != :none
    foreach(((i, n),) -> out[n] = spot(g, i), enumerate(sorted(dir, names, l.order)))
    return out
  end
  for n in names
    p = get(k.places, n, nothing)
    p === nothing || (out[n] = within(size, l, (p[1] * size[1], p[2] * size[2])))
  end
  for n in sorted(dir, [n for n in names if !haskey(out, n)], :name)
    out[n] = free(g, values(out))
  end
  out
end

"Keep the place `at` of the icon called `name`, on a desktop of `size`. With `snap`, it goes to the nearest cell of the grid."
place!(k::Kept, name, at::Spot, size::Spot, l::Look) = begin
  at = within(size, l, l.snap ? nearest(grid(size, l), at) : at)
  k.places[String(name)] = share(at, size)
  at
end

"Forget the places of the icons whose names aren't in `names`, as when a file has left the folder. It's true when a place went."
prune!(k::Kept, names) = begin
  gone = [n for n in keys(k.places) if !(n in names)]
  foreach(n -> delete!(k.places, n), gone)
  !isempty(gone)
end
