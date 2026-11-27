# The view of a `canvas` block: a board of cards, or a mind map
#
# A code block in the language `canvas` is a board of cards that you put
# anywhere, as in the app Muse. canvas.jl says how the block is written. In
# the page it shows the whole board, small, with its tools over it, and you
# change it there. Only the button beside its top right corner makes it fill
# the window, where it has more room. A click or a pinch never does. A page
# that can't change shows only the board.
#
#   - Two fingers on the trackpad move round the board, and so does a drag
#     on an empty place. A pinch, the mouse wheel, or two fingers with ⌘ held
#     make it bigger or smaller round the mouse. Fit shows the whole board.
#     In the page, the wheel and two fingers scroll the page past the board,
#     and only with ⌘ held do they make it bigger or smaller.
#   - Click twice on an empty place for a new note there, and type its words.
#     Return starts a new line in it. Esc or a click elsewhere ends the
#     typing, and a note with no words is taken away.
#   - Tab makes a new note to the right of the note that's selected or typed
#     in, joined to it by a line, as in a mind map. ⇧Return makes a new note
#     under it, joined to the same card that it's joined from.
#   - Click a card to select it, and drag it to move it. The circle on its
#     bottom right corner makes it wider or narrower. The circle beside its
#     right side draws a line from it: let go on another card to join the
#     two, or on an empty place for a new note that's joined to it. Click a
#     line to select it. Delete takes away what's selected.
#   - Click a note or a text twice to change its words where they are.
#   - The text tool writes words straight on the board, with no card round
#     them. The pen draws by hand. The dots choose the colour of the pen, and
#     of the text or the line drawn by hand that's selected.
#   - ⌘V puts in what the clipboard holds: a picture as a picture, a web
#     address as a card of the web page, a [[wiki link]] as a card of the
#     page, files from the Finder as a drop does, and other text as a note. A
#     picture or a Markdown file that's dropped from the Finder goes where
#     it's dropped. Add Picture asks for a file.
#   - A card of a page shows the page's first lines, or its own board when it
#     has one. Click it twice to open the page, with its board filling the
#     window. Back comes back here. Click a card of a web page twice to open
#     the page in the browser.
#   - Esc lets go of what's selected, then chooses the arrow. Then it gives
#     the keyboard back to the page's text, or puts a board that fills the
#     window back in the page.
#
# Each card is a line of the block, so ⌘Z takes back the last change.

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor redraw_in! rect MouseScroll Pinch onpinch with_clip with_round_clip
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring jstring with_pool
@use "github.com/jkroso/UI.jl/Interface/image" image_aspect image_source
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./pictures" picture
@use "./markdown" words
@use "./sheet" parts
@use "./spreadsheet" moved
@use "./pasteboard" => Pasteboard
@use "./linkcard" => Cards
@use "./sketch" => Sketches
@use "./canvas" => Canvases
@use Colors: RGBA
@use InteractiveUtils: clipboard
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
@use "./linkcard_view" exports...
@use "./sketch_view" exports...
@use "./file_view" exports...
@use "./schedule_view" exports...

export CANVAS, CANVAS_TOOLS, NOTE_PAD, CARD_ROUND, NOTE_LEADING, TEXT_LEADING, PAGE_HEAD, PREVIEW_SIZE,
       CANVAS_MOST, CANVAS_LEAST, CANVAS_ROOM, CANVAS_ZOOMS, CARD_KNOB, CARD_KNOB_REACH, TEXT_SIZES,
       MOST_GLANCE, CanvasView, CanvasArea, CanvasDot, same_in, canvas_area, canvas_input, canvas_back,
       card_back, canvas_face, card_wraps, card_wrap, word_room, word_size, word_lead, word_inset, card_lines,
       card_file, card_size, page_glances, plain_words, page_glance, page_card_tall, link_glance, link_title,
       link_card_tall, board_place, window_place, mouse_place, board_middle, board_extent, fit_board!,
       page_tall, zoom_board!, card_under, width_knob, join_knob, knob_under, sized_text, colour_target,
       text_sizes_bar, canvas_to_fill, resize_text!, card_shadow, card_paper, line_foot, draw_words, cut_to,
       draw_join, draw_card, draw_page_card, draw_link_card, card_lines_of, draw_inner_board, draw_board_ink,
       draw_knob, draw_canvas_marks, draw_caret, caret_line, index_near, typed_place, sync_typing!,
       start_typing!, finish_typing!, type_newline!, caret_up_down!, add_joined!, add_after!, delete_picked!,
       undo_canvas!, add_card!, text_card, page_name_for, put_on_board!, drop_place, paste_canvas!,
       choose_pictures!, open_card!, canvas_at, canvas_drop!, canvas_html

const CANVAS = Canvases.CANVAS
"The tools of a canvas: the icon of each one's button, and what the button's tooltip says"
const CANVAS_TOOLS = ((:select, "cursor", "Select a card and drag it. Click twice to write a note."),
                      (:text, "type", "Write words on the board: click where they go"),
                      (:pen, "pencil", "Draw by hand"))
push!(BLOCK_ICONS, "sticky", "cursor", "type", "pencil", "image", "fullscreen", "fullscreen-exit", "trash", "dash", "plus")
const NOTE_PAD = 12.0            # the room round the words of a note, in the board's own measure
const CARD_ROUND = 6.0           # how round the corners of a card are
const NOTE_LEADING = 1.4         # how far apart the lines of a note are, for each of the size of its words
const TEXT_LEADING = 1.25        # and the lines of a text
const PAGE_HEAD = 34.0           # how tall the top of a card of a page is, where its name is
const PREVIEW_SIZE = 12.5        # how big the first lines of a page are on its card
const CANVAS_MOST = 420.0        # px: the most that a canvas in the page is tall
const CANVAS_LEAST = 160.0       # px: and the least
const CANVAS_ROOM = 32.0         # px: the room round the cards of a board that shows whole
const CANVAS_ZOOMS = (0.1, 4.0)  # the least and the most px of the window for each of the board's own measure
const CARD_KNOB = 5.0            # px: the radius of a circle that a drag changes a card with
const CARD_KNOB_REACH = 9.0      # px: how near the mouse is to a circle to drag it
"The sizes that the buttons for the size of a text's words go through"
const TEXT_SIZES = (10.0, 12.0, 14.0, 16.0, 20.0, 24.0, 28.0, 36.0, 48.0, 64.0, 80.0, 96.0, 128.0, 160.0, 200.0)
const MOST_GLANCE = 2_000_000    # bytes: a page that's bigger shows no lines on its card

"What a `canvas` block shows: a board of cards, and the tools that change it"
@def mutable struct CanvasView <: SemanticUI
  n::Int = 0                               # its place among the page's canvases
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Canvases.Canvas = Canvases.Canvas()
  lines::Vector{String} = String[]         # the lines that `data` was read from
  tool::Symbol = :select
  colour::Symbol = :ink                    # the colour of the pen and of the next text
  size::Float64 = Canvases.TEXT_SIZE       # how big the words of the next text are
  picked::Any = nothing                    # the card, the line between cards or the line drawn by hand that's selected, or nothing
  # A drag: what it does (:move, :width, :join, :draw or :pan), where the mouse was last in the window, and whether it moved
  grab::Any = nothing
  draft::Any = nothing                     # the line that's being drawn by hand, or nothing
  reach::Any = nothing                     # the end of the line that's being drawn from a card, a place on the board, or nothing
  typing::Any = nothing                    # the note or the text whose words are being typed, or nothing
  fresh::Bool = false                      # it's new, so it goes when nothing is typed
  was::String = ""                         # its words before the typing
  clicked::NTuple{3,Float64} = (0.0, 0.0, 0.0)   # when and where the board was last clicked
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the board was last drawn in the window
  at::NTuple{2,Float64} = (0.0, 0.0)       # the place on the board at the top left corner of `box`
  zoom::Float64 = 0.0                      # px of the window for each of the board's own measure. 0 shows the whole board next.
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its buttons and its text field, kept between frames
  full::Bool = false                       # it fills the window, over the page
  tall::px = 0px                           # how tall it was in the page when it was last laid out there
  pinned::px = 0px                         # how far the page was scrolled when it filled the window
end

"The part of a canvas that the board is drawn in"
@def mutable struct CanvasArea <: SemanticUI
  of::Any = nothing
end
"A dot at the top of a canvas that chooses a colour"
@def mutable struct CanvasDot <: SemanticUI
  of::Any = nothing
  colour::Symbol = :ink
end

