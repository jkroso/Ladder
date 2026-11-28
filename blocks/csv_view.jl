# A CSV file in the page: a table that you change
#
# A CSV file that the sidebar opens shows as a table as wide as the window has
# room for. Each column is as wide as its first rows need, up to `WIDEST_CELL`,
# and a table that's narrower than the window shares the rest of the room
# among its columns. A table that's wider than the window scrolls sideways: two
# fingers that move sideways on the trackpad, or the wheel with ⇧ held. Text
# that's too long for its column stops with an …. The row of headings stays at
# the top of the window while the rows scroll under it. A thin line with round
# corners goes round the table.
#
# Ladder works out what kind of thing each column holds: numbers, days, yes
# or no, or text. csv.jl says how. The heading of a column of numbers, days or
# yes or no has a small picture of its kind before its name.
#
# A click on a heading opens a menu. Its first part puts the rows in the order
# of that column, and a click on the order that the rows have now puts them
# back in the file's order. Each kind has its own order: text goes A to Z,
# with the numbers in it by their size, so Item 2 comes before Item 10.
# Numbers go by their size, days by their time, the oldest first or the
# newest, and yes before no or no before yes. Empty cells go last in both
# orders, and so do cells that aren't of the column's kind.
#
# The menu's second part shows fewer rows. A column of numbers or days has two
# fields, and only the rows from the first to the second show: 10 and 50, or
# 1 Nov and today. Either can be empty. A day is typed as a field of a form
# reads it, like 2026-11-25, 25 Nov, yesterday or fri. A column with no more
# than `FEW_VALUES` different values lists them, each with how many rows have
# it. A click on a value ticks it, and only the rows with a ticked value show.
# Any other column of text has a field, and only the rows with its words in
# that column show. Return keeps what the fields hold, and esc puts back what
# they held before. The heading of a column that shows fewer rows is in the
# accent colour, with a funnel beside it. The top bar says how big the file is, when
# it last changed, and how many rows show. It's there and not over the table,
# so the words stay in sight while the table scrolls. The table starts nearer
# the top bar than the text of a page does, so the window shows more rows.
#
# Ladder reads `FILE_ROWS` rows of the file at most. When the file changes on
# the disk and its headings stay the same, the table keeps its order and what
# it shows.
#
# The table is the file at its highest level. ⌘E, or the slider in the top
# bar, goes down to the file's text, and the slider goes on down to its bytes
# in hexadecimal and its bits. Back at the table, the rows are in the order
# and show what they did. See "the slider of the levels".

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe detach! window_of focus handled carry! onblur
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor hittest rect popup! close_popup! MouseScroll
@use "github.com/jkroso/UI.jl/Interface/window" system_menu
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./pictures" natural
@use "./markdown" Kind words
@use "./sheet" parts known shown
@use "./merge" changes
@use "./chart" => Charts
@use "./csv" => Csvs
@use "./forms" => Forms
@use Colors: RGBA
@use Dates: Dates, Day
@use "./base" exports...
@use "./sketch_view" exports...

export FILE_ROWS, FILE_BYTES, HEAD_H, CELL_PAD, SHEET_LINE, SHEET_ROUND, SHEET_ABOVE, WIDEST_CELL,
       FEW_VALUES, SHEET_MENU_W, SHEET_KEY, DASH_W, FileSheet, cell_face, file_sheet, KIND_ROWS,
       spread!, ranged, worth, typed_worth, values_of, in_order, sheet_rows!, sheet_top, shown_cell,
       sheet_part!, current_sheet!, new_row, blank_row, sheet_view, cell_layer, SheetFrame,
       SheetHead, SheetMenu, SheetOrder, SheetValue, SheetAction, KIND_ICONS, ORDER_WORDS,
       close_sheet_menu!, table_edits, table_look, table_level!, sheet_edits, sheet_whole,
       empty_row, edit_cell!, end_edit!, stop_edit!, put_cell!, table_edit!, add_line!, delete_row!,
       each_row!, add_column!, delete_column!, show_cell!, cell_at, ROW_MENU, next_cell, edit_on!,
       CellField, MenuField, SheetField, CELL_TEXT, MENU_TEXT, field_editor!, cell_field!,
       cell_text, fill_cell!, fill_field!, field_type, follow_cell!, CELL_COMMANDS, cell_key!,
       COLUMN_ACTIONS, ACTION_WORDS, live, CellStyle, celltext

const FILE_ROWS = 100_000       # the most rows of a CSV file that the page reads
const FILE_BYTES = 40_000_000   # and the most of the file that it reads
const HEAD_H = 30px             # how tall the row of headings is
const CELL_PAD = 10px           # on each side of a cell's text
const SHEET_LINE = 1px          # the line round the table
const SHEET_ROUND = 6px         # how round the corners of that line are
const SHEET_ABOVE = 4px         # the room over the table. With LIVE_GAP, the table is 12px under the top bar.
const WIDEST_CELL = 360px       # the widest a column is before the columns share the room that's left
const FEW_VALUES = 20           # a column with no more different values than this lists them in its menu
const SHEET_MENU_W = 240px
const SHEET_KEY = :sheet_column
const DASH_W = 10px             # the room for the dash between the two fields of a column's menu

"The table of a CSV file that the page shows, and what's chosen for it"
mutable struct FileSheet
  table::Csvs.Table
  at::Any                          # what it was read from: the version of the page's lines, or when the file last changed
  natural::Vector{px}              # how wide each column needs to be, up to WIDEST_CELL
  widths::Vector{px}               # how wide each column is in the page
  wide::px                         # how wide the page was when the widths were worked out
  sort::Any                        # the column that the rows are in the order of and :asc or :desc, or nothing for the file's order
  filters::Dict{Int,String}        # the words that a column's cells must have, for each column that has some
  picks::Dict{Int,Set{String}}     # the values that show, for each column whose menu lists its values and has some ticked
  sought::Any                      # what the rows were last found for: the order, and what each column keeps
  found::Vector{Int}               # the rows that show, in the order that they show in. Row 1 is the headings.
  values::Dict{Int,Any}            # each column's values with how many rows have each, or nothing when it has more than FEW_VALUES
  asking::Int                      # the column whose menu is open, or 0
  was::Any                         # what that column kept when its menu opened, which esc puts back
  field::Any                       # the text field of the menu
  parts::Dict{Any,Any}             # the headings and the lines of the menu, kept between frames
  across::px                       # how far the table is scrolled to the right
  cut::Dict{Tuple{Int,Int},Tuple{px,String}}   # the text of a cell as it shows, with the width that it was cut short for
  kinds::Vector{Symbol}            # what each column holds: :number, :day, :yesno or :text. See csv.jl.
  firstday::Vector{Bool}           # for each column, whether its days that are written with numbers, like 3/4/2026, have the day first
  bounds::Dict{Int,Tuple{String,String}}   # the first and the last value that show, as they're typed, for each column of numbers or days that has some
  upto::Any                        # the menu's second field, for the last value that shows
  lines::Vector{UnitRange{Int}}    # the lines of the page that each row is on, when the page changes the file. Row 1 is the headings.
  mark::Char                       # the mark between two cells
  editing::Any                     # the row and the column of the cell that's being changed, or nothing. See "changing a CSV file".
  input::Any                       # the field that changes it
end

"The font of a cell, or of a heading with `bold`"
cell_face(bold=false) = Face(SANS, bold ? "Semibold" : "", 12px, colours.ink, false)

