# Tests for where a name is defined, in main.jl: in Julia code, a click on a
# name with ⌘ held goes to where the name is defined, and so does the command
# Go To Definition. The command Go To lists the functions and the sections of
# a file of code, and Find Uses lists the places that use a name. Run them with `julia -O0 --project=. test/definition_test.jl`.
# They click in a window that isn't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame cursor popups
"The words of each Text in the layout `x`, from the top"
texts(x) = begin
  hasfield(typeof(x), :content) && getfield(x, :content) isa AbstractString && return Any[x]
  out, c = Any[], hasfield(typeof(x), :firstchild) ? x.firstchild : nothing
  while c !== nothing
    append!(out, texts(c))
    c = c.nextsibling
  end
  out
end
@use GeometryBasics: Vec2
const px = K.px

# The folder is the test's own each time, so that two test processes that run at once don't write the same files
const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")

# A file that another file loads
const walls = joinpath(dir, "walls.jl")
write(walls, """
"A wall, by its length"
struct Wall
  long::Float64
end

"How much paint a wall takes"
paint(w::Wall) = w.long * 2.4 / 10
""")

const rooms = joinpath(dir, "rooms.jl")
write(rooms, """
@use "./walls" => Walls Wall

# --- the rooms -------------------------------------------------------------

const HEIGHT = 2.4

struct Room
  walls::Vector{Wall}
end

area(r::Room) = sum(w -> w.long, r.walls) * HEIGHT
area(w::Wall) = w.long * HEIGHT

# --- the paint ---------------------------------------------------------------

function litres(r::Room, coats=2)
  total = 0.0
  for wall in r.walls
    total += Walls.paint(wall) * coats
  end
  total = round(total, digits=1)   # a string with area( in it: "area(r)"
  total + area(r)
end
""")
# Ladder loaded the file, as it loads the file of a kind of block
Base.invokelatest(K.Kip.require, rooms, dir)