"What `x`, a card, a line between cards or a line drawn by hand of the canvas `old`, is in `new`: the one in its place there, or nothing"
same_in(old::Canvases.Canvas, new::Canvases.Canvas, x) = begin
  x === nothing && return nothing
  for (a, b) in ((old.cards, new.cards), (old.joins, new.joins), (old.strokes, new.strokes))
    i = findfirst(y -> y === x, a)
    i === nothing || return i <= length(b) ? b[i] : nothing
  end
  nothing
end

reread!(v::CanvasView, lines) = begin
  lines == v.lines && return v
  old = v.data
  v.lines = lines
  v.data = Canvases.canvas(lines)
  # What was selected is found again by its place, as after ⌘Z
  v.picked = same_in(old, v.data, v.picked)
  v.typing = same_in(old, v.data, v.typing)
  v
end

"Write the board into its block. Its lines are the ones that it holds now, so it isn't read again."
commit!(v::CanvasView) = (new = Canvases.written(v.data); v.lines = new; write_block!(v, CANVAS, new))

canvas_area(v::CanvasView) = block_part!(() -> CanvasArea(of=v), v, :area)
keyboard_part(v::CanvasView) = canvas_area(v)

"""
The text field that holds the words that are being typed into a note or a
text. It has the keyboard while they're typed, and it isn't shown: the board
shows its words in the card.
"""
canvas_input(v::CanvasView) = block_part!(v, :input) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"The colour of the board behind its cards"
canvas_back() = dark_page() ? colours.bg : colours.block
"The colour of a card"
card_back() = colours.float

# --- the size of a card ---------------------------------------------------------------------

"The face of words `size` big"
canvas_face(size, colour=colours.ink, style="") = Face(SANS, style, px(size), colour, false)

# The lines that each text took, kept, as each card's words are laid out on each frame
const card_wraps = Dict{Tuple{String,Float64,Float64,String},Vector{UnitRange{Int}}}()

"""
The lines that `text` takes when it has `room` across and its words are
`size` big: for each, the characters that it holds, counted from 1. A line
ends where the text has a new line, and where the next word wouldn't fit. A
word that's wider than the room is cut where it reaches the edge. With no
room, a line ends only where the text has a new line. The spaces after the
last word of a line are in that line.
"""
card_wrap(text::AbstractString, room, size, style="") = begin
  length(card_wraps) > 20_000 && empty!(card_wraps)
  get!(card_wraps, (String(text), Float64(room), Float64(size), style)) do
    cs = collect(text)
    face = canvas_face(size, colours.ink, style)
    wide(r) = num(measure(face, String(cs[r])))
    lines = UnitRange{Int}[]
    a = 1
    for b in [findall(==('\n'), cs); length(cs) + 1]   # each line of the text ends before a new line, or at the end
      start = a
      if room > 0
        k, space = start, 0   # the character that's looked at, and the last space of the line so far
        while k <= b - 1
          cs[k] == ' ' && (space = k)
          if cs[k] != ' ' && k > start && wide(start:k) > room
            stop = space >= start ? space : k - 1
            push!(lines, start:stop)
            start, k, space = stop + 1, stop + 1, 0
            continue
          end
          k += 1
        end
      end
      push!(lines, start:b-1)
      a = b + 1
    end
    lines
  end
end

"How wide the words of a note or a text can be, in the board's measure. A text with no width has no edge."
word_room(card) = card.kind == :note ? card.width - 2NOTE_PAD : card.width
"How big the words of a note or a text are"
word_size(card) = card.kind == :note ? Canvases.NOTE_SIZE : card.size
"How far apart the lines of a note or a text are"
word_lead(card) = word_size(card) * (card.kind == :note ? NOTE_LEADING : TEXT_LEADING)
"Where the words of a note or a text start, from its top left corner"
word_inset(card) = card.kind == :note ? (NOTE_PAD, NOTE_PAD) : (0.0, 0.0)

"The lines of the words of a note or a text, as the board shows them"
card_lines(card, text=card.content) = (cs = collect(text); [String(rstrip(String(cs[r]))) for r in card_wrap(text, word_room(card), word_size(card))])

"The file of a picture card: its path from `dir`, the folder of its page, or a whole path"
card_file(card, dir) = (p = expanduser(card.content); isabspath(p) ? p : normpath(joinpath(dir, p)))

"""
How big a card is, in the board's own measure: its width and its height. `dir`
is the folder of the page whose board it's on, where the path of a picture
starts.
"""
card_size(e, card::Canvases.Card, dir=docdir(e)) = begin
  k = card.kind
  if k == :note
    (card.width, 2NOTE_PAD + length(card_lines(card)) * word_lead(card))
  elseif k == :text
    lines = card_lines(card)
    face = canvas_face(card.size)
    (card.width > 0 ? card.width : max(card.size, maximum(l -> num(measure(face, l)), lines, init=0.0)), length(lines) * word_lead(card))
  elseif k == :picture
    key = picture_key(card_file(card, dir))
    (card.width, round(card.width / (key === nothing ? 1.5 : image_aspect(key))))
  elseif k == :page
    (card.width, page_card_tall(e, card))
  else
    (card.width, link_card_tall(e, card))
  end
end
card_size(v::CanvasView, card::Canvases.Card) = card_size(editor(v), card)

# What a card of a page shows, kept under the page's path with when the file last changed
const page_glances = Dict{String,Any}()

"The words of a line of Markdown without its marks: no list mark, no * or _ or `, and a link as its words"
plain_words(s::AbstractString) = begin
  s = replace(s, r"^(?:[-*+]\s+(?:\[[ xX]\]\s+)?|\d+[.)]\s+|>\s*)+" => "")
  s = replace(s, r"!?\[([^\]]*)\]\([^)]*\)" => s"\1")
  s = replace(s, r"\[\[([^\]|]*)(?:\|[^\]]*)?\]\]" => s"\1")
  String(strip(replace(s, r"[*_`]+" => "")))
end

"""
What a card of the page called `name` shows: the page's `path`, its `title`,
its first `lines` of words, its own `board`, which is the first canvas in it,
or nothing, and whether it's `there`. It's kept until the file changes.
"""
page_glance(e, name) = begin
  path = wiki_path(e, name)
  t = isfile(path) ? mtime(path) : -1.0
  kept = get(page_glances, path, nothing)
  kept !== nothing && kept[1] == t && return kept[2]
  text = t < 0 || filesize(path) > MOST_GLANCE ? "" : try read(path, String) catch; "" end
  title, titled, lines, board = splitext(basename(name))[1], false, String[], nothing
  fence, block, top = "", String[], false   # the code block that a line is in, its lines, and whether it's in the front matter
  for (i, line) in enumerate(split(text, '\n'))
    s = strip(line)
    i == 1 && s == "---" && (top = true; continue)
    top && (s == "---" && (top = false); continue)
    if startswith(s, "```") || startswith(s, "~~~")
      if fence == ""
        fence = "~" * lowercase(strip(s[4:end]))   # never "", even for a block with no language
      else
        fence == "~" * CANVAS && board === nothing && (board = Canvases.canvas(block))
        fence = ""
        empty!(block)
      end
      continue
    end
    fence == "" || (push!(block, line); continue)
    isempty(s) && continue
    startswith(s, "# ") && !titled && ((title, titled) = (String(strip(s[3:end])), true); continue)
    startswith(s, "#") && continue
    length(lines) < 3 && push!(lines, plain_words(s))
  end
  g = (path=path, title=title, lines=lines, board=board, there=t >= 0)
  page_glances[path] = (t, g)
  g
end

"How tall a card of a page is: its top, and its board or its first lines under that"
page_card_tall(e, card) = begin
  g = page_glance(e, card.content)
  g.board === nothing || return PAGE_HEAD + round(card.width * 0.6)
  PAGE_HEAD + max(1, length(g.lines)) * PREVIEW_SIZE * NOTE_LEADING + 10
end

"What's known of the web page at `url`: its title, its picture and the name of its site. It asks for the next frame while that's on its way."
link_glance(e, url) = (got = Cards.lookup!(url, cards_dir(), ask=online(e)); got[2] && redraw_in!(e, 0.2); got[1])

"The words at the top of a card of a web page: its title, or the name of its computer"
link_title(c, card) = isempty(c.title) ? Cards.site_name(card.content) : c.title

"How tall a card of a web page is: its picture, two lines of its title at most, and its site"
link_card_tall(e, card) = begin
  c = link_glance(e, card.content)
  n = min(2, length(card_wrap(link_title(c, card), card.width - 2NOTE_PAD, Canvases.NOTE_SIZE, "Semibold")))
  (isempty(c.image) ? 0.0 : round(card.width / 1.91)) + 2NOTE_PAD + n * Canvases.NOTE_SIZE * NOTE_LEADING + 16
