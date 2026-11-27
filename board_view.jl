# The view of a `board` block: a board of the page's tasks
#
# A code block in the language `board` shows each to-do item of the page as a
# card, in columns. board.jl says how the block is written. Drag a card to
# another column to move it. The last column holds the items that are ticked:
# a card that's dropped there ticks its item in the page, and a card that's
# dragged out of it takes the tick away. Click a card twice to go to its line
# of the page. The block's lines hold the column of each card that's between
# the first column and the last.
#
# A block with a line like `in: jobs` is a board of a folder: its cards are
# the to-do items of every page of the folder `jobs` beside the page, and of
# the folders in it. `in: .` is the page's own folder. Each card has the name
# of its page under its words. A card that's dropped on the last column ticks
# its item in the item's own page, as a click on a box of a `find` block
# does: see `tick_page!`. Two clicks on a card open its page at its line. The
# schedule of the board's page plans only that page's items, so a board of a
# folder shows today on every day of the page.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe window_of handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor rect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./html" escape
@use "./sheet" parts shown
@use "./schedule" => Schedules
@use "./board" => Boards
@use "./find" => Searches
@use Colors: RGBA
@use Dates: Dates
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./sheet_view" exports...
@use "./schedule_view" exports...

export BOARD, BoardView, BoardColumn, BoardCard, DragLayer, columns!, board_folder, folder_todos, board_items,
       card_place, cards_on_day, planned, past, card_done, card_todo, drop_column, card_page, board_html

const BOARD = Boards.BOARD
push!(BLOCK_ICONS, "kanban")

"What a `board` block shows: the page's to-do items as cards in columns"
@def mutable struct BoardView <: SemanticUI
  n::Int = 0                               # its place among the page's boards
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Boards.Board = Boards.Board()
  lines::Vector{String} = String[]         # the lines that `data` was read from
  shown::Any = nothing                     # the version of the page, and the cards of each column for that page
  grab::Any = nothing                      # the card that the mouse holds: its name, where the mouse took it, and whether it has moved since
  clicked::NTuple{3,Float64} = (0.0, 0.0, 0.0)   # when and where a card was last clicked
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its columns and cards, kept between frames
end

"A column of a board"
@def mutable struct BoardColumn <: SemanticUI
  of::Any = nothing
  c::Int = 0
end
"A card of a board: one to-do item of the page"
@def mutable struct BoardCard <: SemanticUI
  of::Any = nothing
  key::String = ""
end
"The card that the mouse drags, drawn over the board"
@def mutable struct DragLayer <: SemanticUI
  of::Any = nothing
end

