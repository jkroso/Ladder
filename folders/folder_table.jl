# A table of what's in a folder
#
# A folder that has no page of its own shows in the page as a table of its
# folders and files, as the home folder does, and so does a repository's page. A row for each folder and file that the sidebar lists, with
# its icon, its size and when it last changed. The icon is its kind. A
# folder's size is of every file in it, at any depth, and its time is when
# anything in it last changed: see `Folders.newest` and `Folders.sizes`. The one that
# changed last is at the top.
#
# A click on a heading opens the menu of its column, as a CSV file's table
# has: its two orders, and what shows fewer rows. The heading over the icons
# has a tick for each kind, as the Finder names it. The name has a field for
# words that it holds, and the size and the time each have two ends, like
# `10 MB` and `2 GB`, or `3 days ago` and `1 Nov 2026`. A column that shows fewer rows has a funnel by its heading,
# and a line over the rows says how many show. Return closes the menu and
# keeps what's typed, and esc puts back what the column had.
#
# A click on a folder opens it in the page, and a click on a file shows it. A
# right-click shows the menu of the folder or the file. The folder is read
# again each second, so a new file gets its row.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor redraw_in! popup! close_popup!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "../markdown" words
@use "../blocks/sheet" parts known shown
@use "../dates" => DatesRead
@use "./git" => Git
@use "./zip" => Zips
@use "./macfile" => MacFiles
@use "./folders" => Folders
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use Colors: RGBA
@use Dates: Dates, Date, Day
@use "../base" exports...
@use "../additions" exports...
@use "../window/showed_before" ignored_shown

@use "../flow" rows
export FolderItem, FolderTable, FolderHead, FolderMenu, FolderOrder, FolderKind, FOLDER_COLUMNS, FOLDER_HEADS,
       FOLDER_ICON_W, FOLDER_COL_W, FOLDER_ROWS_FIRST, FOLDER_MENU_W, FOLDER_KEY, folder_table!,
       folder_items!, folder_sorted, read_size, day_edge, read_when, FOLDER_FIELD_HINTS, folder_field!,
       unread_field, folder_filtered, folder_was, field_keys, clear_filters!, folder_head, folder_part!,
       close_folder_menu!, field_help, folder_item_row, size_cell, Favourite, go_to_favourite!

"A folder or a file in the table of a folder"
@def struct FolderItem
  path::String = ""
  object::Any = nothing   # its object, as the sidebar lists it
  folder::Bool = false
  kind::String = ""       # what the Finder calls its kind, like Folder or PNG image. Its icon shows it.
  size::Int = 0           # in bytes. A folder's is of every file in it, at any depth.
  sized::Bool = true      # its size is known. A folder's isn't while it's still being read, or when it isn't read, like ~/Library.
  when::Float64 = 0.0     # when it last changed, or 0 when macOS doesn't say. For a folder, when anything in it did.
  known::Bool = true      # its time is known. A folder's isn't while it's still being read.
end

"The table of the folders and files in the folder at `path`, with the column that it's sorted by, and what shows fewer rows"
@def mutable struct FolderTable <: SemanticUI
  path::String = ""
  rows::Dict{Any,PageRow} = Dict{Any,PageRow}()
  buttons::Dict{Any,PageButton} = Dict{Any,PageButton}()
  items::Vector{FolderItem} = FolderItem[]       # each folder and file in the folder, as it was read last
  read::Float64 = 0.0                            # when the folder was read
  sort::Symbol = :when                           # the column that the table is sorted by: :name, :kind, :size or :when
  desc::Bool = true                              # Z, the largest or the newest first
  heads::Dict{Symbol,Any} = Dict{Symbol,Any}()   # the heading of each column
  every::Bool = false                            # it shows every row, not only the first ones
  hidden::Bool = false                           # it listed the hidden files and folders when it was read
  kinds::Set{String} = Set{String}()             # the kinds that are ticked in the menu of the kinds. With none, every kind shows.
  fields::Dict{Symbol,Any} = Dict{Symbol,Any}()  # the text fields of the menus: :name, :size_lo, :size_hi, :when_lo and :when_hi
  asking::Symbol = :none                         # the column whose menu is open
  was::Any = nothing                             # what that column had when its menu opened, which esc puts back
  parts::Dict{Any,Any} = Dict{Any,Any}()         # the menu, and its orders and kinds
  kindof::Dict{String,String} = Dict{String,String}()   # what macOS called the kind of each thing, by its path
  bytes::Int = -1                                # what the folder holds, at any depth, hidden files too, or -1 while that isn't known
