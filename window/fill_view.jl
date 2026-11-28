# A picture, a diagram or a page that fills the window
#
# While the mouse is over a picture, a diagram, a page of a PDF file, a model or
# a video, a button shows beside its top right corner, so it covers none of it.
# The button makes it fill the window, over the page and under the top bar.
# Esc, or the button with a cross, puts the page back where it was.
#
#   - A picture, a diagram and a page of a PDF file fit the window at first.
#     Pinch, or scroll with ⌘ held, to make one bigger or smaller round the
#     mouse. ⌘+, ⌘- and the buttons under it do the same, and ⌘0 fits it to
#     the window again. Drag it, or scroll, to move it.
#   - A pinch outwards on a picture, a diagram or a page in the page makes it
#     fill the window too.
#   - ← and → go to the page before and the next page of a PDF file. The page
#     that shows in the document goes on from the page you looked at.
#   - A model and a video only fill the window. A model turns and zooms there
#     as it does in the page, and a video plays on.
#   - A diagram of a `mermaid` block can be changed while it fills the window.
#     A click selects a box, a line or another part of it, and two clicks let
#     you type its words where they are. A drag moves the diagram, as before.
#     The first buttons under it are the tools for the part that's selected,
#     or for the whole diagram: add a box, draw a line to the box that's
#     clicked next, change a shape, take the part away. ⌫ takes it away too.
#     Each change is written in the lines of the block, and ⌘Z takes it back.
#     With a part selected, Esc selects nothing, and the next Esc puts the
#     page back.
#
# A diagram is drawn again at each size, so it's sharp however big it is, and so
# is a page of a PDF file once it stops moving. A picture is as sharp as its pixels.

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI GeometricUI with_theme describe detach! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! show_menu! redraw_in! rect MouseScroll Pinch onpinch with_clip with_round_clip
@use "github.com/jkroso/UI.jl/Interface/image" image_source has_image
@use "github.com/jkroso/UI.jl/Interface/window" fills_screen fill_screen!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/STLViewer" STLViewer
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" VideoPlayer pause! controls_show
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" Mermaid
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" => Diagrams
@use "github.com/jkroso/UI.jl/Interface/media" picture_size
@use "./pictures" natural pdf_pages pdf_page pdf_size
@use "./sheet" parts
@use "./spreadsheet" moved
@use "./web/browser" => Browsers
@use "./cad/view" => Designs
@use Colors: RGBA
@use "./base" exports...
@use "./math_view" exports...
@use "./takeoff_view" exports...

export ZOOM_EDGE, BAR_ROOM, MODEL_FOOT, MOST_ZOOM, PAGE_COMMANDS, ZoomView, ZoomArea, Fillable,
       FillButton, button_what, FILL_GAP, zooming, same_what, fills, fill_spot, video_of,
       buttons_tall, scrolls_with_page, fill_rect, fill_over, button_above, fill_window!, zoom_in!,
       screening, screen!, screen_video!, zoom_out!, zoom_tick!, diagram_code, diagram_block,
       changing, refit!, write_diagram!, zoom_over, BAR_NEAR, bar_near, diagram_buttons, use_tool!,
       lay_diagram!, subject_size, zoom_edge, bar_room, view_middle, reframe!, fit_now!, zoom_by!,
       zoom_ink, pdf_ink, picture_spot, let_go!, zoom_key!, FillState, zoom_view, pinch_open,
       video_wide, fill_what, fill_wide, zoomed_node, held_room, square_button, filled

const ZOOM_EDGE = 24.0   # px of room round a picture that fits the window
const BAR_ROOM = 64px    # the bottom of the window, where the bar of buttons is
const MODEL_FOOT = 34px  # how tall the line under a model is, which says what the model is
const MOST_ZOOM = 8.0    # the biggest a picture gets: this many times its own size, or the size that fits the window if that's bigger
"The commands that do what they always do while a picture fills the window. The rest would change the page under it."
const PAGE_COMMANDS = (:save, :open, :open_project, :print, :close, :settings, :sidebar, :sidebar_keys)

"What fills the window, over the page"
@def mutable struct ZoomView <: SemanticUI
  what::Any = nothing                       # (:picture, key), (:diagram, code), (:pdf, path, page) or (:node, node). Nothing while the page shows.
  path::String = ""                         # the document it was opened from. It closes when another document shows.
  from::Any = nothing                       # the node of the page that it was opened from
  page::Int = 1                             # of a PDF file
  pages::Int = 1
  zoom::Float64 = 0.0                       # px of the window to a px of the picture at its own size. 0 fits it to the window.
  at::Tuple{Float64,Float64} = (0.0, 0.0)   # the point of the picture at the view's top left
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the view is in the window: its left, top, width and height
  fits::Bool = true                         # it shows the whole picture, so it fits the window again when the window changes size
  grab::Any = nothing                       # where a drag started, and the point of the picture that was at the view's top left then
  moved::Float64 = 0.0                      # when the view last moved
  sharp::Sharp = Sharp(nothing, C_NULL, 1.0)
  drawn::Any = nothing                      # a diagram laid out at its own size, with what it was laid out for
  home::Any = nothing                       # how tall a model or a video was in the page
  held::px = 0px                            # the room that a model or a video took in the page, which the page keeps for it
  pinned::px = 0px                          # how far the page was scrolled
  block::Int = 0                            # which `mermaid` block of the page its diagram is, so that it can be changed. 0 for a diagram that can't.
  tool::Any = nothing                       # the tool of its diagram that waits for a click, whose button is lit
  parts::Dict{Any,Any} = Dict{Any,Any}()    # its buttons and its area, kept between frames
  screen::Bool = false                      # its video fills the screen: the window is full screen, and the video is all that it shows
  was_full::Bool = false                    # the window filled its screen before the video did, so it stays so after
  screen_at::Float64 = 0.0                  # when the video began to fill the screen
  bare::Bool = false                        # it's the page of a file itself: it has no room round it and nothing closes it. See `file_zoom`.
  read::Float64 = -1.0                      # when the file of such a page had last changed, the last time it was looked at
end

"The part of a ZoomView that shows the picture. It takes the mouse and the keys."
@def mutable struct ZoomArea <: SemanticUI
  of::Any = nothing
end

