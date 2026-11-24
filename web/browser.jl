# A web view: a window onto a page of the web, in a window that UI.jl draws.
#
#     b = Browser(address="https://julialang.org", wide=900px, high=600px)
#
# It gets the page and the files that the page names with files.jl, lays the
# page out with view.jl, and runs the page's scripts. It's `wide` by `high`,
# and the page scrolls in it.
#
#     go!(b, "julialang.org/downloads")    # show another page
#     back!(b), forward!(b), reload!(b)
#     can_back(b), can_forward(b)
#     b.shown                              # the address of the page that shows, where its site moved it to
#     b.title                              # what the page says its title is
#     loading(b)                           # true while a page is on its way
#     page_now(b)                          # the address that was asked for the page that shows, or that's on its way
#     scroll!(b, 400)                      # put the top of the window 400 px down the page
#
# In place of an address, `html` is the HTML of a page to show, and `base` is
# the address that the addresses in it are from. That page has a place among
# the pages that the view goes back to, as a `Written` page.
#
# The owner of the view can make its `address`, `html` and `base` say the
# page that the view went to, and then call `asked!(b)`. The view doesn't get
# that page again, and its pages to go back to stay.
#
# While it's `active`, the mouse and the keyboard reach the page:
#
#   - The wheel scrolls the page. So do Space, Page Up and Page Down, the up
#     and down arrows, Home and End.
#   - A click on a link goes to its page. A link to the place of a name in the
#     same page scrolls there. An address that's no page of the web, like
#     `mailto:`, is given to `open`.
#   - A click on a field for text gives it the keyboard. You type in it, move
#     the caret with the arrows, select with Shift, and ⌘A, ⌘C, ⌘X and ⌘V do
#     what they do in any field. Return sends the field's form, and Tab goes
#     to the next field. Esc takes the keyboard from the field.
#   - A click ticks a tick box and chooses a round button. A click on a list
#     of choices (a <select>) shows them in a menu.
#   - A click on a button that sends its form sends it. A form that sends with
#     "get" is an address, and the view goes there. Nothing can be sent any
#     other way.
#   - A drag over the page's words selects them, and ⌘C copies them. Two
#     clicks select a word, and three a paragraph, and a drag after them goes
#     on by words or by paragraphs. A click with ⇧ held moves the end of the
#     selection there. ⌘A selects all of the page's words. A drag above or
#     below the view scrolls the page. A drag in a field selects its letters.
#   - The page's scripts hear the mouse and the keys: `mousemove`, `mouseover`,
#     `mouseout`, `mousedown`, `mouseup`, `click`, `wheel`, `keydown`, `keyup`,
#     `input`, `change`, `focus`, `blur`, `scroll` and `submit`. A script that
#     says to do no more with a click, a key or the wheel is obeyed. A key says
#     where it is (`code`, like "KeyW"), so a game can move with W, A, S and D,
#     and ⇧, ⌃, ⌥ and ⌘ go down and up too. The middle button of the mouse
#     goes down and up for the scripts only, so a 3D view can move what it
#     shows across while the button is held.
#   - A script can have the mouse to itself (`requestPointerLock`), as a game
#     does to turn its view with the mouse. The pointer hides, and each move
#     of the mouse says only how far it went. Esc gives the pointer back, and
#     so does the view losing the keyboard, or the window going to the back.
#
# While it isn't active, it only shows the page: a click and a key go to the
# nodes above it. `idle` is the shape of the mouse over it then.
#
# `takes` says which clicks, turns of the wheel and pinches an active view
# gives the page. Its owner can keep some for itself: a view in a document
# leaves the plain wheel to the document. A pinch reaches the page's scripts
# as a browser sends it, as the wheel with Ctrl held.
#
# What it doesn't do yet: a box that's fixed in the window scrolls with the
# page. What the page's CSS says for the mouse over an element (`:hover`) or
# for the field with the keyboard (`:focus`) is left out. Text in a field
# that's longer than the field isn't scrolled into view. A selection of the
# page's words is kept as places in its words, so a script that changes the
# words before it moves it. A page's `user-select: none` is left out. And see
# what view.jl, live.jl and script.jl leave out.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl" onkey onmouse ontype onscroll KeyPress KeyRelease MouseMove Typed Keys flt
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific" ConcreteRect
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe handled window_of focus onblur
@use "github.com/jkroso/UI.jl/Interface/draw" draw cursor open_url rect redraw_in! MouseScroll Pinch onpinch clipboard clipboard! show_menu! with_clip
@use Skia
@use GLFW
@use "./main" => Web
@use "./live" => Live
@use "./form" => Forms
@use "./files" => Fetch
@use "./files" Files
@use "./entities" entities
@use "./view" View page! refresh! restart!
@use "./select" => Select
@use "./dom" Element document attr text
@use "./css" resolve

const PATIENCE = 6.0   # seconds that a page waits for its sheets and its scripts before it shows without the ones that haven't come
const SLACK = 4.0      # px that the mouse can move between going down and coming up, and still click
const STEP = 40.0      # px that an arrow key scrolls
const AGAIN = 0.25     # seconds between two layouts of a page whose files are still coming
const QUICK = 0.03     # seconds: a page whose scripts and layout take longer than this in a frame is a slow page
const SHARE = 3        # a slow page rests this many times as long as its frame took, so that the window stays yours
const LIMIT = 4.0      # seconds that a script of the page may run before it's stopped
const AGAIN_CLICK = 0.4   # seconds between two clicks at one place that make them a double click
const EDGE_SPEED = 12.0   # px a second that a drag scrolls the page for each px that the mouse is above or below the view
const EDGE_MOST = 80.0    # px above or below the view past which the drag scrolls no faster

"A page that's on its way: its address, then its HTML once that has come, and the files that it waits for before it shows"
mutable struct Coming
  address::String
  since::Float64
  html::Union{String,Nothing}
  base::String             # the address that the page ended up at
  needs::Vector{String}    # its sheets and its scripts
  failed::Bool
end

"A page that was written in place of an address: its HTML, and the address that the addresses in it are from"
struct Written
  html::String
  base::String
end