end

"The heading of a column of a folder's table. A click on it opens the column's menu."
@def mutable struct FolderHead <: SemanticUI
  table::Any = nothing   # the FolderTable that it's on
  key::Symbol = :name    # :name, :kind, :size or :when
end

"The menu of a column of a folder's table: its two orders, and what shows fewer rows"
@def mutable struct FolderMenu <: SemanticUI
  table::Any = nothing
end

"One of the two orders in the menu of a column of a folder's table"
@def mutable struct FolderOrder <: SemanticUI
  table::Any = nothing
  desc::Bool = false   # Z, the largest or the newest first
end

"A kind in the menu of the kinds of a folder's table, with its icon. A click ticks it, or takes the tick away."
@def mutable struct FolderKind <: SemanticUI
  table::Any = nothing
  kind::String = ""
  icon::String = "file"
  count::Int = 0
end

"The columns of a folder's table, from the left. The kind is the column of icons."
const FOLDER_COLUMNS = (:kind, :name, :size, :when)
"The words of each heading of a folder's table. The heading of the icons has an icon."
const FOLDER_HEADS = Dict(:name => "Name", :size => "Size", :when => "Modified")
"How wide the column of icons is"
const FOLDER_ICON_W = 16px
"How wide the columns of sizes and times are"
const FOLDER_COL_W = 90px
"How many rows a folder's table shows before the button that shows them all"
const FOLDER_ROWS_FIRST = 100
"How wide the menu of a column of a folder's table is"
const FOLDER_MENU_W = 260px
"The key of the popup of that menu"
const FOLDER_KEY = :folder_column
# The app that's built has only the icons that it loaded when it was made
push!(BLOCK_ICONS, "files", "funnel-fill")

"The table of the folder at `path`, for a part of a page that `owner` draws. It keeps its order and what it shows while the window is open."
folder_table!(e, owner, path) = get!(() -> own!(owner, FolderTable(path=path)), e.nodes, (:folder_table, path))

