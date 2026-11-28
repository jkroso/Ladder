# Tests for the `calendar` block of main.jl: a month with the page's tasks,
# its to-do items that have a day, and the calendar's own events. Run them with
# `julia -O0 --project=. test/calendar_view_test.jl`. They click, drag and type
# in a window that isn't on the screen. Set `LADDER_SHOTS` to a folder, and
# they save pictures of the page there.

@use Test: @test, @testset
@use Dates: Dates, Date, Day
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

# Wednesday 18 November 2026 counts as today
K.calendar_day[] = Date(2026, 11, 18)
nov(d) = Date(2026, 11, d)

const RING = "Ring the council about the inspection of the drains and of the new pipe"
const dir = mktempdir()
const page = joinpath(dir, "job.md")
write(page, """
# A job

- [x] Dig the trench
- [ ] Lay the pipe
- [ ] Order the tiles 2026-11-25
- [x] Book the digger (2026-11-20)
- [ ] $RING 2026-11-25

```schedule
start: 2026-11-19

Dig the trench | 3 days
Lay the pipe | 2 days | after Dig the trench
```

```calendar
month: 2026-11

2026-11-25 | Concrete pour
2026-11-25 | Skip arrives
2026-11-27 | Council inspection
```

The end.
""")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 1400px))
const (; frames, at, press, release, click, typed, key, shot) = drive(w)
frames()
const v = e.nodes[(:block, K.CALENDAR, page, 1)]

"Press the mouse at one place, move it to another by way of the place between, and let go"
drag(from, to) = (press(from); at(((from[1] + to[1]) / 2, (from[2] + to[2]) / 2)); at(to); release())
button(name) = click(middle(rect(v.parts[(:button, name)])))
"""
Two clicks at one place. The calendar takes them as two clicks in one place when the second comes within 0.35
seconds of the first, and on a busy Mac the frames between them take longer. So the first click's time is now
when the second comes.
"""
twice(place) = (click(place); v.clicked = (time(), v.clicked[2], v.clicked[3]); click(place))
block() = (s = K.block_lines(e.buf, K.CALENDAR, 1); e.buf.lines[s[1]+1:s[2]-1])
line(words) = e.buf.lines[findfirst(l -> occursin(words, l), e.buf.lines)]
"The days that show, and the things that show on each, as the last frame drew them"
cells() = [v.parts[(:day, i)] for i in 1:7v.weeks]
cell(d) = only(c for c in cells() if c.day == d)
chips(d) = (c = cell(d); [v.parts[(:thing, c.i, k)] for k in 1:length(K.Calendars.fit(K.day_things(v, d), K.Calendars.monday(d) in v.open ? 99 : K.DAY_ROWS)[1])])
chip(d, words) = only(c for c in chips(d) if c.thing.words == words)
words(d) = [c.thing.words for c in chips(d)]
"The empty part at the bottom of a day"
empty(d) = (r = rect(cell(d)); (K.num(r.left + r.width / 2), K.num(r.top + r.height - 6)))
more(d) = v.parts[(:more, cell(d).i)]
title() = K.Calendars.title(K.month_shown(v))

@testset "the month shows the page's things on their days" begin
  @test title() == "November 2026" && v.weeks == 6 && cells()[1].day == Date(2026, 10, 26) && cells()[end].day == Date(2026, 12, 6)
  # The days are side by side, each as wide as the next, and a week is under the week before
  rs = [rect(c) for c in cells()]
  @test rs[1].left < rs[2].left < rs[7].left && rs[1].width ≈ rs[4].width ≈ rs[7].width && rs[8].top ≈ rs[1].top + rs[1].height && rs[8].left ≈ rs[1].left
  # A task is on each working day that it runs, and not at the weekend
  @test words(nov(19)) == ["Dig the trench"] && words(nov(23)) == ["Dig the trench"] && isempty(words(nov(21))) && words(nov(24)) == ["Lay the pipe"]
  # A to-do item is on the day in its text, without that day, and an event is on its own
  @test [(c.thing.kind, c.thing.words, c.thing.done) for c in chips(nov(20))] == [(:task, "Dig the trench", true), (:todo, "Book the digger", true)]
  @test words(nov(27)) == ["Council inspection"]
  # A day with more things than it has room for shows the first of them, and how many more there are
  @test words(nov(25)) == ["Lay the pipe", "Order the tiles"] && more(nov(25)).more == 3
  @test any(en -> en.title == "Calendar", K.outline(e.buf))
  @test !K.dirty(e.buf)
  shot("calendar.png")
