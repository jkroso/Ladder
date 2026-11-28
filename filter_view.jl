# The view of a `filter` block: the rows of a table that meet its conditions
#
# A code block in the language `filter` shows only the rows of a table that
# meet its conditions: the rows of a CSV file, of a JSON file or of a table of
# the page. filter.jl says how the block is written. The top of the block
# names where the rows come from and says how many show. Its Save button
# writes the rows that show into a new file.
#
# Under the top, each condition is a chip with an × that takes it away. The
# field after them adds one: type `Total > 100` and press Return. A chip whose
# condition the filter can't use is in the accent colour, and the line under
# the chips says why. When the block hides some columns, a chip says how many,
# and its × shows them again.
#
# The rows show as a table. A click on a heading opens a menu, as it does in a
# CSV file's table. It puts the rows in the order of that column, ticks the
# values to show, or keeps only the rows that have some words in that column.
# It can also hide the column. Each choice goes into the block's lines, so the
# file holds the whole filter, and ⌘Z takes it back. Esc in the menu puts back
# the lines that the block had when the menu opened.
#
# The table shows its first FILTER_ROWS rows. A line under them says how many
# more there are, and a click on it shows them all. Only the rows in the window
# are made, so a long table costs no more to draw than a short one. A table
# that's wider than the page scrolls sideways: two fingers that move sideways,
# or the wheel with ⇧ held.
#
# A filter reads a table of the page that's above it. A chart can draw the rows
# that a filter shows: they're a table of the page, under the heading that the
# block is under. Save writes the rows that show to a file that you choose: a
# CSV file, or a JSON file that has each thing as the file had it, when the
# rows came from a JSON file. Ladder reads a file once, and again when it
# changes on the disk.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe detach! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! redraw_in! rect popup! close_popup! MouseScroll
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" problem
@use "./pictures" natural
@use "./html" escape
@use "./markdown" words
@use "./sheet" shown
@use "./csv" => Csvs
@use "./filter" => Filters
@use "./save" => Saves
@use "github.com/jkroso/JSON.jl" JSONObject JSONNumber json_value write_json
@use Colors: @colorant_str, RGBA
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./csv_view" exports...
@use "./json_view" exports...
@use "./load_view" exports...
@use "./rows_from" exports...
@use "./page_extras" save_panel

export ADD_W, CHIP_H, ChipCross, FILTER_COLUMNS, FILTER_KEY, FILTER_ROWS, FilterChip, FilterFound,
       FilterGrid, FilterHead, FilterMenu, FilterMore, FilterPick, chip_problem, chip_width,
       close_filter_menu!, filter_adder, filter_cell, filter_chips, filter_field, filter_files,
       filter_found, filter_grid, filter_html, filter_page_table, filter_shown!, filter_subset,
       filter_table, filter_values, filter_widths!, json_cell, json_cells!, json_filter_rows,
       json_first_list, json_line, json_table, json_things, no_rows, page_filter_rows, rows_to_show,
       save_name, save_rows

const FILTER_ROWS = 30              # the rows that a filter shows until you ask for the rest
const FILTER_COLUMNS = 60           # the most columns that the things of a JSON file make
const FILTER_KEY = :filter_column   # the key of the menu of a filter's column
const CHIP_H = 24px                 # how tall a condition is, at the top of a filter
const ADD_W = 230px                 # how wide the field is that adds a condition
push!(BLOCK_ICONS, "funnel", "x", "download", "eye-slash", "plus")

"No rows, and why"
no_rows(problem; name="", path="") = FilterRows(Vector{String}[], Bool[], Any[], name, path, false, problem)

# What's known of each file that a filter reads: when it last changed, how big it was then, and its rows, for each `at`
const filter_files = Dict{Tuple{String,String},Tuple{Float64,Int,FilterRows}}()

"True when the file at `path` is one that a filter reads: a CSV file, a TSV file or a JSON file"
isfilterable(path) = (x = lowercase(splitext(path)[2]); x in TABLES || x in JSONS)

"""
The rows of the file at `path`, for a filter. `at` says where the list is in
a JSON file, and `name` is what the block calls the file. The file is read
once, and again when it changes on the disk.
"""
filter_file(path, at; name=basename(path)) = begin
  isfile(path) || return no_rows("Ladder can't find the file $name.", name=name, path=path)
  s = stat(path)
  when, size = Float64(s.mtime), Int(s.size)
  json = lowercase(splitext(path)[2]) in JSONS
  key = (path, json ? String(strip(at)) : "")
  kept = get(filter_files, key, nothing)
  kept !== nothing && kept[1] == when && kept[2] == size && return kept[3]
  table_reads[] += 1   # what's worked out from the file is worked out again
  rows = json ? json_filter_rows(path, at; name) : begin
    t = Csvs.load(path, most=FILE_ROWS, upto=FILE_BYTES)
    isempty(t.problem) ? FilterRows(t.rows, t.numbers, Any[], name, path, t.more, "") : no_rows(t.problem, name=name, path=path)
  end
  filter_files[key] = (when, size, rows)
  rows
end

"The rows of the JSON file at `path`: a row for each thing in the list that `at` names"
json_filter_rows(path, at; name=basename(path)) = begin
  filesize(path) <= MOST_JSON || return no_rows("The file $name is too big for Ladder to read.", name=name, path=path)
  root = try
    json_value(read(path))
  catch
    return no_rows("Ladder can't read $name as JSON.", name=name, path=path)
  end
  things, problem = json_things(root, at)
  isempty(problem) || return no_rows(problem, name=name, path=path)
  isempty(things) && return no_rows("The list in $name has nothing in it.", name=name, path=path)
  rows = json_table(things)
  FilterRows(rows, Csvs.numbers(rows), things, name, path, false, "")
