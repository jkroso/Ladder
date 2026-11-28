# The snake and the ladder in the top bar, and the slider of the levels
#
# A page shows at one of two levels of abstraction. The low level is its
# symbols: the markup that the file holds. The high level is its graphics: what
# the symbols make, like bold words, a table or a chart. The top bar of a
# document has one picture that says which level the page is at now, from the
# game of snakes and ladders. A ladder takes you up, so at the high level it's
# a ladder. A snake takes you down, so at the low level it's a snake. A click
# on it goes to the other level, and ⌘E does too. See "rich text and plain
# text" above for what each level does. While a takeoff, a schedule or a
# sketch fills the window, the click goes down to the lines that make it,
# and those lines fill the window as text. See `page_level!`. A file of text
# that's only shown has three levels, and a JSON file and a CSV file have
# four. Julia code has four of its own, and while the caret is in a `julia`
# code block the picture is about that block. While the mouse is over the
# picture, it opens into a slider with a stop for each level. See "the slider
# of the levels".

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor show_tooltip! hide_tooltip! redraw_in! rect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon icon_cache
@use "github.com/jkroso/UI.jl/Interface/Semantic/SVG" SVGPath
@use "./markdown" words
@use "./sheet" parts
@use "github.com/jkroso/UI.jl/Interface/draw" sync_mouse!
@use "./look" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./blocks" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./julia_levels" exports...
@use "./json_view" exports...
@use "./file_view" exports...
@use "./live_view" exports...
@use "./check_view" exports...
@use "./email_view" exports...

export MODE_W, TITLE_ROOM, SNAKE, snake, level_picture, mode_part, FILE_LEVELS, PAGE_LEVELS, BLOCK_LEVELS,
       LEVELS_KEY, STOP_W, TRACK_W, OPENS_IN, level_part, other_level, click_level, level_names, stop_tip,
       slide!, openness, slider_w, slider_grown, track, go!, plain!, low, block_lang, block_span, page_level!,
       lower!, widen!, confine!, refill!, LoweredState

const MODE_W = 30px   # the room that the picture takes in the top bar
const TITLE_ROOM = 160px   # the least room that the file's name keeps in the top bar of a narrow window

# UI.jl has a ladder among its icons and no snake. These are the snake's
# shapes, in a square 16 wide: its body and its tongue. The body is a line round
# a snake that lies folded three times, with its tail at the top and its head
# hung down, as a snake takes you down. Each edge of a line is on a whole or a
# half, so on a screen with two pixels to a point each line is sharp.
const SNAKE = ("M0.92 1.01L6.92 0.01Q6.96 0 7 0L12 0Q13.45 0 14.47 1.03Q15.5 2.05 15.5 3.5Q15.5 4.95 14.47 5.97Q13.45 7 12 7L4 7Q3.5 7 3.5 7.5Q3.5 8 4 8L7 8Q8.04 8 8.77 8.73Q9.5 9.46 9.5 10.5Q9.5 10.37 9.43 10.3Q9.43 10.3 9.51 10.36Q10.25 10.9 10.25 11.8Q10.25 12.68 9.45 13.65Q8.65 14.6 8 14.6Q7.35 14.6 6.55 13.65Q5.75 12.68 5.75 11.8Q5.75 10.9 6.49 10.36Q6.57 10.3 6.57 10.3Q6.5 10.37 6.5 10.5L7 10.5L7 11L4 11Q2.55 11 1.53 9.97Q0.5 8.95 0.5 7.5Q0.5 6.05 1.53 5.03Q2.55 4 4 4L12 4Q12.5 4 12.5 3.5Q12.5 3 12 3L7 3Q6.96 3 6.92 2.99L0.92 1.99Q0.87 1.99 0.82 1.97Q0.78 1.95 0.74 1.92Q0.69 1.9 0.66 1.86Q0.62 1.83 0.59 1.79Q0.56 1.75 0.54 1.71Q0.52 1.66 0.51 1.61Q0.5 1.56 0.5 1.52Q0.5 1.47 0.51 1.42Q0.52 1.34 0.56 1.27Q0.59 1.2 0.65 1.15Q0.7 1.09 0.77 1.06Q0.84 1.02 0.92 1.01ZM1.08 1.99L1 1.5L1.08 1.01L7.08 2.01L7 2.5L7 2L12 2Q12.62 2 13.06 2.44Q13.5 2.88 13.5 3.5Q13.5 4.12 13.06 4.56Q12.62 5 12 5L4 5Q2.96 5 2.23 5.73Q1.5 6.46 1.5 7.5Q1.5 8.54 2.23 9.27Q2.96 10 4 10L7 10Q7.05 10 7.1 10.01Q7.15 10.02 7.19 10.04Q7.24 10.06 7.28 10.08Q7.32 10.11 7.35 10.15Q7.39 10.18 7.42 10.22Q7.44 10.26 7.46 10.31Q7.48 10.35 7.49 10.4Q7.5 10.45 7.5 10.5Q7.5 10.86 7.08 11.17Q6.75 11.41 6.75 11.8Q6.75 12.32 7.32 13Q7.82 13.6 8 13.6Q8.18 13.6 8.68 13Q9.25 12.32 9.25 11.8Q9.25 11.41 8.92 11.17Q8.5 10.86 8.5 10.5Q8.5 9.88 8.06 9.44Q7.62 9 7 9L4 9Q3.38 9 2.94 8.56Q2.5 8.12 2.5 7.5Q2.5 6.88 2.94 6.44Q3.38 6 4 6L12 6Q13.04 6 13.77 5.27Q14.5 4.54 14.5 3.5Q14.5 2.46 13.77 1.73Q13.04 1 12 1L7 1L7 0.5L7.08 0.99L1.08 1.99Z",
               "M8.4 14.1L8.4 14.55A0.4 0.4 0 0 1 7.6 14.55L7.6 14.1A0.4 0.4 0 0 1 8.4 14.1ZM8.26 14.86L7.36 15.61A0.4 0.4 0 0 1 6.84 14.99L7.74 14.24A0.4 0.4 0 0 1 8.26 14.86ZM8.26 14.24L9.16 14.99A0.4 0.4 0 0 1 8.64 15.61L7.74 14.86A0.4 0.4 0 0 1 8.26 14.24Z")

