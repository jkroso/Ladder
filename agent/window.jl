# Agent mode: the window, the colours of its two panes, and a window that you see through
#
# The command Agent Mode puts an agent's session at the left of the page and
# the page's outline at its right. The window grows wider to make room for
# the two, and the page shows between them on a card with round corners, in
# the shape of a sheet of paper. The command again puts the window back.
#
# The session is a talk with Claude Code. What you type at the foot of the
# agent's pane goes to the agent, and what the agent says shows over it as a
# page of Ladder's, not as a terminal's letters: headings, lists, tables,
# maths, diagrams and charts. Each step that the agent takes, like reading a
# file, is a line. When the agent wants to do something that your settings
# make it ask for, the pane asks you, with a button that allows it and one
# that refuses.
#
# The agent is one program that runs for the whole session. Ladder writes it
# a line of JSON for each thing that you say, and it prints a line of JSON
# for each thing that it does: see `take_line!`. Its words come a few at a
# time, so they show as the agent writes them. The session starts in the top
# folder of the file's repository.
#
# What the agent says is a page, and its code runs as a page's code does: a
# sum in a line shows what it comes to, a `ui` block shows what it makes, and
# a block that a file of the session's folder defines draws. A drag on a
# number, a click on a to-do box and a block that writes its lines change the
# reply, as they change a page. No key changes it. See `reply_tick!`.
#
# The agent's pane has the sidebar's place. It always shows: the agent is
# what agent mode is for, so the top bar has no button that hides it, and the
# sidebar's key does nothing. Leaving agent mode is what takes it away. The
# outline is the panel at the right (see "the panel at the right"), with its
# button at the right end of the top bar. A click on a line of the outline
# goes to that heading.
#
# The outline needs only so much room, and the page has the width of a sheet
# of paper. So the page's card is beside the outline, and the agent's pane
# has all the rest of the window: a wider window gives the agent more room.

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use GLFW
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe window_of handled
@use "github.com/jkroso/UI.jl/Interface/draw" draw ishovered cursor redraw_in! box_path
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg with_pool send
@use "github.com/jkroso/UI.jl/Interface/window" nswindow
@use Colors: RGBA
@use "../look" exports...
@use "../buffer" exports...
@use "../editor_type" exports...
@use "../strokes" exports...
@use "../shared" exports...
@use "../host" exports...
@use "../folder_page" exports...
@use "../slides_view" exports...

export SOON, AGENT_W, AGENT_MIN, OUTLINE_W, PAGE_CARD_GAP, PAGE_CARD_ROUND, WINDOW_ROUND, PAGE_CARD_LEAST,
       PAGE_CARD_NARROWEST, PAGE_CARD_CHOSEN, PANE_X, PANE_LEFT, SEND_GROWS, SEND_ROOM, REPLY_SIZE,
       REPLY_NAME, reply_page, OutlinePane, OutlineRow, PageCard, CardEdge, PaneButton, PaneSlot, agent_pane,
       agent_mode, agent_shows, outline_room, agent_wide, page_card_wide, page_card_setting, page_shape_wide,
       page_card!, page_card_span, page_card_round, glass_colour, glass, on_glass, PANE_COLOURS, PAGE_KEPT, colours_over,
       pane_dark, over_colours!, with_colours, with_pane_colours, PaneColours, ColourMark, pane_mark,
       agent_body, GLASS_ALPHA, GLASS_BLUR, see_through, SURFACE_OPACITY, see_through!, glass_window!,
       blur_behind!