const e = K.build_editor(rooms)
const w = Window(e, size=(1000px, 700px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()
const b = e.buf
line(words) = findfirst(l -> occursin(words, l), b.lines)
"The place of the first `name` on the line that has `words`, a few characters into the name"
at(words, name; into=1) = (i = line(words); (i, length(b.lines[i], 1, first(findfirst(name, b.lines[i])) - 1) + into))
"Where a click on that place goes"
goes(words, name; into=1) = K.definition(e, at(words, name; into))

@testset "the name at a place" begin
  @test K.name_at(b, at("total + area(r)", "area")).name == "area"
  @test K.name_at(b, at("total + area(r)", "area", into=0)).name == "area" && K.name_at(b, at("total + area(r)", "area", into=4)).name == "area"
  found = K.name_at(b, at("Walls.paint(wall)", "paint"))
  @test found.name == "paint" && found.owners == ["Walls"]
  # A word of the language, a number, a string and a comment have no name
  @test K.name_at(b, at("function litres", "function")) === nothing && K.name_at(b, at("total = 0.0", "0.0")) === nothing
  @test K.name_at(b, at("a string with", "string")) === nothing && K.name_at(b, at("\"area(r)\"", "area(r)\"")) === nothing
  @test K.name_at(b, at("the rooms", "rooms")) === nothing
end

@testset "a name that the file makes" begin
  # A name of the function that the click is in, where it was last made before the click
  @test goes("total + area(r)", "total") == (line("total = round"), 2)
  @test goes("total += Walls", "total") == (line("total = 0.0"), 2)
  @test goes("Walls.paint(wall)", "wall)") == (line("for wall in"), 6)
  @test goes("for wall in r.walls", "r.walls") == (line("function litres"), 16)
  # A name of the whole file
  @test goes("* HEIGHT", "HEIGHT") == (line("const HEIGHT"), 6)
  @test goes("function litres(r::Room", "Room") == (line("struct Room"), 7)
  # A function with two methods: the first, and from the first the second, and from the second the first again
  first_one, second = (line("area(r::Room)"), 0), (line("area(w::Wall)"), 0)
  @test goes("total + area(r)", "area") == first_one
  @test K.definition(e, first_one) == second && K.definition(e, second) == first_one
end

@testset "a name that another file makes" begin
  m = goes("Walls.paint(wall)", "paint")
  @test m isa Method && K.code_place(m) == (realpath(walls), 7)
  m = goes("walls::Vector{Wall}", "Wall")
  @test m isa Method && K.code_place(m)[1] == realpath(walls)
  # A function of Julia's own is in Julia's folder of code, at a method of the module that made it, not at a package's
  m = goes("sum(w -> w.long", "sum")
  @test m isa Method && m.module === Base && dirname(K.code_place(m)[1]) == realpath(dirname(Base.find_source_file("essentials.jl")))
  # A part of a value, after a dot, has no place, and nor has a name that nothing made
  @test goes("sum(w -> w.long", "long") === nothing
  K.edit!(b, (length(b.lines), 0), (length(b.lines), 0), "nowhere_at_all(1)")
  @test K.definition(e, (length(b.lines), 3)) === nothing
  K.undo!(b)
end

"Hold ⌘, and the keys `others`, and click the place `p` of the page. It's true when the mouse was a hand there."
click(p, others...) = begin
  it = K.item(e, p[1])
  _, x = K.spot(it.content, p[2])
  pos = Vec2{px}(e.origin[1] + x + 1px, e.origin[2] + it.top + it.tall / 2)
  w.mouse = typeof(w.mouse)(pos...)
  onmouse(w, MouseMove(pos, w))
  foreach(k -> w.keys |= k, (Keys.cmd, others...))
  frames(1)
  hand = cursor(e.nodes[:document]) == :hand
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  foreach(k -> w.keys ⊻= k, (Keys.cmd, others...))
  frames()
  hand
end

@testset "a click with ⌘ held goes there" begin
  # The mouse is a hand over a name that has a place to go to
  @test click(at("total + area(r)", "area"))
  @test b.caret == (line("area(r::Room)"), 0)
  # On the name where the file makes it, the click lists the places that use it
  @test click(b.caret) && e.popup == :commands && K.palette(e).command.name == :find_uses
  foreach(_ -> (onkey(w, KeyPress{Keys.escape}(0, w)); frames()), 1:2)
  @test e.popup == :none
  K.palette(e).moved = 0.0   # the palette has slid away, so that a click doesn't land on it
  frames()
  # A name with no place leaves the caret where the click put it, and the mouse isn't a hand
  p = at("sum(w -> w.long", "long")
  @test !click(p) && b.caret[1] == p[1]
  # With ⇧ or ⌃ held as well as ⌘, or a key that holds all four, the click goes nowhere and the mouse isn't a hand
  p = at("total + area(r)", "area")
  for others in ((Keys.shft,), (Keys.ctrl,), (Keys.shft, Keys.ctrl, Keys.opt))
    b.caret = b.anchor = (1, 0)
    @test !click(p, others...) && b.caret[1] == p[1]
  end
  # A name of another file shows in a window beside this one, at its line
  @test click(at("Walls.paint(wall)", "paint"))
  shown = only(filter(o -> o.buf.path == realpath(walls), K.editors))
  @test shown.buf.caret[1] == 7 && shown.buf.view == :code
end

"The point of the window over the place `p` of the page"
point(p) = (it = K.item(e, p[1]); (e.origin[1] + K.spot(it.content, p[2])[2] + 1px, e.origin[2] + it.top + it.tall / 2))

@testset "with ⌘ held, the words that a click would act on are marked" begin
  # A name that has a place to go to: its first column and the column after its last
  p = at("total + area(r)", "area", into=2)
  @test K.cmd_words(e, point(p)) == (p[1], p[2] - 2, p[2] + 2)
  q = at("Walls.paint(wall)", "paint")
  @test K.cmd_words(e, point(q)) == (q[1], q[2] - 1, q[2] + 4)
  # A name with no place, a word of the language and a comment have no mark
  @test K.cmd_words(e, point(at("sum(w -> w.long", "long"))) === nothing
  @test K.cmd_words(e, point(at("function litres", "function"))) === nothing
  # It's drawn only while ⌘ is held by itself, and the window draws again soon, so the mark follows the mouse
  w.mouse = typeof(w.mouse)(point(p)...)
  frames(1)
  w.keys |= Keys.cmd
  frames(1)
  w.keys ⊻= Keys.cmd
  frames(1)
end

@testset "with ⌘ held, a name that the mouse rests on shows a card of what it is" begin
  # Its documentation, one line or several, and its code up to the end of its block
  lines = ["x = 1", "\"How much paint\"", "paint(w) = w * 2", "\"\"\"", "Two lines", "of words", "\"\"\"", "f(x) = begin", "  x", "end"]
  @test K.peek_lines(lines, 3, 3) == lines[2:3] && K.peek_lines(lines, 8, 10) == lines[4:10] && K.peek_lines(lines, 1, 1) == ["x = 1"]
  @test K.peek_lines(["\"\"\"Short\"\"\"", "g() = 2"], 2, 2) == ["\"\"\"Short\"\"\"", "g() = 2"]
  # A name of another file: where it is, and its documentation and code. Each row is a line, in one or more parts.
  rows(c) = (out = Any[]; r = c.firstchild.firstchild; while r !== nothing; push!(out, texts(r)); r = r.nextsibling end; out)
  card(p) = (c = K.peek_card(e, K.cmd_words(e, point(p))); c === nothing ? nothing : [join(x.content for x in r) for r in rows(c)])
  @test card(at("Walls.paint(wall)", "paint")) == ["walls.jl:7", "\"How much paint a wall takes\"", "paint(w::Wall) = w.long * 2.4 / 10"]
  # The code has the colours that it has in the page, made for the dark grey of a tooltip
  colour(c, words) = only(x.color for r in rows(c) for x in r if x.content == words)
  c = K.peek_card(e, K.cmd_words(e, point(at("Walls.paint(wall)", "paint"))))
  @test colour(c, "\"How much paint a wall takes\"") == K.TIP_CODE.string && colour(c, "Wall") == K.TIP_CODE.type
  @test colour(c, "2.4") == K.TIP_CODE.number && colour(c, "walls.jl:7") != K.TIP_CODE.string
  # The lines inside three quotes are all the colour of a string, though they have words like for and end
  tip = K.tip_code(["\"\"\"", "Shows it for a time, to the end", "\"\"\"", "f(x) = begin"])
  @test [[x.color for x in texts(r)] for r in tip[2:3]] == [[K.TIP_CODE.string], [K.TIP_CODE.string]]
  @test K.TIP_CODE.keyword in [x.color for x in texts(tip[4])]
  # The tooltip of a check's dot has its code in colour too
  @test K.TIP_CODE.number in [x.color for x in texts(K.check_tip(K.Checked("total == 12", :pass, "")))]
  # A name of a function of this file: its lines. A name made in a function: the one line.
  @test card(at("total + area(r)", "area"))[1:2] == ["line 11", "area(r::Room) = sum(w -> w.long, r.walls) * HEIGHT"]
  @test card(at("total + area(r)", "total")) == ["line $(line("total = round"))", "  total = round(total, digits=1)   # a string with area( in it: \"area(r)\""]
  # The card shows when the mouse has rested on the name for a moment with ⌘ held, and goes when ⌘ comes up
  p = at("Walls.paint(wall)", "paint")
  w.mouse = typeof(w.mouse)(point(p)...)
  w.keys |= Keys.cmd
  frames(1)
  @test !e.nodes[:peek].shown && !any(x -> x.key == :tooltip, popups(w))
  # A mouse that hasn't moved since ⌘ went down shows no card, however long it rests: the ⌘ was likely for a key like ⌘S
  rested() = (e.nodes[:peek] = (words=e.nodes[:peek].words, since=time() - 1, shown=false))
  rested()
  frames(1)
  @test !e.nodes[:peek].shown && !any(x -> x.key == :tooltip, popups(w))
  # A move along the name starts the rest, and the card shows after it
  w.mouse = typeof(w.mouse)(point(p)[1] + 1px, point(p)[2])
  frames(1)
  @test !e.nodes[:peek].shown && time() - e.nodes[:peek].since < K.PEEK_WAIT
  rested()
  frames(1)
  @test e.nodes[:peek].shown && any(x -> x.key == :tooltip, popups(w))
  w.keys ⊻= Keys.cmd
  frames(1)
  @test !haskey(e.nodes, :peek) && !haskey(e.nodes, :cmd_mouse) && !any(x -> x.key == :tooltip, popups(w))
  # The next time ⌘ goes down, the mouse must move again
  w.keys |= Keys.cmd
  frames(1)
  rested()
  frames(1)
  @test !e.nodes[:peek].shown && !any(x -> x.key == :tooltip, popups(w))
  w.keys ⊻= Keys.cmd
  frames(1)
end

@testset "Rename In Code gives a name another name, wherever it means the same thing" begin
  name(words, n) = K.own_name(e, at(words, n))
  # A name of another file, and a word of the language, aren't the page's own names
  @test name("Walls.paint(wall)", "paint") === nothing && name("function litres", "function") === nothing
  # A name made in a function is changed in that function, and not in the comment or the string
  total = name("total + area(r)", "total")
  @test total.name == "total" && K.name_uses(e, total) == [(17, 2), (19, 4), (21, 2), (21, 16), (22, 2)]
  # A name of the whole file is changed in all of its code
  area = name("total + area(r)", "area")
  @test [u[1] for u in K.name_uses(e, area)] == [11, 12, 22]
  before = copy(b.lines)
  K.rename_in_code!(e, area, "surface")
  @test b.lines[11] == "surface(r::Room) = sum(w -> w.long, r.walls) * HEIGHT" && b.lines[22] == "  total + surface(r)"
  @test occursin("area(", b.lines[21])   # the comment and the string say area still
  # It's one change, which ⌘Z takes back
  K.undo!(b)
  @test b.lines == before
  @test_throws ErrorException K.rename_in_code!(e, area, "not a name")
  # In the palette, the name is the one at the caret, as a letter, and Return after the new name runs it
  b.caret = b.anchor = at("* HEIGHT", "HEIGHT")
  K.focus(e)
  frames()
  w.keys |= Keys.cmd | Keys.shft; onkey(w, KeyPress{Keys.p}(0, w)); w.keys ⊻= Keys.cmd | Keys.shft
  frames()
  foreach(c -> ontype(w, Typed(c, w)), "rename in code"); frames()
  onkey(w, KeyPress{Keys.enter}(0, w)); frames()
  p = K.palette(e)
  @test p.command.name == :rename_in_code && K.chip_value(p, K.palette_chips(p), 1).name == "HEIGHT" && p.at == 2
  @test [(l.letter) for l in K.chip_letters(p, K.palette_chips(p))] == ["A"] && K.shown_at(e, K.chip_value(p, K.palette_chips(p), 1)) !== nothing
  foreach(c -> ontype(w, Typed(c, w)), "WALL_HEIGHT"); frames()
  onkey(w, KeyPress{Keys.enter}(0, w)); frames()
  @test e.popup == :none && b.lines[5] == "const WALL_HEIGHT = 2.4" && count(l -> occursin("WALL_HEIGHT", l), b.lines) == 3
  K.undo!(b)
  @test b.lines == before
end

@testset "Find Uses lists each place that uses a name, and goes to the one that's chosen" begin
  # A name made in a function: its places in that function, each with its line's words
  b.caret = b.anchor = at("total + area(r)", "total")
  uses = K.choices_for(K.Use, e)
  @test [(u.line, u.col) for u in uses] == [(17, 2), (19, 4), (21, 2), (21, 16), (22, 2)]
  @test (K.worded(uses[1]), K.sidenote(uses[1])) == ("total = 0.0", "line 17")
  # A name of the whole file: its places in the file, then in the other Julia files of its git repository,
  # after the name of a module and a dot too. Not in a comment, a string, or a longer name.
  run(`git -C $dir init -q`)
  house = joinpath(dir, "house.jl")
  write(house, "# the area of a house\nhouse_area(rs) = sum(Rooms.area, rs)\nlabel = \"area\"\nfloor(t) = t.area\n")
  b.caret = b.anchor = at("total + area(r)", "area")
  uses = K.choices_for(K.Use, e)
  @test [K.sidenote(u) for u in uses] == ["line 11", "line 12", "line 22", "house.jl:2"] && last(uses).col == 27
  @test K.name_columns("x = area(1) # area", "area") == [4] && K.name_columns("Rooms.area + \"area\"", "area") == [6]
  # After a name that starts with a small letter, it's a part of a value
  @test K.name_columns("x = t.area + K.area", "area") == [15]
  # A name that the file doesn't make has no command
  b.caret = b.anchor = at("Walls.paint(wall)", "paint")
  @test !K.works_here(e, Val(:find_uses))
  # In the palette: ↓ shows the next place in the window, with a line round the name, and Esc puts the window back
  b.caret = b.anchor = at("total + area(r)", "area")
  K.focus(e)
  frames()
  was = e.scroll.offset
  w.keys |= Keys.cmd | Keys.shft; onkey(w, KeyPress{Keys.p}(0, w)); w.keys ⊻= Keys.cmd | Keys.shft
  frames()
  foreach(c -> ontype(w, Typed(c, w)), "find uses"); frames()
  onkey(w, KeyPress{Keys.enter}(0, w)); frames()
  p = K.palette(e)
  @test p.command.name == :find_uses && p.at == 1 && length(K.palette_rows(e, p)) == 4
  onkey(w, KeyPress{Keys.down}(0, w)); frames()
  @test K.chip_value(p, K.palette_chips(p), 1).line == 12 && p.before == was && K.shown_at(e, uses[2]) !== nothing
  @test K.shown_at(e, uses[4]) === nothing
  foreach(_ -> (onkey(w, KeyPress{Keys.escape}(0, w)); frames()), 1:2)
  @test e.popup == :none && e.scroll.offset == was && p.before === nothing
  # Return goes to the place, with the caret on the name
  K.find_uses!(e, uses[3])
  frames()
  @test b.caret == (22, 10)
  # A place in another file shows in a window beside this one
  K.find_uses!(e, uses[4])
  shown = only(filter(o -> endswith(o.buf.path, "house.jl"), K.editors))
  @test shown.buf.caret == (2, 27)
  close(K.window_of(shown))
  # Rename In Code changes a name of the whole file in those files too, and ⌘Z takes it back there as well
  before = copy(b.lines)
  K.rename_in_code!(e, K.own_name(e, at("total + area(r)", "area")), "surface")
  frames()
  @test b.lines[22] == "  total + surface(r)"
  @test read(house, String) == "# the area of a house\nhouse_area(rs) = sum(Rooms.surface, rs)\nlabel = \"area\"\nfloor(t) = t.area\n"
  K.undo!(b)
  frames()
  @test b.lines == before && occursin("Rooms.area,", read(house, String))
  K.redo!(b)
  frames()
  @test occursin("Rooms.surface,", read(house, String))
  K.undo!(b)
  frames()
  @test occursin("Rooms.area,", read(house, String))
  # A name that a function makes stays in its function
  K.rename_in_code!(e, K.own_name(e, at("total + area(r)", "total")), "sum_so_far")
  frames()
  @test occursin("Rooms.area,", read(house, String))
  K.undo!(b)
  frames()
  @test b.lines == before
  rm(joinpath(dir, ".git"), recursive=true)
end

@testset "the command Go To Definition" begin
  # The tests of ⌘⌥← below check where it goes. A word with no place says so.
  b.caret = b.anchor = at("the paint", "paint")
  @test_throws ErrorException K.go_to_definition!(e)
end

@testset "Go To lists the sections and the names of a file of code" begin
  places = K.choices_for(K.HeadingLine, e)
  @test [(K.worded(p), K.sidenote(p)) for p in places] == [
    ("Walls", "line 1"), ("Wall", "line 1"),
    ("the rooms", "section · line 3"), ("HEIGHT", "Float64 · line 5"), ("Room", "struct · line 7"),
    ("area(r::Room)", "function · line 11"), ("area(w::Wall)", "function · line 12"),
    ("the paint", "section · line 14"), ("litres(r::Room, coats=2)", "function · line 16")]
  # ↓ in the palette's list shows each place with a line round it, and Esc leaves the caret where it was
  b.caret = b.anchor = (1, 0)
  K.focus(e)
  frames()
  w.keys |= Keys.cmd | Keys.shft; onkey(w, KeyPress{Keys.p}(0, w)); w.keys ⊻= Keys.cmd | Keys.shft
  frames()
  foreach(c -> ontype(w, Typed(c, w)), "go to"); frames()
  onkey(w, KeyPress{Keys.enter}(0, w)); frames()
  p = K.palette(e)
  onkey(w, KeyPress{Keys.down}(0, w)); frames()
  @test p.command.name == :go_to && p.before !== nothing && K.shown_at(e, K.chip_value(p, K.palette_chips(p), 1)) !== nothing
  foreach(_ -> (onkey(w, KeyPress{Keys.escape}(0, w)); frames()), 1:2)
  @test e.popup == :none && p.before === nothing && b.caret == (1, 0)
  K.palette(e).moved = 0.0
  K.go_to!(e, places[end])
  frames()
  @test b.caret[1] == 16 && e.layout[first(e.shown)].first <= 16
  # A page of Markdown still lists its headings
  page = joinpath(dir, "page.md")
  write(page, "# One\n\nWords.\n\n## Two\n")
  K.open!(e, page)
  frames()
  @test [(K.worded(p), K.sidenote(p)) for p in K.choices_for(K.HeadingLine, e)] == [("One", "line 1"), ("Two", "line 5")]
end

@testset "⌘⌥← goes back to the line that a jump left, and ⌘⌥→ to the jump's line again" begin
  K.open!(e, rooms)
  frames()
  b.caret = b.anchor = at("* HEIGHT", "HEIGHT")
  was = b.caret
  K.go_to_definition!(e)
  def = b.caret
  @test def == (line("const HEIGHT"), 6) && K.step_words(e) == "line $(was[1])"
  # Go To is a jump too
  K.go_to!(e, 16)
  @test b.caret[1] == 16
  @test K.go_back!(e) && b.caret == def
  @test K.go_back!(e) && b.caret == was
  # Before the jumps, the file that showed before this one
  @test K.step_words(e) == "page.md"
  @test K.go_forward!(e) && b.caret == def
  @test K.go_forward!(e) && b.caret[1] == 16 && K.step_words(e, e.ahead) === nothing
  w.keys |= Keys.cmd | Keys.opt; onkey(w, KeyPress{Keys.left}(0, w)); w.keys ⊻= Keys.cmd | Keys.opt
  frames()
  @test b.caret == def
  # A new jump ends what ⌘⌥→ goes to
  K.go_to!(e, 5)
  @test K.step_words(e, e.ahead) === nothing && K.step_words(e) == "line $(def[1])"
  # After another file showed, ⌘⌥← shows this file again, and then the line that the jump left
  K.open!(e, joinpath(dir, "page.md"))
  frames()
  @test K.go_back!(e) && e.buf === b && b.caret[1] == 5
  @test K.go_back!(e) && b.caret == def
  # The window scrolls back to where it was too
  frames()
  K.go_to!(e, 1)
  @test K.go_back!(e) && b.caret == def
end

@testset "with ⌘ held, a link's words are marked" begin
  page = joinpath(dir, "links.md")
  write(page, "See [the **walls** file](walls.jl) for more.\n")
  K.open!(e, page)
  frames()
  # A point on "the", and one on "walls", which is bold: both give all of the link's words
  @test K.cmd_words(e, point((1, 6))) == K.cmd_words(e, point((1, 12)))
  line, lo, hi = K.cmd_words(e, point((1, 6)))
  @test line == 1 && lo <= 5 && hi >= 22
  @test K.cmd_words(e, point((1, 1))) === nothing
end

foreach(o -> (win = K.window_of(o); win === nothing || close(win)), copy(K.editors))
