# A top bar that hides until the mouse is at the top of the window

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in! close_popup! popups sync_mouse!
@use "github.com/jkroso/UI.jl/Interface/window" fade_window_buttons!
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
@use "./agent/window" exports...
@use "./top_bar" exports...
@use "./editing" exports...
@use "./tabs" exports...
@use "./title_path" exports...

export BAR_BELOW, BAR_EDGE, BAR_HIDINGS, BAR_STAYS, BAR_WAIT, bar_out, bar_slid, bar_wanted,
       hiding_named, slide_bar!

# --- a top bar that hides -------------------------------------------------------------------
#
# The top bar can hide as macOS can hide its menu bar: always, or only while
# the window fills a screen of its own. The page then runs up to the top edge
# of the window. Rest the mouse at that edge
# and the bar slides down over the page, with the Mac's close, minimise and
# zoom buttons. It slides back up a moment after the mouse leaves it, unless a
# list or a menu of the bar is open. ⌘F and a rename of the file bring it out
# too, since what they show hangs from the bar.

const BAR_EDGE = 10px    # how near the top of the window the mouse brings out a top bar that hides
const BAR_WAIT = 0.15    # seconds the mouse rests there first, so a mouse on its way out of the window doesn't bring it out
const BAR_STAYS = 0.3    # seconds the bar stays after the mouse leaves it
const BAR_BELOW = 6px    # how far under the bar the mouse can go before the bar hides
"When the top bar can hide, and the settings page's name for each: always, only while the window fills a screen of its own, or never. macOS gives its menu bar the same choices."
const BAR_HIDINGS = [:always => "Always", :full_screen => "In full screen only", :never => "Never"]

"The settings page's name for `how` the top bar hides"
hiding_name(how) = something(get(Dict(BAR_HIDINGS), how, nothing), "Never")

"How the top bar hides, from its name on the settings page"
hiding_named(name) = (i = findfirst(p -> last(p) == name, BAR_HIDINGS); i === nothing ? :never : first(BAR_HIDINGS[i]))

"""
Hide the top bar until the mouse is at the top of the window: `:always`,
`:full_screen` while the window fills a screen of its own, or `:never`. Each
window does the same.
"""
hide_bar!(e, how::Symbol) = (how in first.(BAR_HIDINGS) && (e.hide_bar = how); save_settings!(e); rerun!(e, :hide_bar); e)

"True when the top bar hides now: always, or while the window fills a screen of its own"
hides_bar(e) = e.hide_bar == :always || (e.hide_bar == :full_screen && e.full_screen)

"How much room the top bar keeps at the top of the window, over the page. A bar that hides keeps none: it shows over the page."
above_page(e) = (hides_bar(e) ? 0px : TOPBAR_H) + (agent_shows(e) ? PAGE_CARD_GAP : 0px)   # in agent mode, the page's card starts a little under the window's top

"When the top bar that hides last started to slide in or out, and how much of it showed then, from 0 to 1"
bar_slid(e) = get(e.nodes, :bar_slid, (1.0, 0.0))

"True when the top bar that hides is out, or sliding out. A new window's bar starts out, and goes when the mouse isn't on it."
bar_out(e) = get(e.nodes, :bar_out, true)

"How much of the top bar shows, from 0 to 1. A bar that doesn't hide always shows."
bar_shown(e) = hides_bar(e) ? ((from, at) = bar_slid(e); eased(from, bar_out(e) ? 1.0 : 0.0, at)) : 1.0

bar_sliding(e) = hides_bar(e) && time() - bar_slid(e)[2] < SLIDE_TIME

"Where the top bar's top is: 0 while the bar shows, and as far above the window as the bar is tall while it hides"
bar_top(e) = px(round(num((bar_shown(e) - 1) * TOPBAR_H)))

"How far down the window the top bar reaches now"
bar_bottom(e) = TOPBAR_H + bar_top(e)

"Start the top bar sliding down into the window, or with `out` false, back up out of it"
slide_bar!(e, out::Bool) = begin
  bar_out(e) == out && return e
  e.nodes[:bar_slid] = (bar_shown(e), time())
  e.nodes[:bar_out] = out
  e
end

"""
Bring out the top bar that hides, or put it away, as the mouse and what's open
ask. The Mac's close, minimise and zoom buttons go with it, and so does a path
pinned in it.
"""
bar_tick!(e) = begin
  w = window_of(e)
  w === nothing && return
  hides_bar(e) || return (fade_window_buttons!(w, 1); nothing)
  if bar_wanted(e, w)
    delete!(e.nodes, :bar_leaving)
    slide_bar!(e, true)
  elseif bar_out(e)
    since = get!(e.nodes, :bar_leaving, time())
    if time() - since >= BAR_STAYS
      delete!(e.nodes, :bar_leaving)
      slide_bar!(e, false)
    else
      redraw_in!(e, BAR_STAYS - (time() - since))
    end
  end
  shown = bar_shown(e)
  fade_window_buttons!(w, shown)
  # A path pinned in the bar shows only with the bar. It opens again once the bar shows: see `title_trail!`.
  shown == 0 && close_popup!(w, :title_trail)
  nothing