# A wait of 0 would leave the window waiting for a key or the mouse: its loop reads a wake of 0 as no wake at all
const SOON = 0.001                       # seconds: the wait for a frame that should come at once
const AGENT_W = 400px                    # how wide the agent's pane is in the window that agent mode makes. A wider window gives it more.
const AGENT_MIN = 300px                  # the agent's pane is never narrower than this while the window has room for it
const OUTLINE_W = 260px                  # how wide the outline is, in a window that has room for it
const PAGE_CARD_GAP = 8px                # between the page's card and the window's edges, and between it and each pane
const PAGE_CARD_ROUND = 14px             # how round the corners of the page's card are, where they're beside a pane
const WINDOW_ROUND = 16px                # how round macOS makes the corners of a window: AppKit's _cornerRadius on macOS 26 and later
const PAGE_CARD_LEAST = 420px            # the card is never narrower than this while the window has room for it
const PAGE_CARD_NARROWEST = 240px        # nor than this, when you drag its edge or the window is narrow
"How wide you made the page's card with the strip at its left edge, or `nothing` while it has a page's shape. Every window has it, and the settings file keeps it."
const PAGE_CARD_CHOSEN = Ref{Union{Nothing,px}}(nothing)
const PANE_X = 16px                      # the room at each side of what a pane shows
const PANE_LEFT = 24px                   # the room at the left of what you and the agent said, in line with the words that you type
const SEND_GROWS = 0.16                  # seconds that the send button takes to open over what goes with your words
const SEND_ROOM = 36px                   # the room at the right of the words that you type: the send button, and the gap before it
const REPLY_SIZE = 14px                  # how tall the text of the agent's pane is, before the page's zoom
const REPLY_NAME = ".ladder-reply.md"    # the name of the page that holds a reply of the agent. No file has it.

"The path of a page that holds what an agent said in a session that runs in the folder `dir`. Its pictures and links are from that folder."
reply_page(dir) = joinpath(dir, REPLY_NAME)

"True when `path` is the path of a page that holds what an agent said in a session"
is_reply(path::AbstractString) = endswith(path, REPLY_NAME) && basename(path) == REPLY_NAME

# --- the window in agent mode ---

"The outline of the page, at the right of the window in agent mode. `folded` holds each heading whose own headings are hidden."
@def mutable struct OutlinePane <: SemanticUI
  folded::Set{Tuple{Int,String}} = Set{Tuple{Int,String}}()
  rows::Dict{Int,Any} = Dict{Int,Any}()
  scroll::Scroll = Scroll(width(grow=grow), height(grow=grow))
end

"A line of the outline: a heading or a component of the page. `opens` is true when it has lines under it, which a click on its arrow hides."
@def mutable struct OutlineRow <: SemanticUI
  of::Any = nothing
  line::Int = 0
  caret::Int = 0
  level::Int = 1
  title::String = ""
  icon::String = ""
  depth::Int = 0
  opens::Bool = false
  folded::Bool = false
  now::Bool = false
end

"The card that the page is on in agent mode: its round corners cut off what the page shows"
@def mutable struct PageCard <: SemanticUI end

"The strip between the agent's pane and the page's card. A drag of it makes the card wider or narrower."
@def mutable struct CardEdge <: SemanticUI
  grab::px = 0px           # how far right of the card's left edge the mouse was when the drag started
  pressed::Float64 = 0.0   # when the mouse was last pressed on it, to know two clicks
end

"A button of the agent's pane: `action` is what it does, and `what` is what it does it to, like something that the agent asks for"
@def mutable struct PaneButton <: SemanticUI
  of::Any = nothing
  action::Symbol = :none
  what::Any = nothing
end

"""
The slot of the agent's pane `of`: the box that you type in, with its
buttons. It's a node so that Ladder knows where it was drawn, because the
model's button shows only while the mouse is over it. `inside` is what it
shows, which `pane_foot` makes on each frame.
"""
@def mutable struct PaneSlot <: SemanticUI
  of::Any = nothing
  inside::Any = nothing
end
describe(s::PaneSlot) = s.inside

"The agent's pane of the window of `e`. It's kept while the window is open, with its session, so leaving agent mode loses nothing."
agent_pane(e) = node!(AgentPane, e, :agent_pane)

"True while the window of `e` is in agent mode"
agent_mode(e) = get(e.nodes, :agent_mode, false) === true

"True while the window of `e` shows the agent's pane, the page's card and the outline. Something that fills the window, slides and a page shown as an app have it all."
agent_shows(e) = agent_mode(e) && lowered(e) === nothing && !as_app(e) && slideshow(e) === nothing

"How wide the outline is once it's open, or 0px while it's hidden"
outline_room(e) = e.right && right_view(e) !== nothing ? right_w(e) : 0px

