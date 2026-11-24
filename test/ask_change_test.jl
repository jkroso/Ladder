# Tests for a change that's asked for, in main.jl: the command Ask For Change
# takes what to change, a block of Julia code or a part of the window, and
# words. It starts with what the caret is on, and a click chooses another. An
# agent changes the code, and Ladder runs the code that changed. Ask About
# takes a question, and the agent's answer shows in a card. The command Keep This Change adds the function at the caret to the
# startup page. Run them with `julia -O0 --project=. test/ask_change_test.jl`.
# The agent here is a small script, so no real agent runs. They draw windows
# that aren't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect window_tool popups
@use GeometryBasics: Vec2
const px = K.px

# The folder has the same name each time, so that Kip compiles its file once
const dir = joinpath(tempdir(), "ladder-ask-change-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
@eval K settings_file() = $(joinpath(dir, "settings"))
K.STARTUP_FOLDER[] = dir
const page = joinpath(dir, "tank.md")
const source = joinpath(dir, "level.jl")

# A kind of block with a node of its own
write(source, """
@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe

"How full a tank is"
@def mutable struct Level <: SemanticUI
  level::Int = 0
end

level(lines) = Level(level=something(tryparse(Int, strip(get(lines, 1, ""))), 0))

"How wide the bar of a tank is"
wide(l::Level) = 200px

"A bar as wide as the tank is full"
describe(l::Level) =
  Box(width(wide(l)), height(30px), background("steelblue"))
""")
write(page, "# A tank\n\n```level\n3\n```\n\nThe end.\n\n```julia\nx = 1\n```\n")

"An agent of these tests: it writes the words that it was given to a file, notes its folder, and runs `change` on the code"
agent(name, change, said...) = begin
  path = joinpath(dir, name)
  write(path, "#!/bin/sh\nprintf '%s' \"\$1\" > \"$dir/asked.txt\"\npwd > \"$dir/where.txt\"\n$change\n" * join(("echo \"$s\"" for s in said), "\n") * "\n")
  path
end
const wider = agent("wider.sh", "sed -i '' 's/^wide(l::Level) = 200px/wide(l::Level) = 120px/' \"$source\"", "I read the file.", "", "The bar is 120 pixels wide now.")
const thinner = agent("thinner.sh", "sed -i '' 's/height(30px)/height(12px)/' \"$source\"", "The bar is 12 pixels tall now.")
const broken = agent("broken.sh", "sed -i '' 's/^wide(l::Level) = \\([0-9]*px\\)\$/wide(l::Level) = \\1; nothing_of_that_name + 1/' \"$source\"", "Done.")
const quiet = agent("quiet.sh", "true", "I looked, and it's as you say.")
const stopped = joinpath(dir, "stopped.sh")
write(stopped, "#!/bin/sh\necho 'No network.'\nexit 3\n")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 600px))
frames(win=w, n=2) = foreach(_ -> Base.invokelatest(frame, win), 1:n)
frames(w, 4)
node() = e.nodes[(:block, "level", page, 1)].value
picker(win=w) = window_tool(win)::K.CodePicker

# The file of code, in a window of its own
const code = K.build_editor(source)
const cw = Window(code, size=(700px, 800px))
frames(cw, 3)
"What Ask For Change offers in the window of `o`, with the caret at `at`"
offered(o, at) = (o.buf.caret = o.buf.anchor = at; frames(K.window_of(o), 2); K.choices_for(K.ToChange, o))

"Draw frames of the window `win` until the agent has ended, for a few seconds at most"
finish(win=w) = begin
  from = time()
  while picker(win).asked !== nothing && picker(win).asked.ended == 0 && time() - from < 20
    frames(win, 1)
    sleep(0.05)
  end
  frames(win)
end
"Ask for a change to `c` with the script `script` as the agent, and wait for the agent"
ask(script, c, words; win=w) = begin
  K.AGENT_COMMAND[] = `sh $script`
  K.ask_for_change!(win.ui, c, words)
  finish(win)
  picker(win).asked
end
asked() = read(joinpath(dir, "asked.txt"), String)

"Press the key `k` in window `win` with the keys `held` down"
press(win, k, held...) = begin
  foreach(h -> win.keys |= h, held)
  onkey(win, KeyPress{k}(0, win))
  foreach(h -> win.keys ⊻= h, held)
  haskey(win.ui.nodes, :palette) && (win.ui.nodes[:palette].moved = 0.0)
  frames(win)
end
typed(win, s) = (foreach(c -> ontype(win, Typed(c, win)), s); frames(win))
"Click the window `win` at `(x, y)`"
click(win, x, y) = begin
  win.mouse = typeof(win.mouse)(x, y)
  onmouse(win, MouseMove(Vec2{px}(x, y), win))
  frames(win, 1)
  win.keys |= Keys.mouse_left
  onkey(win, KeyPress{Keys.mouse_left}(0, win))
  win.keys ⊻= Keys.mouse_left
  onkey(win, KeyRelease{Keys.mouse_left}(0, win))
  frames(win)
end
"The middle of line `i` of the page of `o`, a little in from its left"
on_line(o, i) = (it = K.item(o, i); (o.origin[1] + 30px, o.origin[2] + it.top + it.tall / 2))
middle(r) = (r.left + r.width / 2, r.top + r.height / 2)

@testset "what the agent said, and the parts of a file's code" begin
  @test K.agent_said("I read the file.\n\nThe bar is\n12 pixels tall.\n\n") == "The bar is 12 pixels tall."
  @test K.agent_said("  \n") == ""
  lines = ["\"Words\"", "f(x) = 1", "", "# A comment", "g(x) = begin", "  2", "end", "", ""]
  @test K.part_texts(lines) == [(1, "\"Words\"\nf(x) = 1\n\n# A comment"), (5, "g(x) = begin\n  2\nend")]
  @test K.part_lines(lines, 6) == (5, 7) && K.part_lines(lines, 2) == (1, 4)
  # The first line of code after documentation and comments
  @test K.code_start(lines, 1) == 2 && K.code_start(lines, 3) == 5
  @test K.code_start(["\"\"\"", "Words", "\"\"\"", "f(x) = 1"], 1) == 4 && K.code_start(["\"\"\"Words", "more\"\"\"", "f(x) = 1"], 1) == 3
  @test K.code_start(["\"\"\"Words\"\"\"", "f(x) = 1"], 1) == 2 && K.code_start(["# only words", ""], 1) == 1
end

@testset "a file of Julia code offers its blocks, the one that the caret is in first" begin
  offers = offered(code, (14, 3))
  blocks = filter(c -> c.node === nothing, offers)
  mod = K.loaded_module(realpath(source))
  # Each piece of code at the top of the file, with its documentation, and none of the lines that only load code
  @test [(c.words, c.note, c.first, c.last) for c in blocks] == [
    ("wide(l::Level)", "function · line 14", 13, 14), ("Level", "mutable struct · line 7", 6, 9),
    ("level(lines)", "function · line 11", 11, 11), ("describe(l::Level)", "function · line 17", 16, 18)]
  @test all(c -> c.file == realpath(source) && c.mod === mod, blocks)
  # The block that the caret is in comes first, then the parts of the window in focus, then the other blocks
  @test first(offers) === first(blocks) && offers[2].node !== nothing && last(offers) === last(blocks)
  # On a line of the code's documentation, the caret is in that block
  @test first(offered(code, (16, 0))).words == "describe(l::Level)"
  # What the agent is told
  prompt = K.change_prompt(blocks[1], "make it wider")
  @test occursin("a block of the file's Julia code", prompt) && occursin("$(realpath(source)), lines 13 to 14. It starts:\n\n    wide(l::Level) = 200px", prompt)
  @test occursin("The user's words: make it wider", prompt) && occursin("only files in $(realpath(dir))", prompt)
end

@testset "a page offers the thing that a block shows, which its file draws" begin
  first_one = first(offered(e, (3, 0)))
  @test first_one.node === node() && first_one.words == "Level" && first_one.note == "drawn at level.jl:17"
  @test (first_one.file, first_one.first, first_one.last) == (realpath(source), 16, 18)
  prompt = K.change_prompt(first_one, "make it red")
  # The agent is told which page the window shows. The bar has no words, so it's told of none.
  @test occursin("a part of its window, a Level. The window shows $(e.buf.path). The function that draws that part", prompt) && occursin("lines 16 to 18", prompt)
  # Then the block itself and the page, which Ladder's own code draws
  @test any(c -> c.node isa K.FileBlock, offered(e, (3, 0))) && !any(c -> c.node === node(), offered(e, (7, 0)))
  # A `julia` code block of the page is a block to change, with no code that runs after the change
  block = first(offered(e, (10, 2)))
  @test (block.words, block.note, block.first, block.last, block.node, block.mod) == ("x = 1", "julia block · line 10", 10, 10, nothing, nothing)
  @test occursin("a block of Julia code on a page of Markdown", K.change_prompt(block, "add one")) && block in offered(e, (7, 0))
end