reread!(v::BoardView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Boards.board(lines)
  v.shown = nothing
  v
end

"The cards of each column of the board. They're worked out again when the page has changed, and when it shows another day."
columns!(v::BoardView) = begin
  e = editor(v)
  items = board_items(v)
  # The items of a folder are one list until a page of the folder changes
  key = (e.buf.version, v.lines, page_day(e), objectid(items))
  (v.shown !== nothing && v.shown[1] == key) || (v.shown = (key, board_folder(v) === nothing ? cards_on_day(e, v.data) : Boards.arrange(v.data, items)))
  v.shown[2]
end

"The folder whose pages the board shows the items of, as a path, or nothing for a board of its own page's items"
board_folder(v::BoardView) = begin
  name = Boards.folder(v.data)
  name === nothing ? nothing : abspath(joinpath(docdir(editor(v)), expanduser(name)))
end

"""
The to-do items of every page of `folder`, and then of the folders in it, in
the order of the pages' names, for a board or a calendar of a folder.
`items` has each as a to-do item that's called by its page and its text, like
`plans/kitchen: Lay the new pipe`, so two pages can each have an item with
the same words. `found` says where each is, by that name: its page, its line
and its text. They're found again when a page changes in Ladder, and when
the folder is read again. A folder that isn't there has none.
"""
folder_todos(e, folder::AbstractString) = begin
  isdir(folder) || return get!(() -> (key=nothing, items=Schedules.Todo[], found=Dict{String,Searches.Match}()), e.flows, (:no_folder_todos, folder))
  listed = folder_pages(folder)
  key = (hash([b.version for b in values(e.buffers)]), listed.read)
  kept = get(e.flows, (:folder_todos, folder), nothing)
  kept !== nothing && kept.key == key && return kept
  pages = get!(() -> Dict{String,Any}(), e.flows, :folder_todo_pages)   # the items of each page, for every board and calendar of the window
  # A list finds the items that aren't ticked, or the ones that are. These are both, in the order of their lines.
  open, done = Searches.Query(:todo, String[], "", String[]), Searches.Query(:done, String[], "", String[])
  both(path, lines, ks) = sort!([Searches.matches(open, path, lines, ks); Searches.matches(done, path, lines, ks)], by=m -> m.line)
  items, found = Schedules.Todo[], Dict{String,Searches.Match}()
  for (path, at) in listed.pages
    lines, ks, mark = page_text(e, path, at)
    had = get(pages, path, nothing)
    ms = had !== nothing && had[1] == mark ? had[2] : (pages[path] = (mark, both(path, lines, ks)))[2]
    page = splitext(relpath(path, folder))[1]
    seen = Dict{String,Int}()
    for m in ms
      n = seen[m.text] = get(seen, m.text, 0) + 1
      name = "$page: $(m.text)" * (n == 1 ? "" : " #$n")
      push!(items, Schedules.Todo(m.line, m.text, name, 0, m.kind == :done))
      found[name] = m
    end
  end
  e.flows[(:folder_todos, folder)] = (key=key, items=items, found=found)
end

"The to-do items that the board shows: those of its page, or those of every page of its folder, as `folder_todos` gives them"
board_items(v::BoardView) = (folder = board_folder(v); folder === nothing ? page_todos(editor(v)) : folder_todos(editor(v), folder).items)

"Where the item of the card called `key` is, for a board of a folder: its page, its line and its text. It's nothing for a board of its own page, and for a card that the folder has no more."
card_place(v::BoardView, key) = (folder = board_folder(v); folder === nothing ? nothing : get(folder_todos(editor(v), folder).found, key, nothing))

"""
The cards of each column on the page's day. Today, that's what the page's
items and the board's lines say. On another day, a page with a schedule shows
the plan: a task that's finished by that day is in the last column, a task
that runs on that day is in the second column of three or more, and the rest
are in the first.
"""
cards_on_day(e, board::Boards.Board) = begin
  tasks = planned_tasks(e)
  # With no schedule to plan from, a card is where its item was on the page's day, as git has it: see `todos_then`
  isempty(tasks) && return Boards.arrange(board, todos_then(e))
  n = length(board.columns)
  out = [Schedules.Todo[] for _ in 1:n]
  for t in tasks
    s = standing(e, t)
    push!(out[s == :done ? n : s == :doing && n > 2 ? 2 : 1], t.todo)
  end
  out
end

"True when the board shows the schedule's plan for another day than today. Its cards stay where they are then."
planned(v::BoardView) = board_folder(v) === nothing && !isempty(planned_tasks(editor(v)))

"True when the board shows the items as git has them for a day before today: a board of its own page with no schedule to plan from. Its cards stay where they are then, too."
past(v::BoardView) = board_folder(v) === nothing && !planned(v) && page_then(editor(v)) !== nothing

"True when the card of the item `t` shows as done"
card_done(v::BoardView, t) = planned(v) || past(v) ? t in columns!(v)[end] : t.done

"The to-do item of the page that the card called `key` is for, or nothing"
card_todo(v::BoardView, key) = (items = board_items(v); k = findfirst(t -> t.key == key, items); k === nothing ? nothing : items[k])

"True while the mouse drags a card of the board"
dragging(v::BoardView) = v.grab !== nothing && v.grab[4]

"The place of the column that the mouse is over, or nothing when the mouse isn't over the board"
drop_column(v::BoardView) = begin
  w = window_of(v)
  r = rect(v)
  (w === nothing || r === nothing) && return nothing
  x, y = w.mouse[1], w.mouse[2]
  (r.top - 40px <= y <= r.top + r.height + 40px) || return nothing
  for c in eachindex(v.data.columns)
    column = get(v.parts, (:column, c), nothing)
    cr = column === nothing ? nothing : rect(column)
    cr !== nothing && cr.left <= x < cr.left + cr.width && return c
  end
  nothing
end

describe(card::BoardCard) = begin
  v = card.of
  t = card_todo(v, card.key)
  t === nothing && return Box(height(0px))
  taken = dragging(v) && v.grab[1] == card.key
  done = card_done(v, t)
  place = card_place(v, card.key)
  # A card is marked while the mouse is on its item in another part of the page
  lit = !taken && !ishovered(card) && marked(v, card.key)
  Row(width(grow=grow), padding(10px, 8px), radius(6px), child_gap=7px, Alignment.Start, name="Card",
      background(taken ? clear : lit ? mark_colour(takeoff_back()) : takeoff_back()),
      border(1px, :solid, taken ? colours.faint : lit ? colours.accent : ishovered(card) ? colours.marker : colours.line),
    (done ? (Box(padding(0px, 2px), Icon("check", size=14px, color=taken ? colours.faint : colours.string)),) : ())...,
    Column(width(grow=grow), Alignment.Start, child_gap=3px,
      Box(width(grow=grow), Text(t.name, size=13px, family=SANS, color=taken ? colours.faint : done ? colours.dim : colours.ink, wrap=WrapMode.words)),
      # A card of a board of a folder says which page its item is in
      (place === nothing ? () : (Box(width(grow=grow), clip=true, label(card_page(v, place), 11px, color=colours.faint)),))...))
end

"The name of the page of a card's item as the card shows it: where it is in the board's folder, without the end of its file's name"
card_page(v::BoardView, place) = splitext(relpath(place.path, board_folder(v)))[1]

cursor(card::BoardCard) = planned(card.of) || past(card.of) ? :arrow : :hand
cursor(::Union{BoardView,BoardColumn,DragLayer}) = :arrow

onkey(card::BoardCard, ev::KeyPress{Keys.mouse_left}) = begin
  v, w = card.of, ev.window
  x, y = num(w.mouse[1]), num(w.mouse[2])
  at, cx, cy = v.clicked
  v.clicked = (time(), x, y)
  t = card_todo(v, card.key)
  # Two clicks in one place go to the card's line of the page, or of its own page for a board of a folder
  if time() - at < 0.35 && hypot(x - cx, y - cy) < 4 && t !== nothing
    place = card_place(v, card.key)
    return place === nothing ? show_line!(editor(v), t.line) : visit!(editor(v), place.path, place)
  end
  # A board that shows the plan for another day, or the items of a day that's past, has no card to move
  planned(v) || past(v) || (v.grab = (card.key, x, y, false))
  handled
end

describe(col::BoardColumn) = begin
  v = col.of
  cards = col.c <= length(columns!(v)) ? columns!(v)[col.c] : Schedules.Todo[]
  over = dragging(v) && drop_column(v) == col.c
  Column(width(grow=grow), Alignment.Start, radius(8px), padding(8px), child_gap=6px, name="Column",
         background(over ? RGBA(colours.accent, 0.14) : colours.block),
    Row(width(grow=grow), height(22px), padding(3px, 0px), child_gap=7px, Alignment.Center,
        Box(label(get(v.data.columns, col.c, ""), 12px, color=colours.dim, weight="Semibold")),
        Box(label(string(length(cards)), 11px, color=colours.faint)), Box(width(grow=grow))),
    [block_part!(() -> BoardCard(of=v, key=t.key), v, (:card, t.key)) for t in cards]...,
    (isempty(cards) ? (Box(width(grow=grow), height(34px)),) : ())...)
end

describe(v::BoardView) = begin
  e = editor(v)
  w = window_of(v)
  g = v.grab
  # A press that moves is a drag
  if g !== nothing && !g[4] && w !== nothing && hypot(num(w.mouse[1]) - g[2], num(w.mouse[2]) - g[3]) > 4
    v.grab = (g[1], g[2], g[3], true)
  end
  # The cards of items that the page had once are forgotten
  items = board_items(v)
  folder = board_folder(v)
  length(v.parts) > 2length(items) + 40 && filter!(p -> !(p[1] isa Tuple && p[1][1] == :card) || card_todo(v, p[1][2]) !== nothing, v.parts)
  with_theme(component_theme(e.zoom)) do
    isempty(items) && return Column(block_look()..., clip=true, name="Board",
      block_note(folder === nothing ? "This page has no to-do items yet. Start a line with - [ ] to make a card." :
                 isdir(folder) ? "No page of the folder “$(basename(folder))” has a to-do item yet." :
                 "There's no folder called “$(Boards.folder(v.data))” beside this page."))
    n = length(v.data.columns)
    wide = (e.width - 2px - 16px - 8px * (n - 1)) / n   # each column is as wide as the next
    columns = Row(width(grow=grow), padding(8px), child_gap=8px, Alignment.Start,
      [Box(fixed(wide), Alignment.Start, block_part!(() -> BoardColumn(of=v, c=c), v, (:column, c))) for c in 1:n]...)
    # On another day than today, a line over the columns says whose cards these are
    d = page_day(e)
    planned(v) && (columns = Column(width(grow=grow), Alignment.Start,
      Row(width(grow=grow), height(30px), padding(14px, 0px), child_gap=7px, Alignment.Center, clip=true,
          Icon("calendar-day", size=13px, color=colours.accent),
          Box(label("As the schedule plans it for $(Dates.dayname(d)) $(Schedules.long(d))", 12px, color=colours.dim)), Box(width(grow=grow))),
      columns))
    past(v) && (columns = Column(width(grow=grow), Alignment.Start,
      Row(width(grow=grow), height(30px), padding(14px, 0px), child_gap=7px, Alignment.Center, clip=true,
          Icon("calendar-day", size=13px, color=colours.accent),
          Box(label("As git has the page for $(Dates.dayname(d)) $(Schedules.long(d))", 12px, color=colours.dim)), Box(width(grow=grow))),
      columns))
    # A board of a folder says whose items these are
    folder === nothing || (columns = Column(width(grow=grow), Alignment.Start,
      Row(width(grow=grow), height(30px), padding(14px, 0px), child_gap=7px, Alignment.Center, clip=true,
          Icon("folder", size=13px, color=colours.dim),
          Box(label("Every page of $(basename(folder))", 12px, color=colours.dim)), Box(width(grow=grow))),
      columns))
    Stack(block_look()..., clip=true, name="Board", columns,
          (dragging(v) ? (block_part!(() -> DragLayer(of=v), v, :drag),) : ())...)
  end
end

describe(::DragLayer) = Box(width(grow=grow), height(grow=grow))

draw(ctx, size, ui::ConcreteRect, layer::DragLayer) = begin
  v = layer.of
  w = window_of(v)
  (w === nothing || !dragging(v)) && return
  t = card_todo(v, v.grab[1])
  column = get(v.parts, (:column, 1), nothing)
  cr = column === nothing ? nothing : rect(column)
  (t === nothing || cr === nothing) && return
  # The card stays under the mouse where the mouse took hold of it
  wide = num(cr.width) - 16
  x, y = num(w.mouse[1]) - wide / 2, num(w.mouse[2]) - 17
  face = Face(SANS, "", 13px, colours.ink, false)
  round_box(ctx, x + 1, y + 3, wide, 34, 6; fill=RGBA(0, 0, 0, 0.12))
  round_box(ctx, x, y, wide, 34, 6; fill=takeoff_back(), line=colours.accent, wide=1.5)
  write_ink(ctx, elide(t.name, 13px, px(wide - 20)), x + 10, y + 22, face)
end

"A drag ended. The card goes to the column that it was dropped on, and its item is ticked if that's the last one."
drop!(v::BoardView) = begin
  g = v.grab
  v.grab = nothing
  (g === nothing || !g[4]) && return v
  c = drop_column(v)
  e = editor(v)
  b = e.buf
  items = board_items(v)
  t = card_todo(v, g[1])
  (c === nothing || t === nothing || readonly(b) || Boards.column(v.data, t, items) == c) && return v
  place = card_place(v, g[1])
  # The item of another page is ticked there first. If its page can't be written, the card stays where it is.
  if place !== nothing
    last = length(v.data.columns)
    turns = c == last ? !t.done : t.done
    turns && !tick_page!(e, place, c == last) && return v
  end
  Boards.prune!(v.data, items)
  tick = Boards.move!(v.data, t, c, items)
  # The tick and the block's lines change together, so one ⌘Z takes both back
  b.typed = 0.0
  if tick !== nothing && place === nothing
    caret, anchor = b.caret, b.anchor
    col = findfirst('[', b.lines[t.line])
    edit!(b, (t.line, col), (t.line, col + 1), tick ? "x" : " ", typing=true)
    b.caret, b.anchor = caret, anchor
  end
  write_block!(v, BOARD, Boards.written(v.data), typing=true)
  b.typed = 0.0
  v.shown = nothing
  v
end

block_tick!(v::BoardView) = (v.grab !== nothing && !held(v, Keys.mouse_left) && drop!(v); v)
# A drag is the board's, so the page's text doesn't select
onmouse(v::BoardView, ::MouseMove) = v.grab === nothing ? nothing : handled

"The board as HTML: a table with a column for each of the board's columns"
board_html(e, v::BoardView) = begin
  columns = columns!(v)
  all(isempty, columns) && return nothing
  heads = join("<th>$(escape(name))</th>" for name in v.data.columns)
  cells = join("<td style=\"vertical-align: top\">" * join((escape(t.name) for t in cards), "<br>") * "</td>" for cards in columns)
  "<table>\n<tr>$heads</tr>\n<tr>$cells</tr>\n</table>"
end

BLOCKS[BOARD] = BoardView
block_name(::Type{BoardView}) = "Board"
block_icon(::Type{BoardView}) = "kanban"
block_insert(::Type{BoardView}) = ("Board", ["```$BOARD", "```", "", ""], (4, 0))
block_html(e, v::BoardView) = board_html(e, v)