end

# --- where things are -----------------------------------------------------------------------

"The place on the board at the place `(x, y)` in the window"
board_place(v::CanvasView, x, y) = (v.at[1] + (x - v.box[1]) / v.zoom, v.at[2] + (y - v.box[2]) / v.zoom)
"The place in the window of the place `p` on the board"
window_place(v::CanvasView, p) = (v.box[1] + (p[1] - v.at[1]) * v.zoom, v.box[2] + (p[2] - v.at[2]) * v.zoom)
"The place on the board under the mouse"
mouse_place(v::CanvasView, w) = board_place(v, num(w.mouse[1]), num(w.mouse[2]))
"The place on the board in the middle of what shows of it"
board_middle(v::CanvasView) = board_place(v, v.box[1] + v.box[3] / 2, v.box[2] + v.box[4] / 2)

"What the board holds: its left, top, right and bottom. An empty board is a small one."
board_extent(v::CanvasView) = something(Canvases.extent(v.data, c -> card_size(v, c)), (0.0, 0.0, 480.0, 200.0))

"Show the whole board in a box `w` by `h` px: no bigger than its own size, and in the middle"
fit_board!(v::CanvasView, w, h) = begin
  l, t, r, b = board_extent(v)
  m = CANVAS_ROOM
  v.zoom = clamp(min((w - 2m) / max(r - l, 1.0), (h - 2m) / max(b - t, 1.0), 1.0), CANVAS_ZOOMS[1], 1.0)
  v.at = ((l + r) / 2 - w / 2 / v.zoom, (t + b) / 2 - h / 2 / v.zoom)
  v
end

"How tall the board is in the page, in px: as tall as its cards need at the width of the page, between the least and the most"
page_tall(v::CanvasView) = begin
  l, t, r, b = board_extent(v)
  w = num(editor(v).width) - 2
  z = min(1.0, (w - 2CANVAS_ROOM) / max(r - l, 1.0))
  clamp((b - t) * z + 2CANVAS_ROOM, CANVAS_LEAST, CANVAS_MOST)
end

"Make the board `by` times as big. The place on the board at `(x, y)` in the window stays there."
zoom_board!(v::CanvasView, by, x, y) = begin
  v.zoom > 0 || return handled
  p = board_place(v, x, y)
  v.zoom = clamp(v.zoom * by, CANVAS_ZOOMS...)
  v.at = (p[1] - (x - v.box[1]) / v.zoom, p[2] - (y - v.box[2]) / v.zoom)
  handled
end

"Move the board, if it must, so that all of `card` shows"
show_place!(v::CanvasView, card) = begin
  v.zoom > 0 || return v
  x, y = window_place(v, card.at)
  w, h = card_size(v, card) .* v.zoom
  l, t, bw, bh = v.box
  m = 40.0
  shift(lo, hi, from, to) = lo < from + m ? lo - from - m : hi > to - m ? min(hi - to + m, lo - from - m) : 0.0
  dx, dy = shift(x, x + w, l, l + bw), shift(y, y + h, t, t + bh)
  v.at = (v.at[1] + dx / v.zoom, v.at[2] + dy / v.zoom)
  v
end

"The card at the place `p` on the board, or nothing. `reach` is in px of the window."
card_under(v::CanvasView, p; reach=0.0) = v.zoom > 0 ? Canvases.card_at(v.data, p, c -> card_size(v, c); reach=reach / v.zoom) : nothing

"Where the circle that makes a card wider is in the window: on its bottom right corner"
width_knob(v::CanvasView, card) = (wh = card_size(v, card); window_place(v, card.at .+ wh))
"Where the circle that draws a line from a card is in the window: a little right of the middle of its right side"
join_knob(v::CanvasView, card) = (wh = card_size(v, card); q = window_place(v, (card.at[1] + wh[1], card.at[2] + wh[2] / 2)); (q[1] + 12, q[2]))

"""
The circle under the place `(x, y)` in the window: what a drag of it does,
`:width` or `:join`, and its card. The card that's selected has both, and
the card that the mouse is near has the circle that joins. Nothing when no
circle is there.
"""
knob_under(v::CanvasView, x, y) = begin
  (v.zoom > 0 && v.tool == :select) || return nothing
  near(q) = hypot(q[1] - x, q[2] - y) <= CARD_KNOB_REACH
  p = v.picked
  if p isa Canvases.Card && p !== v.typing
    near(width_knob(v, p)) && return (:width, p)
    near(join_knob(v, p)) && return (:join, p)
  end
  card = card_under(v, board_place(v, x, y), reach=2CARD_KNOB_REACH + 12)
  card !== nothing && card !== v.typing && near(join_knob(v, card)) ? (:join, card) : nothing
end

# --- in the page and in the window ----------------------------------------------------------

"The text whose size the buttons at the top change: the one that's typed in or selected, or nothing"
sized_text(v::CanvasView) = begin
  for p in (v.typing, v.picked)
    p isa Canvases.Card && p.kind == :text && return p
  end
  nothing
end

"What a colour that's chosen goes to: the text that's typed in or selected, or the line drawn by hand that's selected, or nothing"
colour_target(v::CanvasView) = begin
  t = sized_text(v)
  t !== nothing ? t : v.picked isa Sketches.Shape ? v.picked : nothing
end

"The buttons that make the words of a text smaller or bigger, while the text tool is chosen or a text is selected"
text_sizes_bar(v::CanvasView) = begin
  card = sized_text(v)
  (v.tool == :text || card !== nothing) || return ()
  n = card === nothing ? v.size : card.size
  (rule(),
   block_button!(v, :smaller, (:size, false), icon="dash", tip="Make the words smaller", off=n <= TEXT_SIZES[1]),
   Box(fixed(30px), height(26px), Alignment.Center, justify=Alignment.Center, label(Sketches.figure(n), 12px, color=colours.dim)),
   block_button!(v, :bigger, (:size, true), icon="plus", tip="Make the words bigger", off=n >= TEXT_SIZES[end]))
end

"The page that a card of a page opened, whose first canvas fills the window when it's laid out"
const canvas_to_fill = Ref("")

describe(v::CanvasView) = begin
  e = editor(v)
  canvas_to_fill[] == e.buf.path && redraw_in!(v, 0.02)   # its first canvas fills the window on the next frame
  with_theme(component_theme(e.zoom)) do
    # In the page, a page that can't change shows only the whole board, small
    v.full || !readonly(e.buf) ||
      return Box(width(grow=grow), Alignment.Start, fillable(v, (:block, v), Column(block_look()..., clip=true, name="Canvas", canvas_area(v)), wide=:grow))
    tools = [block_button!(v, tool, (:tool, tool), icon=icon, tip=tip, on=v.tool == tool) for (tool, icon, tip) in CANVAS_TOOLS]
    dots = [block_part!(() -> CanvasDot(of=v, colour=c), v, (:ink, c)) for c in Canvases.COLOURS]
    picked = v.picked === nothing ? () : (block_button!(v, :delete, :delete, icon="trash", tip="Take away what's selected  Delete"),)
    # The last button puts a board that fills the window back in the page. In the page, the button beside its top
    # right corner makes it fill the window.
    full = v.full ? (block_button!(v, :full, :full, icon="fullscreen-exit", tip="Back to the page  esc"),) : ()
    bar = block_bar(tools..., rule(), dots..., text_sizes_bar(v)..., rule(),
                    block_button!(v, :picture, :picture, icon="image", words="Add Picture…", tip="Put a picture from a file on the board"),
                    block_button!(v, :fit, :fit, icon="fullscreen", words="Fit", tip="Show the whole board"),
                    Box(width(grow=grow)), picked..., full...)
    # In the page its tools are over the board, so that you change it where it is
    v.full || return Box(width(grow=grow), Alignment.Start, fillable(v, (:block, v), Column(block_look()..., clip=true, name="Canvas", bar, canvas_area(v)), wide=:grow))
    Column(width(grow=grow), height(grow=grow), Alignment.Start, background(canvas_back()), name="Canvas", bar, canvas_area(v))
  end
end

# In the page it's as tall as the board needs. In the window it takes all the room under its buttons.
describe(a::CanvasArea) = (v = a.of; Box(width(grow=grow), v.full ? height(grow=grow) : height(px(page_tall(v)))))

"In the page a canvas shows the whole board, so words that were being typed are kept and nothing stays selected."
before_fill!(v::CanvasView, on::Bool) = begin
  on || (finish_typing!(v); v.picked = v.grab = v.draft = v.reach = nothing)
  v.zoom = 0.0   # it's another size now, so it shows the whole board
  v.box = (0.0, 0.0, 0.0, 0.0)