"""
Read the folder of the table `t` again: the folders and files that the
sidebar lists, each with its kind, its size and when it last changed. A
folder's size and time are of everything in it. It's read a second after it
was last read, or at once when the sidebar starts or stops listing hidden files.
It also adds up what the whole folder holds, as the Finder does, with the
hidden folders and files that the table leaves out.
"""
folder_items!(e, t::FolderTable) = begin
  time() - t.read < 1 && t.hidden == e.hidden && t.read > Folders.changed() && return t.items
  t.read, t.hidden = time(), e.hidden
  d = try object(e, t.path) catch; nothing end
  found = d isa AbstractDirectory ? entries(e, d) : FSObject[]
  paths = String[joinpath(t.path, o.path.name) for o in found]
  # What the table leaves out, like hidden files, still counts in the folder's size. With a folder in it that
  # isn't read, like ~/Library, that size is never known, so its hidden folders, like ~/.julia, aren't read for it.
  out = try setdiff(readdir(t.path, join=true), paths) catch; String[] end
  whole = !any(Folders.unread, [paths; out])
  stats = whole ? [(p, try lstat(p) catch; nothing end) for p in out] : []
  out_folders = [p for (p, st) in stats if st !== nothing && isdir(st)]
  # When anything in each folder last changed, for the folders that have been read
  deep = Folders.newest(t.path, [[p for (p, o) in zip(paths, found) if o isa AbstractDirectory]; out_folders])
  # How big each folder is, for the folders that have been read to the end
  bytes = Folders.sizes(t.path)
  length(t.kindof) > 10_000 && empty!(t.kindof)
  t.items = map(zip(paths, found)) do (path, o)
    folder = o isa AbstractDirectory
    # macOS can refuse to say, as it does for the Trash before Ladder has Full Disk Access
    st = try stat(path) catch; nothing end
    own = st === nothing ? 0.0 : st.mtime
    FolderItem(path=path, object=o, folder=folder, kind=get!(() -> MacFiles.finder_kind(path), t.kindof, path),
               size=folder ? get(bytes, path, 0) : st === nothing ? 0 : Int(st.size), sized=!folder || haskey(bytes, path),
               when=folder ? max(own, get(deep, path, 0.0)) : own, known=!folder || haskey(deep, path))
  end
  known = whole && all(it -> it.sized, t.items) && all(p -> haskey(bytes, p), out_folders)
  t.bytes = !known ? -1 : sum(it -> it.size, t.items, init=0) + sum(p -> bytes[p], out_folders, init=0) +
                          sum(((p, st),) -> st === nothing || isdir(st) ? 0 : Int(st.size), stats, init=0)
  t.items
end

"The folders and files of the table `t`, in the order of the column that it's sorted by. Rows with the same value keep the sidebar's order."
folder_sorted(t::FolderTable) = begin
  by = t.sort == :name ? (it -> lowercase(entry_name(it.object))) :
       t.sort == :kind ? (it -> lowercase(it.kind)) :
       t.sort == :size ? (it -> it.sized ? it.size : -1) : (it -> it.when)
  sort(t.items, by=by, rev=t.desc, alg=MergeSort)
end

# --- what shows fewer rows ---

"""
The bytes that `text` says, as the Finder counts them, in thousands: `300` or
`300 bytes`, `48 KB`, `1.5 MB`, `2 GB`, `1 TB`, or `500k`. It's nothing when the
text says no size.
"""
read_size(text::AbstractString) = begin
  m = match(r"^\s*(\d+(?:\.\d+)?|\.\d+)\s*([a-zA-Z]*)\s*$", text)
  m === nothing && return nothing
  unit = lowercase(m[2])
  scale = unit in ("", "b", "byte", "bytes") ? 1 : unit in ("k", "kb") ? 1_000 : unit in ("m", "mb") ? 1_000_000 :
          unit in ("g", "gb") ? 1_000_000_000 : unit in ("t", "tb") ? 1_000_000_000_000 : nothing
  scale === nothing ? nothing : round(Int, parse(Float64, m[1]) * scale)
end

"The start of the day `d` in the Mac's time zone, in seconds, or its end when `upto` is true"
day_edge(d::Date, upto::Bool) = begin
  upto && return day_edge(d + Day(1), false) - 0.001
  tm = Libc.TmStruct()
  tm.year, tm.month, tm.mday = Dates.year(d) - 1900, Dates.month(d) - 1, Dates.day(d)
  tm.hour, tm.min, tm.sec, tm.isdst = 0, 0, 0, -1
  Libc.time(tm)
end

