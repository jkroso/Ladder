# Tests for the top bar while something fills the window: a schedule, the
# lines of a schedule as text, or a diagram. The sidebar isn't there then, so
# the bar has none of the sidebar's buttons. Run them with
# `julia -O0 --project=. test/full_bar_test.jl`. They draw in a window that
# isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save a
# picture of each step there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "bathroom.md")
write(page, """
# The bathroom

```schedule
```

- [ ] Tile the floor

```mermaid
flowchart LR
  A[Measure the room] --> B[Draw it]
```

The end.
""")
write(joinpath(dir, "other.md"), "# Another page\n")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
e.panel = true   # the sidebar shows
# The window showed another file before, so the arrow that goes back has a file to go to
K.open!(e, joinpath(dir, "other.md")); K.open!(e, page)
frames(3)
const v = K.block_view(e, K.SCHEDULE, 1)
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())

"The buttons of the top bar, as what each one does"
buttons(node=K.describe(e.nodes[:topbar]), out=Symbol[]) = begin
  (node isa K.GeometricUI && !(node isa K.Text)) || return out
  hasproperty(node, :from) && node.from isa K.ToolButton && push!(out, node.from.action)
  foreach(n -> buttons(n, out), node.children)
  out
end
const SIDEBAR_BUTTONS = [:panel, :hidden, :back, :forward]
"How far the middle of the file's name is from the left edge of the window"
name_middle() = (r = rect(e.nodes[:title]); K.num(r.left + r.width / 2))
"True when the file's name is in the middle of the window"
centred() = abs(name_middle() - 500) <= 1

@testset "the sidebar's buttons while the page shows" begin
  @test buttons() == SIDEBAR_BUTTONS && !K.filled(e)
  # The name is in the middle of the space beside the sidebar
  @test abs(name_middle() - (K.num(K.panel_w(e)) + 1000) / 2) <= 1
  shot("bar-page.png")
end

@testset "a schedule that fills the window" begin
  K.full!(v, true); frames()
  @test K.filled(e) && e.panel
  @test isempty(buttons()) && centred()
  shot("bar-schedule.png")
  # Back in the page, the buttons come back
  K.full!(v, false); frames()
  @test !K.filled(e) && buttons() == SIDEBAR_BUTTONS && !centred()
end

@testset "the lines of a schedule that fill the window" begin
  K.full!(v, true); frames()
  K.level!(e); frames()
  @test K.lowered(e) !== nothing && !v.full && K.filled(e)
  @test isempty(buttons()) && centred()
  shot("bar-lines.png")
  key(Keys.escape)
  @test K.lowered(e) === nothing && buttons() == SIDEBAR_BUTTONS
  K.plain!(e, false); frames()
end

@testset "a diagram that fills the window" begin
  s = only(n for n in values(e.nodes) if n isa K.Shown && n.value isa K.Mermaid)
  K.zoom_in!(e, (:diagram, s.value.code), s); frames()
  @test K.zooming(e) !== nothing && K.filled(e)
  @test isempty(buttons()) && centred()
  shot("bar-diagram.png")
  key(Keys.escape)
  @test K.zooming(e) === nothing && buttons() == SIDEBAR_BUTTONS
end

@testset "a closed sidebar" begin
  # The button that shows the sidebar goes too
  K.toggle_panel!(e); e.slid = 0.0; frames()
  @test buttons() == [:panel]
  K.full!(v, true); frames()
  @test isempty(buttons()) && centred()
  K.full!(v, false); frames()
  @test buttons() == [:panel]
end