end

# A pinch on a canvas in the page makes its board bigger or smaller there: see `onpinch(::CanvasArea, ...)`. It doesn't make
# it fill the window. Only the button beside its top right corner does.
onpinch(::CanvasView, ::Pinch) = nothing

act!(v::CanvasView, action, w) = begin
  # A button for the size of the words changes the words that are being typed, and they stay open. Any other button keeps them.
  (action isa Tuple && action[1] == :size) || finish_typing!(v)
  if action == :delete
    delete_picked!(v)
  elseif action == :full
    return full!(v, !v.full)
  elseif action == :fit
    v.zoom = 0.0
  elseif action == :picture
    return choose_pictures!(v, w)
  elseif action[1] == :tool
    v.tool = action[2]
    v.tool == :select || (v.picked = nothing)
  elseif action[1] == :size
    resize_text!(v, action[2])
  end
  focus(v.typing === nothing ? canvas_area(v) : canvas_input(v))
  handled
end

"Make the words of the text that's typed in or selected, and of the next text, the next size up or down"
resize_text!(v::CanvasView, up) = begin
  card = sized_text(v)
  n = card === nothing ? v.size : card.size
  i = up ? findfirst(s -> s > n + 0.01, TEXT_SIZES) : findlast(s -> s < n - 0.01, TEXT_SIZES)
  i === nothing && return v
  v.size = TEXT_SIZES[i]
  card === nothing && return v
  card.size = v.size
  card === v.typing || commit!(v)   # words that are being typed are written when the typing ends
  v
end

describe(::CanvasDot) = Box(fixed(22px), height(26px), name="Colour")

# The dot and the ring round it are drawn about the middle of the dot's box, as a sketch draws them
draw(ctx, size, ui::ConcreteRect, d::CanvasDot) = begin
  v = d.of
  t = colour_target(v)
  on = (t === nothing ? v.colour : t.colour) == d.colour
  x, y = Float32(num(ui.left + ui.width / 2)), Float32(num(ui.top + ui.height / 2))
  disc(colour, r, wide=0.0) = (paint = ink(colour, wide); Skia.sk_canvas_draw_circle(ctx, x, y, Float32(r), paint); Skia.sk_paint_delete(paint))
  disc(sketch_colour(d.colour), 5)
  (on || ishovered(d)) && disc(on ? colours.accent : colours.marker, 7.25, 1.5)
end

cursor(::CanvasDot) = :hand

# A click on a colour gives it to the pen, to the next text, and to the text or the line drawn by hand that's selected
onkey(d::CanvasDot, ::KeyPress{Keys.mouse_left}) = begin
  v = d.of
  v.colour = d.colour
  t = colour_target(v)
  t === nothing || (t.colour = d.colour; t === v.typing || commit!(v))
  focus(v.typing === nothing ? canvas_area(v) : canvas_input(v))   # words that are being typed keep the keyboard
  handled
end

# --- drawing ----------------------------------------------------------------------------------

"Draw the soft shadow under a card at `(x, y)` in the window that's `w` by `h`, with corners `r` round. `z` is how big the board shows."
card_shadow(ctx, x, y, w, h, r, z) = begin
  paint = ink(RGBA(0, 0, 0, dark_page() ? 0.4 : 0.11))
  blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, Float32(1 + 3min(z, 1.0)), true)
  Skia.sk_paint_set_maskfilter(paint, blur)
  shape = Skia.sk_path_new()
  rect = Ref(Skia.sk_rect_t(Float32(x), Float32(y + 1.5min(z, 1.0)), Float32(x + w), Float32(y + h + 1.5min(z, 1.0))))
  Skia.sk_path_add_rounded_rect(shape, rect, Float32(r), Float32(r), Skia.SK_PATH_DIRECTION_CW)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_path_delete(shape)
  Skia.sk_maskfilter_unref(blur)
  Skia.sk_paint_delete(paint)
end

"Draw a card's paper: its shadow, its colour and a thin line round it"
card_paper(ctx, x, y, w, h, z) = begin
  r = CARD_ROUND * z
  card_shadow(ctx, x, y, w, h, r, z)
  round_box(ctx, x, y, w, h, r, fill=card_back(), line=colours.line, wide=0.75)
end

"How far down from the top of its line the words of a line stand, when they're `size` big and the lines are `lead` apart"
line_foot(size, lead) = (lead - size) / 2 + 0.84size

"""
Draw `lines` of words from `(x, y)` in the window, `size` px big and `lead` px
apart. Words too small to read are a faint bar each, as long as the words.
`room` is how big the words are in the board's own measure, for that.
"""
draw_words(ctx, lines, x, y, size, lead, colour; style="", room=size) = begin
  if size < 3.5
    face = canvas_face(room, colour, style)
    k = size / room
    for (i, line) in enumerate(lines)
      isempty(line) && continue
      round_box(ctx, x, y + (i - 1) * lead + 0.3lead, num(measure(face, line)) * k, 0.4lead, 0.2lead, fill=RGBA(colour, 0.25))
    end
    return
  end
  face = canvas_face(size, colour, style)
  for (i, line) in enumerate(lines)
    isempty(line) || write_ink(ctx, line, x, y + (i - 1) * lead + line_foot(size, lead), face)
  end
end

"`text`, cut short with … to be no wider than `room` in `face`"
cut_to(face, text, room) = begin
  num(measure(face, text)) <= room && return String(text)
  cs = collect(text)
  lo, hi = 0, length(cs)
  while lo < hi   # the most characters that fit before the …
    mid = (lo + hi + 1) ÷ 2
    num(measure(face, String(cs[1:mid]) * "…")) <= room ? (lo = mid) : (hi = mid - 1)
  end
  String(cs[1:lo]) * "…"
end

"Draw the line between two cards through the four places of a curve, which are in the window"
draw_join(ctx, (a, b, c, d), colour, wide) = begin
  paint = ink(colour, wide)
  path = Skia.sk_path_new()
  Skia.sk_path_move_to(path, Float32(a[1]), Float32(a[2]))
  Skia.sk_path_cubic_to(path, Float32(b[1]), Float32(b[2]), Float32(c[1]), Float32(c[2]), Float32(d[1]), Float32(d[2]))
  Skia.sk_canvas_draw_path(ctx, path, paint)
  Skia.sk_path_delete(path)
  Skia.sk_paint_delete(paint)
end

"""
Draw a card of a board whose place 0,0 is at `(x0, y0)` in the window, `z`
px for each of the board's measure. `dir` is the folder of the board's page.
`depth` is how many boards it's inside: a card of a page shows its own board
only on the board that fills the window or shows in the page.
"""
draw_card(ctx, e, card, x0, y0, z, dir; depth=0) = begin
  w, h = card_size(e, card, dir)
  x, y, W, H = x0 + card.at[1] * z, y0 + card.at[2] * z, w * z, h * z
  k = card.kind
  if k == :text
    draw_words(ctx, card_lines(card), x, y, card.size * z, word_lead(card) * z, sketch_colour(card.colour), room=card.size)
  elseif k == :note
    card_paper(ctx, x, y, W, H, z)
    draw_words(ctx, card_lines(card), x + NOTE_PAD * z, y + NOTE_PAD * z, Canvases.NOTE_SIZE * z, word_lead(card) * z, colours.ink, room=Canvases.NOTE_SIZE)
  elseif k == :picture
    key = picture_key(card_file(card, dir))
    if key === nothing
      card_paper(ctx, x, y, W, H, z)
      face = canvas_face(PREVIEW_SIZE)
      words = ["No picture at", cut_to(face, card.content, w - 2NOTE_PAD)]
      draw_words(ctx, words, x + NOTE_PAD * z, y + NOTE_PAD * z, PREVIEW_SIZE * z, PREVIEW_SIZE * NOTE_LEADING * z, colours.dim, room=PREVIEW_SIZE)
    else
      card_shadow(ctx, x, y, W, H, 3z, z)
      image = image_source(key)
      with_round_clip(() -> paint_picture(ctx, image.raw, (0, 0, image.width, image.height), (x, y, W, H)), ctx, px(x), px(y), px(W), px(H), px(3z))
    end
  elseif k == :page
    draw_page_card(ctx, e, card, w, x, y, z, H, depth)
  else
    draw_link_card(ctx, e, card, w, x, y, z, H)
  end
end