@def mutable struct Browser <: SemanticUI
  address::String = ""      # the address of the page to show. Change it, or call `go!`, to show another.
  html::String = ""         # the HTML of a page to show in place of what's at `address`
  base::String = ""         # the address that the addresses in `html` are from
  wide::px = 800px
  high::px = 600px
  zoom::Float64 = 1.0
  active::Bool = true       # the mouse and the keyboard reach the page
  idle::Symbol = :arrow     # the shape of the mouse over a page that isn't active
  takes::Any = ev -> true   # true when the page gets a click, a turn of the wheel or a pinch. One that it doesn't get goes to the nodes above.
  scripts::Bool = true      # run the page's scripts
  open::Any = open_url      # opens an address that's no page of the web, like `mailto:`
  say::Any = (level, text) -> nothing   # called with each line that a script prints
  files::Files = Files()
  view::View = View()       # the page, laid out
  trail::Vector{Any} = Any[]   # the pages that it has shown, in order: their addresses, and a `Written` page
  at::Int = 0               # which of them shows now, or is on its way
  asked::Any = nothing      # the address and the HTML that it was last asked to show
  coming::Any = nothing     # the page that's on its way, or nothing
  shown::String = ""        # the address of the page that shows, where its site moved it to
  title::String = ""        # what that page says its title is
  failed::Bool = false      # the page couldn't be had, and what shows says so
  landed::Int = 0           # how many files had come when the page was last laid out for them
  refreshed::Float64 = 0.0  # and when that was
  offset::Float64 = 0.0     # how far down the page the top of the window is, in px, for a page with no scripts
  field::Any = nothing      # the field that has the keyboard, for a page with no scripts
  caret::Int = 0            # how many characters of the field's text come before the caret
  anchor::Int = 0           # and before the other end of what's selected
  touched::Float64 = 0.0    # when a key last went down, so that the caret shows then
  down::Any = nothing       # where on the page the mouse button went down, while it's down
  rest::Float64 = 0.0       # until when a slow page's scripts and layout don't run again
  made::Any = nothing       # the size and the zoom that the page was last laid out for
  swallow::Bool = false     # a script said to do no more with the key that's down, so it types nothing
  locked::Any = nothing     # where in the window the hidden pointer is kept while a script has the mouse to itself, or nothing
  picked::Tuple{Int,Int} = (0, 0)   # the page's words that are selected: where the selection started, and where it ends, as places in the words
  grain::Int = 1                    # what a drag selects: letters, words after two clicks, paragraphs after three
  grown::Tuple{Int,Int} = (0, 0)    # what the click that started the drag selected
  clicks::Tuple{Float64,Int,Int} = (0.0, -1, 0)   # when the mouse last went down on the page's words, at which place, and how many clicks in a row that makes
  drag::Symbol = :none      # what a drag with the button down selects: the page's words (:words), the letters of the field (:field), or nothing
  dragged::Float64 = 0.0    # when a drag above or below the view last scrolled the page
end

# --- which page shows -----------------------------------------------------------------------

"True for an address that the view shows itself: a page of the web, or a file of this computer"
shows(address::AbstractString) = occursin(r"^(https?|file)://"i, address) || startswith(address, '/')

"""
The whole address that `words` mean when someone types them: `julialang.org`
is `https://julialang.org`. A path of a file of this computer is its `file://`
address, so that the addresses in its page are from its folder.
"""
whole(words::AbstractString) = begin
  t = String(strip(words))
  isempty(t) && return t
  startswith(t, '~') && (t = expanduser(t))
  startswith(t, '/') && return "file://" * replace(t, '%' => "%25", ' ' => "%20", '#' => "%23", '?' => "%3F")
  if !shows(t)
    # A name with a colon and no // is the kind of address that another app opens: mailto:jake@example.com. A port is a number.
    occursin(r"^[a-z][a-z0-9+.-]*:(?!\d)"i, t) && return t
    t = (occursin(r"^(localhost|127\.|\[::1\])"i, t) ? "http://" : "https://") * t
  end
  # The first page of a site is at /
  occursin(r"^https?://[^/?#]+$"i, t) ? t * "/" : t
end

"True while a page is on its way"
loading(b::Browser) = b.coming !== nothing

can_back(b::Browser) = b.at > 1
can_forward(b::Browser) = b.at < length(b.trail)

"""
Show the page at `address`. `julialang.org` means `https://julialang.org`. An
address that's no page, like `mailto:`, is given to `b.open`. The page that
shows stays until the new one has come.
"""
go!(b::Browser, address::AbstractString; note=true) = begin
  to = whole(address)
  isempty(to) && return b
  shows(to) || return (b.open(to); b)
  note && note!(b, to)
  b.files.held > Fetch.MOST && Fetch.forget!(b.files)
  Fetch.ask!(b.files, to)
  b.coming = Coming(to, time(), nothing, to, String[], false)
  redraw_in!(b, 0)
  b
end

"Show the `Written` page `page`"
go!(b::Browser, page::Written; note=true) = begin
  note && note!(b, page)
  b.coming = arrive!(b, Coming(page.base, time(), nothing, page.base, String[], false), page.html, page.base)
  redraw_in!(b, 0)
  b
end

"Put `page` after the page that shows, among the pages that the view goes back to. The pages that were after that one go."
note!(b::Browser, page) = begin
  resize!(b.trail, b.at)
  push!(b.trail, page)
  b.at = length(b.trail)
  b
end

"The page that shows, or that's on its way: the address that was asked for it, or a `Written` page. Nothing before the view was asked for one."
page_now(b::Browser) = 1 <= b.at <= length(b.trail) ? b.trail[b.at] : nothing

"Say that `b.address`, `b.html` and `b.base` are of the page that shows, so that the view doesn't get it again"
asked!(b::Browser) = (b.asked = (b.address, b.html, b.base); b)

"Show the page that showed before this one, or the one that showed after it"
back!(b::Browser) = can_back(b) ? go!(b, b.trail[b.at -= 1]; note=false) : b
forward!(b::Browser) = can_forward(b) ? go!(b, b.trail[b.at += 1]; note=false) : b

"Get the page that shows again, with all of its files"
reload!(b::Browser) = begin
  Fetch.forget!(b.files)
  b.at > 0 ? go!(b, b.trail[b.at]; note=false) : (b.asked = nothing; b)
end

"""
Go where the page asks to: a link that was clicked, a form that was sent, or
a script that set `location.href`. A page from the web doesn't lead to a file
of this computer, and `javascript:` leads nowhere. A link to a place in the
page that shows scrolls there.
"""
follow!(b::Browser, address::AbstractString) = begin
  to = String(strip(address))
  (isempty(to) || startswith(lowercase(to), "javascript:")) && return b
  (Fetch.path(to) !== nothing && Fetch.path(b.shown) === nothing) && return b
  i = findfirst('#', to)
  if i !== nothing && Fetch.bare(to) == Fetch.bare(b.shown)
    name = to[nextind(to, i):end]
    e = isempty(name) ? nothing : named(b, name)
    scroll!(b, e === nothing ? 0.0 : place(b, e)[2])
    return b
  end
  go!(b, to)
end

escaped(s) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")

"A page that says that the page at `address` couldn't be had, or with `drawn=false` that it came and couldn't be drawn"
sorry(address; drawn=true) = """<!DOCTYPE html><meta charset="utf-8"><title>No page</title>
  <body style="margin:0;font:15px/22px system-ui;color:#3c3c3c;background:#fafafa">
  <div style="max-width:460px;margin:22vh auto 0;padding:0 24px;text-align:center">
  <h1 style="font-size:20px;line-height:28px;margin:0 0 8px;color:#1d1d1f">$(drawn ? "This page didn't come" : "This page can't be drawn")</h1>
  <p style="margin:0 0 6px">$(drawn ? "The site didn't answer, or it has no page at this address." : "The page came, and something in it stopped the engine that draws it.")</p>
  <p style="margin:0;font-size:13px;color:#8a8a8a;overflow-wrap:anywhere">$(escaped(address))</p></div></body>"""