"""
A picture, a diagram, a page, a model or a video in the page that can fill the
window. It's a node of its own so that the window knows where it is, to put
its button beside it.
"""
@def mutable struct Fillable <: SemanticUI
  what::Any = nothing      # what fills the window. See ZoomView.
  content::Any = nothing   # what shows in the page
  sizing::Any = ()         # how wide it is
  button::Any = nothing       # its FillButton, once it has shown
  transcript::Any = nothing   # a video's TranscriptButton, once it has shown
  also::Any = nothing         # what fills the window too, for a `view` block: its first button fills the window with this, and its second goes to its file
  expand::Any = nothing       # the FillButton for `also`, once it has shown
end

"What a window keeps of what fills it, and of the pictures of its page that can"
@def mutable struct FillState
  zoom::Union{Nothing,ZoomView} = nothing                 # what fills the window, over the page, or nothing until something first does
  fills::Dict{UInt,Fillable} = Dict{UInt,Fillable}()      # the Fillable of each node of the page that shows one, by the node
  laid_scroll::Union{Nothing,px} = nothing                # the scroll of the page that the last layout used, or nothing before the page is first drawn
  at::Union{Nothing,Tuple{Fillable,Any}} = nothing        # the picture that has the buttons beside it in this frame, and where it is
end

"The ZoomView of the window of `e`, which shows what fills the window. It's made the first time that it's asked for."
zoom_view(e) = (s = state_of(e, FillState); s.zoom === nothing && (s.zoom = own!(e, ZoomView())); s.zoom)

"The button beside the top right corner of a Fillable that makes it fill the window"
@def mutable struct FillButton <: SemanticUI
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip under it
  quiet::Bool = false                         # clicked, so no tooltip until the mouse leaves it
  also::Bool = false                          # it's for its Fillable's `also`, not for its `what`
end

"What the button `b` does: what it makes fill the window, or `(:go, path)` for the file that it goes to"
button_what(b::FillButton) = b.also ? b.parent.also : b.parent.what

const FILL_GAP = 4px     # between that button and the picture, and between it and the window's edge

"""
A small square button with a line round it and the icon `icon`, like the one
that makes a picture fill the window. `lit` while the mouse is over it, or
while what it opens is open.
"""
square_button(icon, lit) =
  Box(width(FILL_SIDE), height(FILL_SIDE), radius(6px), Alignment.Center, justify=Alignment.Center, name="Button",
      background(lit ? colours.hover : colours.float), border(1px, :solid, colours.line),
    Icon(icon, size=12px, color=colours.dim))

"The ZoomView of `e` while it fills the window, or nothing"
zooming(e) = (v = state_of(e, FillState).zoom; v === nothing || v.what === nothing ? nothing : v)

"True when `a` and `b` say the same thing fills the window. A node is the same node, not one like it."
same_what(a, b) = a !== nothing && b !== nothing && a[1] == b[1] && (a[1] == :node ? a[2] === b[2] : a == b)

"True when `node`, a model or a video, fills the window now"
zoomed_node(e, node) = (v = zooming(e); v !== nothing && v.what[1] == :node && v.what[2] === node)

"The empty room that the page keeps for the model or the video that fills the window"
held_room(e) = Box(width(grow=grow), height(zooming(e).held))

"What fills the window when you click the button over `x`, a node that a live block made, or nothing if it has no button"
fill_what(x) = x isa Mermaid ? (isdiagram(x.code) ? (:diagram, x.code) : nothing) : x isa Union{STLViewer,VideoPlayer} ? (:node, x) : nothing

"How wide `x` is at most in the page, for the button over its top right corner: a width, or :grow when it's as wide as the page"
fill_wide(x) = x isa VideoPlayer ? video_wide(x) : x isa Mermaid && x.made !== nothing && hasproperty(x.made[2], :w) ? px(x.made[2].w) : :grow

"How wide the picture of a video is at most: as wide as a picture of its height is, as VideoPlayer works it out"
video_wide(p::VideoPlayer) = begin
  s = p.media === nothing ? (0.0, 0.0) : picture_size(p.media)
  s[1] > 0 && s[2] > 0 ? max(240px, p.height * s[1] / s[2]) : :grow
end

"The Fillable of each node of the page that shows one, by the node"
fills(e) = state_of(e, FillState).fills

"""
`content`, which `owner` shows, as a Fillable: while the mouse is over it, a
button beside it makes `what` fill the window. `wide` is how wide the content
is at most: a width, :grow for content that's as wide as the room it's given,
or nothing for content of a fixed size. A model or a video that fills the
window now leaves its room empty.
"""
fillable(owner, what, content; wide=nothing) = begin
  e = editor(owner)
  what[1] == :node && zoomed_node(e, what[2]) && return held_room(e)
  f = get!(() -> own!(owner, Fillable()), fills(e), objectid(owner))
  f.what, f.content, f.also = what, content, nothing
  f.sizing = wide === nothing ? () : wide === :grow ? (width(grow=grow),) : (width(grow=grow, max=wide),)
  f
end

describe(f::Fillable) = Box(f.sizing..., Alignment.Start, f.content isa GeometricUI ? detach!(f.content) : f.content)

"""
Where the button of a picture that's at `r` in the window goes: beside its top
right corner, so it covers none of the picture. Where the window has no room
there, it's beside the top left corner, and where there's room on neither
side, it's in the top right corner. It stays under the top bar.
"""
fill_spot(e, r) = begin
  w, _ = window_size(e)
  top = min(max(r.top, above_page(e) + FILL_GAP), r.top + r.height - FILL_SIDE)
  right = r.left + r.width + FILL_GAP
  right + FILL_SIDE <= w - FILL_GAP && return (right, top)
  left = r.left - FILL_GAP - FILL_SIDE
  left >= side_w(e) + FILL_GAP && return (left, top)
  (right - 2FILL_GAP - FILL_SIDE, top + FILL_GAP)
end

"The video player that `f` shows, or nothing when it shows something else"
video_of(f::Fillable) = f.what !== nothing && f.what[1] == :node && f.what[2] isa VideoPlayer ? f.what[2] : nothing

"How tall the buttons beside `f` are: a video has the button that shows what was said in it under the first"
buttons_tall(f::Fillable) = video_of(f) === nothing && f.also === nothing ? FILL_SIDE : 2FILL_SIDE + FILL_GAP

# The buttons beside a picture are put in place before the frame's layout, so
# `rect` gives where the last frame put the picture. A scroll of the page since
# then moves the picture as far, so the buttons move with it in the same frame.
# Anything else that moved the picture, like a block above it that grew, puts
# the buttons right on the next frame, which comes at once.