"""
The time that `text` says, in seconds, as the Modified column writes times:
`just now`, `5 min ago`, `3 h ago`, `today`, `yesterday`, `4 days ago`, `2 weeks
ago`, `6 months ago`, or a day like `1 Nov 2026`. `ago` can be left out. A day is
its start, or its end when `upto` is true, so a day at both ends shows that
day. It's nothing when the text says no time.
"""
read_when(text::AbstractString, upto::Bool; now::Real=time()) = begin
  w = lowercase(strip(text))
  isempty(w) && return nothing
  w in ("now", "just now") && return Float64(now)
  today = DatesRead.day(now)
  w == "today" && return day_edge(today, upto)
  w == "yesterday" && return day_edge(today - Day(1), upto)
  m = match(r"^(\d+(?:\.\d+)?)\s*([a-z]+)(?:\s+ago)?$", w)
  if m !== nothing
    u = m[2]
    secs = u in ("s", "sec", "secs", "second", "seconds") ? 1 : u in ("m", "min", "mins", "minute", "minutes") ? 60 :
           u in ("h", "hr", "hrs", "hour", "hours") ? 3600 : u in ("d", "day", "days") ? 86400 :
           u in ("w", "wk", "wks", "week", "weeks") ? 7 * 86400 : u in ("mo", "mos", "month", "months") ? 30 * 86400 :
           u in ("y", "yr", "yrs", "year", "years") ? 365 * 86400 : nothing
    secs === nothing || return now - parse(Float64, m[1]) * secs
  end
  d = DatesRead.day(w; today, year=:past)
  d === nothing ? nothing : day_edge(d, upto)
end

"What's typed in the field `key` of the menus of the table `t`"
field_text(t::FolderTable, key::Symbol) = (f = get(t.fields, key, nothing); f === nothing ? "" : f.text)

"The words that each field of the menus of a folder's table shows before anything is typed in it"
const FOLDER_FIELD_HINTS = Dict(:name => "Contains…", :size_lo => "10 MB", :size_hi => "2 GB", :when_lo => "3 days ago", :when_hi => "1 Nov 2026")

"The text field `key` of the menus of the table `t`"
folder_field!(t::FolderTable, key::Symbol) = get!(t.fields, key) do
  own!(t, TextInput(placeholder=FOLDER_FIELD_HINTS[key], font_family=SANS, font_size=13px,
                    look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text)))
end

"True when something is typed in the field `key` of the table `t` that it can't read: a size field needs a size, and a time field a time"
unread_field(t::FolderTable, key::Symbol) = begin
  text = strip(field_text(t, key))
  isempty(text) && return false
  key in (:size_lo, :size_hi) ? read_size(text) === nothing :
  key in (:when_lo, :when_hi) ? read_when(text, key == :when_hi) === nothing : false
end

"True when the column `key` of the table `t` shows fewer rows"
narrowed(t::FolderTable, key::Symbol) =
  key == :name ? !isempty(strip(field_text(t, :name))) :
  key == :kind ? !isempty(t.kinds) :
  key == :size ? read_size(field_text(t, :size_lo)) !== nothing || read_size(field_text(t, :size_hi)) !== nothing :
  key == :when ? read_when(field_text(t, :when_lo), false) !== nothing || read_when(field_text(t, :when_hi), true) !== nothing : false

"True when any column of the table `t` shows fewer rows"
narrowed(t::FolderTable) = any(k -> narrowed(t, k), FOLDER_COLUMNS)

"""
The folders and files of `items` that the menus of the table `t` let show: a
name that holds the words typed, a kind that's ticked, and a size and a time
between the two ends. A folder whose size or time isn't known yet doesn't show
while its column has an end.
"""
folder_filtered(t::FolderTable, items) = begin
  words = lowercase(strip(field_text(t, :name)))
  slo, shi = read_size(field_text(t, :size_lo)), read_size(field_text(t, :size_hi))
  wlo, whi = read_when(field_text(t, :when_lo), false), read_when(field_text(t, :when_hi), true)
  sizing, timing = slo !== nothing || shi !== nothing, wlo !== nothing || whi !== nothing
  filter(items) do it
    (isempty(words) || occursin(words, lowercase(entry_name(it.object)))) &&
    (isempty(t.kinds) || it.kind in t.kinds) &&
    (!sizing || it.sized && (slo === nothing || it.size >= slo) && (shi === nothing || it.size <= shi)) &&
    (!timing || it.known && it.when > 0 && (wlo === nothing || it.when >= wlo) && (whi === nothing || it.when <= whi))
  end
