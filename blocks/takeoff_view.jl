# The view of a `takeoff` block: measures on a plan
#
# A code block in the language `takeoff` shows a plan that you measure from: a
# page of a PDF file, or a picture. takeoff.jl says how the block is written.
# Click it with ⌥ held to see its lines, or as plain text put the caret in the block.
#
#   - Drop a PDF file or a picture on the block, or click it, to choose the plan.
#   - Set the scale: type it, like 1:100, or choose the ruler, click the two ends
#     of a length that you know and type how long it is.
#   - Two buttons under the table start a measure. Add a measure asks what it
#     measures: type a few words that describe it, like "Double power point".
#     Its item is defined later: the measure is matched to one in Centient.
#     Add from catalogue asks for an item of Centient's catalogue, and shows
#     only on a Mac that has Centient. The item gives the measure its name, and
#     its unit says what the measure is and chooses the tool: a length for an
#     item sold by the metre, an area for one sold by the square metre, and a
#     count for the rest.
#   - A measure with no item and nothing drawn yet is what the tool you choose
#     makes it. A click on a measure in the list chooses its tool too.
#   - The table has no column for a measure's name. A measure with no item
#     shows its words, and a click on them, when it's the measure that's
#     chosen, changes them. A measure with an item shows the item's name, then
#     the catalogue that it's from, and the same click chooses another item.
#   - The table has columns for the price of one and for the cost while a
#     measure has an item. With none, there's no price to show.
#   - What a search of Centient finds shows in a list that floats beside the
#     text field. The search for an item looks in one catalogue at a time: the
#     business's own items, or a supplier's that ⌥ lets you choose. The headings of the table of measures sort and search it.
#   - A click on the unit after a measure's amount lists the units that it can
#     be in, as Centient's unit picker does. Type to search them. The amount
#     shows in the unit that you choose, and the quote's line is in it too. A
#     measure with nothing drawn and no item can take a unit of another kind,
#     and that changes what it measures.
#   - A count takes a mark for each click. A length and an area take a corner for
#     each click. To end one, click the Done button beside its last corner,
#     click twice, or press Return. An area also ends with a click on its
#     first corner.
#   - A corner snaps to the lines of a PDF plan: to the end of a line, to the
#     place where two lines cross, or to the nearest point of a line. A small
#     mark shows where it will go. It snaps to the corners of what's already
#     measured too. The magnet turns snapping off, and so does ⌘ while it's held.
#   - The tool after the area tool cuts a shape out of an area, like a window
#     out of a wall. Draw its outline over the area. What the area comes to is
#     then without the part of the cut-out that's in it. A cut-out is selected,
#     moved and taken away like any outline, and it goes when its area does.
#   - With the arrow, click a mark or a line to select it, drag a corner to move
#     it, and press Delete to take it away. Drag the plan to move it.
#   - A mouse wheel makes the plan bigger and smaller round the mouse, and so
#     does a pinch. Two fingers on the trackpad move the plan. With ⌘ held, they
#     make it bigger and smaller. In the page, the wheel and two fingers move
#     the page until you click the plan. A plan that shows whole stays put.
#   - The button with four arrows makes the block fill the window, with the list
#     of measures beside the plan or under it. Esc puts it back in the page.
#   - V, C, L, A, X and S choose the tools. Esc drops what's half drawn. ⌘Z takes
#     the last change back.
#   - Choose the customer, then Make quote in Centient. Centient makes a quote
#     with a line for each measure. A measure with an item is priced from the
#     catalogue. One with none is a line of its words, to price in Centient.
#
# Every change is written into the block's lines, so the file holds the whole
# takeoff. The catalogue, the contacts and the quote come from Centient through
# its MCP server, which centient.jl starts. Centient's app needn't be open.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl/skia" rounded_rectangle
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe reuse! window_of focus handled inputs version
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! redraw_in! rect popup! close_popup! MouseScroll Pinch onpinch placed! with_clip with_round_clip
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring jstring with_pool
@use "github.com/jkroso/UI.jl/Interface/fonts" skia_font
@use "github.com/jkroso/UI.jl/Interface/image" image_source
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "../files/pictures" pdf_pages pdf_page pdf_size pdf_part pdf_lines
@use "../html" escape
@use "../markdown" words
@use "./sheet" parts known shown
@use "./spreadsheet" moved
@use "./takeoff" => Plans
@use "../centient" => Centient
@use Colors: @colorant_str, RGBA
@use "../base" exports...

export TAKEOFF, PLAN_LEAST, REACH, SNAP, NEAR, SETTLED, QUICK, MOST_FOUND, SIDE_W, HUES, PLAN_TOOLS,
       PLAN_ICONS, hue, Sharp, TakeoffView, PlanArea, MeasureRow, AmountCell, UnitWord, UnitMenu, UnitRow,
       MeasureCell, ColumnHead, HeadWords, ColumnMenu, SortRow, FoundRow, CatalogueFoot, FoundList,
       plan_input, plan_path, ispdf, plan_pages, plan_size, plan_h, plan!, choose_plan!, takeoff_at,
       takeoff_lines, lookup!, dollars, unit_price, cost_of, quote_line, make_quote!, settle_asking!,
       metres_typed, scale!, choose_row!, page_point, window_point, plan_lines, lines_of, aim, PAPER_EDGE,
       zoom_plan!, density, sharpen!, PAPER_ROUND, paper!, draw_plan, plan_ink, snap_mark, dot, tag,
       size_text, cut_text, draw_shapes, DONE_W, DONE_H, DONE_GAP, done_box, on_done, over_done, done_tip,
       draw_done, over_shape, first_name, FIRST_NAME, KIND_WORDS, sold_by, kind!, measure!, CUT_NOWHERE,
       finish_shape!, tool!, remove_picked!, swatch, price_text, item_name, choose_measure!, UNIT_KEY,
       AMOUNT_W, MOST_UNITS, units_for, fold_unit, UNIT_EXTRAS, unit_matches, names_unit, unit_word,
       open_units!, unit!, float_list, float_none, FOUND_KEY, ITEM_FROM, browse!, toggle_catalogue!,
       catalogue_words, lists_suppliers, found_h, show_found!, FOUND_GAP, settle_side!, HEAD_KEY, COLUMNS,
       item_words, column_value, search_column!, shown_measures, head_words, next_order, prompt, has_items,
       has_price, adders, measure_rows, foot, list_h, LIST_SHARE, goes_beside, shown_state

const TAKEOFF = Plans.TAKEOFF
const PLAN_LEAST = 220px      # how tall the plan's view is at the least
const REACH = 7.0             # px. A corner or a line that's this near the mouse is under it.
const SNAP = 8.0              # px. A corner that's put this near a line of the plan goes on the line.
const NEAR = 24.0             # the most px to a point of the page: as big as the plan gets
const SETTLED = 0.15          # seconds after the plan last moved until a plan that's slow to draw is drawn sharp
const QUICK = 0.012           # seconds. A plan that's drawn in less is drawn sharp while it moves.
const MOST_FOUND = 8          # the lines of the list under a search
const SIDE_W = 380px          # how wide the list of measures is beside a plan that fills the window
const HUES = (colorant"rgb(222,72,58)", colorant"rgb(38,120,214)", colorant"rgb(30,150,90)", colorant"rgb(232,140,24)",
              colorant"rgb(140,84,208)", colorant"rgb(18,160,170)", colorant"rgb(214,70,150)", colorant"rgb(128,104,72)")
"The tools of a takeoff, in the order of their buttons: the icon of each, what it says of itself, and the letter that chooses it"
const PLAN_TOOLS = (:select => ("cursor", "Select and move  V", 'v'), :count => ("plus-circle", "Count  C", 'c'),
                    :length => ("vector-pen", "Measure a length  L", 'l'), :area => ("pentagon", "Measure an area  A", 'a'),
                    :cut => ("subtract", "Cut a shape out of an area  X", 'x'),
                    :scale => ("rulers", "Set the scale from a length that you know  S", 's'))
"Every icon that a takeoff can show. The built app reads them all when it's made."
const PLAN_ICONS = ["cursor", "plus-circle", "vector-pen", "pentagon", "rulers", "chevron-left", "chevron-right", "zoom-out", "zoom-in",
                    "aspect-ratio", "file-earmark-pdf", "x-lg", "plus-lg", "map", "person", "receipt", "arrows-fullscreen", "fullscreen-exit",
                    "chevron-up", "chevron-down", "check", "subtract", "magnet", "box-seam"]

"The colour of the measure at place `i` in the list"
hue(i) = HUES[mod1(i, length(HUES))]

"The part of a page of a PDF plan that a takeoff shows, as a picture that Skia draws. It's kept until the view moves."
mutable struct Sharp
  of::Any                         # what it's a picture of
  image::Ptr{Skia.sk_image_t}
  cost::Float64                   # seconds that the last one took to draw
end

"What a `takeoff` block shows: the plan, the tools and the list of measures"
@def mutable struct TakeoffView <: SemanticUI
  n::Int = 0                              # its place among the page's takeoffs
  first::Int = 0                          # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Plans.Takeoff = Plans.Takeoff()
  lines::Vector{String} = String[]        # the lines that `data` was read from
  tool::Symbol = :select
  current::Int = 0                        # the measure that the tools draw for: its place in the list, or 0
  picked::Any = nothing                   # what's selected on the plan: the place of its measure and its shape, and of its point if it's one corner
  draft::Vector{Plans.Point} = Plans.Point[]   # the corners so far of what's being drawn
  zoom::Float64 = 0.0                     # px to a point of the page. 0 fits the page in the view.
  at::Plans.Point = (0.0, 0.0)            # the point of the page at the view's top left
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the view was last drawn in the window: its left, top, width and height
  fitted::Any = nothing                   # the file and the page that the zoom is for
  mouse::Any = nothing                    # the point of the page under the mouse, or the one near it that a corner snaps to
  aim::Any = nothing                      # what `mouse` snapped to: :corner, :crossing or :line, or nothing when it's where the mouse is
  snap::Bool = true                       # corners snap to the lines of the plan
  grab::Any = nothing                     # a drag: of the plan, or of a corner
  clicked::NTuple{3,Float64} = (0.0, 0.0, 0.0)   # when and where the plan was last clicked
  moved::Float64 = 0.0                    # when the view last moved
  asking::Any = nothing                   # what the text field is for: (:name, i), (:item, i), (:extra, i), (:scale,), (:length, a, b) or (:customer,)
  query::String = ""                      # the words that were last searched for
  typed::Float64 = 0.0                    # when the words in the text field last changed
  search::Any = nothing                   # the search that Centient hasn't answered yet
  rows::Vector{Any} = Any[]               # what the last search found
  pick::Int = 1                           # the row of them that Return takes
  known::Dict{String,Any} = Dict{String,Any}()   # what Centient says of each item: its name, its unit, its price
  lookup::Any = nothing                   # the request for those that Centient hasn't answered yet
  quoting::Any = nothing                  # the request for a quote that Centient hasn't answered yet
  said::String = ""                       # what the foot of the block says
  wrong::Bool = false                     # it says what went wrong
  parts::Dict{Any,Any} = Dict{Any,Any}()  # its buttons, rows and text field, kept between frames
  sharp::Sharp = Sharp(nothing, C_NULL, 1.0)
  full::Bool = false                      # it fills the window, over the page
  beside::Bool = false                    # it fills the window with its list of measures beside the plan, not under it
  tall::px = 0px                          # how tall it was in the page when it was last laid out there
  pinned::px = 0px                        # how far the page was scrolled when it filled the window
  sort::Any = nothing                     # the column that the table of measures is sorted by, and which way: (:cost, :desc)
  filters::Dict{Symbol,String} = Dict{Symbol,String}()   # the words that a column's text must have for the table to show a measure
  order::Vector{Int} = Int[]              # the measures that the table shows, in the order that it shows them
  reads::UInt = UInt(0)                   # what its parts read, as one number. See `shown_state`.
  measured::Int = -1                      # the `version` of its geometry when `tall` was measured
end

"The part of a takeoff that shows the plan"
@def mutable struct PlanArea <: SemanticUI
  of::Any = nothing
end
"A measure in a takeoff's list"
@def mutable struct MeasureRow <: SemanticUI
  of::Any = nothing
  i::Int = 0
end
"The amount of a measure in its row: the number, then the unit that it's in"
@def mutable struct AmountCell <: SemanticUI
  of::Any = nothing
  i::Int = 0
  unit::Any = nothing   # its UnitWord
end
"The unit after a measure's amount. A click on it shows the list of units that the measure can be in."
@def mutable struct UnitWord <: SemanticUI
  of::Any = nothing     # the AmountCell
end
"The list of units that floats under a measure's amount, with a field that searches it"
@def mutable struct UnitMenu <: SemanticUI
  of::Any = nothing
  i::Int = 0
  side::Symbol = :bottom   # the side of the amount that it's on
  pick::Int = 0            # the row that was picked when it was last drawn. A row that the keys pick is brought in sight.
end
"A unit in the list of units"
@def mutable struct UnitRow <: SemanticUI
  of::Any = nothing
  k::Int = 0
end
"A part of a measure's row that a click changes: its item, or what it adds for waste"
@def mutable struct MeasureCell <: SemanticUI
  of::Any = nothing
  i::Int = 0
  what::Symbol = :item
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn: its width cuts its words short, and its tooltip goes under it
  full::String = ""                           # its words when they're cut short with …, to show in its tooltip, or "" when they fit
end
"""
The heading of a column of the table of measures. It fills the column's cell, so
the mouse can be anywhere over the column to use it. A click sorts by the
column, or opens a menu that sorts and searches it.
"""
@def mutable struct ColumnHead <: SemanticUI
  of::Any = nothing
  key::Symbol = :item
  side::Symbol = :start   # the side of the cell that its words go on: :start, or :end over numbers that line up on the right
  words::Any = nothing    # its HeadWords
end
"The words of a column's heading, and the arrow of its order. The heading's menu and tooltip point at them."
@def mutable struct HeadWords <: SemanticUI
  of::Any = nothing   # the heading
end
"The menu of a column of text: its two orders and a field to search it. It floats under the heading, as it does in Centient's lists."
@def mutable struct ColumnMenu <: SemanticUI
  of::Any = nothing
  key::Symbol = :item
  side::Symbol = :bottom   # the side of the heading that it's on
end
"One of the two orders in the menu of a column"
@def mutable struct SortRow <: SemanticUI
  of::Any = nothing
  key::Symbol = :item
  dir::Symbol = :asc
end
"A line of the list that a search shows: an item of Centient's catalogue, or a contact"
@def mutable struct FoundRow <: SemanticUI
  of::Any = nothing
  k::Int = 0
end
"The foot of the list of items: the catalogue that the list shows. A click on it shows another."
@def mutable struct CatalogueFoot <: SemanticUI
  of::Any = nothing
