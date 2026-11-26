# Tests for the code of a thing, in main.jl: a click with ⌘ and ⌥ down keeps
# a line round the thing, with buttons on its top edge. Show Code there, or
# Show Code in the palette with the thing as its node, shows the method of
# `describe` that draws the thing, in a window beside this one. Change and
# Explain there open the palette with the thing. Code that
# runs in that window runs in the module that the file made, so a new method
# draws the thing at once. Run them with
# `julia -O0 --project=. test/show_code_test.jl`.
# They click in windows that aren't on the screen. Set `LADDER_SHOTS` to a
# folder, and they save a picture of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect _cursor_shape
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px

# The folder has the same name each time, so that Kip compiles its file once
const dir = joinpath(tempdir(), "ladder-show-code-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const page = joinpath(dir, "tank.md")
const source = joinpath(dir, "gauge.jl")

# A kind of block with a node of its own, which counts the clicks that it gets
write(source, """
@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl" Keys KeyPress onkey
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe handled

"How full a tank is"
@def mutable struct Gauge <: SemanticUI
  level::Int = 0
  clicks::Int = 0
end

gauge(lines) = Gauge(level=something(tryparse(Int, strip(get(lines, 1, ""))), 0))

"A bar as wide as the tank is full"
describe(g::Gauge) =
  Box(width(200px), height(30px), background("steelblue"))

onkey(g::Gauge, ::KeyPress{Keys.mouse_left}) = (g.clicks += 1; handled)
""")
write(page, "# A tank\n\n```gauge\n3\n```\n\nThe end.\n")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 600px))
# Each frame is drawn with the newest code, as the app's own loop draws it
frames(win=w, n=2) = foreach(_ -> Base.invokelatest(frame, win), 1:n)
frames(w, 4)
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

node() = e.nodes[(:block, "gauge", page, 1)].value
over() = begin
  r = rect(node())
  x, y = r.left + r.width / 2, r.top + r.height / 2
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  frames(w, 1)
end
click(held...) = begin
  over()
  foreach(h -> w.keys |= h, held)
  frames(w, 1)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
"The window's tool, which draws the line round a thing and the buttons on it"
picker() = K.code_picker(e)
"What the buttons on the line round the thing that a click with ⌘ and ⌥ down chose do, as the last frame drew them"
buttons() = [a for (a, _) in picker().buttons if a != :label]
"Where the last frame drew the button `action`, or the label for `:label`"
button(action) = last(only(b for b in picker().buttons if b[1] == action))
"Click the button `action` on the line round the thing that a click with ⌘ and ⌥ down chose"
press_button(action) = begin
  left, top, wide, tall = button(action)
  x, y = px(left + wide / 2), px(top + tall / 2)
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  frames(w, 1)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames()
end
"The cursor that the window shows with the mouse at the middle of the place `(left, top, wide, tall)`"
cursor_at((left, top, wide, tall)) = begin
  x, y = px(left + wide / 2), px(top + tall / 2)
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  get(_cursor_shape, objectid(w), :arrow)
end
"The editors of the windows that show the file of code"
code_windows() = filter(o -> o !== e && o.buf.path == realpath(source), K.editors)
const first_line = findfirst(startswith("describe(g::Gauge)"), readlines(source))

