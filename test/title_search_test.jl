# Tests for the end of the path in the top bar: the headings over the caret and
# the component that it's on, after the file's name, and the search that the ›
# after the file's name or after a heading opens. See "the path in the top bar"
# and "a search of a page's parts" in main.jl. Run them with
# `julia -O0 --project=. test/title_search_test.jl`. They use folders of their
# own, and they click in a window that isn't on the screen, with the sidebar
# hidden. With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle

const px = K.px
const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")

const jobs = mkpath(joinpath(dir, "Jobs"))
const site = mkpath(joinpath(jobs, "Site"))
made(path, text) = (write(path, text); path)
const plan = made(joinpath(jobs, "plan.md"), """
# Plan

Intro text.

## Costs

```sheet
x = 1
```

After the sheet.
""")
const tasks = made(joinpath(jobs, "tasks.md"), """
# Plumbing

- [ ] Call the plumber
- [x] Buy the pipe
- A plumber's note
""")
const room = made(joinpath(site, "bathroom.md"), """
# Bathroom

```sketch
box 10 10 100 60 "Shower"
```
""")
K.HOME[] = dir   # the path starts with ~ for this folder

const e = K.build_editor(plan)
e.panel = false   # the sidebar is hidden: the top bar is the way round
const w = Window(e, size=(1100px, 760px))
const (; frames, at, typed, key) = drive(w, frames=3, latest=true)
frames()

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "title-search-$name.png"), w)
press() = (w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1); w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2))
click(place) = (at(place); press())
showing(k) = any(p -> p.key == k, popups(w))
trail() = e.nodes[:title_trail]
"Hold the mouse over the file's name until the path shows"
hover!() = (at(middle(e.nodes[:title])); sleep(K.TT_WAIT + 0.05); frames())
"Put the caret on line `i` of the page, as a click there would"
caret!(i) = (b = e.buf; b.reading = false; b.caret = b.anchor = (i, 0); frames())
titles() = [x.title for x in trail().parts]
search() = e.nodes[:title_search]
menu() = only(p.content for p in popups(w) if p.key == K.TS_MENU)
"What each row of the search shows, in the list's order: a heading or a component that's there, or a thing that was found"
found() = [r.kind == :entry ? "part " * "  "^r.depth * r.x.title : r.m.text for r in search().rows]
drop(k) = trail().drops[k]
"Open the search under the › after the file's name (0), or after the path's heading `k`"
open!(k) = (hover!(); click(middle(drop(k))))
clear!() = (f = K.search_field(search()); f.text = ""; f.anchor = f.cursor = 0; frames())

@testset "a search of many kinds at once, in find.jl" begin
  Searches = K.Searches
  lines = String.(split(read(tasks, String), '\n'))
  @test [m.text for (m, _) in Searches.search([:todo], ["plumb"], tasks, lines)] == ["Call the plumber"]
  # Words with no kinds find any line. Each shows as the kind of line that it is.
  @test [(m.text, k) for (m, k) in Searches.search(Symbol[], ["plumb"], tasks, lines)] ==
        [("Plumbing", :heading), ("Call the plumber", :todo), ("A plumber's note", :bullet)]
  # A kind of block with no words lists every block of that kind, by the heading over it
  sk = String.(split(read(room, String), '\n'))
  @test [(m.text, k) for (m, k) in Searches.search([:sketch], String[], room, sk)] == [("Bathroom", :sketch)]
  # With no kinds, a block needs the words in its own lines, not only in its heading
  @test isempty(Searches.search(Symbol[], ["bathroom"], room, sk)[2:end])
  @test [m.text for (m, _) in Searches.search(Symbol[], ["shower"], room, sk)] == ["Bathroom"]
end