end

@testset "the arrows and Today change the month" begin
  button(:after)
  @test block()[1] == "month: 2026-12" && title() == "December 2026" && v.weeks == 5 && words(Date(2026, 11, 30)) == String[]
  button(:after); button(:after)
  @test block()[1] == "month: 2027-02" && v.weeks == 4
  # ⌘Z takes each change back
  K.undo!(e.buf); frames()
  @test block()[1] == "month: 2027-01"
  button(:before); button(:before); button(:before)
  @test block()[1] == "month: 2026-10" && length(block()) == 5
  # Today takes the month's line away, and the block shows the month of today
  button(:today)
  @test block() == ["2026-11-25 | Concrete pour", "2026-11-25 | Skip arrives", "2026-11-27 | Council inspection"] && title() == "November 2026"
  @test v.parts[(:button, :today)].off
  # The month before has the last days of this one's first week
  button(:before)
  @test block()[1:2] == ["month: 2026-10", ""] && title() == "October 2026" && cells()[end].day == nov(1)
  button(:today)
  @test title() == "November 2026" && length(block()) == 3
end

@testset "a click selects a thing, and two clicks go to its line" begin
  click(middle(rect(chip(nov(27), "Council inspection"))))
  @test v.picked == (:event, "3")
  click(empty(nov(10)))
  @test v.picked === nothing
  place = middle(rect(chip(nov(19), "Dig the trench")))
  twice(place)
  @test e.buf.caret[1] == findfirst(==("- [x] Dig the trench"), e.buf.lines) && w.focus === e
  place = middle(rect(chip(nov(20), "Book the digger")))
  twice(place)
  @test e.buf.lines[e.buf.caret[1]] == "- [x] Book the digger (2026-11-20)"
  # An event's line is in the block, so the block shows its lines
  place = middle(rect(chip(nov(27), "Council inspection")))
  twice(place)
  @test e.buf.lines[e.buf.caret[1]] == "2026-11-27 | Council inspection"
  e.buf.caret = e.buf.anchor = (1, 0); frames()
end

@testset "a click on a box ticks the item in the page" begin
  click(middle(rect(chip(nov(25), "Order the tiles").box)))
  @test line("Order the tiles") == "- [x] Order the tiles 2026-11-25" && chip(nov(25), "Order the tiles").thing.done && v.grab === nothing
  click(middle(rect(chip(nov(20), "Book the digger").box)))
  @test line("Book the digger") == "- [ ] Book the digger (2026-11-20)"
  K.undo!(e.buf); K.undo!(e.buf); frames()
  @test line("Order the tiles") == "- [ ] Order the tiles 2026-11-25" && line("Book the digger") == "- [x] Book the digger (2026-11-20)"
end

@testset "a week grows to show every thing of its days" begin
  tall = rect(cell(nov(25))).height
  @test rect(cell(nov(18))).height ≈ tall
  click(middle(rect(more(nov(25)))))
  @test words(nov(25)) == ["Lay the pipe", "Order the tiles", RING, "Concrete pour", "Skip arrives"] && more(nov(25)).more == 0
  # Each day of the week is as tall as the day with the most, and the weeks under it move down
  @test rect(cell(nov(25))).height > tall && rect(cell(nov(23))).height ≈ rect(cell(nov(25))).height && rect(cell(nov(18))).height ≈ tall
  @test rect(chip(nov(25), "Skip arrives")).top + rect(chip(nov(25), "Skip arrives")).height < rect(more(nov(25))).top + 1px
  @test rect(cell(nov(30))).top ≈ rect(cell(nov(25))).top + rect(cell(nov(25))).height
  # The words of a thing stop at the edge of its day
  long, day = rect(chip(nov(25), RING)), rect(cell(nov(25)))
  @test chip(nov(25), RING).cut && long.left >= day.left && long.left + long.width <= day.left + day.width
  # The mouse over a thing whose words are cut shows all of them
  at(middle(long))
  @test any(p -> p.key == :tooltip, popups(w))
  at(middle(rect(chip(nov(25), "Skip arrives"))))
  @test !any(p -> p.key == :tooltip, popups(w))
  shot("calendar-week.png")
  click(middle(rect(more(nov(25)))))
  @test length(words(nov(25))) == 2 && rect(cell(nov(25))).height ≈ tall
