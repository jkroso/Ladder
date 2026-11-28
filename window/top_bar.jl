# The top bar: its buttons, its lock and its dot, and its colour over a web page

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" describe window_of focus
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon icon_cache
@use "github.com/jkroso/UI.jl/Interface/Semantic/SVG" SVGPath
@use "../code/highlight" tokens left_open
@use "../blocks/sheet" parts
@use "../web/browser" => Browsers
@use Colors: @colorant_str, RGBA
@use "../base" exports...
@use "./fill_view" filled
@use "../blocks/sketch_view" exports...
@use "../files/webpage_view" exports...
@use "../folders/blog_page" exports...
@use "../code/run_code" exports...
@use "../agent/window" exports...
@use "../agent/page" exports...
@use "./showed_before" exports...
@use "./markdown_app" exports...
@use "../page/editing" toggle_panel!

export DOT_GAP, DOT_W, LOCK_SHAPES, LOCK_W, TINT_COLOURS, TIP_CODE, Tipped, bar_inks, blended,
       how_light, lock_icon, lock_part, page_actions, panel_w, shows_lock, side!, tint_colours!,
       tip_rect, waiting_dot, widest_panel, BarTint

# --- the top bar over a web page ------------------------------------------------------------------
#
# Over a page of HTML the top bar takes the page's colour, as a browser's bar
# does: the colour that the page's `<meta name="theme-color">` says, or else
# the one colour along the top edge of what shows, so it changes as the page
# scrolls past a header. So the bar and the page are one piece. The bar's
# buttons and the file's name have the ink of a theme that shows on that
# colour: the window's own when they show, dark on a light page and light on a
# dark one when they don't. The part of the bar over the sidebar, and over a
# panel at the right, keeps the window's colours. A page with no one colour
# along its top, like one with a picture there, leaves the bar as it was.

"The colour that a window's top bar last took from a web page, kept between frames"
@def mutable struct BarTint
  tint::Union{Nothing,Tuple} = nothing   # the web page that the bar last took its colour from, how far it was scrolled, and the colour
end

"""
The colour of the web page that the window shows, which the top bar takes, or
nothing: before the page shows, for a page with no one colour at its top, for
an HTML file shown as its text, and for any other file. In agent mode the
page lies on a card, and the top of the card and the middle of the bar over
it take the colour.
"""
bar_tint(e) = begin
  (html_shown(e) && !filled(e) && !page_covered(e)) || return nothing
  v = get(e.nodes, (:html, e.buf.path), nothing)
  (v isa HTMLPage && v.browser !== nothing) || return nothing
  b = v.browser
  p, s = b.view.page, Browsers.scrolled(b)
  p === nothing && return nothing
  # The bar asks more than once in each frame, so the colour is kept until the page is laid out again or scrolls
  bar = state_of(e, BarTint)
  was = bar.tint
  was !== nothing && was[1] === p && was[2] == s && return was[3]
  c = Browsers.tint(b)
  tint = c === nothing ? nothing : RGBA(((c >> 16) & 0xff) / 255, ((c >> 8) & 0xff) / 255, (c & 0xff) / 255, 1.0)
  bar.tint = (p, s, tint)
  tint
end

"How light the colour `c` looks, from 0 for black to 1 for white"
how_light(c) = (k = convert(RGBA{Float64}, c); 0.2126k.r + 0.7152k.g + 0.0722k.b)

"The colour `share` of the way from `a` to `b`"
blended(a, b, share) = begin
  x, y = convert(RGBA{Float64}, a), convert(RGBA{Float64}, b)
  RGBA(x.r + (y.r - x.r) * share, x.g + (y.g - x.g) * share, x.b + (y.b - x.b) * share, 1.0)
end

"The colours of the top bar over a web page: see `tint_colours!`"
const TINT_COLOURS = deepcopy(SEPIA)