"The HTML that shows what came from an address: the page itself, or a page with the picture or the text that came"
page_of(got::Fetch.Got) = begin
  type = got.type
  top = isempty(type) ? lowercase(String(got.bytes[1:min(end, 512)])) : ""
  (occursin("html", type) || occursin("<html", top) || occursin("<!doctype html", top)) && return Fetch.text(got)
  startswith(type, "image/") && return """<!DOCTYPE html><meta charset="utf-8"><body style="margin:0;min-height:100vh;display:grid;place-items:center;background:#1e1e1e">
    <img src="$(escaped(got.address))" style="max-width:100%"></body>"""
  (startswith(type, "text/") || isempty(type) || occursin(r"json|javascript|xml", type)) &&
    return """<!DOCTYPE html><meta charset="utf-8"><body style="margin:12px"><pre style="margin:0;font:12px/17px ui-monospace,Menlo,monospace;white-space:pre-wrap;overflow-wrap:anywhere">$(escaped(Fetch.text(got)))</pre></body>"""
  """<!DOCTYPE html><meta charset="utf-8"><body style="margin:0;font:15px/22px system-ui;color:#3c3c3c;background:#fafafa">
    <p style="margin:22vh 24px 0;text-align:center">This address holds a file that isn't a page ($(escaped(type))).</p></body>"""
end

# What a <script> says its type is, when it's JavaScript that script.jl runs
const SCRIPT = ("", "text/javascript", "application/javascript", "text/ecmascript", "application/ecmascript", "application/x-javascript")

"The addresses of the sheets and the scripts that the page of `html` names, which it's laid out with and run with"
needs(html::AbstractString, base::AbstractString; scripts=true) = begin
  doc = document(html)
  from = isempty(doc.base) ? String(base) : resolve(base, doc.base)
  out = String[]
  visit(e) = for c in e.children
    c isa Element || continue
    if c.tag == "link" && occursin(r"(^|\s)stylesheet(\s|$)"i, attr(c, "rel")) && !isempty(strip(attr(c, "href")))
      push!(out, resolve(from, attr(c, "href")))
    elseif c.tag == "script" && scripts && !isempty(strip(attr(c, "src"))) && lowercase(strip(attr(c, "type"))) in SCRIPT
      push!(out, resolve(from, attr(c, "src")))
    end
    visit(c)
  end
  visit(doc.root)
  unique(filter(a -> !startswith(lowercase(a), "data:"), out))
end

"What the page of `html` says its title is, or \"\""
title_of(html::AbstractString) = begin
  m = match(r"<title\b[^>]*>(.*?)</title\s*>"is, html)
  m === nothing ? "" : String(strip(replace(entities(String(m[1])), r"\s+" => " ")))
end

"The HTML of the page that's on its way has come. Its sheets and its scripts are asked for."
arrive!(b::Browser, c::Coming, html, base; failed=false) = begin
  c.html, c.base, c.failed, c.since = String(html), String(base), failed, time()
  load = Fetch.loader(b.files, c.base)
  c.needs = try needs(c.html, c.base; scripts=b.scripts) catch; String[] end
  foreach(load, c.needs)
  c
end

"Show the page that was on its way, in place of the one that showed"
show!(b::Browser, c::Coming) = begin
  v = b.view
  b.coming = nothing
  v.html, v.base = c.html, c.base
  v.load = Fetch.loader(b.files, c.base)
  v.allowed = address -> Fetch.readable(b.files, address, c.base)
  restart!(v)
  b.shown, b.failed, b.title = c.base, c.failed, title_of(c.html)
  b.offset, b.field, b.caret, b.anchor, b.down = 0.0, nothing, 0, 0, nothing
  b.picked, b.drag = (0, 0), :none
  b.landed, b.refreshed = b.files.landed, time()
  b
end

"""
What happens in each frame: a page that was asked for is fetched, a page
whose HTML has come waits for its sheets and its scripts, for no longer than
`PATIENCE`, and then shows. A page that shows is laid out again when more of
its files have come.
"""
tick!(b::Browser) = begin
  want = (b.address, b.html, b.base)
  if b.asked != want
    b.asked = want
    if !isempty(b.html)
      # The page is written here. It's the first of the pages to go back to.
      empty!(b.trail)
      b.at = 0
      go!(b, Written(b.html, b.base))
    elseif !isempty(b.address)
      empty!(b.trail)
      b.at = 0
      go!(b, b.address)
    end
  end
  c = b.coming
  if c !== nothing
    if c.html === nothing
      s = Fetch.state(b.files, c.address)
      if s == :there
        got = Fetch.file(b.files, c.address)
        arrive!(b, c, try page_of(got) catch; sorry(c.address) end, got.address)
      elseif s != :coming
        arrive!(b, c, sorry(c.address), c.address; failed=true)
      end
    end
    if c.html !== nothing && (time() - c.since > PATIENCE || all(a -> Fetch.state(b.files, a) != :coming, c.needs))
      show!(b, c)
    end
  elseif b.files.landed != b.landed && time() - b.refreshed > AGAIN
    b.landed, b.refreshed = b.files.landed, time()
    refresh!(b.view)
  end
  b
end

# --- the page in the window -----------------------------------------------------------------

"The page with its scripts running, or nothing for a page with none"
live(b::Browser) = b.view.live

"How far down the page the top of the window is, in px"
scrolled(b::Browser) = (l = live(b); l === nothing ? b.offset : l.scroll * b.zoom)

"How far down the page the top of the window can be, in px"
reach(b::Browser) = b.view.page === nothing ? 0.0 : max(0.0, b.view.page.tall - Float64(flt(b.high)))

"Put the top of the window `y` px down the page, or as near that as the page goes"
scroll!(b::Browser, y) = begin
  l = live(b)
  l === nothing ? (b.offset = clamp(Float64(y), 0.0, reach(b))) : Live.scroll!(l, y / b.zoom)
  redraw_in!(b, 0)
  scrolled(b)
end