"Draw a card of a page, `w` wide in the board's measure, at `(x, y)` in the window, and `H` px tall"
draw_page_card(ctx, e, card, w, x, y, z, H, depth) = begin
  g = page_glance(e, card.content)
  W = w * z
  card_paper(ctx, x, y, W, H, z)
  pad = NOTE_PAD * z
  # A small sheet of paper before its title
  round_box(ctx, x + pad, y + (PAGE_HEAD - 13) / 2 * z, 10z, 13z, 1.5z, line=colours.dim, wide=max(0.5, 1.2z))
  size = 13.5
  title = cut_to(canvas_face(size, colours.ink, "Semibold"), g.title, w - 2NOTE_PAD - 16)
  draw_words(ctx, [title], x + pad + 16z, y + (PAGE_HEAD - size * 1.3) / 2 * z, size * z, size * 1.3z, g.there ? colours.ink : colours.dim, style="Semibold", room=size)
  top = y + PAGE_HEAD * z
  if g.board !== nothing
    inner = (x + 6z, top, W - 12z, H - PAGE_HEAD * z - 6z)
    round_box(ctx, inner..., 4z, fill=canvas_back())
    depth == 0 && with_round_clip(() -> draw_inner_board(ctx, e, g.board, dirname(g.path), inner), ctx, px.(inner)..., px(4z))
  else
    trace(ctx, [(x, top), (x + W, top)], colours.line, max(0.5, 0.75z))
    face = canvas_face(PREVIEW_SIZE)
    lines = !g.there ? ["No page yet. Click twice to make it."] : isempty(g.lines) ? ["No words yet"] : g.lines
    draw_words(ctx, [cut_to(face, l, w - 2NOTE_PAD) for l in lines], x + pad, top + 5z, PREVIEW_SIZE * z, PREVIEW_SIZE * NOTE_LEADING * z, colours.dim, room=PREVIEW_SIZE)
  end
end

"Draw a card of a web page: its picture at the top, its title and its site under that"
draw_link_card(ctx, e, card, w, x, y, z, H) = begin
  c = link_glance(e, card.content)
  W = w * z
  card_paper(ctx, x, y, W, H, z)
  top = y
  key = isempty(c.image) ? "" : card_picture(e, c.image)
  if !isempty(c.image)
    tall = round(w / 1.91) * z
    if !isempty(key)
      image = image_source(key)
      # The picture covers its room, and what doesn't fit is cut off
      s = max(W / image.width, tall / image.height)
      from = ((image.width - W / s) / 2, (image.height - tall / s) / 2, W / s, tall / s)
      with_round_clip(() -> paint_picture(ctx, image.raw, from, (x, y, W, tall)), ctx, px(x), px(y), px(W), px(tall + CARD_ROUND * z), px(CARD_ROUND * z))
    end
    top += tall
  end
  pad = NOTE_PAD * z
  size = Canvases.NOTE_SIZE
  rows = card_lines_of(link_title(c, card), w - 2NOTE_PAD, size, "Semibold")
  length(rows) > 2 && (rows = [rows[1], cut_to(canvas_face(size, colours.ink, "Semibold"), rows[2] * " " * join(rows[3:end], " "), w - 2NOTE_PAD)])
  draw_words(ctx, rows, x + pad, top + pad, size * z, size * NOTE_LEADING * z, colours.ink, style="Semibold", room=size)
  # A page with no title shows the name of its computer at the top, and its whole address under that
  site = isempty(c.title) ? replace(card.content, r"^https?://(www\.)?"i => "") : isempty(c.site) ? Cards.site_name(card.content) : c.site
  draw_words(ctx, [cut_to(canvas_face(12.0), site, w - 2NOTE_PAD)], x + pad, top + pad + length(rows) * size * NOTE_LEADING * z + 2z, 12z, 14z, colours.dim, room=12.0)
end

"The lines that `text` takes `room` across, with words `size` big in the style `style`"
card_lines_of(text, room, size, style="") = (cs = collect(text); [String(rstrip(String(cs[r]))) for r in card_wrap(text, room, size, style)])

"Draw the board of another page small, to fit `(x, y, w, h)` in the window"
draw_inner_board(ctx, e, board, dir, (x, y, w, h)) = begin
  size(c) = card_size(e, c, dir)
  ext = Canvases.extent(board, size)
  ext === nothing && return
  l, t, r, b = ext
  m = 8.0
  z = min((w - 2m) / max(r - l, 1.0), (h - 2m) / max(b - t, 1.0), 1.0)
  draw_board_ink(ctx, e, board, dir, x + w / 2 - (l + r) / 2 * z, y + h / 2 - (t + b) / 2 * z, z, depth=1)
end

"""
Draw what a board holds: the lines between cards under the cards, then the
cards, then the lines drawn by hand over them. The board's place 0,0 is at
`(x0, y0)` in the window, and `z` px are one of its measure. What's `picked`
is in the colour of a selection.
"""
draw_board_ink(ctx, e, data, dir, x0, y0, z; depth=0, picked=nothing) = begin
  size(c) = card_size(e, c, dir)
  at(p) = (x0 + p[1] * z, y0 + p[2] * z)
  wide = clamp(1.4z, 0.6, 2.2)
  for j in data.joins
    curve = Canvases.join_curve(Canvases.edges(j[1], size(j[1])), Canvases.edges(j[2], size(j[2])))
    draw_join(ctx, at.(curve), j === picked ? colours.accent : colours.dim, j === picked ? wide + 1 : wide)
  end
  foreach(card -> draw_card(ctx, e, card, x0, y0, z, dir; depth), data.cards)
  for s in data.strokes
    s === picked && draw_shape(ctx, s, x0, y0, z, glow=true)
    draw_shape(ctx, s, x0, y0, z)
  end
end

"Draw a circle that a drag changes a card with, at `(x, y)` in the window. The one under the mouse is filled."
draw_knob(ctx, (x, y), hot) = for paint in (ink(hot ? colours.accent : card_back()), ink(colours.accent, 1.5))
  Skia.sk_canvas_draw_circle(ctx, Float32(x), Float32(y), Float32(CARD_KNOB), paint)
  Skia.sk_paint_delete(paint)
end

"""
Draw what shows only while the board fills the window: the line round the
card that's selected, its circles, the circle that joins the card that the
mouse is near, the line that's being drawn from a card, and the words that are
being typed with their caret.
"""
draw_canvas_marks(ctx, v::CanvasView) = begin
  w = window_of(v)
  mx, my = w === nothing ? (-1e9, -1e9) : (num(w.mouse[1]), num(w.mouse[2]))
  hot = v.grab === nothing ? knob_under(v, mx, my) : v.grab[1] in (:width, :join) ? (v.grab[1], v.picked) : nothing
  p = v.picked
  if p isa Canvases.Card
    x, y = window_place(v, p.at)
    W, H = card_size(v, p) .* v.zoom
    round_box(ctx, x - 2, y - 2, W + 4, H + 4, CARD_ROUND * v.zoom + 2, line=colours.accent, wide=2.0)
    if p !== v.typing && v.tool == :select
      draw_knob(ctx, width_knob(v, p), hot == (:width, p))
      draw_knob(ctx, join_knob(v, p), hot == (:join, p))
    end
  end
  # The card that the mouse is near shows the circle that draws a line from it
  hot !== nothing && hot[2] !== p && draw_knob(ctx, join_knob(v, hot[2]), true)
  if v.reach !== nothing && p isa Canvases.Card
    target = card_under(v, v.reach)
    to = target === nothing || target === p ? (v.reach..., v.reach...) : Canvases.edges(target, card_size(v, target))
    draw_join(ctx, map(q -> window_place(v, q), Canvases.join_curve(Canvases.edges(p, card_size(v, p)), to)), colours.accent, 2.0)
    if target !== nothing && target !== p
      x, y = window_place(v, target.at)
      W, H = card_size(v, target) .* v.zoom
      round_box(ctx, x - 2, y - 2, W + 4, H + 4, CARD_ROUND * v.zoom + 2, line=RGBA(colours.accent, 0.5), wide=2.0)
    end
  end
  v.typing === nothing || draw_caret(ctx, v)
end

"Draw the selection and the caret of the words that are being typed, where they are in their card"
draw_caret(ctx, v::CanvasView) = begin
  card, field, z = v.typing, canvas_input(v), v.zoom
  cs = collect(field.text)
  lines = card_wrap(field.text, word_room(card), word_size(card))
  x, y = window_place(v, card.at .+ word_inset(card))
  lead = word_lead(card) * z
  face = canvas_face(word_size(card))
  wide(r) = num(measure(face, String(cs[r]))) * z
  lo, hi = minmax(field.anchor, field.cursor)
  for (i, r) in enumerate(lines)
    a, b = max(first(r) - 1, lo), min(last(r), hi)
    a < b && round_box(ctx, x + wide(first(r):a), y + (i - 1) * lead, wide(a+1:b), lead, 2.0, fill=RGBA(colours.select, 0.6))
  end
  # The caret blinks, and it's lit just after a key
  mod(time() - field.last_action, 1.0) < 0.5 || return
  i = caret_line(lines, field.cursor)
  cx, top = x + wide(first(lines[i]):field.cursor), y + (i - 1) * lead
  trace(ctx, [(cx, top + 0.12lead), (cx, top + 0.88lead)], colours.accent, 1.5)