@testset "the node starts as what the caret is on, and a click chooses another" begin
  K.focus(e)
  e.buf.caret = e.buf.anchor = (3, 0)
  frames(w)
  press(w, Keys.p, Keys.cmd, Keys.shft)
  typed(w, "ask for change")
  press(w, Keys.enter)
  p = K.palette(e)
  said() = K.chip_value(p, K.palette_chips(p), 1)
  # What the caret was on is the node, so the keyboard is in the words
  @test said().node === node() && p.at == 2
  # The node's chip shows only a letter in a colour, which the line round the node has too
  letters() = [(l.k, l.letter, l.colour) for l in K.chip_letters(p, K.palette_chips(p))]
  @test letters() == [(1, "A", K.CHIP_MARKS[1])]
  @test K.chip_wide(e, p, K.palette_chips(p), 1) < 40
  # While the keyboard is in the words, the mouse picks out nothing on the page, and a click there chooses nothing
  @test K.click_chip(e, p) === nothing
  click(w, on_line(e, 10)...)
  @test said().node === node() && p.at == 2 && e.popup == :commands
  # With the keyboard in the node's chip, a click on the page's `julia` block chooses it, and the keyboard goes on to the words
  press(w, Keys.tab, Keys.shft)
  @test p.at == 1 && K.click_chip(e, p) == 1
  click(w, on_line(e, 10)...)
  @test said().words == "x = 1" && p.at == 2 && e.popup == :commands && e.buf.caret == (3, 0)
  # A click on the bar chooses the thing that the block shows
  press(w, Keys.tab, Keys.shft)
  click(w, middle(rect(node()))...)
  @test said().node === node() && p.at == 2
  # ⇧ and a click add a second thing, B in orange, and the chip shows both letters. Again takes it out.
  press(w, Keys.tab, Keys.shft)
  w.keys |= Keys.shft
  click(w, on_line(e, 10)...)
  w.keys ⊻= Keys.shft
  @test said() isa K.Things && [x.words for x in said().all] == ["Level", "x = 1"] && p.at == 1
  @test letters() == [(1, "A", K.CHIP_MARKS[1]), (1, "B", K.CHIP_MARKS[2])]
  # Tab goes on to the words, and the chip keeps both things
  press(w, Keys.tab)
  @test p.at == 2 && said() isa K.Things && length(said().all) == 2 && 60 < K.chip_wide(e, p, K.palette_chips(p), 1) < 80
  # ⇧Tab and Return keep them too
  press(w, Keys.tab, Keys.shft)
  press(w, Keys.enter)
  @test p.at == 2 && said() isa K.Things && length(said().all) == 2
  press(w, Keys.tab, Keys.shft)
  prompt = K.change_prompt(said().all, "make A look like B")
  @test occursin("A: a part of its window, a Level.", prompt) && occursin("B: a block of Julia code on a page of Markdown, in the file", prompt)
  @test occursin("The user's words: make A look like B", prompt)
  w.keys |= Keys.shft
  click(w, on_line(e, 10)...)
  w.keys ⊻= Keys.shft
  @test said().node === node()
  # ⌥↑ works from the words too
  press(w, Keys.tab)
  @test p.at == 2
  # ⌥↑ takes the part that holds it, which is bigger on the screen, and ⌥↓ goes back, with the keyboard where it was
  place(x) = (r = rect(x); (r.left, r.top, r.width, r.height))
  press(w, Keys.up, Keys.opt)
  @test said().node !== node() && place(said().node) != place(node()) && p.at == 2
  ups = 1
  while !(said().node isa K.Document) && ups < 6
    press(w, Keys.up, Keys.opt)
    ups += 1
  end
  @test said().node isa K.Document
  foreach(_ -> press(w, Keys.down, Keys.opt), 1:ups)
  @test said().node === node()
  press(w, Keys.down, Keys.opt)
  @test said().node === node()
  # A click on the palette's own bar isn't a choice
  @test K.on_palette(p, K.num(w.size[1]) / 2, K.num(w.size[2]) - 30)
  press(w, Keys.escape)
  press(w, Keys.escape)
  @test e.popup == :none && K.click_chip(e, p) === nothing
end

@testset "the palette asks for the block and the words, and the agent changes the block" begin
  code.buf.caret = code.buf.anchor = (14, 3)
  K.AGENT_COMMAND[] = `sh $wider`
  K.focus(code)
  press(cw, Keys.p, Keys.cmd, Keys.shft)
  typed(cw, "ask for change")
  press(cw, Keys.enter)
  p = K.palette(code)
  chips = K.palette_chips(p)
  @test p.command.name == :ask_for_change && [K.chip_name(c) for c in chips] == ["Node", "Request"] && K.chip_kind(code, chips[1]) == :search
  # The node is the block that the caret is in, so the keyboard is in the words
  @test K.chip_value(p, chips, 1).words == "wide(l::Level)" && p.at == 2
  # With the keyboard in the node's chip, a click on another block of the file chooses it, and a click on the first chooses it again
  @test K.num(on_line(code, 17)[2]) < K.palette(code).plan.band.y
  press(cw, Keys.tab, Keys.shft)
  click(cw, on_line(code, 17)...)
  @test K.chip_value(p, chips, 1).words == "describe(l::Level)" && p.at == 2
  press(cw, Keys.tab, Keys.shft)
  click(cw, on_line(code, 14)...)
  @test K.chip_value(p, chips, 1).words == "wide(l::Level)" && code.buf.caret == (14, 3)
  # ⌥↑ takes the whole file, which nothing holds, and ⌥↓ goes back to the block
  press(cw, Keys.up, Keys.opt)
  whole = K.chip_value(p, chips, 1)
  @test (whole.words, whole.note, whole.first, whole.last) == ("level.jl", "the whole file", 1, length(code.buf.lines))
  @test occursin("the whole of a file", K.change_prompt(whole, "tidy it"))
  press(cw, Keys.up, Keys.opt)
  @test K.chip_value(p, chips, 1) == whole
  press(cw, Keys.down, Keys.opt)
  @test K.chip_value(p, chips, 1).words == "wide(l::Level)"
  typed(cw, "make the bar wider")
  press(cw, Keys.enter)
  @test p.at == 3
  press(cw, Keys.enter)
  @test code.popup == :none
  a = picker(cw).asked
  @test a !== nothing && a.words == "make the bar wider" && a.places[1].first == 13
  # A line goes round the block while the agent works
  @test K.asked_rect(code, a.places[1]) !== nothing
  finish(cw)
  # The agent got the words and the block's place, and ran in the folder of the file
  @test occursin("The user's words: make the bar wider", asked()) && occursin("lines 13 to 14", asked())
  @test realpath(strip(read(joinpath(dir, "where.txt"), String))) == realpath(dir)
  # The window shows the file as the agent left it, Ladder ran the code that changed, and the label has what the agent said
  @test "wide(l::Level) = 120px" in code.buf.lines && !K.dirty(code.buf)
  frames(w, 3)
  @test rect(node()).width == 120px
  @test a.ended > 0 && !a.failed && a.said == "The bar is 120 pixels wide now."
  # The label says what the agent said, and a click on it shows the change
  @test a.changed && last(K.AGENT_CHANGES) === a
  left, top, wide, tall = a.label
  click(cw, px(left + wide / 2), px(top + tall / 2))
  shown = only(filter(o -> endswith(o.buf.path, "what the agents changed.md"), K.editors))
  close(K.window_of(shown))
  # The label goes after a few seconds
  a.ended -= 9
  frames(cw)
  @test picker(cw).asked === nothing
end

@testset "Show Change shows what the agent changed, and Undo Change puts it back" begin
  @test K.works_here(code, Val(:undo_change)) && K.works_here(code, Val(:show_change))
  shown = K.show_change!(code)
  frames(K.window_of(shown), 3)
  page = join(shown.buf.lines, "\n")
  @test occursin("```changes\n--- $(realpath(source))\n+++ $(realpath(source))\n@@", page) && occursin("[accepted]", page)
  @test occursin("-wide(l::Level) = 200px", page) && occursin("+wide(l::Level) = 120px", page) && occursin(r"## \d+:\d\d [ap]m: make the bar wider", page)
  # Reject takes the change out of the file, and the code that it changed runs. Accept puts it back.
  v = shown.nodes[(:block, K.CHANGES, shown.buf.path, 1)]
  K.decide!(v, 1, :rejected)
  frames(w, 3)
  @test occursin("wide(l::Level) = 200px", read(source, String)) && rect(node()).width == 200px
  K.decide!(v, 1, :accepted)
  frames(w, 3)
  @test occursin("wide(l::Level) = 120px", read(source, String)) && rect(node()).width == 120px
  close(K.window_of(shown))
  # Undo Change puts each file back as it was, and runs its code. There's nothing to undo after that.
  K.undo_change!(code)
  frames(w, 3)
  @test occursin("wide(l::Level) = 200px", read(source, String)) && rect(node()).width == 200px && last(K.AGENT_CHANGES).undone
  @test_throws ErrorException K.undo_change!(code)
  @test !K.works_here(code, Val(:undo_change)) && K.works_here(code, Val(:show_change))
end

@testset "a change to a part of the window" begin
  @test rect(node()).height == 30px
  a = ask(thinner, first(offered(e, (3, 0))), "make the bar thinner")
  @test occursin("a Level", asked()) && rect(node()).height == 12px
  @test !a.failed && a.said == "The bar is 12 pixels tall now."
  picker().asked = nothing
  # Show Change lists each change, the newest first. Each is marked by what its file has now: the first was undone.
  shown = K.show_change!(e)
  frames(K.window_of(shown), 3)
  page = join(shown.buf.lines, "\n")
  @test count("## ", page) == 2 && findfirst("make the bar thinner", page).start < findfirst("make the bar wider", page).start
  thinner_part, wider_part = split(page, "make the bar wider")
  @test occursin("+  Box(width(wide(l)), height(12px)", thinner_part) && occursin("[accepted]", thinner_part) && !occursin("[rejected]", thinner_part)
  @test occursin("+wide(l::Level) = 120px", wider_part) && occursin("[rejected]", wider_part)
  # Again, it shows the same window
  @test K.show_change!(e) === shown
  close(K.window_of(shown))
  # A file that changed after the agent's change isn't put back
  open(io -> println(io, "# a line of mine"), source, "a")
  @test_throws ErrorException K.undo_change!(e)
  write(source, replace(read(source, String), "# a line of mine\n" => ""))
  # Words with nothing in them ask for nothing
  @test_throws ErrorException K.ask_for_change!(e, first(offered(e, (3, 0))), "  ")