describe(b::Browser) = begin
  v = b.view
  v.parent === nothing && setfield!(v, :parent, b)
  v.go === nothing && (v.go = address -> follow!(b, address))
  tick!(b)
  v.wide, v.high, v.zoom, v.scripts, v.say, v.limit = b.wide, Float64(flt(b.high)), b.zoom, b.scripts, b.say, LIMIT
  # The page's scripts run and the page is laid out, unless it's a slow page that rests. Another page, or another size
  # of the window, doesn't wait. While the page rests, the window shows it as it was last laid out, and it still scrolls.
  # A page that has the mouse to itself never rests: it's a game that you're playing, and each frame is yours.
  want = (v.html, v.base, v.wide, v.high, v.zoom, v.scripts)
  if v.page === nothing || b.made != want || time() >= b.rest || b.locked !== nothing
    b.made = want
    began = time()
    try
      page!(v)
    catch err
      # A page that can't be laid out says so, and the view goes on
      b.say(:error, sprint(showerror, err))
      v.html, v.scripts, b.failed = sorry(b.shown; drawn=false), false, true
      restart!(v)
      page!(v)
    end
    took = time() - began
    b.rest = took > QUICK ? time() + SHARE * took : 0.0
  else
    redraw_in!(b, max(0.0, b.rest - time()))
  end
  b.offset = clamp(b.offset, 0.0, reach(b))
  lock!(b)
  edge_scroll!(b)
  (loading(b) || Fetch.coming(b.files) > 0 || b.files.landed != b.landed) && redraw_in!(b, 0.05)
  # The caret blinks, so the window has to draw again while a field has the keyboard
  field(b) !== nothing && focused(b) && redraw_in!(b, 0.5)
  Box(width(b.wide), height(b.high), background("white"))
end

"Fill a rectangle of the canvas with a colour, with round corners when `round` is more than 0"
patch(ctx, x, y, w, h, colour::UInt32; round=0.0) = begin
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, round > 0)
  Skia.sk_paint_set_color(paint, colour)
  r = Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h)))
  round > 0 ? Skia.sk_canvas_draw_round_rect(ctx, r, Float32(round), Float32(round), paint) : Skia.sk_canvas_draw_rect(ctx, r, paint)
  Skia.sk_paint_delete(paint)
end

const SELECTED = 0x4d4285f4   # the colour over the text that's selected in a field, and over the page's words that are selected
const ASIDE = 0x33808080      # and over the page's words that are selected while the view doesn't have the keyboard
const THUMB = 0x59000000      # the bar at the right that says where the window is in the page
const COMING = 0xff2a78d6     # the line at the top while a page is on its way

draw(ctx, size, ui::ConcreteRect, b::Browser) = begin
  p = b.view.page
  p === nothing && return
  s = scrolled(b)
  left, top, wide, high = Float64(flt(ui.left)), Float64(flt(ui.top)), Float64(flt(ui.width)), Float64(flt(ui.height))
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    Web.draw(ctx, p; x=left, y=top - s, top=s, bottom=s + high)
    # The page's words that are selected, in grey while the keyboard is elsewhere, as a browser shows them. A view that
    # only shows the page shows no selection.
    colour = focused(b) ? SELECTED : ASIDE
    if b.active
      for (x, y, across, tall) in Select.marks(p.words, selection(b)...)
        s - tall <= y <= s + high && patch(ctx, left + x, top - s + y, across, tall, colour)
      end
    end
    e = field(b)
    if e !== nothing && focused(b)
      stops = caret_stops(b, e)
      lo, hi = extrema((clamp(b.caret, 0, length(stops) - 1), clamp(b.anchor, 0, length(stops) - 1)))
      # Each character that's selected is marked from the place before it to the place after it
      for k in lo:hi-1
        (x0, y0, tall), (x1, y1, _) = stops[k+1], stops[k+2]
        y0 == y1 && x1 > x0 && patch(ctx, left + x0, top - s + y0, x1 - x0, tall, SELECTED)
      end
      if lo == hi && (time() - b.touched < 0.5 || mod(time() - b.touched - 0.5, 1.0) < 0.5)
        x, y, tall = stops[lo+1]
        patch(ctx, left + x - 0.75, top - s + y, 1.5, tall, ink(b, e))
      end
    end
    # The bar that says where the window is in the page shows while the page can be scrolled
    far = reach(b)
    if far > 0 && b.active
      long = max(24.0, high * high / p.tall)
      patch(ctx, left + wide - 7, top + 2 + (high - long - 4) * s / far, 5, long, THUMB; round=2.5)
    end
    if loading(b)
      # The line grows fast at first and then slowly, since nothing says how much of the page has come
      patch(ctx, left, top, wide * (1 - exp(-(time() - b.coming.since + 0.15) / 1.5)), 2, COMING)
    end
  end
end

"The point of the page that the mouse is over, or that's at the point `at` of the window, in px of the page as it's drawn, or nothing"
point(b::Browser, at=nothing) = begin
  w = window_of(b)
  (w === nothing || b.view.page === nothing) && return nothing
  r = rect(b)
  r === nothing && return nothing
  at = something(at, w.mouse)
  (Float64(flt(at[1] - r.left)), Float64(flt(at[2] - r.top)) + scrolled(b))
end

"The element at the point `(x, y)` of the page, or nothing. Of the boxes there, it's the one that the page has last."
element(b::Browser, x, y) = begin
  p = b.view.page
  z = p.zoom
  places = p.list.places
  i = findlast(q -> q.left <= x / z < q.left + q.wide && q.top <= y / z < q.top + q.tall, places)
  i === nothing ? nothing : places[i].element
end

"Where the box of the element `e` is on the page: its left, its top, its width and its height in px, or nothing for an element with no box"
place(b::Browser, e::Element) = begin
  p = b.view.page
  i = findfirst(q -> q.element === e, p.list.places)
  i === nothing ? nothing : (q = p.list.places[i]; (q.left, q.top, q.wide, q.tall) .* p.zoom)
end

"The element of the page that a link to `#name` leads to: the one with that `id`, or the <a> with that `name`"
named(b::Browser, name::AbstractString) = begin
  p = b.view.page
  i = findfirst(q -> attr(q.element, "id") == name || (q.element.tag == "a" && attr(q.element, "name") == name), p.list.places)
  i === nothing ? nothing : p.list.places[i].element
end

# --- the page's words that are selected -----------------------------------------------------

"The page's words, with where each letter is drawn, or none while no page shows"
page_words(b::Browser) = (p = b.view.page; p === nothing ? () : p.words)

"The two ends of the page's words that are selected, as places in the words, first the one nearer the top. They're the same when none are."
selection(b::Browser) = (n = Select.letter_count(page_words(b)); extrema(clamp.(b.picked, 0, n)))

"The page's words that are selected, as they're copied"
selected_words(b::Browser) = Select.copied(page_words(b), selection(b)...)

"""
The mouse went down at the point `(x, y)` of the page, on no field. One click
puts the start of the selection there, two select the word there, and three
its paragraph. With `shift`, the end of the selection moves there.
"""
pick!(b::Browser, x, y, shift) = begin
  ws = page_words(b)
  at = Select.place(ws, x, y)
  t, before, n = b.clicks
  n = time() - t < AGAIN_CLICK && before == at ? n % 3 + 1 : 1
  b.clicks = (time(), at, n)
  b.grain = shift ? 1 : n
  b.grown = b.grain == 2 ? Select.word(ws, at) : b.grain == 3 ? Select.paragraph(ws, at) : shift ? (b.picked[1], b.picked[1]) : (at, at)
  b.drag = :words
  stretch!(b, at)
end