end

draw(ctx, size, ui::ConcreteRect, a::CanvasArea) = begin
  v = a.of
  e = editor(v)
  was = v.box
  v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  (v.box[3] > 0 && v.box[4] > 0) || return
  sync_typing!(v)
  # It shows the whole board when it first shows, and after Fit. In the page it shows it whole again when the page
  # gets wider or narrower. Otherwise it stays as big as a pinch or the wheel made it, so a card that's dragged
  # stays under the mouse.
  (v.zoom <= 0 || (!v.full && was[3] != v.box[3])) && fit_board!(v, v.box[3], v.box[4])
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    round_box(ctx, v.box..., 0, fill=canvas_back())
    isempty(v.data.cards) && isempty(v.data.strokes) && v.draft === nothing &&
      write_ink(ctx, readonly(e.buf) ? "Nothing is on this board" : "Click twice to write a note, or paste a picture, a link or a page",
                v.box[1] + 16, v.box[2] + 28, Face(SANS, "", 13px, colours.faint, false))
    x0, y0 = v.box[1] - v.at[1] * v.zoom, v.box[2] - v.at[2] * v.zoom
    draw_board_ink(ctx, e, v.data, docdir(e), x0, y0, v.zoom; picked=v.picked)
    v.draft === nothing || draw_shape(ctx, v.draft, x0, y0, v.zoom)
    draw_canvas_marks(ctx, v)
  end
end

# --- typing -------------------------------------------------------------------------------------

"The number of the line among `lines`, which `card_wrap` gives, that the caret after `n` characters is on"
caret_line(lines, n) = something(findlast(r -> first(r) - 1 <= n <= last(r), lines), length(lines))

"""
The place among the characters of `text`, as the note or the text `card`
shows it, that's nearest to `p`, a place on the board.
"""
index_near(card, text, p) = begin
  cs = collect(text)
  lines = card_wrap(text, word_room(card), word_size(card))
  dx, dy = word_inset(card)
  i = clamp(floor(Int, (p[2] - card.at[2] - dy) / word_lead(card)) + 1, 1, length(lines))
  r = lines[i]
  face = canvas_face(word_size(card))
  # The space at the end of a line that wraps belongs to it, but the caret goes before it
  soft = i < length(lines) && last(r) + 1 == first(lines[i+1])
  ns = first(r)-1:max(first(r) - 1, soft ? last(r) - 1 : last(r))
  argmin(n -> abs(num(measure(face, String(cs[first(r):n]))) - (p[1] - card.at[1] - dx)), ns)
end

"The place among the characters that are being typed that's nearest to `p`, a place on the board, or nothing when `p` is off their card"
typed_place(v::CanvasView, p) = begin
  card = v.typing
  card === nothing && return nothing
  Canvases.inside(p, Canvases.edges(card, card_size(v, card)), 4 / v.zoom) || return nothing
  index_near(card, canvas_input(v).text, p)
end

"While words are typed, the card holds them, so that it's as big as they need"
sync_typing!(v::CanvasView) = (v.typing === nothing || (v.typing.content = canvas_input(v).text); v)

"Start typing in the note or the text `card`, with the caret nearest `p`, a place on the board, or at the end of its words"
start_typing!(v::CanvasView, card, p=nothing; fresh=false) = begin
  field = canvas_input(v)
  v.typing, v.fresh, v.was = card, fresh, card.content
  v.picked = card
  v.grab = nothing
  field.text = card.content
  field.anchor = field.cursor = p === nothing ? length(field.text) : index_near(card, field.text, p)
  field.last_action = time()
  focus(field)
  handled
end

"""
Stop typing. With `keep`, the words that were typed are written down, and a
note that holds only a web address or a wiki link becomes a card of that
page. Without it, the words go back to what they were. A card with no words
left is taken away. The keyboard goes back to the board.
"""
finish_typing!(v::CanvasView; keep=true) = begin
  card = v.typing
  card === nothing && return nothing
  field = canvas_input(v)
  v.typing = nothing
  w = window_of(v)
  w !== nothing && w.focus === field && focus(canvas_area(v))
  text = keep ? replace(rstrip(field.text), r"^(?:[ \t]*\n)+" => "") : v.was
  fresh, v.fresh = v.fresh, false
  if isempty(strip(text))
    Canvases.remove!(v.data, card)
    v.picked === card && (v.picked = nothing)
    fresh || commit!(v)   # a new card that was never written goes as it came
    return nothing
  end
  card.content = text
  if card.kind == :note && !occursin('\n', text)
    if Cards.isaddress(text)
      card.kind, card.width = :link, Canvases.WIDTHS.link
    elseif occursin(r"^\[\[[^\]]+\]\]$", text)
      card.kind, card.width, card.content = :page, Canvases.WIDTHS.page, Canvases.page_name(text)
    end
  end
  commit!(v)
  v.tool == :select || (v.picked = nothing)   # with another tool, the next click makes more
  card
end

"Put a new line in the words that are being typed, where the caret is, in place of what's selected"
type_newline!(v::CanvasView) = begin
  field = canvas_input(v)
  cs = collect(field.text)
  lo, hi = minmax(field.anchor, field.cursor)
  field.text = String([cs[1:lo]; '\n'; cs[hi+1:end]])
  field.anchor = field.cursor = lo + 1
  field.last_action = time()
  handled
end

"Move the caret of the words that are being typed a line up or down, as near as it can be to where it is across. ⇧ selects."
caret_up_down!(v::CanvasView, down, shift) = begin
  card, field = v.typing, canvas_input(v)
  cs = collect(field.text)
  lines = card_wrap(field.text, word_room(card), word_size(card))
  i = caret_line(lines, field.cursor)
  j = i + (down ? 1 : -1)
  n = if j < 1
    0
  elseif j > length(lines)
    length(cs)
  else
    dx, dy = word_inset(card)
    across = num(measure(canvas_face(word_size(card)), String(cs[first(lines[i]):field.cursor])))
    index_near(card, field.text, (card.at[1] + dx + across, card.at[2] + dy + (j - 0.5) * word_lead(card)))
  end
  field.cursor = n
  shift || (field.anchor = n)
  field.last_action = time()
  handled
end

"Note a click at `(x, y)` in the window. True when it's the second of two clicks in one place."
click_twice!(v::CanvasView, x, y) = begin
  at, cx, cy = v.clicked
  v.clicked = (time(), x, y)
  time() - at < 0.35 && hypot(x - cx, y - cy) < 4
end

# --- changing the board -----------------------------------------------------------------------

"""
A new note joined to `card` by a line, and the keyboard in it: to the right
of `card` as the next card that it joins to (`:child`), or under it as the
next card joined from the card that it's joined from (`:sibling`).
"""
add_joined!(v::CanvasView, card, how) = begin
  readonly(editor(v).buf) && return handled
  size(c) = card_size(v, c)
  new = Canvases.Card(:note, (0.0, 0.0))
  wh = (new.width, 2NOTE_PAD + word_lead(new))
  if how == :child
    new.at, from = Canvases.child_place(v.data, card, wh, size), card
  else
    new.at, from = Canvases.sibling_place(v.data, card, wh, size), Canvases.parent_of(v.data, card)
  end
  push!(v.data.cards, new)
  from === nothing || Canvases.join!(v.data, from, new)
  show_place!(v, new)
  start_typing!(v, new; fresh=true)
end

"Stop typing, and add a note joined to the card that was typed in or is selected, as `add_joined!` does"
add_after!(v::CanvasView, how) = begin
  card = v.typing !== nothing ? v.typing : v.picked
  card isa Canvases.Card || return handled
  finish_typing!(v)
  any(c -> c === card, v.data.cards) || return handled   # it had no words, and went
  add_joined!(v, card, how)
end

"Take away the card, the line between cards or the line drawn by hand that's selected"
delete_picked!(v::CanvasView) = begin
  p, d = v.picked, v.data
  p === nothing && return handled
  v.picked = nothing
  p isa Canvases.Card ? Canvases.remove!(d, p) : p isa Pair ? filter!(j -> j !== p, d.joins) : filter!(s -> s !== p, d.strokes)
  commit!(v)
  handled
end

