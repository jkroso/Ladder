# The view of a `chart` block: a table's numbers as bars, as lines or as a pie
#
# A code block in the language `chart` draws the numbers of a table of the
# page as bars, as lines or as a pie. chart.jl says how the block is written,
# and works out where each bar goes. A drop-down at the top of the chart
# chooses its kind, and another ticks the columns that it draws. The mouse
# over a bar, a dot or a slice says its number.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe reuse! window_of handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! rect popup! close_popup! placed! with_clip
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./pictures" picture
@use "./html" escape
@use "./markdown" Kind tablecells
@use "./sheet" folded
@use "github.com/jkroso/Units.jl" => Units
@use "./chart" => Charts
@use Colors: @colorant_str, RGBA
@use "./base" exports...
@use "./csv_view" exports...
@use "./takeoff_view" exports...
@use "./rows_from" exports...
@use "./media_view" chart_file file_table istable table_rows

export CHART_KINDS, CHART_MENU, ChartMenu, ChartMenuButton, ChartMenuRow, PIE_H, PLOT_H, PlotArea,
       cell_amount, chart_buttons_shown, chart_colour, chart_columns, chart_data, chart_hit,
       chart_html, chart_kind_place, chart_list_open, chart_measure, chart_menu_button, chart_part,
       column_shown, draw_marks, plain_cell, plot_height, row_count, shown!, table_amounts,
       take_chart_row!, toggle_column!

const PLOT_H = 260px   # how tall bars and lines are
const PIE_H = 220px    # and a pie
"The colour at place `k` of a chart. Past the eighth, the colours come round again darker, then lighter: see `Charts.shade`."
chart_colour(k::Integer) = begin
  cs = series_colours()
  place, shift = Charts.shade(k, length(cs))
  shift == 0 && return cs[place]
  c = convert(RGBA{Float64}, cs[place])
  towards(x) = shift > 0 ? x + (1 - x) * shift : x * (1 + shift)
  RGBA(towards(c.r), towards(c.g), towards(c.b), 1.0)
end

"The part of a chart that shows the bars, the lines or the pie"
@def mutable struct PlotArea <: SemanticUI
  of::Any = nothing
end

