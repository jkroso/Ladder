# Tests for checks in a file of Julia code, in main.jl: a comment like
# `# check: share("70%") == 0.7` runs in the module of the file's code, and a
# dot at the end of its line says how it went. A function with checks over it
# runs again as you type. Show Steps shows what each line of a function came
# to, and Fix It and Ask For Checks ask an agent. Run them with
# `julia -O0 --project=. test/file_checks_test.jl`. They draw a window that
# isn't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame window_tool
@use GeometryBasics: Vec2
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

# The folder has the same name each time, so that Kip compiles its file once
const dir = joinpath(tempdir(), "ladder-file-checks-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
@eval K settings_file() = $(joinpath(dir, "settings"))

const source = joinpath(dir, "shares.jl")
write(source, """
"A share written as a percentage, like \\"70%\\", as a number from 0 to 1"
# check: share("70%") == 0.7
# check: share("5%") == 0.5
# check: share("half")
share(s) = parse(Float64, rstrip(s, '%')) / 100

#check:twice(2) == 4
twice(x) = 2x

quarter() = share("25%")
""")

const e = K.build_editor(source)
const w = Window(e, size=(900px, 400px))
frames(n=2) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames(3)
const b = e.buf
results() = e.nodes[:file_checks].results
went(code) = results()[code].went

@testset "the comments that are checks" begin
  @test K.file_checks(b.lines) == [(2, "share(\"70%\") == 0.7"), (3, "share(\"5%\") == 0.5"), (4, "share(\"half\")"), (7, "twice(2) == 4")]
  @test K.file_checks(["# checks: none", "x = 1  # check: not at the start", "# check:", "  # check: indented(1)"]) == [(4, "indented(1)")]
end

@testset "a check in a string in three quotes is text, not a check" begin
  # As in the prompt that Ask For Checks gives an agent, in main.jl
  other = joinpath(dir, "prompt.jl")
  write(other, """
  \"\"\"
  # check: in_docstring()
  \"\"\"
  # check: real(1)
  ask() = \"\"\"
    A check is a comment over a function, like this one:

        # check: in_prompt()
    \"\"\"
  # check: real(2)
  """)
  o = K.build_editor(other)
  K.file_checks_tick!(o)
  @test o.nodes[:file_checks].found == [(4, "real(1)"), (10, "real(2)")]
end

@testset "a check of a function that hasn't run yet says to run it" begin
  @test went("twice(2) == 4") == :stop
  note = K.check_note(results()["twice(2) == 4"], false)
  @test occursin("twice", note) && endswith(note, "Press ⌘Return in its function to run it.")
end

@testset "the checks run again when code runs, and say how each went" begin
  K.run_code(e, join(b.lines, "\n"))
  frames()
  @test went("share(\"70%\") == 0.7") == :pass && went("twice(2) == 4") == :pass
  # A check that compares two values and fails says what the two were
  @test went("share(\"5%\") == 0.5") == :fail && K.check_note(results()["share(\"5%\") == 0.5"], false) == "0.05 == 0.5"
  # One that stops says why
  @test went("share(\"half\")") == :stop && occursin("half", results()["share(\"half\")"].said)
  @test K.check_note(results()["share(\"70%\") == 0.7"], false) == ""
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "file-checks.png"), w)
end

@testset "a check that changes runs again" begin
  K.edit!(b, (3, 16), (3, 17), "50")
  @test b.lines[3] == "# check: share(\"50%\") == 0.5"
  frames()
  @test went("share(\"50%\") == 0.5") == :pass
  # They don't run again while neither a check nor the code changed
  ran = e.nodes[:file_checks].ran
  K.edit!(b, (5, 0), (5, 0), " ")
  frames()
  @test e.nodes[:file_checks].ran === ran
end

@testset "the top bar says how many checks pass, and a click goes to the next that fails" begin
  @test K.check_words(last.(K.file_results(e))) == "3 of 4 checks pass"
  @test !isempty(K.check_part(e))
  @test K.tip(e.nodes[:check_count]) == "Go to the next check that fails"
  b.caret = b.anchor = (1, 0)
  K.next_check!(e)
  @test b.caret[1] == 4
  K.next_check!(e)
  @test b.caret[1] == 4   # the only one that fails now, round to the top again
  b.caret = b.anchor = (5, 0)
  K.next_check!(e)
  @test b.caret[1] == 4
end