end

@testset "a drag moves a to-do item and an event to another day" begin
  press(middle(rect(chip(nov(25), "Order the tiles")))); at(empty(nov(26)) .- (20, 0)); at(empty(nov(26)))
  @test K.dragging(v) && K.drop_day(v) == nov(26)
  shot("calendar-drag.png")
  release()
  @test line("Order the tiles") == "- [ ] Order the tiles 2026-11-26" && words(nov(26)) == ["Order the tiles"] && v.grab === nothing
  @test v.picked == (:todo, "Order the tiles 2026-11-26")
  K.undo!(e.buf); frames()
  @test line("Order the tiles") == "- [ ] Order the tiles 2026-11-25" && isempty(words(nov(26)))
  # The day keeps the brackets that were round it, and a day of the month after can take the item
  drag(middle(rect(chip(nov(20), "Book the digger"))), empty(Date(2026, 12, 2)))
  @test line("Book the digger") == "- [x] Book the digger (2026-12-02)" && words(Date(2026, 12, 2)) == ["Book the digger"]
  # An event's line of the block gets the new day
  drag(middle(rect(chip(nov(27), "Council inspection"))), empty(nov(30)))
  @test block()[end] == "2026-11-30 | Council inspection" && words(nov(30)) == ["Council inspection"] && isempty(words(nov(27)))
  K.undo!(e.buf); frames()
  @test block()[end] == "2026-11-27 | Council inspection"
  # A task stays where it is, and so does a thing that's dropped on its own day or away from the days
  before, caret = copy(e.buf.lines), e.buf.caret
  e.clicked = (time(), caret, 1)   # as it is after a click on the page's text
  drag(middle(rect(chip(nov(19), "Dig the trench"))), empty(nov(12)))
  drag(middle(rect(chip(nov(27), "Council inspection"))), empty(nov(27)))
  drag(middle(rect(chip(nov(27), "Council inspection"))), (700, 110))
  @test e.buf.lines == before && v.grab === nothing
  # The page's text doesn't select while the mouse is held on the calendar, or leaves it with a thing
  @test e.buf.caret == caret && e.buf.anchor == caret && rect(cell(nov(27))) !== nothing
  @test e.buf.lines[end-1] == "The end."
end

@testset "two clicks on a day add an event" begin
  twice(empty(nov(10)))
  @test v.adding == nov(10) && w.focus === K.calendar_input(v)
  typed("Scaffold up")
  shot("calendar-typing.png")
  key(Keys.enter)
  @test v.adding === nothing && block()[end] == "2026-11-10 | Scaffold up" && words(nov(10)) == ["Scaffold up"] && w.focus === e
  K.undo!(e.buf); frames()
  @test block()[end] == "2026-11-27 | Council inspection" && isempty(words(nov(10)))
  # Esc leaves the words out, and so does Return with no words
  before = block()
  twice(empty(nov(11))); typed("Not this"); key(Keys.escape)
  @test v.adding === nothing && block() == before
  twice(empty(nov(11))); key(Keys.enter)
  @test v.adding === nothing && block() == before
  # A click somewhere else keeps the words that were typed
  twice(empty(nov(12))); typed("Plumber"); click(empty(nov(3)))
  @test v.adding === nothing && block()[end] == "2026-11-12 | Plumber"
  K.undo!(e.buf); frames()
end

@testset "the page changes, and the calendar with it" begin
  i = findfirst(==("- [ ] Lay the pipe"), e.buf.lines)
  K.tick!(e, i); frames()
  @test chip(nov(24), "Lay the pipe").thing.done
  K.tick!(e, i); frames()
  # An item that gets a day in its text shows on that day, and no more on the days that the schedule gives it
  K.edit!(e.buf, (i, length(e.buf.lines[i])), (i, length(e.buf.lines[i])), " 2026-11-13")
  e.buf.caret = e.buf.anchor = (1, 0); frames()
  @test [(c.thing.kind, c.thing.words) for c in chips(nov(13))] == [(:todo, "Lay the pipe")] && isempty(words(nov(24)))
  K.undo!(e.buf); frames()
  @test words(nov(24)) == ["Lay the pipe"]