"""
The colours of the top bar over a web page of the colour `c`. They're the
window's own when its ink shows on `c`, else those of the light or the dark
theme. `c` is behind them, and a button under the mouse or turned on is a
little darker than `c` on a light page and lighter on a dark one.
"""
tint_colours!(c) = begin
  own = colours_over[] === nothing ? colours : PAGE_KEPT
  dark = how_light(c) < 0.5
  base = (how_light(own.bg) < 0.5) == dark ? own : dark ? NIGHT : PAPER
  base === TINT_COLOURS || foreach(n -> setfield!(TINT_COLOURS, n, getfield(base, n)), fieldnames(Palette))
  TINT_COLOURS.bg = c
  TINT_COLOURS.panel = blended(c, base.ink, 0.04)
  TINT_COLOURS.hover = blended(c, base.ink, 0.08)
  TINT_COLOURS.active = blended(c, base.ink, 0.13)
  TINT_COLOURS.line = blended(c, base.ink, 0.15)
  TINT_COLOURS
end

"""
The colours of the top bar's three parts, its left end, its middle and its
right end: each a Palette, or nothing for the page's own. In agent mode the
two ends lie over the dark panes, and the middle over the page's card. Over a
web page the bar has the page's colours, but where an end lies over the
sidebar or a panel at the right.
"""
bar_inks(e) = begin
  tint = bar_tint(e)
  p = tint === nothing ? nothing : tint_colours!(tint)
  agent_shows(e) && return (PANE_COLOURS, p, PANE_COLOURS)
  p === nothing && return (nothing, nothing, nothing)
  (side_w(e) > 0px ? nothing : p, p, right_view(e) !== nothing && right_opened(e) > 0 ? nothing : p)
end

"""
The most of the window's width that the sidebar can have, so the page keeps
room beside it. In agent mode, the agent's pane and the page's card keep
their least widths beside it too.
"""
widest_panel(e) = begin
  wide = window_size(e)[1]
  most = min(PANEL_MAX, px(floor(num(wide) / 2)))
  agent_shows(e) && (most = min(most, wide - AGENT_MIN - PAGE_CARD_NARROWEST - outline_room(e) - 2PAGE_CARD_GAP))
  max(PANEL_MIN, most)
end

"How wide the sidebar is when it's open. A narrow window makes it narrower than you dragged it."
panel_w(e) = min(e.side, widest_panel(e))

"Make the sidebar `w` pixels wide, or as near to that as it can be, and keep the width in the settings"
side!(e, w) = begin
  w = px(round(num(clamp(w, PANEL_MIN, widest_panel(e)))))
  w == e.side && return e
  e.side = w
  save_settings!(e)
  e
end

ismouse(k) = k in (Keys.mouse_left, Keys.mouse_right, Keys.mouse_middle, Keys.mouse_back, Keys.mouse_forward)

# --- the top bar ------------------------------------------------------------------------

describe(b::ToolButton) = begin
  e = editor(b)
  ishovered(b) || (b.quiet = false)
  on = (b.action == :panel && e.panel) || (b.action == :marks && marking(e)) || (b.action == :hidden && e.hidden) ||
       (haskey(BUTTONS, b.action) && get(BUTTONS[b.action], :on, _ -> false)(e))
  # A button whose work takes a while, like a commit while the agent writes its message, spins until it's done
  busy = haskey(BUTTONS, b.action) && get(BUTTONS[b.action], :busy, _ -> false)(e)
  # A half button, like each chevron beside the diff button, is half as tall as the others, with one over the other, and narrow
  half = haskey(BUTTONS, b.action) && get(BUTTONS[b.action], :half, false) !== false
  box = Box(width(half ? 18px : 30px), height(half ? 14px : 28px), radius(half ? 4px : 6px), Alignment.Center, name="Button",
            background(on ? colours.active : ishovered(b) && !off(b) ? colours.hover : clear),
          busy ? Spinner(size=15px) :
          Icon(b.icon, size=half ? 9px : 15px, color=off(b) ? colours.faint : haskey(BUTTONS, b.action) && BUTTONS[b.action].strong ? colours.accent : colours.dim))
  # While the sidebar is closed, a dot beside its button says that an agent waits for a page that isn't showing
  (b.action == :panel && waiting_dot(e)) || return box
  Row(Alignment.Center, child_gap=DOT_GAP, box, Box(width(DOT_W), height(DOT_W), radius(DOT_W / 2), background(colours.accent)))