end
"""
The list of what a search found. It floats beside the text field with an arrow
that points at the field, the way the lists in Centient's own forms do.
"""
@def mutable struct FoundList <: SemanticUI
  of::Any = nothing
  side::Symbol = :bottom   # the side of the text field that it's on
  rows::Any = nothing      # what it showed last. A new list starts at its top.
  pick::Int = 0            # the row that was picked when it was last drawn. A row that the keys pick is brought in sight.
  popup::Any = nothing     # what UI.jl floats it in
  settled::Bool = false    # its side of the text field is chosen, and it keeps that side while it's open
end

"The text field of a takeoff. One field does for the name of a measure, a search, the scale and the rest."
plan_input(v::TakeoffView) = part!(v, :input) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

# --- the plan's file ---------------------------------------------------------------------

"The file of the plan, or \"\" when the block names none that's there"
plan_path(v::TakeoffView) = begin
  isempty(v.data.plan) && return ""
  path = abspath(docdir(editor(v)), expanduser(unescaped(v.data.plan)))
  isfile(path) ? path : ""
end

ispdf(path) = lowercase(splitext(path)[2]) == ".pdf"

"How many pages the plan has"
plan_pages(v::TakeoffView) = (path = plan_path(v); isempty(path) ? 0 : ispdf(path) ? pdf_pages(path) : 1)

"""
How wide and how tall the page that shows is, in points, or nothing when there's
no plan to show. A picture has a point for each of its pixels.
"""
plan_size(v::TakeoffView) = begin
  path = plan_path(v)
  isempty(path) && return nothing
  ispdf(path) && return pdf_size(path, v.data.page)
  key = picture_key(path)
  key === nothing && return nothing
  source = image_source(key)
  (Float64(source.width), Float64(source.height))
end

"How tall the plan's view is in a block that's `w` wide: tall enough for the whole page, and no taller than leaves room for the list"
plan_h(v::TakeoffView, w::px) = begin
  s = plan_size(v)
  s === nothing && return 180px
  _, tall = window_size(editor(v))
  clamp((w - 2px(PAPER_EDGE)) * s[2] / s[1] + 2px(PAPER_EDGE), PLAN_LEAST, max(PLAN_LEAST, tall - 280px))
end

"Make the file at `path` the plan"
plan!(v::TakeoffView, path) = begin
  v.data.plan = named(editor(v), path)
  v.data.page = 1
  v.zoom = 0.0
  empty!(v.draft)
  commit!(v)
end

"Ask which file holds the plan, with macOS's own panel"
choose_plan!(v::TakeoffView, w) = begin
  # A window that isn't on the screen, like one a test makes, has no panel to ask with
  (Sys.isapple() && !isempty(w.glfw)) || return handled
  path = with_pool() do
    panel = msg(cls("NSOpenPanel"), "openPanel")
    msg(panel, "setDirectoryURL:", msg(cls("NSURL"), "fileURLWithPath:", nsstring(docdir(editor(v)))))
    # 1 is the panel's Open button
    ccall((:objc_msgSend, libobjc), Int, (Ptr{Cvoid}, Ptr{Cvoid}), panel, sel("runModal")) == 1 || return nothing
    jstring(msg(msg(panel, "URL"), "path"))
  end
  # The panel took the mouse, so the window never heard its button come up
  Keys.mouse_left in w.keys && (w.keys ⊻= Keys.mouse_left)
  path === nothing || plan!(v, path)
  handled
end

"The takeoff under the mouse, or nothing"
takeoff_at(e, w) = begin
  x, y = w.mouse
  for node in values(e.nodes)
    node isa TakeoffView || continue
    r = rect(node)
    r !== nothing && r.left <= x < r.left + r.width && r.top <= y < r.top + r.height && return node
  end
  nothing
end

# --- the block's lines -------------------------------------------------------------------

"The first and the last line of the `n`th takeoff block of `b`, or nothing"
takeoff_lines(b::Buffer, n::Int) = block_lines(b, TAKEOFF, n)

"Read the takeoff again from the lines of its block, if they've changed"
reread!(v::TakeoffView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Plans.takeoff(lines)
  v.current = min(v.current, length(v.data.measures))
  v.picked = nothing
  v
end

"""
Write the takeoff into its block. The caret stays where it was in the text, and
⌘Z takes the change back. If the block's lines aren't the ones that the takeoff
was read from, something else changed them, and the takeoff is read again.
"""
commit!(v::TakeoffView) = begin
  b = editor(v).buf
  readonly(b) && return v
  span = takeoff_lines(b, v.n)
  span === nothing && return v
  i, t = span
  v.first, v.last = i, t
  b.lines[i+1:t-1] == v.lines || return reread!(v, b.lines[i+1:t-1])
  write_block!(v, TAKEOFF, Plans.written(v.data), reread=false)
end

# While nothing that a takeoff shows changes, its geometry is kept (see `shown_state`), and so is its height.
measure_block!(e, v::TakeoffView) = begin
  g = geometry(v)
  if version(v) == 0 || version(v) != v.measured
    v.tall = describe(Column(fixed(e.width), Alignment.Start, g), (e.width, 9999px)).height
    v.measured = version(v)
  end
  v.tall
end

# --- Centient ----------------------------------------------------------------------------

"What Centient says of the item that `ref` names, or nothing if it hasn't said yet"
known(v::TakeoffView, ref) = isempty(ref) ? nothing : get(v.known, ref, nothing)

"Ask Centient for the items of the takeoff that it hasn't told of yet. The plan's view asks when it's drawn, so a takeoff that's out of sight asks nothing."
lookup!(v::TakeoffView) = begin
  v.lookup === nothing || return
  refs = unique!([m.item for m in v.data.measures if !isempty(m.item) && !haskey(v.known, m.item)])
  (isempty(refs) || !Centient.available()) && return
  # An item that Centient doesn't have is asked for once
  foreach(ref -> v.known[ref] = nothing, refs)
  v.lookup = Centient.ask("lookup_items", Dict("refs" => refs))
  nothing
end

"A sentence at the foot of the block. `wrong` shows it as something that went wrong."
say!(v::TakeoffView, words, wrong=false) = (v.said = String(words); v.wrong = wrong; handled)

"An amount of money: \$1,234.50"
dollars(x::Real) = begin
  cents = round(Int, 100x)
  (cents < 0 ? "-" : "") * "\$" * commas(abs(cents) ÷ 100) * "." * lpad(abs(cents) % 100, 2, '0')
end

"""
The price of one of measure `m`'s unit, from the catalogue's `row`. Centient's
price is for one of the item's unit, so an item sold at \$2 a foot is \$6.56 a
metre to a measure in metres. It's nothing when the item is sold by a unit
that `m` can't be in, like a price a metre for a count.
"""
unit_price(m, row) = begin
  u = string(something(get(row, "unit", nothing), ""))
  Plans.kind_for(u) == m.kind || return nothing
  # A unit that Centient doesn't name, like "lineal metre" or "each", is its kind's own
  row["price"] * get(Plans.UNIT_SIZES, Plans.unit(m), 1.0) / get(Plans.UNIT_SIZES, u, 1.0)
end

"What `amount` of its kind's own unit of measure `m` costs at the price of the catalogue's `row`"
cost_of(m, amount::Real, row) = begin
  p = unit_price(m, row)
  p === nothing ? amount * row["price"] : Plans.in_unit(amount, Plans.unit(m)) * p
end

"""
The line of a quote for measure `m`, which comes to `amount` of its kind's own
unit. The line is in the measure's unit, and Centient prices it from the item
in that unit. A measure with no item names none, and its line is its words,
to match to an item in Centient.
"""
quote_line(m, amount::Real) = begin
  unit = Plans.unit(m)
  line = Dict{String,Any}("quantity" => round(Plans.in_unit(amount, unit), sigdigits=6), "unit" => unit, "note" => m.name)
  isempty(m.item) || (line["ref"] = m.item)
  line
end

"Ask Centient for a quote with a line for each measure"
make_quote!(v::TakeoffView) = begin
  v.quoting === nothing || return handled
  t = v.data
  Centient.available() || return say!(v, "Centient isn't on this Mac, so Ladder can't make the quote", true)
  isempty(t.customer) && return say!(v, "Choose the customer first", true)
  lines = Any[]
  for m in t.measures
    amount = Plans.amount(t, m)
    amount === nothing && return say!(v, "Set the scale first, so that $(isempty(m.name) ? "each length" : m.name) has a size", true)
    amount > 0 || continue
    push!(lines, quote_line(m, amount))
  end
  isempty(lines) && return say!(v, "Nothing is measured yet", true)
  plan = isempty(t.plan) ? "" : " of " * basename(t.plan)
  v.quoting = Centient.ask("create_quote", Dict{String,Any}("customer" => t.customer, "notes" => "From a takeoff$plan in Ladder", "lines" => lines))
  say!(v, "Making the quote in Centient…")
end

"""
What happens to a takeoff in each frame, before the page is laid out: a drag
that ended is written down, the text field that lost the keyboard closes, and
Centient's answers are taken.
"""
block_tick!(v::TakeoffView) = begin
  w = window_of(v)
  v.grab !== nothing && !held(v, Keys.mouse_left) && drop!(v)
  # A click somewhere else took the keyboard from the text field
  v.asking !== nothing && w !== nothing && w.focus !== plan_input(v) && settle_asking!(v)
  waiting = false
  # A column shows what its search finds while you type
  v.asking !== nothing && v.asking[1] == :filter && search_column!(v, v.asking[2], plan_input(v).text)
  # The list of units shows the ones that match what's typed. New words pick the unit that they name, or the first.
  if v.asking !== nothing && v.asking[1] == :unit
    words = String(strip(plan_input(v).text))
    v.rows = Any[u for u in units_for(v, v.asking[2]) if unit_matches(u, words)]
    words == v.query || (v.query = words; v.pick = something(findfirst(u -> names_unit(u, words), v.rows), 1))
    v.pick = clamp(v.pick, 1, max(1, length(v.rows)))
  end
  if v.asking !== nothing && v.asking[1] in (:item, :customer)
    words = String(strip(plan_input(v).text))
    words == v.query || (v.query = words; v.typed = time(); v.pick = 1)
    # The search waits until the typing stops for a moment
    if v.typed > 0 && time() - v.typed > 0.2
      v.typed = 0.0
      from = ITEM_FROM[]
      v.search = v.asking[1] == :customer ? Centient.ask("find_contacts", Dict("query" => words)) :
                 from[1] == :suppliers    ? Centient.ask("list_catalogues", Dict("query" => words)) :
                 Centient.ask("search_catalogue", Dict("query" => words, "catalogue" => from[1] == :own ? "own" : from[2]))
    end
    waiting = v.typed > 0
  end
  Centient.check!()
  r = v.search
  if r !== nothing && Centient.finished(r)
    v.search = nothing
    if Centient.failed(r)
      v.rows = Any[]
      say!(v, r.problem, true)
    else
      v.rows = collect(Any, get(r.value, r.tool == "find_contacts" ? "contacts" : r.tool == "list_catalogues" ? "catalogues" : "items", Any[]))
      v.pick = clamp(v.pick, 1, max(1, length(v.rows)))
    end
  end
  r = v.lookup
  if r !== nothing && Centient.finished(r)
    v.lookup = nothing
    Centient.failed(r) || foreach(row -> v.known[row["ref"]] = row, get(r.value, "items", Any[]))
  end
  r = v.quoting
  if r !== nothing && Centient.finished(r)
    v.quoting = nothing
    if Centient.failed(r)
      say!(v, r.problem, true)
    else
      v.data.made = string(get(r.value, "number", ""))
      company = Centient.server.company
      say!(v, "Centient has quote $(v.data.made) for $(dollars(get(r.value, "total", 0.0))) with GST" * (isempty(company) ? "" : ", in $company"))
      commit!(v)
    end
  end
  # While Centient works, the window looks again soon
  (waiting || v.search !== nothing || v.lookup !== nothing || v.quoting !== nothing) && redraw_in!(v, 0.1)
  v
end

# --- the text field ----------------------------------------------------------------------

"Close the text field, if it shows. What's typed in it is kept, but nothing is chosen from a list."
settle_asking!(v::TakeoffView) = v.asking === nothing ? handled : v.asking[1] in (:item, :customer, :unit) ? stop_asking!(v) : answer!(v)

"Show the text field for `what`, with `text` in it and selected"
ask!(v::TakeoffView, what, text="", placeholder="") = begin
  settle_asking!(v)
  i = plan_input(v)
  i.color = colours.ink
  i.text, i.placeholder = String(text), String(placeholder)
  i.anchor, i.cursor = 0, length(i.text)
  v.asking = what
  v.rows, v.pick, v.search = Any[], 1, nothing
  v.query, v.typed = "\0", 0.0   # no words yet, so the first look at the field starts a search
  v.said, v.wrong = "", false
  focus(i)
  if what[1] == :item
    # The list starts on the catalogue that an item was last chosen from, and not on the list of suppliers
    ITEM_FROM[][1] == :suppliers && (ITEM_FROM[] = (:own,))
    i.placeholder = "⌥ to toggle catalogue"
  end
  what[1] in (:item, :customer) && Centient.available() && show_found!(v)
  handled
end

"Take the text field away. The keyboard goes back to the plan."
stop_asking!(v::TakeoffView) = begin
  v.asking = nothing
  v.rows, v.search = Any[], nothing
  w = window_of(v)
  w === nothing || (close_popup!(w, FOUND_KEY); close_popup!(w, HEAD_KEY); close_popup!(w, UNIT_KEY))
  w !== nothing && w.focus === plan_input(v) && focus(part!(() -> PlanArea(of=v), v, :area))
  handled
end

"The number of metres that `text` says: 3.6, 3.6m or 3600mm. It's nothing when it says none."
metres_typed(text) = begin
  m = match(r"^\s*(\d+(?:\.\d+)?)\s*(mm|cm|m)?\s*$", lowercase(text))
  m === nothing && return nothing
  n = parse(Float64, m[1]) * (m[2] == "mm" ? 0.001 : m[2] == "cm" ? 0.01 : 1.0)
  n > 0 ? n : nothing
end

"Give page `page` the scale `n`. A plan's first scale is for all its pages. After that, a page gets a scale of its own."
scale!(v::TakeoffView, n) = begin
  t = v.data
  page = t.page
  key = isempty(t.scales) || plan_pages(v) <= 1 || (length(t.scales) == 1 && haskey(t.scales, 0) && page == 1) ? 0 : page
  t.scales[key] = round(n, digits=1)
  commit!(v)
end

"Take row `k` of what a search found"
choose_row!(v::TakeoffView, k::Int) = begin
  a = v.asking
  (a === nothing || !(1 <= k <= length(v.rows))) && return stop_asking!(v)
  row = v.rows[k]
  # A supplier in the list of suppliers opens its catalogue. The search goes on there.
  a[1] == :item && haskey(row, "slug") && return browse!(v, (:catalogue, string(row["slug"]), string(row["name"])))
  if a[1] == :customer
    v.data.customer = string(row["name"])
  elseif a[2] <= length(v.data.measures)
    m = v.data.measures[a[2]]
    was = known(v, m.item)
    # A measure that still has the name it was made with, or its old item's name, takes the new item's name
    (isempty(m.name) || occursin(FIRST_NAME, m.name) || (was !== nothing && m.name == was["name"])) &&
      (m.name = replace(string(row["name"]), '|' => '/'))
    m.item = string(row["ref"])
    v.known[m.item] = row
    # The item's unit says what the measure is, and the tool for it is ready to draw
    kind = Plans.kind_for(get(row, "unit", nothing))
    isempty(m.shapes) && m.kind != kind && (m.kind = kind; m.unit = "")
    # The amount shows in the unit that the item is sold by, when the measure can be in it
    sold = string(something(get(row, "unit", nothing), ""))
    Plans.unit_kind(sold) == m.kind && Plans.unit!(m, sold)
    stop_asking!(v)
    commit!(v)
    v.current = a[2]
    tool!(v, m.kind)
    m.kind == kind || say!(v, "Centient's price for $(row["name"]) is for $(sold_by(row)), and this measure is $(KIND_WORDS[m.kind])", true)
    return handled
  end
  stop_asking!(v)
  commit!(v)
  handled
end

"Do what the text field was for with what's typed in it"
answer!(v::TakeoffView) = begin
  a = v.asking
  a === nothing && return handled
  text = String(strip(plan_input(v).text))
  t = v.data
  # A column's search changes what the table shows, and nothing in the block
  a[1] == :filter && return (search_column!(v, a[2], text); stop_asking!(v))
  a[1] == :unit && return isempty(v.rows) ? stop_asking!(v) : unit!(v, a[2], v.rows[clamp(v.pick, 1, length(v.rows))])
  if a[1] in (:item, :customer)
    isempty(v.rows) || return choose_row!(v, v.pick)
    # Nothing to choose from. An empty field takes the item away, and a customer is kept as it's typed.
    a[1] == :item && isempty(text) && a[2] <= length(t.measures) && (t.measures[a[2]].item = "")
    a[1] == :customer && !isempty(text) && (t.customer = text)
  elseif a[1] == :name
    a[2] <= length(t.measures) && !isempty(text) && (t.measures[a[2]].name = replace(text, '|' => '/'))
  elseif a[1] == :extra
    n = tryparse(Float64, strip(replace(text, '%' => "", '+' => "")))
    a[2] <= length(t.measures) && (t.measures[a[2]].extra = n === nothing ? 0.0 : clamp(n, 0, 1000) / 100)
  elseif a[1] == :scale
    n = Plans.scale(text)
    n === nothing ? say!(v, "A scale is written like 1:100", true) : scale!(v, n)
  elseif a[1] == :length
    real = metres_typed(text)
    n = real === nothing ? nothing : Plans.scale(a[2], a[3], real)
    n === nothing ? say!(v, "Type the length in metres, like 3.6", true) : scale!(v, n)
    empty!(v.draft)
    v.tool = :select
  end
  stop_asking!(v)
  commit!(v)
  handled
end

# The keys of the text field that the field has no use for come here
onkey(v::TakeoffView, ev::KeyPress{Keys.enter}) = unmodified(ev) ? (v.asking === nothing ? nothing : answer!(v)) : nothing
onkey(v::TakeoffView, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  v.asking === nothing && return nothing
  v.asking[1] == :length && (empty!(v.draft); v.tool = :select)
  stop_asking!(v)
end
# ⌥ in an empty search for an item changes the catalogue that the list shows
onkey(v::TakeoffView, ev::KeyPress{Keys.opt}) = begin
  setdiff(held_keys(ev.window), Keys.opt) == Keys(0) || return nothing   # ⌥ by itself
  a = v.asking
  (a !== nothing && a[1] == :item && Centient.available() && isempty(strip(plan_input(v).text))) || return nothing
  toggle_catalogue!(v)
end
onkey(v::TakeoffView, ev::KeyPress{Keys.down}) = unmodified(ev) ? (v.asking === nothing ? nothing : (v.pick = min(v.pick + 1, max(1, length(v.rows))); handled)) : nothing
onkey(v::TakeoffView, ev::KeyPress{Keys.up}) = unmodified(ev) ? (v.asking === nothing ? nothing : (v.pick = max(v.pick - 1, 1); handled)) : nothing

# --- the view of the plan ----------------------------------------------------------------

"The point of the page that's at a place in the window"
page_point(v::TakeoffView, x, y) = (v.at[1] + (x - v.box[1]) / v.zoom, v.at[2] + (y - v.box[2]) / v.zoom)

"The place in the window of a point of the page"
window_point(v::TakeoffView, p) = (v.box[1] + (p[1] - v.at[1]) * v.zoom, v.box[2] + (p[2] - v.at[2]) * v.zoom)

# The lines of the pages of PDF plans that were last shown, each with a grid that finds the ones near the mouse.
# Each is kept under its file, when the file last changed, and its page.
const plan_lines = Dict{Any,Plans.Lines}()

"The lines of the page that shows, for corners to snap to. A picture has none, and nor has a PDF file that's a scan of paper."
lines_of(v::TakeoffView) = begin
  path = plan_path(v)
  (isempty(path) || !ispdf(path)) && return Plans.Lines()
  key = (path, mtime(path), v.data.page)
  kept = get(plan_lines, key, nothing)
  kept === nothing || return kept
  length(plan_lines) >= 4 && empty!(plan_lines)
  s = pdf_size(path, v.data.page)
  found = pdf_lines(path, v.data.page)
  plan_lines[key] = s === nothing || found === nothing ? Plans.Lines() : Plans.Lines(found[1], s[1], s[2], found[2])
end

"""
The point of the page where a corner goes when the mouse is at a place in the
window, and what it snapped to there: :corner, :crossing or :line. With the
magnet off or ⌘ held, and where nothing is near, it's the point under the
mouse, and nothing. `skip` is a corner that it doesn't snap to: the one that's
being dragged.
"""
aim(v::TakeoffView, w, x, y; skip=nothing) = begin
  p = page_point(v, x, y)
  (v.snap && !only_held(w, Keys.cmd)) || return (p, nothing)
  something(Plans.snap(v.data, lines_of(v), v.data.page, p, SNAP / v.zoom, skip=skip), (p, nothing))
end

"The px of white that the view keeps round the paper, so that the paper's edge and its shadow show"
const PAPER_EDGE = 14.0

"How many px to a point fits the whole page in the view, with white round it"
fit_zoom(v::TakeoffView, s) = max(min((v.box[3] - 2PAPER_EDGE) / s[1], (v.box[4] - 2PAPER_EDGE) / s[2]), 1e-3)

"Show the whole page, in the middle of the view"
fit!(v::TakeoffView, s) = begin
  v.zoom = fit_zoom(v, s)
  v.at = ((s[1] - v.box[3] / v.zoom) / 2, (s[2] - v.box[4] / v.zoom) / 2)
  v
end

"""
Keep the page in the view. Where the page is narrower than the view, it stays
in the middle, and so it does where it's shorter. So the plan only moves once
it's bigger than the view, and then no further than its edges, with the
white that the view keeps round the paper. `s` is the page's size in points.
"""
hold!(v::TakeoffView, s) = begin
  w, h = v.box[3] / v.zoom, v.box[4] / v.zoom
  e = PAPER_EDGE / v.zoom
  v.at = (s[1] <= w ? (s[1] - w) / 2 : clamp(v.at[1], -e, s[1] - w + e),
          s[2] <= h ? (s[2] - h) / 2 : clamp(v.at[2], -e, s[2] - h + e))
  v
end

"Note that the view moved just now, and keep the page in it"
moved!(v::TakeoffView) = begin
  v.moved = time()
  s = plan_size(v)
  s === nothing ? v : hold!(v, s)
end

"Make the plan `by` times as big. The point of the page at the place `(x, y)` in the window stays there."
zoom_plan!(v::TakeoffView, by, x, y) = begin
  s = plan_size(v)
  (s === nothing || v.zoom <= 0) && return handled
  p = page_point(v, x, y)
  v.zoom = clamp(v.zoom * by, fit_zoom(v, s), NEAR)   # never smaller than the whole page
  v.at = (p[1] - (x - v.box[1]) / v.zoom, p[2] - (y - v.box[2]) / v.zoom)
  moved!(v)
  handled
end

"Go on by `by` pages"
page!(v::TakeoffView, by) = begin
  page = clamp(v.data.page + by, 1, max(1, plan_pages(v)))
  page == v.data.page && return handled
  v.data.page = page
  v.zoom = 0.0
  v.picked = nothing
  empty!(v.draft)
  commit!(v)
  handled
end

# --- drawing -----------------------------------------------------------------------------

"How many of the screen's pixels a px is wide on the canvas `ctx`"
density(ctx) = begin
  m = Ref(Skia.sk_matrix_t(1f0, 0f0, 0f0, 0f0, 1f0, 0f0, 0f0, 0f0, 1f0))
  Skia.sk_canvas_get_total_matrix(ctx, m)
  sqrt(abs(m[].scaleX * m[].scaleY - m[].skewX * m[].skewY))
end

"The part of a page of a PDF plan that the view shows, drawn at the screen's own pixels and kept until the view moves"
sharpen!(v::TakeoffView, path, of, k, x, y, w, h) = sharpen!(v.sharp, path, v.data.page, of, k, x, y, w, h)

"""
The part of page `page` of the PDF file at `path` that's `w` by `h` pixels and
starts `x` and `y` pixels into the page drawn `k` pixels to the point. It's kept
in `p` while `of`, what it's a picture of, stays the same.
"""
sharpen!(p::Sharp, path, page, of, k, x, y, w, h) = begin
  p.of == of && return p.image
  started = time()
  pixels = pdf_part(path, page, k, x, y, w, h)
  p.image == C_NULL || Skia.sk_image_unref(p.image)
  p.image, p.of = C_NULL, of
  pixels === nothing && return C_NULL
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_BGRA_8888, Skia.SK_ALPHA_TYPE_PREMUL, w, h))
  GC.@preserve info pixels begin
    data = Skia.sk_data_new_with_copy(pointer(pixels), UInt64(4w * h))
    p.image = Skia.sk_image_new_raster_data(info, data, Csize_t(4w))
    Skia.sk_data_unref(data)
  end
  p.cost = time() - started
  p.image