"""
The table in the CSV file at `path`, read for the page: from the lines `lines`
of the page, when the page changes the file, or else from the file. `at` says
which: see `FileSheet`. When `old` is the table that the file had before and
it has as many columns, the new one keeps its order, what it shows, and how far
it's scrolled. When it has as many rows as before, they show in the same
places, so a row that you change stays where it is.
"""
file_sheet(path, old, at, lines=nothing) = begin
  t, places = lines === nothing ? (Csvs.load(path, most=FILE_ROWS, upto=FILE_BYTES), UnitRange{Int}[]) : Csvs.table(lines, most=FILE_ROWS)
  # A CSV file with nothing in it yet has one heading with no name, for you to name
  lines !== nothing && isempty(t.rows) && (t = Csvs.Table([[""]], [false], false, ""))
  rows = t.rows
  head, plain = cell_face(true), cell_face()
  # A heading has room for the picture of its column's kind and the arrow of its order beside it
  need(r, c) = measure(r == 1 ? head : plain, first(celltext(rows[r][c]), 300)) + (r == 1 ? 28px : 0px)
  natural = [clamp(maximum(r -> need(r, c), 1:min(length(rows), 200)), 24px, WIDEST_CELL) + 2CELL_PAD for c in eachindex(t.numbers)]
  # A few thousand rows are enough to say what kind of thing each column holds
  sample = @view rows[1:min(length(rows), KIND_ROWS)]
  mark = isempty(places) ? (lowercase(splitext(path)[2]) == ".tsv" ? '\t' : ',') : Csvs.mark(lines[first(places[1])])
  s = FileSheet(t, at, natural, copy(natural), 0px, nothing, Dict{Int,String}(), Dict{Int,Set{String}}(), nothing, Int[],
                Dict{Int,Any}(), 0, nothing, nothing, Dict{Any,Any}(), 0px, Dict{Tuple{Int,Int},Tuple{px,String}}(),
                Csvs.kinds(sample), Csvs.dayfirsts(sample), Dict{Int,Tuple{String,String}}(), nothing, places, mark, nothing, nothing)
  if old isa FileSheet
    # The fields of the menus and of a cell are kept, and so is the cell that's being changed
    s.field, s.upto, s.input, s.editing = old.field, old.upto, old.input, old.editing
    if !isempty(rows) && !isempty(old.table.rows) && length(old.table.rows[1]) == length(rows[1])
      s.sort, s.filters, s.picks, s.bounds, s.across = old.sort, old.filters, old.picks, old.bounds, old.across
      s.asking, s.was, s.parts = old.asking, old.was, old.parts
      # The rows stay in their places
      length(rows) == length(old.table.rows) && ((s.sought, s.found) = (old.sought, old.found))
    end
    # The columns share the page's width as they did, so a cell can be shown before the next frame
    old.wide > 0px && spread!(s, old.wide)
  end
  s
end

const KIND_ROWS = 2000   # how many rows of a table say what kind of thing each column holds

"Share the page's width `wide` among the columns of `s`. A table that's narrower than the page grows, each column by its share."
spread!(s::FileSheet, wide) = begin
  s.wide == wide && return s
  total = sum(s.natural, init=0px)
  s.widths = total < wide ? s.natural .* (num(wide) / num(total)) : copy(s.natural)
  s.wide = wide
  empty!(s.cut)
  s
end

"True when column `c` of `s` shows only some rows"
narrowed(s::FileSheet, c::Int) = haskey(s.filters, c) || haskey(s.picks, c) || haskey(s.bounds, c)
"True when some column of `s` shows only some rows"
narrowed(s::FileSheet) = !isempty(s.filters) || !isempty(s.picks) || !isempty(s.bounds)

"Keep only the rows that have `words` in column `column`. No words takes that away."
keep!(s::FileSheet, column::Int, words) = begin
  words = String(strip(words))
  isempty(words) ? delete!(s.filters, column) : (s.filters[column] = words)
  s
end

"True when column `c` of `s` holds numbers or days, so its menu has two fields that show the rows from one value to another"
ranged(s::FileSheet, c::Int) = s.kinds[c] in (:number, :day)

"Keep only the rows of column `c` from the value typed as `from` to the one typed as `to`. With both fields empty, every row shows."
hold!(s::FileSheet, c::Int, from, to) = begin
  from, to = String(strip(from)), String(strip(to))
  isempty(from) && isempty(to) ? delete!(s.bounds, c) : (s.bounds[c] = (from, to))
  s
end

"""
What the cell `text` of column `c` of `s` comes to, to put it in order and to
keep it between two values: a number, a time, or true for yes. It's nothing in
a column of text, and for a cell that isn't of its column's kind.
"""
worth(s::FileSheet, c::Int, text::AbstractString) = begin
  kind = s.kinds[c]
  kind == :number ? (n = Charts.number(text); n === nothing ? nothing : n[1]) :
  kind == :day ? Csvs.when(text, dayfirst=s.firstday[c]) :
  kind == :yesno ? Csvs.yesno(text) : nothing
end

"""
The value that `text`, typed in a field of the menu of column `c`, names: a
number, or the first moment of a day, or with `last` its last moment. A day is
read as a field of a form reads it, like 25 Nov, yesterday or fri, or as a cell
is read. It's nothing when the text names no value, so the field keeps no row
out while you type in it. A number alone names no day there, since it's the
start of a day that you're typing.
"""
typed_worth(s::FileSheet, c::Int, text::AbstractString; last=false) = begin
  isempty(strip(text)) && return nothing
  s.kinds[c] == :number && return (n = Charts.number(text); n === nothing ? nothing : n[1])
  occursin(r"^\s*\+?\d{1,4}\s*$", text) && return nothing
  day = Forms.day(text)
  day === nothing || return last ? Dates.DateTime(day + Day(1)) - Dates.Millisecond(1) : Dates.DateTime(day)
  Csvs.when(text, dayfirst=s.firstday[c])
end

"""
The values of column `c` of `s`, each with how many rows have it, in the order
that the column puts them in. It's nothing when the column has more than
`FEW_VALUES` different values.
"""
values_of(s::FileSheet, c::Int) = get!(s.values, c) do
  counts = Dict{String,Int}()
  for r in 2:length(s.table.rows)
    value = s.table.rows[r][c]
    counts[value] = get(counts, value, 0) + 1
    length(counts) > FEW_VALUES && return nothing
  end
  [(value, counts[value]) for value in in_order(s, collect(keys(counts)), c, :asc, value -> value)]
end

"""
The text of the least and of the greatest value in column `c` of `s`, as the
file writes them, or "" when it has none. The fields of the column's menu show
them before you type.
"""
extent(s::FileSheet, c::Int) = begin
  lo = hi = nothing
  for r in 2:length(s.table.rows)
    text = s.table.rows[r][c]
    v = worth(s, c, text)
    v === nothing && continue
    (lo === nothing || v < lo[1]) && (lo = (v, text))
    (hi === nothing || v > hi[1]) && (hi = (v, text))
  end
  (lo === nothing ? "" : lo[2], hi === nothing ? "" : hi[2])
end

"""
`items` in the order of column `c` of `s`, with `way` :asc or :desc.
`cell(item)` is the text of the item's cell. Text goes A to Z, or Z to A, with
the numbers in it by their size. Numbers go by their size, days by their time,
and yes before no. A cell that isn't of its column's kind goes after the ones
that are, A to Z. Empty cells go last whichever way.
"""
in_order(s::FileSheet, items, c, way, cell) = begin
  rev = way == :desc
  blank = [x for x in items if isempty(cell(x))]
  full = [x for x in items if !isempty(cell(x))]
  text(x) = (x, Csvs.sortkey(cell(x)))
  kind = s.kinds[c]
  kind == :text && return [first.(sort!(map(text, full), by=last, rev=rev)); blank]
  found = [(x, worth(s, c, cell(x))) for x in full]
  # Yes is false here, so it comes first
  known = sort!([(x, kind == :yesno ? !v : v) for (x, v) in found if v !== nothing], by=last, rev=rev)
  others = sort!([text(x) for (x, v) in found if v === nothing], by=last, rev=rev)
  [first.(known); first.(others); blank]
end

