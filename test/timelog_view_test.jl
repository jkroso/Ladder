# Tests for the `timelog` block of main.jl: the hours of each task, and the
# button that starts and stops the clock. Run them with
# `julia -O0 --project=. test/timelog_view_test.jl`. They click and type in a
# window that isn't on the screen. The test gives the time now, so nothing
# here depends on the clock. Set `LADDER_SHOTS` to a folder, and they save
# pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups _soon
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use Dates: DateTime, Second, Minute
@use "./drive" drive middle
const px = K.px
const T = K.Timelogs

# The time that the block reads as now. A test moves it on.
const NOW = Ref(DateTime(2026, 11, 18, 9, 12, 0))
T.CLOCK[] = () -> NOW[]

const dir = mktempdir()
const page = joinpath(dir, "job.md")
write(page, """
# A job

```timelog
rate: 85

2026-11-17 07:30-12:00 | Framing
2026-11-17 12:30-15:45 | Framing
this line is not a stretch of work
2026-11-18 07:00-08:00 | Roofing
```

```chart
```

```timelog
```

```timelog
2026-11-18 08:00-08:20 | Painting the shed
round: a lot
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1300px))
const (; frames, at, press, release, click, typed, key, shot) = drive(w)
frames()
log(n=1) = e.nodes[(:block, K.TIMELOG, page, n)]

block(n=1) = (s = K.block_lines(e.buf, K.TIMELOG, n); e.buf.lines[s[1]+1:s[2]-1])
button(n=1) = log(n).parts[(:button, :clock)]
cell(i, part, n=1) = log(n).parts[(:cell, i, part)]
offers() = any(p -> p.key == K.TASKS_KEY, popups(w))
"Every piece of text that a node shows"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.SemanticUI ? texts(K.describe(node), out) :
  node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end
"How soon the log asks the window to draw again, in seconds, or nothing when it doesn't ask"
asks(v) = (delete!(_soon, objectid(w)); K.describe(v); pop!(_soon, objectid(w), nothing))
"The time now moves on"
pass(period) = (NOW[] += period; frames())

@testset "the block shows a row for each stretch, and the totals" begin
  v = log()
  said = texts(v)
  # The day shows once for its rows, and each row has its times, its hours and its task
  @test count(==("Tue 17 Nov"), said) == 1 && "Wed 18 Nov" in said
  @test all(t -> t in said, ["Day", "From", "To", "Hours", "Task", "07:30", "12:00", "4 h 30 min", "3 h 15 min", "1 h", "Framing", "Roofing"])
  # A line that can't be read shows as it's written, and counts for nothing
  @test "this line is not a stretch of work" in said
  # The total, with its money, then each task
  @test all(t -> t in said, ["Total", "8 h 45 min", "\$743.75", "7 h 45 min", "\$658.75", "\$85.00"])
  @test button().words == "Start" && !button().on && button().tip == "Start the clock on Roofing"
  @test any(en -> en.title == "Time log", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Time Log", K.INSERTS)
  @test K.Searches.block_kind(K.TIMELOG) == :timelog
  # An empty log says what to do, and a log with a setting that can't be read still shows
  @test any(t -> occursin("no hours yet", t), texts(log(2)))
  @test "round: a lot" in texts(log(3)) && "20 min" in texts(log(3))
  @test !K.dirty(e.buf)
  shot("timelog.png")
end

@testset "Start adds a line for now" begin
  v = log()
  input = K.task_input(v)
  click(middle(rect(input)))
  @test w.focus === input && offers()      # the field offers the tasks that the log has
  @test v.offers == ["Roofing", "Framing"]
  shot("timelog-offers.png")
  typed("Clad")
  @test !offers()                          # no task has that in it
  @test button().tip == "Start the clock on Clad"
  click(middle(rect(button())))
  @test block()[end] == "2026-11-18 09:12- | Clad" && length(block()) == 7 && K.dirty(e.buf)
  @test input.text == "" && w.focus === e
  # The button reads Stop, and is lit while the line runs
  @test button().words == "Stop" && button().on && button().tip == "Stop the clock on Clad"
  @test e.buf.lines[end-1] == "The end."
end

@testset "the row that runs counts up" begin
  v = log()
  @test "0 s" in texts(v) && "now" in texts(v)
  # The log asks the window to draw again in about a second
  @test 0 < asks(v) <= 1.1
  pass(Second(67))
  @test "1 min 07 s" in texts(v) && "8 h 46 min" in texts(v)   # the total has the minute that has gone by
  pass(Minute(61))
  @test "1 h 02 min 07 s" in texts(v) && "9 h 47 min" in texts(v) && "\$87.83" in texts(v)
  shot("timelog-running.png")
  # The page of HTML says that the row runs, and has its hours so far
  @test occursin("<td>09:12</td><td>now</td><td>1 h 2 min</td><td>Clad</td>", K.page_html(e))
  # The chart under the log draws the hours of each task, with the hours of the row that runs
  d = K.shown!(e.nodes[(:block, K.CHART, page, 1)])
  @test isempty(d.problem) && d.labels == ["Framing", "Roofing", "Clad"]
  # A task typed while a line runs makes the button read Start: it stops that line and starts the new one
  click(middle(rect(K.task_input(v))))
  typed("roo")
  @test offers() && v.offers == ["Roofing"] && button().words == "Start"
  @test button().tip == "Stop the clock on Clad, and start it on roo"
  # ↓ picks the task in the list, and Return puts it in the field
  key(Keys.down); key(Keys.enter)
  @test K.task_input(v).text == "Roofing" && !offers() && w.focus === K.task_input(v) && length(block()) == 7
  # Return again starts it
  key(Keys.enter)
  @test block()[end-1:end] == ["2026-11-18 09:12-10:14 | Clad", "2026-11-18 10:14- | Roofing"] && w.focus === e
end

@testset "Stop writes the stop time, and ⌘Z takes each change back" begin
  v = log()
  pass(Minute(30))
  click(middle(rect(button())))
  @test block()[end] == "2026-11-18 10:14-10:44 | Roofing" && button().words == "Start" && !button().on
  @test T.running(v.data) === nothing && !("now" in texts(v))
  # With no line that runs, the log doesn't ask the window to draw again
  @test asks(v) === nothing
  K.undo!(e.buf); frames()
  @test block()[end] == "2026-11-18 10:14- | Roofing" && button().words == "Stop" && T.running(v.data) == 6
  K.undo!(e.buf); frames()
  @test block()[end] == "2026-11-18 09:12- | Clad" && length(block()) == 7
  K.undo!(e.buf); frames()
  @test length(block()) == 6 && block()[end] == "2026-11-18 07:00-08:00 | Roofing" && button().words == "Start"
  K.redo!(e.buf); frames()
  @test block()[end] == "2026-11-18 09:12- | Clad" && button().words == "Stop"
  # Start with an empty field, while no line runs, uses the task of the last line
  click(middle(rect(button()))); frames()
  click(middle(rect(button())))
  @test block()[end-1:end] == ["2026-11-18 09:12-10:44 | Clad", "2026-11-18 10:44- | Clad"]
  click(middle(rect(button())))
  @test block()[end] == "2026-11-18 10:44-10:44 | Clad"
end

@testset "a click on a time or a task changes it in place" begin
  v = log()
  click(middle(rect(cell(1, :to))))
  field = K.cell_input(v)
  @test v.editing == (1, :to) && w.focus === field && field.text == "12:00"
  shot("timelog-editing.png")
  # The time was selected, so what's typed takes its place. Return writes it into the line.
  typed("11:15am"); key(Keys.enter)
  @test block()[3] == "2026-11-17 07:30-11:15 | Framing" && v.editing === nothing && w.focus === e
  @test "3 h 45 min" in texts(v)
  # A time that can't be read stays in the field, and the line stays as it was
  click(middle(rect(cell(1, :from))))
  typed("early"); key(Keys.enter)
  @test v.editing == (1, :from) && v.wrong && block()[3] == "2026-11-17 07:30-11:15 | Framing"
  # Esc leaves the row as it was
  key(Keys.escape)
  @test v.editing === nothing && w.focus === e && block()[3] == "2026-11-17 07:30-11:15 | Framing"
  # A task, and a click somewhere else writes it
  click(middle(rect(cell(2, :task))))
  typed("Cladding")
  click(middle(rect(cell(4, :task))))
  @test block()[4] == "2026-11-17 12:30-15:45 | Cladding" && v.editing == (4, :task)
  key(Keys.escape)
  K.undo!(e.buf); frames()
  @test block()[4] == "2026-11-17 12:30-15:45 | Framing"
end

@testset "the log in a dark page, in a narrow window and as HTML" begin
  html = K.page_html(e)
  @test occursin("<th>Day</th><th>From</th><th>To</th><th>Hours</th><th>Task</th>", html)
  @test occursin("<tr><td>Tue 17 Nov</td><td>07:30</td><td>11:15</td><td>3 h 45 min</td><td>Framing</td></tr>", html)
  @test occursin("<tr><td></td><td>12:30</td><td>15:45</td><td>3 h 15 min</td><td>Framing</td></tr>", html)
  @test occursin(">this line is not a stretch of work</td>", html)
  @test occursin("<tr><th colspan=\"3\">Total</th><th>9 h 32 min</th><th>\$810.33</th></tr>", html)
  @test occursin("<tr><td colspan=\"3\">Clad</td><td>1 h 32 min</td><td>\$130.33</td></tr>", html)
  # In the dark page, with the list of tasks under the field
  e.theme = :night; K.restyle!(e); frames()
  click(middle(rect(K.task_input(log()))))
  @test offers()
  shot("timelog-night.png")
  # Esc closes the list, and Esc again gives the keyboard back to the page
  key(Keys.escape)
  @test !offers() && w.focus === K.task_input(log())
  key(Keys.escape)
  @test w.focus === e
  e.theme = :sepia; K.restyle!(e); frames()
end

@testset "the keyboard alone starts the clock" begin
  # The caret on the block as a whole, then Return, gives the block's field the keyboard
  s = K.block_lines(e.buf, K.TIMELOG, 2)
  e.buf.caret = e.buf.anchor = (s[1], 0); frames()
  @test K.picked(e.buf) !== nothing
  key(Keys.enter)
  @test w.focus === K.task_input(log(2))
  typed("Paint"); key(Keys.enter)
  @test block(2) == ["2026-11-18 10:44- | Paint"] && w.focus === e && T.running(log(2).data) == 1
  K.undo!(e.buf); frames()
  @test isempty(block(2))
end

close(w)

@testset "a narrow window has each day on a line of its own" begin
  n = K.build_editor(page)
  small = Window(n, size=(420px, 1300px))
  foreach(_ -> frame(small), 1:3)
  v = n.nodes[(:block, K.TIMELOG, page, 1)]
  said = texts(v)
  @test !("Day" in said) && count(==("Tue 17 Nov"), said) == 1 && "Total" in said
  # Each row is inside the block
  r, c = rect(v), rect(v.parts[(:cell, 1, :task)])
  @test c.left + c.width <= r.left + r.width && c.width > 40px
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "timelog-narrow.png"), small)
  close(small)
end
