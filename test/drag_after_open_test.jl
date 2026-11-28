# Tests for a drag that comes before the window has laid out the file that it
# shows now, in main.jl's `locate`. A click can open another file in the
# window, as ⌘-click on a name does. If the mouse moves while its button is
# still down, the move comes before the next frame, and the layout is still
# the one of the page before. That page can have more lines than the new file,
# or longer ones. The installed app quit with a BoundsError there.
# Run them with `julia -O0 --project=. test/drag_after_open_test.jl`.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window MouseMove onmouse Keys
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use GeometryBasics: Vec2
@use "./drive" drive
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const long = joinpath(dir, "long.md")
write(long, join(["Line $i of a long page, with enough words in it to make it a long line." for i in 1:300], "\n\n"))
const short = joinpath(dir, "short.jl")
write(short, join(["x$i = $i" for i in 1:81], "\n"))

const e = K.build_editor(long)
const w = Window(e, size=(900px, 600px))
const (; frames) = drive(w, latest=true)
frames(3)

"Move the mouse to `(x, y)` with its button down, as a drag does"
drag(x, y) = begin
  pos = Vec2{px}(px(x), px(y))
  w.mouse = typeof(w.mouse)(pos[1], pos[2])
  onmouse(w, MouseMove(pos, w))
end

@testset "a drag before the new file is laid out leaves the caret" begin
  e.scroll.offset = 4000px; frames(2)
  K.open!(e, short)
  @test length(e.buf.lines) == 81 && e.layout[end].last > 81   # the layout is still the long page's
  w.keys |= Keys.mouse_left
  e.clicked = (time(), (1, 0), 1)
  was = e.buf.caret
  drag(300, 300)
  @test e.buf.caret == was
  # A line that this file has too, but shorter than the long page's line of that number
  e.scroll.offset = 0px
  drag(800, 120)
  @test e.buf.caret[1] <= 81 && e.buf.caret[2] <= length(e.buf.lines[e.buf.caret[1]])
  w.keys ⊻= Keys.mouse_left
end

@testset "once a frame has laid the file out, a drag moves the caret" begin
  frames(2)
  w.keys |= Keys.mouse_left
  e.buf.caret = e.buf.anchor = (1, 0)
  e.clicked = (time(), (1, 0), 1)
  drag(200, 200)
  @test e.buf.caret[1] > 1
  w.keys ⊻= Keys.mouse_left
end

close(w)