@testset "the method that draws a thing" begin
  @test nameof(typeof(node())) == :Gauge
  m = K.drawn_by(node())
  @test m isa Method && K.code_place(m) == (realpath(source), first_line)
  @test K.code_label(m) == "gauge.jl:$first_line"
  @test K.drawn_by(3) === nothing
  # A method of Julia's own is in Julia's folder of code: Base's by its place in Base's folder, the standard library's by the
  # path of the Mac that built Julia. A method that code made with no file has none.
  trig = which(sin, Tuple{Float64})
  @test K.code_place(trig) == (realpath(Base.find_source_file(String(trig.file))), trig.line)
  @test K.code_place(which(K.Dates.year, Tuple{K.Dates.Date}))[1] == realpath(Base.fixup_stdlib_path(String(which(K.Dates.year, Tuple{K.Dates.Date}).file)))
  @test K.code_place(only(methods(Core.eval(Module(), Base.remove_linenums!(:(nofile(x) = x)))))) === nothing
  # Ladder shows Julia's own files and never changes them, as it does an email
  @test K.protected(K.code_place(trig)[1]) && !K.protected(realpath(source))
  # The built app says where it wrote each file that the Mac that built it had
  other = joinpath(dir, "copy.jl")
  write(other, "1\n")
  K.SOURCE_FILES[String(m.file)] = other
  @test K.code_place(m) == (realpath(other), first_line)
  delete!(K.SOURCE_FILES, String(m.file))
  @test K.code_label(which(K.describe, Tuple{K.Editor})) == "Ladder/main.jl:$(which(K.describe, Tuple{K.Editor}).line)"
end

@testset "a click with ⌘ and ⌥ down shows the code" begin
  # A click with no key down is the block's own
  click()
  @test node().clicks == 1 && isempty(code_windows())
  # With only one of the two keys down, too
  click(Keys.cmd)
  @test isempty(code_windows())
  # And with ⇧ or ⌃ down as well, as with a key that holds all four
  t = K.code_picker(e)
  for others in ((Keys.shft,), (Keys.ctrl,), (Keys.shft, Keys.ctrl))
    foreach(h -> w.keys |= h, (Keys.cmd, Keys.opt, others...))
    @test !K.picks(t, w)
    foreach(h -> w.keys ⊻= h, (Keys.cmd, Keys.opt, others...))
  end
  n = node().clicks
  click(Keys.cmd, Keys.opt, Keys.shft, Keys.ctrl)
  @test node().clicks == n + 1 && isempty(code_windows())
  n = node().clicks
  over()
  w.keys |= Keys.cmd; w.keys |= Keys.opt
  frames()
  shot("show-code-line.png")
  w.keys ⊻= Keys.cmd; w.keys ⊻= Keys.opt
  click(Keys.cmd, Keys.opt)
  # The block didn't get the click. Its line stays after the keys went up, with a button for each thing to do with it.
  @test node().clicks == n && isempty(code_windows())
  @test picker().chosen[1] === node() && buttons() == [:show_code, :ask_agent]
  # The label and the buttons are in a row on the line's top edge, the label first
  r = rect(node())
  label = button(:label)
  @test label[2] == K.num(r.top) - 18 && all(b -> last(b)[2] == label[2], picker().buttons)
  @test label[1] + label[3] < button(:show_code)[1] < button(:ask_agent)[1]
  # Ask Agent's button is as wide as it's tall, for the agent's logo
  @test button(:ask_agent)[3] == button(:ask_agent)[4] == 18
  # The cursor is a hand over each button, and not over the label, which does nothing
  @test all(a -> cursor_at(button(a)) == :hand, buttons())
  @test cursor_at(label) != :hand
  gone = button(:ask_agent)
  # A click on the label does nothing
  press_button(:label)
  @test picker().chosen !== nothing && isempty(code_windows()) && node().clicks == n
  # Esc takes the line and its buttons away
  onkey(w, KeyPress{Keys.escape}(0, w)); frames()
  @test picker().chosen === nothing && isempty(picker().buttons) && isempty(code_windows()) && e.popup == :none
  @test cursor_at(gone) != :hand
  # So does a click anywhere else, and the click goes on to what it's on
  click(Keys.cmd, Keys.opt)
  @test picker().chosen !== nothing
  click()
  @test picker().chosen === nothing && node().clicks == n + 1
  n = node().clicks
  # Show Code shows a window with the file, with the caret on the method, and the line goes
  click(Keys.cmd, Keys.opt)
  press_button(:show_code)
  @test picker().chosen === nothing && node().clicks == n
  shown = code_windows()
  @test length(shown) == 1
  @test shown[1].buf.caret[1] == first_line
  @test !shown[1].panel
end

