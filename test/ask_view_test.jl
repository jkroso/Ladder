# Tests for the `ask` block of main.jl: a question with answers to choose. Run
# them with `julia -O0 --project=. test/ask_view_test.jl`. They click and type
# in a window that isn't on the screen. Set `LADDER_SHOTS` to a folder, and
# they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "plan.md")
write(page, """
# A plan

```ask
Which database should the app use?
( ) SQLite. It's one file, and needs no server, so there's nothing more to look after on the Mac that runs the app, and a copy of that one file is a copy of everything.
( ) Postgres
[ ] Keep a copy in the cloud
```

```ask
What should the button say?
```

```ask
How should the logo look?
Size: 48px (16px to 96px)
Colour: #e8632b
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
const (; frames, at, press, release, click, typed, shot) = drive(w)
frames()
ask(n) = e.nodes[(:block, K.ASK, page, n)]

block(n) = (s = K.block_lines(e.buf, K.ASK, n); e.buf.lines[s[1]+1:s[2]-1])
option(n, i) = middle(rect(ask(n).parts[(:option, i)]))

@testset "the block shows the question and its answers" begin
  v = ask(1)
  @test K.Asks.asked(v.data) == "Which database should the app use?" && length(v.data.options) == 3
  # A long answer wraps, so its row is taller than a short one's
  @test rect(v.parts[(:option, 1)]).height > rect(v.parts[(:option, 2)]).height
  @test any(en -> en.title == "Question", K.outline(e.buf))
  @test !K.dirty(e.buf)
end

@testset "a click chooses an answer" begin
  click(option(1, 2))
  @test block(1)[3] == "(x) Postgres" && startswith(block(1)[2], "( ) SQLite") && K.dirty(e.buf)
  click(option(1, 1))
  @test startswith(block(1)[2], "(x) SQLite") && block(1)[3] == "( ) Postgres"
  click(option(1, 3))
  @test block(1)[4] == "[x] Keep a copy in the cloud" && startswith(block(1)[2], "(x) SQLite")
  K.undo!(e.buf); frames()
  @test block(1)[4] == "[ ] Keep a copy in the cloud" && !ask(1).data.options[3].chosen
  @test e.buf.lines[end-1] == "The end."
  shot("ask.png")
end

@testset "the words of each row are level with its mark" begin
  middle_y(r) = K.num(r.top + r.height / 2)
  # The middle of the capitals of the first line, which is the only line of a short answer
  caps_middle(t) = K.num(t.top + K.skia_cap_height(t.from) / 2)
  click(option(1, 3))
  for i in 1:3                                   # a long answer that wraps, a round mark and a ticked box
    row = rect(ask(1).parts[(:option, i)])
    mark, words = row.children[1].children[1], row.children[2].children[1]
    @test abs(caps_middle(words) - middle_y(mark)) < 0.5
  end
  # The tick fills its box, so it's in the middle of it
  box = rect(ask(1).parts[(:option, 3)]).children[1].children[1]
  tick = box.children[1]
  @test (tick.left, tick.top, tick.width, tick.height) == (box.left, box.top, box.width, box.height)
  # The question is level with its icon
  head = rect(ask(1)).children[1]
  @test abs(caps_middle(head.children[2].children[1]) - middle_y(head.children[1].children[1])) < 0.5
  K.undo!(e.buf); frames()
  @test !ask(1).data.options[3].chosen
end

@testset "what's typed in the field goes under the answers" begin
  input = ask(2).parts[:input]
  click(middle(rect(input)))
  @test w.focus === input
  typed("Save")
  @test block(2) == ["What should the button say?", "> Save"]
  typed(" it")
  @test block(2)[2] == "> Save it" && K.Asks.answered(ask(2).data)
  # The letters were typed one soon after another, so one ⌘Z takes them all back
  K.undo!(e.buf); frames()
  @test block(2) == ["What should the button say?"] && input.text == ""
  K.redo!(e.buf); frames()
  @test block(2)[2] == "> Save it" && input.text == "Save it"
  # Return gives the keyboard back to the page
  onkey(w, KeyPress{Keys.enter}(0, w)); frames()
  @test w.focus === e && block(2)[2] == "> Save it"
  html = K.page_html(e)
  @test occursin("<strong>What should the button say?</strong>", html) && occursin("<blockquote>Save it</blockquote>", html)
  @test occursin("☑ <strong>SQLite", html) && occursin("☐ Postgres", html)
end

@testset "the page's own button sends the answers" begin
  # This process stands in for a script that waits for the page
  K.Agent.place[] = mktempdir()
  write(joinpath(K.Agent.folder(), "$(getpid()).wait"), realpath(page) * "\nClaude\n")
  delete!(e.nodes, :agents); frames()
  # A question has no button of its own that sends: the bell in the top bar does that, and ⌘Return
  @test !any(key -> key isa Tuple && first(key) == :button, keys(ask(1).parts))
  K.send!(e); frames()
  sent = read(joinpath(K.Agent.folder(), "$(getpid()).sent"), String)
  # The agent reads the answers in the lines that changed
  @test occursin("-( ) SQLite", sent) && occursin("+(x) SQLite", sent) && occursin("+> Save it", sent)
  saved = readlines(page)
  @test !K.dirty(e.buf) && saved[findfirst(==("What should the button say?"), saved) + 1] == "> Save it"
  K.Agent.place[] = ""
end

@testset "a slider and a colour picker write what you set into the block" begin
  v = ask(3)
  @test [f.kind for f in v.data.fields] == [:slider, :colour] && K.Asks.asked(v.data) == "How should the logo look?"
  slider, picker = K.ask_field(v, 1), K.ask_field(v, 2)
  @test slider isa K.Slider && (slider.value, slider.min, slider.max, slider.step) == (48, 16, 96, 1)
  @test picker isa K.ColorPicker && K.colour_hex(picker.color) == "#e8632b"
  # A click at the slider's left end sets it to the least it goes to, and the block's line says so
  r = rect(slider)
  click((K.num(r.left) + 1, middle(r)[2]))
  @test block(3) == ["How should the logo look?", "Size: 16px (16px to 96px)", "Colour: #e8632b"] && K.dirty(e.buf)
  # A colour that's picked is written as its line writes one
  picker.color = K.HSV(210, 0.8, 0.86); frames()
  @test block(3)[3] == "Colour: " * K.colour_hex(picker.color) && block(3)[3] != "Colour: #e8632b"
  html = K.page_html(e)
  @test occursin("Size: <strong>16px</strong>", html) && occursin("<strong>$(K.colour_hex(picker.color))</strong>", html)
  # ⌘Z puts the colour back, and the picker shows it
  K.undo!(e.buf); frames()
  @test block(3)[3] == "Colour: #e8632b" && K.colour_hex(picker.color) == "#e8632b"
  # A line that's typed sets the slider
  b = e.buf
  i = findfirst(l -> startswith(l, "Size: "), b.lines)
  K.edit!(b, (i, 6), (i, 8), "80")
  b.caret = b.anchor = (1, 0)   # with the caret in its lines, the block shows its code
  frames()
  @test slider.value == 80 && block(3)[2] == "Size: 80px (16px to 96px)"
  shot("ask values.png")
end