"""
Select the page's words from where the click that started the drag selected
them to the place `at`. After two clicks, the drag selects whole words, and
after three, whole paragraphs.
"""
stretch!(b::Browser, at) = begin
  ws = page_words(b)
  lo, hi = b.grown
  from, to = b.grain == 2 ? Select.word(ws, at) : b.grain == 3 ? Select.paragraph(ws, at) : (at, at)
  b.picked = at < lo ? (hi, from) : (lo, max(hi, to))
  redraw_in!(b, 0)
  b
end

"The mouse is at the point `(x, y)` of the page with its button down: the drag selects what it has gone over"
drag!(b::Browser, x, y) = begin
  if b.drag == :words
    stretch!(b, Select.place(page_words(b), x, y))
  elseif b.drag == :field
    e = field(b)
    e === nothing || caret!(b, e, index_at(b, e, x, y), true)
  end
  b
end

"""
While a drag selects and the mouse is above or below the view, the page
scrolls that way, faster the further the mouse is, and the drag selects what
comes into view. A drag whose button came up where the view didn't hear it
ends here.
"""
edge_scroll!(b::Browser) = begin
  b.drag == :none && return b
  w, r = window_of(b), rect(b)
  (w === nothing || r === nothing) && return b
  if !(Keys.mouse_left in w.keys)
    b.drag, b.down = :none, nothing
    return b
  end
  y, high = Float64(flt(w.mouse[2] - r.top)), Float64(flt(r.height))
  off = y < 0 ? max(y, -EDGE_MOST) : y > high ? min(y - high, EDGE_MOST) : 0.0
  now = time()
  took, b.dragged = clamp(now - b.dragged, 0.0, 0.1), now
  off == 0 && return b
  scroll!(b, scrolled(b) + off * EDGE_SPEED * took)
  at = point(b)
  at === nothing || drag!(b, at...)
  redraw_in!(b, 1 / 60)
  b
end

"Select all of the page's words"
select_all!(b::Browser) = (b.picked = (0, Select.letter_count(page_words(b))); redraw_in!(b, 0); b)

"Copy the page's words that are selected to the clipboard. It's false when none are."
copy_words!(b::Browser, w) = begin
  words = selected_words(b)
  isempty(words) ? false : (clipboard!(w, words); true)
end

# --- the field that has the keyboard --------------------------------------------------------

"True when the keys of the window go to the view"
focused(b::Browser) = (w = window_of(b); w !== nothing && w.focus === b)

"The field for text that has the keyboard, or nothing"
field(b::Browser) = begin
  l = live(b)
  e = l === nothing ? b.field : l.focused
  e isa Element && Forms.typed(e) && e.parent !== nothing ? e : nothing
end

"Give the keyboard to the field `e`, or take it from the field that has it, with nothing"
field!(b::Browser, e) = begin
  l = live(b)
  old = field(b)
  old === nothing || old === e || l === nothing || Live.fire!(l, "change", old)
  l === nothing ? (b.field = e) : Live.focus!(l, e)
  b.touched = time()
  e
end

"The first box of the element `e` in the page, or nothing"
box_of(b::Browser, e::Element) = begin
  find(k) = begin
    k.element === e && return k
    for c in k.children
      found = find(c)
      found === nothing || return found
    end
    for c in k.over
      found = find(c)
      found === nothing || return found
    end
    nothing
  end
  find(b.view.page.root)
end

"The colour of the caret in the field `e`: the colour of its text"
ink(b::Browser, e::Element) = (k = box_of(b, e); k === nothing ? 0xff000000 : k.style.color | 0xff000000)

"""
Where the caret can be in the field `e`: for each number of characters before
it, from none to all of the field's text, where it is across the page, the
top of its line and how tall its line is, in px of the page as it's drawn.
The page's own layout of the text says where each letter is.
"""
caret_stops(b::Browser, e::Element) = begin
  p = b.view.page
  r = place(b, e)
  r === nothing && return [(0.0, 0.0, 0.0)]
  left, top, wide, tall = r
  # The letters that the page drew in the field's box, in order
  letters = NTuple{4,Float64}[]   # left, right, top, tall
  for w in p.words
    top - 1 <= w.top + w.tall / 2 <= top + tall + 1 || continue
    for i in eachindex(w.letters)
      left - 1 <= (w.edges[i] + w.edges[i+1]) / 2 <= left + wide + 1 && push!(letters, (w.edges[i], w.edges[i+1], w.top, w.tall))
    end
  end
  value = Forms.value(e)
  k = box_of(b, e)
  z = p.zoom
  # Where the text starts: inside the field's border and padding
  home = k === nothing ? (left + 4z, top + 3z, max(tall - 6z, 8z)) :
         (left + (k.border[4] + k.padding[4]) * z, top + (k.border[1] + k.padding[1]) * z, max(8.0, min(tall, 1.25 * k.style.size) * z))
  if isempty(value)
    # What shows in an empty field is its hint, and the caret is where the hint starts
    isempty(letters) || (home = (home[1], letters[1][3], letters[1][4]))
    return [home]
  end
  isempty(letters) || (home = (letters[1][1], letters[1][3], letters[1][4]))
  stops = [home]
  j = 0
  for c in value
    if c == '\n'
      # After the end of a line, the caret is at the start of the next line
      last = stops[end]
      next = j < length(letters) ? letters[j+1] : nothing
      push!(stops, next !== nothing && next[3] > last[2] + last[3] / 2 ? (next[1], next[3], next[4]) : (home[1], last[2] + last[3], last[3]))
    else
      j += 1
      push!(stops, j <= length(letters) ? (letters[j][2], letters[j][3], letters[j][4]) : stops[end])
    end
  end
  stops
end

"How many characters of the field `e` come before the place in its text that's nearest the point `(x, y)` of the page"
index_at(b::Browser, e::Element, x, y) = begin
  stops = caret_stops(b, e)
  # The line whose middle is nearest, then the place on it that's nearest
  line = argmin(i -> abs(stops[i][2] + stops[i][3] / 2 - y), eachindex(stops))
  on = [i for i in eachindex(stops) if stops[i][2] == stops[line][2]]
  on[argmin(i -> abs(stops[on[i]][1] - x), eachindex(on))] - 1
end

"What someone did to the page is answered in the next frame, also by a slow page that rests"
wake!(b::Browser) = (b.rest = 0.0; redraw_in!(b, 0); b)

"Put `value` in the field `e`, as typing does"
set!(b::Browser, e::Element, value::AbstractString) = begin
  l = live(b)
  l === nothing ? (Forms.value!(e, value); b.view.made = nothing) : Live.input!(l, e, value)
  b.touched = time()
  wake!(b)
  value
end

"The two ends of what's selected in the field `e`, as how many characters come before each"
selected(b::Browser, e::Element) = (n = length(Forms.value(e)); extrema((clamp(b.caret, 0, n), clamp(b.anchor, 0, n))))