"The scroll of the page that the last layout used, which the draw of the page keeps"
draw(ctx, size, ui::ConcreteRect, p::Page) = begin
  e = editor(p)
  state_of(e, FillState).laid_scroll = e.scroll.offset
  nothing
end

"True when `node` is a part of the page of `e`, so it moves when the page scrolls"
scrolls_with_page(e, node) = begin
  doc = get(e.nodes, :document, nothing)
  while node isa SemanticUI && !(node isa Editor)
    node === doc && return true
    node = getfield(node, :parent)
  end
  false
end

"Where `f` is in the window in this frame: where the last layout put it, moved as far as the page has scrolled since"
fill_rect(e, f::Fillable) = begin
  r = rect(f)
  r === nothing && return nothing
  moved = something(state_of(e, FillState).laid_scroll, e.scroll.offset) - e.scroll.offset
  (moved == 0px || !scrolls_with_page(e, f)) && return r
  (left=r.left, top=r.top + moved, width=r.width, height=r.height)
end

"The picture that has the buttons beside it draws again at once when it isn't where they were put for it"
draw(ctx, size, ui::ConcreteRect, f::Fillable) = begin
  at = state_of(editor(f), FillState).at
  (at === nothing || at[1] !== f) && return
  r = at[2]
  abs(num(ui.left - r.left)) + abs(num(ui.top - r.top)) + abs(num(ui.width - r.width)) + abs(num(ui.height - r.height)) > 0.5 &&
    redraw_in!(f, 0)
  nothing
end

"""
The button that makes the picture under the mouse fill the window, beside it.
A video has a button under that one, which shows what was said in the video.
They show while the mouse is over the picture or the buttons, or between them,
and while the drop-down of what was said is open.
"""
fill_over(e) = begin
  state_of(e, FillState).at = nothing
  (zooming(e) === nothing && full_block(e) === nothing && e.popup == :none) || return ()
  win = window_of(e)
  win === nothing && return ()
  x, y = num(win.mouse[1]), num(win.mouse[2])
  # A picture under a path is in a live block that can fill the window too, so the smallest one under the mouse has the button
  best, spot, least, at = nothing, nothing, Inf, nothing
  for f in values(fills(e))
    r = fill_rect(e, f)
    (r === nothing || button_above(f)) && continue
    s = fill_spot(e, r)
    if f.transcript !== nothing && f.transcript.open
      best, spot, at = f, s, r
      break
    end
    num(min(r.left, s[1])) <= x < num(max(r.left + r.width, s[1] + FILL_SIDE)) || continue
    num(min(r.top, s[2])) <= y < num(max(r.top + r.height, s[2] + buttons_tall(f))) || continue
    area = num(r.width) * num(r.height)
    area < least && ((best, spot, least, at) = (f, s, area, r))
  end
  state_of(e, FillState).at = best === nothing ? nothing : (best, at)
  best === nothing && return ()
  b = best.button === nothing ? (best.button = own!(best, FillButton())) : best.button
  buttons = Any[b]
  # A `view` block has two: the first makes what it shows fill the window, and the second goes to its file
  if best.also !== nothing
    best.expand === nothing && (best.expand = own!(best, FillButton(also=true)))
    pushfirst!(buttons, best.expand)
  end
  if video_of(best) !== nothing
    best.transcript === nothing && (best.transcript = own!(best, TranscriptButton()))
    push!(buttons, best.transcript)
  end
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(spot[2], 0px, 0px, spot[1]),
     Column(Alignment.Start, child_gap=FILL_GAP, buttons...)),)
end

"""
True when a part that holds the Fillable `f`, like a `view` block, has a
button of its own beside it that stands for all that's in it. Then `f` shows
no button.
"""
button_above(f::Fillable) = begin
  n = f.parent === nothing ? nothing : f.parent.parent
  while n !== nothing
    own_button(n) && return true
    n = hasproperty(n, :parent) ? n.parent : nothing
  end
  false
end

"True when the node `n` has a button beside it that stands for all that's in it. A `view` block's goes to its file."
own_button(n) = false

# A `view` block has a button that goes to its file, `(:go, path)`. The rest make what they show fill the window.
describe(b::FillButton) = begin
  ishovered(b) || (b.quiet = false)
  square_button(button_what(b)[1] == :go ? "arrow-up-right" : "arrows-fullscreen", ishovered(b))
end

cursor(::FillButton) = :hand
draw(ctx, size, ui::ConcreteRect, b::FillButton) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::FillButton, ev::MouseMove) = begin
  b.quiet && return handled
  what = button_what(b)
  tip = what[1] == :go ? "Go to " * view_name(what[2]) : what[1] == :node ? "Fill the window" : "Fill the window  pinch"
  # The tooltip of one of two buttons goes beside it, so that it doesn't cover the other button
  show_tooltip!(ev.window, tip_label(tip), b.rect...,
                placement=video_of(b.parent) === nothing && b.parent.also === nothing ? :bottom : :right, gap=6px)
  handled
end

onkey(b::FillButton, ev::KeyPress{Keys.mouse_left}) = begin
  b.quiet = true
  hide_tooltip!(ev.window)
  f = b.parent
  fill_window!(editor(b), button_what(b), f.parent)
end

"""
Make `what`, which a Fillable of the node `from` shows, fill the window. A
block like a sketch, `(:block, view)`, fills it by itself. The rest fill the
ZoomView. A `view` block's `(:go, path)` goes to its file instead.
"""
fill_window!(e, what, from) = what[1] == :block ? full!(what[2], true) : what[1] == :go ? go_view!(from) : zoom_in!(e, what, from)

"A pinch outwards on a picture, a diagram, a page or a sketch in the page makes it fill the window"
pinch_open(owner, ev::Pinch) = begin
  ev.scale > 1 || return nothing
  e = editor(owner)
  f = get(fills(e), objectid(owner), nothing)
  (f === nothing || f.what === nothing || f.what[1] in (:node, :go)) && return nothing
  # Only when the fingers are on the picture, not beside it
  r = rect(f)
  x, y = num(ev.window.mouse[1]), num(ev.window.mouse[2])
  (r !== nothing && num(r.left) <= x < num(r.left + r.width) && num(r.top) <= y < num(r.top + r.height)) || return nothing
  fill_window!(e, f.what, owner)
end

onpinch(s::Shown, ev::Pinch) = pinch_open(s, ev)
onpinch(p::Pages, ev::Pinch) = pinch_open(p, ev)
onpinch(v::FileView, ev::Pinch) = pinch_open(v, ev)
onpinch(l::Breadcrumb, ev::Pinch) = pinch_open(l, ev)