end

@testset "an agent that stops, changes nothing, or leaves code that doesn't run" begin
  level = first(offered(e, (3, 0)))
  a = ask(stopped, level, "make it green")
  @test a.failed && a.said == "The agent stopped. No network."
  a = ask(quiet, level, "is it blue?")
  @test !a.failed && a.said == "Nothing changed. I looked, and it's as you say."
  # Code that fails as it loads: the label says so. The file's block has nothing to show until the code is put right.
  a = ask(broken, level, "make it wider")
  @test a.failed && startswith(a.said, "The new code doesn't run.") && occursin("nothing_of_that_name", a.said)
  picker().asked = nothing
end

@testset "only the code that changed runs again" begin
  mod = K.loaded_module(realpath(source))
  before = K.text(source)
  write(source, replace(read(source, String), r"wide\(l::Level\) = \d+px; nothing_of_that_name \+ 1" => "wide(l::Level) = 80px"))
  @test K.reload_changed!(mod, realpath(source), before) == (1, "")
  frames(w, 3)
  @test rect(node()).width == 80px
  @test K.reload_changed!(mod, realpath(source), K.text(source)) == (0, "")
end

"Press Esc, which goes on to the page and hides the caret, and show the caret again for the tests after"
esc!() = (press(w, Keys.escape); e.buf.reading = false; frames(w, 2))

@testset "The × on the label, or Stop Agent, stops the agent, and what it changed doesn't run. Esc doesn't." begin
  level = first(offered(e, (3, 0)))
  # An agent that changes the file, and then works on
  half = agent("half.sh", "sed -i '' 's/^wide(l::Level) = 80px/wide(l::Level) = 60px/' \"$source\"\nexec sleep 30")
  K.AGENT_COMMAND[] = `sh $half`
  K.ask_for_change!(e, level, "make it thinner")
  from = time()
  while !occursin("60px", read(source, String)) && time() - from < 10
    frames(w, 1); sleep(0.05)
  end
  @test picker().asked.ended == 0 && K.works_here(e, Val(:stop_agent))
  runs = K.CODE_RUNS[]
  # Esc does nothing to the agent, as it's easy to press by mistake
  esc!()
  @test picker().asked.ended == 0 && !picker().asked.stopped
  @test endswith(K.asked_label(picker().asked), "Click to open")
  # A click on the label opens a field under the thing, with what was asked and what the agent does. The agent works on.
  left, top, wide, tall = picker().asked.label
  click(w, left + wide / 2, top + tall / 2)
  frames(w, 2)
  f = only(K.ask_boxes(e))
  @test K.same_things([f.thing], [level]) && any(p -> p.key == K.box_key(f), popups(w)) && w.focus === f.parts[:text]
  @test K.unanswered(e, f) == [("make it thinner", "Claude is working on it.")] && K.box_shows(e, w, picker().asked)
  @test picker().asked.ended == 0 && !picker().asked.stopped && !endswith(K.asked_label(picker().asked, open=false), "Click to open")
  # Its Close button closes only the field, which has nothing in it, and the label stays
  x = rect(f.parts[:close])
  click(w, x.left + x.width / 2, x.top + x.height / 2)
  @test isempty(K.ask_boxes(e)) && picker().asked.ended == 0 && !picker().asked.stopped && w.focus === e
  # The × at the end of the label stops it
  frames(w, 2)
  left, top, wide, tall = K.close_spot(picker().asked.label)
  click(w, left + wide / 2, top + tall / 2)
  finish()
  a = picker().asked
  @test a.stopped && a.changed && a.said == "You stopped the agent. Ladder didn't run what it changed. Undo Change puts it back."
  @test !K.works_here(e, Val(:stop_agent)) && last(K.AGENT_CHANGES) === a
  @test K.CODE_RUNS[] == runs   # Ladder didn't run the half-done change
  K.undo_change!(e)
  @test occursin("wide(l::Level) = 80px", read(source, String))
  # An agent that changed nothing says so
  K.AGENT_COMMAND[] = `sh -c "exec sleep 30"`
  K.ask_for_change!(e, level, "make it red")
  frames(w, 2)
  left, top, wide, tall = K.close_spot(picker().asked.label)
  click(w, left + wide / 2, top + tall / 2)
  finish()
  @test picker().asked.stopped && picker().asked.said == "You stopped the agent. Nothing changed."
  # So does the command, which says so when no agent works
  K.ask_for_change!(e, level, "make it blue")
  K.stop_agent!(e)
  finish()
  @test picker().asked.stopped
  @test_throws ErrorException K.stop_agent!(e)
  picker().asked = nothing
  # An agent that's answering a question keeps working after Esc too. A click on its label stops it, and there's no card.
  K.ask_about!(e, level, "why is it blue?")
  @test picker().about.ended == 0
  process = picker().about.process
  frames(w, 2)
  esc!()
  @test picker().about !== nothing && !process_exited(process)
  left, top, wide, tall = picker().about.label
  click(w, left + wide / 2, top + tall / 2)
  @test picker().about === nothing
  sleep(0.2)
  @test process_exited(process)
end

@testset "a paragraph that an agent works on keeps its line while the agent works" begin
  # The page makes its paragraphs again on each frame, so the line goes round this frame's paragraph
  w.mouse = typeof(w.mouse)(on_line(e, 7)...)
  frames(w, 2)
  para = K.chip_click(K.ToChange, e, w)
  @test para isa K.ToChange && para.node isa K.Paragraph
  frames(w, 2)
  r = K.asked_rect(e, para)
  @test r !== nothing && K.num(r.top) > 100 && r.height < 60px
  K.AGENT_COMMAND[] = `sh -c "exec sleep 30"`
  K.ask_for_change!(e, para, "make it bigger")
  frames(w, 3)
  # The label of what was asked is on the paragraph's top edge, not under the top bar where a thing that doesn't show has it
  @test picker().asked.ended == 0 && picker().asked.label[2] == K.num(K.asked_rect(e, para).top) - 18
  K.stop_agent!(e)
  finish()
  picker().asked = nothing
end

@testset "Ask About shows the agent's answer in a card beside the thing, and changes nothing" begin
  level = first(offered(e, (3, 0)))
  answers = agent("answers.sh", "true", "The bar is blue because describe(l::Level) gives it a steelblue background.", "", "It is 12 pixels tall.")
  before = read(source, String)
  "Ask the question `words` about `c` with the script `script` as the agent, and wait for the answer"
  ask_about(script, c, words) = begin
    K.AGENT_COMMAND[] = `sh $script`
    K.ask_about!(e, c, words)
    from = time()
    while picker().about.ended == 0 && time() - from < 20
      frames(w, 1)
      sleep(0.05)
    end
    frames(w)
    picker().about
  end
  q = ask_about(answers, level, "  why is it blue? ")
  @test q.words == "why is it blue?" && !q.failed
  @test q.answer == "The bar is blue because describe(l::Level) gives it a steelblue background.\n\nIt is 12 pixels tall."
  # The agent was told what the thing is, the question, and to change nothing. Nothing changed.
  @test occursin("a question about a part of its window, a Level.", asked()) && occursin("The user's question: why is it blue?", asked())
  @test occursin("Don't change any file.", asked()) && read(source, String) == before
  # The card is at the right of the bar, with the question, then each paragraph of the answer
  r = rect(node())
  left, top, wide, tall = q.card
  @test left >= K.num(r.left + r.width) && top >= K.num(r.top) - 50
  lines = [l for (_, l) in K.answer_lines(q, wide - 24, 30)]
  @test lines[1] == "why is it blue?" && lines[2] == "" && "It is 12 pixels tall." in lines && lines[end-1] == ""
  # A click on the card takes it away, and does nothing else
  e.buf.caret = e.buf.anchor = (7, 3)
  frames(w)
  was = e.buf.caret
  click(w, px(left + wide / 2), px(top + tall / 2))
  @test picker().about === nothing
  @test e.buf.caret == was
  # Esc leaves it, so that an answer stays until you've read it
  ask_about(answers, level, "why?")
  esc!()
  @test picker().about !== nothing && picker().about.ended > 0
  picker().about = nothing
  # A thing at the bottom of a window with no room at its side has its card over it
  @test K.answer_place((left=10px, top=500px, width=880px, height=60px), 380.0, 120.0, (900.0, 600.0)) == (10.0, 370.0)
  @test K.answer_place((left=10px, top=100px, width=880px, height=60px), 380.0, 120.0, (900.0, 600.0)) == (10.0, 170.0)
  # An agent that stops says so in the card. Words with nothing in them ask nothing.
  q = ask_about(stopped, level, "why?")
  @test q.failed && q.answer == "The agent stopped. No network."
  picker().about = nothing
  @test_throws ErrorException K.ask_about!(e, level, "  ")
  # The palette asks for the thing, which starts as what the caret is on, and the question
  K.focus(e)
  e.buf.caret = e.buf.anchor = (3, 0)
  frames(w)
  press(w, Keys.p, Keys.cmd, Keys.shft)
  typed(w, "ask about")
  press(w, Keys.enter)
  p = K.palette(e)
  @test p.command.name == :ask_about && [K.chip_name(c) for c in K.palette_chips(p)] == ["Node", "Question"] && p.at == 2
  @test K.chip_value(p, K.palette_chips(p), 1).node === node()
  # The question is what the command is for, so its chip takes the room that's left on the bar, up to OMNI_WORDS_MOST
  frames(w)
  room = K.palette_room(e)
  place(k) = only(filter(pl -> pl.what == :chip && pl.k == k, p.plan.places))
  run() = only(filter(pl -> pl.what == :run, p.plan.places))
  @test place(2).w >= min(K.OMNI_WORDS_LEAST, room) && place(2).w <= K.OMNI_WORDS_MOST
  @test place(2).w > 4K.chip_wide(e, p, K.palette_chips(p), 1)
  @test run().y == place(2).y && run().x + run().w <= p.plan.bar.x + p.plan.bar.w
  # Long words grow it only to the end of its line, and then scroll in it, so it and the Run button stay in sight
  typed(w, repeat("why is it blue ", 20))
  frames(w)
  @test !p.plan.more && run().y == place(2).y && run().x + run().w <= p.plan.bar.x + p.plan.bar.w
  @test K.input(e).scroll > 0
  # Words for a command that isn't for them, like Rename In Code's new name, are as wide as they are
  @test !K.wide_words(Val(:rename_in_code)) && K.wide_words(Val(:ask_for_change)) && K.wide_words(Val(:ask_agent))
  press(w, Keys.escape); press(w, Keys.escape)
  # The agent that answers can read files, and can't change them. Each agent prints its steps as lines of JSON.
  K.AGENT_COMMAND[] = nothing
  @test K.agent_command(e, changes=false).exec[end-2:end] == ["--allowedTools", "Read,Grep,Glob", "-p"]
  @test occursin("--output-format stream-json --verbose", join(K.agent_command(e).exec, " "))
