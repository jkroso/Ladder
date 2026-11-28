# Tests for changing a diagram while it fills the window. See "a picture, a
# diagram or a page that fills the window" in main.jl. Run them with
# `julia -O0 --project=. test/diagram_edit_test.jl`. They click and type in a
# window that isn't on the screen. Set the environment variable DIAGRAM_SHOTS
# to a folder to keep a picture of each step.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle

const px = K.px
const D = K.Diagrams

const dir = mktempdir()
const page = joinpath(dir, "diagram.md")
const CODE = "flowchart LR\n  A[Write a page] --> B{Is it clear?}\n  B -- Yes --> C([Share it])\n  B -- No --> D[Change it]\n  D --> B"
write(page, """
# Diagrams

```ui
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" Mermaid
Mermaid("flowchart LR\\n  X --> Y")
```

Some words over it.

```mermaid
$CODE
```

Some words under it.
""")

const e = K.build_editor(page)
e.remember = false
const w = Window(e, size=(1100px, 800px))
const (; frames, at, press, release, click, key) = drive(w, moved=2)
frames()

const shots = get(ENV, "DIAGRAM_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

command(k, more...) = (foreach(m -> w.keys |= m, (Keys.cmd, more...)); key(k); foreach(m -> w.keys ⊻= m, (Keys.cmd, more...)))
type(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
view() = K.zooming(e)
"The lines of the page's `mermaid` block, as one text"
block() = K.diagram_code(e.buf, 1)
"The place in the window of the words of a part of the diagram that fills it"
spot(which) = (v = view(); p = D.part(K.changing(v), which).words; (v.box[1] + (p[1] - v.at[1]) * v.zoom, v.box[2] + (p[2] - v.at[2]) * v.zoom))
"The names of the tools that have a button under the diagram now"
tool_names() = [t.name for t in D.tools(K.changing(view()))]
tool_button(name) = view().parts[(:button, (:tool, name))]

shown(code) = only(n for n in values(e.nodes) if n isa K.Shown && n.value isa K.Mermaid && n.value.code == code)

@testset "a diagram in the page takes no click" begin
  s = shown(CODE)
  @test !s.value.editing && isempty(D.tools(s.value))
  click(middle(rect(s.value)))
  @test s.value.picked === nothing && view() === nothing
end

@testset "the diagram of a block can be changed once it fills the window" begin
  K.zoom_in!(e, (:diagram, CODE), shown(CODE))
  frames()
  v = view()
  @test v !== nothing && v.block == 1
  m = K.changing(v)
  @test m !== nothing && m.editing && !m.bar
  # The tools for the whole diagram have buttons, before the ones that change its size
  @test tool_names() == [:add, :way]
  @test K.num(rect(tool_button(:add)).left) < K.num(rect(v.parts[(:button, :smaller)]).left)
  shot("1-filled")
end

@testset "a click selects a part, and its tools show" begin
  m = K.changing(view())
  click(spot((:box, "B")))
  @test m.picked == (:box, "B")
  @test tool_names() == [:add, :join, :shape, :delete]
  shot("2-selected")
  click(spot((:line, 2)))
  @test m.picked == (:line, 2) && tool_names() == [:look, :turn, :delete]
  # A click where nothing is selects nothing, and a drag still moves the diagram
  v = view()
  click((v.box[1] + 4, v.box[2] + 4))
  @test m.picked === nothing
  # A drag that starts on a box moves the diagram and selects nothing
  from = spot((:box, "B"))
  press(from)
  at((from[1] + 60, from[2] + 20))
  release()
  @test m.picked === nothing
end

@testset "two clicks type the words of a part, and the block's lines change" begin
  m = K.changing(view())
  click(spot((:box, "A")))
  click(spot((:box, "A")))
  @test m.typing == (:box, "A") && w.focus === m.field && m.field.text == "Write a page"
  command(Keys.a)
  type("Draft it")
  shot("3-typing")
  key(Keys.enter)
  @test m.typing === nothing
  @test block() == replace(CODE, "A[Write a page]" => "A[Draft it]")
  @test view().what == (:diagram, block())
  @test w.focus === view().parts[:area]
  # The page's own text is as it was
  @test e.buf.lines[1] == "# Diagrams" && "Some words under it." in e.buf.lines
  # ⌘Z takes the change back, in the block and in the window
  command(Keys.z)
  @test block() == CODE && view().what == (:diagram, CODE) && m.code == CODE
  command(Keys.z, Keys.shft)
  @test block() == replace(CODE, "A[Write a page]" => "A[Draft it]")
  command(Keys.z)
  # Esc leaves the words as they were. This click is long after the two above. In a process that has run this code
  # before, it comes within the 0.4 s of a second click, and would start the typing itself.
  m.clicked = (0.0, 0.0, 0.0)
  click(spot((:box, "A")))
  @test m.typing === nothing
  key(Keys.enter)
  @test m.typing == (:box, "A")
  type("x")
  key(Keys.escape)
  @test m.typing === nothing && block() == CODE && view() !== nothing
end

@testset "the tools add a box, draw a line and take a part away" begin
  m = K.changing(view())
  click(spot((:box, "C")))
  click(middle(rect(tool_button(:add))))
  @test m.picked == (:box, "E") && m.typing == (:box, "E")
  @test endswith(block(), "\n  C --> E[New box]")
  type("Print it")
  key(Keys.enter)
  @test endswith(block(), "\n  C --> E[Print it]")
  shot("4-added")
  # The tool that draws a line waits for a click on another box, and its button is lit
  click(middle(rect(tool_button(:join))))
  @test m.waiting == :join && view().tool == :join
  click(spot((:box, "A")))
  @test m.waiting === nothing && endswith(block(), "\n  E --> A") && m.picked == (:line, 6)
  # ⌫ takes the line away
  key(Keys.backspace)
  @test !occursin("E --> A", block()) && m.picked === nothing
  # A tool with choices shows them in a menu
  click(spot((:box, "E")))
  click(middle(rect(tool_button(:shape))))
  frames()
  shot("4b-menu")
  D.use!(m, :shape, :stadium)
  frames()
  @test endswith(block(), "\n  C --> E([Print it])")
  K.hide_menu!(w)
  frames()
end

@testset "a drag from a box's point onto another box draws a line" begin
  v = view()
  m = K.changing(v)
  window_spot(p) = (v.box[1] + (p[1] - v.at[1]) * v.zoom, v.box[2] + (p[2] - v.at[2]) * v.zoom)
  area = v.parts[:area]
  # The box under the mouse shows its point, in the middle of its right side since the diagram goes right
  at(spot((:box, "A")))
  @test m.hovered !== nothing && (m.hovered.kind, m.hovered.key) == (:box, "A") && !m.on_point
  point = window_spot(D.point_of(m, D.part(m, (:box, "A"))))
  at(point)
  @test m.on_point && K.cursor(area) == :crosshair
  shot("4c-point")
  # A drag from the point follows the mouse, and doesn't move the diagram
  was = v.at
  press(point)
  @test m.joining !== nothing && v.grab === nothing
  at(spot((:box, "D")))
  @test D.landing(m) !== nothing && D.landing(m).key == "D" && v.at == was
  shot("4d-joining")
  # Over box D the button comes up, and the line from A to D is in the block's lines
  release()
  @test m.joining === nothing
  @test endswith(block(), "\n  A --> D")
  @test m.picked[1] == :line
  # ⌫ takes it away again
  key(Keys.backspace)
  @test !occursin("A --> D", block())
  # The point goes when the mouse leaves the boxes
  at((v.box[1] + 2, v.box[2] + 2))
  @test m.hovered === nothing && K.cursor(area) == :arrow
end

@testset "Esc selects nothing, and then puts the page back" begin
  m = K.changing(view())
  click(spot((:box, "B")))
  key(Keys.escape)
  @test m.picked === nothing && view() !== nothing
  key(Keys.escape)
  @test view() === nothing
  frames()
  # The page shows the diagram as it is now
  @test shown(block()) !== nothing
end

@testset "a diagram that the code of a live block made can't be changed" begin
  s = shown("flowchart LR\n  X --> Y")
  K.zoom_in!(e, (:diagram, s.value.code), s)
  frames()
  v = view()
  @test v !== nothing && v.block == 0 && K.changing(v) === nothing
  @test !haskey(v.parts, (:button, (:tool, :add))) || rect(v.parts[(:button, (:tool, :add))]) === nothing
  click(middle((left=px(v.box[1]), top=px(v.box[2]), width=px(v.box[3]), height=px(v.box[4]))))
  @test v.parts[:diagram].picked === nothing
  key(Keys.escape)
  @test view() === nothing
end

"Open a page that holds only the diagram `code`, and make the diagram fill the window"
fill(name, code) = begin
  path = joinpath(dir, name * ".md")
  write(path, "# " * name * "\n\n```mermaid\n" * code * "\n```\n\nThe end.\n")
  K.open!(e, path)
  frames(3)
  K.zoom_in!(e, (:diagram, code), shown(code))
  frames()
  K.changing(view())
end

@testset "a sequence diagram: a message from one of them to another" begin
  m = fill("sequence", "sequenceDiagram\n  participant A as Alice\n  actor B as Bob\n  A->>B: Hello\n  Note over A,B: They talk")
  @test m !== nothing && tool_names() == [:add]
  click(spot((:person, "B")))
  @test m.picked == (:person, "B") && tool_names() == [:message, :note, :drawn, :delete]
  click(middle(rect(tool_button(:message))))
  click(spot((:person, "A")))
  @test m.typing == (:message, 2) && m.field.text == "Message"
  type("Hi")
  shot("5-sequence")
  key(Keys.enter)
  @test endswith(block(), "\n  B->>A: Hi")
  click(spot((:message, 1)))
  @test m.picked == (:message, 1) && tool_names() == [:look, :turn, :up, :down, :delete]
  key(Keys.backspace)
  @test !occursin("Hello", block())
  command(Keys.z)
  @test occursin("A->>B: Hello", block())
  key(Keys.escape); key(Keys.escape)
  @test view() === nothing
end

@testset "a state diagram: a state after the selected one" begin
  m = fill("state", "stateDiagram-v2\n  [*] --> Still\n  Still --> Moving : push\n  Moving --> [*]")
  click(spot((:state, "Moving")))
  @test tool_names() == [:add, :join, :start, :stop, :note, :delete]
  click(middle(rect(tool_button(:add))))
  @test m.typing == (:state, "S1")
  type("Stopped")
  shot("6-state")
  key(Keys.enter)
  @test endswith(block(), "\n  Moving --> S1\n  S1 : Stopped")
  click(spot((:move, 2)))
  click(spot((:move, 2)))
  @test m.typing == (:move, 2) && m.field.text == "push"
  key(Keys.escape); key(Keys.escape); key(Keys.escape)
  @test view() === nothing
end

@testset "a class diagram: a line of a class, and another name for it" begin
  m = fill("class", "classDiagram\n  class Animal {\n    +String name\n  }\n  Animal <|-- Dog")
  click(spot((:class, "Dog")))
  @test tool_names() == [:line, :join, :add, :note, :delete]
  click(middle(rect(tool_button(:line))))
  @test m.typing == (:member, ("Dog", 1))
  type("+bark()")
  key(Keys.enter)
  @test endswith(block(), "\n  Dog : +bark()")
  # A click on a line of a class selects the line, and a click on the name selects the class
  click(spot((:member, ("Animal", 1))))
  @test m.picked == (:member, ("Animal", 1))
  click(spot((:class, "Dog")))
  key(Keys.enter)
  command(Keys.a)
  type("Hound")
  shot("7-class")
  key(Keys.enter)
  @test occursin("Animal <|-- Hound", block()) && occursin("Hound : +bark()", block()) && m.picked == (:class, "Hound")
  key(Keys.escape); key(Keys.escape)
end

@testset "a pie chart: the name and the number of a slice" begin
  m = fill("pie", "pie title Pets\n  \"Dogs\" : 30\n  \"Cats\" : 10")
  @test tool_names() == [:add, :numbers]
  click(spot((:slice, 2)))
  @test m.picked == (:slice, 2)
  key(Keys.enter)
  @test m.field.text == "Cats: 10"
  command(Keys.a)
  type("Birds: 25")
  shot("8-pie")
  key(Keys.enter)
  @test block() == "pie title Pets\n  \"Dogs\" : 30\n  \"Birds\" : 25"
  click(middle(rect(tool_button(:add))))
  type("Fish: 5")
  key(Keys.enter)
  @test endswith(block(), "\n  \"Fish\" : 5")
  key(Keys.escape); key(Keys.escape)
  @test view() === nothing
end