"Make `what` fill the window. `from` is the node of the page that shows it."
zoom_in!(e, what, from=nothing) = begin
  v = zoom_view(e)
  # A pinch goes on to the page until the next frame is drawn, so it would open it again
  same_what(v.what, what) && return handled
  zoom_out!(v, false)
  v.what, v.path, v.from, v.pinned = what, e.buf.path, from, e.scroll.offset
  v.zoom, v.fits, v.grab, v.drawn = 0.0, true, nothing, nothing
  v.block, v.tool = 0, nothing
  delete!(v.parts, :diagram)
  if what[1] == :diagram
    # The diagram of a `mermaid` block can be changed here. One that the code of a live block made has no lines of its own.
    from !== nothing && get(e.nodes, (:diagram, what[2]), nothing) === from && !readonly(e.buf) && (v.block = diagram_block(e.buf, what[2]))
  elseif what[1] == :pdf
    v.page, v.pages = what[3], max(1, pdf_pages(what[2]))
  elseif what[1] == :node
    r = rect(what[2])
    # A model fills the window with no frame, so it has that to get back too. A page of the web is sized by its block.
    v.home = what[2] isa Union{STLViewer,Designs.DesignView} ? (what[2].height, what[2].fill) : what[2] isa Browsers.Browser ? nothing : what[2].height
    v.held = r !== nothing ? r.height : what[2] isa Browsers.Browser ? what[2].high : what[2].height
  end
  # A page of the web has the keyboard, for its fields and its keys. Esc comes back from it when the page doesn't take it.
  what[1] == :node && what[2] isa Browsers.Browser ? focus(what[2]) : focus(part!(() -> ZoomArea(of=v), v, :area))
  handled
end

"True while a video fills the screen"
screening(e) = (v = zooming(e); v !== nothing && v.screen)

"""
Make the video that fills the window fill the screen, or with `on` false put
it back to filling the window. The window fills a screen of its own, as the
green button of its title bar makes it, and the video is all that it shows:
black is round the picture, and the top bar is gone. The video's controls lie
over the foot of the picture while the mouse moves. A window that filled its
screen before stays so after.
"""
screen!(v::ZoomView, on::Bool) = begin
  what = v.what
  (what !== nothing && what[1] == :node && what[2] isa VideoPlayer) || return handled
  v.screen == on && return handled
  v.screen = what[2].screen = on
  w = window_of(editor(v))
  if w !== nothing
    if on
      v.was_full = fills_screen(w)
      v.screen_at = time()
      fill_screen!(w, true)
    else
      v.was_full || fill_screen!(w, false)
    end
  end
  on && (what[2].stirred = time())   # its controls show at first
  handled
end

"Make the video `p`, which the node `from` shows in the page, fill the screen"
screen_video!(e, p::VideoPlayer, from=nothing) = (zoom_in!(e, (:node, p), from); screen!(zoom_view(e), true))

"Put the page back, with a model or a video back in it. `refocus` gives the keyboard back to the text."
zoom_out!(v::ZoomView, refocus=true) = begin
  what = v.what
  what === nothing && return handled
  v.screen && screen!(v, false)   # a video that filled the screen leaves it
  # Words that were being typed into a diagram are taken
  m = changing(v)
  m === nothing || Diagrams.settle!(m)
  v.what = nothing
  what[1] == :node && v.home !== nothing && (v.home isa Tuple ? ((what[2].height, what[2].fill) = v.home) : (what[2].height = v.home))
  # A video of a gallery shows only while it fills the window, so it stops when it leaves
  what[1] == :node && what[2] isa VideoPlayer && v.from isa GalleryView && pause!(what[2])
  v.from isa Pages && (v.from.page = v.page)   # the page in the document goes on from the page you looked at
  v.from = nothing
  e = editor(v)
  e.scroll.offset = v.pinned
  refocus && focus(e)
  handled
end

"In each frame: the page comes back when another document shows, and until then it stays where it was"
zoom_tick!(e) = begin
  v = zooming(e)
  v === nothing && return
  v.path == e.buf.path || return zoom_out!(v, false)
  e.scroll.offset = v.pinned
  # The mouse button that started a drag has come up
  w = window_of(e)
  v.grab === nothing || w === nothing || Keys.mouse_left in w.keys || let_go!(v, w)
  # A window that left its screen another way, as the green button does, has its video fill the window again.
  # macOS takes a moment to make a window fill a screen, so the first seconds don't count.
  v.screen && w !== nothing && !isempty(w.glfw) && time() - v.screen_at > 2 && !fills_screen(w) && screen!(v, false)
  m = changing(v)
  if m !== nothing && w !== nothing
    m.joining === nothing || Keys.mouse_left in w.keys || Diagrams.let_go_at!(m, picture_spot(v, w.mouse)...)
    # A box shows its point only while the mouse is over the diagram, and not over the buttons under it
    m.hovered === nothing || ishovered(part!(() -> ZoomArea(of=v), v, :area)) || Diagrams.unhover!(m)
  end
  v.what === nothing && return
  if v.what[1] == :diagram && v.block > 0
    # The diagram is what the lines of its block say now. They change under it when ⌘Z takes a change back.
    code = diagram_code(e.buf, v.block)
    (code === nothing || !isdiagram(code)) && return zoom_out!(v, false)
    code == v.what[2] || (v.what = (:diagram, code); refit!(v))
  end
  nothing
end

"The code of the `n`th `mermaid` block of `b`, or nothing when it has no such block"
diagram_code(b::Buffer, n::Int) = begin
  span = block_lines(b, DIAGRAM, n)
  span === nothing ? nothing : join(b.lines[span[1]+1:span[2]-1], "\n")
end

"Which `mermaid` block of `b` has the code `code`: the first one that does, or 0"
diagram_block(b::Buffer, code) = begin
  n = 1
  while (found = diagram_code(b, n)) !== nothing
    found == code && return n
    n += 1
  end
  0
end

"The diagram of `v` as the component that changes it, or nothing when `v` shows something else or a diagram that can't be changed"
changing(v::ZoomView) = begin
  (v.what !== nothing && v.what[1] == :diagram && v.block > 0) || return nothing
  m = get(v.parts, :diagram, nothing)
  m !== nothing && m.editing ? m : nothing
end

"A diagram that fitted the window fits it again after a change, which gives it another size"
refit!(v::ZoomView) = (v.fits && (v.zoom = 0.0); v)