@testset "Add Check writes a check of the call at the caret, with the value that it has now" begin
  i = findfirst(startswith("quarter()"), b.lines)
  b.caret = b.anchor = (i, 14)
  @test K.expression_at(e) == (i, "share(\"25%\")")
  K.add_check!(e)
  @test b.lines[i] == "# check: share(\"25%\") == 0.25" && b.lines[i+1] == "quarter() = share(\"25%\")" && b.caret == (i + 1, 14)
  frames()
  @test went("share(\"25%\") == 0.25") == :pass && K.check_words(last.(K.file_results(e))) == "4 of 5 checks pass"
  K.undo!(b)
  @test b.lines[i] == "quarter() = share(\"25%\")"
  # What's selected is the expression
  b.anchor, b.caret = (i, 18), (i, 23)
  K.add_check!(e)
  @test b.lines[i] == "# check: \"25%\" == \"25%\""
  K.undo!(b)
  # A value too long to write, and a call whose values the file doesn't have, write nothing
  @test K.check_value("x", 0.7) == "0.7" && K.check_value("x", "a") == "\"a\""
  @test_throws ErrorException K.check_value("x", collect(1:100))
  j = findfirst(startswith("twice(x)"), b.lines)
  b.caret = b.anchor = (j, 2)
  n = length(b.lines)
  @test_throws ErrorException K.add_check!(e)
  @test length(b.lines) == n
end

@testset "a function with checks over it runs again a second after its text changes, and then its checks" begin
  mod = K.PAGE_MODULES[K.page_key(source)]
  j = findfirst(startswith("twice(x)"), b.lines)
  K.edit!(b, (j, 11), (j, 12), "3")
  @test b.lines[j] == "twice(x) = 3x"
  frames()
  @test went("twice(2) == 4") == :pass   # it waits for a second with no change
  sleep(1.1); frames()
  @test went("twice(2) == 4") == :fail
  # Code that doesn't run yet leaves the checks as they were. The wait starts at the frame after a change.
  K.edit!(b, (j, 13), (j, 13), " +")
  frames(); sleep(1.1); frames()
  @test went("twice(2) == 4") == :fail
  K.edit!(b, (j, 11), (j, 15), "2x")
  frames(); sleep(1.1); frames()
  @test b.lines[j] == "twice(x) = 2x" && went("twice(2) == 4") == :pass
  # A function with no checks over it runs only when you run it
  i = findfirst(startswith("quarter()"), b.lines)
  K.edit!(b, (i, 19), (i, 21), "50")
  @test b.lines[i] == "quarter() = share(\"50%\")"
  frames(); sleep(1.1); frames()
  @test Base.invokelatest(getfield(mod, :quarter)) == 0.25
  K.edit!(b, (i, 19), (i, 21), "25")
end

@testset "Show Steps writes what each line of the function came to" begin
  j = findfirst(l -> occursin("share(s) =", l), b.lines)
  steps = K.check_steps(e, K.FileCheck(3, "share(\"50%\") == 0.5", :pass))
  @test steps.first == j && steps.words == Dict(j => "s = \"50%\"  → 0.5") && steps.stopped == 0
  # The line where the function stopped says why
  steps = K.check_steps(e, K.FileCheck(4, "share(\"half\")", :stop))
  @test steps.stopped == j && startswith(steps.words[j], "s = \"half\"  stopped: ArgumentError")
  # Each line of a longer function, and a loop's last value with how many times it ran. It needn't have run.
  n = length(b.lines)
  K.edit!(b, (n, length(b.lines[n])), (n, length(b.lines[n])), "\n\n# check: total([1, 2, 3]) == 6\nfunction total(xs)\n  sum = 0\n  for x in xs\n    sum += x\n  end\n  sum\nend")
  frames()
  steps = K.check_steps(e, K.FileCheck(n + 2, "total([1, 2, 3]) == 6", :pass))
  @test steps.words == Dict(n + 3 => "xs = [1, 2, 3]", n + 4 => "→ 0", n + 6 => "→ 6  (3 times)", n + 8 => "→ 6")
  # A check that calls no function of the file has no steps
  @test_throws ErrorException K.check_steps(e, K.FileCheck(1, "1 + 1 == 2", :pass))
  # They show until the text changes, or Esc
  K.show_steps!(e, K.FileCheck(n + 2, "total([1, 2, 3]) == 6", :pass))
  frames()
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "show-steps.png"), w)
  @test haskey(e.nodes, :steps)
  onkey(w, KeyPress{Keys.escape}(0, w)); frames()
  @test !haskey(e.nodes, :steps)
  K.show_steps!(e, K.FileCheck(n + 2, "total([1, 2, 3]) == 6", :pass))
  K.edit!(b, (n + 4, 9), (n + 4, 9), " ")
  frames()
  @test !haskey(e.nodes, :steps)
  foreach(_ -> K.undo!(b), 1:2)
  @test length(b.lines) == n
end

"An agent of these tests: it writes the words that it was given to a file, runs `change`, and says `said`"
agent(name, change, said) = begin
  path = joinpath(dir, name)
  write(path, "#!/bin/sh\nprintf '%s' \"\$1\" > \"$dir/asked.txt\"\n$change\necho \"$said\"\n")
  path
