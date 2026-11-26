# Tests for the `schedule` block of main.jl: the bars of the page's tasks, the
# links between them, and the days that show beside a to-do item. Run them with
# `julia -O0 --project=. test/schedule_view_test.jl`. They click and type in a window
# that isn't on the screen.

@use Test: @test, @testset
@use Dates: Dates, Date, Day
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype onscroll
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups onpinch
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "../main" => K
const S, px = K.Schedules, K.px

# 9 November 2026 is a Monday
const MON = Date(2026, 11, 9)

const dir = mktempdir()
const page = joinpath(dir, "job.md")
write(page, """
# A job

- [x] Dig the trench
- [ ] Lay the pipe
- [ ] Test the pipe
- [ ] Fill the trench, and then put back the turf and the paving that was lifted, all of it, as it was before

```schedule
start: 2026-11-09

Dig the trench | 2 days
Lay the pipe | after Dig the trench
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
const v = only(node for node in values(e.nodes) if node isa K.ScheduleView)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
"Press the mouse at one place, move it to another by way of the place between, and let go"
drag(from, to) = (press(from); at(((from[1] + to[1]) / 2, (from[2] + to[2]) / 2)); at(to); release())
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())
command(k) = (w.keys |= Keys.cmd; key(k); w.keys ⊻= Keys.cmd)
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
button(key) = click(middle(rect(v.parts[(:button, key)])))
block() = (s = K.block_lines(e.buf, K.SCHEDULE, 1); e.buf.lines[s[1]+1:s[2]-1])
task(i) = v.tasks[i]
days(i) = (task(i).start, task(i).finish)
"The middle of the bar of the task at place `i`, its right end, and the circle after it"
bar(i) = (b = K.task_bar(v, i); (b[1] + b[3] / 2, b[2] + b[4] / 2))
bar_end(i) = (b = K.task_bar(v, i); (b[1] + b[3] - 2, b[2] + b[4] / 2))
knob(i) = K.knob(v, i)
"A place that's `n` days to the right of the place `p`"
right(p, n) = (p[1] + n * v.zoom, p[2])
"The middle of the row of the page that shows line `i`"
line_place(i, dx=120) = (it = K.item(e, i); (K.num(e.origin[1]) + dx, K.num(e.origin[2] + it.top + it.tall / 2)))
details() = e.nodes[:task_details]
shows_details() = any(n -> n === details(), K.task_over(e) |> x -> isempty(x) ? () : x[1].children)

@testset "the block shows the page's tasks" begin
  @test [t.todo.name for t in v.tasks][1:3] == ["Dig the trench", "Lay the pipe", "Test the pipe"]
  @test days(1) == (MON, MON + Day(1)) && days(2) == (MON + Day(2), MON + Day(2)) && days(3) == (MON, MON)
  @test task(2).after == [1] && task(1).todo.done
  @test v.zoom > 0 && K.day_x(v, K.daynum(MON)) > v.box[1]
  # The bar of the last task is in sight, with room after it
  @test K.task_bar(v, 4)[1] + K.task_bar(v, 4)[3] < v.box[1] + v.box[3]
  @test any(en -> en.title == "Schedule", K.outline(e.buf))
  html = K.page_html(e)
  @test occursin("<td>Dig the trench</td><td>Mon 9 Nov</td><td>Tue 10 Nov</td><td>2 days</td>", html)
  @test occursin("<td>Lay the pipe</td><td>Wed 11 Nov</td><td>Wed 11 Nov</td><td>1 day</td><td>Dig the trench</td>", html)
  @test any(x -> x isa Tuple && x[1] == "Schedule", K.INSERTS)
  @test !K.dirty(e.buf)
end

@testset "what's under the mouse" begin
  area = K.chart(v)
  pointer(p) = (at(p); K.cursor(area))
  @test K.under(v, bar(1)...) == (:bar, 1) && pointer(bar(1)) == :hand
  @test K.under(v, bar_end(1)...) == (:edge, 1) && pointer(bar_end(1)) == :resize_x
  @test K.under(v, knob(2)...) == (:knob, 2, 1) && pointer(knob(2)) == :hand
  @test K.under(v, right(bar(4), 6)...) == (:row, 4) && pointer(right(bar(4), 6)) == :arrow
  # The arrow from the first task to the second
  ps = K.link_points(v, 1, 2)
  spot = ((ps[2][1] + ps[3][1]) / 2, (ps[2][2] + ps[3][2]) / 2)
  @test K.under(v, spot...) == (:link, 1, 2, 0, 1) && pointer(spot) == :hand
  # A bar says its days
  at(bar(1))
  @test !isempty(popups(w))
  @test K.task_words(task(1)) == "Mon 9 Nov – Tue 10 Nov  ·  2 days"
end

@testset "how long a task takes" begin
  before = block()
  from = bar_end(3)
  press(from); at(right(from, 1)); at(right(from, 2))
  @test task(3).days == 3 && block() == before   # nothing is written until the button comes up
  release()
  @test task(3).days == 3 && days(3) == (MON, MON + Day(2))
  @test block() == ["start: 2026-11-09", "", "Dig the trench | 2 days", "Lay the pipe | after Dig the trench", "Test the pipe | 3 days"]
  @test K.dirty(e.buf) && e.buf.caret[1] < v.first
  # A bar is never shorter than a day
  drag(bar_end(3), right(bar_end(3), -6))
  @test task(3).days == 1 && length(block()) == 4
  # A task that gets longer moves the task that waits for it. The Friday's task goes to the Monday.
  drag(bar_end(1), right(bar_end(1), 2))
  @test task(1).days == 4 && days(2) == (MON + Day(4), MON + Day(4))
  drag(bar_end(1), right(bar_end(1), 1))
  @test task(1).days == 5 && days(2) == (MON + Day(7), MON + Day(7))
  # ⌘Z takes a change back
  command(Keys.z)
  @test task(1).days == 4 && days(2) == (MON + Day(4), MON + Day(4))
  command(Keys.z)
  @test task(1).days == 2
end

@testset "when a task starts" begin
  # Dragged to the Thursday, the task starts there
  drag(bar(3), right(bar(3), 3))
  @test days(3) == (MON + Day(3), MON + Day(3))
  @test block()[end] == "Test the pipe | from 2026-11-12"
  # Dragged onto the Saturday, it starts on the Monday after
  drag(bar(3), right(bar(3), 2))
  @test days(3)[1] == MON + Day(7) && block()[end] == "Test the pipe | from 2026-11-16"
  # A task that waits for another can't start before it's finished, and has no day of its own there
  drag(bar(2), right(bar(2), -2))
  @test days(2)[1] == MON + Day(2) && block()[4] == "Lay the pipe | after Dig the trench"
  drag(bar(2), right(bar(2), 1))
  @test days(2)[1] == MON + Day(3) && block()[4] == "Lay the pipe | from 2026-11-12 | after Dig the trench"
  drag(bar(2), right(bar(2), -1))
  @test block()[4] == "Lay the pipe | after Dig the trench"
  # Back on the day that the work starts, the task has no line
  drag(bar(3), right(bar(3), -7))
  @test days(3)[1] == MON && length(block()) == 4
end

@testset "links" begin
  # From the circle after the second task to the third: the third waits for the second
  drag(knob(2), bar(3))
  @test task(3).after == [2] && days(3)[1] == MON + Day(3)
  @test block()[end] == "Test the pipe | after Lay the pipe"
  @test v.said == ""
  # The first task can't wait for the third, which waits for it
  drag(knob(3), bar(1))
  @test isempty(task(1).after) && occursin("waits for", v.said)
  # A link to the task itself, or one that's there already, changes nothing
  before = block()
  drag(knob(2), bar(2)); drag(knob(2), bar(3))
  @test block() == before
  # Click the arrow, and Delete takes the link away
  ps = K.link_points(v, 2, 3)
  click(((ps[end-1][1] + ps[end][1]) / 2, ps[end][2]))
  @test v.picked == (:link, "Lay the pipe", "Test the pipe", 0, 1) && w.focus === K.chart(v)
  key(Keys.delete)
  @test isempty(task(3).after) && v.picked === nothing && length(block()) == 4
  # Delete with nothing selected leaves the page as it is
  lines = copy(e.buf.lines)
  key(Keys.delete)
  @test e.buf.lines == lines
end

@testset "the days in sight" begin
  # A drag of the days moves them
  was = v.at
  drag(right(bar(4), 6), right(bar(4), 4))
  @test isapprox(v.at, was + 2, atol=0.01) && v.picked === nothing
  # The buttons show more days and fewer, and all the tasks again
  zoom = v.zoom
  button(:smaller)
  @test v.zoom ≈ zoom / 1.4
  button(:bigger)
  @test v.zoom ≈ zoom
  spot = (v.box[1] + v.box[3] / 2, bar(4)[2])   # in the fourth task's row, in the middle of the days
  at(spot)
  onpinch(w, 1.5); frames()
  @test v.zoom ≈ min(1.5zoom, K.DAY_MOST)
  button(:fit)
  @test v.zoom <= K.DAY_USUAL && v.at == K.daynum(MON) - 1
  # Scrolling sideways moves the days. Scrolling up and down is the page's.
  was = v.at
  at(spot); onscroll(w, Vec2{px}(px(-2), px(0))); frames()
  @test v.at > was
  was = v.at
  onscroll(w, Vec2{px}(px(0), px(-2))); frames()
  @test v.at == was
  # A sideways scroll over the names of the tasks moves the days too
  name = middle(rect(v.parts[(:name, task(4).todo.key)]))
  at(name); onscroll(w, Vec2{px}(px(-2), px(0))); frames()
  @test v.at > was
  # And a pinch there shows fewer days, round the first day that shows
  zoom, first = v.zoom, v.at
  onpinch(w, 1.5); frames()
  @test v.zoom > zoom && v.at ≈ first
  button(:fit)
end

@testset "a schedule that fills the window" begin
  small, offset = v.box, e.scroll.offset
  button(:full)
  @test v.full && K.full_block(e) === v && w.focus === K.chart(v)
  # It's as wide as the window, and its days go down to the window's foot
  @test v.box[3] > small[3] + 150 && isapprox(v.box[2] + v.box[4], 900, atol=1)
  @test K.task_bar(v, 4)[1] + K.task_bar(v, 4)[3] < v.box[1] + v.box[3]
  # The page's to-do items are under it, and show no days
  at(line_place(4))
  @test isempty(K.task_over(e))
  # A bar is dragged there as it is in the page
  drag(bar_end(3), right(bar_end(3), 1))
  @test task(3).days == 2 && block()[end] == "Test the pipe | 2 days"
  drag(bar_end(3), right(bar_end(3), -1))
  @test task(3).days == 1
  # Esc takes the selection away, then puts the schedule back in the page, where the page was
  @test v.picked !== nothing
  key(Keys.escape)
  @test v.picked === nothing && v.full
  key(Keys.escape)
  @test !v.full && K.full_block(e) === nothing && e.scroll.offset == offset
  @test v.box[3] ≈ small[3] && v.box[4] ≈ small[4]
  # The button puts it back too
  button(:full); button(:full)
  @test !v.full
end

@testset "the day that the work starts, and the days that are worked" begin
  button(:start)
  @test v.asking && w.focus === K.schedule_input(v) && K.schedule_input(v).text == "9 Nov 2026"
  command(Keys.a); typed("someday"); key(Keys.enter)
  @test v.asking && occursin("can't read", v.said)
  command(Keys.a); typed("16 Nov 2026"); key(Keys.enter)
  @test !v.asking && v.data.start == MON + Day(7) && block()[1] == "start: 2026-11-16"
  @test days(1)[1] == MON + Day(7) && v.at == K.daynum(MON + Day(7)) - 1
  # Esc leaves the day as it was
  button(:start); typed("1 Jan 2030"); key(Keys.escape)
  @test !v.asking && v.data.start == MON + Day(7)
  command(Keys.z)
  @test v.data.start == MON
  # With every day worked, a task that ends on the Friday is followed on the Saturday
  drag(bar_end(1), right(bar_end(1), 3))
  @test days(1) == (MON, MON + Day(4)) && days(2)[1] == MON + Day(7)
  button(:weekends)
  @test v.data.weekends && block()[2] == "days: every day" && days(2)[1] == MON + Day(5)
  button(:weekends)
  @test !v.data.weekends && days(2)[1] == MON + Day(7)
  drag(bar_end(1), right(bar_end(1), -3))
  @test task(1).days == 2
end

@testset "a to-do item shows its days under the mouse" begin
  @test isempty(K.task_over(e))
  # The second task's line of the page
  at(line_place(4))
  @test !isempty(K.task_over(e)) && details().key == "Lay the pipe" && !details().floats
  @test K.task_days(K.task_of(details())) == "Wed 11 Nov"
  # The button on the right makes the task a day longer, and the one on the left a day shorter
  more, less = middle(rect(details().more)), middle(rect(details().less))
  click(more)
  @test task(2).days == 2 && block()[4] == "Lay the pipe | 2 days | after Dig the trench"
  @test e.buf.caret[1] != 4   # the caret didn't go to the line
  # They stay while the mouse is on them
  @test !isempty(K.task_over(e)) && details().key == "Lay the pipe"
  click(more); click(less); click(less)
  @test task(2).days == 1
  click(less)
  @test task(2).days == 1
  # A long item has no room in its lines, so its days are under it
  at(line_place(6))
  @test details().key == task(4).todo.key && details().floats
  # Off the items, they go
  at(line_place(1))
  @test isempty(K.task_over(e))
  # As rich text, the item that the caret is on shows its days too
  e.buf.caret = e.buf.anchor = (4, 8)
  at(line_place(4))
  @test !isempty(K.task_over(e))
  # As plain text, the item still shows its box while the caret is in its words, and its days with it
  e.plain = true
  frames()
  at(line_place(4))
  @test !isempty(K.task_over(e))
  # With the caret in the - [ ] that starts it, the item shows that markup, and no days
  e.buf.caret = e.buf.anchor = (4, 1)
  frames()
  at(line_place(4))
  @test isempty(K.task_over(e))
  e.plain = false
  e.buf.caret = e.buf.anchor = (1, 0)
  frames()
end

@testset "a task that's renamed in the page keeps its line of the schedule" begin
  e.buf.caret = e.buf.anchor = (4, length(e.buf.lines[4]))
  K.focus(e)   # as a click on the line does
  typed(" in its bed")
  @test e.buf.lines[4] == "- [ ] Lay the pipe in its bed"
  @test task(2).after == [1] && task(2).todo.name == "Lay the pipe in its bed" && v.renamed
  @test block()[4] == "Lay the pipe | after Dig the trench"
  # Saving the page writes the new name in the schedule
  K.save_page!(e)
  @test block()[4] == "Lay the pipe in its bed | after Dig the trench" && !v.renamed
  @test occursin("Lay the pipe in its bed | after Dig the trench", read(page, String))
  # A task that's ticked in the page is done in the schedule
  e.buf.caret = e.buf.anchor = (1, 0)
  frames()
  K.tick!(e, 4); frames()
  @test task(2).todo.done
  # Two clicks on a task's bar go to its line of the page
  click(bar(3)); click(bar(3))
  @test e.buf.caret == (5, length(e.buf.lines[5])) && w.focus === e
end

@testset "a page with no start, and a page with no tasks" begin
  other = joinpath(dir, "other.md")
  write(other, "- [ ] One\n- [ ] Two\n\n```schedule\n```\n\nThe end.\n")
  K.open!(e, other); frames()
  u = K.block_view(e, K.SCHEDULE, 1)
  today = S.workday(Dates.today(), false)
  @test length(u.tasks) == 2 && u.tasks[1].start == today
  # The first change writes the day that the work starts
  b = K.task_bar(u, 1)
  drag((b[1] + b[3] - 2, b[2] + b[4] / 2), (b[1] + b[3] - 2 + u.zoom, b[2] + b[4] / 2))
  s = K.block_lines(e.buf, K.SCHEDULE, 1)
  @test e.buf.lines[s[1]+1:s[2]-1] == ["start: $today", "", "One | 2 days"]
  empty = joinpath(dir, "empty.md")
  write(empty, "# Nothing to do\n\n```schedule\n```\n\nThe end.\n")
  K.open!(e, empty); frames()
  @test isempty(K.block_view(e, K.SCHEDULE, 1).tasks)
  # A page with no schedule shows no days beside its to-do items
  plain = joinpath(dir, "plain.md")
  write(plain, "- [ ] One\n- [ ] Two\n\nThe end.\n")
  K.open!(e, plain); frames()
  at(line_place(2))
  @test isempty(K.task_over(e))
end

@testset "a task that repeats has a bar for each run" begin
  K.calendar_day[] = MON
  job = joinpath(dir, "repeats.md")
  write(job, """
  - [ ] Dig the trench
  - [ ] Water the slab every 2 days

  ```schedule
  start: 2026-11-09

  Dig the trench | 2 days
  ```

  ```day
  ```

  The end.
  """)
  K.open!(e, job); frames()
  u = K.block_view(e, K.SCHEDULE, 1)
  nov(n) = Date(2026, 11, n)
  # Every two days from Monday 9: the run that's due on Sunday 15 is done on Monday 16
  runs = K.task_runs(u, 2)
  @test runs[1:4] == [(nov(11), nov(11)), (nov(13), nov(13)), (nov(16), nov(16)), (nov(17), nov(17))]
  @test isempty(K.task_runs(u, 1))
  # Each run has a bar of its own, and the mouse over it says its days and how often the task repeats
  r = K.bar_box(u, 2, nov(13), nov(13))
  spot = (r[1] + r[3] / 2, r[2] + r[4] / 2)
  @test K.under(u, spot...) == (:run, 2, nov(13), nov(13))
  at(spot)
  @test any(p -> p.key == :tooltip, popups(w))
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "schedule-repeats.png"), w)
  # A drag of a run moves every run: the first one starts a day later, and so do the others
  drag(spot, (spot[1] + u.zoom, spot[2]))
  s = K.block_lines(e.buf, K.SCHEDULE, 1)
  @test e.buf.lines[s[1]+1:s[2]-1] == ["start: 2026-11-09", "", "Dig the trench | 2 days", "Water the slab every 2 days | from 2026-11-10"]
  @test u.tasks[2].start == nov(10) && K.task_runs(u, 2)[1] == (nov(12), nov(12))
  K.undo!(e.buf); frames()
  @test u.tasks[2].start == nov(9)
  # On another day, the runs that are finished by then are done, and the task itself is never done: its next run is to come
  water = u.tasks[2]
  K.set_day!(K.block_view(e, K.DAY_BLOCK, 1), nov(13)); frames()
  @test K.standing(e, water) == :doing && !K.finished(e, water) && K.ticked_then(e, 2) == false
  @test K.run_done(e, nov(11), nov(11), false) && !K.run_done(e, nov(13), nov(13), false) && K.run_done(e, water.start, water.finish, false)
  K.set_day!(K.block_view(e, K.DAY_BLOCK, 1), nov(14)); frames()
  @test K.standing(e, water) == :todo && K.standing(e, u.tasks[1]) == :done
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "schedule-repeats-day.png"), w)
  K.calendar_day[] = nothing
end

@testset "a task that repeats for a while has a bar for each time, and is done after the last" begin
  K.calendar_day[] = MON
  job = joinpath(dir, "repeats-limit.md")
  write(job, """
  - [ ] Pour the slab
  - [ ] Water the slab every day for 3 days

  ```schedule
  start: 2026-11-09

  Water the slab every day for 3 days | after Pour the slab
  ```

  ```day
  ```

  The end.
  """)
  K.open!(e, job); frames()
  u = K.block_view(e, K.SCHEDULE, 1)
  nov(n) = Date(2026, 11, n)
  water = u.tasks[2]
  # The first bar is on the 10th, after the pour, and two more are on the 11th and 12th, however many days show
  @test (water.start, K.task_runs(u, 2)) == (nov(10), [(nov(11), nov(11)), (nov(12), nov(12))])
  # The mouse over a run says its days, and the limit with how often
  r = K.bar_box(u, 2, nov(12), nov(12))
  spot = (r[1] + r[3] / 2, r[2] + r[4] / 2)
  @test K.under(u, spot...) == (:run, 2, nov(12), nov(12))
  at(spot)
  @test any(p -> p.key == :tooltip, popups(w))
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "schedule-repeats-limit.png"), w)
  u.zoom /= 4; frames()
  @test length(K.task_runs(u, 2)) == 2
  # On the day of the last run the task is being done, and after it the task is done
  K.set_day!(K.block_view(e, K.DAY_BLOCK, 1), nov(12)); frames()
  @test K.standing(e, water) == :doing && !K.finished(e, water)
  K.set_day!(K.block_view(e, K.DAY_BLOCK, 1), nov(13)); frames()
  @test K.standing(e, water) == :done && K.finished(e, water)
  K.calendar_day[] = nothing
end

@testset "each time of a task that repeats has its own circle, and its own links" begin
  K.calendar_day[] = MON
  job = joinpath(dir, "repeats-links.md")
  write(job, """
  - [ ] Pour the slab
  - [ ] Water the slab every day for 3 days
  - [ ] Cut the joints
  - [ ] Book the pump
  - [ ] Seal the slab

  ```schedule
  start: 2026-11-09

  Water the slab every day for 3 days | after Pour the slab
  Book the pump | 4 days
  ```

  The end.
  """)
  K.open!(e, job); frames()
  u = K.block_view(e, K.SCHEDULE, 1)
  W = "Water the slab every day for 3 days"
  lines() = (s = K.block_lines(e.buf, K.SCHEDULE, 1); e.buf.lines[s[1]+1:s[2]-1])
  nov(n) = Date(2026, 11, n)
  mid(b) = (b[1] + b[3] / 2, b[2] + b[4] / 2)
  # The third time leaves no room after the second, so the second's circle is on its own top right corner
  b2 = K.time_bar(u, 2, 2)
  k2, corner = K.knob_place(b2, K.time_bar(u, 2, 3))
  @test corner && b2[1] < k2[1] < b2[1] + b2[3] && k2[2] == b2[2]
  @test K.under(u, k2...) == (:knob, 2, 2)
  # The last time's circle is after its bar, where there's room
  b3 = K.time_bar(u, 2, 3)
  @test !K.knob_place(b3, nothing)[2] && K.knob(u, 2, 3)[1] > b3[1] + b3[3]
  # The mouse on a time shows that time's circle. Elsewhere in the row, the circle is the last time's: the task as a whole.
  at(mid(b2))
  @test K.hot_time(u, 2) == 2
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "schedule-time-knob.png"), w)
  at(mid(K.time_bar(u, 2, 1)))
  @test K.hot_time(u, 2) == 1
  at((b3[1] + b3[3] + 3u.zoom, b3[2] + b3[4] / 2))
  @test K.hot_time(u, 2) == 3
  # From the second time's circle to the joints: they wait for the second time
  drag(k2, mid(K.task_bar(u, 3)))
  @test "Cut the joints | after time 2 of $W" in lines() && u.tasks[3].start == nov(12)
  # From the last time's circle, the link is to the task as a whole
  drag(K.knob(u, 2, 3), mid(K.task_bar(u, 5)))
  @test "Seal the slab | after $W" in lines() && u.tasks[5].start == nov(13)
  # To the bar of the third time: it waits for the pump, and so does the sealing, after it
  drag(K.knob(u, 4), mid(K.time_bar(u, 2, 3)))
  @test "time 3 of $W | after Book the pump" in lines()
  @test u.tasks[2].runs[2] == (nov(13), nov(13)) && u.tasks[5].start == nov(16)
  # The second time can't wait for the joints, which wait for it
  drag(K.knob(u, 3), mid(K.time_bar(u, 2, 2)))
  @test occursin("waits for", u.said) && !any(startswith("time 2 of"), lines())
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "schedule-time-links.png"), w)
  # The arrow to the third time says which day it goes to. Click it, and Delete takes it away.
  ps = K.link_points(u, 4, 1, 2, 3)
  spot = ((ps[end-1][1] + ps[end][1]) / 2, ps[end][2])
  @test K.under(u, spot...) == (:link, 4, 2, 0, 3)
  @test K.time_words(u, 2, 3) == "“$(W)” on Fri 13 Nov"
  click(spot)
  @test u.picked == (:link, "Book the pump", W, 0, 3)
  key(Keys.delete)
  @test !any(startswith("time 3 of"), lines()) && u.tasks[2].runs[2] == (nov(12), nov(12))
  K.calendar_day[] = nothing
end

foreach(close, (w,))
