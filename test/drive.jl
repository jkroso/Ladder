# The mouse, the keys and typing that a test sends to a window that isn't on
# the screen, as a person sends them, with frames drawn after each. `drive(w)`
# gives the functions for the window `w`, so a test's lines read as they did
# when each test wrote its own:
#
#     const w = Window(e, size=(1000px, 900px))
#     const (; frames, at, press, release, click, typed, key, shot) = drive(w)
#
#     click(middle(rect(button)))   # move there, press the left button, let it go
#     press((40, 60)); at((200, 60)); release()   # a drag
#     typed("Buy milk")
#     key(Keys.enter)
#     key(Keys.s, Keys.cmd)         # ⌘S
#     shot("after")                 # after.png, in the folder LADDER_SHOTS names, if it names one
#
# Each one draws 2 frames after it, except a mouse move, which draws 1.
# `drive(w, frames=3)` draws 3, and `drive(w, moved=2)` draws 2 after a move.
# With `latest=true`, each frame runs in Julia's newest world, for a test
# whose page defines functions while it runs.
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

"The functions that drive the window `w`: see the top of this file"
drive(w; frames=2, moved=1, latest=false) = begin
  draw_frames(n=frames) = foreach(_ -> latest ? Base.invokelatest(frame, w) : frame(w), 1:n)
  at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); draw_frames(moved))
  press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
  release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); draw_frames())
  click(place) = (press(place); release())
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
