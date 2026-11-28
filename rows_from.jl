# Where a block's rows come from: the button at the top of a filter, a load block, a save block and a chart, and the list that it opens
#
# A filter, a load block, a save block and a chart read rows. The name at the
# top of each is a button that says where its rows come from. A click opens a
# list under it, as the buttons of a `find` block do: the table nearest above,
# each table of the page that it can read, and a last row, Choose a file…. A
# table there is any table, sheet, spreadsheet, filter, load block or time log
# of the page, or a line that shows a CSV file. A click on a row makes it the
# block's `from`. Choose a file… shows a breadcrumb under the top of the block,
# open, that lists folders and the files that the block can read. A click on
# a file makes it the block's `from`, and Close keeps the `from` that it has.
#
# A `from` line calls a table by the heading over it, like `from: Costs`. The
# second table under that heading is `from: Costs 2`. A table with no heading
# over it is called by the name of the page's file.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor popup! close_popup!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./markdown" Kind words
@use "./chart" => Charts
@use "./save" => Saves
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
@use "./json_view" exports...
@use "./load_view" exports...
@use "./media_view" istable chart_path
@use "./find_view" choice_matches

export SOURCE_MENU, SourceButton, close_picker!, from_picker, from_picker_section, headless_name,
       named_table, open_sources!, own_rows, pick_file!, set_source!, several_sources,
       source_button, source_chooser, source_files, source_folder, source_from, source_lang,
       source_rows, source_tables, source_words, table_kind, table_name, with_from

const SOURCE_MENU = :source_menu   # the key of the list of where a block's rows can come from

"The button at the top of a block that says where its rows come from. A click opens the list of where else they can."
@def mutable struct SourceButton <: SemanticUI
  of::Any = nothing   # the block's view
end

"What a table with no heading over it is called: the name of the page's file"
headless_name(e) = isempty(e.buf.path) ? "Untitled" : title(e.buf.path)

"What table `n` of `tables`, the tables of the page of `e`, is called in a `from` line: the heading over it, with a number after it for the second table under that heading and the ones after"
table_name(e, tables, n) = begin
  base(t) = isempty(t.under) ? headless_name(e) : t.under
  name = base(tables[n])
  before = count(k -> Charts.same(base(tables[k]), name), 1:n-1)
  before == 0 ? name : "$name $(before + 1)"
end

"""
Which of `tables`, the tables of the page of `e` in their order, the `from`
line `from` calls, or nothing. A heading calls the first table under it, and
a heading with a number after it calls the table of that number under it. The
name of the page's file calls the tables with no heading over them.
"""
named_table(e, tables, from) = begin
  from = String(strip(from))
  isempty(from) && return nothing
  k = findfirst(t -> Charts.same(t.under, from), tables)
  k === nothing || return k
  m = match(r"^(.*\S)\s+(\d+)$", from)
  base, n = m === nothing ? (from, 1) : (String(m[1]), parse(Int, m[2]))
  ks = [k for (k, t) in enumerate(tables) if Charts.same(isempty(t.under) ? headless_name(e) : t.under, base)]
  1 <= n <= length(ks) ? ks[n] : nothing
end

"What a table of the page of `e` is, in a word or two: the kind of block or line that it's in"
table_kind(e, t) = begin
  k = kinds(e.buf)[t.first]
  k.kind == Kind.table && return "table"
  k.kind == Kind.fence || return "CSV file"
  haskey(BLOCKS, k.lang) ? block_table_kind(BLOCKS[k.lang]) : "block"
end

# The language of each kind of block that reads rows, for writing its lines
source_lang(v::FilterView) = v.lang
source_lang(::SaveView) = SAVE
source_lang(::ChartView) = CHART

"The `from` of the block `v`"
source_from(v::Union{FilterView,SaveView,ChartView}) = String(strip(v.spec.from))