"""
The name of the snake's icon. Its shapes go among UI.jl's icons the first time
that it's asked for. They go there again when the shapes there aren't these:
an app that loads this file again keeps UI.jl's icons, and with them the shapes
that the file had before.
"""
snake() = begin
  kept = get(icon_cache, "snake", nothing)
  (kept === nothing || [p.d for p in kept.paths] != collect(SNAKE)) &&
    (icon_cache["snake"] = (paths=[SVGPath(d=d) for d in SNAKE], viewbox=(0f0, 0f0, 16f0, 16f0)))
  "snake"
end

describe(m::Mode) = begin
  e = editor(m)
  ishovered(m) || (m.quiet = false)
  l = slide!(m)
  # While the slider is open, and while it opens out or closes, it's what shows here. It's a part of the row of
  # the top bar, so the parts before it move aside as it opens, and come back as it closes.
  (l.open || openness(l) > 0) && return Box(height(28px), name="Levels", l)
  level_picture(m)
end

"The picture that `m` shows while its slider is closed: the ladder at the highest level, and the snake under it"
level_picture(m::Mode) = begin
  e = editor(m)
  Box(width(MODE_W), height(28px), radius(6px), Alignment.Center, name=low(e) ? "Plain text" : "Rich text",
      background(ishovered(m) ? colours.hover : clear),
    # Both are drawn for a square 16 wide, so at this size their lines are on whole pixels
    Icon(low(e) ? snake() : "ladder", size=16px, color=colours.dim))
end

cursor(::Mode) = :hand
# A block that the click makes fill the window again keeps the keyboard that it took
# What shows the front matter, like the top of an email, keeps the keyboard, so the ladder stays its own
onkey(m::Mode, ::KeyPress{Keys.mouse_left}) = (e = editor(m); level!(e); hush!(m); full_block(e) === nothing && head_in_charge(e) === nothing && focus(e); handled)
# The tip says what a click does, as the count's tip does
tip(m::Mode) = (e = editor(m); stop_tip(e, other_level(e)))

"The snake or the ladder for the top bar. A document has one, and so have a file of text that's only shown and a file of Julia code. It's about the part of the page that the caret is in: see `level_part`."
mode_part(e) = e.buf.view == :markdown || !isempty(file_views(e.buf)) || julia_file(e.buf) ? (node!(Mode, e, :mode),) : ()