@testset "the path ends with the heading over the caret, and a › follows the file's name and the heading" begin
  caret!(3)
  hover!()
  @test showing(:title_trail)
  @test trail().steps[end] == ("plan.md", plan)
  @test titles() == ["Plan"]
  # In order: the file's name, its ›, the heading, the heading's ›
  @test rect(trail().crumbs[plan]).left < rect(drop(0)).left < rect(trail().marks[1]).left < rect(drop(1)).left
  # The file's name is where the bar had it, after the room that the bar keeps empty before it
  t = rect(e.nodes[:title])
  @test abs(K.num(rect(trail().crumbs[plan]).left) + K.num(K.TT_PAD) - K.num(t.left) - K.num(e.nodes[:title_lead])) <= 2
  shot("heading")
end

@testset "on a component, the path has each heading over it and the component, which has no ›" begin
  caret!(8)
  hover!()
  @test titles() == ["Plan", "Costs", "Sheet"]
  @test trail().parts[end].icon == "calculator"
  @test rect(drop(2)).left < rect(trail().marks[3]).left
  r = rect(trail().marks[3])
  @test !haskey(trail().drops, 3) || rect(drop(3)) === nothing || rect(drop(3)).left < r.left
  shot("component")
  # Under the block, the caret is on no component
  caret!(11)
  hover!()
  @test titles() == ["Plan", "Costs"]
end

@testset "a click on a heading of the path puts the caret on it" begin
  caret!(11)
  hover!()
  click(middle(trail().marks[1]))
  @test e.buf.caret[1] == 1
  frames()
  @test titles() == ["Plan"]
end

@testset "a page with no caret has no parts, and a › after the file's name all the same" begin
  e.buf.reading = true
  frames()
  hover!()
  @test isempty(trail().parts)
  @test rect(drop(0)).left > rect(trail().crumbs[plan]).left
  e.buf.reading = false
end

@testset "the bar shows the parts after the file's name all the time, and the name stays where it is" begin
  at((550, 500))   # the mouse is away from the bar
  e.buf.reading = true
  frames()
  bare = rect(e.nodes[:title])
  caret!(8)
  @test !showing(:title_trail)
  r = rect(e.nodes[:title])
  @test abs(K.num(r.width) - K.num(bare.width) - (2K.num(K.parts_wide(K.focus_parts(e))) + 12)) <= 1
  @test abs(K.num(r.left) + K.num(r.width) / 2 - (K.num(bare.left) + K.num(bare.width) / 2)) <= 1
  shot("bar")
end

@testset "the › after the file's name lists its headings and components, under the ›" begin
  caret!(11)
  open!(0)
  @test showing(K.TS_KEY) && showing(:title_trail)   # the path stays
  s = search()
  @test w.focus === K.search_field(s)
  @test s.under == 0
  @test found() == ["part Plan", "part   Costs", "part     Sheet"]
  # It hangs under the ›
  r, ra = rect(s), rect(drop(0))
  @test r.top > ra.top + ra.height && r.left <= ra.left && ra.left + ra.width <= r.left + r.width
  shot("file")
  # A click on one goes to it
  click(middle(s.parts[(:row, 2)]))
  @test !showing(K.TS_KEY)
  @test e.buf.caret[1] == 5 && w.focus === e
end

@testset "the › after a heading lists what's under it, and a second click takes it away" begin
  caret!(11)
  open!(1)   # after Plan
  @test search().under == 1
  @test found() == ["part Costs", "part   Sheet"]
  @test K.search_place(search()) == "Plan"
  click(middle(drop(1)))
  @test !showing(K.TS_KEY)
  open!(2)   # after Costs
  @test found() == ["part Sheet"]
  key(Keys.escape)
  @test !showing(K.TS_KEY) && w.focus === e
end

@testset "words find the lines and blocks that have them, there" begin
  caret!(11)
  open!(0)
  typed("sheet")
  @test found() == ["After the sheet."]
  @test K.search_summary(search()) == "1 thing in plan.md."
  @test search().rows[search().pick].kind == :thing
  shot("words")
  key(Keys.escape)
  open!(1)
  typed("intro")
  @test found() == ["Intro text."]
  @test K.search_summary(search()) == "1 thing under Plan."
  key(Keys.escape)
end