end

"How round the corners of the plan's paper are, in px"
const PAPER_ROUND = 3.0

"""
Draw the plan's paper, with what shows where it ends on the white behind it:
a soft shadow under it and a thin line round it. Its corners are a little round.
"""
paper!(ctx, (x, y, w, h)) = begin
  shape(grow, down) = begin
    path = Skia.sk_path_new()
    rect = Ref(Skia.sk_rect_t(Float32(x - grow), Float32(y - grow + down), Float32(x + w + grow), Float32(y + h + grow + down)))
    Skia.sk_path_add_rounded_rect(path, rect, Float32(PAPER_ROUND + grow), Float32(PAPER_ROUND + grow), Skia.SK_PATH_DIRECTION_CW)
    path
  end
  fill(path, paint) = (Skia.sk_canvas_draw_path(ctx, path, paint); Skia.sk_paint_delete(paint); Skia.sk_path_delete(path))
  shadow = ink(RGBA(0, 0, 0, 0.2))
  blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, 6f0, true)
  Skia.sk_paint_set_maskfilter(shadow, blur)
  fill(shape(0, 2), shadow)
  Skia.sk_maskfilter_unref(blur)
  # The line is outside the paper, so the plan doesn't cover it
  fill(shape(0.5, 0), ink(RGBA(0, 0, 0, 0.16), 1))
  fill(shape(0, 0), ink(colorant"white"))
end

"Draw the page of the plan that shows. `s` is its size in points."
draw_plan(ctx, v::TakeoffView, s) = begin
  left, top, wide, tall = v.box
  path = plan_path(v)
  # Where the paper is in the window
  x, y = window_point(v, (0.0, 0.0))
  paper = (x, y, s[1] * v.zoom, s[2] * v.zoom)
  paper!(ctx, paper)
  # What's on the paper is cut off at the paper's round corners
  with_round_clip(() -> plan_ink(ctx, v, s, path, paper), ctx, px(paper[1]), px(paper[2]), px(paper[3]), px(paper[4]), px(PAPER_ROUND))
end

"Draw what's on the paper: the picture, or the part of the PDF page that's in the view"
plan_ink(ctx, v::TakeoffView, s, path, paper) = begin
  left, top, wide, tall = v.box
  if !ispdf(path)
    key = picture_key(path)
    key === nothing || paint_picture(ctx, image_source(key).raw, (0, 0, s[1], s[2]), paper)
    return
  end
  # Never fewer than 2 pixels to the px, so that the plan is sharp on paper too
  d = clamp(density(ctx), 2, 3)
  w, h = round(Int, wide * d), round(Int, tall * d)
  (w < 1 || h < 1) && return
  k = v.zoom * d   # the screen's pixels to a point of the page
  of = (path, mtime(path), v.data.page, k, v.at, w, h)
  p = v.sharp
  # A plan that takes long to draw shows a rougher picture of the whole page while it moves
  if p.of != of && p.cost > QUICK && time() - v.moved < SETTLED
    rough = pdf_page(path, v.data.page, 2000)
    rough === nothing || paint_picture(ctx, image_source(rough).raw, (0, 0, image_source(rough).width, image_source(rough).height), paper)
    redraw_in!(v, SETTLED)
    return
  end
  image = sharpen!(v, path, of, k, v.at[1] * k, v.at[2] * k, w, h)
  image == C_NULL && return
  # The picture is of the whole view, with white where the paper ends. The paper's edge cuts it off.
  paint_picture(ctx, image, (0, 0, w, h), (left, top, wide, tall))
end

"""
Show where the next corner snaps to: a square on a corner of the plan, a cross
where two of its lines cross, and a ring on a line.
"""
snap_mark(ctx, (x, y), kind) = begin
  r = 5.0
  # White under the colour, so that it shows on a dark part of the plan
  for (colour, wide) in ((colorant"white", 3.5), (colours.accent, 1.5))
    if kind == :corner
      trace(ctx, [(x - r, y - r), (x + r, y - r), (x + r, y + r), (x - r, y + r)], colour, wide, closed=true)
    elseif kind == :crossing
      trace(ctx, [(x - r, y - r), (x + r, y + r)], colour, wide)
      trace(ctx, [(x - r, y + r), (x + r, y - r)], colour, wide)
    else
      paint = ink(colour, wide)
      Skia.sk_canvas_draw_circle(ctx, Float32(x), Float32(y), Float32(r), paint)
      Skia.sk_paint_delete(paint)
    end
  end
end

"Draw a dot of radius `r` at the place `(x, y)`, with a white edge"
dot(ctx, (x, y), r, colour) = begin
  for (radius, c) in ((r + 1.5, colorant"white"), (r, colour))
    paint = ink(c)
    Skia.sk_canvas_draw_circle(ctx, Float32(x), Float32(y), Float32(radius), paint)
    Skia.sk_paint_delete(paint)
  end
end