end

@testset "the label says what the agent is doing, from the lines of JSON that it prints" begin
  step(json) = K.agent_step(json)
  @test step("""{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"/a/b/level.jl"}}]}}""") == "Reading level.jl"
  @test step("""{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/a/level.jl","old_string":"x"}}]}}""") == "Changing level.jl"
  @test step("""{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Grep","input":{"pattern":"wide("}}]}}""") == "Looking for wide("
  @test step("""{"type":"assistant","message":{"content":[{"type":"text","text":"I'll make\\nit thinner."}]}}""") == "I'll make it thinner."
  @test step("""{"type":"result","result":"Done."}""") === nothing && step("plain words") === nothing && step("{not json") === nothing
  # What it said at its end: its result line, or the lines that aren't JSON, like an error
  @test K.agent_text("""{"type":"system"}\n{"type":"result","result":"The bar is thinner."}\n""") == "The bar is thinner."
  @test K.agent_text("""{"type":"system"}\nError: no network\n""") == "Error: no network\n" && K.agent_text("Plain words.\n") == "Plain words.\n"
  @test K.asking_words("make it red", "") == "Asked: make it red …" && K.asking_words("make it red", "Reading level.jl") == "Asked: make it red  ·  Reading level.jl …"
  # While the agent works, the thing's label says its last step
  steps = joinpath(dir, "steps.sh")
  write(steps, """
    #!/bin/sh
    printf '%s' "\$1" > "$dir/asked.txt"
    echo '{"type":"system","subtype":"init"}'
    echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"$source"}}]}}'
    sleep 2
    echo '{"type":"result","subtype":"success","result":"It reads the level from the block."}'
    """)
  K.AGENT_COMMAND[] = `sh $steps`
  K.ask_about!(e, first(offered(e, (3, 0))), "where does the level come from?")
  q = picker().about
  from = time()
  while isempty(q.step) && time() - from < 10
    frames(w, 1); sleep(0.05)
  end
  @test q.step == "Reading level.jl" && q.ended == 0
  while q.ended == 0 && time() - from < 20
    frames(w, 1); sleep(0.05)
  end
  frames(w)
  @test q.answer == "It reads the level from the block."
  picker().about = nothing
end

@testset "the card's buttons ask more, or ask for a change, with what was asked before" begin
  level = first(offered(e, (3, 0)))
  answers = agent("more.sh", "true", "It's blue because of its background.")
  K.AGENT_COMMAND[] = `sh $answers`
  K.ask_about!(e, level, "why is it blue?")
  from = time()
  while picker().about.ended == 0 && time() - from < 20
    frames(w, 1); sleep(0.05)
  end
  frames(w)
  q = picker().about
  @test [a for (a, _) in q.buttons] == [:ask_about, :ask_for_change]
  "Where the button of the card that does `action` is"
  button(q, action) = last(only(filter(b -> b[1] == action, q.buttons)))
  # Ask More: the palette asks about the same thing, with the keyboard in the question
  left, top, wide, tall = button(q, :ask_about)
  click(w, px(left + wide / 2), px(top + tall / 2))
  p = K.palette(e)
  @test picker().about === nothing && e.popup == :commands && p.command.name == :ask_about && p.at == 2
  @test K.chip_value(p, K.palette_chips(p), 1).node === node()
  typed(w, "and why is it short?")
  press(w, Keys.enter); press(w, Keys.enter)
  from = time()
  while picker().about.ended == 0 && time() - from < 20
    frames(w, 1); sleep(0.05)
  end
  frames(w)
  # The agent is told the question before and its answer
  @test occursin("The user's question: and why is it short?", asked())
  @test occursin("Before this, the user asked about it, and an agent answered:\n\nQuestion: why is it blue?\nAnswer: It's blue because of its background.", asked())
  @test length(picker().about.talk) == 1
  # Change It: the palette asks for a change to the same thing, and the agent is told both questions and answers
  left, top, wide, tall = button(picker().about, :ask_for_change)
  click(w, px(left + wide / 2), px(top + tall / 2))
  @test e.popup == :commands && p.command.name == :ask_for_change && p.at == 2 && K.chip_value(p, K.palette_chips(p), 1).node === node()
  K.AGENT_COMMAND[] = `sh $quiet`
  typed(w, "make it red")
  press(w, Keys.enter); press(w, Keys.enter)
  finish()
  @test occursin("The user's words: make it red", asked()) && occursin("Question: why is it blue?", asked()) && occursin("Question: and why is it short?", asked())
  picker().asked = nothing
  # What was asked before goes only with the same thing
  @test K.follow_up!(e, [level]) == Tuple{String,String}[]
  e.nodes[:follow_up] = (places=[level], talk=[("a", "b")])
  @test K.follow_up!(e, offered(e, (10, 2))[1:1]) == Tuple{String,String}[] && !haskey(e.nodes, :follow_up)
end

@testset "a file whose code Ladder never ran changes, and nothing runs" begin
  notes = joinpath(dir, "notes.jl")
  write(notes, "\"Twice a number\"\ntwice(x) = 2x\n")
  shown = K.build_editor(notes)
  win = Window(shown, size=(600px, 400px))
  frames(win, 3)
  c = first(offered(shown, (2, 3)))
  @test c.words == "twice(x)" && c.mod === nothing
  a = ask(agent("triple.sh", "sed -i '' 's/2x/3x/' \"$notes\"", "It's three times now."), c, "make it three times"; win)
  @test !a.failed && a.said == "It's three times now." && "twice(x) = 3x" in shown.buf.lines
end