reread!(v::ChartView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.spec = Charts.chart(lines)
  v.shown = nothing
  v
end

"The text of a cell without the marks that make it bold or code"
plain_cell(text) = String(strip(replace(text, r"\*\*|__|`" => "")))

"""
Every table of the page that shows: each table, each spreadsheet and each
sheet. Each one has its first and last line, the heading that it's under, and
the text of each cell of each row. A formula's cell holds what the formula
comes to, and a cell with a sum in it holds what the sum shows. `headed` is true when the first row has the names of the columns.
"""
page_tables(e) = begin
  b = e.buf
  key = (:tables, b.path, b.version, table_reads[], sums_run[], page_day(e))
  haskey(e.flows, key) && return e.flows[key]
  ks = kinds(b)
  out = @NamedTuple{first::Int, last::Int, under::String, rows::Vector{Vector{String}}, headed::Bool, ranged::Bool}[]
  under = ""
  i = 1
  while i <= length(ks)
    k = ks[i]
    stop = i
    if k.kind == Kind.heading
      under = plain_cell(rest(b.lines[i], k.prefix))
    elseif k.kind == Kind.table
      run = table(b, i)
      if run !== nothing && run[1] == i
        # A chart draws what a sum in a cell shows, and not its code
        rows = [String[plain_cell(sums_shown(e, r, c.lo, rest(head(b.lines[r], c.hi), c.lo))) for c in tablecells(b.lines[r])] for r in tablerows(run)]
        push!(out, (first=i, last=run[2], under=under, rows=rows, headed=true, ranged=false))
        stop = run[2]
      end
    elseif k.kind == Kind.fence && k.level == 0
      t = codeblock(b, i)[2]
      if haskey(BLOCKS, k.lang) && t > i && ks[t].kind == Kind.fence && ks[t].level == 1
        block_tables!(BLOCKS[k.lang], e, i, t, under, out)
      end
      stop = max(i, t)   # a table in a block of code isn't one
    elseif k.kind == Kind.paragraph && (rows = table_rows(e, i)) !== nothing
      push!(out, (first=i, last=i, under=under, rows=rows, headed=true, ranged=false))   # a line that shows a CSV file as a table
    end
    i = stop + 1
  end
  e.flows[key] = out
end

"""
The rows that a chart draws: its own, or those of a table of the page. With
`from`, that's the first table under the heading that `from` names, or the
tables that it names with commas between them. Without it, it's the table
that's nearest above the chart, or the first one under it. `c` is what the
block says, or other settings to try, and `most` is as Charts.data has it.
"""
chart_data(e, v::ChartView, c::Charts.Chart=v.spec; most=Charts.MOST) = begin
  isempty(c.rows) || return Charts.data(c, c.rows; most)
  drawn = chart_file(e, c; most)   # `from` can name a CSV file
  drawn === nothing || return drawn
  tables = page_tables(e)
  k = isempty(c.from) ? something(findlast(t -> t.last < v.first, tables), findfirst(t -> t.first > v.last, tables), 0) :
                        something(named_table(e, tables, c.from), 0)
  k == 0 || return Charts.data(c, tables[k].rows, headed=tables[k].headed, by_first=tables[k].ranged, values=table_amounts(e, tables[k]), most=most)
  names = chart_sources(c)
  length(names) > 1 && return Charts.joined(c, [chart_part(e, c, tables, name; most) for name in names], names; most)
  Charts.nothing_to_draw(isempty(c.from) ?
    "This page has no table yet. Put a table, a spreadsheet or a sheet over this chart, and the chart draws its numbers." :
    "This page has no table called “$(c.from)”. A table is called by the heading over it, with a number after it for the second table under that heading.")
end

"The tables that the `from` of the chart `c` names, with commas between them. It's one name, or none, for a chart that draws one table."
chart_sources(c::Charts.Chart) = Charts.listed(c.from)

"What the chart `c` draws of `name`, one of the several tables that it draws: the table under a heading of the page, or a CSV file"
chart_part(e, c::Charts.Chart, tables, name; most=Charts.MOST) = begin
  if istable(name)
    t = file_table(abspath(docdir(e), expanduser(name)))
    return isempty(t.problem) ? Charts.data(c, t.rows, headed=true, part=true, most=most) : Charts.nothing_to_draw(t.problem)
  end
  k = named_table(e, tables, name)
  k === nothing && return Charts.nothing_to_draw("This page has no table called “$(name)”. A table is called by the heading over it.")
  Charts.data(c, tables[k].rows, headed=tables[k].headed, by_first=tables[k].ranged, part=true, values=table_amounts(e, tables[k]), most=most)
end

"The amount of each cell of a Markdown table, where the cell is one sum and the amount has a unit. Any other cell is nothing, and so is a table that isn't rows of the page."
table_amounts(e, t) = begin
  b = e.buf
  run = table(b, t.first)
  (run === nothing || run[1] != t.first) && return nothing
  rows = Vector{Any}[]
  for r in tablerows(run)
    push!(rows, Any[cell_amount(e, r, c.lo, rest(head(b.lines[r], c.hi), c.lo)) for c in tablecells(b.lines[r])])
  end
  rows
end

"The amount a cell holds, when the cell is one sum and that amount has a unit. The % in an amount goes into its number, as the cell shows it."
cell_amount(e, i::Int, col::Int, text::AbstractString) = begin
  m = match(r"!`([^`]+)`", text)
  m === nothing && return nothing
  strip(text) == INLINE * m[1] * "`" || return nothing
  code = String(m[1])
  n = ordinal(e, i, col + length(text, 1, m.offset) + 1, code)
  made(e, code, n)
  value = get(e.nodes, (:amount, e.buf.path, code, n), nothing)
  value isa Units.Unit || return nothing
  y = folded(value)
  y isa Units.Unit ? y : nothing
end

"What the chart shows. It's worked out again when the page has changed."
shown!(v::ChartView) = begin
  e = editor(v)
  key = (e.buf.version, v.first, v.lines, table_reads[], sums_run[], page_day(e))
  (v.shown !== nothing && v.shown[1] == key) || (v.shown = (key, chart_data(e, v)))
  v.shown[2]
end

"How wide `text` is in the font of a chart's words, at the size `size`"
chart_measure(text, size) = num(measure(Face(SANS, "", px(size), colours.ink, false), text))

"The three kinds of chart: the icon of each one, and its name in the list of kinds"
const CHART_KINDS = ((:bars, "bar-chart", "Bars"), (:lines, "graph-up", "Lines"), (:pie, "pie-chart", "Pie"))
const CHART_MENU = :chart_menu   # the key of the list that a button at the top of a chart opens
push!(BLOCK_ICONS, "list-check", "square", "check2-square", "chevron-down")

"""
A button at the top of a chart that opens a list under it. One is for the
kind of chart, and shows the icon of the kind that it is now. Its list makes
the chart bars, lines or a pie. The other is for the columns of numbers. Its
list has a tick box for each column of the table, and the chart draws the
columns that are ticked. Each button is only an icon, so the title has room.
"""
@def mutable struct ChartMenuButton <: SemanticUI
  of::Any = nothing     # the chart
  what::Symbol = :kind  # :kind or :columns
  open::Bool = false    # its list shows
end
"""
The list that floats under such a button. The arrows pick a row, and Return or
a click takes it. A kind closes the list. A column is ticked or unticked, and
the list stays for the next one. Esc, or a click somewhere else, closes it.
"""
@def mutable struct ChartMenu <: SemanticUI
  button::Any = nothing
  side::Symbol = :bottom               # the side of the button that it's on
  pick::Int = 1                        # the row that Return takes
  seen::Int = 0                        # the row that was picked when it was last drawn. A row that the keys pick is brought in sight.
  names::Vector{String} = String[]     # the columns of a list of columns, in the order of their table
  rows::Vector{Any} = Any[]            # its rows, kept between frames
  scroll::Any = nothing                # what scrolls a long list
end
"A row of that list: a kind of chart, or a column"
@def mutable struct ChartMenuRow <: SemanticUI
  menu::Any = nothing
  k::Int = 0
end

"The place in CHART_KINDS of the kind of the chart `v`"
chart_kind_place(v::ChartView) = something(findfirst(k -> k[1] == v.spec.kind, CHART_KINDS), 1)

"The button of the chart `v` that opens the list of `what`: :kind or :columns"
chart_menu_button(v::ChartView, what::Symbol) = block_part!(() -> ChartMenuButton(of=v, what=what), v, what)

"""
The columns of numbers that the chart `v` can draw, in the order of their
table. They're the columns that a `show` line can name, so a column with no
heading isn't one of them.
"""
chart_columns(v::ChartView) = begin
  e, c = editor(v), v.spec
  showing(names) = Charts.Chart(:bars, "", c.by, names, c.from, c.rows, String[])
  several = several_sources(e, c)
  every = isempty(several) ? [chart_data(e, v, showing(String[]), most=typemax(Int))] :
                             [chart_part(e, showing(String[]), page_tables(e), name, most=typemax(Int)) for name in several]
  found = unique(s.name for d in every for s in d.series if !isempty(s.name))
  filter(name -> isempty(chart_data(e, v, showing([name])).problem), found)
end

"True when the chart `v` draws the column `name`: its `show` line names it, or it has no `show` line"
column_shown(v::ChartView, name) = isempty(v.spec.show) || any(n -> Charts.same(n, name), v.spec.show)

"""
Tick or untick the column `name` of the list `m`, so that the chart draws it
or stops drawing it. The `show` line names the columns that are ticked, and
it goes when every column is. The last column that's ticked stays ticked,
because a chart draws one column at least.
"""
toggle_column!(m::ChartMenu, name) = begin
  v = m.button.of
  on = filter(n -> column_shown(v, n), m.names)
  if column_shown(v, name)
    length(on) == 1 && return handled
    filter!(n -> !Charts.same(n, name), on)
  else
    on = filter(n -> n in on || Charts.same(n, name), m.names)
  end
  c = deepcopy(v.spec)
  c.show = length(on) == length(m.names) ? String[] : on
  write_block!(v, CHART, Charts.written(c))
  handled
end

"How many rows the list `m` has"
row_count(m::ChartMenu) = m.button.what == :kind ? length(CHART_KINDS) : length(m.names)

"Take row `k` of the list `m`: make the chart that kind and close the list, or tick that column"
take_chart_row!(m::ChartMenu, k, w) = begin
  b = m.button
  k in 1:row_count(m) || return handled
  b.what == :columns && return toggle_column!(m, m.names[k])
  b.open = false
  close_popup!(w, CHART_MENU)
  act!(b.of, (:kind, CHART_KINDS[k][1]), w)
end

describe(b::ChartMenuButton) = begin
  icon = b.what == :kind ? CHART_KINDS[chart_kind_place(b.of)][2] : "list-check"
  Row(height(26px), padding(7px, 0px), child_gap=4px, radius(6px), Alignment.Center, name=b.what == :kind ? "Kind" : "Columns",
      border(1px, :solid, b.open ? colours.accent : colours.line), background(ishovered(b) ? colours.hover : colours.bg),
    Icon(icon, size=14px, color=colours.dim), Icon("chevron-down", size=9px, color=colours.dim))
end

cursor(::ChartMenuButton) = :hand
# The button shows what's on now, so its tooltip says what a click does
onmouse(b::ChartMenuButton, ev::MouseMove) = b.open ? nothing :
  show_tooltip!(ev.window, tip_label(b.what == :kind ? "Choose bars, lines or a pie" : "Choose the columns that the chart draws"), b,
                placement=:bottom, gap=6px)
onkey(b::ChartMenuButton, ev::KeyPress{Keys.mouse_left}) = begin
  v = b.of
  hide_tooltip!(ev.window)
  names = b.what == :columns ? chart_columns(v) : String[]
  pick = b.what == :kind ? chart_kind_place(v) : 1
  b.open = true
  menu = v.parts[(:menu, b.what)] = ChartMenu(button=b, pick=pick, names=names)
  popup!(ev.window, menu, anchor=b, placement=:bottom, gap=9px, width=b.what == :kind ? 150px : 220px, key=CHART_MENU,
         onclose=() -> (b.open = false), theme=component_theme(editor(v).zoom))
  handled
end

describe(m::ChartMenu) = begin
  n = row_count(m)
  length(m.rows) == n || (m.rows = Any[ChartMenuRow(menu=m, k=k) for k in 1:n])
  n == 0 && return float_list(nothing, float_none("The table has no column of numbers"), name="Columns")
  m.scroll === nothing && (m.scroll = Scroll(width(grow=grow)))
  # Half a row at the bottom says that the list goes on
  m.scroll.height = height(n <= MOST_CHOICES ? n * FLOAT_ROW : MOST_CHOICES * FLOAT_ROW - FLOAT_ROW / 2)
  m.seen == m.pick || (m.seen = m.pick; scroll_into_view!(m.scroll, FLOAT_ROW * (m.pick - 1), FLOAT_ROW * m.pick))
  float_list(nothing, reuse!(m.scroll, Column(width(grow=grow), Alignment.Start, m.rows...)), name=m.button.what == :kind ? "Kinds" : "Columns")
end

placed!(m::ChartMenu, side) = (m.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, m::ChartMenu) = caret(ctx, ui, m.side, rect(m.button))

onkey(m::ChartMenu, ev::KeyPress{Keys.down}) = unmodified(ev) ? (m.pick = min(m.pick + 1, max(1, row_count(m))); handled) : nothing
onkey(m::ChartMenu, ev::KeyPress{Keys.up}) = unmodified(ev) ? (m.pick = max(m.pick - 1, 1); handled) : nothing
onkey(m::ChartMenu, ev::KeyPress{Keys.enter}) = unmodified(ev) ? take_chart_row!(m, m.pick, ev.window) : nothing

describe(r::ChartMenuRow) = begin
  m = r.menu
  v = m.button.of
  r.k <= row_count(m) || return Box(height(0px))
  if m.button.what == :kind
    _, icon, name = CHART_KINDS[r.k]
    return float_row(name, picked=m.pick == r.k, on=chart_kind_place(v) == r.k, icon=icon)
  end
  name = m.names[r.k]
  on = column_shown(v, name)
  float_row(name, picked=m.pick == r.k, icon=on ? "check2-square" : "square", tint=on ? colours.accent : nothing)
end

cursor(::ChartMenuRow) = :hand
onkey(r::ChartMenuRow, ev::KeyPress{Keys.mouse_left}) = take_chart_row!(r.menu, r.k, ev.window)
# The mouse picks the row that it's over, as the arrow keys do. It's in sight already, so the list doesn't scroll to it.
onmouse(r::ChartMenuRow, ::MouseMove) = (m = r.menu; m.pick = m.seen = r.k; handled)

"True when one of the lists of the chart `v` is open: its kinds, its columns, its tables or its files"
chart_list_open(v::ChartView) = begin
  v.sourcing && return true
  any(k -> (b = get(v.parts, k, nothing); b !== nothing && b.open), (:kind, :columns)) && return true
  c = get(v.parts, :sources, nothing)
  c !== nothing && c.asking !== nothing
end

"""
True when the chart `v` shows its three buttons: while the mouse is on the
chart, or one of their lists is open. At other times its bar shows only its
title, so the title has the whole bar. A chart with no title has no bar at
those times.
"""
chart_buttons_shown(v::ChartView) = ishovered(v) || chart_list_open(v)

describe(v::ChartView) = begin
  e = editor(v)
  d = shown!(v)
  with_theme(component_theme(e.zoom)) do
    # The title's row is as tall as the bar, so what it clips is only a title too long for it. A row as tall as the text
    # would clip the tails of letters like p and y, which hang under the text's box.
    title = isempty(v.spec.title) ? () : (Row(width(grow=grow), height(grow=grow), padding(6px, 0px), Alignment.Center, clip=true,
                                              Box(label(v.spec.title, 13px, weight="Semibold"))),)
    buttons = chart_buttons_shown(v)
    bar = buttons ?
      block_bar(chart_menu_button(v, :kind), Box(width(4px)), source_button(v), Box(width(4px)), chart_menu_button(v, :columns),
                (isempty(title) ? () : (rule(), title...))...) :
      block_bar(title...)
    plot = isempty(d.problem) ? block_part!(() -> PlotArea(of=v), v, :area) : block_note(d.problem)
    # A chart with no title has no room kept for its bar. The buttons lie over the top of the chart while the mouse is on it.
    # The list of tables and files goes under the bar, so while it's open the bar has its own room.
    isempty(title) && !v.sourcing && return Stack(block_look()..., clip=true, name="Chart", plot, (buttons ? (bar,) : ())...)
    Column(block_look()..., clip=true, name="Chart", bar, (v.sourcing ? from_picker_section(v) : ())..., plot)
  end
end

cursor(::Union{ChartView,PlotArea}) = :arrow

act!(v::ChartView, action, w) = begin
  action == :close_picker && return (v.sourcing = false; handled)
  action isa Tuple && action[1] == :kind || return handled
  v.spec.kind = action[2]
  write_block!(v, CHART, Charts.written(v.spec))
  handled
end

describe(a::PlotArea) = Box(width(grow=grow), height(plot_height(a.of)))

"How tall the chart `v` is: a pie, or bars and lines with room for the names of their axes"
plot_height(v::ChartView) = (v.spec.kind == :pie ? PIE_H : PLOT_H) + px(Charts.axis_room(shown!(v), v.spec.kind))

"The mark of the chart that the mouse is over, or nothing"
chart_hit(v::ChartView) = begin
  w = window_of(v)
  w === nothing ? nothing : Charts.hit(v.marks, num(w.mouse[1]) - v.box[1], num(w.mouse[2]) - v.box[2])
end

"Draw the marks of a chart, with the top left corner of the chart at `(x0, y0)`. The mark `hot` is the one under the mouse."
draw_marks(ctx, marks, x0, y0, hot=nothing; lit=0) = begin
  surface = takeoff_back()
  for m in marks
    # While the mouse is over a bar or a slice, the others are pale. So are the bars of the other rows,
    # while the mouse is on a row of the chart's table: the row at place `lit`.
    pale = m.kind in (:bar, :slice) && (hot !== nothing ? (m.label, m.series) != (hot.label, hot.series) : lit > 0 && m.label != lit)
    colour = m.colour == 0 ? colours.dim : chart_colour(m.colour)
    pale && (colour = RGBA(colour, 0.4))
    x, y = x0 + m.at[1], y0 + m.at[2]
    if m.kind == :rule
      trace(ctx, [(x, y), (x0 + m.at[3], y0 + m.at[4])], RGBA(colours.ink, m.style == :strong ? 0.3 : 0.08), 1.0)
    elseif m.kind == :bar
      w, h = m.at[3], m.at[4]
      # Only the end that's away from the line of 0 has round corners, so the box is drawn longer and cut off at that line
      with_clip(ctx, px(x), px(y), px(w), px(h)) do
        round_box(ctx, x, m.style == :down ? y - 4 : y, w, h + 4, min(4.0, w / 2); fill=colour)
      end
    elseif m.kind == :line
      trace(ctx, [(x0 + a, y0 + b) for (a, b) in m.points], colour, 2.0)
    elseif m.kind == :dot
      on = hot === m || (hot === nothing && lit > 0 && m.label == lit)
      r = on ? 5.5 : m.at[3]
      r > 0 || continue
      disc(ctx, x, y, r + 2, surface)   # a ring in the colour of the page keeps it apart from the line that it's on
      disc(ctx, x, y, r, colour)
    elseif m.kind == :slice
      trace(ctx, [(x0 + a, y0 + b) for (a, b) in m.points], surface, 2.0; fill=colour, closed=true)
    elseif m.kind == :swatch
      round_box(ctx, x, y, m.at[3], m.at[4], 2.5; fill=colour)
    elseif m.kind == :words
      face = Face(SANS, "", px(m.size), m.tone == :ink ? colours.ink : colours.dim, false)
      wide = num(measure(face, m.text))
      write_ink(ctx, m.text, m.style == :end ? x - wide : m.style == :middle ? x - wide / 2 : x, y, face)
    end
  end
end

draw(ctx, size, ui::ConcreteRect, a::PlotArea) = begin
  v = a.of
  v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  v.box[3] > 0 || return
  v.marks = Charts.plot(shown!(v), v.spec.kind, v.box[3], v.box[4], chart_measure)
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    hot = ishovered(a) ? chart_hit(v) : nothing
    # The row of the table that the mouse is on, in another part of the page, has its bars marked
    lit = hot === nothing ? something(findfirst(name -> marked(v, name), shown!(v).labels), 0) : 0
    draw_marks(ctx, v.marks, v.box[1], v.box[2], hot; lit)
  end
end

# The mouse over a bar, a dot or a slice says its number
onmouse(a::PlotArea, ev::MouseMove) = begin
  v = a.of
  m = Charts.hit(v.marks, num(ev.position[1]) - v.box[1], num(ev.position[2]) - v.box[2])
  m === nothing && return nothing
  x, y = v.box[1] + m.at[1], v.box[2] + m.at[2]
  spot = m.kind == :bar ? (x, y, m.at[3], m.at[4]) : m.kind == :dot ? (x - 6, y - 6, 12.0, 12.0) :
         (mid = (m.at[3] + m.at[4]) / 2; (x + 0.6m.size * cos(mid) - 4, y + 0.6m.size * sin(mid) - 4, 8.0, 8.0))
  show_tooltip!(ev.window, tip_label(Charts.said(shown!(v), m)), px.(spot)..., placement=:top, gap=6px)
  handled
end

"The chart as HTML: its title, and a picture of it"
chart_html(e, v::ChartView) = begin
  d = shown!(v)
  isempty(d.problem) || return nothing
  wide, tall = 720.0, num(plot_height(v))
  picture = Charts.svg(Charts.plot(d, v.spec.kind, wide, tall, chart_measure), wide, tall, colours=css_colour.(SERIES_LIGHT),
                       ink="#2b2622", dim="#6b6259", line="#e6e0d0", surface="#fdfcf9", family="-apple-system, Helvetica, sans-serif")
  title = isempty(v.spec.title) ? "" : "<p><strong>$(escape(v.spec.title))</strong></p>\n"
  "<div class=\"diagram\">\n$title$picture\n</div>"
end

BLOCKS[CHART] = ChartView
block_name(::Type{ChartView}) = "Chart"
block_icon(::Type{ChartView}) = "bar-chart"
block_insert(::Type{ChartView}) = ("Chart", ["```$CHART", "```", "", ""], (4, 0))
block_html(e, v::ChartView) = chart_html(e, v)