end

"What the column `key` of the table `t` has, for esc to put back"
folder_was(t::FolderTable, key::Symbol) =
  key == :kind ? copy(t.kinds) : [field_text(t, f) for f in field_keys(key)]

"The fields of the menu of the column `key`"
field_keys(key::Symbol) = key == :name ? (:name,) : key == :size ? (:size_lo, :size_hi) : key == :when ? (:when_lo, :when_hi) : ()

"Put back in the column `key` of the table `t` what `folder_was` gave"
put_back!(t::FolderTable, key::Symbol, was) = begin
  if key == :kind
    t.kinds = was
  else
    for (f, text) in zip(field_keys(key), was)
      field = folder_field!(t, f)
      field.text = text
      field.cursor = field.anchor = length(text)
    end
  end
  nothing
end

"Show every row of the table `t` again: take away what's typed in its menus, and the ticks of its kinds"
clear_filters!(t::FolderTable) = begin
  for f in values(t.fields)
    f.text = ""
    f.cursor = f.anchor = 0
  end
  empty!(t.kinds)
  nothing
end

# --- the headings and their menus ---

"The heading of the column `key` of the table `t`"
folder_head(t::FolderTable, key::Symbol) = get!(() -> own!(t, FolderHead(table=t, key=key)), t.heads, key)

"A part of the menus of the table `t`, kept under `key`"
folder_part!(make, t::FolderTable, key) = get!(() -> own!(t, make()), t.parts, key)

describe(h::FolderHead) = begin
  t = h.table
  on = t.sort == h.key
  lit = ishovered(h) || t.asking == h.key
  fewer = narrowed(t, h.key)
  # Over the icons there's room for one mark: the funnel, the arrow of the order, or two files, so the heading shows that it opens
  if h.key == :kind
    mark = fewer ? Icon("funnel-fill", size=10px, color=colours.accent) :
           on ? Icon(t.desc ? "chevron-down" : "chevron-up", size=9px, color=colours.ink) :
           Icon(lit ? "chevron-down" : "files", size=lit ? 9px : 11px, color=lit ? colours.ink : colours.faint)
    return Row(fixed(FOLDER_ICON_W), height(grow=grow), Alignment.Center, justify=Alignment.Center, name="Heading", mark)
  end
  # The funnel of a column that shows fewer rows, and the arrow of its order. With neither, the mouse over the heading shows that it opens.
  marks = ((fewer ? (Icon("funnel-fill", size=9px, color=colours.accent),) : ())...,
           (on ? (Icon(t.desc ? "chevron-down" : "chevron-up", size=9px, color=colours.ink),) :
            lit && !fewer ? (Icon("chevron-down", size=9px, color=colours.faint),) : ())...)
  # The words are in a Box of their own, so they're as wide as they are and don't fill the heading
  parts = (Box(label(FOLDER_HEADS[h.key], 11px, color=fewer ? colours.accent : on || lit ? colours.ink : colours.dim)), marks...)
  # Words go at the left of their column and numbers at the right. The marks go on the side away from the column's edge, so they don't push the words.
  left = h.key == :name
  Row(left ? width(grow=grow) : fixed(FOLDER_COL_W), height(grow=grow), Alignment.Center,
      child_gap=4px, name="Heading", justify=left ? Alignment.Start : Alignment.End, (left ? parts : reverse(parts))...)
end

cursor(::FolderHead) = :hand

onkey(h::FolderHead, ev::KeyPress{Keys.mouse_left}) = begin
  t, key = h.table, h.key
  t.asking, t.was = key, folder_was(t, key)
  menu = folder_part!(() -> FolderMenu(table=t), t, :menu)
  e = editor(t)
  # A click outside the menu closes it and keeps what's chosen
  popup!(ev.window, menu, anchor=h, placement=:below, gap=4px, width=FOLDER_MENU_W, key=FOLDER_KEY,
         onclose=() -> (t.asking = :none; focus(e)), theme=component_theme(e.zoom))
  # The first field takes the keyboard, with the caret after what it has
  fields = field_keys(key)
  if !isempty(fields)
    f = folder_field!(t, first(fields))
    f.cursor = f.anchor = length(f.text)
    focus(f)
  end
  redraw_in!(t, 0)
  handled