# --- the slider of the levels --------------------------------------------------------------------
#
# What the window shows can have more than two levels. A file of text that's
# only shown has three: its bits, its bytes in hexadecimal, and its text. A
# JSON file has the tree of its values over those, and a CSV file has its
# table. Julia code has four, in a file or in a `julia` code block of a page,
# and they're levels of what the code comes to when it runs: its assembly,
# its LLVM code, its inferred code, and its value.
# So while the mouse is over the picture in the top bar, the picture opens out
# into a slider. The snake is at the slider's low end and the ladder is at its
# high end, and each is the stop of its level. Each level between those two
# has a dot between them. The stop of the level that the window shows is lit.
# The slider takes the picture's place in the top bar, so the buttons and
# words before it move to the left as it opens, and come back as it closes.
# It covers none of them.
#
# A click on a stop goes to its level, and so does a drag along the slider.
# The slider opens out to the left, so the ladder stays under the mouse. A
# click on the ladder while the window is at the highest level goes one level
# down, and a click on the snake while it's at the lowest goes one level up.
# So with two levels, a click on the picture still goes to the other level.
# ⌘E goes one level down from the highest level, and to the highest level
# from any other. The tip of a stop says what a click on it does.
#
# The levels belong to a part of the window, not to the window. The top bar
# asks one part for them: the part that the caret is in. See `level_part`.
# `levels`, `level` and `level!` are functions of a part. A part that has no
# levels of its own passes each of them to the part that it's in, so the
# nearest part up the tree answers. A block of Julia code answers for itself:
# see "what Julia code ran, down a level". The document answers for every
# other part of a page, for a block that fills the window, and for a file. So
# with the caret in a `julia` code block, the slider has the four levels of
# that block, and with the caret in the page's text it has the two of the
# page. A part gets levels of its own with a method of each of the three
# functions.

const FILE_LEVELS = ("the file's bits", "the file's bytes in hexadecimal", "the file's text")   # and the tree or the table over them
const PAGE_LEVELS = ("the symbols of the part with the caret", "the graphics that the symbols make")
const BLOCK_LEVELS = ("the symbols that make this", "the graphics that the symbols make")
const LEVELS_KEY = :levels
const STOP_W = 24px      # the room of the dot of a level between the two ends, with the line that goes through it
const TRACK_W = 14px     # the line between the two ends, when there's no level between them
const OPENS_IN = 0.14    # seconds for the slider to open out from the picture

"""
The part of the window that the top bar asks for its levels: what shows the
front matter, like the top of an email, while it or a part of it has the
keyboard or the caret is on it, the `check` block that the caret is on or in,
the block of Julia code that the caret is in, or the document when the caret
is in no such block.
While a block fills the window, the caret is out of sight, and the document
answers for that block.
"""
level_part(e) = begin
  b = e.buf
  full_block(e) === nothing && (h = head_in_charge(e)) !== nothing && return h
  full_block(e) === nothing && (v = check_in_charge(e)) !== nothing && return v
  c = full_block(e) !== nothing ? nothing : julia_file(b) || !caretless(b) ? julia_part(e, b.caret[1]) : nothing
  c === nothing ? node!(Document, e, :document) : c
end

"""
The levels of abstraction that `node` can show at, from the lowest to the
highest. Each is what shows there, as the tip of its stop says it. A part of
the window with no levels of its own gives those of the part that it's in.
"""
levels(node::SemanticUI) = levels(node.parent)
"The level that `node` shows at: its place in `levels(node)`"
level(node::SemanticUI) = level(node.parent)
"Show `node` at level `i` of `levels(node)`"
level!(node::SemanticUI, i::Int) = level!(node.parent, i)

# The window is at the top of the tree. It has no levels of its own, and answers with those of the part that the top bar asks.
levels(e::Editor) = levels(level_part(e))
level(e::Editor) = level(level_part(e))
level!(e::Editor, i::Int) = (level!(level_part(e), i); e)

# The document answers for a page, for a block that fills the window, and for a file with more than one way to show
levels(d::Document) = begin
  e = editor(d)
  b = e.buf
  views = file_views(b)
  isempty(views) && return full_block(e) === nothing ? PAGE_LEVELS : BLOCK_LEVELS
  length(views) == 3 ? FILE_LEVELS : (FILE_LEVELS..., json_page(b) ? "the tree of the file's values" : html_page(b) ? "the page that the HTML makes" :
                                                    term_page(b) ? "the terminal that the file keeps" : chat_page(b) ? "the session that the file keeps" : "the file's table")
end

level(d::Document) = begin
  e = editor(d)
  views = file_views(e.buf)
  isempty(views) && return e.plain && full_block(e) === nothing ? 1 : 2
  something(findfirst(==(e.buf.view), views), length(views))