"Type `words` into the field `e`, in place of what's selected"
type!(b::Browser, e::Element, words::AbstractString) = begin
  chars = collect(Forms.value(e))
  lo, hi = selected(b, e)
  new = collect(e.tag == "textarea" ? words : replace(words, r"\r?\n|\r" => " "))
  most = tryparse(Int, attr(e, "maxlength"))
  most === nothing || most < 0 || (new = new[1:clamp(most - (length(chars) - (hi - lo)), 0, length(new))])
  set!(b, e, String(vcat(chars[1:lo], new, chars[hi+1:end])))
  b.caret = b.anchor = lo + length(new)
  handled
end

"Put the caret `to` characters into the field `e`. With `keep`, what's between it and where the selection started is selected."
caret!(b::Browser, e::Element, to, keep=false) = begin
  b.caret = clamp(to, 0, length(Forms.value(e)))
  keep || (b.anchor = b.caret)
  b.touched = time()
  redraw_in!(b, 0)
  handled
end

"The fields for text of the page that the element `e` is in, in the page's order"
fields(e::Element) = Forms.under(Forms.typed, Forms.root(e))

"The address that the addresses in the page are from"
home(b::Browser) = (l = live(b); l === nothing ? b.view.base : Live.JS.home(l.scripts))

"Send the form that the element `e` is in, as the button `by` does, or the Return key with nothing"
send!(b::Browser, e::Element, by=nothing) = begin
  f = Forms.form(e)
  f === nothing && return handled
  l = live(b)
  if l === nothing
    method, to = Forms.sent(f, by; base=home(b))
    method == "get" && follow!(b, to)
  else
    Live.submit!(l, f, by)
  end
  wake!(b)
  handled
end

"""
The keys of ⌃, ⌘, ⌥ and ⇧ that are down in the window `w`. Each key and click
that does something else with one of them held asks for all four, so that it
does it only with the keys that it's for. A key that holds all four does none.
"""
held_keys(w) = w.keys & (Keys.ctrl | Keys.cmd | Keys.opt | Keys.shft)

"What the key `K` does in the field `e` that has the keyboard: `handled`, or nothing for a key that's for the app"
edit!(b::Browser, e::Element, K, w) = begin
  down = held_keys(w)
  shift = Keys.shft in down
  n = length(Forms.value(e))
  lo, hi = selected(b, e)
  if Keys.cmd in down
    # ⌘A, ⌘C, ⌘X and ⌘V with ⌘ alone. ⌘← and ⌘→ can have ⇧ with them, to grow the selection.
    alone, moving = down == Keys.cmd, down in (Keys.cmd, Keys.cmd | Keys.shft)
    K == Keys.a && alone && return (b.anchor = 0; caret!(b, e, n, true))
    K == Keys.left && moving && return caret!(b, e, 0, shift)
    K == Keys.right && moving && return caret!(b, e, n, shift)
    secret = Forms.kind(e) == "password"
    if (K == Keys.c || K == Keys.x) && alone
      (hi > lo && !secret) && clipboard!(w, String(collect(Forms.value(e))[lo+1:hi]))
      return K == Keys.x && hi > lo ? type!(b, e, "") : handled
    end
    K == Keys.v && alone && return type!(b, e, clipboard(w))
    return nothing
  end
  # The keys below work by themselves, or with ⇧: it grows the selection, and Tab goes back
  plain = down in (Keys(0), Keys.shft)
  plain || return handled
  K == Keys.left && return caret!(b, e, hi > lo && !shift ? lo : b.caret - 1, shift)
  K == Keys.right && return caret!(b, e, hi > lo && !shift ? hi : b.caret + 1, shift)
  K == Keys.home && return caret!(b, e, 0, shift)
  K == Keys._end && return caret!(b, e, n, shift)
  if K == Keys.backspace || K == Keys.delete
    hi > lo && return type!(b, e, "")
    K == Keys.backspace ? (lo > 0 && (b.anchor = lo - 1; b.caret = lo)) : (lo < n && (b.anchor = lo; b.caret = lo + 1))
    return b.anchor == b.caret ? handled : type!(b, e, "")
  end
  if K == Keys.enter
    e.tag == "textarea" && return type!(b, e, "\n")
    l = live(b)
    l === nothing || Live.fire!(l, "change", e)
    return send!(b, e)
  end
  K == Keys.escape && !shift && return (field!(b, nothing); wake!(b); handled)
  if K == Keys.tab
    all = fields(e)
    i = findfirst(f -> f === e, all)
    (i === nothing || length(all) < 2) && return handled
    next = all[mod1(i + (shift ? -1 : 1), length(all))]
    field!(b, next)
    b.anchor = 0
    return caret!(b, next, length(Forms.value(next)), true)
  end
  # Any other key types, which `ontype` hears, so the app gets none of it
  handled
end

# --- the mouse and the keys -----------------------------------------------------------------

# What a script calls each key that has a name
const NAMES = Dict(Keys.enter => "Enter", Keys.escape => "Escape", Keys.backspace => "Backspace", Keys.delete => "Delete", Keys.tab => "Tab",
                   Keys.space => " ", Keys.left => "ArrowLeft", Keys.right => "ArrowRight", Keys.up => "ArrowUp", Keys.down => "ArrowDown",
                   Keys.home => "Home", Keys._end => "End", Keys.pageup => "PageUp", Keys.pagedown => "PageDown", Keys.capslock => "CapsLock",
                   Keys.shft => "Shift", Keys.ctrl => "Control", Keys.opt => "Alt", Keys.cmd => "Meta",
                   (getproperty(Keys, Symbol("f", i)) => "F$i" for i in 1:12)...)
const LETTERS = Dict(getproperty(Keys, Symbol(c)) => string(c) for c in 'a':'z')
# What each key of a US keyboard that types a figure or a sign types, by itself and with ⇧
const SIGNS = Dict(getproperty(Keys, Symbol(c)) => (string(c), string(up)) for (c, up) in zip("0123456789", ")!@#\$%^&*("))
merge!(SIGNS, Dict(Keys.minus => ("-", "_"), Keys.equal => ("=", "+"), Keys.left_bracket => ("[", "{"), Keys.right_bracket => ("]", "}"),
                   Keys.semicolon => (";", ":"), Keys.apostrophe => ("'", "\""), Keys.comma => (",", "<"), Keys.period => (".", ">"),
                   Keys.slash => ("/", "?"), Keys.backslash => ("\\", "|"), Keys.tilde => ("`", "~")))
# The keys that are held with others
const HELD = (Keys.cmd, Keys.shft, Keys.opt, Keys.ctrl)

"What a script calls the key `K`: what it types, or its name, like \"Enter\". Nothing for a key that this file has no name for."
key_name(K, shift) = haskey(NAMES, K) ? NAMES[K] : haskey(LETTERS, K) ? (shift ? uppercase(LETTERS[K]) : LETTERS[K]) :
                     haskey(SIGNS, K) ? SIGNS[K][shift ? 2 : 1] : nothing