@testset "Ask For Change asks the agent that works on the page with you" begin
  K.Agent.place[] = mktempdir()
  # The agent waits for the page, as `ladder wait` does. Its process is this one, so it runs.
  waits() = (write(joinpath(K.Agent.folder(), "$(getpid()).wait"), realpath(page) * "\nClaude\n"); sleep(0.6); frames(w, 3))
  sent = joinpath(K.Agent.folder(), "$(getpid()).sent")
  got() = (s = read(sent, String); rm(sent); s)
  # A new agent would leave this file
  oneshot = joinpath(dir, "oneshot.txt")
  rm(oneshot, force=true)
  K.AGENT_COMMAND[] = `sh -c "touch $oneshot"`
  picker().asked = nothing
  waits()
  @test K.sharer(e) == "Claude"
  # The button at the top right is Claude's logo, in Claude's colour. An agent that Ladder has no logo of has a bell.
  @test K.agent_logo("Claude") == ("agent-claude", K.colorant"#D97757") && K.agent_logo("grok-cli")[1] == "agent-grok"
  @test K.agent_logo("Codex")[1] == "agent-codex" && K.agent_logo("the agent") === nothing && K.agent_logo("") === nothing
  @test haskey(K.icon_cache, "agent-claude") && K.icon_cache["agent-claude"].viewbox == (0f0, 0f0, 24f0, 24f0)
  level = first(offered(e, (3, 0)))
  K.ask_for_change!(e, level, "make the bar shorter")
  a = picker().asked
  told = got()
  @test a.by == "Claude" && a.sent && a.ended == 0 && !isfile(oneshot)
  @test startswith(told, "The user asked you for a change from Ladder, on the page $(e.buf.path).")
  @test occursin("The user's words: make the bar shorter", told) && occursin("A: A Level of the page, on lines 3 to 5", told)
  @test occursin("Ladder draws it with the code in the file $(level.file), lines $(level.first) to $(level.last).", told)
  frames(w, 2)
  @test startswith(K.asked_label(a), "Asked Claude: make the bar shorter")
  # Another change waits in the queue until Claude has done this one, and its label says its place
  K.ask_for_change!(e, level, "and red")
  q = K.ask_queue(e)
  @test length(q) == 1 && q[1][1].words == "and red" && picker().asked === a && !isfile(sent)
  frames(w, 2)
  @test q[1][1].label !== nothing
  # Claude changes the code, and waits for the page again. Ladder runs the new code, and Claude gets the next change.
  write(source, replace(read(source, String), r"height\(\d+px\)" => "height(22px)"))
  waits()
  @test a.ended > 0 && a.changed && a.said == "Claude has done it." && last(K.AGENT_CHANGES) === a
  @test isempty(q)
  @test last(K.asks_ended(e)) === a
  @test picker().asked.words == "and red"
  @test picker().asked.sent
  @test occursin("The user's words: and red", got())
  frames(w, 2)
  @test rect(node()).height == 22px
  waits()
  @test picker().asked.ended > 0
  picker().asked = nothing
  empty!(K.asks_ended(e))
  # The Nudge button gives Claude the page, so it waits no more. A change waits for it.
  K.send!(e)
  got()
  frames(w, 2)
  K.ask_for_change!(e, level, "make it green")
  a = picker().asked
  @test a.by == "Claude" && !a.sent && !isfile(sent) && startswith(K.asked_label(a), "For Claude when it waits for the page again")
  waits()
  @test a.sent && occursin("The user's words: make it green", got())
  "Click the label of the change that the agent was asked for"
  click_label() = (frames(w, 2); (left, top, wide, tall) = picker().asked.label; click(w, left + wide / 2, top + tall / 2); frames(w, 2))
  "Click the × at the end of that label"
  click_close() = (frames(w, 2); (left, top, wide, tall) = K.close_spot(picker().asked.label); click(w, left + wide / 2, top + tall / 2); frames(w, 2))
  # Esc leaves the label of a change that Claude has. A click on the label opens a field with the request and how it goes.
  frames(w, 2)
  esc!()
  @test picker().asked === a && endswith(K.asked_label(a), "Click to open")
  click_label()
  f = only(K.ask_boxes(e))
  @test K.unanswered(e, f) == [("make it green", "Claude is working on it.")] && picker().asked === a
  # Its Close button closes only the field, and the label stays. The × at the label's end takes it away.
  x = rect(f.parts[:close])
  click(w, x.left + x.width / 2, x.top + x.height / 2)
  @test isempty(K.ask_boxes(e)) && picker().asked === a
  @test K.close_words(e, a) == "Hide this. Claude still has the request."
  click_close()
  @test picker().asked === nothing
  # Esc leaves a change that Claude hasn't got. A click on its label opens a field to change its words.
  K.ask_for_change!(e, level, "make it blue")
  a = picker().asked
  @test !a.sent && endswith(K.asked_label(a), "Click to change it")
  esc!()
  @test picker().asked === a && K.sharer(e) != ""
  click_label()
  f = only(K.ask_boxes(e))
  @test f.editing === a && f.parts[:text].buf.lines == ["make it blue"]
  @test K.waits_note(e, a) == "Return changes the request. Claude gets it when it waits for the page again."
  K.edit!(f.parts[:text].buf, (1, 0), (1, 12), "make it purple")
  K.send_ask!(f, w)
  @test isempty(K.ask_boxes(e)) && picker().asked === a && a.words == "make it purple" && !a.sent
  # Take Back takes it back, and the page isn't shared any more
  click_label()
  f = only(K.ask_boxes(e))
  @test f.parts[:text].buf.lines == ["make it purple"]
  K.take_back!(e, a)
  K.close_ask!(f, w)
  frames(w, 2)
  @test picker().asked === nothing && K.sharer(e) == ""
  # So the next change goes to a new agent
  K.ask_for_change!(e, level, "make it blue")
  finish()
  @test isfile(oneshot) && isempty(picker().asked.by)
  picker().asked = nothing
  K.Agent.place[] = ""
end

@testset "Ask Agent takes a change or a question, and an answer shows in a card" begin
  level = first(offered(e, (3, 0)))
  picker().asked = picker().about = nothing
  # Words that ask for a change: the agent changes the code, as for Ask For Change
  any_height = agent("any_height.sh", "sed -i '' -E 's/height\\([0-9]+px\\)/height(12px)/' \"$source\"", "The bar is 12 pixels tall now.")
  a = (K.AGENT_COMMAND[] = `sh $any_height`; K.ask_agent!(e, level, "make the bar thinner"); finish(); picker().asked)
  @test a.asks && a.changed && a.said == "The bar is 12 pixels tall now." && picker().about === nothing
  @test occursin("The user's words: make the bar thinner", asked()) && occursin("The words ask for a change, or ask a question.", asked())
  @test occursin("marked this thing in its window as A", asked()) && occursin("For a question, don't change any file.", asked())
  picker().asked = nothing
  # Words that ask a question: the agent changes nothing, and its answer shows in a card
  K.AGENT_COMMAND[] = `sh $quiet`
  K.ask_agent!(e, level, "why is it blue?")
  finish()
  q = picker().about
  @test picker().asked === nothing && q !== nothing && q.ended > 0 && q.words == "why is it blue?" && q.answer == "I looked, and it's as you say."
  frames(w, 2)
  @test q.card !== nothing
  picker().about = nothing
  # An agent that fails says why on the label, with no card
  a = (K.AGENT_COMMAND[] = `sh $stopped`; K.ask_agent!(e, level, "why?"); finish(); picker().asked)
  @test a.failed && a.said == "The agent stopped. No network." && picker().about === nothing
  picker().asked = nothing
  # What an agent writes to its errors counts only when it fails, as Codex writes each step there
  K.AGENT_COMMAND[] = `sh -c "echo 'Reading main.jl' >&2; echo 'It is blue for the sky.'"`
  K.ask_agent!(e, level, "why blue?")
  finish()
  @test picker().about.answer == "It is blue for the sky."
  picker().about = nothing
  a = (K.AGENT_COMMAND[] = `sh -c "echo 'Not logged in.' >&2; exit 1"`; K.ask_agent!(e, level, "why?"); finish(); picker().asked)
  @test a.failed && occursin("Not logged in.", a.said)
  picker().asked = nothing
  @test_throws ErrorException K.ask_agent!(e, level, "  ")
  # The agent that shares the page gets the words, and is told that they can ask a question
  K.Agent.place[] = mktempdir()
  write(joinpath(K.Agent.folder(), "$(getpid()).wait"), realpath(page) * "\nClaude\n")
  sleep(0.6); frames(w, 2)
  @test K.asks_whom(e) == "Claude"
  # The level's part is made again when its code changes, so it's found again
  level = first(offered(e, (3, 0)))
  K.ask_agent!(e, level, "why is it blue?")
  sent = joinpath(K.Agent.folder(), "$(getpid()).sent")
  told = read(sent, String)
  @test picker().asked.asks && picker().asked.by == "Claude"
  @test startswith(told, "The user asked you for a change, or asked you a question, from Ladder, on the page ")
  reply = picker().asked.reply
  @test startswith(basename(reply), "answer-") && dirname(reply) == K.Agent.folder()
  @test endswith(told, "If the words ask a question, write your answer to the file $reply, in a few short sentences of Markdown, and change no other file. Ladder shows the answer under what the user marked. Then run `ladder wait` again.\n")
  # The agent writes its answer to that file, and it shows under the thing
  write(reply, "It's blue for the **sky**.\n")
  sleep(0.4); frames(w, 2)
  a = only(K.ask_boxes(e))
  @test a.answers == [(asked="why is it blue?", answer="It's blue for the **sky**.", by="Claude")] && !isfile(reply) && picker().asked.said == "Claude answered."
  K.close_ask!(a, w)
  # An answer about a thing that doesn't show now is in a card, so that it isn't lost
  gone = K.ToChange("Spinner", "", level.file, level.first, level.last, K.Spinner(), nothing)   # a part that was never drawn
  K.show_answer!(e, K.AskedChange(words="and now?", places=[gone]), "Still blue.")
  @test isempty(K.ask_boxes(e)) && picker().about.answer == "Still blue."
  picker().about = nothing
  delete!(e.nodes, :sent)
  K.Agent.place[] = ""
end

@testset "Settings chooses the agent that Ladder starts" begin
  @test [k.name for k in K.AGENT_KINDS] == ["Claude", "Codex", "Gemini", "Grok"] && e.ai == "Claude" && K.asks_whom(e) == "Claude"
  @test K.agent_kind("Grok").look == ["--permission-mode", "plan", "-p"] && K.agent_kind("Nobody").name == "Claude"
  K.preferred_agent!(e, "Grok")
  @test e.ai == "Grok" && K.asks_whom(e) == "Grok" && K.agent_logo(K.asks_whom(e))[1] == "agent-grok"
  @test_throws ErrorException K.preferred_agent!(e, "Nobody")
  # The command of the agent, with its folder first on its PATH, and the options for a change or for a question
  bin = mktempdir()
  fake = joinpath(bin, "grok")
  write(fake, "#!/bin/sh\n"); chmod(fake, 0o755)
  was = (K.AGENT_COMMAND[], ENV["PATH"])
  K.AGENT_COMMAND[] = nothing
  ENV["PATH"] = bin * ":" * ENV["PATH"]
  c = K.agent_command(e)
  @test c.exec == [fake, "--permission-mode", "acceptEdits", "-p"] && startswith(only(filter(startswith("PATH="), c.env)), "PATH=$bin:/opt/homebrew/bin:")
  @test K.agent_command(e, changes=false).exec == [fake, "--permission-mode", "plan", "-p"]
  @test_throws ErrorException K.agent_path(K.AgentKind("Nobody", "no-such-agent-command", String[], String[], String[]))
  K.AGENT_COMMAND[], ENV["PATH"] = was
  # The setting is kept with the others
  write(K.settings_file(), "agent=Gemini\n")
  K.load_settings!(e)
  @test e.ai == "Gemini"
  write(K.settings_file(), "agent=Nobody\n")
  K.load_settings!(e)
  @test e.ai == "Gemini"
  rm(K.settings_file())
  K.preferred_agent!(e, "Claude")