end

level!(d::Document, i::Int) = begin
  e = editor(d)
  i == level(d) && return d
  views = file_views(e.buf)
  # A page has two levels, so it goes to the other one
  isempty(views) ? page_level!(e) : file_level!(e, views[i])
  d
end

"The level that ⌘E goes to: one down from the highest level, and the highest level from any other"
other_level(node) = (n = length(levels(node)); level(node) == n ? n - 1 : n)

"""
The level that a click on the stop of level `i` goes to: its own level. The
ladder lies where the picture in the top bar is, so while the window is at the
highest level, a click on the ladder goes down a level, as a click on the
picture does.
"""
click_level(node, i::Int) = (n = length(levels(node)); i == n == level(node) ? n - 1 : i)

"What each level of the part that the top bar asks shows, as the tips of the stops say it. An email with HTML has its own words for its two levels."
level_names(e) = level_part(e) isa Document && full_block(e) === nothing && sent_html(e) !== nothing ? SENT_LEVELS : levels(e)

"""
What the tip of the stop of level `i` says. The stop of the level that the
window is at says what the window shows, and what a click on it does when a
click does something. Each other stop says what a click on it does.
"""
stop_tip(e, i::Int) = begin
  ls, now = level_names(e), level(e)
  # An email that can't show as it was sent shows its words at both levels, and its ladder says why
  ls === SENT_LEVELS && i == now == 2 && (why = sent_problem(e)) !== nothing && return why
  # The stop of the other level of an email with HTML says plainly what a click on it shows
  ls === SENT_LEVELS && i != now && return (i == 2 ? "Show HTML email" : "Show plain text email") * hint(e, :plain)
  to = click_level(e, i)
  shows = "The window shows $(ls[now])"
  to == now && return shows
  steps = abs(to - now)
  go = "$(to > now ? "up" : "down") $(steps == 1 ? "a level" : "$steps levels")"
  words = i == now ? "$shows. A click goes $go" : "Go $go, to $(ls[to])"
  to == other_level(e) ? words * hint(e, :plain) : words
end

"""
Open the slider of the levels while the mouse is over `m`, the picture in the
top bar, and close it when the mouse leaves. The slider takes the picture's
place in the row of the top bar, with its high end where the picture was. It's
a part of `m`, so the mouse is over `m` while it's over the slider. Returns the
slider.
"""
slide!(m::Mode) = begin
  e = editor(m)
  l = get!(() -> own!(m, Levels()), e.nodes, LEVELS_KEY)
  over = ishovered(m)
  if over != l.open
    # It opens or closes from where it is, so a mouse that comes back while it closes opens it again from there
    l.from, l.since, l.open = openness(l), time(), over
    l.pressed = -1
  end
  # A window hears nothing of a mouse that has left it, and the top bar is at its edge. So while the slider
  # is open, the window looks where the mouse is, and soon looks again.
  w = window_of(m)
  l.open && w !== nothing && !isempty(w.glfw) && (sync_mouse!(w); redraw_in!(m, 0.2))
  l
end

"How far the slider of the levels is open, from 0 for the picture to 1. It opens out quick at first, then slower, and closes the same way."
openness(l::Levels) = begin
  t = clamp((time() - l.since) / OPENS_IN, 0.0, 1.0)
  k = 1 - (1 - t)^2
  l.open ? l.from + (1 - l.from) * k : l.from * (1 - k)
end

"How wide the slider of `n` levels is when it's all the way open"
slider_w(n) = 2MODE_W + (n == 2 ? TRACK_W : STOP_W * (n - 2))

"How much wider than the picture the slider of the levels is now: none while it's closed"
slider_grown(e) = (l = get(e.nodes, LEVELS_KEY, nothing); l === nothing ? 0px : (slider_w(length(levels(e))) - MODE_W) * openness(l))

describe(l::Levels) = begin
  e = editor(l)
  n = length(levels(e))
  # A stop for each level. A page that fills the window with a block, or a file of another kind, can have a different number.
  length(l.stops) == n || (l.stops = Any[own!(l, Stop(level=i)) for i in 1:n])
  # A line goes from the snake to the ladder. The stop of each level between them has its part of the line.
  parts = n == 2 ? Any[l.stops[1], track(TRACK_W), l.stops[2]] : l.stops
  full = slider_w(n)
  time() - l.since < OPENS_IN && redraw_in!(l, 1/60)
  # It opens out to the left from the picture, so the ladder stays where the picture was
  wide = MODE_W + (full - MODE_W) * openness(l)
  Row(fixed(wide), height(28px), radius(6px), Alignment.Start, background(colours.float), clip=true, name="Levels",
    Box(Alignment.Start, offset_x=wide - full, Row(fixed(full), height(28px), Alignment.Center, parts...)))