end

"""
The first list in `root` whose items are mostly objects, looking at the top
level first and then a level further in each time. Without one, it's the first
list, or `root` itself when it holds no list.
"""
json_first_list(root) = begin
  root isa Vector{Any} && return root
  level, first = Any[root], nothing
  while !isempty(level)
    for v in level
      v isa Vector{Any} || continue
      first === nothing && (first = v)
      !isempty(v) && 2count(x -> x isa JSONObject, v) > length(v) && return v
    end
    level = Any[x for v in level if json_holder(v) for (_, x) in json_items(v) if json_holder(x)]
  end
  something(first, root)
end

"""
The things that a filter of a JSON file has a row for, and why there are none
or "". They're the items of the list that `at` names, as keys with dots
between them, like data.orders. A number in `at` is the place of an item in its
list, counting from 0. Without `at`, they're the items of `json_first_list`.
An object whose values are all objects has a row for each of them, with a
column called key for its key. Any other object is one row.
"""
json_things(root, at) = begin
  at = String(strip(at))
  value = isempty(at) ? json_first_list(root) : root
  for step in (isempty(at) ? String[] : strip.(split(at, '.')))
    if value isa JSONObject && (k = findfirst(==(step), value.keys)) !== nothing
      value = value.values[k]
    elseif value isa Vector{Any} && (n = tryparse(Int, step)) !== nothing && 0 <= n < length(value)
      value = value[n+1]
    else
      return Any[], "The file has nothing at “$(at)”."
    end
  end
  value isa Vector{Any} && return value, ""
  if value isa JSONObject && !isempty(value.values) && all(x -> x isa JSONObject, value.values)
    return Any[JSONObject(["key"; o.keys], Any[k; o.values]) for (k, o) in zip(value.keys, value.values)], ""
  end
  Any[value], ""
end

"""
The rows of a table of `things`: the names of the columns, then a row for each
thing. Each key of a thing is a column, and so is each key of an object in it,
with a dot between the keys: customer.name. A thing that isn't an object has a
column called value.
"""
json_table(things) = begin
  names, place = String[], Dict{String,Int}()
  cells = [json_cells!(Dict{Int,String}(), names, place, "", x, 0) for x in things]
  rows = Vector{String}[names]
  append!(rows, [[get(row, c, "") for c in eachindex(names)] for row in cells])
end

"Put the cells of `x` into `row`, with the name of each one's column after `prefix`"
json_cells!(row, names, place, prefix, x, depth) = begin
  if x isa JSONObject && !isempty(x.keys) && depth < 4
    for (k, v) in zip(x.keys, x.values)
      json_cells!(row, names, place, isempty(prefix) ? k : prefix * "." * k, v, depth + 1)
    end
    return row
  end
  name = isempty(prefix) ? "value" : prefix
  c = get(place, name, 0)
  if c == 0
    length(names) >= FILTER_COLUMNS && return row
    push!(names, name)
    c = place[name] = length(names)
  end
  row[c] = json_cell(x)
  row
end

"What a JSON value shows as in a cell: a string as its text, null as nothing, a list of words with commas between them, and anything else as JSON on one line"
json_cell(x::AbstractString) = String(x)
json_cell(x::JSONNumber) = x.text
json_cell(x::Bool) = string(x)
json_cell(::Nothing) = ""
json_cell(x) = x isa Vector{Any} && !any(json_holder, x) ? join((json_cell(y) for y in x), ", ") : json_line(x)

"`x` as JSON on one line"
json_line(x) = replace(sprint(write_json, x, 0), r",\n\s*" => ", ", r"\n\s*" => "")

"""
The rows of the table of the page that a filter reads: the one under the
heading that `from` names, or the nearest one above line `line`. `tables` are
the page's tables that are above the filter.
"""
page_filter_rows(e, spec::Filters.Filter, tables, line) = begin
  from = String(strip(spec.from))
  k = isempty(from) ? something(findlast(t -> t.last < line, tables), 0) : something(named_table(e, tables, from), 0)
  k == 0 && return no_rows(isempty(from) ?
    "Name a CSV or JSON file with a line like “from: orders.csv”, or put a table over this block." :
    "There's no file called $from beside this page, and no table called “$(from)” above this block.")
  t = tables[k]
  rows = t.headed ? t.rows : [[["Name", "Value"]]; t.rows]   # a sheet's rows have no names
  wide = maximum(length, rows)
  rows = [[r; fill("", wide - length(r))] for r in rows]
  FilterRows(rows, Csvs.numbers(rows), Any[], isempty(t.under) ? "The table above" : t.under, "", false, "")
end

"What a filter shows of `d`, its rows: the names of the columns that show, then each row that shows"
filter_table(d::FilterRows, s) = [[Filters.cell_of(d.rows[r], c) for c in s.columns] for r in [1; s.rows]]

"What a filter shows: the rows that it reads, and what it shows of them"
mutable struct FilterFound
  data::FilterRows
  subset::Any   # what Filters.subset gives, or nothing when there are no rows
  table::Any    # the rows that show, as a table of the page. It's made when a chart first asks for it.
