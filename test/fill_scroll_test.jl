# Tests that the buttons beside a picture or a `view` block stay beside it
# while the page scrolls. See "The buttons beside a picture are put in place
# before the frame's layout" in main.jl. Run them with
# `julia -O0 --project=. test/fill_scroll_test.jl`. They draw in a window that
# isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window MouseMove onmouse onscroll
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "scroll.md")
cp(joinpath(K.pages_dir[], "photos", "3 roof.png"), joinpath(dir, "roof.png"))
words = "The roof went on in a week. Each sheet was screwed down at both ends and along the ridge."
write(page, """
# Scroll

$words

```view
roof.png
```

$(join(fill(words, 40), "\n\n"))
""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 700px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
# The caret is at the end of the page, so the view shows as a view and not as its lines
e.buf.caret = e.buf.anchor = (length(e.buf.lines), 0)
frames()

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames())
middle(r) = (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2)
const f = only(f for f in values(K.fills(e)) if f.parent isa K.ViewBlock)
"How far the top of the first button beside the view is from the top of the view"
gap() = K.num(rect(f.expand).top) - K.num(rect(f).top)

@testset "the buttons beside a view move with it in the frame that scrolls the page" begin
  at(middle(rect(f)))
  @test f.expand !== nothing && rect(f.expand) !== nothing
  @test gap() ≈ 0 atol=1
  for _ in 1:4
    was = K.num(rect(f).top)
    onscroll(w, Vec2{px}(px(0), px(-1)))
    frame(w)   # one frame only: the buttons are beside the view in the same frame that moved it
    @test K.num(rect(f).top) < was
    @test gap() ≈ 0 atol=1
  end
  # Back up again
  for _ in 1:4
    onscroll(w, Vec2{px}(px(0), px(1)))
    frame(w)
    @test gap() ≈ 0 atol=1
  end
end

@testset "a view that moves for another reason gets its buttons on the next frame, which comes at once" begin
  at(middle(rect(f)))
  @test gap() ≈ 0 atol=1
  was = K.num(rect(f).top)
  # A longer first paragraph pushes the view down, and the page doesn't scroll
  i = findfirst(==(words), e.buf.lines)
  K.edit!(e.buf, (i, length(words)), (i, length(words)), " " * words ^ 3)
  e.buf.caret = e.buf.anchor = (length(e.buf.lines), 0)
  frame(w)
  @test K.num(rect(f).top) > was
  @test w.wake < 0.01
  frame(w)
  @test gap() ≈ 0 atol=1
end
