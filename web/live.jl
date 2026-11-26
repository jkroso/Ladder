# A page whose scripts run.
#
#     l = live(html; wide=700, load, base)    # read the page and run its scripts
#     p = page!(l)              # the page, laid out as it is now. It's laid out again only after a script changed it.
#     draw(canvas, p)           # as any page of main.jl
#     step!(l)                  # run the timers that are due. Gives how many seconds until the next, or nothing.
#     click!(l, x, y)           # a click at a point of the page. False when a script said to do no more with it.
#     move!(l, x, y; dx, dy)    # the mouse is at a point of the page now, after it moved by (dx, dy)
#     press!(l, x, y), release!(l, x, y)   # the mouse button goes down there, and comes up
#     wheel!(l, x, y, dx, dy)   # the wheel scrolls there. False when a script said not to scroll the page.
#     locked(l), unlock!(l)     # a script has the mouse to itself (requestPointerLock), and Esc takes it back
#     scroll!(l, 400)           # the top of the window is 400 px down the page
#     focus!(l, element)        # give an element the keyboard. `l.focused` is the element that has it.
#     input!(l, element, "text")           # type into a field
#     key!(l, "keydown", "Enter")          # a key goes down, or comes up with "keyup"
#     key!(l, "keydown", "w"; code="KeyW", repeat=true)   # where the key is, and whether it goes down again as it's held
#     submit!(l, form)          # send a form
#     refresh!(l)               # a file that the page waited for has come: lay the page out again with it
#     resize!(l, 500)           # the page is 500 px wide now
#     l.scripts.log             # what the scripts printed, and the errors that they threw
#     evaluate(l, "document.title")
#     close(l)
#
# `live` takes what `page` takes, and `limit`: how many seconds a script may
# run before it's stopped. `say(level, text)` is called with each line that a
# script prints. `go(address)` is called when the page asks to go to another
# page: a script set `location.href`, or a form was sent. `allowed(address)`
# says whether a script may read the file at an address: see script.jl.
#
# With `high`, the page is seen through a window that high, and it scrolls:
# `l.scroll` is how far down the page the top of the window is, in px before
# the zoom. A point that `click!` and the others take is a point of the page,
# as `link(p, x, y)` takes it, wherever the page is scrolled to.
#
# The scripts run in script.jl. This file lays the page out for them: a script
# that asks where an element is (`getBoundingClientRect`, `offsetWidth`) gets
# the answer from a layout of the page as it is at that moment.
#
# An animation of the page's CSS runs too, and a style that a script changes
# takes the time that its `transition` says. While something moves, `page!`
# lays the page out again each time, as it is at that moment, and `moving(p)`
# is true of the page that it gives. `step!` tells the scripts what has ended
# (`animationend`, `transitionend`).
#
# All of a page is laid out again after any change. A script that changes the
# page and then asks for a size, again and again in one loop, makes that many
# layouts.
#
# Use a live page from the main task only: see jsc.jl.

@use "./dom" Element Document document
@use "./box" Box
@use "./style" alpha Clock events!
@use "./script" => JS
@use "./script" Scripts ScriptError
@use "./main" Page Pictures page moving due retry!

"A page whose scripts run"
mutable struct Live
  doc::Document
  scripts::Scripts
  options::NamedTuple        # what `page` takes
  pictures::Pictures
  page::Union{Page,Nothing}  # the page as it was last laid out
  places::IdDict{Element,Vector{NTuple{4,Float64}}}   # where the box of each element is in that page, in px before the zoom
  boxes::IdDict{Element,Box}                          # and the first box of each element
  scroll::Float64                                     # how far down the page the top of the window is, in px before the zoom
  focused::Union{Element,Nothing}                     # the element that has the keyboard
  over::Union{Element,Nothing}                        # the element that the mouse is over
  rest::Float64                                       # until when a page that moves isn't laid out again only because time passed
end

# With scripts, what's for a reader with none isn't part of the page
const WITH_SCRIPTS = "\nnoscript { display: none !important }\n"