"""
How wide the agent's pane is: all of the window that the page's card and the
outline leave, so a wider window gives the agent more room.
"""
agent_wide(e) = px(round(num(max(AGENT_MIN, window_size(e)[1] - outline_room(e) - page_card_wide(e) - 2PAGE_CARD_GAP))))

"""
How wide the page's card is. It has the shape of a sheet of A4 paper that
stands up, as tall as the window. A window that's too narrow for that beside
the agent's pane makes it narrower, and it's never narrower than
`PAGE_CARD_LEAST` while there's room for that. A drag of the strip at its
left edge gives it another width (see `CardEdge`). It keeps its width while
a pane slides, so the page's text doesn't wrap again on each frame.
"""
page_card_wide(e) = begin
  w, h = window_size(e)
  room = w - AGENT_MIN - outline_room(e) - 2PAGE_CARD_GAP
  px(round(num(max(min(room, something(PAGE_CARD_CHOSEN[], page_shape_wide(h))), PAGE_CARD_NARROWEST))))
end

"What the settings file says about the page's card: the width you gave it, or nothing while it has a page's shape"
page_card_setting() = (c = PAGE_CARD_CHOSEN[]; c === nothing ? "" : string(c.value))

"How wide the page's card is in a window `h` tall while it has a page's shape"
page_shape_wide(h) = max((h - 2PAGE_CARD_GAP) / √2, PAGE_CARD_LEAST)

"""
Make the page's card `wide` across, or as near to that as the window of `e`
allows, and keep the width in the settings. The agent's pane gets the rest
of the window. `nothing` gives the card a page's shape again.
"""
page_card!(e, wide) = begin
  if wide !== nothing
    room = window_size(e)[1] - AGENT_MIN - outline_room(e) - 2PAGE_CARD_GAP
    wide = px(round(num(clamp(wide, PAGE_CARD_NARROWEST, max(PAGE_CARD_NARROWEST, room)))))
  end
  wide == PAGE_CARD_CHOSEN[] && return e
  PAGE_CARD_CHOSEN[] = wide
  save_settings!(e)
  foreach(o -> redraw_in!(o, SOON), editors)   # each window in agent mode has the new width
  e
end

"""
Where the page's card is across the window: its left edge, and how wide it
is. It's beside the outline, with the agent's pane at its left. While the
outline slides out, the card goes with it to the window's edge.
"""
page_card_span(e) = begin
  w, _ = window_size(e)
  wide = page_card_wide(e)
  right = right_view(e) === nothing ? 0px : right_w(e) * right_opened(e)
  (w - right - wide - PAGE_CARD_GAP, wide)
end

"""
How round the page's card is at its left and at its right. Its left corners
are beside the agent's pane. While the outline is hidden, its right corners
are in the window's own corners, `PAGE_CARD_GAP` in from them. There they
are that much less round than the window, so the card's curve and the
window's curve have one middle, and the gap between them is as wide all the
way round. While the outline slides out, they go to the card's own radius.
A window that fills a screen has square corners, so there all four corners
have the card's own radius.
"""
page_card_round(e) = begin
  e.full_screen && return (PAGE_CARD_ROUND, PAGE_CARD_ROUND)
  shut = WINDOW_ROUND - PAGE_CARD_GAP
  open = right_view(e) === nothing ? 0.0 : right_opened(e)
  (PAGE_CARD_ROUND, shut + (PAGE_CARD_ROUND - shut) * open)
end

# The agent's pane has no narrower form and never goes: all of it stays, as the compact form of a side menu does.
# So the top bar has no button that hides it.
compact_width(p::AgentPane) = agent_wide(editor(p))

"""
The colour of the window behind the two panes of agent mode: dark, whatever
colours the page has, so that the page's card stands out. While the window
is see-through (see `see_through!`), what's behind the window shows through it.
"""
glass_colour(e) = RGBA(0.09, 0.09, 0.1, see_through(e) && !e.full_screen ? GLASS_ALPHA : 1.0)   # a window that fills a screen of its own has nothing behind it, so there the glass is solid