end

@testset "the palette's Switch Agent chooses the agent, as Settings does" begin
  press(w, Keys.p, Keys.cmd, Keys.shft)
  typed(w, "switch agent")
  press(w, Keys.enter)
  p = K.palette(e)
  @test e.popup == :commands && p.command.name == :switch_agent
  # The agents are a list over the chip. One whose command isn't on this Mac says so.
  rows = K.palette_rows(e, p)
  @test [r.name for r in rows] == ["Claude", "Codex", "Gemini", "Grok"]
  @test [r.note for r in rows] == [(try K.agent_path(k); "" catch; "not installed" end) for k in K.AGENT_KINDS]
  # Return takes the row, and the command runs at once: it changes no file
  foreach(_ -> press(w, Keys.down), 1:3)
  press(w, Keys.enter)
  @test e.popup == :none && e.ai == "Grok" && K.asks_whom(e) == "Grok"
  K.preferred_agent!(e, "Claude")
end

@testset "the page's menu asks the agent about the words that are selected" begin
  "The field of a request in place that shows"
  box() = only(K.ask_boxes(e))
  "True while a field of a request in place shows"
  asking() = !isempty(K.ask_boxes(e))
  picker().asked = picker().about = nothing
  b = e.buf
  @test b.lines[7] == "The end." && first(K.PAGE_MENU) == "Ask Agent…"
  b.anchor, b.caret = (7, 0), (7, 8)
  c = K.selected_thing(e)
  @test c.words == "“The end.”" && c.note == "selected · line 7" && (c.file, c.first, c.last) == (K.page_key(b.path), 7, 7)
  @test c.node isa K.PickedText && c.node.text == "The end." && K.chip_wider(c, e) === nothing
  frames(w, 2)
  @test K.asked_rect(e, c) !== nothing
  # Lines that are selected whole end at the start of the next line, which isn't one of them
  b.anchor, b.caret = (7, 0), (8, 0)
  @test K.selected_thing(e).last == 7
  b.anchor, b.caret = (7, 0), (7, 8)
  # The menu's item draws a box round the words, and opens a field under them, with the keyboard in it
  K.page_act!(e, 1)
  frames(w, 2)
  a = only(K.ask_boxes(e))
  @test a isa K.AskBox && a.thing == c && w.focus === a.parts[:text] && any(p -> p.key == K.box_key(a), popups(w))
  r = K.asked_rect(e, c)
  @test r.width < 120px && r.height < 40px   # round the words, not the whole line
  # The text is an editor of its own, as a page's is. A long request goes on under itself, and the field grows taller.
  sub = a.parts[:text]
  tall = K.lowest(sub, sub.layout)
  typed(w, "a request that is much too long to fit on one line of the field, so it goes on under itself")
  @test sub.buf.lines == ["a request that is much too long to fit on one line of the field, so it goes on under itself"]
  @test K.lowest(sub, sub.layout) > tall && b.lines[7] == "The end."
  # ↑ goes up a line of the wrapped text, as it does in a page
  at = sub.buf.caret[2]
  press(w, Keys.up)
  @test sub.buf.caret[1] == 1 && 0 < sub.buf.caret[2] < at
  # ⇧Return starts a new line, and sends nothing
  press(w, Keys._end); press(w, Keys.enter, Keys.shft)
  @test length(sub.buf.lines) == 2 && asking() && picker().asked === nothing
  # ⌘Z takes it back
  press(w, Keys.z, Keys.cmd)
  @test length(sub.buf.lines) == 1
  press(w, Keys.a, Keys.cmd); press(w, Keys.backspace)
  @test sub.buf.lines == [""]
  # Esc does nothing, as it's easy to press by mistake: the field keeps what's typed
  typed(w, "half a request")
  press(w, Keys.escape)
  @test asking() && w.focus === sub && sub.buf.lines == ["half a request"]
  press(w, Keys.a, Keys.cmd); press(w, Keys.backspace)
  # Return with nothing typed does nothing
  press(w, Keys.enter)
  @test asking() && w.focus === sub && picker().asked === nothing
  # Nor does a click on the page: the field keeps what's typed, and a click in it gives it the keyboard again
  typed(w, "half a request")
  click(w, on_line(e, 1)...)
  @test asking() && w.focus === e && sub.buf.lines == ["half a request"]
  r = rect(K.node!(K.Document, sub, :document))
  click(w, r.left + 4px, r.top + r.height / 2)
  @test w.focus === sub
  press(w, Keys.a, Keys.cmd); press(w, Keys.backspace)
  # The field is put under its words in each frame, so it follows them as the page scrolls
  r = K.asked_rect(e, c)
  @test only(filter(p -> p.key == K.box_key(a), popups(w))).anchor == (r.left, r.top, r.width, r.height)
  # The field has no words and no answer, so there's nothing to open again: the Close button takes the field and the box away
  x = rect(a.parts[:close])
  click(w, x.left + x.width / 2, x.top + x.height / 2)
  @test !asking() && !any(p -> p.key == K.box_key(a), popups(w)) && w.focus === e
  b.anchor, b.caret = (7, 0), (7, 8)
  # What's typed goes to the agent with the words, and its answer shows under them, in place
  K.page_act!(e, 1)
  frames(w, 2)
  K.AGENT_COMMAND[] = `sh $quiet`
  typed(w, "is this right?")
  press(w, Keys.enter)
  @test !asking() && picker().asked.words == "is this right?" && picker().asked.places == [c]
  finish()
  @test occursin("A: words that the user selected in a file, in the file $(c.file), lines 7 to 7. It starts:\n\n    The end.", asked())
  a = only(K.ask_boxes(e))
  @test a.answers == [(asked="is this right?", answer="I looked, and it's as you say.", by="Claude")] && a.thing == c && picker().about === nothing
  @test any(p -> p.key == K.box_key(a), popups(w)) && w.focus !== a.parts[:text]   # the keyboard stays where it was
  frames(w, 2)
  @test picker().asked.said == "Claude answered."
  # The keys of the page are the page's while the answer shows: Return starts a new line there
  before = copy(b.lines)
  b.anchor = b.caret = (8, 0)
  press(w, Keys.enter)
  @test length(b.lines) == length(before) + 1 && only(K.ask_boxes(e)) === a
  press(w, Keys.z, Keys.cmd)
  @test b.lines == before
  # A question after the answer goes with the question and the answer before it. The field hides while the agent
  # works, and shows again with the new answer under the first, and the field empty.
  shows(a) = any(p -> p.key == K.box_key(a), popups(w))
  K.AGENT_COMMAND[] = `sh $(agent("slow.sh", "sleep 1", "Because it is."))`
  K.focus(a.parts[:text])
  typed(w, "and why?")
  press(w, Keys.enter)
  @test only(K.ask_boxes(e)) === a && a.parts[:text].buf.lines == [""] && length(a.answers) == 1 && w.focus === e
  @test !shows(a) && picker().asked.words == "and why?" && picker().asked.ended == 0
  finish()
  @test occursin("Question: is this right?\nAnswer: I looked, and it's as you say.", asked()) && occursin("The user's words: and why?", asked())
  @test only(K.ask_boxes(e)) === a && [x.asked for x in a.answers] == ["is this right?", "and why?"] && a.answers[2].answer == "Because it is."
  frames(w, 2)
  @test shows(a) && !haskey(a.parts, :to_end)   # it scrolled to the new answer
  K.AGENT_COMMAND[] = `sh $quiet`
  # A third question goes with both questions and answers before it
  K.focus(a.parts[:text])
  typed(w, "and then?")
  press(w, Keys.enter)
  finish()
  @test occursin("Question: is this right?", asked()) && occursin("Question: and why?", asked()) && length(a.answers) == 3
  # A question whose agent you stop has no answer: the field shows again as it was
  K.AGENT_COMMAND[] = `sh -c "exec sleep 30"`
  K.focus(a.parts[:text])
  typed(w, "and how?")
  press(w, Keys.enter)
  @test !shows(a)
  K.stop_agent!(e)
  finish()
  frames(w, 2)
  @test shows(a) && length(a.answers) == 3 && only(K.ask_boxes(e)) === a
  K.close_ask!(a, w)
  picker().asked = nothing
  # When the agent can't take it, the field stays and says why
  push!(K.AGENT_KINDS, K.AgentKind("Nobody", "no-such-agent-command", String[], String[], String[]))
  K.preferred_agent!(e, "Nobody")
  K.AGENT_COMMAND[] = nothing
  b.anchor, b.caret = (7, 0), (7, 8)
  K.page_act!(e, 1)
  frames(w, 2)
  typed(w, "and this?")
  press(w, Keys.enter)
  @test box().error == "Ladder can't find the command `no-such-agent-command` of Nobody. Install it, or choose another agent with the command Switch Agent."
  K.preferred_agent!(e, "Claude")
  pop!(K.AGENT_KINDS)
  # Esc in the field leaves a working agent working, and the field as it is
  K.AGENT_COMMAND[] = `sh -c "exec sleep 30"`
  K.ask_agent!(e, c, "something else")
  press(w, Keys.escape)
  @test asking() && picker().asked.ended == 0
  K.close_ask!(box(), w)
  # A request while the agent works waits in the queue, and its label says its place
  K.page_act!(e, 1)
  frames(w, 2)
  typed(w, "and this?")
  press(w, Keys.enter)
  q = K.ask_queue(e)
  @test !asking() && length(q) == 1 && q[1][1].words == "and this?" && picker().asked.words == "something else"
  @test K.queued_label(1, "and this?") == "Number 1 in the queue: and this?  ·  Click to change it"
  K.ask_agent!(e, c, "and that?")
  frames(w, 2)
  @test [a.words for (a, _) in q] == ["and this?", "and that?"] && all(((a, _),) -> a.label !== nothing, q)
  # A click on a label opens a field with the request's words. Return gives the request the field's words, and it keeps its place.
  "Click the label of the request `a`"
  click_on(a) = (frames(w, 2); (left, top, wide, tall) = a.label; click(w, px(left + wide / 2), px(top + tall / 2)); frames(w, 2))
  click_on(q[1][1])
  f = only(K.ask_boxes(e))
  @test f.editing === q[1][1] && f.parts[:text].buf.lines == ["and this?"] && w.focus === f.parts[:text]
  @test K.waits_note(e, q[1][1]) == "Return changes the request. It stays number 1 in the queue."
  @test any(p -> p.key == K.box_key(f), popups(w))
  typed(w, " and these?")
  press(w, Keys.enter)
  @test isempty(K.ask_boxes(e)) && [a.words for (a, _) in q] == ["and this? and these?", "and that?"]
  # Close leaves the request as it was
  click_on(q[2][1])
  f = only(K.ask_boxes(e))
  typed(w, " no")
  x = rect(f.parts[:close])
  click(w, x.left + x.width / 2, x.top + x.height / 2)
  @test isempty(K.ask_boxes(e)) && [a.words for (a, _) in q] == ["and this? and these?", "and that?"]
  # Take Back takes it out, and the others move up
  click_on(q[2][1])
  f = only(K.ask_boxes(e))
  @test f.parts[:text].buf.lines == ["and that?"]
  x = rect(f.parts[:take_back])
  click(w, x.left + x.width / 2, x.top + x.height / 2)
  @test isempty(K.ask_boxes(e)) && [a.words for (a, _) in q] == ["and this? and these?"] && picker().asked.ended == 0
  # When the agent ends, the next request starts with its new words, and the label of the one before stays a while.
  # A field that was open on it says so, and Return then asks with its words as a new request.
  click_on(q[1][1])
  f = only(K.ask_boxes(e))
  K.stop_agent!(e)
  finish()
  frames(w, 2)
  @test isempty(q) && picker().asked.words == "and this? and these?" && picker().asked.ended == 0 && last(K.asks_ended(e)).words == "something else"
  @test f.editing === nothing && startswith(f.error, "Claude started on it before you changed it.")
  K.close_ask!(f, w)
  # The words of the Fix It of a check go to the agent too, when you change them
  @test K.reworded("Fix it.\n", "Fix the check", "Fix the check") == "Fix it.\n"
  @test K.reworded("Fix it.\n", "Fix the check", "Fix the check, not the code") == "Fix it.\n\nThe user's own words about this: Fix the check, not the code\n"
  K.stop_agent!(e)
  finish()
  picker().asked = nothing
  empty!(K.asks_ended(e))
  # The agent that shares the page reads where the words are
  @test K.thing_told(e, c) == "Words that the user selected, on line 7 of the page:\n\n    The end."
  # With nothing selected, the box goes round the caret's line
  b.anchor = b.caret = (7, 3)
  @test K.selected_thing(e) === nothing && K.line_thing(e).node.text == "The end."
  K.page_act!(e, 1)
  @test box().thing.node.text == "The end."
  K.close_ask!(box(), w)
  # A right-click on a block that shows as one thing, like a formula, puts the caret on it as a whole, as a click does.
  # The menu's first item then puts the box round all of the block's lines, not round an empty line beside it.
  w.mouse = typeof(w.mouse)(on_line(e, 4)...)
  K.page_menu!(e, w)
  frames(w, 1)
  @test b.caret == b.anchor == (3, 0) && K.picked(b) == (3, 5)
  press(w, Keys.down); press(w, Keys.enter)
  frames(w, 2)
  t = box().thing
  @test (t.first, t.last) == (3, 5) && t.node.text == "```level\n3\n```" && K.asked_rect(e, t) !== nothing
  K.close_ask!(box(), w)