@testset "the agent's logo on the line opens the palette with the thing as A" for command in (:ask_agent,)
  n = node().clicks
  click(Keys.cmd, Keys.opt)
  press_button(command)
  p = K.palette(e)
  @test e.popup == :commands && p.command.name == command && node().clicks == n && picker().chosen === nothing
  c = K.chip_value(p, K.palette_chips(p), 1)
  @test c isa K.ToChange && c.node === node() && c.file == realpath(source) && c.first <= first_line <= c.last
  # The keyboard is in the words of the change, which have nothing yet
  @test p.at == 2 && K.chip_value(p, K.palette_chips(p), 2) === K.UNSAID
  # Esc empties the bar, and a second Esc closes the palette
  foreach(_ -> (onkey(w, KeyPress{Keys.escape}(0, w)); frames(w, 1)), 1:2)
  p.moved = 0.0
  frames()
  @test e.popup == :none
end

@testset "Show Code takes what the caret is on, or what a click chooses" begin
  shown = only(code_windows())
  shown.buf.caret = shown.buf.anchor = (1, 0)
  # The caret on the block: Show Code has the block's thing as A, and Return shows its code
  K.focus(e)
  e.buf.caret = e.buf.anchor = (3, 0)
  frames()
  press(k, held...) = (foreach(h -> w.keys |= h, held); onkey(w, KeyPress{k}(0, w)); foreach(h -> w.keys ⊻= h, held); haskey(e.nodes, :palette) && (e.nodes[:palette].moved = 0.0); frames())
  press(Keys.p, Keys.cmd, Keys.shft)
  foreach(c -> ontype(w, Typed(c, w)), "show code"); frames()
  press(Keys.enter)
  p = K.palette(e)
  @test p.command.name == :show_code && K.chip_value(p, K.palette_chips(p), 1).node === node() && e.popup == :commands
  press(Keys.enter)
  @test e.popup == :none && shown.buf.caret[1] == first_line
  # A click chooses the thing and shows its code at once. The thing doesn't get the click.
  shown.buf.caret = shown.buf.anchor = (1, 0)
  e.buf.caret = e.buf.anchor = (7, 0)
  frames()
  press(Keys.p, Keys.cmd, Keys.shft)
  foreach(c -> ontype(w, Typed(c, w)), "show code"); frames()
  press(Keys.enter)
  @test K.chip_value(p, K.palette_chips(p), 1).node isa K.Document
  n = node().clicks
  click()
  @test e.popup == :none && node().clicks == n && shown.buf.caret[1] == first_line
  # The click after that is the block's own again, once the bar has slid down
  e.nodes[:palette].moved = 0.0
  frames()
  click()
  @test node().clicks == n + 1
end

@testset "code that runs in the file's window changes what's loaded" begin
  shown = only(code_windows())
  m = K.page_module(shown, realpath(source))
  @test m === Kip.modules[realpath(source)]
  @test K.workspace(shown) === m
  @test rect(node()).width == 200px
  value, printed, failed = K.run_code(shown, "describe(g::Gauge) = Box(width(40px * g.level), height(30px), background(\"tomato\"))")
  @test !failed
  frames(w, 3)
  @test rect(node()).width == 120px
  shot("show-code-changed.png")
  # A page's own code still has a module of its own
  @test K.page_module(e, page) !== m
end

# --- a method of a long file -------------------------------------------------------
#
# A file that's longer than `MOST_TEXT` opens whole, as code to change. A kind
# of block whose file is that long has its drawing method far down the file.