end

# A FilterFound comes apart into its rows and what it shows of them: `d, s = filter_shown!(v)`
Base.iterate(x::FilterFound, i=1) = i == 1 ? (x.data, 2) : i == 2 ? (x.subset, 3) : nothing

# What each filter of a file showed last: the rows of the file then, and what showed. By the file and the block's lines.
const filter_found = Dict{Tuple{String,Vector{String}},Tuple{FilterRows,FilterFound}}()

"""
What the filter in `lines`, on line `line`, shows. `tables` are the page's
tables. A filter of a file is worked out again only when its lines or the file
change, so typing in another part of the page costs it nothing. A file of
100,000 rows takes about a tenth of a second. With `load`, it's a load block,
whose `from` can be a web address. Its rows are then the copy of what that
address last gave.
"""
filter_subset(e, lines, tables, line; load=false) = begin
  spec = Filters.query(lines)
  from = String(strip(spec.from))
  found(data) = FilterFound(data, isempty(data.problem) ? Filters.subset(spec, data.rows, data.numbers) : nothing, nothing)
  if Saves.isurl(from)
    load || return found(no_rows("A filter reads a file or a table of the page. To get rows from a server, write load in place of filter at the top of the block."))
    path, name = load_copy(from), Saves.host(from)
    isempty(path) && return found(no_rows("Ladder hasn't loaded the rows from $name yet.", name=name))
  elseif load && isempty(from)
    return found(no_rows("Name a file or a web address with a line like “from: orders.json” or “from: https://example.com/orders”."))
  else
    isfilterable(from) || return found(page_filter_rows(e, spec, [t for t in tables if t.last < line], line))
    path = abspath(docdir(e), expanduser(from))
    name = basename(path)
  end
  key = (path, String.(lines))
  data = filter_file(path, spec.at; name)
  kept = get(filter_found, key, nothing)
  kept !== nothing && kept[1] === data && return kept[2]
  length(filter_found) > 200 && empty!(filter_found)
  (filter_found[key] = (data, found(data)))[2]
end

"The rows that the filter in `lines`, on line `line`, shows as a table of the page, or nothing when it has none"
filter_page_table(e, lines, tables, line; load=false) = begin
  x = filter_subset(e, lines, tables, line; load)
  x.subset === nothing && return nothing
  x.table === nothing && (x.table = filter_table(x.data, x.subset))
  x.table
end

"A condition at the top of a filter. Its × takes it away. With `k` 0, it's the chip that says how many columns are hidden."
@def mutable struct FilterChip <: SemanticUI
  of::Any = nothing
  k::Int = 0
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip under it
end
"The × of a chip"
@def mutable struct ChipCross <: SemanticUI
  of::Any = nothing   # the chip
end
"The table of a filter. It scrolls sideways when it's wider than the page."
@def mutable struct FilterGrid <: SemanticUI
  of::Any = nothing
  inside::Any = nothing   # what's in it in this frame: the table, as far to the left as it's scrolled
end
"The heading of a column of a filter's table. A click on it opens the column's menu."
@def mutable struct FilterHead <: SemanticUI
  of::Any = nothing
  column::Int = 1    # the column of the rows that the filter reads
  wide::px = 0px
end
"The menu of a column of a filter's table"
@def mutable struct FilterMenu <: SemanticUI
  of::Any = nothing
end
"A line of that menu: one of the two orders, a value to tick, or the line that hides the column"
@def mutable struct FilterPick <: SemanticUI
  of::Any = nothing
  what::Symbol = :asc   # :asc, :desc, :value or :hide
  value::String = ""
  count::Int = 0
end
"The line under a filter's table that says how many rows don't show. A click shows them, or hides them again."
@def mutable struct FilterMore <: SemanticUI
  of::Any = nothing
end