end

const DOT_W = 7px     # how wide the dot beside the sidebar's button is
const DOT_GAP = 4px   # the room between the button and its dot

"True when the sidebar's button has a dot beside it: the sidebar is closed, and an agent waits for a page that isn't showing"
waiting_dot(e) = !e.panel && !isempty(elsewhere(e))

cursor(b::ToolButton) = off(b) ? :arrow : :hand

onkey(b::ToolButton, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(b)
  b.action == :panel && toggle_panel!(e)
  b.action == :outside && open_outside!(e)
  b.action == :marks && toggle_marks!(e)
  b.action == :hidden && hidden!(e, !e.hidden)
  b.action == :back && go_back!(e)
  b.action == :forward && go_forward!(e)
  b.action == :job && make_job!(e)
  b.action in BLOG_ACTIONS && blog_act!(e, b.action)
  haskey(BUTTONS, b.action) && BUTTONS[b.action].run(e)
  hush!(b)
  # A button that opened the palette, like Commit's, leaves the keyboard in it
  e.popup == :commands || focus(e)
end

# Each button in the top bar says what it does while the mouse is over it. A
# click hides what it says until the mouse leaves the button.

const Tipped = Union{ToolButton,SendButton,Mode,CheckCount,ReadOnly}
# The colours of code in a tooltip. A tooltip is dark grey in each theme, so
# they're the night theme's, with comments lighter so that they can be read.
const TIP_CODE = (comment=colorant"rgb(150,150,156)", string=NIGHT.string, number=NIGHT.number,
                  keyword=NIGHT.keyword, call=NIGHT.call, type=NIGHT.type, added=NIGHT.added, removed=NIGHT.removed)

"""
Lines of code in a tooltip, each a row `high` tall, with the colours that code
has in the page. `lang` is the code's language, like julia: text that isn't
code is all `TIP_INK`. The lines inside three quotes, like the middle of a
docstring, are all the colour of a string. `open` is the quote of one that's
open at the first line, as `string_opens` gives it, or '\\0'.
"""
tip_code(lines, lang="julia"; high=17px, open='\0') = begin
  face(kind) = Face(codefont(), kind == :comment ? codeslant() : codestyle(), 12px,
                    kind == :plain ? TIP_INK : getfield(TIP_CODE, kind), false)
  rows = Any[]
  for line in lines
    parts = tokens(line, lang, open)
    open = left_open(line, lang, open)
    push!(rows, Box(height(high), Row(Alignment.Start, [p for t in parts if !isempty(t.text) for p in spared(t.text, face(t.kind))]...)))
  end
  rows
end

"What the tooltip of a button in the top bar says"
tip(b::ToolButton) = begin
  e = editor(b)
  if b.action == :panel
    e.panel && return "Hide sidebar" * hint(e, :sidebar)
    ws = elsewhere(e)
    # The dot beside the button is for the first of these
    isempty(ws) && return "Show sidebar" * hint(e, :sidebar)
    return "$(uppercasefirst(first(ws).name)) waits for $(basename(first(ws).page))  ·  Show sidebar" * hint(e, :sidebar)
  end
  b.action == :marks && return marking(e) ? "Hide $(whose(e)) changes" : "Show $(whose(e)) changes"
  b.action == :hidden && return (e.hidden ? "Leave out hidden and ignored files" : "Show hidden and ignored files") * hint(e, :hidden_files)
  if b.action == :back
    to = step_words(e)
    return to === nothing ? "No file to go back to" : "Back to $to" * hint(e, :back)
  elseif b.action == :forward
    to = step_words(e, e.ahead)
    return to === nothing ? "No file to go forward to" : "Forward to $to" * hint(e, :forward)
  end
  b.action == :job && return job_tip(e)
  b.action in BLOG_ACTIONS && return blog_tip(e, b.action)
  haskey(BUTTONS, b.action) && return BUTTONS[b.action].tip(e)
  b.action == :outside || return ""
  "Open in $(app_name(opener(e.buf.path)))"
end
tip(s::SendButton) = begin
  e = editor(s)
  ws = agents(e)
  isempty(ws) ? "Nudged $(page_agents(e).last)" : "Nudge $(first(ws).name) with what you changed" * hint(e, :run)
end

tip(::ReadOnly) = "Read only"

const LOCK_W = 26px   # how wide the lock is in the top bar

# UI.jl's lock is 10 wide and 14 tall, so in the top bar it looked stretched. This one is 11 wide and 13 tall, in a
# square 16 wide: a body with round corners, and a shackle over it. Each line is 1 wide, as in UI.jl's icons.
const LOCK_SHAPES = ("M4.5 7H11.5A2 2 0 0 1 13.5 9V12.5A2 2 0 0 1 11.5 14.5H4.5A2 2 0 0 1 2.5 12.5V9A2 2 0 0 1 4.5 7ZM4.5 8A1 1 0 0 0 3.5 9V12.5A1 1 0 0 0 4.5 13.5H11.5A1 1 0 0 0 12.5 12.5V9A1 1 0 0 0 11.5 8Z",
                     "M4.5 7V5A3.5 3.5 0 0 1 11.5 5V7H10.5V5A2.5 2.5 0 0 0 5.5 5V7Z")

"The name of the lock's icon. Its shapes go among UI.jl's icons the first time that it's asked for, as the snake's do."
lock_icon() = begin
  kept = get(icon_cache, "ladder-lock", nothing)
  (kept === nothing || [p.d for p in kept.paths] != collect(LOCK_SHAPES)) &&
    (icon_cache["ladder-lock"] = (paths=[SVGPath(d=LOCK_SHAPES[1], evenodd=true), SVGPath(d=LOCK_SHAPES[2])], viewbox=(0f0, 0f0, 16f0, 16f0)))
  "ladder-lock"
end

describe(::ReadOnly) = Box(width(LOCK_W), height(28px), Alignment.Center, Icon(lock_icon(), size=15px, color=colours.dim))

"The lock in the top bar of `e`"
lock_part(e) = node!(() -> ReadOnly(), e, :read_only)

"""
True when the top bar has a lock while the page shows `o`, a file or a folder
that's only shown: nothing can be typed in it. A kind of folder whose own page
takes changes its own way, as a company's books take a new invoice, has a
method of this that says false.
"""
shows_lock(e, o) = true

"""
What the right end of the top bar has for the page of `o`, a file or a folder
that's shown its own way: nodes, like a button for what the page is for. A
kind of folder has a method of this, as a company's books have New invoice.
"""
page_actions(e, o) = ()

draw(ctx, size, ui::ConcreteRect, b::Tipped) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::Tipped, ev::MouseMove) = begin
  b.quiet && return
  show_tooltip!(ev.window, tip_label(tip(b)), tip_rect(b)...,
                placement=:bottom, gap=6px)
end

"What a button's tooltip points at: the button itself, or the upper half button and the one under it, so the tooltip doesn't cover the lower one"
tip_rect(b::Tipped) = b.rect
tip_rect(b::ToolButton) = haskey(BUTTONS, b.action) && get(BUTTONS[b.action], :half, false) == :top ?
                          (b.rect[1], b.rect[2], b.rect[3], 2b.rect[4]) : b.rect

hush!(b::Tipped) = (b.quiet = true; hide_tooltip!(window_of(b)))