"""
The tables that the block `v` can read, by their places among the page's
tables. A filter, a load block and a save block read the tables above them,
so a table never reads itself. A chart can read any.
"""
source_tables(v::Union{FilterView,SaveView}) = (ts = page_tables(editor(v)); [k for k in eachindex(ts) if ts[k].last < v.first])
source_tables(v::ChartView) = (ts = page_tables(editor(v)); [k for k in eachindex(ts) if !(v.first <= ts[k].first <= v.last)])

"True for the name of a file that the block `v` can read. A chart draws a CSV or TSV file. The others read JSON too."
source_files(::ChartView) = istable
source_files(_) = isfilterable

"The tables that the chart `c` of the page of `e` draws, when it draws more than one, or none"
several_sources(e, c::Charts.Chart) = begin
  names = chart_sources(c)
  length(names) > 1 && chart_path(e, c) === nothing && named_table(e, page_tables(e), c.from) === nothing ? names : String[]
end
several_sources(v) = v isa ChartView ? several_sources(editor(v), v.spec) : String[]

"What the button of `v` says: where its rows come from"
source_words(v) = begin
  own_rows(v) && return "Its own rows"
  from = source_from(v)
  isempty(from) && return v isa FilterView && v.lang == LOAD ? "Choose rows" : "The table above"
  n = length(several_sources(v))
  n > 1 && return "$n tables"
  Saves.isurl(from) ? Saves.host(from) : source_files(v)(from) ? basename(from) : from
end

"The button of the block `v` that says where its rows come from"
source_button(v) = block_part!(() -> SourceButton(of=v), v, :source)

describe(b::SourceButton) = begin
  v = b.of
  from = source_from(v)
  c = get(v.parts, :sources, nothing)
  open = c !== nothing && c.asking !== nothing
  icon = Saves.isurl(from) ? "cloud" : !isempty(from) && source_files(v)(from) ? "file-earmark" : "table"
  Row(height(26px), padding(9px, 0px), child_gap=6px, radius(6px), Alignment.Center, name="Source",
      border(1px, :solid, open ? colours.accent : colours.line), background(ishovered(b) ? colours.hover : colours.bg),
    Icon(icon, size=13px, color=colours.dim), Box(label(source_words(v), 12px, weight="Semibold")), Icon("chevron-down", size=9px, color=colours.dim))
end

cursor(::SourceButton) = :hand
onkey(b::SourceButton, ev::KeyPress{Keys.mouse_left}) = open_sources!(b, ev.window)

"""
The rows of the list of where the rows of `v` can come from: the table nearest
above, each table of the page that `v` can read, the file or the server that
it reads now, and a row that chooses a file. A load block's rows come from a
file or a server, so it has no row for the table above.
"""
source_rows(v) = begin
  e = editor(v)
  ts = page_tables(e)
  from = source_from(v)
  rows = Any[]
  own_rows(v) && push!(rows, (key=:own, name="Its own rows", short="", words=["its own rows", "own"]))
  v isa FilterView && v.lang == LOAD || push!(rows, (key="", name="The table above", short="", words=["the table above", "nearest"]))
  for k in source_tables(v)
    name, kind = table_name(e, ts, k), table_kind(e, ts[k])
    push!(rows, (key=name, name=name, short=kind, words=[name, kind]))
  end
  several = several_sources(v)
  for name in several   # a chart that draws several tables can draw files too
    istable(name) && !any(r -> r.key isa String && Charts.same(r.key, name), rows) &&
      push!(rows, (key=name, name=basename(name), short="file", words=[name]))
  end
  own_rows(v) || isempty(from) || !isempty(several) || any(r -> r.key == from, rows) || named_table(e, ts, from) !== nothing ||
    push!(rows, (key=from, name=source_words(v), short=Saves.isurl(from) ? "server" : "file", words=[from]))
  push!(rows, (key=:file, name="Choose a file…", short="", words=["choose a file", "file"]))
  rows
end

"The list of where the rows of the block `v` can come from, kept with the block"
source_chooser(v) = block_part!(() -> SourceChooser(of=v), v, :sources)