"The code that a script knows the key `K` by, which says where the key is and not what it types: \"KeyW\", \"Digit1\", \"Space\", \"ShiftLeft\""
key_code(K) = (name = key_name(K, false); name === nothing ? "" : Live.code_of(name))

"The buttons of the mouse that are down in the window `w`, as a script counts them: 1 for the left one and 4 for the middle one"
buttons(w) = (Keys.mouse_left in w.keys ? 1 : 0) | (Keys.mouse_middle in w.keys ? 4 : 0)

"""
While a script of the page has the mouse to itself (`requestPointerLock`),
the pointer is hidden and kept in the middle of the view, and a move of the
mouse tells the page only how far it went. The pointer shows again where it
was once the script lets it go or Esc takes it back. So it does when the view
loses the keyboard, stops being active, or its window isn't the front one, as
in a browser. `b.locked` is where the hidden pointer is kept.
"""
lock!(b::Browser) = begin
  l, w = live(b), window_of(b)
  r = w === nothing ? nothing : rect(b)
  glfw = w === nothing || isempty(w.glfw) ? nothing : w.glfw[1]
  wants = l !== nothing && Live.locked(l)
  if wants && (!b.active || r === nothing || !focused(b) || (glfw !== nothing && GLFW.GetWindowAttrib(glfw, GLFW.FOCUSED) == 0))
    Live.unlock!(l)
    wants = false
  end
  if wants && b.locked === nothing
    b.locked = (r.left + r.width / 2, r.top + r.height / 2)
    glfw === nothing || GLFW.SetInputMode(glfw, GLFW.CURSOR, GLFW.CURSOR_DISABLED)
    keep!(b)
  elseif !wants && b.locked !== nothing
    b.locked = nothing
    glfw === nothing || GLFW.SetInputMode(glfw, GLFW.CURSOR, GLFW.CURSOR_NORMAL)
  end
  b
end

"Put the hidden pointer back where it's kept, so that the next move of the mouse says how far the mouse went from there"
keep!(b::Browser) = begin
  w = window_of(b)
  (b.locked === nothing || w === nothing || isempty(w.glfw)) && return b
  GLFW.SetCursorPos(w.glfw[1], Float64(flt(b.locked[1])), Float64(flt(b.locked[2])))
  b
end

# A view that loses the keyboard takes the mouse back from a script that has it to itself. The page hears `blur`, as
# when a browser's window goes to the back, so a game lets go of a key that was held, whose `keyup` goes elsewhere.
onblur(b::Browser, from) = begin
  lock!(b)
  l = live(b)
  l === nothing || Live.fire!(l, "blur")
  nothing
end

cursor(b::Browser) = begin
  b.active || return b.idle
  at = point(b)
  at === nothing && return :arrow
  Web.link(b.view.page, at...) === nothing || return :hand
  e = element(b, at...)
  e !== nothing && Forms.typed(e) && return :ibeam
  Select.over_words(page_words(b), at...) ? :ibeam : :arrow
end

onmouse(b::Browser, ev::MouseMove) = begin
  b.active || return nothing
  w, l = ev.window, live(b)
  # While a script has the mouse to itself, the page hears how far the mouse went from where the hidden pointer is kept
  from = something(b.locked, w.mouse)
  dx, dy = Float64(flt(ev.position[1] - from[1])), Float64(flt(ev.position[2] - from[2]))
  if b.locked !== nothing
    keep!(b)
    at = point(b, b.locked)
    (l === nothing || at === nothing || dx == dy == 0) && return handled
    Live.move!(l, at...; dx, dy, buttons=buttons(w))
    wake!(b)
    return handled
  end
  at = point(b, ev.position)
  at === nothing && return handled
  b.down !== nothing && Keys.mouse_left in w.keys && drag!(b, at...)
  l === nothing && return handled
  Live.move!(l, at...; dx, dy, buttons=buttons(w))
  l.scripts.changed && redraw_in!(b, 0)
  handled
end

onscroll(b::Browser, ev::MouseScroll) = begin
  (b.active && b.takes(ev)) || return nothing
  # The page's scripts hear the wheel first, and one that says to do no more with it keeps the page where it is
  l, at = live(b), point(b, b.locked)
  if l !== nothing && at !== nothing
    w = ev.window
    go = Live.wheel!(l, at..., -30 * Float64(flt(ev.delta[1])), -30 * Float64(flt(ev.delta[2]));
                     ctrl=Keys.ctrl in w.keys, meta=Keys.cmd in w.keys, alt=Keys.opt in w.keys, shift=Keys.shft in w.keys)
    l.scripts.changed && wake!(b)
    (go && b.locked === nothing) || return handled
  end
  scroll!(b, scrolled(b) - 30 * Float64(flt(ev.delta[2])))
  at = point(b)
  b.down === nothing || at === nothing || drag!(b, at...)
  handled
end

# A pinch reaches the page's scripts as a browser sends it: as the wheel with Ctrl held, where each 100 px down makes
# the page e times smaller. A pinch that no script takes goes on to the nodes above, since the page doesn't zoom.
onpinch(b::Browser, ev::Pinch) = begin
  (b.active && b.takes(ev)) || return nothing
  l, at = live(b), point(b, b.locked)
  (l === nothing || at === nothing || ev.scale <= 0) && return nothing
  go = Live.wheel!(l, at..., 0.0, -100 * log(ev.scale); ctrl=true)
  l.scripts.changed && wake!(b)
  go ? nothing : handled
end

onkey(b::Browser, ev::KeyPress{Keys.mouse_left}) = begin
  (b.active && b.takes(ev)) || return nothing
  focus(b)
  at = point(b)
  at === nothing && return handled
  x, y = at
  l = live(b)
  b.down, b.drag, b.dragged = (x, y), :none, time()
  shift = held_keys(ev.window) == Keys.shft   # ⇧ by itself grows the selection
  # The element that has the mouse to itself hears the button, which selects nothing
  if b.locked !== nothing
    l === nothing || Live.press!(l, point(b, b.locked)...)
    lock!(b)
    wake!(b)
    return handled
  end
  # A script that says to do no more with the button going down keeps the keyboard where it is, and selects nothing
  went = l === nothing || Live.press!(l, x, y)
  # A script that asked for the mouse to itself, as a game does when it's clicked, has it from now on, and the button selects nothing
  l === nothing || lock!(b)
  if went && b.locked === nothing
    e = element(b, x, y)
    to = e !== nothing && Forms.typed(e) ? e : nothing
    was = field(b)
    field!(b, to)
    if to === nothing
      pick!(b, x, y, shift)
    else
      # In a field, the click and the drag select its letters, and the page's words are no longer selected
      b.picked, b.drag = (0, 0), :field
      b.caret = index_at(b, to, x, y)
      shift && was === to || (b.anchor = b.caret)
    end
  end
  wake!(b)
  handled
end