"Write `words` in a small dark box beside the place `(x, y)`"
tag(ctx, (x, y), words) = begin
  isempty(words) && return
  face = Face(SANS, "Semibold", 11px, colorant"white", false)
  wide = num(measure(face, words))
  rounded_rectangle(ctx, px(x + 10), px(y - 22), px(wide + 12), 18px, 4px, background=RGBA(0.12, 0.12, 0.12, 0.85))
  paint = ink(colorant"white")
  blob = Skia.sk_textblob_make_from_string(words, skia_font(face.family, face.size, face.style).raw, Skia.SK_TEXT_ENCODING_UTF8)
  Skia.sk_canvas_draw_text_blob(ctx, blob, Float32(x + 16), Float32(y - 9), paint)
  Skia.sk_textblob_unref(blob)
  Skia.sk_paint_delete(paint)
end

"What a shape of this kind comes to in the unit `unit`, as the plan shows it beside the shape, or \"\" when its page has no scale"
size_text(v::TakeoffView, kind, shape, unit=Plans.own_unit(kind)) = begin
  a = Plans.amount(v.data, kind, shape)
  a === nothing ? "" : Plans.shown(kind, a, unit)
end

"""
What shape `j` of measure `m` comes to in the measure's unit, as the plan shows
it beside the shape: an outline without its cut-outs, and a cut-out as what it
takes away, with a minus. It's "" when its page has no scale.
"""
size_text(v::TakeoffView, m::Plans.Measure, j::Int) = begin
  a = Plans.amount(v.data, m, j)
  a === nothing ? "" : (m.shapes[j].cut ? "−" : "") * Plans.shown(m.kind, a, Plans.unit(m))
end

"""
What a cut-out with the corners `points` takes from the outline at the place
`from`, as the plan shows it while the cut-out is drawn. Over no outline, it
says so.
"""
cut_text(v::TakeoffView, from, points) = begin
  length(points) < 3 && return ""
  from === nothing && return "Not over an area"
  n = Plans.scale(v.data, v.data.page)
  n === nothing && return ""
  m = v.data.measures[from[1]]
  "−" * Plans.shown(:area, Plans.takes(m, from[2], points) * Plans.metres(n)^2, Plans.unit(m))
end

"Draw what's measured on the page that shows, and what's being drawn"
draw_shapes(ctx, v::TakeoffView) = begin
  t = v.data
  for (i, m) in enumerate(t.measures), (j, s) in enumerate(m.shapes)
    s.page == t.page || continue
    colour = hue(i)
    on = v.picked !== nothing && v.picked[1] == i && v.picked[2] == j
    ps = [window_point(v, p) for p in s.points]
    if m.kind == :count
      for (k, p) in enumerate(ps)
        dot(ctx, p, on && length(v.picked) == 3 && v.picked[3] == k ? 7.5 : 5, colour)
      end
      continue
    end
    area = m.kind == :area
    if s.cut
      # A cut-out is an outline of dashes. Its area's colour stops at it.
      trace(ctx, ps, colour, on ? 3 : 1.5, closed=true, dashed=true)
    else
      holes = area ? [[window_point(v, p) for p in m.shapes[k].points] for k in Plans.cuts(m, j)] : ()
      trace(ctx, ps, colour, on ? 4 : 2.5, fill=area ? RGBA(colour, 0.22) : nothing, closed=area, holes=holes)
    end
    # The corners show on the measure that the tools draw for, so that you can take hold of one
    (on || v.current == i) && foreach(p -> dot(ctx, p, on ? 4 : 3, colour), ps)
    on && tag(ctx, ps[end], size_text(v, m, j))
  end
  # Where the next corner goes, when it snaps to something
  marked = v.aim !== nothing && v.mouse !== nothing && v.asking === nothing && ishovered(part!(() -> PlanArea(of=v), v, :area))
  if isempty(v.draft)
    marked && snap_mark(ctx, window_point(v, v.mouse), v.aim)
    return
  end
  # What's being drawn runs on to the mouse
  cut = v.tool == :cut
  kind = cut ? :area : v.tool
  # With the mouse over the Done button, it shows what a click there leaves
  done = over_done(v)
  points = v.mouse === nothing || v.asking !== nothing || done ? copy(v.draft) : [v.draft; [v.mouse]]
  # A cut-out has the colour of the area that it's cut from
  from = cut ? Plans.cut_from(t, t.page, points, v.current) : nothing
  colour = kind == :scale ? colours.accent : cut ? (from === nothing ? colours.dim : hue(from[1])) :
           hue(v.current > 0 && t.measures[v.current].kind == kind ? v.current : length(t.measures) + 1)
  ps = [window_point(v, p) for p in points]
  closed = kind == :area && length(ps) > 2
  trace(ctx, ps, colour, 2, fill=closed && !cut ? RGBA(colour, 0.15) : nothing, closed=closed, dashed=cut)
  foreach(p -> dot(ctx, p, 3, colour), ps[1:length(v.draft)])
  # In the unit of the measure that it's for
  unit = v.current > 0 && t.measures[v.current].kind == kind ? Plans.unit(t.measures[v.current]) : Plans.own_unit(kind)
  kind == :scale || tag(ctx, ps[end], cut ? cut_text(v, from, points) : size_text(v, kind, Plans.Shape(t.page, points), unit))
  marked && !done && snap_mark(ctx, window_point(v, v.mouse), v.aim)
  draw_done(ctx, v, done)
end

# --- the button that ends a line or an outline -------------------------------------------
#
# While a length or an area is being drawn, a Done button shows beside its last
# corner, as soon as it has corners enough to end. A click on the button ends
# the line or the outline, as Return does, and puts no corner down. The button
# is behind the last corner and to one side of the line that led to it. The
# next corner is seldom put there, so the button is seldom in its way.

const DONE_W, DONE_H = 64.0, 24.0   # px. How wide and how tall the Done button is.
const DONE_GAP = 10.0               # px between the button and the line that led to the last corner

"""
Where the Done button is in the window: its left, its top, its width and its
height. It's nothing while there's no line or outline with corners enough to end.
"""
done_box(v::TakeoffView) = begin
  (v.tool in (:length, :area, :cut) && v.zoom > 0) || return nothing
  n = length(v.draft)
  n >= (v.tool == :length ? 2 : 3) || return nothing
  (x, y), (x0, y0) = window_point(v, v.draft[n]), window_point(v, v.draft[n-1])
  far = hypot(x - x0, y - y0)
  # The way the line went to its last corner
  ux, uy = far > 0 ? ((x - x0) / far, (y - y0) / far) : (1.0, 0.0)
  # The button's place on one side of the line. Its front is level with the corner, and its near edge is DONE_GAP from the line.
  place(nx, ny) = begin
    back = (abs(ux) * DONE_W + abs(uy) * DONE_H) / 2
    off = (abs(nx) * DONE_W + abs(ny) * DONE_H) / 2 + DONE_GAP
    (x - ux * back + nx * off - DONE_W / 2, y - uy * back + ny * off - DONE_H / 2)
  end
  left, top, wide, tall = v.box
  fits((bx, by)) = bx >= left && by >= top && bx + DONE_W <= left + wide && by + DONE_H <= top + tall
  # The side that's lower in the window, or the right one of two that are level. The other side if only that one is in the view.
  nx, ny = ux > 0 || (ux == 0 && uy < 0) ? (-uy, ux) : (uy, -ux)
  at = place(nx, ny)
  other = place(-nx, -ny)
  fits(at) || !fits(other) || (at = other)
  # A corner that's out of sight still has its button in sight
  (clamp(at[1], left, max(left, left + wide - DONE_W)), clamp(at[2], top, max(top, top + tall - DONE_H)), DONE_W, DONE_H)
end

"True when the place `(x, y)` of the window is on the Done button"
on_done(v::TakeoffView, x, y) = begin
  b = done_box(v)
  b !== nothing && b[1] <= x <= b[1] + b[3] && b[2] <= y <= b[2] + b[4]
end

"True when the mouse is over the Done button"
over_done(v::TakeoffView) = (w = window_of(v); w !== nothing && on_done(v, num(w.mouse[1]), num(w.mouse[2])))

"What the Done button's tooltip says"
done_tip(v::TakeoffView) = (v.tool == :length ? "End the line" : "End the outline") * "  Return"

"Draw the Done button. It's lighter while the mouse is over it."
draw_done(ctx, v::TakeoffView, over::Bool) = begin
  b = done_box(v)
  b === nothing && return
  size = (px(b[3]), px(b[4]))
  white = colorant"white"
  button = Box(fixed(size[1]), height(size[2]), radius(size[2] / 2), Alignment.Center, border(1.5px, :solid, white),
               background(over ? RGBA(0.3, 0.3, 0.3, 0.95) : RGBA(0.12, 0.12, 0.12, 0.9)),
               Row(Alignment.Center, child_gap=4px, Icon("check", size=12px, color=white), label("Done", 12px, color=white, weight="Semibold")))
  Skia.sk_canvas_save(ctx)
  Skia.sk_canvas_translate(ctx, Float32(b[1]), Float32(b[2]))
  draw(ctx, size, describe(button, size))
  Skia.sk_canvas_restore(ctx)
end

describe(a::PlanArea) = begin
  v = a.of
  # In the window, the plan takes all the room that the tools leave
  h = v.full ? height(grow=grow) : height(plan_h(v, editor(v).width - 2px))
  plan_size(v) === nothing || return Box(width(grow=grow), h, background(takeoff_back()))
  words = isempty(v.data.plan) ? "Drop a plan here, or click to choose one: a PDF file or a picture" :
                                 "$(v.data.plan) isn't a plan that Ladder can show. Click to choose another."
  Column(width(grow=grow), h, justify=Alignment.Center, child_gap=10px, background(colours.stripe),
    Icon("map", size=26px, color=colours.faint), Box(label(words, 13px, color=colours.dim)))
end

draw(ctx, size, ui::ConcreteRect, a::PlanArea) = begin
  v = a.of
  was = v.box
  v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  s = plan_size(v)
  s === nothing && return
  # A new file or a new page is shown whole
  shown = (plan_path(v), v.data.page)
  if v.zoom <= 0 || v.fitted != shown
    fit!(v, s)
    v.fitted = shown
  elseif was[3] > 0 && (was[3] != v.box[3] || was[4] != v.box[4])
    # The view changed its size, as it does when the window does, when it fills the window and on paper.
    # A view that showed the whole page still does. A view that was bigger shows the same part of the plan.
    if v.zoom <= 1.0001min(was[3] / s[1], was[4] / s[2])
      fit!(v, s)
    else
      middle = (v.at[1] + was[3] / 2v.zoom, v.at[2] + was[4] / 2v.zoom)
      v.zoom = max(v.zoom * v.box[3] / was[3], fit_zoom(v, s))
      v.at = (middle[1] - v.box[3] / 2v.zoom, middle[2] - v.box[4] / 2v.zoom)
      hold!(v, s)
    end
  end
  lookup!(v)
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    draw_plan(ctx, v, s)
    draw_shapes(ctx, v)
  end
end

"""
True when the mouse is over something on the plan that a click selects: a
mark, a line, an outline or the inside of one. The window asks for the cursor
before the plan sees the mouse move, so this reads where the window's mouse is.
"""
over_shape(v::TakeoffView) = begin
  w = window_of(v)
  (w === nothing || v.zoom <= 0) && return false
  p = page_point(v, num(w.mouse[1]), num(w.mouse[2]))
  Plans.shape(v.data, v.data.page, p, REACH / v.zoom) !== nothing
end

# With the select tool, a hand over something that a click selects, and an arrow over the paper
cursor(a::PlanArea) = begin
  v = a.of
  plan_size(v) === nothing || over_done(v) ? :hand : v.tool == :select ? (v.grab !== nothing || over_shape(v) ? :hand : :arrow) : :crosshair
end

# --- the mouse and the keys on the plan --------------------------------------------------

"The name that a new measure of this kind starts with: Count 1, Length 2"
first_name(v::TakeoffView, kind) = "$(uppercasefirst(string(kind))) $(count(m -> m.kind == kind, v.data.measures) + 1)"
const FIRST_NAME = r"^(Count|Length|Area) \d+$"
const KIND_WORDS = Dict(:count => "a count", :length => "a length", :area => "an area")

"What an item's price is for, in words: each one, each m, each m²"
sold_by(row) = begin
  unit = string(something(get(row, "unit", nothing), ""))
  unit in ("", "Piece", "each") ? "each one" : "each " * unit
end

"Make a measure that has nothing drawn yet one of `kind`. A name that it was made with follows its kind."
kind!(v::TakeoffView, m, kind::Symbol) = begin
  (m.kind == kind || !isempty(m.shapes)) && return m
  occursin(FIRST_NAME, m.name) && (m.name = first_name(v, kind))
  m.kind = kind
  m.unit = ""
  m
end

"The measure of this kind that the tools draw for. If the current measure is of another kind, a new one starts."
measure!(v::TakeoffView, kind::Symbol) = begin
  ms = v.data.measures
  1 <= v.current <= length(ms) && ms[v.current].kind == kind && return ms[v.current]
  push!(ms, Plans.Measure(kind, first_name(v, kind)))
  v.current = length(ms)
  last(ms)
end

"What the foot of the block says when a cut-out is drawn where there's no area to cut it from"
const CUT_NOWHERE = "A cut-out goes over an area that's measured. Measure the area first, then cut the shape out of it."

"""
End the line or the outline that's being drawn. One with too few corners is
dropped. A cut-out goes to the area that it's over, and one that's over none is
dropped too.
"""
finish_shape!(v::TakeoffView) = begin
  kind = v.tool
  if kind == :cut && length(v.draft) >= 3
    made = Plans.cut!(v.data, v.data.page, copy(v.draft), v.current)
    empty!(v.draft)
    if made === nothing
      say!(v, CUT_NOWHERE, true)
    else
      v.current = made[1]
      v.said == CUT_NOWHERE && say!(v, "")
      commit!(v)
    end
  elseif kind in (:length, :area) && length(v.draft) >= (kind == :length ? 2 : 3)
    push!(measure!(v, kind).shapes, Plans.Shape(v.data.page, copy(v.draft)))
    empty!(v.draft)
    commit!(v)
  end
  empty!(v.draft)
  handled
end

"""
Choose a tool. A tool that measures draws for the measure that's chosen in the
list. If that measure is of another kind, it becomes the tool's kind when
nothing is drawn for it yet and it has no item. If not, the tool draws for the
last measure of its kind.
"""
tool!(v::TakeoffView, tool::Symbol) = begin
  v.tool = tool
  empty!(v.draft)
  v.picked = nothing
  ms = v.data.measures
  if tool in Plans.KINDS && !(1 <= v.current <= length(ms) && ms[v.current].kind == tool)
    m = 1 <= v.current <= length(ms) ? ms[v.current] : nothing
    if m !== nothing && isempty(m.shapes) && isempty(m.item)
      kind!(v, m, tool)
      commit!(v)
    else
      v.current = something(findlast(m -> m.kind == tool, ms), 0)
    end
  end
  handled
end

"A drag ended. A corner that moved is written down."
drop!(v::TakeoffView) = begin
  g = v.grab
  v.grab = nothing
  g !== nothing && g[1] == :corner && g[3] && commit!(v)
  v
end