"""
Read the page that `html` writes and run its scripts. Takes what `page`
takes. `limit` is how many seconds a script may run before it's stopped, and
`say(level, text)` is called with each line that a script prints.
"""
live(html::AbstractString; wide=700, zoom=1.0, load=src -> nothing, pictures=Pictures(load), css="", fit=false, widest=2000, high=nothing, base="",
     limit=10, say=(level, text) -> nothing, go=nothing, allowed=address -> true, dark=false) = begin
  doc = document(html)
  options = (; wide, zoom, load, css=css * WITH_SCRIPTS, fit, widest, high, base, clock=Clock(), dark)
  l = Live(doc, Scripts(doc; load, base, say, limit, go, allowed), options, pictures, nothing, IdDict{Element,Vector{NTuple{4,Float64}}}(), IdDict{Element,Box}(),
           0.0, nothing, nothing, 0.0)
  s = l.scripts
  s.scroll = (y...) -> isempty(y) ? l.scroll : scroll!(l, y[1])
  s.focused = e -> (l.focused = e; nothing)
  s.place = e -> (page!(l); get(l.places, e, NTuple{4,Float64}[]))
  s.at = (x, y) -> at(l, x, y)
  s.computed = (e, name) -> computed(l, e, name)
  s.window = () -> (Float64(l.options.wide / l.options.zoom), Float64(something(l.options.high, 800) / l.options.zoom), l.options.dark)
  JS.start!(s)
  l
end

Base.close(l::Live) = close(l.scripts)
Base.isopen(l::Live) = isopen(l.scripts)

"The page of `l`, laid out as its tree is now"
page!(l::Live) = begin
  s = l.scripts
  # A page that moves is laid out again as time passes. A layout that takes long leaves three times as long for the
  # rest: a script that asks where things are, again and again, would else get a new layout each time.
  (l.page === nothing || s.changed || (due(l.page, time() - s.started) && time() >= l.rest)) || return l.page
  began = time()
  s.changed = false
  # A script can add a <style> or a <base>, and can put another <body> in the page
  root = l.doc.root
  i = findfirst(c -> c isa Element && c.tag == "body", root.children)
  l.doc = s.doc = Document(root, i === nothing ? l.doc.body : root.children[i], l.doc.mode)
  # The page's time is the scripts' time: what `performance.now()` gives a script
  p = l.page = page(l.doc; l.options..., pictures=l.pictures, at=time() - s.started)
  empty!(l.places)
  for q in p.list.places
    push!(get!(() -> NTuple{4,Float64}[], l.places, q.element), (q.left, q.top, q.wide, q.tall))
  end
  empty!(l.boxes)
  note(b::Box) = begin
    b.element === nothing || get!(l.boxes, b.element, b)
    foreach(note, b.children)
    foreach(note, b.over)
  end
  note(p.root)
  l.rest = time() + max(1 / 30, 3 * (time() - began))
  p
end

"The page as it was last laid out, which is what the window shows. It's laid out now only if it never was."
seen(l::Live) = l.page === nothing ? page!(l) : l.page

"""
The element at the point `(x, y)` of the page, in px before the zoom, or
nothing. Of the boxes there, it's the one that the page has last. A script
asks about the page as it is now. With `fresh=false`, it's the page as it
was last laid out: the mouse points at what the window shows.
"""
at(l::Live, x, y; fresh=true) = begin
  places = (fresh ? page!(l) : seen(l)).list.places
  i = findlast(q -> q.left <= x < q.left + q.wide && q.top <= y < q.top + q.tall, places)
  i === nothing ? nothing : places[i].element
end

rgb(c::UInt32) = begin
  r, g, b = (c >> 16) & 0xff, (c >> 8) & 0xff, c & 0xff
  alpha(c) == 1 ? "rgb($r, $g, $b)" : "rgba($r, $g, $b, $(round(alpha(c), digits=3)))"
end

pixels(x) = string(round(x, digits=3), "px") |> t -> replace(t, r"\.0px$" => "px")