"""
The rows of `s` that show, in the order that they show in: the rows that have
each column's words in that column, one of its ticked values, and a value
between its two values, in the order of the column that's chosen. When they
change, a page that was scrolled down the table goes back to the top of the
table.
"""
sheet_rows!(e, s::FileSheet) = begin
  key = (s.sort, copy(s.filters), Dict(c => copy(p) for (c, p) in s.picks), copy(s.bounds))
  key == s.sought && return s.found
  rows = s.table.rows
  words = [(c, lowercase(w)) for (c, w) in s.filters]
  ranges = [(c, typed_worth(s, c, a), typed_worth(s, c, z, last=true)) for (c, (a, z)) in s.bounds]
  between(r, (c, lo, hi)) = (lo === nothing && hi === nothing) ||
    (v = worth(s, c, rows[r][c]); v !== nothing && (lo === nothing || v >= lo) && (hi === nothing || v <= hi))
  keep = [r for r in 2:length(rows) if all(((c, w),) -> occursin(w, lowercase(rows[r][c])), words) &&
                                       all(((c, p),) -> rows[r][c] in p, s.picks) && all(t -> between(r, t), ranges)]
  s.sort === nothing || (keep = in_order(s, keep, s.sort[1], s.sort[2], r -> rows[r][s.sort[1]]))
  s.sought === nothing || (e.scroll.offset = min(e.scroll.offset, sheet_top()))
  s.sought, s.found = key, keep
  keep
end

"How far the top of the table of a CSV file is under the top of the page"
sheet_top() = SHEET_ABOVE + LIVE_GAP + SHEET_LINE

"The text of row `r`, column `c` of `s`, as it shows in a column that's `room` wide: on one line, and cut short with an … when it's too long"
shown_cell(s::FileSheet, r, c, room, face=cell_face(r == 1)) = begin
  kept = get(s.cut, (r, c), nothing)
  kept !== nothing && kept[1] == room && return kept[2]
  length(s.cut) > 50_000 && empty!(s.cut)
  text = first(celltext(s.table.rows[r][c]), 300)
  while measure(face, text) > room && length(text) > 1
    text = first(text, max(1, floor(Int, (length(text) - 1) * num(room) / num(measure(face, text))) - 1)) * "…"
  end
  s.cut[(r, c)] = (room, text)
  text
end

"A node of the headings or of the menu of the table of `v`, kept between frames"
sheet_part!(make, v, key) = get!(() -> own!(v, make()), (v.table::FileSheet).parts, key)

"""
The table of the CSV file that `v` shows, as the file is now. A file that the
page changes is read from the page's lines, each time they change, and any
other from the file, each time it changes.
"""
current_sheet!(v, e) = begin
  b = e.buf
  lines = b.path == v.path && table_text(b)
  at = lines ? (:lines, b.version) : (:file, mtime(v.path))
  (v.table isa FileSheet && v.table.at == at) || (v.table = file_sheet(v.path, v.table, at, lines ? b.lines : nothing))
  v.table::FileSheet
end

"True when a new row is being written after the last row of `s`"
new_row(s::FileSheet) = s.editing !== nothing && s.editing[1] > length(s.table.rows)

"True when the table of `v` shows an empty row after its last, to write a new row in: it has only its headings, and it changes its file"
blank_row(v, s::FileSheet) = new_row(s) || (length(s.table.rows) == 1 && sheet_edits(v) && sheet_whole(v))

"""
The table of the CSV file that `v` shows, or nothing when the file has no
table. It's as wide as the page and as tall as all the rows that show, but only
the rows in the window are made. The headings stay at the top of the window
while the page is scrolled down the table. `note(words)` adds to what the top
bar says of the file.
"""
sheet_view(v, e, note) = begin
  s = current_sheet!(v, e)
  isempty(s.table.problem) || return nothing
  # What the fields of a heading's menu hold is what its column keeps, as it's typed
  c = s.asking
  if c > 0 && s.field isa MenuField
    ranged(s, c) ? hold!(s, c, cell_text(s.field), s.upto isa MenuField ? cell_text(s.upto) : "") :
      values_of(s, c) === nothing && keep!(s, c, cell_text(s.field))
  end
  found = sheet_rows!(e, s)
  n, total = length(found), length(s.table.rows) - 1
  held = s.table.more ? "the first $(commas(total)) rows" : "$(commas(total)) row$(total == 1 ? "" : "s")"
  note(n < total || narrowed(s) ? "$(commas(n)) of $held" : held)
  wide = e.width - 2SHEET_LINE   # the room inside the line round the table
  spread!(s, wide)
  room = sum(s.widths, init=0px)
  s.across = clamp(s.across, 0px, max(0px, room - wide))
  _, h = window_size(e)
  # A new row that's being written shows after the others, and so does an empty row under headings with no rows
  shown = n + (blank_row(v, s) ? 1 : 0)
  into = e.scroll.offset - sheet_top()   # how far the top of the window is past the top of the table
  lo = clamp(floor(Int, (into - HEAD_H) / ROW_H) - 4, 0, shown)
  hi = min(shown, lo + ceil(Int, h / ROW_H) + 8)
  plain = cell_face()
  cell(r, c, w) = Row(fixed(w), height(ROW_H), padding(CELL_PAD, 0px), Alignment.Center, clip=true,
                      label(r <= length(s.table.rows) ? shown_cell(s, r, c, w - 2CELL_PAD, plain) : "", 12px))
  row(k) = (r = k <= n ? found[k] : length(s.table.rows) + 1;
    Row(fixed(room), height(ROW_H), Alignment.Start, background(iseven(k) ? colours.stripe : clear),
      [cell(r, c, w) for (c, w) in enumerate(s.widths)]...))
  none = shown == 0 && total > 0 ? (Box(fixed(min(room, wide)), height(2ROW_H), label("No row has what the headings keep.", 12px, color=colours.dim)),) : ()
  rows = Column(fixed(room), Alignment.Start, spacer(HEAD_H + ROW_H * lo), [row(k) for k in lo+1:hi]..., spacer(ROW_H * (shown - hi)), none...)
  heads = Row(fixed(room), height(HEAD_H), Alignment.Start, background(colours.head),
    [sheet_part!(() -> SheetHead(of=v, column=c), v, (:head, c)) for c in eachindex(s.widths)]...)
  # The headings are over the rows, and move down with the window until the rows end
  stick = clamp(into, 0px, ROW_H * max(shown - 1, 0))
  # The field of the cell that's being changed lies over its cell, and over the rows under it when its text needs them
  field = s.editing === nothing ? nothing : cell_layer(v, s, found, stick)
  over_rows = field === nothing || s.editing[1] == 1 ? () : (field,)
  over_heads = field === nothing || s.editing[1] != 1 ? () : (field,)
  table = Stack(fixed(room), Alignment.Start, rows, over_rows..., Box(Alignment.Start, offset_y=stick, heads), over_heads...)
  frame = sheet_part!(() -> SheetFrame(of=v), v, :frame)
  frame.wide, frame.inside = e.width, Box(Alignment.Start, offset_x=-s.across, table)
  frame
end

"The field of the cell of `s` that's being changed, where the cell is in the table, or nothing when the cell doesn't show"
cell_layer(v, s::FileSheet, found, stick) = begin
  r, c = s.editing
  k = r == 1 ? 0 : r > length(s.table.rows) ? length(found) + 1 : findfirst(==(r), found)
  (k === nothing || !(s.input isa CellField)) && return nothing
  f = s.input::CellField
  f.wide, f.heading = s.widths[c], r == 1
  f.icon = r == 1 ? get(KIND_ICONS, s.kinds[c], "") : ""
  Box(Alignment.Start, offset_x=sum(s.widths[1:c-1], init=0px), offset_y=r == 1 ? stick : HEAD_H + ROW_H * (k - 1), f)
end