"""
Write the code of the diagram that fills the window as the lines of its block.
The caret stays where it was in the text, and ⌘Z takes the change back.
"""
write_diagram!(v::ZoomView, code::String) = begin
  e = editor(v)
  b = e.buf
  span = block_lines(b, DIAGRAM, v.block)
  (span === nothing || readonly(b)) && return v
  i, t = span
  new, old = String.(split(code, '\n')), b.lines[i+1:t-1]
  if new != old
    caret, anchor = b.caret, b.anchor
    edit!(b, line_end(b, i), line_end(b, t - 1), "\n" * join(new, "\n"))
    by = length(new) - length(old)
    moved(p) = p[1] >= t ? (p[1] + by, p[2]) : p[1] > i ? (i, 0) : p
    b.caret, b.anchor = moved(caret), moved(anchor)
  end
  v.what = (:diagram, code)
  refit!(v)
end

"What fills the window, over the page and the sidebar and under the top bar"
zoom_over(e) = zooming(e) === nothing ? () :
  # A video that fills the screen has the top bar's room too, and black round it
  screening(e) ? (Box(width(grow=grow), height(grow=grow), background(RGBA(0, 0, 0, 1)), geometry(state_of(e, FillState).zoom)),) :
  (Box(width(grow=grow), height(grow=grow), padding(above_page(e), 0px, 0px, 0px), background(colours.bg), geometry(state_of(e, FillState).zoom)),)

"The button of `v` that's kept under `key`, with what it does and shows now"
button!(v::ZoomView, key, action; icon="", tip="", off=false) = begin
  on = action isa Tuple && action[1] == :tool && v.tool == action[2]
  block_button!(v, key, action; icon, tip, on, off)
end

"Do what a button of a ZoomView does"
act!(v::ZoomView, action, w) = begin
  a = action isa Tuple ? action[1] : action
  a == :tool && return use_tool!(v, action[2], w)
  a == :zoom && return zoom_by!(v, action[2], view_middle(v)...)
  a == :fit && return fit_now!(v)
  a == :page && return turn!(v, action[2])
  a == :close && return zoom_out!(v)
  a == :screen && return screen!(v, !v.screen)
  handled
end

describe(v::ZoomView) = begin
  e = editor(v)
  what = v.what
  bar(buttons...; up=0px) = Column(width(grow=grow), height(grow=grow), Alignment.Center, justify=Alignment.End, padding(0px, 0px, 16px + up, 0px),
    Row(height(36px), padding(4px), child_gap=2px, radius(8px), Alignment.Center, background(colours.float),
        border(1px, :solid, colours.line), lifted, buttons...))
  close = v.bare ? nothing : button!(v, :close, :close, icon="x-lg", tip="Back to the page  esc")
  if what[1] == :node && what[2] isa Browsers.Browser
    # A page of the web has all of the window under the top bar, as it has a browser's window. Nothing lies over it:
    # Esc puts the document back.
    b = what[2]
    w, h = window_size(e)
    b.zoom = round(Float64(e.zoom), digits=2)
    b.wide, b.high = w, max(40px, h - above_page(e))
    return Stack(width(grow=grow), height(grow=grow), Alignment.Start, b)
  elseif what[1] == :node && what[2] isa Designs.DesignView
    # A SolidCraft design that's only shown has all of the window under the top bar, as a model has. Esc puts the document back.
    node = what[2]
    node.fill = true
    shows = with_theme(() -> geometry(node), component_theme(e.zoom))
    return Stack(width(grow=grow), height(grow=grow), Alignment.Start, Box(width(grow=grow), height(grow=grow), shows))
  elseif what[1] == :node && what[2] isa STLViewer
    # A model has all of the window under the top bar too, with no frame, and nothing lies over it: Esc puts the document
    # back. Only a model of a gallery has a bar, to go to the file before it and the next one. It's above the line that
    # says what the model is, if the model has that line.
    node = what[2]
    node.fill = true
    shows = with_theme(() -> geometry(node), component_theme(e.zoom))
    steps = gallery_buttons(v, rest=100)
    return Stack(width(grow=grow), height(grow=grow), Alignment.Start, Box(width(grow=grow), height(grow=grow), shows),
      gallery_edges(v)..., (isempty(steps) ? () : (bar(steps..., close, up=node.foot ? MODEL_FOOT : 0px),))...)
  elseif what[1] == :node
    # A model or a video is as tall as the window has room for. Its own bar is under its picture.
    node = what[2]
    _, h = window_size(e)
    if v.screen
      # A video that fills the screen is as tall as the window. Its two buttons are in the top right corner, while it shows its own controls.
      node.height = h
      shows = with_theme(() -> geometry(node), component_theme(e.zoom))
      corner = controls_show(node) ?
        (Column(width(grow=grow), height(grow=grow), Alignment.End, padding(16px),
           Row(height(36px), padding(4px), child_gap=2px, radius(8px), Alignment.Center, background(colours.float), border(1px, :solid, colours.line),
               button!(v, :screen, :screen, icon="fullscreen-exit", tip="Back to the window  F"), close)),) : ()
      return Stack(width(grow=grow), height(grow=grow), Alignment.Start,
        Box(width(grow=grow), height(grow=grow), background(RGBA(0, 0, 0, 1)), shows), corner...)
    end
    node.height = max(160px, h - above_page(e) - BAR_ROOM - px(2ZOOM_EDGE) - 44px)
    shows = with_theme(() -> geometry(node), component_theme(e.zoom))
    # A video has a button that makes it fill the screen
    buttons = node isa VideoPlayer ? (button!(v, :screen, :screen, icon="arrows-fullscreen", tip="Fill the screen  F"), close) : (close,)
    # A video or a model of a gallery says where it is in the gallery, with a button to each side
    return Stack(width(grow=grow), height(grow=grow), Alignment.Start,
      Column(width(grow=grow), height(grow=grow), Alignment.Center, padding(px(ZOOM_EDGE)), shows),
      gallery_edges(v)..., bar(gallery_buttons(v, rest=60 + 40length(buttons))..., buttons...))
  end
  what[1] == :diagram && lay_diagram!(v)
  # The view is the whole window under the top bar, so it's fitted here, and the bar says how big the picture is in this frame.
  # The page of a file itself is beside the sidebar, where it was drawn last.
  w, h = window_size(e)
  place = v.bare ? rect(part!(() -> ZoomArea(of=v), v, :area)) : nothing
  v.bare || reframe!(v, (0.0, num(above_page(e)), num(w), num(h) - num(above_page(e))))
  place === nothing || reframe!(v, (num(place.left), num(place.top), num(place.width), num(place.height)))
  buttons = Any[diagram_buttons(v)..., button!(v, :smaller, (:zoom, 1 / ZOOM_STEP), icon="zoom-out", tip="Smaller  pinch, or ⌘ and scroll"),
                Box(width(46px), Alignment.Center, justify=Alignment.Center,
                    label(v.zoom > 0 ? "$(round(Int, 100v.zoom))%" : "", 12px, color=colours.dim)),
                button!(v, :bigger, (:zoom, ZOOM_STEP), icon="zoom-in", tip="Bigger  pinch, or ⌘ and scroll"),
                button!(v, :fit, :fit, icon="aspect-ratio", tip="Fit the window  ⌘0")]
  pages = what[1] == :pdf && v.pages > 1
  # A file of a gallery says where it is in the gallery, with a button to each side
  prepend!(buttons, gallery_buttons(v, rest=pages ? 450 : 281))
  if pages
    # In a gallery, ← and → go to the file before and the next one, so ↑ and ↓ turn the pages
    before, next = v.from isa GalleryView ? ("↑", "↓") : ("←", "→")
    push!(buttons, button!(v, :back, (:page, -1), icon="chevron-left", tip="The page before  $before", off=v.page <= 1),
          Box(Alignment.Center, padding(4px, 0px), label("Page $(v.page) of $(v.pages)", 12px, color=colours.dim)),
          button!(v, :on, (:page, 1), icon="chevron-right", tip="The next page  $next", off=v.page >= v.pages))
  end
  v.bare || push!(buttons, close)
  # On the page of a file itself the bar lies over the foot of the picture, so it shows only while the mouse is near it
  Stack(width(grow=grow), height(grow=grow), Alignment.Start, part!(() -> ZoomArea(of=v), v, :area), gallery_edges(v)...,
        (!v.bare || bar_near(v) ? (bar(buttons...),) : ())...)