"""
What the window draws behind the two panes of agent mode. A window that's
see-through draws nothing there: the glass is the colour of the window
itself, which macOS draws in the window's own shape, so the glass has the
window's round corners. See `glass_window!`.
"""
glass(e) = see_through(e) ? clear : glass_colour(e)

"What lies a little lighter on the glass: behind your words, the field that you type in, and a line of the outline under the mouse"
on_glass(strength) = tint(colours.ink, strength)

# --- the colours of the two panes ---
#
# The agent's pane and the outline are dark, whatever colours the page has,
# so that the page stands out between them. Ladder draws with one set of
# colours at a time (see `use!`), and some things read it as they're
# described and others as they're drawn. So the panes' colours are in use
# while a pane is described, and again while it's drawn: a mark at the start
# of each pane turns them on as the frame is drawn, and a mark at its end
# puts the page's colours back. The two ends of the top bar, which lie over
# the panes, have them too.

"The colours of the two panes of agent mode"
const PANE_COLOURS = NIGHT
"The page's colours, kept while other colours are in use"
const PAGE_KEPT = deepcopy(SEPIA)
"The colours in use in place of the page's, like the panes' or those of the top bar over a web page, or nothing while the page's are in use"
const colours_over = Ref{Any}(nothing)
"True while the panes' colours are in use"
const pane_dark = Ref(false)

"""
Use the colours `p` in place of the page's from now on, or with nothing the
page's again. It gives the ones that were in use before, for this to put back.
"""
over_colours!(p) = begin
  was = colours_over[]
  p === was && return was
  was === nothing && foreach(n -> setfield!(PAGE_KEPT, n, getfield(colours, n)), fieldnames(Palette))
  use!(p === nothing ? PAGE_KEPT : p)
  colours_over[] = p
  pane_dark[] = p === PANE_COLOURS
  was
end

"Run `f` with the colours `p` in place of the page's, or with nothing with the page's, and then put back the ones that were in use"
with_colours(f, p) = (was = over_colours!(p); try f() finally over_colours!(was) end)

"Run `f` with the colours of the panes of agent mode, or with `on` false with the page's, and then put back the ones that were in use"
with_pane_colours(f, on::Bool=true) = with_colours(f, on ? PANE_COLOURS : nothing)

"""
A mark in what the window draws: from here on, the frame is drawn with the
colours of the panes of agent mode, or with `on` false with the page's. It's
one pixel wide and as tall as its row, or with `across` one pixel tall and as
wide as its column, so that it's drawn whenever what's beside it is.
"""
@def mutable struct PaneColours <: SemanticUI
  on::Bool = true
  across::Bool = false
end
describe(c::PaneColours) = c.across ? Box(width(grow=grow), height(1px)) : Box(fixed(1px), height(grow=grow))
draw(ctx, size, ui::ConcreteRect, c::PaneColours) = (over_colours!(c.on ? PANE_COLOURS : nothing); nothing)

"""
A mark in a row of what the window draws: from here on, the frame is drawn
with the colours `palette`, or with nothing with the page's. It's one pixel
wide and as tall as its row, as `PaneColours` is.
"""
@def mutable struct ColourMark <: SemanticUI
  palette::Any = nothing
end
describe(c::ColourMark) = Box(fixed(1px), height(grow=grow))
draw(ctx, size, ui::ConcreteRect, c::ColourMark) = (over_colours!(c.palette); nothing)

"The mark that turns the panes' colours on, or off, in a row of the window while it's in agent mode. Nothing when `dark` is false."
pane_mark(dark::Bool, on::Bool) = dark ? (PaneColours(on=on),) : ()

"""
The window in agent mode: the agent's pane, the page on its card, and the
outline, on the window's glass. The top bar lies over the top of all three.
"""
agent_body(e) = begin
  glass_window!(e)
  left, _ = page_card_span(e)
  side = side_w(e)
  Row(width(grow=grow), height(grow=grow), Alignment.Start, background(glass(e)), name="Agent mode",
    (side > 0px ? (side_part(e),) : ())...,
    Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(PAGE_CARD_GAP, 0px, PAGE_CARD_GAP, max(0px, left - side - EDGE_W)),   # top, right, bottom, left
      node!(CardEdge, e, :card_edge),
      node!(PageCard, e, :page_card)),
    right_panel(e)...)