end
picker() = window_tool(w)::K.CodePicker
"Wait for the agent, drawing frames, for a few seconds at most"
finish() = begin
  from = time()
  while picker().asked !== nothing && picker().asked.ended == 0 && time() - from < 20
    frames(1); sleep(0.05)
  end
  frames()
end
click(x, y) = begin
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  frames(1)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  frames()
end

@testset "a check that fails has Show Steps and Fix It beside it, and Fix It asks an agent" begin
  i = findfirst(==("# check: share(\"half\")"), b.lines)
  b.caret = b.anchor = (1, 0)
  e.scroll.offset = 0px
  frames()
  @test isempty(e.nodes[:check_buttons])
  # A mouse that moves onto a check's line draws the window again, with the buttons. One that passes has nothing to fix.
  point(y) = (w.mouse = typeof(w.mouse)(300px, y); onmouse(w, MouseMove(Vec2{px}(300px, y), w)))
  it = K.item(e, 2)
  point(e.origin[2] + it.top + it.tall / 2)
  @test e.nodes[:check_hover] == 2
  frames()
  @test first.(e.nodes[:check_buttons]) == [:steps] && e.nodes[:check_buttons][1][3].line == 2
  it = K.item(e, findfirst(startswith("twice(x)"), b.lines))
  point(e.origin[2] + it.top + it.tall / 2)
  @test e.nodes[:check_hover] == 0
  # The buttons show while the caret is on the check's line
  b.caret = b.anchor = (i, 0)
  frames()
  buttons = e.nodes[:check_buttons]
  @test first.(buttons) == [:steps, :fix] && all(x -> x[3].line == i, buttons) && buttons[1][2][2] > 40
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "check-buttons.png"), w)
  left, top, wide, tall = buttons[1][2]
  click(left + wide / 2, top + tall / 2)
  @test haskey(e.nodes, :steps) && e.nodes[:steps].stopped > 0
  # The palette offers the check on the caret's line first, then those that fail
  @test first(K.choices_for(K.FileCheck, e)).line == i && K.chip_start(K.FileCheck, e).line == i
  @test K.works_here(e, Val(:fix_check)) && K.works_here(e, Val(:show_steps))
  # Fix It: the agent gets the check and what it came to, and the check runs again when it ends
  K.AGENT_COMMAND[] = `sh $(agent("fix.sh", "sed -i '' 's/^# check: share(\"half\")\$/# check: share(\"10%\") == 0.1/' \"$source\"", "The check was wrong, so I changed it."))`
  b.caret = b.anchor = (i, 0)
  frames()
  left, top, wide, tall = e.nodes[:check_buttons][2][2]
  click(left + wide / 2, top + tall / 2)
  @test picker().asked !== nothing && picker().asked.words == "Fix the check share(\"half\")"
  finish()
  asked = read(joinpath(dir, "asked.txt"), String)
  @test occursin("The check is the comment on line $i of the file", asked) && occursin("# check: share(\"half\")", asked)
  @test occursin("Now it stops: ArgumentError", asked) && occursin("If the check is what's wrong", asked)
  frames(3)
  @test b.lines[i] == "# check: share(\"10%\") == 0.1" && went("share(\"10%\") == 0.1") == :pass
  @test picker().asked.said == "The check was wrong, so I changed it."
  # A check that passes has nothing to fix
  @test_throws ErrorException K.fix_check!(e, K.FileCheck(i, "share(\"10%\") == 0.1", :pass))
  picker().asked = nothing
end

@testset "Ask For Checks asks an agent for checks with the values that a function should give" begin
  i = findfirst(startswith("quarter()"), b.lines)
  b.caret = b.anchor = (i, 3)
  frames()
  node = first(K.choices_for(K.ToChange, e))
  @test node.first <= i <= node.last
  K.AGENT_COMMAND[] = `sh $(agent("checks.sh", "perl -0pi -e 's/^quarter\\(\\)/# check: quarter() == 0.25\\nquarter()/m' \"$source\"", "It checks a quarter."))`
  K.ask_for_checks!(e, node)
  @test picker().asked.words == "Write checks"
  finish()
  asked = read(joinpath(dir, "asked.txt"), String)
  @test occursin("# check: share(\"70%\") == 0.7", asked) && occursin("Don't copy what the code does now", asked)
  frames(3)
  @test b.lines[i] == "# check: quarter() == 0.25" && went("quarter() == 0.25") == :pass
  @test_throws ErrorException K.ask_for_checks!(e, K.ToChange("x", "", joinpath(dir, "page.md"), 1, 1, nothing, nothing))
  picker().asked = nothing
  K.AGENT_COMMAND[] = nothing
end

@testset "a page of Markdown has no checks of this kind" begin
  page = joinpath(dir, "page.md")
  write(page, "# check: 1 == 2\n")
  K.open!(e, page)
  frames()
  @test !K.julia_file(e)
end

close(w)