end

@testset "an answer in place stays until the × on its box takes it away" begin
  b = e.buf
  picker().asked = picker().about = nothing
  K.AGENT_COMMAND[] = `sh $quiet`
  K.focus(e)
  "Open a field under the words from `from` to `to` of the page, as the page's menu does"
  field(from, to) = begin
    b.anchor, b.caret = from, to
    K.page_act!(e, 1)
    frames(w, 2)
    last(K.ask_boxes(e))
  end
  shows(a) = any(p -> p.key == K.box_key(a), popups(w))
  "True when the fields that show are `xs`, in that order"
  are(xs...) = (bs = K.ask_boxes(e); length(bs) == length(xs) && all(map(===, bs, collect(xs))))
  asking = field((7, 0), (7, 8))
  typed(w, "is this right?")
  press(w, Keys.enter)
  # The field of a question with no answer goes when it's sent. The answer opens a new one.
  @test isempty(K.ask_boxes(e)) && !shows(asking)
  finish()
  answer = only(K.ask_boxes(e))
  @test answer !== asking && length(answer.answers) == 1 && shows(answer)
  # A field for other words opens, and the answer stays
  empty = field((1, 2), (1, 8))
  @test are(answer, empty) && w.focus === empty.parts[:text] && shows(answer) && shows(empty)
  # A field with nothing in it stays when another opens: only its Close button takes it away
  typing = field((7, 0), (7, 3))
  @test are(answer, empty, typing) && shows(empty) && shows(answer) && shows(typing)
  x = rect(empty.parts[:close])
  click(w, x.left + x.width / 2, x.top + x.height / 2)
  @test are(answer, typing) && !shows(empty) && shows(answer)
  K.focus(typing.parts[:text])
  typed(w, "half a question")
  # The same words again give their field the keyboard, and open no other
  K.focus(e)
  b.anchor, b.caret = (7, 0), (7, 8)
  K.page_act!(e, 1)
  @test are(answer, typing) && w.focus === answer.parts[:text]
  # An answer about words whose field has words typed in it goes over them, and the words stay
  K.show_answer!(e, K.AskedChange(words="which word?", places=[typing.thing]), "The first.")
  @test typing.answers == [(asked="which word?", answer="The first.", by="Claude")] && typing.parts[:text].buf.lines == ["half a question"]
  # An answer about other words opens a field for them, and closes none
  b.anchor, b.caret = (1, 2), (1, 8)
  K.show_answer!(e, K.AskedChange(words="what tank?", places=[K.selected_thing(e)]), "A water tank.")
  frames(w, 2)
  tank = last(K.ask_boxes(e))
  @test are(answer, typing, tank) && tank.answers[1].answer == "A water tank." && all(shows, K.ask_boxes(e))
  # When the window shows another file, the fields hide. They show again with their page.
  K.open!(e, source); frames(w, 2)
  @test length(K.ask_boxes(e)) == 3 && !any(shows, K.ask_boxes(e))
  K.open!(e, page); frames(w, 3)
  @test are(answer, typing, tank) && all(shows, K.ask_boxes(e))
  # The Close button closes each, and the box round its words stays, with a label that opens it again. The newest is on
  # top of the others.
  for a in reverse(copy(K.ask_boxes(e)))
    x = rect(a.parts[:close])
    click(w, x.left + x.width / 2, x.top + x.height / 2)
    frames(w)
    @test any(o -> o === a, K.ask_boxes(e)) && a.closed && !shows(a) && endswith(K.box_label(a), "  ·  Click to open")
  end
  # The × at the end of the label of each box takes it away, with its answers. The label of the request that ended goes
  # after a few seconds: until then it's the box's label.
  @test K.labelled_box(e, answer) && !K.labelled_box(e, tank)
  picker().asked = nothing
  for a in copy(K.ask_boxes(e))
    frames(w, 2)
    left, top, wide, tall = K.close_spot(a.label)
    click(w, left + wide / 2, top + tall / 2)
    frames(w)
    @test !any(o -> o === a, K.ask_boxes(e)) && !shows(a)
  end
  @test isempty(K.ask_boxes(e))
end