end

const BAR_NEAR = 110.0   # px from the bottom of a file's own page within which the mouse brings its bar of buttons

"True while the mouse is over the foot of the view, where the bar of buttons is"
bar_near(v::ZoomView) = begin
  w = window_of(editor(v))
  w === nothing && return false
  x, y = num(w.mouse[1]), num(w.mouse[2])
  left, top, wide, tall = v.box
  left <= x < left + wide && top + tall - BAR_NEAR <= y < top + tall
end

describe(::ZoomArea) = Box(width(grow=grow), height(grow=grow))
# While a tool of the diagram waits for a click on a part, the mouse is a cross
# While a tool of the diagram waits for a click on a part, or a line is dragged from a box's point, the mouse is a cross
cursor(a::ZoomArea) = begin
  m = changing(a.of)
  a.of.tool !== nothing || (m !== nothing && (m.joining !== nothing || m.on_point)) ? :crosshair : :arrow
end

"""
The buttons of the tools of the diagram that fills the window, with a line
after them: the tools for the part that's selected, or for the whole diagram
while nothing is. A diagram that can't be changed has none.
"""
diagram_buttons(v::ZoomView) = begin
  m = changing(v)
  m === nothing && return ()
  # The caret in the words that are typed into the diagram blinks
  m.typing === nothing || redraw_in!(v, 0.5)
  v.tool = m.waiting
  tools = Diagrams.tools(m)
  isempty(tools) && return ()
  (Any[button!(v, (:tool, t.name), (:tool, t.name), icon=t.icon, tip=t.tip) for t in tools]...,
   Box(width(9px), height(18px), Alignment.Center, justify=Alignment.Center, Box(width(1px), height(18px), background(colours.line))))
end

"Use the tool `name` of the diagram that fills the window. A tool with choices shows them in a menu over its button first."
use_tool!(v::ZoomView, name, w) = begin
  m = changing(v)
  m === nothing && return handled
  i = findfirst(t -> t.name == name, Diagrams.tools(m))
  i === nothing && return handled
  tool = Diagrams.tools(m)[i]
  isempty(tool.choices) && return (Diagrams.use!(m, name); handled)
  b = get(v.parts, (:button, (:tool, name)), nothing)
  left, top = b === nothing ? (w.mouse[1], w.mouse[2]) : (b.rect[1], b.rect[2])
  tall = 28px * length(tool.choices) + 10px
  show_menu!(w, [first(c) for c in tool.choices], left, top - tall - 6px, 200px, theme=menu_theme(), item_height=28px, lift=3.0,
             onselect=k -> k in eachindex(tool.choices) && Diagrams.use!(m, name, last(tool.choices[k])))
  handled
end

"""
Lay the diagram of `v` out at its own size, in the page's font and colours, to
draw at any size. It's laid out again when the font or the colours change.
"""
lay_diagram!(v::ZoomView) = begin
  e = editor(v)
  code = v.what[2]
  # One component shows the diagram for as long as it fills the window, so it keeps what's selected in it
  m = part!(() -> Mermaid(code, bar=false), v, :diagram)
  m.code = code
  m.editing = v.block > 0 && !readonly(e.buf)
  m.keys = part!(() -> ZoomArea(of=v), v, :area)
  m.onchange = m -> write_diagram!(v, m.code)
  key = (code, look_key(e), e.font, e.zoom)
  v.drawn !== nothing && v.drawn[1] == key && return v.drawn[2]
  root = with_theme(component_theme(e.zoom)) do
    inner = geometry(m)
    made = m.made === nothing ? nothing : m.made[2]
    (made === nothing || !hasproperty(made, :w) || made.w <= 0) && return nothing
    describe(Column(fixed(px(made.w)), Alignment.Start, inner), (px(made.w), 99999px))
  end
  v.drawn = (key, root)
  root
end

"How wide and how tall what `v` shows is at its own size, in px, or nothing when it can't be shown"
subject_size(v::ZoomView) = begin
  what = v.what
  what === nothing && return nothing
  if what[1] == :picture
    has_image(what[2]) || return nothing
    s = image_source(what[2])
    n = natural(what[2])
    n === nothing ? (Float64(s.width), Float64(s.height)) : (Float64(n[1]), Float64(n[2]))
  elseif what[1] == :diagram
    root = v.drawn === nothing ? nothing : v.drawn[2]
    root === nothing ? nothing : (num(root.width), num(root.height))
  elseif what[1] == :pdf
    s = pdf_size(what[2], v.page)
    s === nothing ? nothing : (Float64(s[1]), Float64(s[2]))
  end