end

"Close the menu of the table `t`, and give the keyboard back to the page"
close_folder_menu!(t::FolderTable) = begin
  t.asking = :none
  w = window_of(t)
  w === nothing || close_popup!(w, FOLDER_KEY)
  focus(editor(t))
  handled
end

"The words of the order of the column `key` that puts Z, the largest or the newest first when `desc` is true"
order_words(key::Symbol, desc::Bool) =
  key == :size ? (desc ? "Largest first" : "Smallest first") :
  key == :when ? (desc ? "Newest first" : "Oldest first") : (desc ? "Z–A" : "A–Z")

"How to write in the fields of the column `key`"
field_help(key::Symbol) =
  key == :size ? "Like 500 KB, 10 MB or 1.5 GB" :
  key == :when ? "Like 3 days ago or 1 Nov 2026" : ""

describe(m::FolderMenu) = begin
  t, c = m.table, found_colours()
  key = t.asking
  section(words) = Row(width(grow=grow), height(22px), padding(8px, 0px), Alignment.Center, label(words, 10px, color=c.dim, weight="Semibold"))
  field(f) = Box(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), border(1px, :solid, unread_field(t, f) ? git_colour(:deleted) : c.line),
                 background(c.frame), folder_field!(t, f))
  # A field of one end of the size or the time, with its name before it
  end_field(words, f) = Row(width(grow=grow), padding(4px, 2px), child_gap=8px, Alignment.Center,
                            Box(fixed(52px), label(words, 12px, color=unread_field(t, f) ? git_colour(:deleted) : c.dim)), field(f))
  # It's clipped, so a long line can't make the menu wider than its frame
  help = Row(width(grow=grow), padding(8px, 4px), clip=true, Box(label(field_help(key), 11px, color=c.dim)))
  fewer = if key == :name
    (section("NAME HAS"), Box(width(grow=grow), padding(4px, 2px), field(:name)))
  elseif key == :kind
    counts, icons = Dict{String,Int}(), Dict{String,String}()
    for it in t.items
      counts[it.kind] = get(counts, it.kind, 0) + 1
      get!(() -> entry_icon(it.object), icons, it.kind)
    end
    rows = map(sort!(collect(keys(counts)), by=lowercase)) do kind
      r = folder_part!(() -> FolderKind(table=t, kind=kind), t, (:kind, kind))
      r.count, r.icon = counts[kind], icons[kind]
      r
    end
    (section("SHOW"), rows...)
  elseif key == :size
    (section("SIZE"), end_field("At least", :size_lo), end_field("At most", :size_hi), help)
  else
    (section("MODIFIED"), end_field("From", :when_lo), end_field("To", :when_hi), help)
  end
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Column menu",
    Column(width(grow=grow), Alignment.Start,
      section("SORT"), folder_part!(() -> FolderOrder(table=t, desc=false), t, (:order, false)),
      folder_part!(() -> FolderOrder(table=t, desc=true), t, (:order, true)),
      Box(width(grow=grow), height(13px), Alignment.Center, Box(width(grow=grow), height(1px), background(c.rule))),
      fewer...))
end

