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
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect window_tool
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
  @test occursin("a part of its window, a Level. The function that draws that part", prompt) && occursin("lines 16 to 18", prompt)
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
  @test said().node === node() && p.at == 2 && K.click_chip(e, p) == 1
  # The node's chip shows only a letter in a colour, which the line round the node has too
  letters() = [(l.k, l.letter, l.colour) for l in K.chip_letters(p, K.palette_chips(p))]
  @test letters() == [(1, "A", K.CHIP_MARKS[1])]
  @test K.chip_wide(e, p, K.palette_chips(p), 1) < 40
  # A click on the page's `julia` block chooses it, and the keyboard stays in the words
  click(w, on_line(e, 10)...)
  @test said().words == "x = 1" && p.at == 2 && e.popup == :commands && e.buf.caret == (3, 0)
  # A click on the bar chooses the thing that the block shows
  click(w, middle(rect(node()))...)
  @test said().node === node() && p.at == 2
  # ⇧ and a click add a second thing, B in orange, and the chip shows both letters. Again takes it out.
  w.keys |= Keys.shft
  click(w, on_line(e, 10)...)
  w.keys ⊻= Keys.shft
  @test said() isa K.Things && [x.words for x in said().all] == ["Level", "x = 1"] && p.at == 2
  @test letters() == [(1, "A", K.CHIP_MARKS[1]), (1, "B", K.CHIP_MARKS[2])] && 60 < K.chip_wide(e, p, K.palette_chips(p), 1) < 80
  prompt = K.change_prompt(said().all, "make A look like B")
  @test occursin("A: a part of its window, a Level.", prompt) && occursin("B: a block of Julia code on a page of Markdown, in the file", prompt)
  @test occursin("The user's words: make A look like B", prompt)
  w.keys |= Keys.shft
  click(w, on_line(e, 10)...)
  w.keys ⊻= Keys.shft
  @test said().node === node()
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
  # A click on another block of the file chooses it, and a click on the first chooses it again
  @test K.num(on_line(code, 17)[2]) < K.palette(code).plan.band.y
  click(cw, on_line(code, 17)...)
  @test K.chip_value(p, chips, 1).words == "describe(l::Level)" && p.at == 2
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
  # A second change can't be asked for while the agent is at work
  K.AGENT_COMMAND[] = `sh -c "sleep 5"`
  K.ask_for_change!(e, level, "make it red")
  @test picker().asked.ended == 0
  @test_throws ErrorException K.ask_for_change!(e, level, "and blue")
  kill(picker().asked.process)
  finish()
  picker().asked = nothing
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

@testset "Esc, a click on the label, or Stop Agent stops the agent, and what it changed doesn't run" begin
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
  press(w, Keys.escape)
  finish()
  a = picker().asked
  @test a.stopped && a.changed && a.said == "You stopped the agent. Ladder didn't run what it changed. Undo Change puts it back."
  @test !K.works_here(e, Val(:stop_agent)) && last(K.AGENT_CHANGES) === a
  @test K.CODE_RUNS[] == runs   # Ladder didn't run the half-done change
  K.undo_change!(e)
  @test occursin("wide(l::Level) = 80px", read(source, String))
  # A click on the label while the agent works stops it
  K.AGENT_COMMAND[] = `sh -c "exec sleep 30"`
  K.ask_for_change!(e, level, "make it red")
  frames(w, 2)
  left, top, wide, tall = picker().asked.label
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
  # Esc stops an agent that's answering a question too, and there's no card
  K.ask_about!(e, level, "why is it blue?")
  @test picker().about.ended == 0
  process = picker().about.process
  press(w, Keys.escape)
  @test picker().about === nothing
  sleep(0.2)
  @test process_exited(process)
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
  # So does Esc
  ask_about(answers, level, "why?")
  press(w, Keys.escape)
  @test picker().about === nothing
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
  press(w, Keys.escape); press(w, Keys.escape)
  # The agent that answers can read files, and can't change them. Each agent prints its steps as lines of JSON.
  K.AGENT_COMMAND[] = nothing
  @test endswith(string(K.agent_command(changes=false)), "--allowedTools Read,Grep,Glob -p`")
  @test occursin("--output-format stream-json --verbose", string(K.agent_command()))
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
  @test !K.wide_words(Val(:rename_in_code)) && K.wide_words(Val(:ask_for_change))
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