end

"A part of the line that the stops of the slider are on. With no width, it takes the room that it's given."
track(wide=nothing) = Box(wide === nothing ? width(grow=grow) : width(wide), height(2px), background(colours.line))

# A click between two stops does nothing, and the picture under the slider doesn't get it
onkey(l::Levels, ::KeyPress{Keys.mouse_left}) = (l.pressed = 0; handled)
onmouse(l::Levels, ev::MouseMove) = (drag!(l, ev); handled)

"""
While the mouse button is down, go to the level of each stop of `l` that the
mouse comes to, and return true. The part of the window that the button went
down on hears each move of the mouse until the button comes up, so the stop
under the mouse isn't always the one that hears the move.
"""
drag!(l::Levels, ev::MouseMove) = begin
  Keys.mouse_left in ev.window.keys || (l.pressed = -1; return false)
  x, y = ev.position
  i = findfirst(l.stops) do s
    r = rect(s)
    r !== nothing && r.left <= x < r.left + r.width && r.top <= y < r.top + r.height
  end
  # The stop that the button went down on does nothing more until the mouse has left it
  i === nothing || l.pressed < 0 || l.pressed == i || (l.pressed = 0; i == level(editor(l)) || go!(l.stops[i]))
  true
end

describe(s::Stop) = begin
  e = editor(s)
  here = s.level == level(e)
  over = ishovered(s)
  over || (s.quiet = false)
  tint = here ? colours.active : over ? colours.hover : clear
  # The two ends are the snake and the ladder. Both are drawn for a square 16 wide, so at this size their lines are on whole pixels.
  s.level in (1, length(levels(e))) &&
    return Box(width(MODE_W), height(28px), radius(6px), Alignment.Center, background(tint), name="Stop",
             Icon(s.level == 1 ? snake() : "ladder", size=16px, color=here ? colours.ink : colours.dim))
  # A level between the ends is a dot on the line: bigger and darker for the level that the window is at
  d = here ? 10px : over ? 8px : 6px
  Row(fixed(STOP_W), height(28px), Alignment.Center, name="Stop",
    track(), Box(width(d), height(d), radius(d / 2), background(here ? colours.ink : over ? colours.dim : colours.marker)), track())
end

cursor(::Stop) = :hand

"Go to the level that a click on `s` goes to, and give the page the keyboard. A block that fills the window again keeps the keyboard that it took, and so does what shows the front matter, like the top of an email."
go!(s::Stop) = begin
  e = editor(s)
  level!(e, click_level(e, s.level))
  s.quiet = true
  hide_tooltip!(window_of(s))
  full_block(e) === nothing && head_in_charge(e) === nothing && focus(e)
  handled
end

onkey(s::Stop, ::KeyPress{Keys.mouse_left}) = ((s.parent::Levels).pressed = s.level; go!(s))

onmouse(s::Stop, ev::MouseMove) = begin
  drag!(s.parent::Levels, ev) && return handled
  r = rect(s)
  (s.quiet || r === nothing) && return handled
  show_tooltip!(ev.window, tip_label(stop_tip(editor(s), s.level)), r.left, r.top, r.width, r.height, placement=:bottom, gap=6px)
  handled
end

"""
Write the page as plain text, or with `on` false as rich text. Only the part
with the caret changes how it shows. Every window does the same, and the
setting is kept. The caret's line stays where it is in the window. When the
caret isn't in sight, the line at the top of the window stays there.
"""
plain!(e, on::Bool) = begin
  e.plain == on && return e
  e.plain = on
  if !isempty(e.layout)
    y = e.scroll.offset
    line = e.buf.caret[1]
    it = item(e, line)
    if e.buf.reading || it.top + it.tall <= y || it.top >= y + e.scroll.viewport
      k = something(findfirst(it -> it.top + it.tall > y, e.layout), 1)
      it, line = e.layout[k], e.layout[k].first
    end
    hold!(e, line, it.top - y)
  end
  save_settings!(e)
  rerun!(e, :plain)
  e
end