end

# The gap between the agent's pane and the page's card is a strip that you
# drag, as the sidebar's edge is. A drag to the left gives the page more of the
# window, and one to the right gives the agent more. Two clicks give the card a
# page's shape again. A short line shows in the gap while the mouse is on it.

describe(c::CardEdge) = begin
  Box(width(EDGE_W), height(grow=grow), Alignment.Center, name="Card edge",
    (ishovered(c) ? (Box(width(3px), height(44px), radius(2px), background(RGBA(1, 1, 1, 0.32))),) : ())...)
end

cursor(::CardEdge) = :resize_x

onkey(c::CardEdge, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(c)
  twice = time() - c.pressed < 0.4
  c.pressed = twice ? 0.0 : time()
  twice && return (page_card!(e, nothing); handled)
  c.grab = ev.window.mouse[1] - page_card_span(e)[1]
  handled
end

onmouse(c::CardEdge, ev::MouseMove) = begin
  held(c, Keys.mouse_left) || return
  e = editor(c)
  left, wide = page_card_span(e)
  page_card!(e, left + wide - (ev.position[1] - c.grab))   # the card's right edge stays where it is
  handled
end

describe(c::PageCard) = begin
  e = editor(c)
  # The top of the card is under the top bar. Over a web page it has the page's colour, as the bar's middle has.
  tint = bar_tint(e)
  left, right = page_card_round(e)
  Column(fixed(page_card_wide(e)), height(grow=grow), Alignment.Start, radius(left, right, right, left), background(colours.bg), clip=true, name="Page card",
    Box(width(grow=grow), height(above_page(e) - PAGE_CARD_GAP), (tint === nothing ? () : (background(tint),))...),
    node!(Page, e, :page))
end

# A box cuts its children off at its straight edges. So what the page shows in the card's corners, like a picture
# that's as wide as the card, is painted over with the glass, and then a thin line goes round the card.
#
# The glass goes on four small squares, cut by the card's round shape. The graphics card does that cut itself. A
# path of the card's edge with its round shape as a hole took Skia 4.5 ms a frame: it drew a mask as big as the card
# with the CPU, and sent it to the graphics card, in each frame.
#
# The card's left corners and its right corners can have two radii (see `page_card_round`). Skia makes a round
# rectangle only with one radius at all four corners, and a shape made of arcs is no round rectangle to it, so it would
# cut with a mask again. So the two corners at each side have a cut of their own: the card's shape with their radius.
draw(ctx, size, ui::ConcreteRect, c::PageCard) = begin
  e = editor(c)
  x, y, w, h = num(ui.left), num(ui.top), num(ui.width), num(ui.height)
  left, right = page_card_round(e)
  paint = ink(glass(e))
  # The glass takes the place of what's there, so glass that's see-through stays see-through
  Skia.sk_paint_set_blend_mode(paint, Skia.SK_BLEND_MODE_SRC)
  for (r, cx) in ((num(left), x), (num(right), x + w - num(right)))
    card = Skia.sk_path_new()
    Skia.sk_path_add_rounded_rect(card, Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h))), Float32(r), Float32(r), Skia.SK_PATH_DIRECTION_CW)
    Skia.sk_canvas_save(ctx)
    Skia.sk_canvas_clip_path_with_operation(ctx, card, Skia.SK_CLIP_OP_DIFFERENCE, true)
    for cy in (y, y + h - r)
      Skia.sk_canvas_draw_rect(ctx, Ref(Skia.sk_rect_t(Float32(cx), Float32(cy), Float32(cx + r), Float32(cy + r))), paint)
    end
    Skia.sk_canvas_restore(ctx)
    Skia.sk_path_delete(card)
  end
  Skia.sk_paint_delete(paint)
  edge = box_path(ui.left + 0.5px, ui.top + 0.5px, ui.width - 1px, ui.height - 1px, left, right, right, left)
  line = ink(on_glass(dark_page() ? 0.16 : 0.12), 1.0)
  Skia.sk_canvas_draw_path(ctx, edge, line)
  Skia.sk_paint_delete(line)
  Skia.sk_path_delete(edge)