"""
What the page's CSS gives the element `e` for the property `name`, as CSS
writes it, or nothing for a property that isn't known here. This is what
`getComputedStyle` in a script reads. The few properties here are the ones
that scripts ask for most.
"""
computed(l::Live, e::Element, name::AbstractString) = begin
  page!(l)
  b = get(l.boxes, e, nothing)
  b === nothing && return name == "display" ? "none" : nothing
  s = b.style
  name == "display" ? replace(string(s.display), '_' => '-') :
  name == "position" ? string(s.position) :
  name == "visibility" ? (s.visible ? "visible" : "hidden") :
  name == "opacity" ? string(s.opacity) :
  name == "float" ? string(s.float) :
  name == "color" ? rgb(s.color) :
  name == "background-color" ? rgb(s.background) :
  name == "font-size" ? pixels(s.size) :
  name == "font-weight" ? string(s.weight) :
  name == "width" ? pixels(b.width - b.padding[2] - b.padding[4] - b.border[2] - b.border[4]) :
  name == "height" ? pixels(b.height - b.padding[1] - b.padding[3] - b.border[1] - b.border[3]) :
  (m = match(r"^(margin|padding|border)-(top|right|bottom|left)(-width)?$", name)) !== nothing && (m[1] == "border") == (m[3] !== nothing) ?
    pixels(getfield(b, Symbol(m[1]))[findfirst(==(m[2]), ("top", "right", "bottom", "left"))]) :
  nothing
end

"""
Run the timers of the page that are due, and the scripts that wait for the
next frame. Gives how many seconds until the next timer is due, 0 when a
script waits for the next frame, or nothing when nothing waits. Ask `page!`
after it for the page as the scripts left it.
"""
step!(l::Live) = (tell!(l); JS.step!(l.scripts))

"Tell the page's scripts of each animation and each change of a style that has ended since they were last told: `animationend` and `transitionend`"
tell!(l::Live) = begin
  for (who, type, name, long) in events!(l.options.clock)
    who isa Element || continue   # a part of an element, like ::before, is no element
    # The event says what ended and how long it took: see context.jl
    JS.guarded(() -> l.scripts.hooks["ending"](type, name, long), l.scripts)
    JS.fire!(l.scripts, who, type, Dict{String,Any}("bubbles" => true, "cancelable" => false))
  end
  nothing
end

"How many seconds until the next timer of the page is due, 0 when a script waits for the next frame, or nothing when nothing waits"
waiting(l::Live) = JS.waiting(l.scripts)

"""
A click at the point `(x, y)` of the page, as `link(p, x, y)` takes it. The
page's scripts hear it on the element there. False when a script said that
the click should do no more: then the caller doesn't open the link there.
"""
click!(l::Live, x, y) = begin
  z = l.options.zoom
  JS.click!(l.scripts, at(l, x / z, y / z; fresh=false), x / z, y / z - l.scroll)
end

"""
What an event of the mouse says to a script: where the mouse is in the
window, how far it moved since the last event (`dx` and `dy`, in px of the
page as it's drawn), and which buttons are down: 1 for the left one.
"""
mouse(l::Live, x, y; dx=0.0, dy=0.0, button=0, buttons=0) = begin
  z = l.options.zoom
  Dict{String,Any}("bubbles" => true, "cancelable" => true, "clientX" => x / z, "clientY" => y / z - l.scroll,
                   "movementX" => dx / z, "movementY" => dy / z, "button" => button, "buttons" => buttons)
end

"""
The mouse is at the point `(x, y)` of the page now, after it moved by `(dx,
dy)` px. The page's scripts hear `mousemove` on the element there, and
`mouseout` and `mouseover` when that's another element than before. With no
point, the mouse has left the page. While a script has the mouse to itself,
the element that asked hears each `mousemove`: see `locked`.
"""
move!(l::Live, x, y; dx=0.0, dy=0.0, buttons=0) = begin
  z = l.options.zoom
  e = at(l, x / z, y / z; fresh=false)
  if e !== l.over
    l.over === nothing || JS.fire!(l.scripts, l.over, "mouseout", mouse(l, x, y))
    l.over = e
    e === nothing || JS.fire!(l.scripts, e, "mouseover", mouse(l, x, y))
  end
  e === nothing || JS.fire!(l.scripts, e, "mousemove", mouse(l, x, y; dx, dy, buttons))
  l