end

"""
True when the top bar that hides should show: the mouse has rested at the top
edge of the window, or is still on the bar, or something hangs from the bar.
"""
bar_wanted(e, w) = begin
  # The search that ⌘F opens hangs under the path in the bar, and the file's name is renamed where the bar shows it
  search_asked(e) && return true
  any(p -> p.key == TS_KEY, popups(w)) && return true
  !isempty(e.buf.path) && renaming(e, :title) == e.buf.path && return true
  wide, _ = window_size(e)
  inside(x, y) = 0px <= x < wide && 0px <= y
  if bar_out(e)
    # A list, a menu or a tip that hangs from the bar keeps it. The path pinned in the bar doesn't: it shows whenever the bar does.
    any(p -> p.key != :title_trail && p.anchor[2] < TOPBAR_H, popups(w)) && return true
    # A window hears nothing when the mouse leaves it, so the bar looks where the mouse is for itself
    isempty(w.glfw) || sync_mouse!(w)
    x, y = w.mouse
    on = inside(x, y) && y < TOPBAR_H + BAR_BELOW
    on && !isempty(w.glfw) && redraw_in!(e, 0.2)
    return on
  end
  # A drag that reaches the top of the window, like one that selects lines, doesn't bring the bar out
  at_edge() = begin
    x, y = w.mouse
    inside(x, y) && y < BAR_EDGE && !(Keys.mouse_left in w.keys)
  end
  at_edge() || return (delete!(e.nodes, :bar_rest); false)
  since = get!(e.nodes, :bar_rest, time())
  time() - since < BAR_WAIT && return (redraw_in!(e, BAR_WAIT - (time() - since)); false)
  # The mouse may have gone on out of the window
  isempty(w.glfw) || sync_mouse!(w)
  delete!(e.nodes, :bar_rest)
  at_edge()
end

"""
What the top bar that hides lies on, so the page doesn't show through it: the
colours of the sidebar, the page and the panel at the right, as a bar that
doesn't hide has under it, with a line along its bottom.
"""
bar_back(e) = begin
  tint = bar_tint(e)
  hides = hides_bar(e)
  (hides || tint !== nothing) || return ()
  inpage = crumb_in_page(e)
  if agent_shows(e)
    # Under a bar that doesn't hide is the top of the page's card, which has the web page's colour: see `describe(c::PageCard)`.
    # Over a page that shows the path itself the bar has no middle, so it lies only on the agent's pane.
    (hides && !inpage) || return ()
    # In agent mode only the page's card has a colour of its own, so the bar lies on that
    left, wide = page_card_span(e)
    paper, rule = tint === nothing ? (colours.bg, colours.line) : (tint, tint_colours!(tint).line)
    return (Row(width(grow=grow), height(TOPBAR_H), Alignment.Start, offset_y=bar_top(e), padding(0px, 0px, 0px, left),
              Box(fixed(wide), height(grow=grow), background(paper), border(1px, :solid, rule)[:bottom])),)
  end
  full = filled(e)
  # A side menu that a kind of folder made has no colour of Ladder's over its top
  side = full || lowered(e) !== nothing || as_app(e) || own_side_menu(e) ? 0px : side_w(e)
  right = full || right_view(e) === nothing ? 0px : right_w(e) * right_opened(e)
  line = border(1px, :solid, colours.line)
  # Over a web page the part beside the sidebar has the page's colour. A bar that doesn't hide has no line under it
  # there, so it and the page are one piece. The sidebar and a panel at the right are under a bar that doesn't hide.
  if !hides
    return (Row(width(grow=grow), height(TOPBAR_H), Alignment.Start, offset_y=bar_top(e),
              Box(fixed(side), height(grow=grow)), Box(width(grow=grow), height(grow=grow), background(tint)), Box(fixed(right), height(grow=grow))),)
  end
  # Over a page that shows the path itself the bar is only its left end: over the sidebar, and as far past it as its buttons reach
  inpage && return (Row(fixed(side_w(e) + bar_space(e).past_side), height(TOPBAR_H), Alignment.Start, offset_y=bar_top(e),
                        background(colours.bg), line[:bottom],
                      (side > 0px ? (Box(fixed(side), height(grow=grow), background(colours.panel), line[:right]),) : ())...),)
  middle = tint === nothing ? () : (background(tint), border(1px, :solid, tint_colours!(tint).line)[:bottom])
  (Row(width(grow=grow), height(TOPBAR_H), Alignment.Start, offset_y=bar_top(e), background(colours.bg), line[:bottom],
     (side > 0px ? (Box(fixed(side), height(grow=grow), background(colours.panel), line[:right]),) : ())...,
     Box(width(grow=grow), height(grow=grow), middle...),
     (right > 0px ? (Box(fixed(right), height(grow=grow), background(colours.panel), line[:left]),) : ())...),)
end