end

# --- a window that you see through ---
#
# With `GLASS_ALPHA` under 1, the window of agent mode is see-through behind
# the two panes, like a pane of frosted glass: what's behind the window
# shows, blurred, and only the page's card is solid. At 1, as it is now, the
# window is solid. A window that isn't on the screen, in a test, is always solid.

const GLASS_ALPHA = 1.0    # how much of the glass's own colour shows. At 1 the window is solid. Under 1 it's see-through behind the panes.
const GLASS_BLUR = 30      # how far what's behind the window is blurred, in px

"True while the window of `e` is see-through behind its panes"
see_through(e) = get(e.nodes, :see_through, false) === true

const SURFACE_OPACITY = 236   # the number that AppKit has for how solid what OpenGL draws is: NSOpenGLContextParameterSurfaceOpacity

"""
Make the window `w` of `e` see-through where it draws a colour that isn't
solid, with what's behind it blurred, or with `on` false make it solid
again. The window draws with OpenGL, so both the window and what OpenGL
draws are told. A window that isn't on the screen stays solid.
"""
see_through!(e, w, on::Bool) = begin
  e.nodes[:see_through] = false
  (Sys.isapple() && w !== nothing && !isempty(w.glfw)) || return nothing
  try
    win = nswindow(w)
    context = ccall((:glfwGetNSGLContext, GLFW.libglfw), Ptr{Cvoid}, (GLFW.Window,), w.glfw[1])
    context == C_NULL && return nothing
    with_pool() do
      solid = Ref{Cint}(on ? 0 : 1)
      ccall((:objc_msgSend, libobjc), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cint}, Cint), context, sel("setValues:forParameter:"), solid, SURFACE_OPACITY)
      send(win, "setOpaque:", !on)
      on || msg(win, "setBackgroundColor:", msg(cls("NSColor"), "windowBackgroundColor"))
      blur_behind!(win, on ? GLASS_BLUR : 0)
      msg(win, "invalidateShadow")
    end
    e.nodes[:see_through] = on
    delete!(e.nodes, :glass_set)
    on && glass_window!(e)
  catch err
    @warn "Ladder couldn't make the window see-through" exception=(err, catch_backtrace())
  end
  nothing
end

"""
Give the window of `e` the glass's colour for its own colour, while it's
see-through. The colour changes with the theme, and it's solid while the
window fills a screen of its own, so each frame of agent mode asks.
"""
glass_window!(e) = begin
  see_through(e) || return nothing
  c = glass_colour(e)
  get(e.nodes, :glass_set, nothing) == c && return nothing
  w = window_of(e)
  (w === nothing || isempty(w.glfw)) && return nothing
  with_pool() do
    colour = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble),
                   cls("NSColor"), sel("colorWithSRGBRed:green:blue:alpha:"), c.r, c.g, c.b, c.alpha)
    msg(nswindow(w), "setBackgroundColor:", colour)
  end
  e.nodes[:glass_set] = c
  nothing
end

"""
Blur what's behind the NSWindow `win` by `radius` px, where the window is
see-through. macOS has no public way to do it for a window that OpenGL draws,
so this asks its window server, as terminals with a blurred background do.
It's true when the window server took it.
"""
blur_behind!(win, radius::Integer) = begin
  lib = Base.Libc.Libdl.dlopen_e("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight")
  lib == C_NULL && return false
  server = Base.Libc.Libdl.dlsym_e(lib, :SLSMainConnectionID)
  blur = Base.Libc.Libdl.dlsym_e(lib, :SLSSetWindowBackgroundBlurRadius)
  (server == C_NULL || blur == C_NULL) && return false
  number = ccall((:objc_msgSend, libobjc), Clong, (Ptr{Cvoid}, Ptr{Cvoid}), win, sel("windowNumber"))
  ccall(blur, Cint, (Cint, Cint, Cint), ccall(server, Cint, ()), number, radius) == 0
end