end

"How many px of room are round a picture that fits the view. The page of a file itself has none."
zoom_edge(v::ZoomView) = v.bare ? 0.0 : ZOOM_EDGE
"How many px at the bottom of the view are kept for the bar of buttons. On the page of a file itself the bar lies over the picture."
bar_room(v::ZoomView) = v.bare ? 0.0 : num(BAR_ROOM)

"The middle of the part of the view that's above the bar of buttons"
view_middle(v::ZoomView) = (v.box[1] + v.box[3] / 2, v.box[2] + (v.box[4] - bar_room(v)) / 2)

"How many px to a px of the picture fits the whole of something `s` big in the view, above the bar and with room round it"
fit_zoom(v::ZoomView, s) = max(min((v.box[3] - 2zoom_edge(v)) / s[1], (v.box[4] - bar_room(v) - 2zoom_edge(v)) / s[2]), 1e-3)

"Show the whole picture, in the middle of the view"
fit!(v::ZoomView, s) = (v.zoom = fit_zoom(v, s); v.fits = true; hold!(v, s))

"""
Keep the picture in the view. Where it's narrower than the view, it stays in
the middle, and so it does where it's shorter. Otherwise it moves no further
than its edges, with room round them.
"""
hold!(v::ZoomView, s) = begin
  w, h = v.box[3] / v.zoom, (v.box[4] - bar_room(v)) / v.zoom
  edge = zoom_edge(v) / v.zoom
  v.at = (s[1] + 2edge <= w ? (s[1] - w) / 2 : clamp(v.at[1], -edge, s[1] - w + edge),
          s[2] + 2edge <= h ? (s[2] - h) / 2 : clamp(v.at[2], -edge, s[2] - h + edge))
  v
end

"Note that the view is now `box`. A picture that fitted the old view fits the new one."
reframe!(v::ZoomView, box) = begin
  s = subject_size(v)
  changed, v.box = box != v.box, box
  s === nothing && return v
  v.zoom <= 0 || (v.fits && changed) ? fit!(v, s) : hold!(v, s)
end

"Note that the view moved just now, and keep the picture in it"
moved!(v::ZoomView, s) = begin
  v.moved = time()
  hold!(v, s)
  v.fits = v.zoom <= fit_zoom(v, s) * 1.0001
  handled
end

"Fit the picture to the window again"
fit_now!(v::ZoomView) = (s = subject_size(v); s === nothing || fit!(v, s); handled)

"Make the picture `by` times as big. The point of it at the place `(x, y)` in the window stays there."
zoom_by!(v::ZoomView, by, x, y) = begin
  s = subject_size(v)
  (s === nothing || v.zoom <= 0) && return handled
  p = (v.at[1] + (x - v.box[1]) / v.zoom, v.at[2] + (y - v.box[2]) / v.zoom)
  f = fit_zoom(v, s)
  v.zoom = clamp(v.zoom * by, min(f, 1.0), max(f, 1.0) * MOST_ZOOM)
  v.at = (p[1] - (x - v.box[1]) / v.zoom, p[2] - (y - v.box[2]) / v.zoom)
  moved!(v, s)
end

"Go on by `by` pages of a PDF file, as far as the first page or the last"
turn!(v::ZoomView, by) = begin
  page = clamp(v.page + by, 1, v.pages)
  page == v.page && return handled
  v.page, v.zoom, v.fits = page, 0.0, true
  handled
end

draw(ctx, size, ui::ConcreteRect, a::ZoomArea) = begin
  v = a.of
  v.what === nothing && return
  reframe!(v, (num(ui.left), num(ui.top), num(ui.width), num(ui.height)))
  s = subject_size(v)
  (s === nothing || v.zoom <= 0) && return
  with_clip(() -> zoom_ink(ctx, v, s), ctx, ui.left, ui.top, ui.width, ui.height)
end

"Draw what `v` shows, which is `s` big at its own size"
zoom_ink(ctx, v::ZoomView, s) = begin
  x, y = v.box[1] - v.at[1] * v.zoom, v.box[2] - v.at[2] * v.zoom
  w, h = s[1] * v.zoom, s[2] * v.zoom
  kind = v.what[1]
  if kind == :picture
    image = image_source(v.what[2])
    paint_picture(ctx, image.raw, (0, 0, image.width, image.height), (x, y, w, h))
  elseif kind == :diagram
    # The diagram is drawn at its own size onto a canvas that's made bigger, so its lines and its words stay sharp
    root = v.drawn[2]
    Skia.sk_canvas_save(ctx)
    Skia.sk_canvas_translate(ctx, Float32(x), Float32(y))
    Skia.sk_canvas_scale(ctx, Float32(v.zoom), Float32(v.zoom))
    Skia.sk_canvas_translate(ctx, -Float32(num(root.left)), -Float32(num(root.top)))
    try
      draw(ctx, root.size, root)
    finally
      Skia.sk_canvas_restore(ctx)
    end
  else
    paper = (x, y, w, h)
    paper!(ctx, paper)
    with_round_clip(() -> pdf_ink(ctx, v, paper), ctx, px(x), px(y), px(w), px(h), px(PAPER_ROUND))
  end
end

"Draw the part of a PDF page that's in the view, at the screen's own pixels. While it moves, a rougher picture of the whole page shows."
pdf_ink(ctx, v::ZoomView, paper) = begin
  left, top, wide, tall = v.box
  path = v.what[2]
  d = clamp(density(ctx), 2, 3)
  w, h = round(Int, wide * d), round(Int, tall * d)
  (w < 1 || h < 1) && return
  k = v.zoom * d   # the screen's pixels to a point of the page
  of = (path, mtime(path), v.page, k, v.at, w, h)
  p = v.sharp
  if p.of != of && p.cost > QUICK && time() - v.moved < SETTLED
    rough = pdf_page(path, v.page, 2000)
    if rough !== nothing
      r = image_source(rough)
      paint_picture(ctx, r.raw, (0, 0, r.width, r.height), paper)
    end
    redraw_in!(v, SETTLED)
    return
  end
  image = sharpen!(p, path, v.page, of, k, v.at[1] * k, v.at[2] * k, w, h)
  image == C_NULL || paint_picture(ctx, image, (0, 0, w, h), (left, top, wide, tall))
end