"The line round a CSV file's table, which has round corners. The table scrolls sideways inside it."
@def mutable struct SheetFrame <: SemanticUI
  of::Any = nothing       # the FileView
  wide::px = 0px          # how wide it is, with its line
  inside::Any = nothing   # what's in it in this frame: the table, as far to the left as it's scrolled
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was drawn in the window, to find the cell under the mouse
end

describe(f::SheetFrame) = Row(fixed(f.wide), Alignment.Start, padding(SHEET_LINE), clip_x=true, name="Table frame", detach!(f.inside))
cursor(::SheetFrame) = :arrow

# The rows of the table have square ends, so the page's colour goes over what of them is outside the
# round corners. The line goes round on top of that.
draw(ctx, size, ui::ConcreteRect, f::SheetFrame) = begin
  f.rect = (ui.left, ui.top, ui.width, ui.height)
  x, y, w, h, r = num(ui.left), num(ui.top), num(ui.width), num(ui.height), num(SHEET_ROUND)
  shape = Skia.sk_path_new()
  rect = Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h)))
  Skia.sk_path_add_rounded_rect(shape, rect, Float32(r), Float32(r), Skia.SK_PATH_DIRECTION_CW)
  Skia.sk_canvas_save(ctx)
  Skia.sk_canvas_clip_path_with_operation(ctx, shape, Skia.SK_CLIP_OP_DIFFERENCE, true)
  foreach(((cx, cy),) -> round_box(ctx, cx, cy, r, r, 0; fill=colours.bg), ((x, y), (x + w - r, y), (x, y + h - r), (x + w - r, y + h - r)))
  Skia.sk_canvas_restore(ctx)
  Skia.sk_path_delete(shape)
  line = num(SHEET_LINE)
  round_box(ctx, x + line / 2, y + line / 2, w - line, h - line, r - line / 2; line=colours.line, wide=line)
  nothing
end

# Two fingers that move sideways, or the wheel with ⇧ held, scroll a wide table sideways. Their move up or down scrolls the page.
onscroll(v::FileView, ev::MouseScroll) = begin
  s = v.table
  (s isa FileSheet && ev.delta[1] != 0px) || return nothing
  s.across = clamp(s.across - 30ev.delta[1], 0px, max(0px, sum(s.widths, init=0px) - s.wide))
  ev.delta[2] == 0px ? handled : nothing
end

"The heading of a column of a CSV file's table. A click on it opens the column's menu."
@def mutable struct SheetHead <: SemanticUI
  of::Any = nothing   # the FileView
  column::Int = 1
end
"The menu of a column of a CSV file's table: its two orders, what shows fewer rows, and what changes the column"
@def mutable struct SheetMenu <: SemanticUI
  of::Any = nothing
  column::Int = 1
end
"One of the two orders in the menu of a column of a CSV file's table"
@def mutable struct SheetOrder <: SemanticUI
  of::Any = nothing
  way::Symbol = :asc
end
"A value in the menu of a column of a CSV file's table. A click ticks it, or takes the tick away."
@def mutable struct SheetValue <: SemanticUI
  of::Any = nothing
  value::String = ""
  count::Int = 0
end
"A line in the menu of a column that changes the file: Rename Column, Add Column or Delete Column. See \"changing a CSV file\"."
@def mutable struct SheetAction <: SemanticUI
  of::Any = nothing
  what::Symbol = :rename
end

"The picture before the name of a column that holds numbers, days, or yes or no. A column of text has none."
const KIND_ICONS = Dict(:number => "hash", :day => "calendar3", :yesno => "check2-square")
"The words of the two orders of a column of each kind"
const ORDER_WORDS = Dict(:text => ("A–Z", "Z–A"), :number => ("Smallest first", "Largest first"),
                         :day => ("Oldest first", "Newest first"), :yesno => ("Yes first", "No first"))

describe(h::SheetHead) = begin
  s = h.of.table::FileSheet
  c = h.column
  w = s.widths[c]
  way = s.sort !== nothing && s.sort[1] == c ? s.sort[2] : nothing
  lit = ishovered(h) || s.asking == c
  fewer = narrowed(s, c)
  colour = fewer ? colours.accent : colours.ink
  kind = get(KIND_ICONS, s.kinds[c], nothing)
  icon = kind === nothing ? () : (Icon(kind, size=10px, color=colours.faint),)
  # The funnel of a column that shows fewer rows, and the arrow of its order. With neither, the mouse over the heading shows that it opens.
  marks = ((fewer ? (Icon("funnel-fill", size=9px, color=colours.accent),) : ())...,
           (way !== nothing ? (Icon(way == :asc ? "chevron-up" : "chevron-down", size=9px, color=colours.ink),) :
            lit && !fewer ? (Icon("chevron-down", size=9px, color=colours.faint),) : ())...)
  room = w - 2CELL_PAD - 13px * (length(marks) + length(icon))
  Row(fixed(w), height(HEAD_H), padding(CELL_PAD, 0px), child_gap=4px, Alignment.Center, clip=true,
      background(lit ? colours.hover : clear),
    icon..., Box(label(shown_cell(s, 1, c, max(room, 12px)), 12px, color=colour, weight="Semibold")), marks...)
end

cursor(::SheetHead) = :hand
onmouse(::SheetHead, ::MouseMove) = handled

onkey(h::SheetHead, ev::KeyPress{Keys.mouse_left}) = begin
  v = h.of
  # A cell that's being changed keeps what was typed in it
  stop_edit!(v)
  s = v.table::FileSheet
  c = h.column
  listed = values_of(s, c) !== nothing
  s.asking = c
  # What esc puts back: the column's words, its ticked values and its two values
  s.was = (get(s.filters, c, nothing), haskey(s.picks, c) ? copy(s.picks[c]) : nothing, get(s.bounds, c, nothing))
  s.field isa MenuField || (s.field = field_editor!(own!(v, MenuField(of=v))))
  s.upto isa MenuField || (s.upto = field_editor!(own!(v, MenuField(of=v))))
  # The fields start with what the column keeps. Those of a column of numbers or days show its least and greatest value while they're empty.
  if ranged(s, c)
    least, most = extent(s, c)
    from, to = get(s.bounds, c, ("", ""))
    fill_field!(s.field, from, least)
    fill_field!(s.upto, to, most)
  elseif !listed
    fill_field!(s.field, get(s.filters, c, ""), "Contains…")
  end
  menu = sheet_part!(() -> SheetMenu(of=v), v, :menu)
  menu.column = c
  e = editor(v)
  # A click outside the menu closes it and keeps what's chosen
  popup!(ev.window, menu, anchor=h, placement=:below, gap=4px, width=SHEET_MENU_W, key=SHEET_KEY,
         onclose=() -> (v.table isa FileSheet && (v.table.asking = 0); focus(e)), theme=component_theme(e.zoom))
  (ranged(s, c) || !listed) && focus(s.field)
  handled
end

"Close the menu of the table of `v`, and give the keyboard back to the page"
close_sheet_menu!(v) = begin
  v.table isa FileSheet && (v.table.asking = 0)
  w = window_of(v)
  w === nothing || close_popup!(w, SHEET_KEY)
  focus(editor(v))
  handled
end