# The menu sees a key before its text field does. Return keeps what's typed, and esc puts back what the column had.
onkey(m::FolderMenu, ev::KeyPress{Keys.enter}) = unmodified(ev) ? close_folder_menu!(m.table) : nothing
onkey(m::FolderMenu, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  t = m.table
  t.asking == :none || put_back!(t, t.asking, t.was)
  close_folder_menu!(t)
end
# Tab goes from one end of the size or the time to the other
onkey(m::FolderMenu, ev::KeyPress{Keys.tab}) = begin
  t = m.table
  fields = field_keys(t.asking)
  length(fields) == 2 || return nothing
  w = ev.window
  at = findfirst(f -> haskey(t.fields, f) && w.focus === t.fields[f], fields)
  next = folder_field!(t, fields[at == 1 ? 2 : 1])
  next.cursor, next.anchor = length(next.text), 0   # what it has is chosen, so typing takes its place
  focus(next)
  handled
end

describe(r::FolderOrder) = begin
  t, c = r.table, found_colours()
  on = t.sort == t.asking && t.desc == r.desc
  Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(on || ishovered(r) ? c.pick : c.frame),
    Icon(r.desc ? "chevron-down" : "chevron-up", size=10px, color=on ? c.ink : c.dim),
    label(order_words(t.asking, r.desc), 13px, color=on ? c.ink : c.dim, weight=on ? "Semibold" : ""))
end

cursor(::FolderOrder) = :hand
onmouse(::FolderOrder, ::MouseMove) = handled
onkey(r::FolderOrder, ::KeyPress{Keys.mouse_left}) = (t = r.table; t.asking == :none || ((t.sort, t.desc) = (t.asking, r.desc)); handled)