"The place in the picture of the diagram that's at the place `at` in the window"
picture_spot(v::ZoomView, at) = (v.at[1] + (num(at[1]) - v.box[1]) / v.zoom, v.at[2] + (num(at[2]) - v.box[2]) / v.zoom)

# A click starts a drag that moves the picture. On the point of a box of a diagram, the drag draws a line from the box.
onkey(a::ZoomArea, ev::KeyPress{Keys.mouse_left}) = begin
  w, v = ev.window, a.of
  focus(a)
  m = changing(v)
  # The point is under the mouse when it's within 8px of it on the screen, however small the diagram is drawn
  m !== nothing && v.zoom > 0 && Diagrams.press_at!(m, picture_spot(v, w.mouse)..., near=8 / v.zoom) && return handled
  v.grab = ((num(w.mouse[1]), num(w.mouse[2])), v.at)
  handled
end

# A line that's dragged from a box's point is drawn when the button comes up over another box
onkey(a::ZoomArea, ev::KeyRelease{Keys.mouse_left}) = begin
  m = changing(a.of)
  m === nothing || a.of.zoom <= 0 || Diagrams.let_go_at!(m, picture_spot(a.of, ev.window.mouse)...)
  nothing
end

"""
The mouse button came up. On a diagram that can be changed, a click that
didn't drag the diagram selects the part that it was on, or nothing. A drag
only moves the diagram, so the part that's selected stays selected.
"""
let_go!(v::ZoomView, w) = begin
  g, v.grab = v.grab, nothing
  m = changing(v)
  (g === nothing || m === nothing || v.zoom <= 0) && return v
  x, y = g[1]
  hypot(num(w.mouse[1]) - x, num(w.mouse[2]) - y) < 4 || return v
  # A line is clicked when the mouse is within 5px of it on the screen, however small the diagram is drawn
  Diagrams.pick_at!(m, v.at[1] + (x - v.box[1]) / v.zoom, v.at[2] + (y - v.box[2]) / v.zoom, near=5 / v.zoom)
  v
end

onmouse(a::ZoomArea, ev::MouseMove) = begin
  v = a.of
  m = changing(v)
  if m !== nothing && v.zoom > 0
    at = picture_spot(v, ev.position)
    if m.joining !== nothing
      Keys.mouse_left in ev.window.keys ? Diagrams.drag_to!(m, at...) : Diagrams.let_go_at!(m, at...)
      return handled
    end
    # The box under the mouse shows its point
    v.grab === nothing && Diagrams.hover_at!(m, at..., near=8 / v.zoom)
  end
  g = v.grab
  g === nothing && return handled
  Keys.mouse_left in ev.window.keys || (let_go!(v, ev.window); return handled)
  s = subject_size(v)
  (s === nothing || v.zoom <= 0) && return handled
  (x0, y0), at = g
  x, y = num(ev.position[1]), num(ev.position[2])
  v.at = (at[1] - (x - x0) / v.zoom, at[2] - (y - y0) / v.zoom)
  moved!(v, s)
end

# Scrolling with ⌘ held makes the picture bigger or smaller, round the mouse. Scrolling without ⌘ moves it.
onscroll(a::ZoomArea, ev::MouseScroll) = begin
  v, w = a.of, ev.window
  only_held(w, Keys.cmd) && return zoom_by!(v, exp(num(ev.delta[2]) / 10), num(w.mouse[1]), num(w.mouse[2]))
  s = subject_size(v)
  (s === nothing || v.zoom <= 0) && return handled
  v.at = (v.at[1] - 30num(ev.delta[1]) / v.zoom, v.at[2] - 30num(ev.delta[2]) / v.zoom)
  moved!(v, s)
end

# Two fingers that move apart or together on the trackpad make the picture bigger or smaller, round the mouse
onpinch(a::ZoomArea, ev::Pinch) = zoom_by!(a.of, ev.scale, num(ev.window.mouse[1]), num(ev.window.mouse[2]))

# The keys are the view's, so none of them change the page under it: the editor gives each key to `zoom_key!`
# when the key comes up to it. A right-click has no menu here.
onkey(a::ZoomArea, ::KeyPress{Keys.mouse_right}) = handled
ontype(::ZoomArea, ::Typed) = handled

"""
Do what the key `K` does while `v` fills the window. `command` is the command
that the key bindings give the key, or nothing. It's `handled`, or nothing for
the key of a command that the page still takes, like the one that saves. The
keys that change the size of the page's text change the size of the picture.
"""
zoom_key!(v::ZoomView, K, w, command) = begin
  m = changing(v)
  if m !== nothing
    # ⌘Z takes back the last change to the diagram, which is a change to the lines of its block
    if command in (:undo, :redo)
      Diagrams.cancel!(m)
      command == :redo ? redo!(editor(v).buf) : undo!(editor(v).buf)
      return handled
    end
    # Return types the words of the part that's selected, ⌫ takes it away and Esc selects nothing
    !unmodified(w) || !Diagrams.key!(m, K) || return handled
  end
  K == Keys.escape && unmodified(w) && return zoom_out!(v)
  command in PAGE_COMMANDS && return nothing
  # A file of a gallery: ← and → go to the file before it and the next one. A video that fills the screen keeps them.
  unmodified(w) && v.from isa GalleryView && !v.screen && K in (Keys.left, Keys.right) && return step!(v.from, K == Keys.left ? -1 : 1)
  if v.what[1] == :node && v.what[2] isa VideoPlayer && unmodified(w)
    # F makes a video fill the screen, and puts it back. The keys of the video are its own here too.
    K == Keys.f && return screen!(v, !v.screen)
    K in (Keys.space, Keys.left, Keys.right) && return onkey(v.what[2], KeyPress{K}(0, w))
  end
  v.what[1] == :node && return handled
  command == :bigger && return zoom_by!(v, ZOOM_STEP, view_middle(v)...)
  command == :smaller && return zoom_by!(v, 1 / ZOOM_STEP, view_middle(v)...)
  command == :usual_size && return fit_now!(v)
  # ← and →, or ↑ and ↓, turn the pages of a PDF file. In a gallery only ↑ and ↓ do.
  unmodified(w) && v.what[1] == :pdf && K in (Keys.left, Keys.right, Keys.up, Keys.down) && return turn!(v, K in (Keys.left, Keys.up) ? -1 : 1)
  handled
end

"""
True when something fills the window in place of the page and the sidebar: a
takeoff, a schedule or a sketch, the lines of one as text, or a picture.
"""
filled(e) = full_block(e) !== nothing || lowered(e) !== nothing || zooming(e) !== nothing