describe(m::SheetMenu) = begin
  v, c = m.of, found_colours()
  s = v.table::FileSheet
  col = m.column
  section(words) = Row(width(grow=grow), height(22px), padding(8px, 0px), Alignment.Center, label(words, 10px, color=c.dim, weight="Semibold"))
  order(way) = sheet_part!(() -> SheetOrder(of=v, way=way), v, (:sort, way))
  values = values_of(s, col)
  value(text, count) = (r = sheet_part!(() -> SheetValue(of=v, value=text), v, (:value, col, text)); r.count = count; r)
  rule() = Box(width(grow=grow), height(13px), Alignment.Center, Box(width(grow=grow), height(1px), background(c.rule)))
  # The fields are as wide as the menu has room for: one, or two with a dash between them
  room = SHEET_MENU_W - 2(6px + 1px) - 2 * 4px
  half = (room - 2 * 6px - DASH_W) / 2
  ranged(s, col) && ((s.field.wide, s.upto.wide) = (half, half))
  # A column of numbers or days shows the rows between two values, and one with few values lists them
  between = ranged(s, col) ? (section("BETWEEN"), Row(width(grow=grow), padding(4px, 2px), child_gap=6px, Alignment.Center,
                                                      s.field, Box(fixed(DASH_W), Alignment.Center, label("–", 13px, color=c.dim)), s.upto)) : ()
  listed = values === nothing ? () : (section("SHOW"), [value(text, count) for (text, count) in values]...)
  contains = !ranged(s, col) && values === nothing ? (s.field.wide = room; (section("FILTER FOR"), Box(width(grow=grow), padding(4px, 2px), s.field))) : ()
  # A file that the page changes can have its columns changed here
  changes = sheet_edits(v) && sheet_whole(v) ?
    (rule(), [sheet_part!(() -> SheetAction(of=v, what=a), v, (:action, a)) for a in COLUMN_ACTIONS if a != :delete || length(s.widths) > 1]...) : ()
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Column menu",
    Column(width(grow=grow), Alignment.Start,
      section("SORT"), order(:asc), order(:desc), rule(), between..., listed..., contains..., changes...))
end

# The menu sees a key before its text fields do. Return keeps what's chosen, and esc puts back what the column kept before.
onkey(m::SheetMenu, ev::KeyPress{Keys.enter}) = unmodified(ev) ? close_sheet_menu!(m.of) : nothing
onkey(m::SheetMenu, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  s = m.of.table::FileSheet
  c = m.column
  words, ticked, range = s.was
  words === nothing ? delete!(s.filters, c) : (s.filters[c] = words)
  ticked === nothing ? delete!(s.picks, c) : (s.picks[c] = ticked)
  range === nothing ? delete!(s.bounds, c) : (s.bounds[c] = range)
  close_sheet_menu!(m.of)
end
# Tab goes between the two fields of a column of numbers or days
onkey(m::SheetMenu, ev::KeyPress{Keys.tab}) = begin
  s = m.of.table::FileSheet
  (ranged(s, m.column) && s.upto isa MenuField) || return handled
  focus(ev.window.focus === s.field.sub ? s.upto : s.field)
  handled
end

describe(r::SheetOrder) = begin
  s, c = r.of.table::FileSheet, found_colours()
  on = s.sort == (s.asking, r.way)
  kind = s.asking > 0 ? s.kinds[s.asking] : :text
  words = ORDER_WORDS[kind][r.way == :asc ? 1 : 2]
  Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(on || ishovered(r) ? c.pick : c.frame),
    Icon(r.way == :asc ? "chevron-up" : "chevron-down", size=10px, color=on ? c.ink : c.dim),
    label(words, 13px, color=on ? c.ink : c.dim, weight=on ? "Semibold" : ""))
end

cursor(::SheetOrder) = :hand
onmouse(::SheetOrder, ::MouseMove) = handled
# A click on the order that the rows have puts them back in the file's order
onkey(r::SheetOrder, ::KeyPress{Keys.mouse_left}) = (s = r.of.table::FileSheet; s.sort = s.sort == (s.asking, r.way) ? nothing : (s.asking, r.way); handled)