"Take away what's selected on the plan: a mark, a corner, or a whole line or outline"
remove_picked!(v::TakeoffView) = begin
  p = v.picked
  p === nothing && return handled
  m = v.data.measures[p[1]]
  # An outline takes its cut-outs with it
  length(p) == 3 ? Plans.remove!(m, p[2], p[3]) : Plans.remove!(m, p[2])
  v.picked = nothing
  commit!(v)
  handled
end

onkey(a::PlanArea, ev::KeyPress{Keys.mouse_left}) = begin
  v, w = a.of, ev.window
  focus(a)
  plan_size(v) === nothing && return choose_plan!(v, w)
  v.zoom > 0 || return handled
  x, y = num(w.mouse[1]), num(w.mouse[2])
  # A click on the Done button ends what's being drawn, and puts no corner down
  on_done(v, x, y) && return (hide_tooltip!(w); finish_shape!(v))
  p = page_point(v, x, y)
  at, cx, cy = v.clicked
  twice = time() - at < 0.35 && hypot(x - cx, y - cy) < 4
  v.clicked = (time(), x, y)
  reach = REACH / v.zoom
  page = v.data.page
  if v.tool == :count
    Plans.mark!(measure!(v, :count), page, p)
    commit!(v)
  elseif v.tool in (:length, :area, :cut)
    closes = v.tool != :length && length(v.draft) >= 3 && hypot(v.draft[1][1] - p[1], v.draft[1][2] - p[2]) <= reach
    # The first click of two put the last corner down. A corner snaps to the plan's lines.
    (twice && !isempty(v.draft)) || closes ? finish_shape!(v) : push!(v.draft, aim(v, w, x, y)[1])
  elseif v.tool == :scale
    length(v.draft) >= 2 && empty!(v.draft)
    push!(v.draft, aim(v, w, x, y)[1])
    length(v.draft) == 2 && ask!(v, (:length, v.draft[1], v.draft[2]), "", "metres")
  else
    corner = Plans.corner(v.data, page, p, reach)
    if corner !== nothing
      v.picked, v.current = corner, corner[1]
      v.grab = (:corner, corner, false)
    else
      v.picked = Plans.shape(v.data, page, p, reach)
      v.picked === nothing || (v.current = v.picked[1])
      v.grab = (:pan, (x, y), v.at)
    end
  end
  handled
end

# A right-click ends what's being drawn
onkey(a::PlanArea, ::KeyPress{Keys.mouse_right}) = isempty(a.of.draft) ? nothing : finish_shape!(a.of)

onmouse(a::PlanArea, ev::MouseMove) = begin
  v = a.of
  v.zoom > 0 || return nothing
  x, y = num(ev.position[1]), num(ev.position[2])
  g = v.grab
  # A corner that a tool is about to put down snaps to the plan's lines, and so does one that's dragged. A mark of a count doesn't.
  drawing = g === nothing && v.tool in (:length, :area, :cut, :scale) && !on_done(v, x, y)
  dragged = g !== nothing && g[1] == :corner && v.data.measures[g[2][1]].kind != :count
  v.mouse, v.aim = drawing ? aim(v, ev.window, x, y) : dragged ? aim(v, ev.window, x, y, skip=g[2]) : (page_point(v, x, y), nothing)
  # The Done button says what it does, and the key that does the same
  on_done(v, x, y) && show_tooltip!(ev.window, tip_label(done_tip(v)), px.(done_box(v))..., placement=:bottom, gap=6px)
  g === nothing && return handled
  Keys.mouse_left in ev.window.keys || (drop!(v); return handled)
  if g[1] == :pan
    (x0, y0), at = g[2], g[3]
    v.at = (at[1] - (x - x0) / v.zoom, at[2] - (y - y0) / v.zoom)
    moved!(v)
  else
    i, j, k = g[2]
    v.data.measures[i].shapes[j].points[k] = v.mouse
    v.grab = (:corner, g[2], true)
  end
  handled   # the drag is the plan's, so the page's text doesn't select
end

# A mouse wheel makes the plan bigger or smaller, round the mouse, like a map. Two fingers on the trackpad move
# the plan, and a pinch makes it bigger or smaller. With ⌘ held, both make it bigger or smaller.
# A plan in the page takes them once a click has given it the keyboard, or while ⌘ is held. Before that, they
# move the page that the plan is on, so that the page can scroll past it. A plan that fills the window has no page.
onscroll(a::PlanArea, ev::MouseScroll) = begin
  v, w = a.of, ev.window
  v.zoom > 0 || return nothing
  cmd = only_held(w, Keys.cmd)
  (cmd || w.focus === a || v.full) || return nothing
  (cmd || ev.wheel) && return zoom_plan!(v, exp(num(ev.delta[2]) / 10), num(w.mouse[1]), num(w.mouse[2]))
  v.at = (v.at[1] - 30num(ev.delta[1]) / v.zoom, v.at[2] - 30num(ev.delta[2]) / v.zoom)
  moved!(v)
  handled
end

# Two fingers that move apart or together on the trackpad make the plan bigger or smaller, round the mouse
onpinch(a::PlanArea, ev::Pinch) = begin
  v, w = a.of, ev.window
  v.zoom > 0 || return nothing
  zoom_plan!(v, ev.scale, num(w.mouse[1]), num(w.mouse[2]))
end

onkey(a::PlanArea, ev::KeyPress{Keys.enter}) = unmodified(ev) ? finish_shape!(a.of) : nothing
onkey(a::PlanArea, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  v = a.of
  # Esc drops what's half drawn, then puts the arrow back, then puts a takeoff that fills the window
  # back in the page, then gives the keyboard back to the text
  isempty(v.draft) || return (empty!(v.draft); handled)
  v.tool == :select ? (v.full ? full!(v, false) : nothing) : tool!(v, :select)
end
onkey(a::PlanArea, ::KeyPress{K}) where K = begin
  v = a.of
  if K in (Keys.backspace, Keys.delete) && unmodified(window_of(a))
    # While something is being drawn, Delete takes its last corner back
    return isempty(v.draft) ? remove_picked!(v) : (pop!(v.draft); handled)
  elseif (command = command_of(editor(v), window_of(a), K)) in (:undo, :redo)
    b = editor(v).buf
    command == :redo ? redo!(b) : undo!(b)
    return handled
  end
  nothing
end

ontype(a::PlanArea, ev::Typed) = begin
  # A letter picks a tool by itself, or with ⇧
  (unmodified(ev) || only_held(ev, Keys.shft)) || return nothing
  i = findfirst(((_, (_, _, letter)),) -> letter == lowercase(ev.char), PLAN_TOOLS)
  i === nothing ? nothing : tool!(a.of, PLAN_TOOLS[i][1])
end

# --- the buttons -------------------------------------------------------------------------

"The button of `v` that's kept under `key`, with what it does and shows now"
button!(v::TakeoffView, key, action; icon="", words="", tip="", off=false) = begin
  on = (action isa Tuple && action[1] == :tool && v.tool == action[2]) || (action == :snap && v.snap)
  block_button!(v, key, action; icon, words, tip, on, off)
end

fill_focus(v::TakeoffView, ::Bool) = keyboard_part(v)

"Do what a button of a takeoff does"
act!(v::TakeoffView, action, w) = begin
  settle_asking!(v)
  a = action isa Tuple ? action[1] : action
  t = v.data
  if a == :tool
    tool!(v, action[2])
  elseif a == :page
    page!(v, action[2])
  elseif a == :zoom
    zoom_plan!(v, action[2], v.box[1] + v.box[3] / 2, v.box[2] + v.box[4] / 2)
  elseif a == :fit
    v.zoom = 0.0
  elseif a == :snap
    v.snap = !v.snap
    v.aim = nothing
  elseif a == :full
    full!(v, !v.full)
  elseif a == :scale
    s = Plans.scale(t, t.page)
    ask!(v, (:scale,), s === nothing ? "1:100" : Plans.scale_text(s))
  elseif a == :choose
    choose_plan!(v, w)
  elseif a in (:add, :add_item)
    # It starts as what the tool in use measures, or as a count. Its item's unit, or the next tool, can change that.
    kind = v.tool in Plans.KINDS ? v.tool : :count
    empty!(v.filters)   # a search of the table could hide the new measure
    push!(t.measures, Plans.Measure(kind, first_name(v, kind)))
    v.current = length(t.measures)
    tool!(v, kind)
    commit!(v)
    # A measure from the catalogue asks for its item: it takes the item's name, and the item's unit says what it is.
    # Another asks for the words that describe it. Typing takes the place of the name that it was made with.
    a == :add_item ? ask!(v, (:item, v.current)) : ask!(v, (:name, v.current), last(t.measures).name, "What it measures")
  elseif a == :delete && action[2] <= length(t.measures)
    deleteat!(t.measures, action[2])
    v.current = v.current == action[2] ? 0 : v.current > action[2] ? v.current - 1 : v.current
    v.picked = nothing
    commit!(v)
  elseif a == :customer
    Centient.available() ? ask!(v, (:customer,), "", "Search Centient's contacts") :
                           ask!(v, (:customer,), t.customer, "The customer's name")
  elseif a == :quote
    make_quote!(v)
  end
  handled
end

# --- the list of measures ----------------------------------------------------------------

"The text field in a box, where the thing that it changes was"
field(v::TakeoffView, wide=width(grow=grow)) =
  Box(wide, height(24px), padding(6px, 0px), radius(5px), border(1px, :solid, colours.accent), background(colours.bg), plan_input(v))

"The mark beside a measure's name, in its colour: a dot for a count, a line for a length, a square for an area"
swatch(kind::Symbol, colour) =
  Box(width(14px), height(14px), Alignment.Center,
    kind == :count ? Box(width(10px), height(10px), radius(5px), background(colour)) :
    kind == :length ? Box(width(14px), height(3px), radius(1.5px), background(colour)) :
                      Box(width(11px), height(11px), radius(2px), background(RGBA(colour, 0.3)), border(1.5px, :solid, colour)))

"A price as a row of the list shows it: \$22.00 / m, or \$5.97 each"
price_text(row) = begin
  unit = string(something(get(row, "unit", nothing), ""))
  dollars(row["price"]) * (unit in ("", "Piece", "each") ? " each" : " / " * unit)
end

"""
What the table calls measure `m`. With an item that Centient has told of, it's
the item's name. With no item, it's the words that describe the measure, which
are its name in the block.
"""
item_name(v::TakeoffView, m) = begin
  row = known(v, m.item)
  row === nothing ? (isempty(m.name) ? m.item : m.name) : string(row["name"])
end

"The words `shown`, which start the words of `parts` and may end with …, as a text for each part in its colour"
runs(shown::AbstractString, parts) = begin
  cs, at, out = collect(shown), 0, Any[]
  for (s, colour) in parts
    n = min(length(s), length(cs) - at)
    n > 0 || break
    push!(out, label(String(cs[at+1:at+n]), 13px, color=colour))
    at += n
  end
  out
end

describe(c::MeasureCell) = begin
  v, i = c.of, c.i
  i <= length(v.data.measures) || return Box(width(0px))
  m = v.data.measures[i]
  wide = c.what == :extra ? fixed(52px) : width(grow=grow)
  c.full = ""
  # The item's cell holds the field for the item, and the field for the words of a measure with none
  a = v.asking
  a !== nothing && a[1] in (c.what == :item ? (:item, :name) : (:extra,)) && a[2] == i && return field(v, wide)
  # The words are in a row with no width of its own, so long words take no room from the cells beside them.
  # They're cut short with … to fit the width the cell had when it was last drawn. Each of `parts` is words and their colour.
  words(parts...) = begin
    s = join(first.(parts))
    shown = elide(s, 13px, c.rect[3])
    shown == s || (c.full = s)
    Row(wide, height(grow=grow), Alignment.Center, clip=true, Row(fixed(0px), runs(shown, parts)...))
  end
  c.what == :extra && return words((m.extra > 0 ? "+" * Plans.number(100m.extra) * "%" : "+0%", m.extra > 0 ? colours.ink : colours.faint))
  name, row = item_name(v, m), known(v, m.item)
  # An item that Centient knows shows where it's from after its name
  row === nothing ? words((name, colours.ink)) : words((name, colours.ink), ("  ·  " * string(row["source"]), colours.dim))
end

cursor(::MeasureCell) = :hand

draw(ctx, size, ui::ConcreteRect, c::MeasureCell) = begin
  # A new width cuts the words short in another place, so the cell is described again
  ui.width == c.rect[3] || redraw_in!(c.of, 0)
  c.rect = (ui.left, ui.top, ui.width, ui.height)
  nothing
end

# Words that are cut short show whole under the cell
onmouse(c::MeasureCell, ev::MouseMove) = isempty(c.full) ? nothing :
  show_tooltip!(ev.window, tip_label(c.full), c.rect..., placement=:bottom, gap=6px)

onkey(c::MeasureCell, ::KeyPress{Keys.mouse_left}) = begin
  v, i = c.of, c.i
  i <= length(v.data.measures) || return handled
  m = v.data.measures[i]
  # The first click on a row chooses it. A click on the row that's chosen changes the part that's clicked.
  chosen = v.current == i
  chosen || choose_measure!(v, i)
  chosen || return handled
  c.what == :extra && return ask!(v, (:extra, i), m.extra > 0 ? Plans.number(100m.extra) : "", "%")
  # A measure from the catalogue chooses another item. One with no item changes the words that describe it.
  isempty(m.item) || !Centient.available() ? ask!(v, (:name, i), m.name, "What it measures") : ask!(v, (:item, i))
end

describe(r::MeasureRow) = begin
  v, i = r.of, r.i
  i <= length(v.data.measures) || return Box(height(0px))
  m = v.data.measures[i]
  cell(what) = part!(() -> MeasureCell(of=v, i=i, what=what), v, (:cell, i, what))
  amount = Plans.amount(v.data, m)
  row = known(v, m.item)
  # A Text on its own would take all of the row, so each is in a box that the row puts at its right
  # It's as tall as the row, so that what cuts a long text off at the side doesn't cut the tail of a comma or a g
  right(wide, s, colour) = Row(fixed(wide), height(grow=grow), Alignment.Center, justify=Alignment.End, clip=true, Box(label(s, 13px, color=colour)))
  back = background(v.current == i ? colours.active : ishovered(r) ? colours.hover : clear)
  # The first row has a line that doesn't show, so that its words are where the other rows' are
  line = (border(1px, :solid, !isempty(v.order) && v.order[1] == i ? clear : colours.line)[:top],)
  size = part!(() -> AmountCell(of=v, i=i), v, (:amount, i))
  cost = right(88px, row === nothing || amount === nothing ? "" : dollars(cost_of(m, amount, row)), colours.ink)
  remove = button!(v, (:delete, i), (:delete, i), icon="x-lg", tip="Remove this measure")
  # The panel beside a plan that fills the window is narrow, so a measure has two lines there
  # The cost and the price have columns only while a measure has an item to price it
  costs = has_items(v) ? (cost,) : ()
  v.beside && return Column(width(grow=grow), Alignment.Start, padding(10px, 4px), name="Measure", back, line...,
    Row(width(grow=grow), height(26px), child_gap=8px, Alignment.Center, swatch(m.kind, hue(i)), cell(:item), size),
    Row(width(grow=grow), height(26px), child_gap=8px, Alignment.Center, Box(width(14px)), cell(:extra), Box(width(grow=grow)), costs..., remove))
  Row(width(grow=grow), height(32px), padding(10px, 0px), child_gap=10px, Alignment.Center, name="Measure", back, line...,
    swatch(m.kind, hue(i)), cell(:item), cell(:extra), size,
    # A narrow block has no room for the price of one, so it shows what the measure comes to and no more
    # The price is for one of the measure's unit, so it needs no unit after it. One that the measure can't be in says its own.
    (has_price(v) ? (right(96px, row === nothing ? "" : (p = unit_price(m, row); p === nothing ? price_text(row) : dollars(p)), colours.dim),) : ())...,
    costs..., remove)
end

cursor(::MeasureRow) = :hand

"Make measure `i` the one that the tools draw for, and choose the tool of its kind"
choose_measure!(v::TakeoffView, i::Int) = begin
  i <= length(v.data.measures) || return handled
  v.current = i
  tool!(v, v.data.measures[i].kind)
end

onkey(r::MeasureRow, ::KeyPress{Keys.mouse_left}) = choose_measure!(r.of, r.i)

# --- the units of a measure --------------------------------------------------------------
#
# A click on the unit after a measure's amount shows the list of units that it
# can be in, as Centient's unit picker does: each unit's name, and the short
# form that goes after an amount at the right. A field at the top of the list
# searches it. The up and down arrows pick a unit, and so does the mouse. Return or a
# click takes it. Esc, or a click somewhere else, closes the list and changes
# nothing.

const UNIT_KEY = :takeoff_units
const AMOUNT_W = 96px    # how wide the column of amounts is
const MOST_UNITS = 8     # the units that the list shows before it scrolls

"""
The units that measure `i` can be in. One with nothing drawn and no item can be
a count, a length or an area, so it can take a unit of each kind. Any other
keeps its kind.
"""
units_for(v::TakeoffView, i::Int) = begin
  i <= length(v.data.measures) || return String[]
  m = v.data.measures[i]
  isempty(m.shapes) && isempty(m.item) ? reduce(vcat, collect(Plans.KIND_UNITS)) : copy(getfield(Plans.KIND_UNITS, m.kind))
end

"Write a unit as a keyboard can: m^2 or m2 for m². What's typed is folded the other way, so that each finds the other."
fold_unit(s::AbstractString) = begin
  s = replace(lowercase(s), "^2" => "²", "^3" => "³")
  replace(s, r"([a-z]+)([23])(?!\d)" => m -> m[1:end-1] * (m[end] == '2' ? "²" : "³"))
end

"Other words that a unit is typed as"
const UNIT_EXTRAS = Dict("hectare" => ["ha", "hectares"], "ft" => ["feet"], "inch" => ["in", "inches"],
                         "ft²" => ["sq ft", "square feet"], "m" => ["meter"], "m²" => ["sqm", "square meter"], "Piece" => ["each"])

"True when `words` find `unit`: they're in its name, its short form, or the name that Centient gives it"
unit_matches(unit::AbstractString, words::AbstractString) = begin
  isempty(words) && return true
  q = fold_unit(words)
  any(h -> occursin(q, fold_unit(h)), [Plans.UNIT_WORDS[unit], Plans.unit_short(unit), unit, get(UNIT_EXTRAS, unit, String[])...])
end

"True when `words` are a name of `unit` and not only part of one: metre for m, and not for mm"
names_unit(unit::AbstractString, words::AbstractString) =
  (q = fold_unit(words); any(h -> fold_unit(h) == q, [Plans.UNIT_WORDS[unit], Plans.unit_short(unit), unit, get(UNIT_EXTRAS, unit, String[])...]))

"The unit word of the amount `c`. It belongs to the amount, so the mouse over it is over the amount too."
unit_word(c::AmountCell) = begin
  c.unit === nothing && (c.unit = UnitWord(of=c); setfield!(c.unit, :parent, c))
  c.unit
end

describe(c::AmountCell) = begin
  v, i = c.of, c.i
  i <= length(v.data.measures) || return Box(width(0px))
  m = v.data.measures[i]
  amount = Plans.amount(v.data, m)
  # It's as tall as the row, so that what cuts a long amount off at the side doesn't cut the tail of a comma or a g
  cell(parts...) = Row(fixed(AMOUNT_W), height(grow=grow), Alignment.Center, justify=Alignment.End, clip=true, name="Amount", parts...)
  amount === nothing && return cell(Box(label("No scale", 13px, color=colours.accent)))
  unit = Plans.unit(m)
  number = Box(label(Plans.amount_number(Plans.in_unit(amount, unit)), 13px, color=colours.ink))
  # The unit is there to click when the measure can be in another. A count that can only be in pieces is a number.
  length(units_for(v, i)) > 1 ? cell(number, unit_word(c)) : cell(Box(label(Plans.shown(m, amount), 13px, color=colours.ink)))
end

cursor(::AmountCell) = :hand
# A click on the number chooses the measure, as a click on the rest of its row does
onkey(c::AmountCell, ::KeyPress{Keys.mouse_left}) = choose_measure!(c.of, c.i)

describe(w::UnitWord) = begin
  c = w.of
  v = c.of
  c.i <= length(v.data.measures) || return Box(width(0px))
  unit = Plans.unit(v.data.measures[c.i])
  lit = ishovered(w) || v.asking == (:unit, c.i)
  # A foot and an inch are marks right after the number. Another unit has a space before it, and the space is the unit's to click.
  Row(height(grow=grow), padding(0px, 0px, 0px, unit in ("inch", "ft") ? 1px : 4px), Alignment.Center,
    label(Plans.unit_short(unit), 13px, color=lit ? colours.accent : colours.ink))
end

cursor(::UnitWord) = :hand
onkey(w::UnitWord, ev::KeyPress{Keys.mouse_left}) = open_units!(w.of, ev.window)

"Show the list of the units that the measure of the amount `c` can be in, under its unit"
open_units!(c::AmountCell, window) = begin
  v, i = c.of, c.i
  i <= length(v.data.measures) || return handled
  ask!(v, (:unit, i), "", "Filter…")
  v.query = ""   # so that the first frame keeps the unit that's picked
  v.rows = Any[units_for(v, i)...]
  v.pick = something(findfirst(==(Plans.unit(v.data.measures[i])), v.rows), 1)
  menu = UnitMenu(of=v, i=i)
  v.parts[:unit_menu] = menu
  popup!(window, menu, anchor=unit_word(c), placement=:bottom, gap=9px, width=230px, key=UNIT_KEY,
         onclose=() -> settle_asking!(v), theme=component_theme(editor(v).zoom))
  handled
end

"""
Put measure `i` in `unit`. A unit of another kind makes a measure with nothing
drawn and no item that kind. The tool for it is ready to draw.
"""
unit!(v::TakeoffView, i::Int, unit::AbstractString) = begin
  stop_asking!(v)
  i <= length(v.data.measures) || return handled
  m = v.data.measures[i]
  kind = Plans.unit_kind(unit)
  kind === nothing && return handled
  if kind != m.kind
    (isempty(m.shapes) && isempty(m.item)) || return handled
    kind!(v, m, kind)
  end
  Plans.unit!(m, unit)
  commit!(v)
  v.current = i
  tool!(v, m.kind)
end

# The list of units and the lists at the top of a `find` block are one kind of
# list. These three draw it: the box with the field at its top, a row of it, and
# the words that take the place of its rows when nothing matches.

"""
A list that floats beside what it's for, with a field at its top that searches
it. `input` is the field, or nothing for a list with no field, and `body` is
the rows under it.
"""
float_list(input, body; name="List") = begin
  c = found_colours()
  field = input === nothing ? () :
    (Box(width(grow=grow), padding(2px, 2px),
       Box(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), border(1px, :solid, c.line), background(c.frame), input)),)
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name=name,
    Column(width(grow=grow), Alignment.Start, child_gap=4px, field..., body))
