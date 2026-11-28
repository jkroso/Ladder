# The panel at the right of the window, which a page of some kinds shows

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "github.com/jkroso/UI.jl/Interface/window" fills_screen
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
@use "./additions" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./agent/window" exports...
@use "./editing" exports...

export MAC_BUTTONS_W, RIGHT_W, cleared, clearing, mac_buttons_room, right_part, right_slid,
       right_sliding, screen_tick!, RightSlide, toggle_right!

# --- the panel at the right ---------------------------------------------------------------
#
# A page of a kind that has one shows a panel at the right of the window, as
# the page of a repository shows what git says beside the repository's files:
# see `page_side`. The button at the right end of the top bar hides the panel,
# and shows it again. It slides as the sidebar does. Whether it shows is a
# setting: each window shows it or none does, and so does the next window.

const RIGHT_W = 340px   # how wide the panel at the right is, in a window that has room for it

"What a window keeps of the panel at its right, between frames"
@def mutable struct RightSlide
  slid::Tuple{Float64,Float64} = (1.0, 0.0)   # how far open the panel was when it last started to slide, from 0 to 1, and when that was
end

"When the panel at the right last started to slide in or out, and how far open it was then, from 0 to 1"
right_slid(e) = state_of(e, RightSlide).slid

"How far the panel at the right is open, from 0 to 1"
right_opened(e) = ((from, at) = right_slid(e); eased(from, e.right ? 1.0 : 0.0, at))

right_sliding(e) = time() - right_slid(e)[2] < SLIDE_TIME

"Show or hide the panel at the right of the page, like git's panel beside a repository's files. Each window does the same."
toggle_right!(e) = (state_of(e, RightSlide).slid = (right_opened(e), time()); e.right = !e.right; save_settings!(e); e)
add_command!(toggle_right!, name=:right_panel, title="Show or hide the panel at the right of the page, like git's panel beside a repository's files")

# The button at the right end of the top bar that shows the panel and hides it
BUTTONS[:right_panel] = (run=toggle_right!, tip=e -> (e.right ? "Hide " : "Show ") * (agent_shows(e) ? "the outline" : side_name(e, page_object(e))),
                         off=e -> false, strong=false, on=e -> e.right)

"How wide the panel at the right is when it's open. A narrow window makes it narrower, so the page keeps room beside it."
right_w(e) = begin
  w, _ = window_size(e)
  # The outline of agent mode is narrower than a panel, and a narrow window makes it narrower still
  agent_shows(e) && return px(round(num(min(OUTLINE_W, w * 0.22))))
  left = lowered(e) === nothing ? side_w(e) : 0px
  px(round(num(clamp((w - left) * 0.4, 200px, RIGHT_W))))
end

"""
What the panel at the right shows for the page, or nothing when the page has
no panel: see `page_side`. In agent mode it's the page's outline, for a page
that shows a thing that has an outline, even an empty one: see
`page_outline`. A page of another kind, like a design, has none, so the card
has the room.
"""
right_view(e) = begin
  (filled(e) || as_app(e) || nofile(e)) && return nothing
  agent_shows(e) && return page_outline(e) === nothing ? nothing : node!(OutlinePane, e, :outline_pane)
  o = page_object(e)
  o === nothing ? nothing : page_side(e, o)
end

"""
The panel at the right of the window, while the page has one. It keeps its
width as it slides in and out from the right edge, so only its left part
shows while it's partly out.
"""
right_panel(e) = begin
  shows = right_opened(e)
  shows > 0 || return ()
  own = right_view(e)
  own === nothing && return ()
  right_sliding(e) && redraw_in!(e, 0)
  wide = right_w(e)
  # In agent mode the window's glass shows behind the outline, as it does behind the agent's pane
  glassy = agent_shows(e)
  (Row(fixed(wide * shows), height(grow=grow), Alignment.Start, clip=true,
     Column(fixed(wide), height(grow=grow), Alignment.Start, background(glassy ? clear : colours.panel), name="Side",
            border(glassy ? 0px : 1px, :solid, colours.line)[:left],
       Box(width(grow=grow), height(max(above_page(e), SIDE_GAP))),   # under the top bar
       own)),)
end

"What the button that hides the panel at the right calls the panel of `o`"
side_name(e, o) = "the panel"

"The button at the right end of the top bar that hides the panel at the right and shows it, while the page has a panel"
right_part(e) = right_view(e) === nothing ? () : (button(e, :right_panel, "layout-sidebar-reverse"),)

"""
Notice when the window starts or stops filling a screen of its own, as the
green button makes it do. macOS hides the close, minimise and zoom buttons
then, so the buttons of the top bar slide left into their room. They slide
back when the window leaves full screen.
"""
screen_tick!(e) = begin
  w = window_of(e)
  # A window that isn't on the screen can't fill one. Its setting stays as it is, so a test can set it.
  (w === nothing || isempty(w.glfw)) && return
  on = fills_screen(w)
  on == e.full_screen && return
  e.screened_from = cleared(e)
  e.screened = time()
  e.full_screen = on
end

clearing(e) = time() - e.screened < SLIDE_TIME

"How far the buttons of the top bar have slid into the room of the close, minimise and zoom buttons, from 0 to 1"
cleared(e) = eased(e.screened_from, e.full_screen ? 1.0 : 0.0, e.screened)

const MAC_BUTTONS_W = 84px   # the room at the left of the top bar for the close, minimise and zoom buttons

"""
The room that the top bar leaves at its left for the close, minimise and zoom
buttons. In full screen they're hidden, and it leaves 8px, as it does after
the arrows at the right.
"""
mac_buttons_room(e) = MAC_BUTTONS_W - (MAC_BUTTONS_W - 8px) * cleared(e)
