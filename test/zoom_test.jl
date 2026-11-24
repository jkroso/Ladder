# Tests for the view that fills the window with a picture, a diagram, a page
# of a PDF file or a model. See "a picture, a diagram or a page that fills the
# window" in main.jl. Run them with `julia -O0 --project=. test/zoom_test.jl`. They
# click, pinch and type in a window that isn't on the screen. Set the
# environment variable ZOOM_SHOTS to a folder to keep a picture of each step.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype onscroll
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect onpinch hittest MouseScroll
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

@use "../main" => K
const px = K.px

const dir = mktempdir()
cp(joinpath(@__DIR__, "..", "pages", "plan.pdf"), joinpath(dir, "plan.pdf"))
cp(joinpath(@__DIR__, "..", "pages", "knot.stl"), joinpath(dir, "knot.stl"))
# The picture is the plan, made into a PNG file by macOS
run(pipeline(`sips -s format png $(joinpath(dir, "plan.pdf")) --out $(joinpath(dir, "shot.png"))`, stdout=devnull, stderr=devnull))
const page = joinpath(dir, "zoom.md")
const DIAGRAM = """
flowchart LR
  subgraph Desk[On the desk]
    A[Write the first draft] --> B[Read it aloud]
    N[Add notes and pictures]
  end
  B --> C{{Find what doesn't read well}}
  C --> D[A second draft with a note on each part]
  N --> D
  D --> E[Change the second draft]
  E --> F[Send it to the editor]
  F --> G[(The editor's files)]
  G --> H[The printer]
"""
write(page, """
# Zoom

```mermaid
$(DIAGRAM)```

![a shot](shot.png)

```ui
@use "github.com/jkroso/URI.jl/FSPath" FSPath
FSPath("$(joinpath(dir, "plan.pdf"))")
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1400px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()

const shots = get(ENV, "ZOOM_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames())
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())
command(k) = (w.keys |= Keys.cmd; key(k); w.keys ⊻= Keys.cmd)
middle(r) = (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2)
"A place `dx` px in from the right edge of `r` and `dy` px down from its top"
corner(r, dx=22, dy=22) = (K.num(r.left) + K.num(r.width) - dx, K.num(r.top) + dy)
fillable_of(owner) = K.fills(e)[objectid(owner)]
button(owner) = fillable_of(owner).button
"True when the button that makes what `owner` shows fill the window is in the window"
showing(owner) = (b = button(owner); b !== nothing && rect(b) !== nothing)
view() = K.zooming(e)

const diagram = only(n for n in values(e.nodes) if n isa K.Shown && n.value isa K.Mermaid)
const picture = only(n for n in values(e.nodes) if n isa K.Picture)

@testset "the button shows beside a diagram while the mouse is over it" begin
  r = rect(fillable_of(diagram))
  @test r !== nothing
  at((5, 5))
  @test !showing(diagram)
  at(middle(r))
  @test showing(diagram)
  shot("1-hover")
  # It's beside the diagram's top right corner, so it covers none of the diagram
  b = rect(button(diagram))
  @test K.num(b.left) >= K.num(r.left) + K.num(r.width)
  @test K.num(b.top) ≈ K.num(r.top) atol=1
  # It stays while the mouse goes to it, and goes once the mouse leaves both
  at(middle(b))
  @test showing(diagram)
  at((K.num(b.left) + 60, K.num(b.top) + 10))
  @test !showing(diagram)
end

@testset "where the window has no room beside the top right corner, the button goes elsewhere" begin
  box(left, wide) = (left=px(left), top=px(300), width=px(wide), height=px(200))
  W = K.num(K.window_size(e)[1])
  # Room on the right
  @test K.fill_spot(e, box(100, 400)) == (px(504), px(300))
  # None on the right: beside the top left corner
  @test K.fill_spot(e, box(40, W - 50)) == (px(12), px(300))
  # None on either side: in the top right corner
  @test K.fill_spot(e, box(10, W - 20)) == (px(W - 10 - 4 - 24), px(304))
  # A picture whose top is under the top bar has its button under the top bar
  @test K.fill_spot(e, (left=px(100), top=px(-50), width=px(400), height=px(300)))[2] == K.TOPBAR_H + K.FILL_GAP
end

@testset "the button makes the diagram fill the window" begin
  at(middle(rect(fillable_of(diagram))))
  click(middle(rect(button(diagram))))
  v = view()
  @test v !== nothing
  @test v.what == (:diagram, rstrip(DIAGRAM))
  @test v.zoom > 0 && v.fits
  # Fitted to the window, the diagram is far wider than it is in the page
  @test K.subject_size(v)[1] * v.zoom > 1.2 * K.num(rect(diagram.value).width)
  shot("2-filled")
end

@testset "pinch, ⌘ and scroll, and the keys make it bigger and smaller" begin
  v = view()
  fit = v.zoom
  m = K.view_middle(v)
  w.mouse = typeof(w.mouse)(px(m[1]), px(m[2]))
  under = (v.at[1] + (m[1] - v.box[1]) / v.zoom, v.at[2] + (m[2] - v.box[2]) / v.zoom)
  onpinch(w, 1.5); frames()
  @test v.zoom ≈ 1.5fit
  @test !v.fits
  # The point of the diagram that was under the mouse is still under it
  @test v.box[1] + (under[1] - v.at[1]) * v.zoom ≈ m[1] atol=1
  @test v.box[2] + (under[2] - v.at[2]) * v.zoom ≈ m[2] atol=1
  shot("3-pinched")
  w.keys |= Keys.cmd
  onscroll(w, Vec2{px}(px(0), px(2))); frames()
  w.keys ⊻= Keys.cmd
  @test v.zoom > 1.5fit
  command(getproperty(Keys, Symbol(0)))
  @test v.zoom ≈ fit && v.fits
  command(Keys.equal)
  @test v.zoom ≈ fit * K.ZOOM_STEP
  command(Keys.minus)
  @test v.zoom ≈ fit
  # Never smaller than the whole of it, or than its own size
  foreach(_ -> command(Keys.minus), 1:10)
  @test v.zoom ≈ min(fit, 1.0)
  command(getproperty(Keys, Symbol(0)))
end

@testset "a drag and a scroll move it, as far as its edges" begin
  v = view()
  onpinch(w, 3.0); frames()
  was = v.at
  m = K.view_middle(v)
  press(m)
  at((m[1] - 100, m[2] - 40))
  release()
  @test v.at[1] ≈ was[1] + 100 / v.zoom atol=0.01
  was = v.at
  onscroll(w, Vec2{px}(px(-1), px(0))); frames()
  @test v.at[1] ≈ was[1] + 30 / v.zoom atol=0.01
  # However far it's dragged, its edge stops near the edge of the view
  press(m)
  at((m[1] + 5000, m[2]))
  release()
  @test v.at[1] ≈ -K.ZOOM_EDGE / v.zoom
end

@testset "typing doesn't change the page under it, and esc puts the page back" begin
  lines = copy(e.buf.lines)
  ontype(w, Typed('x', w)); frames()
  key(Keys.backspace)
  key(Keys.enter)
  @test e.buf.lines == lines
  key(Keys.escape)
  @test view() === nothing
  @test w.focus === e
end

@testset "a pinch outwards on a picture makes it fill the window" begin
  r = rect(fillable_of(picture))
  @test r !== nothing
  at(middle(r))
  onpinch(w, 0.9); frames()
  @test view() === nothing   # inwards does nothing
  onpinch(w, 1.1); frames()
  v = view()
  @test v !== nothing && v.what == (:picture, picture.key)
  @test v.zoom > 0
  shot("4-picture")
  click(middle(rect(v.parts[(:button, :close)])))
  @test view() === nothing
end

@testset "a page of a PDF file under a path fills the window, and its pages turn" begin
  # A click on the path's last name shows the preview. It's under the bottom of the window, and the page only makes what's in the window.
  crumb = only(n.value for n in values(e.nodes) if n isa K.Shown && n.value isa K.Breadcrumb)
  crumb.open = true
  frames()
  at((500, 700))
  onscroll(w, Vec2{px}(px(0), px(-40))); frames(3)
  pages = crumb.viewer
  @test pages isa K.Pages
  r = rect(pages)
  @test r !== nothing
  at(corner(r, 30, 30))
  @test showing(pages)
  click(middle(rect(button(pages))))
  v = view()
  @test v !== nothing && v.what[1] == :pdf && v.page == 1
  frames(3)
  shot("5-pdf")
  # A pinch makes the page sharp again once it stops moving
  onpinch(w, 4.0); frames()
  sleep(K.SETTLED + 0.05); frames()
  @test v.sharp.of !== nothing && v.sharp.of[4] ≈ v.zoom * 2
  shot("6-pdf-near")
  if v.pages > 1
    key(Keys.right)
    @test v.page == 2 && v.fits
    key(Keys.escape)
    @test pages.page == 2   # the page in the document goes on from there
  else
    key(Keys.escape)
  end
  @test view() === nothing
end

@testset "a model fills the window, and the page keeps its room" begin
  K.open!(e, joinpath(dir, "knot.stl"))
  frames(3)
  fv = only(n for n in values(e.nodes) if n isa K.FileView && n.path == joinpath(dir, "knot.stl"))
  m = fv.viewer
  @test m isa K.STLViewer
  r = rect(m)
  @test r !== nothing
  tall = m.height
  at(middle(r))
  click(middle(rect(button(fv))))
  v = view()
  @test v !== nothing && v.what[1] == :node && v.what[2] === m
  frames(2)
  @test m.height > tall
  @test K.num(rect(m).height) > K.num(r.height)
  shot("7-model")
  # A pinch on it zooms the model, as it does in the page
  z = m.zoom
  at(middle(rect(m)))
  onpinch(w, 1.3); frames()
  @test m.zoom ≈ 1.3z
  key(Keys.escape)
  @test view() === nothing
  frames(2)
  @test m.height == tall
end

@testset "a glTF model shows what it's made of" begin
  cp(joinpath(@__DIR__, "..", "pages", "satellite.glb"), joinpath(dir, "satellite.glb"))
  K.open!(e, joinpath(dir, "satellite.glb"))
  frames(3)
  fv = only(n for n in values(e.nodes) if n isa K.FileView && n.path == joinpath(dir, "satellite.glb"))
  m = fv.viewer
  @test m isa K.STLViewer && m.model isa K.Mesh
  # The satellite has ten materials, and the file's first is for a part that names none
  @test m.model.look !== nothing && length(m.model.look.materials) == 11
  # Its wings span 70 metres
  @test 69 < m.model.size[1] < 71
  shot("8-satellite")
end

@testset "it closes when another document shows" begin
  K.open!(e, page)
  frames(3)
  s = only(n for n in values(e.nodes) if n isa K.Shown && n.value isa K.Mermaid)
  K.zoom_in!(e, (:diagram, s.value.code), s)
  frames()
  @test view() !== nothing
  K.open!(e, joinpath(dir, "shot.png"))
  frames()
  @test view() === nothing
end