end

"What such a list says in place of its rows when nothing in it matches"
float_none(words) = Row(width(grow=grow), height(FLOAT_ROW), padding(8px, 0px), Alignment.Center, label(words, 12px, color=found_colours().dim))

describe(r::UnitRow) = begin
  v = r.of
  r.k <= length(v.rows) || return Box(height(0px))
  unit = v.rows[r.k]
  a = v.asking
  on = a !== nothing && a[1] == :unit && a[2] <= length(v.data.measures) && Plans.unit(v.data.measures[a[2]]) == unit
  short = Plans.unit_short(unit)
  name = Plans.UNIT_WORDS[unit]
  # The short form shows when it isn't the name again
  float_row(name, lowercase(short) == lowercase(name) ? "" : short, picked=v.pick == r.k, on=on)
end

cursor(::UnitRow) = :hand
onkey(r::UnitRow, ::KeyPress{Keys.mouse_left}) = begin
  v, a = r.of, r.of.asking
  a !== nothing && a[1] == :unit && r.k <= length(v.rows) ? unit!(v, a[2], v.rows[r.k]) : handled
end
# The mouse picks the unit that it's over, as the arrow keys do
onmouse(r::UnitRow, ::MouseMove) = begin
  v = r.of
  v.pick = r.k
  menu = get(v.parts, :unit_menu, nothing)
  menu === nothing || (menu.pick = r.k)   # it's in sight already, so the list doesn't scroll to it
  handled
end

describe(m::UnitMenu) = begin
  v = m.of
  n, high = length(v.rows), FLOAT_ROW
  scroll = get!(() -> Scroll(width(grow=grow)), v.parts, :unit_scroll)
  body = if n == 0
    float_none("No unit has that name")
  else
    # Half a row at the bottom says that the list goes on
    scroll.height = height(n <= MOST_UNITS ? n * high : MOST_UNITS * high - high / 2)
    m.pick == v.pick || (m.pick = v.pick; scroll_into_view!(scroll, high * (v.pick - 1), high * v.pick))
    reuse!(scroll, Column(width(grow=grow), Alignment.Start, [part!(() -> UnitRow(of=v, k=k), v, (:unit_row, k)) for k in 1:n]...))
  end
  float_list(plan_input(v), body, name="Units")
end

placed!(m::UnitMenu, side) = (m.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, m::UnitMenu) = caret(ctx, ui, m.side, rect(unit_word(part!(() -> AmountCell(of=m.of, i=m.i), m.of, (:amount, m.i)))))

# The list sees a key before its field does. The arrows pick a unit, Return takes it, and Esc closes the list.
onkey(m::UnitMenu, ev::KeyPress{Keys.enter}) = unmodified(ev) ? answer!(m.of) : nothing
onkey(m::UnitMenu, ev::KeyPress{Keys.escape}) = unmodified(ev) ? stop_asking!(m.of) : nothing
onkey(m::UnitMenu, ev::KeyPress{Keys.down}) = unmodified(ev) ? (v = m.of; v.pick = min(v.pick + 1, max(1, length(v.rows))); handled) : nothing
onkey(m::UnitMenu, ev::KeyPress{Keys.up}) = unmodified(ev) ? (v = m.of; v.pick = max(v.pick - 1, 1); handled) : nothing

# --- the list that a search shows --------------------------------------------------------
#
# What a search finds shows in a list that floats beside the text field. It
# looks like the lists in Centient's own forms: a cream box with an arrow that
# points at the field, and in it a card with a line for each thing found. The
# up and down arrows pick a line, and so does the mouse. Return or a click
# takes it. Esc closes the list, and so does a click somewhere else.

const FOUND_KEY = :takeoff_found
# The search for an item looks in one catalogue at a time, as Centient's own
# item field does. It starts in the business's own items. ⌥ in an empty field,
# or a click on the foot of the list, shows the suppliers whose catalogues
# Centient holds. A supplier chosen there opens its catalogue, and the search
# goes on in that. ⌥ again goes back to the suppliers, and from the suppliers
# to the business's own items. The next search starts where an item was last
# chosen from.

"""
The catalogue that the search for an item looks in: `(:own,)` for the
business's own items, `(:suppliers,)` for the list of suppliers to choose a
catalogue from, or `(:catalogue, slug, name)` for one supplier's.
"""
const ITEM_FROM = Ref{Any}((:own,))

"Look in another catalogue. The words that were typed go, and a search of the new one starts now."
browse!(v::TakeoffView, from) = begin
  ITEM_FROM[] = from
  i = plan_input(v)
  i.text = ""
  i.anchor, i.cursor = 0, 0
  v.rows, v.search, v.pick = Any[], nothing, 1
  v.query, v.typed = "", time() - 1
  handled
end

"Go from the business's own items to the list of suppliers, and from the list or a supplier's catalogue back"
toggle_catalogue!(v::TakeoffView) = browse!(v, ITEM_FROM[][1] == :catalogue ? (:suppliers,) : ITEM_FROM[][1] == :suppliers ? (:own,) : (:suppliers,))

"What the foot of the list says of the catalogue that it shows"
catalogue_words() = (from = ITEM_FROM[]; from[1] == :own ? "Our catalogue" : from[1] == :suppliers ? "Pick a catalogue" : from[3])

"True when the list shows suppliers to choose from, and false when it shows items"
lists_suppliers(v::TakeoffView) = v.asking !== nothing && v.asking[1] == :item && ITEM_FROM[][1] == :suppliers

"How tall a line of the list is. An item has a second line under its name. A contact or a supplier has its name and no more."
found_h(v::TakeoffView) = v.asking == (:customer,) || lists_suppliers(v) ? 34px : 50px

"Show the list of what the search finds, beside the text field"
show_found!(v::TakeoffView) = begin
  w = window_of(v)
  w === nothing && return
  e = editor(v)
  wide = min(v.asking == (:customer,) ? 340px : 460px, window_size(e)[1] - 16px)
  list = FoundList(of=v)
  v.parts[:found_list] = list
  # The keys stay with the text field, and a click outside the list is the app's, as it is with no list
  list.popup = popup!(w, list, anchor=plan_input(v), placement=:bottom, gap=FOUND_GAP, width=wide, key=FOUND_KEY, modal=false,
                      onclose=() -> stop_asking!(v), theme=component_theme(e.zoom))
end

const FOUND_GAP = 9px   # between the text field and the list, with the list's arrow in it

"""
Choose the side of the text field that the list is on, once for each time it
opens. The list goes under the field when the longest list fits there, and
if not, on the side with more room. A short list, like the one line that shows
while Centient searches, is then on the side that the long list will be on, so
the list doesn't jump from one side to the other.
"""
settle_side!(l::FoundList) = begin
  (l.settled || l.popup === nothing) && return
  v = l.of
  r = rect(plan_input(v))
  r === nothing && return
  item = v.asking !== nothing && v.asking[1] == :item
  # The longest list: its rows, the edges round them, and the foot that names the catalogue
  longest = MOST_FOUND * (item ? 50px : 34px) + 14px + (item ? 28px : 0px)
  over, under = r.top - FOUND_GAP, window_size(editor(v))[2] - r.top - r.height - FOUND_GAP
  l.popup.placement = under >= longest || under >= over ? :bottom : :top
  l.settled = true