end

@testset "the month as HTML" begin
  html = K.page_html(e)
  @test occursin("<caption>November 2026</caption>", html) && occursin("<tr><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th><th>Sun</th></tr>", html)
  @test occursin("<b>27</b><br>Council inspection</td>", html) && occursin("<b>19</b><br><span style=\"color: #8a8176\">✓ Dig the trench</span></td>", html)
  @test occursin("<b>25</b><br>Lay the pipe<br>Order the tiles<br>$RING<br>Concrete pour<br>Skip arrives</td>", html)
  @test count("<td style=\"vertical-align: top\">", html) == 42 && occursin("<span style=\"color: #a89f91\">26</span>", html)
end

@testset "the dark page" begin
  was = e.theme
  e.theme = :night; K.restyle!(e); frames()
  @test K.dark_page() && rect(cell(nov(18))) !== nothing
  shot("calendar-dark.png")
  e.theme = was; K.restyle!(e); frames()
end
close(w)

@testset "the welcome page's calendar shows its events" begin
  welcome = joinpath(K.pages_dir[], "welcome.md")
  e3 = K.build_editor(welcome)
  w3 = Window(e3, size=(1000px, 900px))
  foreach(_ -> frame(w3), 1:2)
  c = e3.nodes[(:block, K.CALENDAR, welcome, 1)]
  @test K.month_shown(c) == nov(1) && [t.words for t in K.day_things(c, nov(25))] == ["Concrete pour"] && length(c.data.events) == 3
  @test !K.dirty(e3.buf)
  close(w3)
end

@testset "a block that's empty or wrong still shows a month" begin
  other = joinpath(dir, "other.md")
  write(other, """
  # Notes

  - [ ] Call the plumber 2026-11-18

  ```calendar
  ```

  ```calendar
  month: never
  2026-99-99 | No such day
  | | |
  2026-11-18 | Today's event that has a lot of words in it, more than a day has room for
  ```
  """)
  e2 = K.build_editor(other)
  # A narrow window
  w2 = Window(e2, size=(430px, 1700px))
  foreach(_ -> frame(w2), 1:3)
  a, b = e2.nodes[(:block, K.CALENDAR, other, 1)], e2.nodes[(:block, K.CALENDAR, other, 2)]
  @test K.Calendars.title(K.month_shown(a)) == "November 2026" && K.Calendars.title(K.month_shown(b)) == "November 2026"
  @test [t.words for t in K.day_things(a, nov(18))] == ["Call the plumber"] && length(K.day_things(b, nov(18))) == 2
  # The words of a thing are cut, and stay in their day. A narrow day gives the room of the item's box to its words.
  things = [p for p in values(b.parts) if p isa K.CalendarThing && p.thing !== nothing && rect(p) !== nothing]
  day = rect(only(c for c in values(b.parts) if c isa K.CalendarDay && c.day == nov(18)))
  @test length(things) == 2 && all(t -> t.cut && rect(t).left >= day.left && rect(t).left + rect(t).width <= day.left + day.width, things)
  @test K.tight(b) && rect(things[1].box) === nothing
  @test occursin("<caption>November 2026</caption>", K.page_html(e2))
  drive(w2).shot("calendar-narrow.png")
  e2.theme = :night; K.restyle!(e2); foreach(_ -> frame(w2), 1:2)
  drive(w2).shot("calendar-narrow-dark.png")
  # The Insert menu adds an empty calendar
  insert = only(x for x in K.INSERTS if x isa Tuple && x[1] == "Calendar")
  e2.buf.caret = e2.buf.anchor = K.line_end(e2.buf, length(e2.buf.lines))
  K.add_block!(e2, insert[2], insert[3]); foreach(_ -> frame(w2), 1:2)
  @test K.block_lines(e2.buf, K.CALENDAR, 3) !== nothing && K.month_shown(e2.nodes[(:block, K.CALENDAR, other, 3)]) == nov(1)
  close(w2)
end