describe(r::SheetValue) = begin
  s, c = r.of.table::FileSheet, found_colours()
  ticked = get(s.picks, s.asking, nothing)
  on = ticked !== nothing && r.value in ticked
  Row(width(grow=grow), height(26px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(ishovered(r) ? c.pick : c.frame),
    Box(fixed(10px), (on ? (Icon("check", size=10px, color=c.ink),) : ())...),
    Box(width(grow=grow), Alignment.Start, clip_x=true,
      label(isempty(r.value) ? "Empty" : r.value, 13px, color=isempty(r.value) || !(on || ticked === nothing) ? c.dim : c.ink, weight=on ? "Semibold" : "")),
    Box(label(commas(r.count), 11px, color=c.dim)))
end

cursor(::SheetValue) = :hand
onmouse(::SheetValue, ::MouseMove) = handled
# A click ticks the value, or takes the tick away. With every value ticked, or none, every row shows.
onkey(r::SheetValue, ::KeyPress{Keys.mouse_left}) = begin
  s = r.of.table::FileSheet
  c = s.asking
  ticked = get!(Set{String}, s.picks, c)
  r.value in ticked ? delete!(ticked, r.value) : push!(ticked, r.value)
  (isempty(ticked) || length(ticked) == length(values_of(s, c))) && delete!(s.picks, c)
  handled
end

# --- changing a CSV file ----------------------------------------------------------------------
#
# A CSV file that the page has whole, no longer than `MOST_PAGE`, is yours to
# change. Its text is the page's lines, as a Markdown file's text is, and the
# table is made from them. So a change goes in the page's lines, ⌘Z takes it
# back, and ⌘S writes the file, as does leaving the window when the settings
# say so. A longer file, and one that your Mac marks as read-only, is only
# shown, with the lock in the top bar.
#
#   - A click on a cell opens a field over it, with the cell's text selected,
#     so what you type takes its place. Return keeps what you typed and goes to
#     the cell below, and ⇧Return to the cell above. ↓ and ↑ do the same. Tab
#     goes to the cell on the right, and from the end of a row to the start of
#     the next. ⇧Tab goes back. Esc puts back what the cell held. A click
#     anywhere else keeps what you typed.
#   - Return in the last row opens a new row under it, when the table shows
#     every row of the file in the file's order. The row goes in the file once
#     you type in it, so a new row that you leave empty doesn't.
#   - A right-click on a row offers Add Row Above, Add Row Below and Delete Row.
#   - A heading's menu has Rename Column, which opens a field over the heading,
#     Add Column, which adds an empty column after it and opens a field for its
#     name, and Delete Column.
#   - A change writes only the cell that changed. The rest of the row stays as
#     the file has it, quotes and all, and a cell that needs quotes gets them.
#   - A row that you change stays where it is, though the table is in the order
#     of a column or shows fewer rows. The rows are put in order and found
#     again when you change the order or what a column keeps.
#   - ⌘E goes down to the file's text, which you can change too. The bytes in
#     hexadecimal and the bits are the file's, so a change that isn't saved is
#     written before they show.

"""
True when the CSV or TSV file at `path` is one that its page changes: a file
of text no longer than `MOST_PAGE`, so the page has all of it, or an empty file.
"""
table_edits(path) = lowercase(splitext(path)[2]) in TABLES && isfile(path) && (n = filesize(path); n == 0 || n <= MOST_PAGE && text_file(path))

"True when `b` shows the table or the text of a CSV file that its page changes"
table_text(b::Buffer) = b.view in (:file, :text) && table_edits(b.path)

"The buffer of a CSV file that the page changes. Its lines are the file's text, and with `view` :file it shows the table, or with :text the text."
table_look(path, view::Symbol=:file) = begin
  lines = text(path)
  b = Buffer(path=path, lines=lines, disk=copy(lines), told=copy(lines), view=view, fixed=protected(path))
  b.sent = b.told   # nothing has changed from outside yet
  b
end

"Show the table of the page's CSV file, with `view` :file, or its text, with :text. They're the same lines, so a change that isn't saved stays."
table_level!(e, view::Symbol) = begin
  b = e.buf
  v = get(e.nodes, (:fileview, b.path), nothing)
  v isa FileView && end_edit!(v)
  saved = b.saved == b.version
  b.view = view
  b.about = ""   # the table says again what it says of the file
  b.caret = b.anchor = (1, 0)
  b.version = (stamp[] += 1)
  saved && (b.saved = b.version)
  e.scroll.offset = 0px
  focus(e)
  e
end

"True when the table of `v` changes its file: the page shows the table of a CSV file that the page changes"
sheet_edits(v) = (b = editor(v).buf; b.path == v.path && b.view == :file && table_text(b) && !b.fixed && v.table isa FileSheet)

"True when the table of `v` has every row of its file, so a row can go after the last and a column can be added or taken away"
sheet_whole(v) = v.table isa FileSheet && !v.table.table.more

"The text of a row with nothing in its cells, for a table `wide` columns wide. A row of one column has a cell in quotes, since an empty line is no row."
empty_row(s::FileSheet, wide=length(s.widths)) = wide <= 1 ? "\"\"" : string(s.mark)^(wide - 1)

"""
Open the field that changes the cell in row `r`, column `c` of the table of
`v`, with the cell's text in it, selected. Row 1 is the headings, and a row
after the last is a new row. A cell that was being changed keeps what was typed.
"""
edit_cell!(v, r, c) = begin
  end_edit!(v)
  sheet_edits(v) || return handled
  s = v.table::FileSheet
  f = cell_field!(v)
  fill_cell!(f, r <= length(s.table.rows) ? s.table.rows[r][c] : "")
  s.editing = (r, c)
  show_cell!(v, r, c)
  focus(f)
  handled
end

"Close the field of the cell of `v` that's being changed. With `keep`, what was typed goes in the cell. It doesn't move the keyboard: see `stop_edit!`."
end_edit!(v; keep=true) = begin
  s = v.table
  (s isa FileSheet && s.editing !== nothing) || return v
  r, c = s.editing
  s.editing = nothing
  keep && s.input isa CellField && put_cell!(v, r, c, cell_text(s.input))
  v
end

"Close the field of the cell of `v` that's being changed, keep what was typed, and give the keyboard back to the page"
stop_edit!(v; keep=true) = begin
  s = v.table
  (s isa FileSheet && s.editing !== nothing) || return v
  end_edit!(v; keep)
  focus(editor(v))
  v
end

"""
Write `text` in the cell in row `r`, column `c` of the table of `v`, in the
page's lines. A row after the last is a new row, which goes in the file when
`text` has something in it.
"""
put_cell!(v, r, c, text) = begin
  sheet_edits(v) || return v
  e = editor(v)
  b = e.buf
  s = current_sheet!(v, e)
  text = String(strip(text))
  if r <= length(s.lines)
    s.table.rows[r][c] == text && return v
    at = s.lines[r]
    table_edit!(b, (first(at), 0), (last(at), length(b.lines[last(at)])), Csvs.with_cell(join(b.lines[at], "\n"), s.mark, c, text))
  else
    (isempty(text) || !sheet_whole(v)) && return v
    # A file with nothing in it gets a row of headings with no names first, when the new row isn't the headings
    if isempty(s.lines) && r > 1
      add_line!(b, 0, empty_row(s))
      s = current_sheet!(v, e)
    end
    add_line!(b, isempty(s.lines) ? 0 : last(s.lines[end]), Csvs.with_cell(empty_row(s), s.mark, c, text))
  end
  current_sheet!(v, e)
  v
end

"Put `text` in place of the text of `b` from `lo` to `hi`, for the table of a CSV file, so that ⌘Z puts it back"
table_edit!(b::Buffer, lo, hi, text) = (table_text(b) && !b.fixed && replace_text!(b, lo, hi, text); b)

"Put the line `text` after line `i` of `b`, or before the first with `i` 0. A last line with nothing on it, after the file's last line break, stays last."
add_line!(b::Buffer, i, text) = i < length(b.lines) ? table_edit!(b, (i + 1, 0), (i + 1, 0), text * "\n") :
                                                      table_edit!(b, (i, length(b.lines[i])), (i, length(b.lines[i])), "\n" * text)

"Take away row `r` of the table of `v`, and the lines that it's on"
delete_row!(v, r) = begin
  sheet_edits(v) || return v
  e = editor(v)
  b = e.buf
  s = current_sheet!(v, e)
  2 <= r <= length(s.lines) || return v
  at = s.lines[r]
  n = length(b.lines)
  last(at) < n ? table_edit!(b, (first(at), 0), (last(at) + 1, 0), "") :
  first(at) > 1 ? table_edit!(b, (first(at) - 1, length(b.lines[first(at)-1])), (n, length(b.lines[n])), "") :
                  table_edit!(b, (1, 0), (n, length(b.lines[n])), "")
  current_sheet!(v, e)
  v
end

"Add a row with nothing in it over row `r` of the table of `v`, or under it with `below`, and open the field of its first cell"
add_row!(v, r, below) = begin
  sheet_edits(v) || return v
  e = editor(v)
  b = e.buf
  s = current_sheet!(v, e)
  1 <= r <= length(s.lines) || return v
  add_line!(b, below ? last(s.lines[r]) : first(s.lines[r]) - 1, empty_row(s))
  sheet_rows!(e, current_sheet!(v, e))
  edit_cell!(v, below ? r + 1 : r, 1)
end

"Give the text of each row of the table of `v` to `f`, and put what it gives in its place. It's one change, which ⌘Z takes back."
each_row!(v, f) = begin
  (sheet_edits(v) && sheet_whole(v)) || return v
  e = editor(v)
  b = e.buf
  s = current_sheet!(v, e)
  isempty(s.lines) && return v
  out = copy(b.lines)
  # From the last row up, so that the lines of the rows above stay where they are
  for at in reverse(s.lines)
    splice!(out, at, String.(split(f(join(b.lines[at], "\n")), '\n')))
  end
  n = length(b.lines)
  table_edit!(b, (1, 0), (n, length(b.lines[n])), join(out, "\n"))
  current_sheet!(v, e)
  v
end

"Add a column with no name after column `c` of the table of `v`, and open the field of its heading"
add_column!(v, c) = begin
  mark = (v.table::FileSheet).mark
  each_row!(v, row -> Csvs.with_new_cell(row, mark, c, ""))
  sheet_rows!(editor(v), v.table::FileSheet)
  edit_cell!(v, 1, c + 1)
end

"Take away column `c` of the table of `v`"
delete_column!(v, c) = (mark = (v.table::FileSheet).mark; each_row!(v, row -> Csvs.without_cell(row, mark, c)))

"""
Scroll the page, and the table sideways, so that the cell in row `r`, column
`c` of the table of `v` shows in the window. The headings always show.
"""
show_cell!(v, r, c) = begin
  e = editor(v)
  s = v.table::FileSheet
  left = sum(s.widths[1:c-1], init=0px)
  s.across = max(0px, min(left, max(s.across, left + s.widths[c] - s.wide)))
  r == 1 && return v
  k = something(findfirst(==(r), s.found), length(s.found) + 1)
  top = sheet_top() + HEAD_H + ROW_H * (k - 1)   # from the top of the page
  _, h = window_size(e)
  # The row shows under the headings, which stay at the top of the window, and over the window's foot
  e.scroll.offset = max(0px, min(max(e.scroll.offset, TOPBAR_H + top + ROW_H - h), top - HEAD_H))
  v
end

"""
The row and the column of the cell of the table of `v` at (`x`, `y`) in the
window, or nothing. The row is the table's: row 1 is the headings, and a row
after the last is the new row that's being written.
"""
cell_at(v, x, y) = begin
  s = v.table::FileSheet
  f = get(s.parts, :frame, nothing)
  f === nothing && return nothing
  left, top = f.rect[1] + SHEET_LINE, f.rect[2] + SHEET_LINE
  k = floor(Int, (y - top - HEAD_H) / ROW_H) + 1
  n = length(s.found)
  r = 1 <= k <= n ? s.found[k] : k == n + 1 && blank_row(v, s) ? length(s.table.rows) + 1 : nothing
  r === nothing && return nothing
  at, edge = x - left + s.across, 0px
  for (c, w) in enumerate(s.widths)
    edge += w
    at < edge && return (r, c)
  end
  nothing
end

# A click on a cell opens its field. A table that's only shown has no use for it.
onkey(f::SheetFrame, ev::KeyPress{Keys.mouse_left}) = begin
  v = f.of
  sheet_edits(v) || return nothing
  at = cell_at(v, ev.window.mouse[1], ev.window.mouse[2])
  at === nothing ? (stop_edit!(v); handled) : edit_cell!(v, at...)
end

"The menu of a row of a CSV file's table"
const ROW_MENU = ["Add Row Above", "Add Row Below", "-", "Delete Row"]

onkey(f::SheetFrame, ev::KeyPress{Keys.mouse_right}) = begin
  v = f.of
  sheet_edits(v) || return nothing
  at = cell_at(v, ev.window.mouse[1], ev.window.mouse[2])
  stop_edit!(v)
  (at === nothing || !(2 <= at[1] <= length((v.table::FileSheet).table.rows))) && return handled
  r = at[1]
  act(i...) = (item = get(ROW_MENU, last(i), "");
               item == "Delete Row" ? delete_row!(v, r) : item in ("Add Row Above", "Add Row Below") ? add_row!(v, r, item == "Add Row Below") : nothing)
  system_menu(ev.window, ROW_MENU, act) || drawn_menu!(ev.window, ROW_MENU, act)
  handled
end

"""
The cell that the field of the table of `v` goes to from row `r`, column `c`,
when it goes `way`: :up, :down, :left or :right. Up and down go by the rows as
they show. Right goes on from the end of a row to the start of the next, and
left back from the start of a row. Down from the last row is a new row, when
the table shows every row of the file in its order. It's nothing past the
headings, and after a new row that was left empty.
"""
next_cell(v, r, c, way) = begin
  s = v.table::FileSheet
  found = sheet_rows!(editor(v), s)
  wide = length(s.widths)
  way == :right && c < wide && return (r, c + 1)
  way == :left && c > 1 && return (r, c - 1)
  order = [1; found]
  k = findfirst(==(r), order)
  k === nothing && return nothing
  step = way in (:down, :right) ? 1 : -1
  col = way == :right ? 1 : way == :left ? wide : c
  1 <= k + step <= length(order) && return (order[k+step], col)
  step == 1 && sheet_whole(v) && s.sort === nothing && !narrowed(s) && return (length(s.table.rows) + 1, col)
  nothing
end

"Keep what's typed in the cell of the table of `v` that's being changed, and open the field of the cell `way` from it, if there's one"
edit_on!(v, way) = begin
  s = v.table
  (s isa FileSheet && s.editing !== nothing) || return nothing
  r, c = s.editing
  end_edit!(v)
  next = next_cell(v, r, c, way)
  next === nothing ? focus(editor(v)) : edit_cell!(v, next...)
  handled
end

# --- the field of a cell ------------------------------------------------------------------------
#
# The field that a cell of a CSV file's table opens is Ladder's own editor of
# text, as a field of a SolidCraft design is: see "the fields of a SolidCraft
# design". So its caret, what's selected, and the keys that move and change
# the text look and work as they do on a page. Its text is in the table's
# font, at the table's size, so it doesn't change when the field opens. It's
# plain text, with no colours of code and no markup of Markdown. Text that's
# longer than the column goes on to the next line, and the field grows down
# over the rows under it.
#
# Return, Tab, ↑, ↓ and esc are the table's: see "changing a CSV file". ⌘Z
# takes back what was typed in the field, and when nothing was, the field
# closes and the page takes back its last change. A command for the page or
# the window, like ⌘S, puts what was typed in the cell first.

"The field of the cell of a CSV file's table that's being changed: see \"the field of a cell\""
@def mutable struct CellField <: SemanticUI
  sub::Any = nothing      # the editor of its text
  of::Any = nothing       # the FileView
  wide::px = 0px          # how wide its column is
  heading::Bool = false   # it's the field of a heading, whose text is semibold
  icon::String = ""       # the picture of the kind of its column, before the name of a heading, or ""
  took::Bool = false      # the editor of its text took the last key, which goes no further: see `cell_key!`
end

"""
A field in the menu of a column of a CSV file's table: the words that the
column's rows have, or the first or the last value that shows. It's Ladder's
own editor of text, as the field of a cell is. While it's empty, it says what
it's for.
"""
@def mutable struct MenuField <: SemanticUI
  sub::Any = nothing          # the editor of its text
  of::Any = nothing           # the FileView
  wide::px = 0px              # how wide the menu has room for it to be
  placeholder::String = ""    # what it says while it has no text
  took::Bool = false          # the editor of its text took the last key, which goes no further: see `cell_key!`
end

"A field of a CSV file's table: the field of a cell, or a field in the menu of a column"
const SheetField = Union{CellField,MenuField}

const CELL_TEXT = 12px     # how big the text of a table's cells is: see `cell_face`
const MENU_TEXT = 13px     # and the text of the menu of a column

"Give the field `f` an editor of its own for its text, whose keys go to `cell_key!` before it does what it does with them"
field_editor!(f::SheetField) = (f.sub = small_editor(f, Buffer(lines=[""], view=:code, lang=CELL_LANG)); f)

"The field of the cells of the table of `v`, made the first time that it's asked for"
cell_field!(v) = begin
  s = v.table::FileSheet
  s.input isa CellField && return s.input
  s.input = field_editor!(own!(sheet_part!(() -> SheetFrame(of=v), v, :frame), CellField(of=v)))
end

"The text in the field `f`"
cell_text(f::SheetField) = join(f.sub.buf.lines, '\n')

"Put `text` in the field `f`, all of it selected. ⌘Z in the field doesn't take it back."
fill_cell!(f::SheetField, text) = begin
  b = f.sub.buf
  edit!(b, (1, 0), line_end(b, length(b.lines)), String(text))
  empty!(b.undo)
  empty!(b.redo)
  b.anchor, b.caret = (1, 0), line_end(b, length(b.lines))
  f
end

"Put `text` in the field `f` of a column's menu, with the caret after it, and `words` in it while it's empty"
fill_field!(f::MenuField, text, words) = (fill_cell!(f, text); b = f.sub.buf; b.anchor = b.caret; f.placeholder = words; f)

"How big the text of the field `f` is, and how heavy"
field_type(f::CellField) = (CELL_TEXT, f.heading ? 600 : 400)
field_type(::MenuField) = (MENU_TEXT, 400)

"The size and the font that the text of a cell's field was last laid out at"
@def mutable struct CellStyle
  key::Union{Nothing,Tuple} = nothing   # the field's zoom, font and weight, or nothing before its first layout
end

"Give the editor of the field `f` the colours and the keys of the page, and the font and the size of the table's text"
follow_cell!(f::SheetField) = begin
  sub = f.sub
  follow_host!(sub, editor(f.of))
  sub.numbers = sub.shade = false
  sub.guide = 0
  sub.wrap = true
  size, weight = field_type(f)
  sub.font, sub.look, sub.weight = SANS, :own, weight
  sub.zoom = num(size) / num(TEXT_SIZE)
  # Text that was laid out at another size or weight is laid out again
  key = (sub.zoom, sub.font, sub.weight)
  style = state_of(sub, CellStyle)
  style.key == key || (style.key = key; empty!(sub.flows))
  f
end

"""
Lay out the text of the field `f` for `room`, and give what shows it, with how
tall its text is and how tall its first line is. Its editor's text is made in
the theme at its usual size, so it's as big as it was laid out. While a field
of the menu is empty, the words that say what it's for show where its text goes.
"""
field_text(f::SheetField, room) = begin
  sub = f.sub
  follow_cell!(f)
  w = window_of(f)
  b = sub.buf
  # The selection shows only while the field has the keyboard
  (w !== nothing && w.focus === sub) || (b.anchor = b.caret)
  layout!(sub, room)
  tall = isempty(sub.layout) ? first(field_type(f)) * 1.5 : lowest(sub, sub.layout)
  one = !isempty(sub.layout) && sub.layout[1].content isa Flow && !isempty(sub.layout[1].content.lines) ? sub.layout[1].content.lines[1].high : tall
  shown = with_theme(unscaled(component_theme(editor(f.of).zoom))) do
    doc = Row(fixed(room), height(tall), Alignment.Start, node!(Document, sub, :document))
    words = f isa MenuField && b.lines == [""] ? f.placeholder : ""
    isempty(words) ? doc : Stack(fixed(room), height(tall), Alignment.Start,
                                 Row(fixed(room), height(tall), Alignment.Center, clip_x=true, label(words, MENU_TEXT, color=colours.dim)), doc)
  end
  shown, tall, one
end

# The text in the field is where it was in the cell: its first line is in the middle of the cell's height, as the cell's
# text is, and a heading's name is after the picture of its column's kind. Text of more lines makes the field taller.
# A Row puts the editor's text at its top, so the room over the text is said, inside the line round the field.
describe(f::CellField) = begin
  room = max(f.wide - 2CELL_PAD - (isempty(f.icon) ? 0px : 14px), 12px)
  text, tall, one = field_text(f, room)
  short = f.heading ? HEAD_H : ROW_H
  over = (short - one) / 2 - 2px
  icon = isempty(f.icon) ? () : (Box(fixed(10px), height(one), Alignment.Center, Icon(f.icon, size=10px, color=colours.faint)),)
  Row(fixed(f.wide), height(max(short, tall + short - one)), padding(over, CELL_PAD - 2px, 0px, CELL_PAD - 2px), child_gap=4px,
      Alignment.Start, background(colours.bg), border(2px, :solid, colours.accent), name="Cell field", icon..., text)
end

describe(f::MenuField) = begin
  c = found_colours()
  room = max(f.wide - 2 * 8px - 2px, 12px)
  text, tall, one = field_text(f, room)
  Row(fixed(f.wide), height(max(28px, tall + 28px - one)), padding((28px - one) / 2 - 1px, 8px, 0px, 8px), radius(6px), Alignment.Start,
      border(1px, :solid, c.line), background(c.frame), name="Menu field", text)
end

# A click on the field, past its text, puts the caret in the text. A click on the text was the text's, and comes here after.
onkey(f::SheetField, ev::KeyPress{Keys.mouse_left}) = (hittest(ev.window) === f && (focus(f); press!(f.sub, ev.window.mouse)); handled)
cursor(::SheetField) = :ibeam
# A key that the editor of its text took goes no further. The editor gives no `handled`, and the page would take it too, as ⌘Z.
onkey(f::SheetField, ::KeyPress) = f.took ? (f.took = false; handled) : nothing
focus(f::SheetField) = focus(f.sub)

# A click anywhere else keeps what was typed in the cell
onblur(f::CellField, from) = begin
  s = f.of.table
  (from === f.sub && s isa FileSheet && s.editing !== nothing) || return nothing
  end_edit!(f.of)
  handled
end

"The commands that the field of a cell does as the page does them. Any other is the page's or the window's."
const CELL_COMMANDS = (:undo, :redo, :cut, :copy, :paste, :paste_copy, :select_all)

# A key in the editor of the field's text is the field's first: see `cell_key!`. The field notes a key that its editor
# takes, so that the key goes no further.
owner_key!(f::SheetField, e, w, K, command, select) = begin
  done = cell_key!(f, e, w, K, command)
  f.took = done === :text
  done
end

"""
What a key does in the field of a cell, before its editor does what it does
with a key: `handled`, nothing when the key goes on to the page and then the
window, or :text when the editor does what it does with the key. See "the
field of a cell".
"""
cell_key!(f::CellField, e, w, K, command) = begin
  v = f.of
  K == Keys.enter && unmodified(w) && return edit_on!(v, :down)
  K == Keys.enter && only_held(w, Keys.shft) && return edit_on!(v, :up)
  K == Keys.tab && unmodified(w) && return edit_on!(v, :right)
  K == Keys.tab && only_held(w, Keys.shft) && return edit_on!(v, :left)
  K in (Keys.up, Keys.down) && unmodified(w) && return edit_on!(v, K == Keys.up ? :up : :down)
  K == Keys.escape && unmodified(w) && return (stop_edit!(v, keep=false); handled)
  command === nothing && return :text
  b = e.buf
  # ⌘Z takes back the page's last change when the field has nothing of its own to take back
  if command in (:undo, :redo) && isempty(command == :undo ? b.undo : b.redo)
    stop_edit!(v, keep=false)
    return nothing
  end
  (command in CELL_COMMANDS || command_kind(command) in (:type, :move)) && return :text
  stop_edit!(v)
  nothing
end

"""
What a key does in a field of the menu of a column: see `cell_key!`. Return,
esc and Tab are the menu's, which sees them first. ⌘Z takes back what was
typed, and does nothing more while the menu shows. A command for the page or
the window goes on to them.
"""
cell_key!(f::MenuField, e, w, K, command) = begin
  command === nothing && return :text
  command in (:undo, :redo) && return isempty(command == :undo ? e.buf.undo : e.buf.redo) ? handled : :text
  (command in CELL_COMMANDS || command_kind(command) in (:type, :move)) ? :text : nothing
end

"The menu items that change a column, in their order"
const COLUMN_ACTIONS = (:rename, :add, :delete)
const ACTION_WORDS = Dict(:rename => ("pencil", "Rename Column"), :add => ("plus-lg", "Add Column"), :delete => ("trash3", "Delete Column"))

describe(a::SheetAction) = begin
  c = found_colours()
  icon, words = ACTION_WORDS[a.what]
  Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(ishovered(a) ? c.pick : c.frame),
    Icon(icon, size=10px, color=c.dim), label(words, 13px, color=c.ink))