end

placed!(l::FoundList, side) = (l.side = side; nothing)

describe(r::FoundRow) = begin
  v = r.of
  r.k <= length(v.rows) || return Box(height(0px))
  row = v.rows[r.k]
  c = found_colours()
  picked = v.pick == r.k
  ref = string(get(row, "ref", ""))
  # Under an item of the business is what it says of it. Under a supplier's product is the supplier's code for it.
  under = isempty(ref) ? "" : startswith(ref, "item ") ? string(something(get(row, "description", nothing), "")) : String(last(split(ref, ' ', limit=2)))
  # At the right is an item's price, and how many products a supplier's catalogue has
  right = !isempty(ref) ? price_text(row) : haskey(row, "slug") ? commas(round(Int, get(row, "products", 0))) * " products" : ""
  # A thin line parts two rows, but not the picked row from the ones beside it. A row with no line has one in its
  # own colour, so that its words don't move by the line's height when the pick comes to it or leaves it.
  back = picked ? c.pick : c.frame
  Row(width(grow=grow), height(found_h(v)), padding(12px, 0px), child_gap=10px, Alignment.Center, background(back),
      border(1px, :solid, r.k == 1 || picked || v.pick == r.k - 1 ? back : c.rule)[:top],
    # As tall as the row, so that what cuts a long name off at the side doesn't cut the tails of its g, p and y
    Column(width(grow=grow), height(grow=grow), Alignment.Start, justify=Alignment.Center, child_gap=6px, clip=true,
      label(string(row["name"]), 13px, color=c.ink),
      (isempty(under) ? () : (label(under, 11px, color=c.dim),))...),
    (isempty(right) ? () : (Box(label(right, 12px, color=c.dim)),))...)
end

cursor(::FoundRow) = :hand
onkey(r::FoundRow, ::KeyPress{Keys.mouse_left}) = choose_row!(r.of, r.k)
# The mouse picks the row that it's over, as the arrow keys do
onmouse(r::FoundRow, ::MouseMove) = begin
  v = r.of
  v.pick = r.k
  list = get(v.parts, :found_list, nothing)
  list === nothing || (list.pick = r.k)   # it's in sight already, so the list doesn't scroll to it
  handled
end

describe(l::FoundList) = begin
  v = l.of
  settle_side!(l)
  c = found_colours()
  high, n = found_h(v), length(v.rows)
  scroll = get!(() -> Scroll(width(grow=grow)), v.parts, :found_scroll)
  l.rows === v.rows || (l.rows = v.rows; l.pick = 0; scroll.offset = 0px)
  item = v.asking !== nothing && v.asking[1] == :item
  body = if n == 0
    words = v.search !== nothing || v.typed > 0 ? "Searching Centient…" :
            !isempty(v.query) && v.query != "\0" ? "Centient has nothing that matches" :
            lists_suppliers(v) ? "Centient holds no supplier's catalogue" : item ? "Nothing here yet" : "Type to search"
    Row(width(grow=grow), height(34px), padding(12px, 0px), Alignment.Center, background(c.frame), label(words, 12px, color=c.dim))
  else
    # Half a row at the bottom says that the list goes on
    scroll.height = height(min(n * high, MOST_FOUND * high - high / 2))
    l.pick == v.pick || (l.pick = v.pick; scroll_into_view!(scroll, high * (v.pick - 1), high * v.pick))
    reuse!(scroll, Column(width(grow=grow), Alignment.Start, [part!(() -> FoundRow(of=v, k=k), v, (:found, k)) for k in 1:n]...))
  end
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Found",
    Column(width(grow=grow), Alignment.Start, child_gap=4px,
      Column(width(grow=grow), Alignment.Start, radius(5px), border(1px, :solid, c.line), background(c.frame), clip=true, body),
      (item ? (part!(() -> CatalogueFoot(of=v), v, :catalogue_foot),) : ())...))
end

# The foot of the list of items says which catalogue it shows. A click on it does what ⌥ does.
describe(f::CatalogueFoot) = begin
  c = found_colours()
  Row(width(grow=grow), height(24px), padding(8px, 0px), radius(5px), child_gap=8px, Alignment.Center, background(ishovered(f) ? c.pick : c.frame),
    Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true, label(catalogue_words(), 12px, color=c.ink, weight="Semibold")),
    Box(label("⌥ to toggle catalogue", 11px, color=c.dim)))
end
cursor(::CatalogueFoot) = :hand
onmouse(::CatalogueFoot, ::MouseMove) = handled
onkey(f::CatalogueFoot, ::KeyPress{Keys.mouse_left}) = toggle_catalogue!(f.of)

"""
Draw the arrow of a floating box `ui`, on its edge that faces what it's for.
`side` is the side of that thing that the box is on, and `aim` is the thing's
rectangle. The arrow covers the box's border where it joins.
"""
caret(ctx, ui::ConcreteRect, side, aim) = begin
  aim === nothing && return
  c = found_colours()
  left, top, wide, high = num(ui.left), num(ui.top), num(ui.width), num(ui.height)
  x = clamp(num(aim.left + aim.width / 2), left + 16, max(left + 16, left + wide - 16))
  # The box's border is a line 1px wide along the middle of the first px of its edge. The arrow's sides start on
  # that line, so they join it with nothing past it.
  edge, way = side == :top ? (top + high - 0.5, 1) : (top + 0.5, -1)
  half, tall = 7.0, 6.5
  tip = edge + way * tall
  # Its inside goes 1px past that line into the box, on the same slant, so that no border shows across the arrow
  inner, spread = edge - way, half * (1 + 1 / tall)
  shape = path_through([(x - spread, inner), (x, tip), (x + spread, inner)], true)
  paint = ink(c.frame)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_paint_delete(paint)
  Skia.sk_path_delete(shape)
  trace(ctx, [(x - half, edge), (x, tip), (x + half, edge)], c.line, 1)
end

draw(ctx, size, ui::ConcreteRect, l::FoundList) = caret(ctx, ui, l.side, rect(plan_input(l.of)))

# --- the columns of the table ------------------------------------------------------------
#
# The headings of the table of measures work as the headings of Centient's
# lists do. A click on a heading of numbers sorts by it: low to high, then high
# to low, then the order that the block is written in. A click on a heading of
# text opens a menu with its two orders and a field that searches the column.
# Return keeps the search, and Esc puts back the one before. A heading whose
# column is searched is in the accent colour. Sorting and searching change what
# the table shows, and nothing in the block or in the quote.

const HEAD_KEY = :takeoff_column
"The columns of the table that sort: the heading of each, and whether it holds text"
const COLUMNS = (item=("Item", true), extra=("Waste", false), amount=("Amount", false), price=("Price", false), cost=("Cost", false))
"What the two orders of a column are called"
order_words(text::Bool) = text ? ("A–Z", "Z–A") : ("Low → High", "High → Low")

"The item of a measure in words, as its column sorts and searches it: what the table calls it, and the catalogue that it's from"
item_words(v::TakeoffView, m) = (row = known(v, m.item); item_name(v, m) * (row === nothing ? "" : "  ·  " * string(row["source"])))

"What measure `i` has in the column `key`, as the thing that the column sorts by"
column_value(v::TakeoffView, i, key) = begin
  m = v.data.measures[i]
  key == :item && return lowercase(item_words(v, m))
  key == :extra && return m.extra
  amount, row = Plans.amount(v.data, m), known(v, m.item)
  key == :amount ? something(amount, -1.0) :
  key == :price  ? (row === nothing ? -1.0 : Float64(something(unit_price(m, row), row["price"]))) :
                   (row === nothing || amount === nothing ? -1.0 : cost_of(m, amount, row))
end

"Search the column `key` for `words`. No words takes its search away."
search_column!(v::TakeoffView, key::Symbol, words) = begin
  words = String(strip(words))
  isempty(words) ? delete!(v.filters, key) : (v.filters[key] = words)
  v
end

"The measures that the table shows, in the order that it shows them: those that the searches keep, sorted by the column that's chosen"
shown_measures(v::TakeoffView) = begin
  ms = v.data.measures
  # The item's column is the one that holds text, so a search is of it
  keep = [i for i in eachindex(ms) if all(words -> occursin(lowercase(words), lowercase(item_words(v, ms[i]))), values(v.filters))]
  v.sort === nothing ? keep : sort!(keep, by=i -> column_value(v, i, v.sort[1]), rev=v.sort[2] == :desc)
end

"The heading of the column `key`. `side` is the side of its cell that its words go on, and nothing keeps the side that it has."
head(v::TakeoffView, key::Symbol, side=nothing) = begin
  h = part!(() -> ColumnHead(of=v, key=key), v, (:head, key))
  side === nothing || (h.side = side)
  h
end

"""
The words of the heading of the column `key`. They belong to the heading, so a
click on them goes to it, and the mouse over them is over it.
"""
head_words(v::TakeoffView, key::Symbol) = begin
  h = head(v, key)
  h.words === nothing && (h.words = HeadWords(of=h); setfield!(h.words, :parent, h))
  h.words
end

"The order that a click on a heading of numbers gives next. It's nothing for the order that the block is written in."
next_order(v::TakeoffView, key) = v.sort === nothing || v.sort[1] != key ? :asc : v.sort[2] == :asc ? :desc : nothing

describe(h::ColumnHead) =
  Row(width(grow=grow), height(grow=grow), Alignment.Center, justify=h.side == :end ? Alignment.End : Alignment.Start, name="Heading",
    head_words(h.of, h.key))

describe(w::HeadWords) = begin
  h = w.of
  v = h.of
  words, text = COLUMNS[h.key]
  dir = v.sort !== nothing && v.sort[1] == h.key ? v.sort[2] : nothing
  open = v.asking !== nothing && v.asking[1] == :filter && v.asking[2] == h.key
  lit = ishovered(h) || open
  colour = haskey(v.filters, h.key) ? colours.accent : lit || dir !== nothing ? colours.ink : colours.dim
  # The arrow of the order that it has. With none, the mouse over it shows what a click gives.
  will = text ? :desc : next_order(v, h.key)
  mark = dir !== nothing ? (Icon(dir == :asc ? "chevron-up" : "chevron-down", size=9px, color=colours.ink),) :
         lit && will !== nothing ? (Icon(will == :asc ? "chevron-up" : "chevron-down", size=9px, color=colours.faint),) : ()
  parts = (label(words, 11px, color=colour), mark...)
  # The arrow goes on the side away from the cell's edge, so that it doesn't push the words when it shows
  Row(height(20px), child_gap=4px, Alignment.Center, (h.side == :start ? parts : reverse(parts))...)
end

cursor(::ColumnHead) = :hand

# A heading of numbers says what a click on it does
onmouse(h::ColumnHead, ev::MouseMove) = begin
  COLUMNS[h.key][2] && return
  will = next_order(h.of, h.key)
  low, high = order_words(false)
  words = will == :asc ? low : will == :desc ? high : "The order they're written in"
  # The tooltip follows the words: the mouse over them shows their arrow, which makes them wider on the next frame
  show_tooltip!(ev.window, tip_label(words), head_words(h.of, h.key), placement=:bottom, gap=6px)
end

onkey(h::ColumnHead, ev::KeyPress{Keys.mouse_left}) = begin
  v = h.of
  hide_tooltip!(ev.window)
  settle_asking!(v)
  COLUMNS[h.key][2] || return (will = next_order(v, h.key); v.sort = will === nothing ? nothing : (h.key, will); handled)
  # The menu's field starts with the column's search, which Esc puts back
  was = get(v.filters, h.key, "")
  ask!(v, (:filter, h.key, was), was, "Contains…")
  menu = ColumnMenu(of=v, key=h.key)
  v.parts[:column_menu] = menu
  # A click outside the menu closes it and keeps what's typed
  popup!(ev.window, menu, anchor=head_words(v, h.key), placement=:bottom, gap=9px, width=210px, key=HEAD_KEY,
         onclose=() -> settle_asking!(v), theme=component_theme(editor(v).zoom))
  handled
end

placed!(m::ColumnMenu, side) = (m.side = side; nothing)

describe(r::SortRow) = begin
  v, c = r.of, found_colours()
  on = v.sort == (r.key, r.dir)
  words = order_words(COLUMNS[r.key][2])[r.dir == :asc ? 1 : 2]
  Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(on || ishovered(r) ? c.pick : c.frame),
    Icon(r.dir == :asc ? "chevron-up" : "chevron-down", size=10px, color=on ? c.ink : c.dim),
    label(words, 13px, color=on ? c.ink : c.dim, weight=on ? "Semibold" : ""))
end

cursor(::SortRow) = :hand
onmouse(::SortRow, ::MouseMove) = handled
# A click on the order that the table has takes it away
onkey(r::SortRow, ::KeyPress{Keys.mouse_left}) = (v = r.of; v.sort = v.sort == (r.key, r.dir) ? nothing : (r.key, r.dir); handled)

describe(m::ColumnMenu) = begin
  v, c = m.of, found_colours()
  section(words) = Row(width(grow=grow), height(22px), padding(8px, 0px), Alignment.Center, label(words, 10px, color=c.dim, weight="Semibold"))
  order(dir) = part!(() -> SortRow(of=v, key=m.key, dir=dir), v, (:sort, m.key, dir))
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Column menu",
    Column(width(grow=grow), Alignment.Start,
      section("SORT"), order(:asc), order(:desc),
      Box(width(grow=grow), height(13px), Alignment.Center, Box(width(grow=grow), height(1px), background(c.rule))),
      section("FILTER FOR"),
      Box(width(grow=grow), padding(4px, 2px),
        Box(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), border(1px, :solid, c.line), background(c.frame), plan_input(v)))))
end

draw(ctx, size, ui::ConcreteRect, m::ColumnMenu) = caret(ctx, ui, m.side, rect(head_words(m.of, m.key)))