"Take back the last change of the page, or do it again"
undo_canvas!(v::CanvasView, command) = begin
  b = editor(v).buf
  command == :redo ? redo!(b) : undo!(b)
  v.picked = nothing
  handled
end

"Put `card` on the board with the middle of its top at `at`, where no card covers it, select it and write the board down"
add_card!(v::CanvasView, card, at) = begin
  wh = card_size(v, card)
  card.at = Canvases.free_place(v.data, (at[1] - wh[1] / 2, at[2] - 20), wh, c -> card_size(v, c))
  push!(v.data.cards, card)
  v.picked = card
  commit!(v)
  show_place!(v, card)
  handled
end

"The card that text which is put on the board makes: a card of a web page for its address, a card of a page for a wiki link, and a note for any other"
text_card(text) = Cards.isaddress(text) ? Canvases.Card(:link, (0, 0), text) :
                  occursin(r"^\[\[[^\]\n]+\]\]$", text) ? Canvases.Card(:page, (0, 0), Canvases.page_name(text)) :
                  Canvases.Card(:note, (0, 0), text)

"The name that a card of the page at `path` has: what a wiki link from this page would call it"
page_name_for(e, path) = (name = splitext(basename(path))[1]; wiki_path(e, name) == path ? name : splitext(named(e, path))[1])

"""
Put the files at `paths` on the board, near the place `at`: a picture as a
picture, and a Markdown file as a card of the page. Other files are left out.
A file in a folder for temporary files is copied to the media folder first,
as a paste in the page does.
"""
put_on_board!(v::CanvasView, paths, at) = begin
  e = editor(v)
  readonly(e.buf) && return handled
  added = 0
  for path in paths
    path = rstrip(String(path), '/')
    isfile(path) || continue
    passing(e, path) && (path = something(keep_copy(e, path), path))
    card = ispicture(path) ? Canvases.Card(:picture, (0, 0), named(e, path)) :
           ismarkdown(path) ? Canvases.Card(:page, (0, 0), page_name_for(e, path)) : nothing
    card === nothing && continue
    wh = card_size(v, card)
    card.at = Canvases.free_place(v.data, (at[1] - wh[1] / 2, at[2] - wh[2] / 2), wh, c -> card_size(v, c))
    push!(v.data.cards, card)
    v.picked = card
    added += 1
  end
  added > 0 && (commit!(v); show_place!(v, v.picked))
  handled
end

"The place on the board where what's pasted goes: under the mouse when it's on the board, or the middle of what shows"
drop_place(v::CanvasView, w) = begin
  x, y = num(w.mouse[1]), num(w.mouse[2])
  Canvases.inside((x, y), (v.box[1], v.box[2], v.box[1] + v.box[3], v.box[2] + v.box[4])) ? board_place(v, x, y) : board_middle(v)
end

"""
Put what the clipboard holds on the board, as a paste in the page does:
files that were copied in the Finder, a picture that was copied as itself, a
web address as a card of its page, a wiki link as a card of the page, and any
other text as a note.
"""
paste_canvas!(v::CanvasView, w) = begin
  e = editor(v)
  at = drop_place(v, w)
  paths = Pasteboard.files()
  isempty(paths) || return put_on_board!(v, paths, at)
  text = String(strip(replace(Sys.isapple() ? Pasteboard.text() : clipboard(), "\r\n" => "\n", '\r' => '\n')))
  # A picture that's copied from a web page comes with its address as text, and the picture is what's wanted
  found = isempty(text) || occursin(r"^\w+://\S+$", text) ? Pasteboard.media() : nothing
  path = found === nothing ? nothing : keep_pasted(e, found...)
  path === nothing || return put_on_board!(v, [path], at)
  isempty(text) ? handled : add_card!(v, text_card(text), at)
end

"Ask which pictures go on the board, with macOS's own panel"
choose_pictures!(v::CanvasView, w) = begin
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
  path === nothing || put_on_board!(v, [path], board_middle(v))
  handled
end

"""
Open what a card shows: a web page in the browser, or one of your pages in
the window. When that page has a canvas, its first one fills the window.
"""
open_card!(v::CanvasView, card) = begin
  e = editor(v)
  if card.kind == :link
    BROWSER[](card.content)
  elseif card.kind == :page
    # From a board that fills the window, the page's own board fills the window too. From a board in the page, the page shows.
    g = page_glance(e, card.content)
    v.full && g.board !== nothing && (canvas_to_fill[] = g.path)
    follow_wiki!(e, card.content)
    redraw_in!(e, 0.05)
  end
  handled
end

"The canvas of the page that's under the mouse, in the page or filling the window, or nothing"
canvas_at(e, w) = begin
  x, y = w.mouse
  full = full_block(e)
  for (key, node) in e.nodes
    node isa CanvasView && key isa Tuple && length(key) == 4 && key[3] == e.buf.path || continue
    (full === nothing || full === node) || continue
    r = rect(canvas_area(node))
    r !== nothing && r.left <= x < r.left + r.width && r.top <= y < r.top + r.height && return node
  end
  nothing
end

# --- the mouse and the keys -------------------------------------------------------------------

cursor(a::CanvasArea) = begin
  v = a.of
  w = window_of(a)
  (w === nothing || v.zoom <= 0) && return :arrow
  v.tool == :pen && return :crosshair
  v.tool == :text && return :ibeam
  v.grab !== nothing && return v.grab[1] == :pan ? :hand : :arrow
  x, y = num(w.mouse[1]), num(w.mouse[2])
  knob_under(v, x, y) === nothing || return :hand
  typed_place(v, board_place(v, x, y)) === nothing ? :arrow : :ibeam
end
cursor(::CanvasView) = :arrow

onkey(a::CanvasArea, ev::KeyPress{Keys.mouse_left}) = begin
  v, w = a.of, ev.window
  # A click changes the board in the page too. With ⌥ held, the page shows the block's lines.
  v.full || !only_held(v, Keys.opt) || return nothing
  v.zoom > 0 || return handled
  x, y = num(w.mouse[1]), num(w.mouse[2])
  p = board_place(v, x, y)
  twice = click_twice!(v, x, y)
  # A click on the words that are being typed puts the caret there
  if v.typing !== nothing && (n = typed_place(v, p)) !== nothing
    field = canvas_input(v)
    field.cursor = n
    only_held(w, Keys.shft) || (field.anchor = n)
    field.last_action = time()
    return handled
  end
  finish_typing!(v)
  focus(a)
  # A page that can't change can still be moved round
  readonly(editor(v).buf) && (v.grab = (:pan, (x, y), false); return handled)
  if v.tool == :pen
    v.picked = nothing
    v.draft = Sketches.Shape(:pen, v.colour, [p])
    v.grab = (:draw, (x, y), false)
    return handled
  elseif v.tool == :text
    card = card_under(v, p)
    card !== nothing && card.kind == :text && return start_typing!(v, card, p)
    # The middle of the first line of the new words is at the mouse
    new = Canvases.Card(:text, (p[1], p[2] - v.size * TEXT_LEADING / 2); colour=v.colour, size=v.size)
    push!(v.data.cards, new)
    return start_typing!(v, new; fresh=true)
  end
  knob = knob_under(v, x, y)
  if knob !== nothing
    v.picked = knob[2]
    v.grab = (knob[1], (x, y), false)
    knob[1] == :join && (v.reach = p)
    return handled
  end
  card = card_under(v, p)
  if card !== nothing
    # Two clicks on a note or a text change its words, and two on a card of a page or a web page open it
    if twice && card === v.picked
      Canvases.wordy(card) && return start_typing!(v, card, p)
      card.kind in (:page, :link) && return open_card!(v, card)
    end
    v.picked = card
    v.grab = (:move, (x, y), false)
    return handled
  end
  line = Canvases.stroke_at(v.data, p; reach=6 / v.zoom)
  line === nothing && (line = Canvases.join_at(v.data, p, c -> card_size(v, c); reach=6 / v.zoom))
  line === nothing || return (v.picked = line; handled)
  # Two clicks on an empty place make a note there, and a drag moves round the board
  if twice
    new = Canvases.Card(:note, (p[1] - 2NOTE_PAD, p[2] - NOTE_PAD - word_lead(Canvases.Card(:note, (0, 0))) / 2))
    push!(v.data.cards, new)
    return start_typing!(v, new; fresh=true)
  end
  v.picked = nothing
  v.grab = (:pan, (x, y), false)
  handled
end