end

cursor(::SheetAction) = :hand
onmouse(::SheetAction, ::MouseMove) = handled
onkey(a::SheetAction, ::KeyPress{Keys.mouse_left}) = begin
  v = a.of
  c = (v.table::FileSheet).asking
  close_sheet_menu!(v)
  c > 0 || return handled
  a.what == :rename ? edit_cell!(v, 1, c) : a.what == :add ? add_column!(v, c) : delete_column!(v, c)
  handled
end

"What the live block with this code shows"
live(e, code::String) = begin
  key = (:live, e.buf.path, code)
  node = get!(e.nodes, key) do
    shown = Shown(value=evaluate(e, code))
    shown.value isa SemanticUI && own!(shown, shown.value)
    old = pop!(e.nodes, (:replaced, key), nothing)
    old isa Shown && carry!(shown.value, old.value)
    shown
  end
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

BLOCKS[LIVE] = LiveBlock
block_name(::Type{LiveBlock}) = "Live Block"
block_icon(::Type{LiveBlock}) = "bounding-box"
block_insert(::Type{LiveBlock}) = ("Live Block", ["```$LIVE", "", "```"], (2, 0))
block_is_code(::Type{LiveBlock}) = true
block_html(::Type{LiveBlock}, e, lang::AbstractString, s::Int, t::Int) = nothing
block_outline(::Type{LiveBlock}, lines::Vector{String}, i::Int, close::Int) =
  ((name, icon) = component(view(lines, i+1:close-1)); Entry(i, 7, name, icon, min(close + 1, length(lines))))
block_layout(::Type{LiveBlock}, e, lang::AbstractString, i::Int, n::Int) = begin
  b = e.buf; ks = kinds(b); t = codeblock(b, i)[2]
  !incode(b, i) && t > i && ks[t].kind == Kind.fence && ks[t].level == 1 ? (t, live(e, join(b.lines[i+1:t-1], "\n"))) : nothing
end

"The text of a cell as the table shows it. A line break in a cell is a space."
celltext(cell) = occursin('\n', cell) ? replace(cell, r"\s*\n\s*" => " ") : cell
