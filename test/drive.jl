# The mouse, the keys and typing that a test sends to a window that isn't on
# the screen, as a person sends them, with frames drawn after each. `drive(w)`
# gives the functions for the window `w`, so a test's lines read as they did
# when each test wrote its own:
#
#     const w = Window(e, size=(1000px, 900px))
#     const (; frames, at, press, release, click, typed, key, shot) = drive(w)
#
#     click((40, 60))               # move there, press the left button, let it go
#     click(button)                 # a node or a rectangle is a place too: its middle
#     click(button, Keys.cmd)       # with ⌘ held from the press until the button is let go
#     press((40, 60)); at((200, 60)); release()   # a drag
#     typed("Buy milk")
#     key(Keys.enter)
#     key(Keys.s, Keys.cmd)         # ⌘S
#     shot("after")                 # after.png, in the folder LADDER_SHOTS names, if it names one
#     frames(); frames(4)           # draw 2 frames, draw 4
#     frames(w2); frames(w2, 4)     # draw another window
#
# Each one draws 2 frames after it, except a mouse move, which draws 1, and a
# mouse press, which draws none. `drive(w, frames=3)` draws 3, `drive(w, moved=2)`
# draws 2 after a move, and `drive(w, pressed=1)` draws 1 after a press.
# With `latest=true`, each frame runs in Julia's newest world, for a test
# whose page defines functions while it runs.
# With `slide=false`, the command palette doesn't slide up or down: each frame
# draws it where it stops, so a click just after it closes can't land on it.
#
# A test with several windows calls `drive()` with no window. Each function
# then takes its window first:
#
#     const (; frames, click, key) = drive()
#     key(w, Keys.w, Keys.cmd)
#
# UI.jl's own helpers (Interface/testing.jl) draw one frame, and refuse a click
# on a node that's covered. Ladder's tests were written for these.

@use "github.com/jkroso/MiniFB.jl" Keys KeyPress KeyRelease MouseMove Typed onkey onmouse ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI
@use "github.com/jkroso/Font.jl/units" px
@use GeometryBasics: Vec2

"A length in px as a plain number"
num(l) = Float64(convert(px, l).value)

"""
The middle of a rectangle as `(x, y)` in px, to click: a rectangle from `rect`,
a node, which has one from the last frame, or `(left, top, width, height)`
"""
middle(r) = (num(r.left + r.width / 2), num(r.top + r.height / 2))
middle(n::SemanticUI) = middle(rect(n))
middle(r::Tuple) = (num(r[1] + r[3] / 2), num(r[2] + r[4] / 2))

"A place in the window as `(x, y)` in px: `(x, y)` itself, as numbers or as lengths, or the middle of a node or of a rectangle"
spot(p::Union{Tuple{Any,Any},AbstractVector}) = map(v -> v isa px ? v : px(v), (p[1], p[2]))
spot(p) = spot(middle(p))

"End the slide of the command palette in the window `w`, so that the next frame draws it where it stops"
rest!(w) = (nodes = w.ui.nodes; haskey(nodes, :palette) && (nodes[:palette].moved = 0.0))

"The functions that drive the window `w`: see the top of this file"
drive(w; frames=2, moved=1, pressed=0, latest=false, slide=true) = begin
  draw_frames(n::Integer=frames) = draw_frames(w, n)
  draw_frames(other, n::Integer=frames) = (slide || rest!(other); foreach(_ -> latest ? Base.invokelatest(frame, other) : frame(other), 1:n))
  at(place) = begin
    x, y = spot(place)
    w.mouse = typeof(w.mouse)(x, y); onmouse(w, MouseMove(Vec2{px}(x, y), w)); draw_frames(moved)
  end
  press(place, held...) = (at(place); foreach(h -> w.keys |= h, held); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); draw_frames(pressed))
  release(held...) = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); foreach(h -> w.keys ⊻= h, held); draw_frames())
  click(place, held...) = (press(place, held...); release(held...))
  typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); draw_frames())
  key(k, held...) = begin
    foreach(h -> w.keys |= h, held)
    onkey(w, KeyPress{k}(0, w))
    foreach(h -> w.keys ⊻= h, held)
    draw_frames()
  end
  shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], endswith(name, ".png") ? name : name * ".png"), w)
  (; frames=draw_frames, at, press, release, click, typed, key, shot)
end

"The same functions for a test with several windows: each takes its window first"
drive(; options...) = begin
  names = (:frames, :at, :press, :release, :click, :typed, :key, :shot)
  NamedTuple{names}(map(name -> (w, args...) -> drive(w; options...)[name](args...), names))
end
