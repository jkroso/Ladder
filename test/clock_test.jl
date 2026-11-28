# Tests for the clock of a to-do item, in main.jl: on a page with a time log,
# a button beside a to-do item starts and stops the log's clock on the item.
# Run them with `julia -O0 --project=. test/clock_test.jl`. They click in a
# window that isn't on the screen.

@use Test: @test, @testset
@use Dates: DateTime, Minute
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "job.md")
write(page, """
# A job

- [ ] Dig the trench
- [ ] Lay the pipe

```timelog
2026-11-19 08:00-10:30 | Lay the pipe
```

```schedule
start: 2026-11-18
Dig the trench | 2 days
```

The end.
""")

const clock = Ref(DateTime(2026, 11, 20, 9, 0))
const real = K.Timelogs.CLOCK[]
K.Timelogs.CLOCK[] = () -> clock[]
try
  e = K.build_editor(page)
  w = Window(e, size=(1000px, 800px))
  (; frames, at, press, release, click) = drive(w, moved=2, pressed=1)
  frames()
  line(text) = findfirst(==(text), e.buf.lines)
  line_at(i) = (it = K.item(e, i); (K.num(e.origin[1]) + 120.0, K.num(e.origin[2] + it.top + it.tall / 2)))
  log() = (s = K.block_lines(e.buf, K.TIMELOG, 1); e.buf.lines[s[1]+1:s[2]-1])
  button() = (r = rect(e.nodes[:item_clock]); (K.num(r.left) + 9.0, K.num(r.top + r.height / 2)))
  hours = e.nodes[(:block, K.TIMELOG, page, 1)]

  @testset "the hours of each task" begin
    @test K.worked(e, "Lay the pipe") == 150 && K.worked(e, "lay the PIPE ") == 150 && K.worked(e, "Dig the trench") == 0
    @test K.page_log(e) === hours && !K.clocked(hours, "Lay the pipe")
  end

  @testset "the button beside a to-do item starts the clock on the item" begin
    at(line_at(line("- [ ] Dig the trench")))
    c = e.nodes[:item_clock]
    @test c.key == "Dig the trench" && rect(c) !== nothing
    click(button())
    @test log() == ["2026-11-19 08:00-10:30 | Lay the pipe", "2026-11-20 09:00- | Dig the trench"]
    @test K.clocked(hours, "Dig the trench")
    # The hours count up while it runs
    clock[] += Minute(20)
    frames()
    @test K.worked(e, "Dig the trench") == 20
    # The button on another item stops this clock and starts that one
    at(line_at(line("- [ ] Lay the pipe")))
    @test e.nodes[:item_clock].key == "Lay the pipe"
    click(button())
    @test log()[2] == "2026-11-20 09:00-09:20 | Dig the trench" && log()[3] == "2026-11-20 09:20- | Lay the pipe"
    @test K.clocked(hours, "Lay the pipe")
    # The same button stops it
    clock[] += Minute(40)
    at(line_at(line("- [ ] Lay the pipe"))); click(button())
    @test log()[3] == "2026-11-20 09:20-10:00 | Lay the pipe" && K.Timelogs.running(hours.data) === nothing
    @test K.worked(e, "Lay the pipe") == 190
  end

  @testset "a tick stops the clock that runs on the item" begin
    at(line_at(line("- [ ] Dig the trench"))); click(button())
    @test K.clocked(hours, "Dig the trench")
    clock[] += Minute(30)
    K.tick!(e, line("- [ ] Dig the trench")); frames()
    @test "- [x] Dig the trench" in e.buf.lines && log()[end] == "2026-11-20 10:00-10:30 | Dig the trench" && K.Timelogs.running(hours.data) === nothing
    # One ⌘Z takes back the tick and the stop
    K.undo!(e.buf); frames()
    @test "- [ ] Dig the trench" in e.buf.lines && log()[end] == "2026-11-20 10:00- | Dig the trench"
    # A tick of another item leaves the clock running
    K.tick!(e, line("- [ ] Lay the pipe")); frames()
    @test K.clocked(hours, "Dig the trench")
    K.tick!(e, line("- [x] Lay the pipe")); frames()
    @test e.buf.lines[end-1] == "The end."
  end

  @testset "a page with a schedule shows the task's days and the clock" begin
    at(line_at(line("- [ ] Dig the trench")))
    d = e.nodes[:task_details]
    @test d.of isa K.ScheduleView && K.task_of(d) !== nothing && rect(e.nodes[:item_clock]) !== nothing
    # With no schedule, the clock shows alone
    s = K.block_lines(e.buf, K.SCHEDULE, 1)
    K.edit!(e.buf, (s[1], 0), K.line_end(e.buf, s[2]), ""); frames()
    at(line_at(line("- [ ] Lay the pipe")) .+ (5, 0))
    @test d.of isa K.TimelogView && K.task_of(d) === nothing && d.key == "Lay the pipe" && rect(e.nodes[:item_clock]) !== nothing
    K.undo!(e.buf); frames()
  end
  close(w)
finally
  K.Timelogs.CLOCK[] = real
end