onmouse(a::CanvasArea, ev::MouseMove) = begin
  v, w = a.of, ev.window
  v.grab === nothing && return nothing
  Keys.mouse_left in w.keys || return handled
  what, from, _ = v.grab
  x, y = num(w.mouse[1]), num(w.mouse[2])
  (x, y) == from && return handled
  dx, dy = (x - from[1]) / v.zoom, (y - from[2]) / v.zoom
  p = v.picked
  if what == :pan
    v.at = (v.at[1] - dx, v.at[2] - dy)
  elseif what == :move && p isa Canvases.Card
    Canvases.move!(p, dx, dy)
  elseif what == :width && p isa Canvases.Card
    p.kind == :text && p.width == 0 && (p.width = card_size(v, p)[1])   # a text with no width gets the width of its words
    Canvases.set!(p, :width, p.width + dx)
  elseif what == :join
    v.reach = board_place(v, x, y)
  elseif what == :draw && v.draft !== nothing
    q = board_place(v, x, y)
    # A line drawn by hand gets a new place when the mouse has moved a little
    hypot((q .- v.draft.points[end])...) >= 1.5 / v.zoom && push!(v.draft.points, q)
    return handled
  end
  v.grab = (what, (x, y), true)
  handled   # the drag is the board's, so the page's text doesn't select
end

"The mouse let go. A line that was drawn joins the board, a line from a card joins it to the card it ends on, and a card that moved is written down."
canvas_drop!(v::CanvasView) = begin
  g, d, at = v.grab, v.draft, v.reach
  v.grab = v.draft = v.reach = nothing
  g === nothing && return v
  what, _, moved = g
  p = v.picked
  if what == :draw && d !== nothing
    d.points = Sketches.simplify(d.points, 0.8 / v.zoom)
    length(d.points) >= 2 || return v   # a click without a drag draws nothing
    push!(v.data.strokes, d)
    commit!(v)
  elseif what == :join && moved && p isa Canvases.Card && at !== nothing
    target = card_under(v, at)
    if target === nothing
      # On an empty place, a new note joined to the card, with the keyboard
      new = Canvases.Card(:note, (at[1], at[2] - NOTE_PAD - word_lead(p) / 2))
      push!(v.data.cards, new)
      Canvases.join!(v.data, p, new)
      start_typing!(v, new; fresh=true)
    elseif target !== p
      Canvases.join!(v.data, p, target) && commit!(v)
    end
  elseif what in (:move, :width) && moved && p isa Canvases.Card
    # A card that's moved goes over the others
    what == :move && (filter!(c -> c !== p, v.data.cards); push!(v.data.cards, p))
    commit!(v)
  end
  v
end

# Two fingers on the trackpad move round the board. A pinch, the mouse wheel, or two fingers with ⌘ held make it
# bigger or smaller round the mouse. In the page the wheel and two fingers scroll the page, which goes past the
# board. With ⌘ held they make it bigger or smaller there too, as a pinch does.
onscroll(a::CanvasArea, ev::MouseScroll) = begin
  v, w = a.of, ev.window
  (v.full || only_held(w, Keys.cmd)) || return nothing
  v.zoom > 0 || return handled
  (only_held(w, Keys.cmd) || ev.wheel) && return zoom_board!(v, exp(num(ev.delta[2]) / 10), num(w.mouse[1]), num(w.mouse[2]))
  v.at = (v.at[1] - 30num(ev.delta[1]) / v.zoom, v.at[2] - 30num(ev.delta[2]) / v.zoom)
  handled
end
onscroll(v::CanvasView, ::MouseScroll) = v.full ? handled : nothing
onpinch(a::CanvasArea, ev::Pinch) = zoom_board!(a.of, ev.scale, num(ev.window.mouse[1]), num(ev.window.mouse[2]))

# Esc lets go of what's selected, then chooses the arrow, then puts a board that fills the window back in the page.
# In the page the page's text takes that Esc, and gets the keyboard back. Delete takes away what's selected. Tab
# and ⇧Return add a note joined to the card that's selected. Return types in the note or the text that's selected,
# or opens a card of a page.
onkey(a::CanvasArea, ev::KeyPress{K}) where K = begin
  v, w = a.of, ev.window
  ro = readonly(editor(v).buf)
  p = v.picked
  if K == Keys.escape && unmodified(ev)
    p === nothing || return (v.picked = nothing; handled)
    v.tool == :select || return (v.tool = :select; handled)
    return v.full ? full!(v, false) : nothing
  elseif K in (Keys.backspace, Keys.delete) && unmodified(ev)
    return ro ? handled : delete_picked!(v)
  elseif K == Keys.tab && unmodified(ev)
    return p isa Canvases.Card && !ro ? add_after!(v, :child) : handled
  elseif K == Keys.enter && only_held(ev, Keys.shft)
    return p isa Canvases.Card && !ro ? add_after!(v, :sibling) : handled
  elseif K == Keys.enter && unmodified(ev)
    p isa Canvases.Card || return handled
    Canvases.wordy(p) && !ro && return start_typing!(v, p)
    return p.kind in (:page, :link) ? open_card!(v, p) : handled
  elseif K == Keys.v && only_held(ev, Keys.cmd)
    return ro ? handled : paste_canvas!(v, w)
  elseif (command = command_of(editor(v), w, K)) in (:undo, :redo)
    return undo_canvas!(v, command)
  end
  nothing
end

# While words are typed, the text field takes the keys that it knows. The rest come here. Return starts a new
# line, and Esc ends the typing. Tab and ⇧Return add a note joined to the one that's typed in. Up and Down move
# the caret a line. ⌘Z ends the typing and takes back the last change.
onkey(v::CanvasView, ev::KeyPress{K}) where K = begin
  v.typing === nothing && return nothing
  if K == Keys.enter
    unmodified(ev) && return type_newline!(v)
    only_held(ev, Keys.shft) && return add_after!(v, :sibling)
  elseif K == Keys.tab && unmodified(ev)
    return add_after!(v, :child)
  elseif K == Keys.escape && unmodified(ev)
    finish_typing!(v)
    return handled
  elseif K in (Keys.up, Keys.down) && (unmodified(ev) || only_held(ev, Keys.shft))
    return caret_up_down!(v, K == Keys.down, only_held(ev, Keys.shft))
  elseif (command = command_of(editor(v), ev.window, K)) in (:undo, :redo)
    finish_typing!(v)
    return undo_canvas!(v, command)
  end
  nothing
end
onmouse(v::CanvasView, ::MouseMove) = v.full || (held(v, Keys.mouse_left) && v.grab !== nothing) ? handled : nothing
# A click beside a button of a canvas that fills the window is the canvas's, and not the page's under it
onkey(v::CanvasView, ::KeyPress{Keys.mouse_left}) = v.full ? (focus(canvas_area(v)); handled) : nothing

block_tick!(v::CanvasView) = begin
  v.grab !== nothing && !held(v, Keys.mouse_left) && canvas_drop!(v)
  w = window_of(v)
  # A click somewhere else took the keyboard from the words that were being typed. They're kept.
  v.typing !== nothing && w !== nothing && w.focus !== canvas_input(v) && finish_typing!(v)
  # The card that was typed in has gone, as after ⌘Z
  v.typing !== nothing && !any(c -> c === v.typing, v.data.cards) && (v.typing = nothing)
  v.typing === nothing || (sync_typing!(v); redraw_in!(v, 0.25))   # the caret blinks
  # The page took the keyboard, as when Back came to this page, but its text doesn't show
  v.full && w !== nothing && w.focus === editor(v) && focus(canvas_area(v))
  # A card of a page opened this page, and its first canvas fills the window
  if canvas_to_fill[] == editor(v).buf.path && v.n == 1
    canvas_to_fill[] = ""
    v.full || full!(v, true)
  end
  v
end

"The canvas as HTML: a picture of it"
canvas_html(e, v::CanvasView) = begin
  d = v.data
  isempty(d.cards) && isempty(d.strokes) && return nothing
  cs = css_colour.(SERIES_LIGHT)
  dir = docdir(e)
  source(card) = (p = card_file(card, dir); isfile(p) ? escaped(named(e, p)) : nothing)
  picture = Canvases.svg(d; size=c -> card_size(e, c, dir), lines=card_lines, source,
                         colours=(ink="#2b2622", red=cs[8], blue=cs[1], green=cs[6], orange=cs[2], card="#ffffff", edge="#dddddd", join="#9a9a9a", dim="#777777"),
                         family="-apple-system, Helvetica, sans-serif")
  "<div class=\"diagram\">\n$picture\n</div>"
end

BLOCKS[CANVAS] = CanvasView
block_name(::Type{CanvasView}) = "Canvas"
block_icon(::Type{CanvasView}) = "sticky"
block_insert(::Type{CanvasView}) = ("Canvas", ["```$CANVAS", "```", "", ""], (4, 0))
block_html(e, v::CanvasView) = canvas_html(e, v)