@testset "the Kinds button chooses kinds, and the list stays for more" begin
  caret!(11)
  open!(0)
  click(middle(search().parts[:kinds]))
  @test showing(K.TS_MENU)
  m = menu()
  @test w.focus === m.parts[:field]
  typed("sheet")   # a kind is found by any name that a find block knows it by
  @test m.rows[m.pick].key == :sheet
  key(Keys.enter)
  @test search().wants == [:sheet]
  @test showing(K.TS_MENU)
  f = m.parts[:field]; f.text = ""; f.anchor = f.cursor = 0; frames()
  shot("kinds-list")
  # Esc goes back to the search's field
  key(Keys.escape)
  @test !showing(K.TS_MENU) && showing(K.TS_KEY)
  @test w.focus === K.search_field(search())
  # Kinds with no words list every thing of those kinds, by the heading over a block
  @test found() == ["Costs"]
  @test search().rows[1].as == :sheet
  @test haskey(search().parts, (:chip, :sheet))
  shot("kinds")
end

@testset "a click on a chip, or Backspace in an empty field, takes a kind away" begin
  key(Keys.tab)   # Tab opens the list of kinds
  typed("headings")
  key(Keys.enter)
  key(Keys.escape)
  @test search().wants == [:sheet, :heading]
  @test found() == ["Plan", "Costs", "Costs"]
  click(middle(search().parts[(:chip, :sheet)]))
  @test search().wants == [:heading]
  @test w.focus === K.search_field(search())
  key(Keys.backspace)
  @test isempty(search().wants)
  @test found() == ["part Plan", "part   Costs", "part     Sheet"]   # nothing asked again
end

@testset "Return shows the thing that's picked in the page, and the search goes" begin
  # The › says where to look, so the search has no button that chooses a place
  @test collect(keys(filter(p -> p[2] isa K.SearchButton, search().parts))) == [:kinds]
  typed("intro")
  @test found() == ["Intro text."]
  key(Keys.enter)
  @test !showing(K.TS_KEY)
  @test e.buf.path == plan
  @test e.buf.caret[1] == 3
  @test w.focus === e
end

@testset "a click outside closes the search" begin
  K.open!(e, plan); frames()
  caret!(11)
  open!(0)
  @test showing(K.TS_KEY)
  click((550, 500))
  @test !showing(K.TS_KEY) && w.focus === e
end

@testset "⌘F shows the path, with the search of the whole file under the › after its name" begin
  # The mouse is away from the file's name, so only ⌘F shows the path
  caret!(11)
  @test !showing(:title_trail)
  key(Keys.f, Keys.cmd)
  @test showing(:title_trail) && showing(K.TS_KEY)
  s = search()
  @test s.arrow === drop(0) && s.under == 0
  @test w.focus === K.search_field(s) && K.search_field(s).text == ""
  @test found() == ["part Plan", "part   Costs", "part     Sheet"]
  shot("cmd-f")
  # ⌘F again selects the words in the field, and the search stays
  typed("sheet")
  key(Keys.f, Keys.cmd)
  f = K.search_field(search())
  @test search() === s && showing(K.TS_KEY) && w.focus === f && (f.anchor, f.cursor) == (0, 5)
  key(Keys.escape)
  @test !showing(K.TS_KEY) && !showing(:title_trail) && w.focus === e
  # The words that are selected on one line go into the field
  b = e.buf
  b.anchor, b.caret = (11, 10), (11, 15)
  frames()
  key(Keys.f, Keys.cmd)
  @test K.search_field(search()).text == "sheet" && found() == ["After the sheet."]
  key(Keys.escape)
  # A file of code has no search in its path, so ⌘F opens the bar that finds text in it
  code = made(joinpath(dir, "sum.jl"), "x = 1\ny = x + 1\n")
  K.open!(e, code); frames()
  key(Keys.f, Keys.cmd)
  @test K.finding(e) && !showing(K.TS_KEY)
  key(Keys.escape)
  @test !K.finding(e)
  K.open!(e, plan); frames()
end