@testset "a click on the label of a request opens its field, Close closes only the field, and the × takes both away" begin
  b = e.buf
  picker().asked = picker().about = nothing
  empty!(K.asks_ended(e))
  K.focus(e)
  shows(a) = any(p -> p.key == K.box_key(a), popups(w))
  "Click the middle of `r`, a label's place"
  click_at(r) = (frames(w, 2); click(w, px(r[1] + r[3] / 2), px(r[2] + r[4] / 2)); frames(w, 2))
  "Click the Close button of the field `a`"
  close!(a) = (x = rect(a.parts[:close]); click(w, x.left + x.width / 2, x.top + x.height / 2); frames(w, 2))
  "Open a field under the words \"The end.\" and ask `words` in it"
  ask!(words) = begin
    K.focus(e)
    b.anchor, b.caret = (7, 0), (7, 8)
    K.page_act!(e, 1)
    frames(w, 2)
    typed(w, words)
    press(w, Keys.enter)
    frames(w, 2)
    picker().asked
  end
  # A question that an agent works on: its field goes when it's sent, and the label says how it goes
  K.AGENT_COMMAND[] = `sh -c "exec sleep 30"`
  a = ask!("is this right?")
  @test isempty(K.ask_boxes(e)) && a.ended == 0 && a.label !== nothing && endswith(K.asked_label(a), "Click to open")
  # A click on the label opens a field under the words, with the question and what the agent does, and the keyboard in it
  click_at(a.label)
  f = only(K.ask_boxes(e))
  @test shows(f) && w.focus === f.parts[:text] && K.unanswered(e, f) == [("is this right?", "Claude is working on it.")]
  @test a.ended == 0 && !a.stopped && K.box_shows(e, w, a) && f.label === nothing   # the request's label is the box's
  # Close closes only the field. It keeps what you typed in it, and the label opens it again.
  typed(w, "and why?")
  close!(f)
  @test only(K.ask_boxes(e)) === f && f.closed && !shows(f) && picker().asked === a && a.ended == 0 && w.focus === e
  click_at(a.label)
  @test shows(f) && !f.closed && f.parts[:text].buf.lines == ["and why?"] && w.focus === f.parts[:text]
  # Over the × at the end of the label, a tooltip says what a click does
  r = K.close_spot(a.label)
  K.focus(e)
  w.mouse = typeof(w.mouse)(px(r[1] + r[3] / 2), px(r[2] + r[4] / 2))
  onmouse(w, MouseMove(Vec2{px}(px(r[1] + r[3] / 2), px(r[2] + r[4] / 2)), w))
  @test any(p -> p.key == :tooltip, popups(w)) && K.close_words(e, a) == "Stop the agent"
  # The × stops the agent, and takes the field away
  click_at(r)
  finish()
  @test a.stopped && isempty(K.ask_boxes(e)) && !shows(f)
  picker().asked = nothing
  # The field of an answer: Close hides it, and the box round the words has a label of its own that opens it again
  K.AGENT_COMMAND[] = `sh $quiet`
  ask!("is this right?")
  finish()
  f = only(K.ask_boxes(e))
  @test length(f.answers) == 1 && shows(f)
  picker().asked = nothing   # the label of the request that ended goes after a few seconds
  frames(w, 2)
  @test f.label !== nothing && K.box_label(f) == "Claude's answer" && K.close_words(e, f) == "Take the box and its answers away"
  close!(f)
  @test only(K.ask_boxes(e)) === f && f.closed && !shows(f) && K.box_label(f) == "Claude's answer  ·  Click to open"
  click_at(f.label)
  @test shows(f) && !f.closed && w.focus === f.parts[:text]
  # A new answer shows a field that Close hid
  close!(f)
  K.show_answer!(e, K.AskedChange(words="and?", places=[f.thing]), "Yes.")
  frames(w, 2)
  @test shows(f) && !f.closed && length(f.answers) == 2 && K.box_label(f) == "Claude's answers"
  # The × at the end of the box's label takes it away, with its answers
  click_at(K.close_spot(f.label))
  @test isempty(K.ask_boxes(e)) && !shows(f)
  K.focus(e)
end

@testset "a click on a field goes to the field, never to a label that the field covers" begin
  b = e.buf
  picker().asked = picker().about = nothing
  K.focus(e)
  # An agent works on the block of code under the words "The end.", and the label of its request is on the block's top edge
  K.AGENT_COMMAND[] = `sh -c "exec sleep 30"`
  K.ask_agent!(e, first(offered(e, (10, 0))), "make it two")
  frames(w, 3)
  working = picker().asked
  b.anchor, b.caret = (7, 0), (7, 8)
  K.page_act!(e, 1)
  frames(w, 2)
  a = only(K.ask_boxes(e))
  # The field of the words "The end." covers that label
  s = only(filter(p -> p.key == K.box_key(a), popups(w))).scene
  left, top, wide, tall = working.label
  x, y = px(left + wide / 2), px(top + tall / 2)
  @test s.left <= x <= s.left + s.width && s.top <= y <= s.top + s.height
  # A click there goes to the field: the agent works on, and the field stays with the keyboard
  typed(w, "half a request")
  K.focus(e)
  click(w, x, y)
  @test picker().asked === working && working.ended == 0 && !working.stopped
  @test only(K.ask_boxes(e)) === a && a.parts[:text].buf.lines == ["half a request"]
  # A field with nothing in it stays when the window shows another file and then its page again
  K.focus(a.parts[:text])
  press(w, Keys.a, Keys.cmd); press(w, Keys.backspace)
  @test a.parts[:text].buf.lines == [""]
  K.open!(e, source); frames(w, 2)
  K.open!(e, page); frames(w, 3)
  @test only(K.ask_boxes(e)) === a && any(p -> p.key == K.box_key(a), popups(w))
  K.close_ask!(a, w)
  K.stop_agent!(e)
  finish()
  picker().asked = nothing
  empty!(K.asks_ended(e))
end

@testset "the card of an answer stays until a click on it, and a new question keeps it under its thing" begin
  level = first(offered(e, (3, 0)))
  picker().asked = picker().about = nothing
  K.AGENT_COMMAND[] = `sh $quiet`
  "Ask the question `words` about the level, and wait for the answer"
  ask(words) = begin
    K.ask_about!(e, level, words)
    from = time()
    while picker().about.ended == 0 && time() - from < 20
      frames(w, 1); sleep(0.05)
    end
    frames(w)
    picker().about
  end
  q = ask("why is it blue?")
  @test q.answer == "I looked, and it's as you say." && q.card !== nothing
  # A click on the page leaves the card
  click(w, on_line(e, 1)...)
  frames(w)
  @test picker().about === q && q.card !== nothing
  # A new question puts the answer of the card in a field under its thing
  r = ask("and why short?")
  @test r !== q && r.words == "and why short?"
  a = only(K.ask_boxes(e))
  @test a.answers == [(asked="why is it blue?", answer="I looked, and it's as you say.", by="Claude")] && K.same_things([a.thing], [level])
  frames(w, 2)
  @test any(p -> p.key == K.box_key(a), popups(w))
  # So does an answer of Ask Agent, which shows in a card too
  K.ask_agent!(e, level, "and why there?")
  finish()
  @test [x.asked for x in a.answers] == ["why is it blue?", "and why short?"] && picker().about.words == "and why there?"
  K.close_ask!(a, w)
  picker().asked = picker().about = nothing
end

@testset "the words that the agent of a page reads, of a margin comment and of a block of code" begin
  b = e.buf
  card = K.CommentCard(line=7, lines=["Is this", "right?"])
  c = K.ToChange("Comment", "", "/x/main.jl", 10, 20, card, nothing)
  @test K.thing_told(e, c) == "A comment in the margin of the page, on line 7. It says: Is this right?\n\nLadder draws it with the code in the file /x/main.jl, lines 10 to 20."
  block = only(filter(c -> c.note == "julia block · line 10", offered(e, (3, 0))))
  @test K.thing_told(e, block) == "a block of Julia code on a page of Markdown, in the file $(block.file), lines 10 to 10. It starts:\n\n    x = 1"
  @test K.quoted_lines(["a", "b", "c"], 2, 3) == "    b\n    c"
  @test endswith(K.quoted_lines(string.(1:20), 1, 20), "    12\n    …")
  told = K.Agent.request("/p.md", ["one"], ["one", "two"], "fix A", ["first", "second"], "\nBefore this, a question.\n")
  @test occursin("The user marked these things in the window with letters", told) && occursin("\nA: first\n\nB: second\n", told)
  @test occursin("Before this, a question.", told) && occursin("+two", told)
  @test !occursin("changed in the page", K.Agent.request("/p.md", ["one"], ["one"], "fix", String[]))
end

@testset "Keep This Change adds the function to the startup page" begin
  @test K.loaded_name(realpath(source)) == "ladder-ask-change-test/level.jl"
  @test K.loaded("ladder-ask-change-test/level.jl") === K.loaded_module(realpath(source))
  @test_throws ErrorException K.loaded("no-such-file.jl")
  b = code.buf
  frames(cw, 3)
  i = findfirst(startswith("wide(l::Level)"), b.lines)
  b.caret = b.anchor = (i, 3)
  # Only a file that the app writes again when it starts has a change to keep
  @test_throws ErrorException K.keep_change!(code)
  K.SOURCE_FILES["/built/level.jl"] = realpath(source)
  K.edit!(b, (i, 0), (i, length(b.lines[i])), "wide(l::Level) = 50px")
  K.keep_change!(code)
  frames(w, 3)
  # The function is as it's kept, in the app that runs
  @test rect(node()).width == 50px
  kept = read(K.startup_page(), String)
  @test occursin("## Kept: `wide(l::Level)` of ladder-ask-change-test/level.jl\n\n```julia\n@eval Ladder.loaded(\"ladder-ask-change-test/level.jl\") begin\n\"How wide the bar of a tank is\"\nwide(l::Level) = 50px\nend\n```\n", kept)
  # A function that was kept before is kept as it is now, in the same place
  K.edit!(b, (i, 0), (i, length(b.lines[i])), "wide(l::Level) = 70px")
  K.keep_change!(code)
  kept = read(K.startup_page(), String)
  @test count("## Kept:", kept) == 1 && occursin("wide(l::Level) = 70px\nend", kept) && !occursin("50px", kept)
  # The startup page's code gives the function to the module of its file
  K.edit!(b, (i, 0), (i, length(b.lines[i])), "wide(l::Level) = 90px")
  K.run_code(code, b.lines[i])
  frames(w, 3)
  @test rect(node()).width == 90px
  K.run_startup!()
  frames(w, 3)
  @test rect(node()).width == 70px
  delete!(K.SOURCE_FILES, "/built/level.jl")
end

foreach(o -> (win = K.window_of(o); win === nothing || close(win)), copy(K.editors))