end
move!(l::Live) = (l.over === nothing || (JS.fire!(l.scripts, l.over, "mouseout"); l.over = nothing); l)

"""
A mouse button goes down at the point `(x, y)` of the page. False when a script
said to do no more with it. `button` is which one, as a script counts them: 0
the left, 1 the middle. `buttons` is all that are down now: 1 the left, 4 the
middle.
"""
press!(l::Live, x, y; button=0, buttons=1) = (z = l.options.zoom; JS.fire!(l.scripts, at(l, x / z, y / z; fresh=false), "mousedown", mouse(l, x, y; button, buttons)))
"A mouse button comes up at the point `(x, y)` of the page. `button` and `buttons` are as for `press!`."
release!(l::Live, x, y; button=0, buttons=0) = (z = l.options.zoom; JS.fire!(l.scripts, at(l, x / z, y / z; fresh=false), "mouseup", mouse(l, x, y; button, buttons)))

"""
The wheel or the trackpad scrolls by `(dx, dy)` px, as the page is drawn,
with the mouse at the point `(x, y)` of the page. More than 0 is down, and to
the right. The page's scripts hear `wheel` on the element there, with the
keys that were held: `ctrl` is true for a pinch, as a browser sends one. False
when a script said to do no more with it: then the page doesn't scroll.
"""
wheel!(l::Live, x, y, dx, dy; ctrl=false, meta=false, alt=false, shift=false) = begin
  z = l.options.zoom
  init = mouse(l, x, y)
  init["deltaX"], init["deltaY"], init["deltaMode"] = dx / z, dy / z, 0
  init["ctrlKey"], init["metaKey"], init["altKey"], init["shiftKey"] = ctrl, meta, alt, shift
  JS.fire!(l.scripts, at(l, x / z, y / z; fresh=false), "wheel", init)
end

"""
True while a script of the page has the mouse to itself, since it asked with
`requestPointerLock`, as a game does to turn its view with the mouse. Each
event of the mouse goes to the element that asked then. The caller hides the
pointer meanwhile, and says how far the mouse moves with `move!`.
"""
locked(l::Live) = JS.locked(l.scripts)

"Take the mouse back from the script that has it to itself, as Esc does"
unlock!(l::Live) = (JS.unlock!(l.scripts); l)

"How far down the page the top of the window can be: the page's height less the window's, in px before the zoom"
reach(l::Live) = l.options.high === nothing ? 0.0 : max(0.0, (seen(l).tall - l.options.high) / l.options.zoom)

"""
Put the top of the window `y` px down the page, in px before the zoom, or as
near that as the page goes. A page with no window doesn't scroll. The page's
scripts hear `scroll` when it moved.
"""
scroll!(l::Live, y) = begin
  to = clamp(Float64(y), 0.0, reach(l))
  to == l.scroll && return to
  l.scroll = to
  fire!(l, "scroll")
  to
end

"Give the keyboard to the element `e`, or take it from the element that has it, with nothing. `l.focused` is the element that has it."
focus!(l::Live, e::Union{Element,Nothing}) = (JS.focus!(l.scripts, e); l.focused)

"Put the text `value` in the field `e`, as typing does"
input!(l::Live, e::Element, value::AbstractString) = JS.input!(l.scripts, e, value)

"""
A key of the keyboard goes down (`type` is "keydown") or comes up ("keyup").
`key` is what it types, like "a" or "Enter". `code` says which key it is,
wherever the keyboard's layout puts what it types, like "KeyA" or "Digit1":
a game reads it to move with W, A, S and D. `repeat` is true when the key goes
down again because it's held. The element that has the keyboard hears it, or
the page's <body>. False when a script said to do no more with it.
"""
key!(l::Live, type::AbstractString, key::AbstractString; code=code_of(key), repeat=false, shift=false, ctrl=false, alt=false, meta=false) =
  JS.fire!(l.scripts, something(l.focused, l.doc.body), type,
           Dict{String,Any}("bubbles" => true, "cancelable" => true, "key" => key, "code" => code, "keyCode" => keycode(key), "repeat" => repeat,
                            "shiftKey" => shift, "ctrlKey" => ctrl, "altKey" => alt, "metaKey" => meta))