const long = joinpath(dir, "dial.jl")
const filler = ["# A line that makes the file long, number $i, with enough words in it to take up some room." for i in 1:6000]
const dial_code = """
\"\"\"
A dial that shows a level,
as a box.
\"\"\"
describe(d::Dial) =
  Box(width(100px), height(30px),
      background("steelblue"))
"""
write(long, """
@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe

@def mutable struct Dial <: SemanticUI
  level::Int = 0
end

dial(lines) = Dial(level=something(tryparse(Int, strip(get(lines, 1, ""))), 0))

$(join(filler, "\n"))

$dial_code
"A line after the method"
after(d::Dial) = d.level
""")
const dials = joinpath(dir, "dials.md")
write(dials, "# Dials\n\n```dial\n2\n```\n")
K.open!(e, dials)
frames(w, 4)
dial_node() = e.nodes[(:block, "dial", dials, 1)].value
"Hold ⌘ and ⌥ and click the dial"
click_dial() = begin
  r = rect(dial_node())
  x, y = r.left + r.width / 2, r.top + r.height / 2
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  w.keys |= Keys.cmd; w.keys |= Keys.opt
  frames(w, 1)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.cmd; w.keys ⊻= Keys.opt
  frames()
  press_button(:show_code)
end
"The windows that show the long file"
shows() = filter(o -> o.buf.path == realpath(long), K.editors)

@testset "the line of a method in a file that changed since it was loaded" begin
  m = K.drawn_by(dial_node())
  lines = ["x = 1", "describe(g::Gauge) = 1", "", "\"Words\"", "describe(d::Dial) =", "  2", "function describe(d::Dial, n::Int)", "end"]
  # Julia has the method's old line. The nearest line that starts a method of that name for that type is its line now.
  @test K.settled_line(m, lines, 5) == 5 && K.settled_line(m, lines, 2) == 5 && K.settled_line(m, lines, 8) == 7
  @test K.settled_line(m, ["nothing here"], 40) == 1
end

@testset "a method of a long file shows in the whole file" begin
  @test filesize(long) > K.MOST_TEXT && K.iscode(long)
  m = K.drawn_by(dial_node())
  at = findfirst(startswith("describe(d::Dial)"), readlines(long))
  @test K.code_place(m) == (realpath(long), at)
  click_dial()
  shown = only(shows())
  # The window has every line of the file, as code to change, with the caret on the method
  @test shown.buf.view == :code && shown.buf.lines == K.text(long) && length(shown.buf.lines) > 6000 && shown.buf.lines[at-4:at+2] == split(rstrip(dial_code), '\n')
  @test shown.buf.caret[1] == at && isempty(shown.buf.about)
  # The method's line is in the lines that the window draws
  win = K.window_of(shown)
  frames(win, 3)
  @test at in first(shown.layout[first(shown.shown)].first:shown.layout[last(shown.shown)].last, 12)
  # A second click shows the same window, with what was changed in it
  K.edit!(shown.buf, (at + 2, 0), (at + 2, 0), " ")
  click_dial()
  @test only(shows()) === shown && shown.buf.lines[at+2] == "       background(\"steelblue\"))"
  K.undo!(shown.buf)
  # Lines that are typed over the method move it, and the next click finds its line as it is in the window
  K.edit!(shown.buf, (1, 0), (1, 0), "# One more line\n")
  click_dial()
  @test shown.buf.caret[1] == at + 1
  K.undo!(shown.buf)
end

@testset "its code runs in the long file's module, and a save writes the file" begin
  shown = only(shows())
  b = shown.buf
  @test K.page_module(shown, b.path) === Kip.modules[realpath(long)]
  @test rect(dial_node()).width == 100px
  at = findfirst(startswith("describe(d::Dial)"), b.lines)
  i = at + 1
  from = length(b.lines[i], 1, prevind(b.lines[i], first(findfirst("100px", b.lines[i]))))
  K.edit!(b, (i, from), (i, from + 5), "60px * d.level")
  value, printed, failed = K.run_code(shown, join(b.lines[at:at+2], "\n"))
  @test !failed
  frames(w, 3)
  @test rect(dial_node()).width == 120px
  # ⌘S writes the whole file, with the new line where the old one was
  K.save!(b)
  now = readlines(long)
  @test now[at+1] == "  Box(width(60px * d.level), height(30px)," && now[at-4] == "\"\"\"" && now[at+3] == ""
  @test now[at+4] == "\"A line after the method\"" && length(now) == 6000 + 22 && now[12] == filler[1] && now[6011] == filler[6000]
end

foreach(o -> (win = K.window_of(o); win === nothing || close(win)), copy(K.editors))