# The menu sees a key before its text field does. Return keeps the search, and Esc puts back the one before.
onkey(m::ColumnMenu, ev::KeyPress{Keys.enter}) = unmodified(ev) ? answer!(m.of) : nothing
onkey(m::ColumnMenu, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  v = m.of
  a = v.asking
  a !== nothing && a[1] == :filter && search_column!(v, a[2], a[3])
  stop_asking!(v)
end

# --- the whole block ---------------------------------------------------------------------

toolbar(v::TakeoffView) = begin
  t = v.data
  n = plan_pages(v)
  s = Plans.scale(t, t.page)
  file = isempty(t.plan) ? "Choose a plan" : basename(t.plan)
  Row(width(grow=grow), height(38px), padding(6px, 0px), child_gap=2px, Alignment.Center, background(colours.block),
    [button!(v, (:tool, tool), (:tool, tool), icon=icon, tip=tip) for (tool, (icon, tip, _)) in PLAN_TOOLS]...,
    rule(),
    button!(v, :snap, :snap, icon="magnet", tip=v.snap ? "Corners snap to the lines of the plan. Click to stop that, or hold ⌘." : "Snap corners to the lines of the plan"),
    rule(),
    button!(v, :scale, :scale, words=s === nothing ? "Set the scale" : Plans.scale_text(s), tip="Type the scale of this page, like 1:100"),
    (n > 1 ? (rule(), button!(v, :back, (:page, -1), icon="chevron-left", tip="The page before", off=t.page <= 1),
              label("Page $(t.page) of $n", 12px, color=colours.dim),
              button!(v, :next, (:page, 1), icon="chevron-right", tip="The next page", off=t.page >= n)) : ())...,
    Box(width(grow=grow)),
    button!(v, :smaller, (:zoom, 1 / 1.4), icon="zoom-out", tip="Smaller"),
    button!(v, :bigger, (:zoom, 1.4), icon="zoom-in", tip=v.full ? "Bigger  pinch, or the mouse wheel" : "Bigger  pinch, or ⌘ and scroll"),
    button!(v, :fit, :fit, icon="aspect-ratio", tip="Show the whole page"),
    button!(v, :full, :full, icon=v.full ? "fullscreen-exit" : "arrows-fullscreen", tip=v.full ? "Back to the page  esc" : "Fill the window"),
    rule(),
    button!(v, :plan, :choose, icon="file-earmark-pdf", words=length(file) > 28 ? first(file, 27) * "…" : file, tip="Choose the plan's file"))
end

"The line under the tools that asks for the scale, or for the length of the line that was drawn"
prompt(v::TakeoffView) = begin
  a = v.asking
  (a !== nothing && a[1] in (:scale, :length)) || return ()
  words, hint = a[1] == :scale ? ("The scale of this page", "like 1:100, then Return") :
                                 ("How long is the line that you drew?", "in metres, like 3.6, or 3600mm, then Return")
  (Row(width(grow=grow), height(36px), padding(12px, 0px), child_gap=10px, Alignment.Center, background(colours.float),
     label(words, 12px), field(v, fixed(110px)), label(hint, 12px, color=colours.dim)),)
end

"""
True when a measure has an item of Centient's catalogue. Only then is there a
price to show, so only then has the table its columns for the price and the cost.
"""
has_items(v::TakeoffView) = any(m -> !isempty(m.item), v.data.measures)

"True when the table of measures shows the price of one of each item: when a measure has an item, and there's room"
has_price(v::TakeoffView) = has_items(v) && editor(v).width >= 720px

"""
The headings of the table of measures. Each is as wide as the cells under it.
The panel beside a plan has two lines for each measure, so it has two
headings and no more: the item and its cost. The cost and the price have
headings only while a measure has an item.
"""
table_head(v::TakeoffView) = begin
  # Each heading fills its cell, so the mouse can use it anywhere over its column
  left(key) = Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true, head(v, key, :start))
  right(wide, key) = Row(wide, height(grow=grow), Alignment.Center, clip=true, (key === nothing ? () : (head(v, key, :end),))...)
  # With no Centient on the Mac there are no prices, so the columns for them have no headings
  ours(key) = Centient.available() ? key : nothing
  cost = has_items(v) ? (right(fixed(88px), ours(:cost)),) : ()
  look = (width(grow=grow), height(26px), Alignment.Center, background(colours.head), border(1px, :solid, colours.line)[:bottom])
  v.beside && return Row(look..., padding(10px, 0px), child_gap=8px, name="Headings",
    Box(width(14px)), left(:item), cost..., Box(width(28px)))
  Row(look..., padding(10px, 0px), child_gap=10px, name="Headings",
    Box(width(14px)), left(:item), Row(fixed(52px), height(grow=grow), Alignment.Center, clip=true, head(v, :extra, :start)),
    right(fixed(AMOUNT_W), :amount), (has_price(v) ? (right(fixed(96px), ours(:price)),) : ())..., cost...,
    Box(width(28px)))   # over the buttons that remove a measure
end

"""
The table of measures, in a box of its own with round corners: the headings,
then `rows`, then the button that adds a measure. `tall` makes it fill the
height that it's given.
"""
table(v::TakeoffView, rows; tall=false) =
  Box(width(grow=grow), (tall ? (height(grow=grow),) : ())..., padding(10px, 8px),
    Column(width(grow=grow), (tall ? (height(grow=grow),) : ())..., Alignment.Start, radius(8px), border(1px, :solid, colours.line),
           background(colours.bg), clip=true, name="Measures",
      table_head(v), rows, adders(v)))

"""
The buttons at the foot of the table that start a new measure. One starts a
measure that you describe in words. The other starts one for an item of
Centient's catalogue, and shows only on a Mac that has Centient.
"""
adders(v::TakeoffView) =
  Row(width(grow=grow), height(36px), padding(6px, 0px), child_gap=2px, Alignment.Center, border(1px, :solid, colours.line)[:top],
    button!(v, :add, :add, icon="plus-lg", words="Add a measure",
            tip="Say what it measures. Then choose a tool: count, length or area."),
    (Centient.available() ? (button!(v, :add_item, :add_item, icon="box-seam", words="Add from catalogue",
                                     tip="Choose an item of Centient's catalogue. Its unit chooses the tool."),) : ())...)

"The rows of the table of measures: those that the columns' searches keep, in the order of the column that's sorted"
measure_rows(v::TakeoffView) = begin
  v.order = shown_measures(v)
  isempty(v.order) && !isempty(v.data.measures) &&
    return Any[Row(width(grow=grow), height(32px), padding(34px, 0px), Alignment.Center, label("No measure has that", 12px, color=colours.dim))]
  Any[part!(() -> MeasureRow(of=v, i=i), v, (:row, i)) for i in v.order]
end

"The line at the foot of the block: the customer, what the measures come to, and the button that makes the quote"
foot(v::TakeoffView) = begin
  t = v.data
  total, priced, all_priced = 0.0, false, true
  for m in t.measures
    amount, row = Plans.amount(t, m), known(v, m.item)
    (amount === nothing || row === nothing) && (all_priced = false; continue)
    total += cost_of(m, amount, row)
    priced = true
  end
  # The total is of the measures that have an item. While a measure has none, the words say that the total leaves it out.
  total_words = all_priced ? "At catalogue prices" : "Catalogue items only"
  asking = v.asking == (:customer,)
  busy = v.quoting !== nothing
  said = isempty(v.said) ? (isempty(t.made) ? "" : "Quote $(t.made)") : v.said
  colour = v.wrong ? colours.accent : colours.dim
  customer = asking ? field(v, v.beside ? width(grow=grow) : fixed(220px)) :
             button!(v, :customer, :customer, words=isempty(t.customer) ? "Choose the customer" : t.customer, tip="Who the quote is for")
  maker = button!(v, :quote, :quote, icon="receipt", words=busy ? "Making the quote…" : isempty(t.made) ? "Make quote in Centient" : "Make another quote",
                  tip=Centient.available() ? "Centient makes a quote with a line for each measure" : "Centient isn't on this Mac",
                  off=busy || isempty(t.measures) || !Centient.available())
  line = border(1px, :solid, colours.line)[:top]
  # In the panel beside a plan that fills the window, each part of the foot has a line of its own
  v.beside && return Column(width(grow=grow), Alignment.Start, padding(10px, 8px), child_gap=6px, line,
    Row(width(grow=grow), height(28px), child_gap=8px, Alignment.Center, Icon("person", size=14px, color=colours.dim), customer),
    (priced ? (Row(width(grow=grow), height(22px), Alignment.Center, Box(label(total_words, 12px, color=colours.dim)),
                   Box(width(grow=grow)), Box(label(dollars(total), 13px, weight="Semibold"))),) : ())...,
    (isempty(said) ? () : (Box(width(grow=grow), Alignment.Start, Text(said, size=12px, family=SANS, color=colour, wrap=WrapMode.words)),))...,
    Row(width(grow=grow), justify=Alignment.End, maker))
  Row(width(grow=grow), height(42px), padding(10px, 0px), child_gap=8px, Alignment.Center, line,
    Icon("person", size=14px, color=colours.dim), customer,
    Row(width(grow=grow), clip=true, justify=Alignment.End, Box(label(said, 12px, color=colour))),
    # The catalogue's prices, before the GST and the margins that Centient adds to a quote
    (priced ? (label(total_words, 12px, color=colours.dim), label(dollars(total), 13px, weight="Semibold")) : ())...,
    maker)
end

"How tall the list of measures is, with what a search found under one of them"
list_h(v::TakeoffView) = 32px * max(1, length(v.order))

"The most of the window's height that the list of measures takes under a plan that fills the window"
const LIST_SHARE = 0.4

"""
True when the list of measures goes beside a plan that fills the window, and
false when it goes under it. It goes where it leaves the page bigger: beside a
wide window's plan, and under a tall window's.
"""
goes_beside(v::TakeoffView) = begin
  w, h = num.(window_size(editor(v)))
  h -= num(above_page(editor(v))) + 38   # the top bar and the tools
  s = plan_size(v)
  s === nothing && return w > h
  side = min(num(SIDE_W), 0.45w)
  # Under the plan are the table, with its headings, its rows and the button that adds a measure, and the foot
  under = min(32.0 * length(v.data.measures), LIST_SHARE * h) + 26 + 36 + 18 + 42
  min((w - side) / s[1], h / s[2]) >= min(w / s[1], (h - under) / s[2])
end

describe(v::TakeoffView) = begin
  e = editor(v)
  plan_input(v).color = colours.ink
  area = part!(() -> PlanArea(of=v), v, :area)
  v.beside = v.full && goes_beside(v)
  with_theme(component_theme(e.zoom)) do
    # Only the tools have a colour of their own behind them. The rest is on white, and the plan's paper has a shadow.
    v.full || return Column(width(grow=grow), Alignment.Start, radius(8px), border(1px, :solid, colours.line), background(takeoff_back()),
                            clip=true, name="Takeoff",
      toolbar(v), prompt(v)..., area,
      table(v, Column(width(grow=grow), Alignment.Start, measure_rows(v)...)),
      foot(v))
    # In the window, the plan is as big as it can be. The wheel scrolls through a list of measures that's longer than its room.
    list = get!(() -> Scroll(width(grow=grow), height(grow=grow)), v.parts, :list)
    rows = Column(width(grow=grow), Alignment.Start, measure_rows(v)...)
    if v.beside
      list.height = height(grow=grow)
      return Row(width(grow=grow), height(grow=grow), Alignment.Start, background(takeoff_back()), name="Takeoff",
        Column(width(grow=grow), height(grow=grow), Alignment.Start, toolbar(v), prompt(v)..., area),
        Column(fixed(min(SIDE_W, window_size(e)[1] * 0.45)), height(grow=grow), Alignment.Start, border(1px, :solid, colours.line)[:left],
          table(v, reuse!(list, rows), tall=true), foot(v)))
    end
    list.height = height(min(list_h(v), (window_size(e)[2] - above_page(e) - 38px) * LIST_SHARE))
    Column(width(grow=grow), height(grow=grow), Alignment.Start, background(takeoff_back()), name="Takeoff",
      toolbar(v), prompt(v)..., area, table(v, reuse!(list, rows)), foot(v))
  end
end

cursor(::TakeoffView) = :arrow

# --- what a takeoff's parts read -----------------------------------------------------------
#
# UI.jl describes a node again only when its `inputs` have changed, and otherwise
# uses its last geometry and layout. A takeoff's parts read its measures, its
# state and the page around it. So each part gives one number for all of that,
# which the takeoff works out once a frame, and the fields of its own that it
# reads. On a frame where nothing changed, nothing in the takeoff is described
# or laid out again: that was half the time a page with a takeoff took to
# describe. The lists that float over the page, of a search, of units and of a
# column's menu, have no `inputs`, so they're described on each frame while
# they're open. So is the takeoff while its text field shows, which has none.

"""
Everything that the parts of takeoff `v` read as they're described, as values.
A part that shows something that isn't here has to add it, or it won't change
when that does.
"""
shown_state(v::TakeoffView) = begin
  e = editor(v)
  (Plans.written(v.data), v.asking, v.current, v.filters, v.full, v.known, v.quoting === nothing, v.said, v.sort,
   v.tool, v.snap, v.wrong, e.width, e.zoom, window_size(e), plan_path(v), plan_size(v), plan_pages(v), Centient.available(),
   ntuple(k -> getfield(colours, k), nfields(colours)))
end

# UI.jl asks for the takeoff's inputs before those of its parts on each frame
inputs(v::TakeoffView) = (v.reads = hash(shown_state(v)); (v.reads,))
inputs(a::PlanArea) = (a.of.reads,)
# A takeoff's buttons keep their geometry while nothing the takeoff reads changes
inputs(b::BlockButton) = b.of isa TakeoffView ? (b.action, b.icon, b.words, b.tip, b.on, b.off, b.quiet, b.of.reads) : nothing
inputs(r::MeasureRow) = (r.i, r.of.reads)
inputs(c::AmountCell) = (c.i, c.of.reads)
inputs(u::UnitWord) = (u.of.i, u.of.of.reads)
inputs(c::MeasureCell) = (c.i, c.what, c.rect[3], c.of.reads)   # its width cuts its words short. Where it is doesn't matter.
inputs(h::ColumnHead) = (h.key, h.side, h.of.reads)
inputs(w::HeadWords) = (w.of.key, w.of.side, ishovered(w.of), w.of.of.reads)   # it's lit while the mouse is over its heading
# A click beside a button is the block's, and takes the keyboard from the text field
onkey(v::TakeoffView, ::KeyPress{Keys.mouse_left}) = (focus(part!(() -> PlanArea(of=v), v, :area)); handled)
onmouse(v::TakeoffView, ::MouseMove) = held(v, Keys.mouse_left) ? handled : nothing

block_names(::Type{TakeoffView}, lines) = begin
  out = Tuple{String,String}[]
  t = Plans.takeoff(lines)
  for m in t.measures
    a = isempty(strip(m.name)) ? nothing : Plans.amount(t, m)
    a === nothing && continue
    x = string(round(a, digits=4))
    push!(out, (m.name, m.kind == :count ? x : m.kind == :length ? x * "m" : x * "m^2"))
  end
  out
end

"The `takeoff` code block as HTML: a table of what's measured and what each measure comes to"
block_html(e, v::TakeoffView) = begin
  data = v.data
  isempty(data.measures) && return nothing
  rows = map(data.measures) do m
    amount = Plans.amount(data, m)
    "<tr><td>$(escape(m.name))</td><td>$(amount === nothing ? "" : escape(Plans.shown(m, amount)))</td></tr>"
  end
  about = join(filter(!isempty, [isempty(data.plan) ? "" : "Measured from " * escape(basename(data.plan)),
                                 isempty(data.customer) ? "" : "for " * escape(data.customer),
                                 isempty(data.made) ? "" : "quote " * escape(data.made)]), ", ")
  (isempty(about) ? "" : "<p>$about</p>\n") * "<table>\n" * join(rows, "\n") * "\n</table>"
end

BLOCKS[TAKEOFF] = TakeoffView
block_name(::Type{TakeoffView}) = "Takeoff"
block_icon(::Type{TakeoffView}) = "rulers"
block_insert(::Type{TakeoffView}) = ("Takeoff", ["```$TAKEOFF", "```", "", ""], (4, 0))