# The number that an old script knows a key by
const KEYCODES = Dict("Backspace" => 8, "Tab" => 9, "Enter" => 13, "Shift" => 16, "Control" => 17, "Alt" => 18, "Escape" => 27, " " => 32,
                      "PageUp" => 33, "PageDown" => 34, "End" => 35, "Home" => 36, "ArrowLeft" => 37, "ArrowUp" => 38, "ArrowRight" => 39,
                      "ArrowDown" => 40, "Delete" => 46, "Meta" => 91)
keycode(key::AbstractString) = get(() -> length(key) == 1 && isascii(key) ? Int(uppercase(only(key))) : 0, KEYCODES, key)

# What a script calls the keys of a US keyboard that type a sign, and the keys that are held with others
const SIGN_CODES = Dict('-' => "Minus", '=' => "Equal", '[' => "BracketLeft", ']' => "BracketRight", ';' => "Semicolon", '\'' => "Quote",
                        ',' => "Comma", '.' => "Period", '/' => "Slash", '\\' => "Backslash", '`' => "Backquote")
const HELD_CODES = Dict("Shift" => "ShiftLeft", "Control" => "ControlLeft", "Alt" => "AltLeft", "Meta" => "MetaLeft")

"The code of the key that types `key` by itself on a US keyboard, like \"KeyA\" for \"a\", \"Digit1\" for \"1\" and \"Space\" for \" \". A key with a name, like \"Enter\", is its code."
code_of(key::AbstractString) = begin
  length(key) == 1 || return get(HELD_CODES, key, key)
  c = only(key)
  'a' <= lowercase(c) <= 'z' ? "Key" * uppercase(key) : '0' <= c <= '9' ? "Digit" * key : c == ' ' ? "Space" : get(SIGN_CODES, c, "")
end

"Send the form `form`, as the button `by` does, or the Return key with nothing"
submit!(l::Live, form::Element, by::Union{Element,Nothing}=nothing) = JS.submit!(l.scripts, form, by)

"A file that the page waited for has come: a picture, a sheet or a font. The page is laid out again with it."
refresh!(l::Live) = (retry!(l.pictures); l.page = nothing; l)

"Tell the page's scripts of an event on the window, like \"resize\", or on the element `e`"
fire!(l::Live, type::AbstractString, e::Union{Element,Nothing}=nothing) = JS.fire!(l.scripts, e, type)

"Lay the page out `wide` px wide from now on, and tell its scripts that the window changed"
Base.resize!(l::Live, wide; high=l.options.high, zoom=l.options.zoom) = begin
  (wide == l.options.wide && high == l.options.high && zoom == l.options.zoom) && return l
  l.options = merge(l.options, (; wide, high, zoom))
  l.page = nothing
  fire!(l, "resize")
  l.scroll = min(l.scroll, reach(l))   # a page that's shorter now can't be scrolled as far
  l
end

"Lay the page out for a screen in dark mode from now on, or in light mode: see `page`'s `dark`"
dark!(l::Live, dark::Bool) = begin
  dark == l.options.dark && return l
  l.options = merge(l.options, (; dark))
  l.page = nothing
  l
end

"Run `code` in the page, and give the value of its last statement. What the script throws is thrown here, as a `ScriptError`."
evaluate(l::Live, code::AbstractString; kw...) = JS.evaluate(l.scripts, code; kw...)

export Live, ScriptError, live, page!, step!, dark!, waiting, click!, move!, press!, release!, wheel!, locked, unlock!, scroll!, focus!, input!, key!, submit!, refresh!, fire!, evaluate