# A takeoff, a schedule or a sketch that fills the window is graphics, so the
# window is at the high level then, whatever level the page under it is at,
# and the top bar shows the ladder. Going down from there shows the symbols
# that make the block: the lines of the block fill the window as text, with
# nothing else of the page and no sidebar, and the caret stays in them. Going
# up again makes the block fill the window again. Esc puts the lines back
# among the lines of the page, as it puts a block that fills the window back
# in the page.

"True when `node` shows under its highest level. For the window, that's the part that the top bar asks: a page shows its symbols and no block fills the window, a file shows its bytes, or its text when it has a tree or a table, or the Julia code with the caret shows under the value of what ran."
low(node) = level(node) < length(levels(node))

"The language of the block that `v` is the view of, or nothing"
block_lang(v) = findfirst(T -> (T isa Type && v isa T) || (T isa BlockKind && T.view isa Type && v isa T.view), BLOCKS)
block_lang(v::FilterView) = v.lang
block_lang(v::ViewBlock) = v.lang

"The first and the last line of the block that `v` is the view of, or nothing"
block_span(b::Buffer, v) = (lang = block_lang(v); lang === nothing ? nothing : block_lines(b, lang, v.n))

"Go to the level that ⌘E goes to, of the part that the top bar asks: down from the highest level, or up to it again"
level!(e::Editor) = level!(e, other_level(e))

"Take a page to the other of its two levels: down from graphics to the symbols that make them, or up again"
page_level!(e) = begin
  v = full_block(e)
  v === nothing || return lower!(e, v)
  e.plain || return plain!(e, true)
  kept = lowered(e) === nothing ? nothing : state_of(e, LoweredState).kept
  plain!(e, false)
  kept === nothing || refill!(e, kept)
  e
end

@use "github.com/jkroso/Prospects.jl" @def

"What a window keeps of a block whose lines fill it as text: see `lower!`"
@def mutable struct LoweredState
  kept::Union{Nothing,NamedTuple} = nothing   # the block as `view`, the `path` of its page, and the `offset` that the page was scrolled to. Nothing while no block's lines fill the window.
end

"""
Go down a level from `v`, a block that fills the window. The lines of the
block fill the window in its place, as text, with the caret in them. A page
that's never changed has no caret, so its block goes back into the page.
"""
lower!(e, v) = begin
  b = e.buf
  span = block_span(b, v)
  v.full = false
  focus(e)
  (span === nothing || b.fixed) && return plain!(e, true)
  s, t = span
  empty!(b.others)
  b.caret = b.anchor = (min(s + 1, t), 0)
  plain!(e, true)
  hold!(e, nothing)   # the lines start at the top of the window
  state_of(e, LoweredState).kept = (view=v, path=b.path, offset=e.scroll.offset)
  e.scroll.offset = 0px
  touch!(e)
end

"""
The first and the last line of the block whose lines fill the window as text,
or nothing. They stop filling it when the block goes, when the page goes up a
level and when another file shows.
"""
lowered(e) = begin
  kept = state_of(e, LoweredState).kept
  kept === nothing && return nothing
  b = e.buf
  span = e.plain && kept.path == b.path && !b.fixed ? block_span(b, kept.view) : nothing
  span === nothing && widen!(e)
  span
end

"""
Put the lines that fill the window back among the lines of the page. The page
is where it was, or as near to that as shows the caret.
"""
widen!(e) = begin
  state = state_of(e, LoweredState)
  kept = state.kept
  kept === nothing && return e
  state.kept = nothing
  kept.path == e.buf.path && (e.scroll.offset = kept.offset; e.reveal = true)
  e
end

"Keep the caret, and each selection, in the lines that fill the window, or in the part of a page that another page shows"
confine!(e) = begin
  span = hosted(e) === nothing ? lowered(e) : shown_span(e)
  span === nothing && return e
  b = e.buf
  s, t = span
  near(p) = p[1] < s ? (s, 0) : p[1] > t ? line_end(b, t) : p
  b.caret, b.anchor = near(b.caret), near(b.anchor)
  filter!(o -> all(p -> s <= p[1] <= t, o), b.others)
  b.reading = false   # without a caret, the block would show as what it makes
  e
end

"Make the block whose lines fill the window fill it again. The caret goes onto the block as a whole, and the page under it is where it was."
refill!(e, kept) = begin
  b = e.buf
  state_of(e, LoweredState).kept = nothing
  hold!(e, nothing)
  e.scroll.offset = kept.offset
  span = block_span(b, kept.view)
  span === nothing && return e
  empty!(b.others)
  b.caret = b.anchor = (span[1], 0)
  full!(kept.view, true)
  e
end