@testset "in inline code, a link or bold words, the path ends with that run, by its kind" begin
  runs = made(joinpath(dir, "runs.md"), """
  # Runs

  Use `sheet` blocks, **bold** words and a [link](https://example.com).
  """)
  K.open!(e, runs); frames()
  text = e.buf.lines[3]
  col(s) = findfirst(s, text)[1] - 1   # the column of the first letter of `s`, as the caret counts them
  on!(c) = (b = e.buf; b.reading = false; b.caret = b.anchor = (3, c); frames())
  last_part() = (p = K.focus_parts(e); isempty(p) ? nothing : (p[end].title, p[end].icon, p[end].level))
  on!(col("sheet") + 2)
  @test last_part() == ("Code", "code", 8)
  # From just before its first letter to just after its last
  on!(col("sheet")); @test last_part()[1] == "Code"
  on!(col("sheet") + 5); @test last_part()[1] == "Code"
  # Past the markup round it, the caret is on plain words, and the path ends with the heading
  on!(col("sheet") - 1); @test last_part()[1] == "Runs"
  on!(col("sheet") + 6); @test last_part()[1] == "Runs"
  on!(col("bold") + 1); @test last_part()[1:2] == ("Bold", "type-bold")
  on!(col("link") + 1); @test last_part()[1:2] == ("Link", "link-45deg")
  on!(1); @test last_part()[1] == "Runs"
  # The path over the bar shows it too, after the heading, as the last part: no click, and no › after it
  on!(col("sheet") + 2)
  hover!()
  @test titles() == ["Runs", "Code"]
  @test rect(drop(1)).left < rect(trail().marks[2]).left
  # Nothing follows it: it ends the path, inside the path's own room at its end
  r, v = rect(trail().marks[2]), rect(trail())
  @test 0 <= K.num(v.left + v.width) - K.num(r.left + r.width) <= K.num(K.TT_EDGE) + 2
  shot("run")
  # On the heading's line, the caret is on no run
  b = e.buf; b.caret = b.anchor = (1, 3); frames()
  @test [x.title for x in K.focus_parts(e)] == ["Runs"]
end

@testset "while a picture or a block fills the window, a click on the path's heading goes back to it in the page" begin
  figs = made(joinpath(jobs, "figures.md"), """
  # Figures

  Words.

  ## Flow

  ```mermaid
  graph TD
  A --> B
  ```

  After the diagram.
  """)
  K.open!(e, figs); frames()
  caret!(1)
  code = join(e.buf.lines[8:9], "\n")
  K.zoom_in!(e, (:diagram, code)); frames()
  @test K.zooming(e) !== nothing
  hover!()
  @test titles() == ["Figures"]
  # The heading is the last part, where the caret is. While the diagram fills the window, a click on it goes there all the same.
  @test K.cursor(trail().marks[1]) == :hand
  click(middle(trail().marks[1]))
  @test K.zooming(e) === nothing && e.buf.path == figs && e.buf.caret[1] == 1 && w.focus === e
  frames()
  hover!()
  @test K.cursor(trail().marks[1]) == :arrow   # in the page, the last part is where the caret is
  shot("unzoomed")
  # A heading chosen in the search under the › after the file's name goes back to the page too
  K.zoom_in!(e, (:diagram, code)); frames()
  open!(0)
  k = findfirst(r -> r.kind == :entry && r.x.title == "Flow", search().rows)
  @test k !== nothing
  K.search_go!(search(), w, k); frames()
  @test K.zooming(e) === nothing && e.buf.caret[1] == 5
  # A sketch that fills the window goes back in the page when the path's heading is clicked
  K.open!(e, room); frames()
  caret!(4)
  s = only(v for v in values(e.nodes) if v isa K.SketchView)
  K.full!(s, true); frames()
  @test K.full_block(e) === s
  hover!()
  @test titles()[1] == "Bathroom"
  click(middle(trail().marks[1]))
  @test K.full_block(e) === nothing && !s.full && e.buf.caret[1] == 1
end