describe(r::FolderKind) = begin
  t, c = r.table, found_colours()
  on = r.kind in t.kinds
  Row(width(grow=grow), height(26px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(ishovered(r) ? c.pick : c.frame),
    Box(fixed(10px), (on ? (Icon("check", size=10px, color=c.ink),) : ())...),
    Box(fixed(14px), Icon(r.icon, size=13px, color=on || isempty(t.kinds) ? c.ink : c.dim)),
    Box(width(grow=grow), Alignment.Start, clip_x=true,
      label(r.kind, 13px, color=on || isempty(t.kinds) ? c.ink : c.dim, weight=on ? "Semibold" : "")),
    Box(label(commas(r.count), 11px, color=c.dim)))
end

cursor(::FolderKind) = :hand
onmouse(::FolderKind, ::MouseMove) = handled
# A click ticks the kind, or takes the tick away. With every kind ticked, or none, every row shows.
onkey(r::FolderKind, ::KeyPress{Keys.mouse_left}) = begin
  t = r.table
  r.kind in t.kinds ? delete!(t.kinds, r.kind) : push!(t.kinds, r.kind)
  length(t.kinds) == length(unique(it.kind for it in t.items)) && empty!(t.kinds)
  handled
end

# --- the rows ---

"The row of the table `t` for the folder or the file `it`: its icon, which shows its kind, its name, its size, and when it changed"
folder_item_row(t::FolderTable, e, it::FolderItem) = begin
  o = it.object
  name = entry_name(o)
  page_row!(t, (:item, it.path), _ -> (open_folder!(e, it.path); nothing),
    Box(width(FOLDER_ICON_W), Icon(entry_icon(o), size=14px, color=colours.dim)),
    Row(width(grow=grow), height(grow=grow), clip=true, child_gap=8px,
      Box(label(name, 13px, color=ishidden(name) || ignored_shown(e, it.path) ? colours.dim : colours.ink)), entry_marks(e, o)...),
    # Each at the right of its column, under its heading. A Box of their own keeps the words from filling the column.
    Box(fixed(FOLDER_COL_W), Alignment.End, Box(label(size_cell(it), 12px, color=colours.faint))),
    Box(fixed(FOLDER_COL_W), Alignment.End, Box(label(!it.known ? "Reading…" : it.when > 0 ? Git.ago(it.when) : "", 12px, color=colours.faint))))
end

"What the table says of the size of `it`: nothing for a folder that Ladder doesn't read, like ~/Library"
size_cell(it::FolderItem) = it.sized ? Zips.size_words(it.size) : Folders.unread(it.path) ? "" : "Reading…"

describe(t::FolderTable) = begin
  e = editor(t)
  folder_items!(e, t)
  redraw_in!(e, 1)   # the folder is read again each second, so a new file gets its row
  isempty(t.items) && return Column(width(grow=grow), Alignment.Start, name="Table", page_note("This folder is empty."))
  items = folder_filtered(t, folder_sorted(t))
  shown = t.every ? items : items[1:min(FOLDER_ROWS_FIRST, end)]
  more = length(items) - length(shown)
  # The headings are over the rows' icons and words
  heads = Row(width(grow=grow), height(24px), padding(8px, 0px), child_gap=8px, name="Headings",
    (folder_head(t, k) for k in FOLDER_COLUMNS)...)
  # While a menu shows fewer rows, a line says how many show, with a button that shows them all again
  fewer = narrowed(t) ?
    (Row(width(grow=grow), height(PAGE_ROW_H), padding(8px, 0px), child_gap=10px, Alignment.Center, name="Shown",
       Box(label(isempty(items) ? "Nothing in this folder matches" : "$(commas(length(items))) of $(commas(length(t.items))) show", 12px, color=colours.dim)),
       page_button!(t, :clear, _ -> (clear_filters!(t); nothing), icon="funnel", words="Show All")),) : ()
  Column(width(grow=grow), Alignment.Start, name="Table",
    heads, Box(width(grow=grow), height(1px), background(colours.line)),
    fewer...,
    [folder_item_row(t, e, it) for it in shown]...,
    (more > 0 ? (Row(padding(8px, 8px), page_button!(t, :items, _ -> (t.every = true; nothing), words="Show $more More")),) :
     t.every && length(items) > FOLDER_ROWS_FIRST ? (Row(padding(8px, 8px), page_button!(t, :items, _ -> (t.every = false; nothing), words="Show Fewer")),) : ())...)
end

cursor(::FolderTable) = :arrow

# A right-click on a row shows the menu of its folder or file. The name is typed where it shows in the sidebar, so the menu has no Rename.
onkey(t::FolderTable, ev::KeyPress{Keys.mouse_right}) = begin
  for (key, r) in t.rows
    (key isa Tuple && key[1] == :item && ishovered(r)) || continue
    path = key[2]
    file_menu!(editor(t), ev.window, path; items=filter(!=("Rename"), file_menu(path)))
    return handled
  end
  nothing
end

# Under the folder's name is what it holds, as a repository's page has it
describe(v::FolderPage) = begin
  e = editor(v)
  t = folder_table!(e, v, v.path)
  folder_items!(e, t)
  Column(width(grow=grow), Alignment.Start, name="Folder",
    page_title("folder", basename(v.path), holds_words(t)),
    t)
end

cursor(::FolderPage) = :arrow

"A favourite folder, for a command to take"
struct Favourite
  path::String
end
choices_for(::Type{Favourite}, e) = [Favourite(p) for p in Folders.favourites()]
worded(f::Favourite) = basename(f.path)
sidenote(f::Favourite) = tilde(dirname(f.path))
runs_at_once(::Val{:go_to_favourite}) = true

"Open one of your favourite folders in the page"
go_to_favourite!(e, favourite::Favourite) = (open_folder!(e, favourite.path); nothing)
"Make the folder `d` a favourite, so Go To Favourite goes to it"
add_to_favourites!(d::AbstractDirectory) = (Folders.favourite!(path_of(d)); nothing)
"Take the folder `d` off the favourites"
remove_from_favourites!(d::AbstractDirectory) = (Folders.unfavourite!(path_of(d)); nothing)
add_command!(go_to_favourite!, title="Go to one of the folders that you made a favourite")
add_command!(add_to_favourites!; group="The file or the folder in focus", title="Make the folder a favourite, so Go To Favourite goes to it")
add_command!(remove_from_favourites!; group="The file or the folder in focus", title="Take the folder off the favourites, so Go To Favourite doesn't list it")