reread!(v::FilterView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.spec = Filters.query(lines)
  v.changed = time()
  v
end

"""
What the filter `v` shows: a FilterFound, with `data`, the rows that it reads,
and `subset`, what it shows of them, or nothing when there are no rows. It's
worked out again when the block, the page or the file changes.
"""
filter_shown!(v::FilterView) = begin
  e = editor(v)
  key = (v.lines, e.buf.version, v.first, table_reads[], sums_run[], page_day(e))
  v.shown !== nothing && v.shown[1] == key && return v.shown[2]
  found = filter_subset(e, v.lines, page_tables(e), v.first; load=v.lang == LOAD)
  # What's kept of the rows is kept while they're the same
  v.shown !== nothing && v.shown[2] === found || (empty!(v.values); empty!(v.cut))
  v.shown = (key, found)
  found
end

"Write `f` as the lines of the filter `v`. ⌘Z takes it back."
filter_write!(v::FilterView, f::Filters.Filter; typing=false) = write_block!(v, v.lang, Filters.written(f); typing)

"The text field that adds a condition"
filter_adder(v::FilterView) = block_part!(v, :add) do
  TextInput(placeholder="Add a condition", font_family=SANS, font_size=12px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"The text field of a column's menu, for the words that the column's cells must have"
filter_field(v::FilterView) = block_part!(v, :field) do
  TextInput(placeholder="Contains…", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"""
The values of column `c` of what `v` reads, each with how many rows have it,
in the order of the column. Capitals don't count, so Sydney and sydney are
one value. It's nothing when the column has more than FEW_VALUES values.
"""
filter_values(v::FilterView, c::Int) = get!(v.values, c) do
  d = filter_shown!(v).data
  counts, shown = Dict{String,Int}(), Dict{String,String}()
  for r in 2:length(d.rows)
    cell = strip(Filters.cell_of(d.rows[r], c))
    key = lowercase(cell)
    haskey(counts, key) || (shown[key] = cell)
    counts[key] = get(counts, key, 0) + 1
    length(counts) > FEW_VALUES && return nothing
  end
  [(shown[k], counts[k]) for k in Filters.ordered(collect(keys(counts)), k -> shown[k], d.numbers[c], false)]
end

"""
What happens to a filter in each frame, before the page is laid out. It looks
at its file, so it shows the new rows when the file changes. While a column's
menu is open, the words in its field go into the block's lines as they're typed.
A load block looks for the rows that it asked its server for.
"""
block_tick!(v::FilterView) = begin
  v.lang == LOAD && load_tick!(v)
  pick_tick!(v)
  sources_tick!(v)
  from = String(strip(v.spec.from))
  isfilterable(from) && filter_file(abspath(docdir(editor(v)), expanduser(from)), v.spec.at)
  v.asking > 0 || return v
  d = filter_shown!(v).data
  (isempty(d.problem) && v.asking <= length(d.rows[1]) && filter_values(v, v.asking) === nothing) || return v
  words = String(strip(filter_field(v).text))
  names = d.rows[1]
  had = Filters.looked_for(v.spec, names, v.asking, :has)
  words == (isempty(had) ? "" : had[1]) && return v
  f = Filters.query(v.lines)
  filter_write!(v, Filters.look_for!(f, names, v.asking, :has, [words]), typing=true)
  v
end

"The width of each column of the table that `v` shows: as wide as its first rows need, and wider when they share room that's left"
filter_widths!(v::FilterView, d, s, wide) = begin
  key = (objectid(v.shown[2]), wide, s.columns)
  v.widths !== nothing && v.widths[1] == key && return v.widths[2]
  head, plain = cell_face(true), cell_face()
  sample = first(s.rows, 200)
  need(c) = max(measure(head, celltext(d.rows[1][c])) + 14px,
                maximum(r -> measure(plain, first(celltext(Filters.cell_of(d.rows[r], c)), 300)), sample, init=0px))
  natural = [clamp(need(c), 24px, WIDEST_CELL) + 2CELL_PAD for c in s.columns]
  total = sum(natural, init=0px)
  widths = total < wide ? natural .* (num(wide) / num(total)) : natural
  v.widths = (key, widths)
  widths
end

"The text of `text` as a cell `room` wide shows it: on one line, and cut short with an … when it's too long"
filter_cell(v::FilterView, text, room, face) = get!(v.cut, (text, room, face.style)) do
  length(v.cut) > 20_000 && empty!(v.cut)
  shown = first(celltext(text), 300)
  while measure(face, shown) > room && length(shown) > 1
    shown = first(shown, max(1, floor(Int, (length(shown) - 1) * num(room) / num(measure(face, shown))) - 1)) * "…"
  end
  shown
end

"How many rows the table of `v` shows, of the `n` that meet its conditions"
rows_to_show(v::FilterView, n) = v.whole ? n : min(n, FILTER_ROWS)

describe(v::FilterView) = begin
  e = editor(v)
  d, s = filter_shown!(v)
  load, url = v.lang == LOAD, load_url(v)
  v.job === nothing || redraw_in!(v, 0.2)   # so that a frame comes soon to see if the rows have come
  with_theme(component_theme(e.zoom)) do
    count = s === nothing ? "" : Filters.summary(length(s.rows), length(d.rows) - 1, more=d.more)
    icon = !load ? "funnel" : isempty(url) ? "file-earmark-arrow-down" : "cloud-arrow-down"
    refresh = isempty(url) ? () : (block_button!(v, :refresh, :refresh, icon="arrow-clockwise", words=v.job === nothing ? "Refresh" : "Loading…",
                                                 tip="Ask $(Saves.host(url)) for the rows again", off=v.job !== nothing || !isempty(load_problem(v))),)
    bar = block_bar(Box(width(6px)), Icon(icon, size=14px, color=colours.dim), Box(width(4px)),
      source_button(v),
      (isempty(count) ? () : (rule(), Box(label(count, 12px, color=colours.dim))))...,
      Box(width(grow=grow)),
      (isempty(v.saved) ? () : (Box(label(v.saved, 12px, color=colours.dim)), Box(width(6px))))...,
      refresh...,
      block_button!(v, :save, :save, icon="download", words="Save", tip="Save the rows that show as a new file", off=s === nothing || isempty(s.rows)))
    picker = picks_file(v) ? picker_section(v) : ()
    # With no `from`, the picker says what to do, so there's nothing else to say
    load && isempty(strip(v.spec.from)) && return Column(block_look()..., clip=true, name="Filter", bar, picker...)
    said = load ? load_line(v) : ()
    # A load block shows no field for conditions until it has one
    chips = load && isempty(v.spec.conditions) && isempty(v.spec.show) ? () : filter_chips(v, d, s)
    # While the first rows from a server are on their way, or when it can't be asked, the line under the top says why
    s === nothing && return Column(block_look()..., clip=true, name="Filter", bar, picker..., said..., chips...,
                                   (v.job !== nothing && isempty(load_copy(url)) || !isempty(url) && !isempty(load_problem(v)) ? () :
                                    (block_note(d.problem),))...)
    problems = isempty(s.problems) ? () : (Row(width(grow=grow), padding(0px, 12px, 8px, 12px), Alignment.Start,
      Box(width(grow=grow), Text(join(s.problems, " "), size=12px, family=SANS, color=colours.accent, wrap=WrapMode.words))),)
    Column(block_look()..., clip=true, name="Filter", bar, picker..., said..., chips..., problems..., filter_grid(v, d, s)...)
  end
end

"""
The rows of chips at the top of a filter, with the field that adds one at the
end. The chips go onto as many rows as they need.
"""
filter_chips(v::FilterView, d, s) = begin
  e = editor(v)
  chips = Any[block_part!(() -> FilterChip(of=v, k=k), v, (:chip, k)) for k in eachindex(v.spec.conditions)]
  s !== nothing && !isempty(v.spec.show) && length(s.columns) < length(d.rows[1]) && push!(chips, block_part!(() -> FilterChip(of=v, k=0), v, (:chip, 0)))
  adder = filter_adder(v)
  adder.color = colours.ink
  # The field suggests a condition on the last column of numbers. The first is often an id.
  names = isempty(d.rows) ? String[] : d.rows[1]
  c = findlast(identity, d.numbers)
  adder.placeholder = c === nothing ? (isempty(names) ? "Add a condition" : "Add a condition, like $(names[1]) is …") :
                                      "Add a condition, like $(names[c]) > 100"
  w = window_of(v)
  typing = w !== nothing && w.focus === adder
  field = Row(fixed(ADD_W), height(CHIP_H), padding(8px, 0px), child_gap=6px, radius(6px), Alignment.Center,
              background(colours.bg), border(1px, :solid, typing ? colours.accent : colours.line),
              Icon("plus", size=12px, color=colours.dim), Box(width(grow=grow), height(grow=grow), adder))
  # Each row of chips takes chips while they fit
  room = e.width - 24px
  lines, used = Vector{Any}[Any[]], 0px
  # Without rows, there's nothing to add a condition to, so only the chips show
  s === nothing && isempty(chips) && return Any[]
  for (chip, wide) in [[(chip, chip_width(chip)) for chip in chips]; s === nothing ? Tuple{Any,px}[] : [(field, ADD_W)]]
    !isempty(lines[end]) && used + wide > room && (push!(lines, Any[]); used = 0px)
    push!(lines[end], chip)
    used += wide + 6px
  end
  [Row(width(grow=grow), padding(k == 1 ? 10px : 0px, 12px, k == length(lines) ? 10px : 6px, 12px), child_gap=6px, Alignment.Center, line...)
   for (k, line) in enumerate(lines)]
end

"What a chip says: its condition, or how many columns are hidden"
chip_words(c::FilterChip) = begin
  v = c.of
  c.k == 0 || return get(v.spec.conditions, c.k, "")
  d, s = filter_shown!(v)
  n = s === nothing ? 0 : length(d.rows[1]) - length(s.columns)
  n == 1 ? "1 column hidden" : "$n columns hidden"
end

"Why the filter can't use the condition of chip `c`, or \"\""
chip_problem(c::FilterChip) = begin
  d, s = filter_shown!(c.of)
  s === nothing || c.k == 0 || c.k > length(s.conditions) ? "" : s.conditions[c.k].problem
end

chip_width(c::FilterChip) = measure(cell_face(), chip_words(c)) + 10px + 8px + 16px

describe(c::FilterChip) = begin
  bad = !isempty(chip_problem(c))
  cross = block_part!(() -> ChipCross(of=c), c.of, (:cross, c.k))
  Row(height(CHIP_H), padding(0px, 4px, 0px, 10px), child_gap=4px, radius(CHIP_H / 2), Alignment.Center, name="Condition",
      background(c.k == 0 ? colours.bg : colours.chip), border(1px, :solid, bad ? colours.accent : colours.chip_line),
    Box(label(chip_words(c), 12px, color=bad ? colours.accent : c.k == 0 ? colours.dim : colours.ink)), cross)
end

cursor(::FilterChip) = :arrow
draw(ctx, size, ui::ConcreteRect, c::FilterChip) = (c.rect = (ui.left, ui.top, ui.width, ui.height); nothing)
# The mouse over a chip whose condition can't be used says why
onmouse(c::FilterChip, ev::MouseMove) = begin
  why = chip_problem(c)
  isempty(why) && return nothing
  show_tooltip!(ev.window, tip_label(why), c.rect..., placement=:bottom, gap=6px)
  handled
end

describe(x::ChipCross) = Box(fixed(16px), radius(8px), Alignment.Center, background(ishovered(x) ? colours.hover : clear),
  Icon("x", size=12px, color=ishovered(x) ? colours.ink : colours.dim))
cursor(::ChipCross) = :hand
onmouse(::ChipCross, ::MouseMove) = handled

# A click on the × takes the condition away, or shows every column again
onkey(x::ChipCross, ev::KeyPress{Keys.mouse_left}) = begin
  c = x.of
  v = c.of
  hide_tooltip!(ev.window)
  f = Filters.query(v.lines)
  c.k == 0 ? empty!(f.show) : c.k <= length(f.conditions) && deleteat!(f.conditions, c.k)
  filter_write!(v, f)
  handled
end

# Return in the field adds what it holds as a condition. Esc empties it, and gives the keyboard back to the page.
onkey(v::FilterView, ev::KeyPress{Keys.enter}) = begin
  unmodified(ev) || return nothing
  adder = filter_adder(v)
  ev.window.focus === adder || return (focus(editor(v)); handled)
  words = String(strip(adder.text))
  isempty(words) && return handled
  f = Filters.query(v.lines)
  push!(f.conditions, words)
  adder.text, adder.cursor, adder.anchor = "", 0, 0
  filter_write!(v, f)
  handled
end
onkey(v::FilterView, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  adder = filter_adder(v)
  adder.text, adder.cursor, adder.anchor = "", 0, 0
  focus(editor(v))
  handled
end

"""
The table of the filter `v`, and the line under it that says how many more
rows there are. Only the rows that are in the window are made.
"""
filter_grid(v::FilterView, d, s) = begin
  e = editor(v)
  wide = e.width - 2px   # the room inside the line round the block
  widths = filter_widths!(v, d, s, wide)
  room = sum(widths, init=0px)
  v.across = clamp(v.across, 0px, max(0px, room - wide))
  n = rows_to_show(v, length(s.rows))
  _, h = window_size(e)
  # The rows that the window shows, with a few each side. The table's top is where it was drawn last.
  lo = clamp(floor(Int, -num(v.top + HEAD_H) / num(ROW_H)) - 8, 0, n)
  hi = clamp(lo + ceil(Int, num(h) / num(ROW_H)) + 16, lo, n)
  plain = cell_face()
  row(k) = (r = s.rows[k];
    Row(fixed(room), height(ROW_H), Alignment.Start, background(iseven(k) ? colours.stripe : clear),
      [Row(fixed(w), height(ROW_H), padding(CELL_PAD, 0px), Alignment.Center, clip=true,
           label(filter_cell(v, Filters.cell_of(d.rows[r], c), w - 2CELL_PAD, plain), 12px))
       for (c, w) in zip(s.columns, widths)]...))
  heads = [block_part!(() -> FilterHead(of=v, column=c), v, (:head, c)) for c in s.columns]
  foreach(((h, w),) -> h.wide = w, zip(heads, widths))
  none = isempty(s.rows) ? (Box(fixed(min(room, wide)), height(2ROW_H), label("No row meets the conditions.", 12px, color=colours.dim)),) : ()
  table = Column(fixed(room), Alignment.Start,
    Row(fixed(room), height(HEAD_H), Alignment.Start, background(colours.head), heads...),
    spacer(ROW_H * lo), [row(k) for k in lo+1:hi]..., spacer(ROW_H * (n - hi)), none...)
  grid = block_part!(() -> FilterGrid(of=v), v, :grid)
  grid.inside = Box(Alignment.Start, offset_x=-v.across, table)
  more = length(s.rows) > FILTER_ROWS ? (block_part!(() -> FilterMore(of=v), v, :more),) : ()
  (Box(width(grow=grow), height(1px), background(colours.line)), grid, more...)
end

describe(g::FilterGrid) = Row(width(grow=grow), Alignment.Start, clip_x=true, name="Rows", detach!(g.inside))
cursor(::FilterGrid) = :arrow
draw(ctx, size, ui::ConcreteRect, g::FilterGrid) = (g.of.top = ui.top; nothing)

# Two fingers that move sideways, or the wheel with ⇧ held, scroll a wide table sideways. They do that anywhere on the
# block, as on a schedule. Their move up or down scrolls the page.
onscroll(v::FilterView, ev::MouseScroll) = begin
  ev.delta[1] == 0px && return nothing
  v.across = max(0px, v.across - 30ev.delta[1])
  ev.delta[2] == 0px ? handled : nothing
end

describe(h::FilterHead) = begin
  v = h.of
  d, s = filter_shown!(v)
  c = h.column
  way = s !== nothing && s.sorted == c ? (Filters.down(v.spec) ? :desc : :asc) : nothing
  lit = ishovered(h) || v.asking == c
  names = d.rows[1]
  fewer = s !== nothing && any(x -> x.column == c && isempty(x.problem), s.conditions)
  colour = fewer ? colours.accent : colours.ink
  marks = ((fewer ? (Icon("funnel-fill", size=9px, color=colours.accent),) : ())...,
           (way !== nothing ? (Icon(way == :asc ? "chevron-up" : "chevron-down", size=9px, color=colours.ink),) :
            lit && !fewer ? (Icon("chevron-down", size=9px, color=colours.faint),) : ())...)
  room = h.wide - 2CELL_PAD - 13px * length(marks)
  Row(fixed(h.wide), height(HEAD_H), padding(CELL_PAD, 0px), child_gap=4px, Alignment.Center, clip=true,
      background(lit ? colours.hover : clear),
    Box(label(filter_cell(v, names[c], max(room, 12px), cell_face(true)), 12px, color=colour, weight="Semibold")), marks...)
end

cursor(::FilterHead) = :hand
onmouse(::FilterHead, ::MouseMove) = handled

onkey(h::FilterHead, ev::KeyPress{Keys.mouse_left}) = begin
  v, c = h.of, h.column
  e = editor(v)
  v.asking = c
  v.was = copy(v.lines)
  names = filter_shown!(v).data.rows[1]
  listed = filter_values(v, c) !== nothing
  # The menu's field starts with the words that the column's cells must have now
  if !listed
    field = filter_field(v)
    had = Filters.looked_for(v.spec, names, c, :has)
    field.text = isempty(had) ? "" : had[1]
    field.cursor = field.anchor = length(field.text)
  end
  menu = block_part!(() -> FilterMenu(of=v), v, :menu)
  # A click outside the menu closes it and keeps what's chosen
  popup!(ev.window, menu, anchor=h, placement=:below, gap=4px, width=SHEET_MENU_W, key=FILTER_KEY,
         onclose=() -> (v.asking = 0; focus(e)), theme=component_theme(e.zoom))
  listed || focus(filter_field(v))
  handled
end

"Close the menu of the filter `v`, and give the keyboard back to the page"
close_filter_menu!(v::FilterView) = begin
  v.asking = 0
  w = window_of(v)
  w === nothing || close_popup!(w, FILTER_KEY)
  focus(editor(v))
  handled
end

describe(m::FilterMenu) = begin
  v, c = m.of, found_colours()
  d, s = filter_shown!(v)
  section(words) = Row(width(grow=grow), height(22px), padding(8px, 0px), Alignment.Center, label(words, 10px, color=c.dim, weight="Semibold"))
  pick(what; value="", count=0) = (p = block_part!(() -> FilterPick(of=v, what=what, value=value), v, (:pick, what, value)); p.count = count; p)
  between() = Box(width(grow=grow), height(13px), Alignment.Center, Box(width(grow=grow), height(1px), background(c.rule)))
  values = v.asking > 0 ? filter_values(v, v.asking) : nothing
  fewer = values === nothing ?
    (section("FILTER FOR"),
     Box(width(grow=grow), padding(4px, 2px),
       Box(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), border(1px, :solid, c.line), background(c.frame), filter_field(v)))) :
    (section("SHOW"), [pick(:value, value=text, count=n) for (text, n) in values]...)
  hide = s !== nothing && length(s.columns) > 1 ? (between(), pick(:hide)) : ()
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Column menu",
    Column(width(grow=grow), Alignment.Start, section("SORT"), pick(:asc), pick(:desc), between(), fewer..., hide...))
end

# The menu sees a key before its text field does. Return keeps what's chosen, and esc puts back the lines that the block had.
onkey(m::FilterMenu, ev::KeyPress{Keys.enter}) = unmodified(ev) ? close_filter_menu!(m.of) : nothing
onkey(m::FilterMenu, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  v = m.of
  was = v.was
  close_filter_menu!(v)
  write_block!(v, v.lang, was)
  handled
end

"True when the line `p` of a menu is on: the order that the rows have, or a value that's ticked"
picked(p::FilterPick) = begin
  v = p.of
  p.what == :value || return p.what in (:asc, :desc) && (s = filter_shown!(v).subset; s !== nothing && s.sorted == v.asking) &&
                             Filters.down(v.spec) == (p.what == :desc)
  ticked = Filters.looked_for(v.spec, filter_shown!(v).data.rows[1], v.asking, :is)
  any(t -> Filters.alike(p.value, t), ticked)
end

describe(p::FilterPick) = begin
  v, c = p.of, found_colours()
  d = filter_shown!(v).data
  on = picked(p)
  back = background(ishovered(p) ? c.pick : c.frame)
  if p.what == :value
    ticked = !isempty(Filters.looked_for(v.spec, d.rows[1], v.asking, :is))
    return Row(width(grow=grow), height(26px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center, back,
      Box(fixed(10px), (on ? (Icon("check", size=10px, color=c.ink),) : ())...),
      Box(width(grow=grow), Alignment.Start, clip_x=true,
        label(isempty(p.value) ? "Empty" : p.value, 13px, color=isempty(p.value) || !(on || !ticked) ? c.dim : c.ink, weight=on ? "Semibold" : "")),
      Box(label(commas(p.count), 11px, color=c.dim)))
  end
  numbers = v.asking > 0 && get(d.numbers, v.asking, false)
  icon, words = p.what == :hide ? ("eye-slash", "Hide this column") :
                p.what == :asc ? ("chevron-up", numbers ? "Smallest first" : "A–Z") : ("chevron-down", numbers ? "Largest first" : "Z–A")
  Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      on ? background(c.pick) : back,
    Icon(icon, size=10px, color=on ? c.ink : c.dim), label(words, 13px, color=on ? c.ink : c.dim, weight=on ? "Semibold" : ""))
end

cursor(::FilterPick) = :hand
onmouse(::FilterPick, ::MouseMove) = handled

"""
A click on an order puts the rows in that order, or back in the table's order
when they're in it already. A click on a value ticks it, or takes the tick
away, and only the rows with a ticked value show. With every value ticked, or
none, every row shows. A click on the last line hides the column.
"""
onkey(p::FilterPick, ::KeyPress{Keys.mouse_left}) = begin
  v = p.of
  c = v.asking
  d, s = filter_shown!(v)
  (c > 0 && s !== nothing) || return handled
  names = d.rows[1]
  f = Filters.query(v.lines)
  if p.what == :hide
    close_filter_menu!(v)
    return (filter_write!(v, Filters.hide!(f, names, c, s.columns)); handled)
  elseif p.what == :value
    ticked = Filters.looked_for(f, names, c, :is)
    k = findfirst(t -> Filters.alike(p.value, t), ticked)
    k === nothing ? push!(ticked, p.value) : deleteat!(ticked, k)
    length(ticked) == length(filter_values(v, c)) && empty!(ticked)
    Filters.look_for!(f, names, c, :is, ticked)
  else
    Filters.sort_by!(f, names, picked(p) ? 0 : c, p.what == :desc, d.numbers[c])
  end
  filter_write!(v, f)
  handled
end

"What the line under the table says"
more_words(v::FilterView) = begin
  s = filter_shown!(v).subset
  rest = length(s.rows) - FILTER_ROWS
  v.whole ? "Show the first $FILTER_ROWS rows only" : "and $(commas(rest)) more row$(rest == 1 ? "" : "s")"
end

describe(m::FilterMore) = Row(width(grow=grow), height(30px), padding(12px, 0px), Alignment.Center, clip=true,
  Box(label(more_words(m.of), 12px, color=ishovered(m) ? colours.accent : colours.dim)), Box(width(grow=grow)))
cursor(::FilterMore) = :hand
onmouse(::FilterMore, ::MouseMove) = handled

# A click on the line under the table shows every row, or only the first ones again. When rows go, the line stays under the mouse.
onkey(m::FilterMore, ::KeyPress{Keys.mouse_left}) = begin
  v = m.of
  e = editor(v)
  s = filter_shown!(v).subset
  hidden = ROW_H * (length(s.rows) - FILTER_ROWS)
  v.whole = !v.whole
  v.whole || (e.scroll.offset = max(0px, e.scroll.offset - hidden))
  handled
end

"""
Write the rows that the filter `v` shows into the file at `path`. A JSON file
gets the things that the rows came from, as the file that the filter reads
had them, when it's a JSON file. Any other file gets the rows as CSV, with the
columns that show.
"""
save_rows(v::FilterView, path) = begin
  d, s = filter_shown!(v)
  s === nothing && return 0
  if lowercase(splitext(path)[2]) in JSONS && !isempty(d.things)
    write(path, sprint(write_json, Any[d.things[r-1] for r in s.rows], 0) * "\n")
  else
    mark = lowercase(splitext(path)[2]) == ".tsv" ? '\t' : ','
    quoted(cell) = occursin(mark, cell) || occursin('"', cell) || occursin('\n', cell) ? "\"" * replace(cell, "\"" => "\"\"") * "\"" : cell
    write(path, join((join(quoted.(row), mark) for row in filter_table(d, s)), "\n") * "\n")
  end
  length(s.rows)
end

"The name that the Save panel starts with: the name of the file that the rows came from, with (filtered) after it"
save_name(v::FilterView) = begin
  d = filter_shown!(v).data
  isempty(d.path) && return "$(isempty(d.name) ? "Rows" : d.name).csv"
  # A copy of what a server sent has a name that means nothing, so the server's name takes its place
  isload_copy(d.path) && return d.name * splitext(d.path)[2]
  stem, ext = splitext(basename(d.path))
  "$stem (filtered)$ext"
end

act!(v::FilterView, action, w) = begin
  action == :refresh && return (load_rows!(v); handled)
  action == :choose && return (toggle_picker!(v); handled)
  action == :close_picker && return (v.choosing = false; handled)
  action == :key && return (ask_load_key!(v, w); handled)
  action == :save || return handled
  # A window that isn't on the screen, like one a test makes, has no panel to ask with
  (Sys.isapple() && !isempty(w.glfw)) || return handled
  path = save_panel(editor(v), save_name(v))
  # The panel took the keyboard, so the window never heard the keys that opened it come up
  w.keys = Keys(0)
  path === nothing && return handled
  v.saved = try
    n = save_rows(v, path)
    "Saved $(commas(n)) row$(n == 1 ? "" : "s") to $(basename(path))"
  catch
    "Ladder couldn't save $(basename(path))"
  end
  handled
end

"The filter as HTML: where its rows come from, its conditions, and the rows that show"
filter_html(e, v::FilterView) = begin
  d, s = filter_shown!(v)
  s === nothing && return "<p><em>$(escape(d.problem))</em></p>"
  table = filter_table(d, s)
  numbers = [get(d.numbers, c, false) for c in s.columns]
  side(c) = numbers[c] ? " style=\"text-align: right\"" : ""
  row(tag, cells) = "<tr>" * join("<$tag$(side(c))>$(replace(escape(cell), "\n" => "<br>"))</$tag>" for (c, cell) in enumerate(cells)) * "</tr>"
  good = [x.text for x in s.conditions if isempty(x.problem)]
  caption = escape(d.name) * ": " * Filters.summary(length(s.rows), length(d.rows) - 1, more=d.more) *
            (isempty(good) ? "" : ", where " * join(escape.(good), " and "))
  "<table>\n<caption>$caption</caption>\n<thead>" * row("th", table[1]) * "</thead>\n<tbody>\n" *
    join((row("td", cells) for cells in table[2:end]), "\n") * "\n</tbody>\n</table>"
end

BLOCKS[FILTER] = FilterView
block_name(::Type{FilterView}) = "Filter"
block_icon(::Type{FilterView}) = "funnel"
block_insert(::Type{FilterView}) = ("Filter", ["```$FILTER", "from: ", "```", "", ""], (2, 6))
block_table_kind(::Type{FilterView}) = "filter"
block_html(e, v::FilterView) = filter_html(e, v)
block_tables!(::Type{FilterView}, e, i::Int, t::Int, under::AbstractString, out; load=false) = begin
  rows = filter_page_table(e, e.buf.lines[i+1:t-1], out, i; load)
  rows === nothing || push!(out, (first=i, last=t, under=under, rows=rows, headed=true, ranged=false))
end
