# Tests for the card of a footnote, in main.jl: when the mouse rests on a
# footnote's number in the text, a card under the number shows the footnote.
# See "footnotes". Run them with `julia -O0 --project=. test/footnote_card_test.jl`.
# They use a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window Keys MouseMove onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame popups
@use GeometryBasics: Vec2
const px = K.px

"The words of each Text in the layout `x`, from the top"
texts(x) = begin
  hasfield(typeof(x), :content) && getfield(x, :content) isa AbstractString && return Any[x.content]
  out, c = Any[], hasfield(typeof(x), :firstchild) ? x.firstchild : nothing
  while c !== nothing
    append!(out, texts(c))
    c = c.nextsibling
  end
  out
end

# The folder has the same name each time, so that Kip compiles its files once
const dir = joinpath(tempdir(), "ladder-footnote-card-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
@eval K settings_file() = $(joinpath(dir, "settings"))
const page = joinpath(dir, "notes.md")
write(page, """
# Notes

Radiation takes 1% of the power each year.[^rad] Chips break too.[^none]

The end.

[^rad]: The rate that NASA measured for the cells of a satellite in **low orbit**.
""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 600px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()
const b = e.buf

"The middle of the footnote number `name` in line `i`, in the window"
number(i, name) = begin
  it = K.item(e, i)
  f = it.content
  for (k, vl) in enumerate(f.lines), s in vl.segs
    s.link == "^" * name && return (e.origin[1] + s.x + s.w / 2, e.origin[2] + it.top + K.line_top(f, k) + vl.high / 2)
  end
end
"Move the mouse to `(x, y)`, and draw the window"
move(x, y) = (w.mouse = typeof(w.mouse)(x, y); onmouse(w, MouseMove(Vec2{px}(x, y), w)); frames(2))
card() = only(filter(p -> p.key == K.NOTE_KEY, popups(w)))
shows() = any(p -> p.key == K.NOTE_KEY, popups(w))

@testset "the card of a footnote shows when the mouse rests on its number" begin
  at = number(3, "rad")
  @test K.note_at(e, at).name == "rad" && K.note_at(e, at).line == 3
  move(at...)
  # It waits a moment, so a mouse that only passes over the number shows nothing
  @test !shows()
  sleep(0.3); frames(2)
  @test shows()
  words = texts(card().content)
  @test "Footnote 1" in words
  # The footnote's text reads as the page does: its markup doesn't show
  @test K.note_card(e, "rad") !== nothing && !any(t -> occursin("**", t), words) && !any(t -> occursin("[^rad]", t), words)
  # It goes when the mouse leaves the number
  move(at[1] - 200px, at[2])
  @test !shows() && !haskey(e.nodes, :note_peek)
end

@testset "no card where there's no footnote to show" begin
  # A number whose footnote isn't there
  at = number(3, "none")
  move(at...); sleep(0.3); frames(2)
  @test K.note_at(e, at).name == "none" && K.note_card(e, "none") === nothing && !shows()
  # The number at the start of the footnote's own line
  i = findfirst(startswith("[^rad]:"), b.lines)
  @test K.note_at(e, number(i, "rad")) === nothing
  # While ⌘ is held, the card of a link shows, and this one doesn't
  at = number(3, "rad")
  w.keys |= Keys.cmd
  move(at...); sleep(0.3); frames(2)
  @test !shows()
  w.keys ⊻= Keys.cmd
  move(at[1] - 200px, at[2])
end