onkey(b::Browser, ev::KeyRelease{Keys.mouse_left}) = begin
  (b.active && b.down !== nothing) || return nothing
  from = b.down
  b.down, b.drag = nothing, :none
  at = point(b, b.locked)
  at === nothing && return handled
  l = live(b)
  l === nothing || Live.release!(l, at...)
  wake!(b)
  # The mouse that came up where it went down clicked. While a script has the mouse to itself, the mouse is always there.
  (b.locked !== nothing || hypot(at[1] - from[1], at[2] - from[2]) <= SLACK) && click!(b, at...)
  handled
end

"A click at the point `(x, y)` of the page"
click!(b::Browser, x, y) = begin
  l, p = live(b), b.view.page
  # A click while a script has the mouse to itself goes to that script's element, and follows no link
  b.locked === nothing || return (l === nothing || Live.click!(l, x, y); b)
  e = element(b, x, y)
  link = Web.link(p, x, y)
  if l !== nothing
    # The page's scripts hear the click first. window.jl ticks a tick box and sends the form of a button.
    Live.click!(l, x, y) || return b
  elseif e !== nothing
    button = something(Forms.within(e, "button"), e)
    Forms.tick!(e) ? (b.view.made = nothing; wake!(b)) : Forms.sends(button) && send!(b, button, button)
  end
  list = e === nothing ? nothing : Forms.within(e, "select")
  list === nothing || haskey(list.attrs, "disabled") || return choose!(b, list)
  # A video in a frame opens in a browser, since no player runs here
  link === nothing || (e !== nothing && e.tag == "iframe" ? b.open(link.url) : follow!(b, link.url))
  b
end

"Show the choices of the <select> `list` in a menu under it. The one that's picked is the list's choice from then on."
choose!(b::Browser, list::Element) = begin
  w, r, at = window_of(b), rect(b), place(b, list)
  options = Forms.under(o -> o.tag == "option" && !haskey(o.attrs, "disabled"), list)
  (w === nothing || r === nothing || at === nothing || isempty(options)) && return b
  words = [String(strip(haskey(o.attrs, "label") ? attr(o, "label") : replace(text(o), r"\s+" => " "))) for o in options]
  show_menu!(w, words, r.left + px(at[1]), r.top + px(at[2] + at[4] - scrolled(b)), max(px(at[3]), 140px), onselect=i -> begin
    i > 0 || return
    foreach(o -> delete!(o.attrs, "selected"), Forms.under(o -> o.tag == "option", list))
    options[i].attrs["selected"] = ""
    l = live(b)
    if l === nothing
      b.view.made = nothing
    else
      l.scripts.changed = true
      Live.fire!(l, "input", list)
      Live.fire!(l, "change", list)
    end
    wake!(b)
  end)
  b
end

# The middle button goes to the page's scripts and does nothing else: it selects no words and follows no link. A 3D
# view moves what it shows across with it, as a CAD program does.
onkey(b::Browser, ev::KeyPress{Keys.mouse_middle}) = begin
  (b.active && b.takes(ev)) || return nothing
  l, at = live(b), point(b, b.locked)
  (l === nothing || at === nothing) && return nothing
  focus(b)   # so that the button coming up comes here too
  Live.press!(l, at...; button=1, buttons=buttons(ev.window))
  l.scripts.changed && wake!(b)
  handled
end

onkey(b::Browser, ev::KeyRelease{Keys.mouse_middle}) = begin
  b.active || return nothing
  l, at = live(b), point(b, b.locked)
  (l === nothing || at === nothing) && return nothing
  Live.release!(l, at...; button=1, buttons=buttons(ev.window))
  l.scripts.changed && wake!(b)
  handled
end

onkey(b::Browser, ev::KeyPress{K}) where K = begin
  b.active || return nothing
  w = ev.window
  # The other buttons of the mouse do nothing here
  K in (Keys.mouse_right, Keys.mouse_back, Keys.mouse_forward) && return nothing
  cmd, shift = Keys.cmd in w.keys, Keys.shft in w.keys
  l, name = live(b), key_name(K, shift)
  # Esc takes the mouse back from a script that has it to itself, and the page doesn't hear that Esc
  if K == Keys.escape && l !== nothing && Live.locked(l)
    Live.unlock!(l)
    lock!(b)
    wake!(b)
    return handled
  end
  keydown() = Live.key!(l, "keydown", name; code=key_code(K), repeat=ev.is_repeat, shift, meta=cmd, ctrl=Keys.ctrl in w.keys, alt=Keys.opt in w.keys)
  # A key that's held with others types nothing itself. The page's scripts hear it go down, and the app has it too.
  if K in HELD
    l === nothing || (keydown(); l.scripts.changed && wake!(b))
    return nothing
  end
  b.swallow = false
  b.touched = time()
  # The page's scripts hear the key first. One that says to do no more with it keeps it from the field and from the page.
  if l !== nothing && name !== nothing
    go = keydown()
    wake!(b)
    go || return (b.swallow = true; handled)
  end
  e = field(b)
  e === nothing || return edit!(b, e, K, w)
  down = held_keys(w)
  if cmd
    K == Keys.c && down == Keys.cmd && return (copy_words!(b, w); handled)
    K == Keys.a && down == Keys.cmd && return (select_all!(b); handled)
    return nothing
  end
  # The keys that scroll the page work by themselves. Space with ⇧ goes back up.
  (down == Keys(0) || (K == Keys.space && down == Keys.shft)) || return nothing
  page = Float64(flt(b.high))
  K == Keys.space ? scroll!(b, scrolled(b) + (shift ? -0.9 : 0.9) * page) :
  K == Keys.pagedown ? scroll!(b, scrolled(b) + 0.9page) :
  K == Keys.pageup ? scroll!(b, scrolled(b) - 0.9page) :
  K == Keys.down ? scroll!(b, scrolled(b) + STEP) :
  K == Keys.up ? scroll!(b, scrolled(b) - STEP) :
  K == Keys.home ? scroll!(b, 0.0) :
  K == Keys._end ? scroll!(b, reach(b)) : return nothing
  handled
end

onkey(b::Browser, ev::KeyRelease{K}) where K = begin
  b.active || return nothing
  w = ev.window
  l, name = live(b), key_name(K, Keys.shft in w.keys)
  (l === nothing || name === nothing) && return nothing
  Live.key!(l, "keyup", name; code=key_code(K), shift=Keys.shft in w.keys, meta=Keys.cmd in w.keys, ctrl=Keys.ctrl in w.keys, alt=Keys.opt in w.keys)
  l.scripts.changed && wake!(b)
  nothing
end

# What the keyboard types goes into the field that has the keyboard. With none, it goes nowhere: the page has the keyboard.
ontype(b::Browser, ev::Typed) = begin
  b.active || return nothing
  e = field(b)
  (e === nothing || iscntrl(ev.char) || b.swallow) && return handled
  type!(b, e, string(ev.char))
end

export Browser, go!, back!, forward!, reload!, can_back, can_forward, loading, scroll!