"The field at the top of the list of where rows can come from, that searches it. A chart's says how to draw several tables."
choice_input(c::SourceChooser) = block_part!(c, :filter) do
  TextInput(placeholder=c.of isa ChartView ? "Filter, or ⌘-click to add a table" : "Filter…", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"True when the row `r` of the list is where the block's rows come from now, or one of the tables that a chart draws"
chosen(c::SourceChooser, r) = own_rows(c.of) ? r.key == :own :
  r.key isa String && (r.key == source_from(c.of) || any(n -> Charts.same(n, r.key), several_sources(c.of)))

"""
Add the table of row `k` of the list to the tables that the chart of `c`
draws, or take it away when the chart draws it already. A chart that drew
the table above names that table, so it goes on drawing it too. The list
stays open, for the next table. A row that isn't a table is taken as a click
takes it.
"""
toggle_source!(c::SourceChooser, k::Int) = begin
  v = c.of
  (c.asking !== nothing && k in eachindex(c.rows)) || return stop_choosing!(c)
  key = c.rows[k].key
  (v isa ChartView && key isa String && !isempty(key)) || return choose!(c, k)
  e = editor(v)
  names = several_sources(v)
  if isempty(names)
    from = source_from(v)
    ts = page_tables(e)
    above = something(findlast(t -> t.last < v.first, ts), findfirst(t -> t.first > v.last, ts), 0)
    names = !isempty(from) ? [from] : above == 0 ? String[] : [table_name(e, ts, above)]
  end
  at = findfirst(n -> Charts.same(n, key), names)
  at === nothing ? push!(names, key) : deleteat!(names, at)
  set_source!(v, join(names, ", "))
  handled
end

"Show the list of where the rows of the block of `b` can come from, under `b`, with the keyboard in its field"
open_sources!(b::SourceButton, window) = begin
  v = b.of
  c = source_chooser(v)
  stop_choosing!(c)
  input = choice_input(c)
  input.color = colours.ink
  input.text = ""
  input.anchor = input.cursor = 0
  c.asking, c.typed = :source, ""
  c.rows = source_rows(v)
  c.pick = something(findfirst(r -> chosen(c, r), c.rows), 1)
  focus(input)
  menu = ChoiceMenu(of=c, button=b)
  c.parts[:menu] = menu
  popup!(window, menu, anchor=b, placement=:bottom, gap=9px, width=260px, key=SOURCE_MENU,
         onclose=() -> stop_choosing!(c), theme=component_theme(editor(v).zoom))
  handled
end

"Take the list away. The keyboard goes back to the page."
stop_choosing!(c::SourceChooser) = begin
  c.asking === nothing && return handled
  c.asking = nothing
  c.rows = Any[]
  w = window_of(c)
  w === nothing && return handled
  close_popup!(w, SOURCE_MENU)
  w.focus === choice_input(c) && focus(editor(c))
  handled
end

"""
What happens in each frame to the list: it closes when a click somewhere else
took the keyboard from its field, and it keeps the rows that have the words in
the field. New words pick the row whose name starts with them, or the first.
"""
choosing_tick!(c::SourceChooser) = begin
  c.asking === nothing && return
  w = window_of(c)
  (w === nothing || w.focus !== choice_input(c)) && return stop_choosing!(c)
  typed = String(strip(choice_input(c).text))
  typed == c.typed && return
  c.typed = typed
  c.rows = filter!(r -> choice_matches(r, typed), source_rows(c.of))
  c.pick = something(findfirst(r -> startswith(lowercase(r.name), lowercase(typed)), c.rows), 1)
end

"The list of the block `v`, in each frame"
sources_tick!(v) = (c = get(v.parts, :sources, nothing); c === nothing || choosing_tick!(c); v)

"Take row `k` of the list: its table is where the block's rows come from, or its file picker opens"
choose!(c::SourceChooser, k::Int) = begin
  (c.asking !== nothing && k in eachindex(c.rows)) || return stop_choosing!(c)
  key = c.rows[k].key
  stop_choosing!(c)
  v = c.of
  key == :file ? pick_file!(v) : key == :own || (key == source_from(v) && !own_rows(v)) ? close_picker!(v) : set_source!(v, key)
  handled
end

"""
`lines` with `from` as their `from` line, in place of the one there or first.
An empty `from` takes the line away. An `at` line says where the list is in a
JSON file, so it goes when `from` is neither a JSON file nor a web address.
"""
with_from(lines, from) = begin
  out = String.(lines)
  k = findfirst(l -> occursin(r"^\s*from\s*:"i, l), out)
  if isempty(from)
    k === nothing || deleteat!(out, k)
  else
    k === nothing ? pushfirst!(out, "from: $from") : (out[k] = "from: $from")
  end
  lowercase(splitext(from)[2]) in JSONS || Saves.isurl(from) || filter!(l -> !occursin(r"^\s*at\s*:"i, l), out)
  out
end

"Make `from` where the rows of the block `v` come from, and close its file picker"
set_source!(v, from) = (close_picker!(v); write_block!(v, source_lang(v), with_from(v.lines, from)))

"""
A chart that holds its own rows draws them, whatever its `from` says. So when
another table or a file is chosen, the rows go from the block. ⌘Z puts them back.
"""
set_source!(v::ChartView, from) = begin
  close_picker!(v)
  own_rows(v) || return write_block!(v, CHART, with_from(v.lines, from))
  c = deepcopy(v.spec)
  c.rows, c.from = Vector{String}[], String(from)
  write_block!(v, CHART, Charts.written(c))
end

"True when the block `v` is a chart that holds its own rows, with a | between the cells, and draws them and no table"
own_rows(v) = v isa ChartView && !isempty(v.spec.rows)

# The file picker of each kind of block: a filter's and a load block's is `load_picker`
pick_file!(v::FilterView) = (v.choosing = false; toggle_picker!(v))
close_picker!(v::FilterView) = (v.choosing = false; v)
close_picker!(v::Union{SaveView,ChartView}) = (v.sourcing = false; v)

"The folder that the file picker of `v` starts in: the folder of its file, or the page's folder"
source_folder(v) = begin
  e = editor(v)
  from = source_from(v)
  path = isempty(from) || Saves.isurl(from) ? "" : abspath(docdir(e), expanduser(from))
  isfile(path) ? dirname(path) : isdir(docdir(e)) ? docdir(e) : homedir()
end

"The breadcrumb that picks the file that a save block or a chart reads"
from_picker(v::Union{SaveView,ChartView}) = block_part!(() -> Breadcrumb(at=source_folder(v), open=true, files=source_files(v)), v, :from_picker)

"Open the file picker of a save block or a chart, in the folder of its file or the page's"
pick_file!(v::Union{SaveView,ChartView}) = begin
  v.sourcing = true
  p = from_picker(v)
  p.at, p.open = source_folder(v), true
  v
end

"What a save block or a chart shows while it picks the file that it reads: what to do, a Close button, and the breadcrumb"
from_picker_section(v::Union{SaveView,ChartView}) = begin
  p = from_picker(v)
  p.room = editor(v).width - 24px
  words = v isa ChartView ? "Choose a CSV or TSV file to draw." : "Choose a CSV, TSV or JSON file to save the rows of."
  (Column(width(grow=grow), Alignment.Start, padding(10px, 12px, 10px, 12px), child_gap=8px, name="Picker",
     Row(width(grow=grow), Alignment.Center, child_gap=8px,
       Box(width(grow=grow), Text(words, size=12px, family=SANS, color=colours.dim, wrap=WrapMode.words)),
       block_button!(v, :close_picker, :close_picker, icon="x-lg", words="Close", tip="Close the list of files")),
     p),)
end

"When a file has been clicked in the file picker of `v`, it's where the rows of `v` come from, as a path from the page's folder"
from_pick_tick!(v::Union{SaveView,ChartView}) = begin
  v.sourcing || return v
  p = from_picker(v)
  isfile(p.at) && source_files(v)(p.at) || return v
  path = p.at
  # The next time the picker opens, it starts in a folder, not on this file
  p.at = dirname(path)
  set_source!(v, tilde(named(editor(v), path)))
end
