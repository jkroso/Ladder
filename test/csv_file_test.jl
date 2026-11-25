# Tests for a CSV file that the page shows by itself, as a table that sorts and
# filters. See "a CSV file in the page" in main.jl. Run them with
# `julia -O0 --project=. test/csv_file_test.jl`. They write CSV files into a
# temporary folder, and click and type in a window that isn't on the screen.
# Set `LADDER_SHOTS` to a folder, and they save pictures of the tables there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse onscroll Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
@use GeometryBasics: Vec2
const px = K.px

const dir = mktempdir()
file(name, text) = (path = joinpath(dir, name); write(path, text); path)

const STATES = ("NSW", "VIC", "QLD", "WA")
# 300 businesses: a name, a state, a price that's empty in each tenth row, and a note
const jobs = file("jobs.csv", "Name,State,Price,Note\n" * join(("Business $r,$(STATES[r % 4 + 1]),$(r % 10 == 0 ? "" : string(r * 7 % 500)),\"Note $r, with a comma\""
                                                               for r in 1:300), "\n") * "\n")
# 30 columns of long words, which is wider than the window
const wide = file("wide.csv", join(("Column $c" for c in 1:30), ",") * "\n" *
                              join((join(("The words in row $r of column $c" for c in 1:30), ",") for r in 1:20), "\n") * "\n")
const page = file("job.md", "# A job\n\nSome words.\n")

const e = K.build_editor(page)
const w = Window(e, size=(1400px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
frames()
K.focus(e)
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name * ".png"), w)

key(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); w.keys ⊻= Keys.mouse_left; frames())
middle(r) = (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2)
press(node) = (onkey(node, KeyPress{Keys.mouse_left}(0, w)); frames())
menu() = any(p -> p.key == K.SHEET_KEY, popups(w))
"The colour of the window's picture at a place in the window, as red, green and blue"
colour_at((x, y)) = begin
  file = joinpath(dir, "window.png")
  save_png(file, w)
  ps = pixels(file)
  k = size(ps, 2) / K.num(K.window_size(e)[1])   # the picture's pixels to a px of the window
  p = ps[round(Int, y * k), round(Int, x * k)]
  (Int(p >> 16 & 0xff), Int(p >> 8 & 0xff), Int(p & 0xff))
end
rgb(c) = round.(Int, 255 .* Float64.((c.r, c.g, c.b)))
near(a, b) = all(abs.(a .- b) .< 30)
"True when the geometry `node` holds what a node of the type `T` draws"
has_node(node, T) = (hasproperty(node, :from) && node.from isa T) || (node isa K.GeometricUI && any(n -> has_node(n, T), node.children))
"The words of each Text in the geometry `node`"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end

"Show the file at `path` in the page, and return its FileView"
open_file(path) = begin
  K.open!(e, path)
  e.scroll.offset = 0px
  frames(3)
  only(n for n in values(e.nodes) if n isa K.FileView && n.path == path)
end

const v = open_file(jobs)
sheet() = v.table::K.FileSheet
frame_of(fv) = fv.table.parts[:frame]
head(c) = sheet().parts[(:head, c)]
"The cells of column `c` of the rows that show, in their order"
column(c) = [sheet().table.rows[r][c] for r in sheet().found]

@testset "the table is as wide as the window has room for" begin
  s = sheet()
  @test s isa K.FileSheet && length(s.table.rows) == 301
  # The page isn't as narrow as the settings make a page of text
  ww, _ = K.window_size(e)
  room = ww - (e.panel ? K.panel_w(e) : 0px) - 2K.PAGE_X
  @test K.num(e.width) ≈ K.num(room)
  # Four short columns grow to fill it, inside the line round it
  @test K.num(sum(s.widths)) ≈ K.num(e.width - 2K.SHEET_LINE)
  r = rect(head(1))
  @test r !== nothing && K.num(r.top) ≈ K.num(K.TOPBAR_H + K.sheet_top())
  # It starts 12px under the top bar, nearer than the text of a page. What's said of the file is in the top bar.
  @test K.num(rect(frame_of(v)).top) ≈ K.num(K.TOPBAR_H) + 12
  bar = texts(K.describe(e.nodes[:topbar]))
  @test any(t -> occursin("300 rows", t) && occursin("Changed", t), bar)
  # The file is yours to change, so the bar has no lock. See test/csv_edit_test.jl.
  @test !any(t -> occursin("Read only", t), bar)
  @test !has_node(K.describe(e.nodes[:topbar]), K.ReadOnly)
  @test !any(t -> occursin("300 rows", t), texts(K.describe(v)))
  @test K.num(r.left) ≈ K.num(K.text_left(e) + K.SHEET_LINE)
  # A line with round corners goes round it. Outside the round corner is the page, not the headings.
  frame = K.sheet_view(v, e, _ -> nothing)
  @test frame isa K.SheetFrame
  f = rect(frame)
  @test K.num(f.left) ≈ K.num(K.text_left(e)) && K.num(f.width) ≈ K.num(e.width)
  @test near(colour_at((K.num(f.left) + 1, K.num(f.top) + 1)), rgb(K.colours.bg))
  @test near(colour_at((K.num(f.left) + 0.5, K.num(f.top) + 100)), rgb(K.colours.line))
  @test near(colour_at((K.num(f.left) + 8, K.num(f.top) + 8)), rgb(K.colours.head))
  shot("csv-file")
end

@testset "the headings stay at the top of the window" begin
  e.scroll.offset = 2000px
  frames(3)
  @test K.num(rect(head(1)).top) ≈ K.num(K.TOPBAR_H)
  @test K.num(rect(head(3)).top) ≈ K.num(K.TOPBAR_H)
  # The rows that show are the ones in the window. A row's cells are under their heading.
  shot("csv-file-down")
  # At the end of the table too
  e.scroll.offset = 99999px
  frames(3)
  @test K.num(rect(head(1)).top) ≈ K.num(K.TOPBAR_H)
  shot("csv-file-end")
  e.scroll.offset = 0px
  frames(3)
  @test K.num(rect(head(1)).top) ≈ K.num(K.TOPBAR_H + K.sheet_top())
end

@testset "a heading's menu puts the rows in order" begin
  click(middle(rect(head(3))))
  s = sheet()
  @test menu() && s.asking == 3
  # Price has numbers, so its rows go in the order of their numbers, and the empty ones go last
  press(s.parts[(:sort, :asc)])
  prices = column(3)
  full = filter(!isempty, prices)
  @test s.sort == (3, :asc) && issorted(parse.(Int, full)) && all(isempty, prices[length(full)+1:end]) && length(full) == 270
  press(s.parts[(:sort, :desc)])
  prices = column(3)
  @test issorted(parse.(Int, filter(!isempty, prices)), rev=true) && isempty(last(prices))
  shot("csv-file-sorted")
  # A second click on the order puts the rows back in the file's order
  press(s.parts[(:sort, :desc)])
  @test s.sort === nothing && column(1)[1:3] == ["Business 1", "Business 2", "Business 3"]
  key(Keys.enter)
  @test !menu() && s.asking == 0
  # Names that are text go Z to A, with the numbers in them by their size
  click(middle(rect(head(1))))
  press(s.parts[(:sort, :desc)])
  @test issorted(column(1), by=K.Csvs.sortkey, rev=true) && column(1)[1:2] == ["Business 300", "Business 299"]
  press(s.parts[(:sort, :desc)])
  key(Keys.enter)
end

@testset "a column with few values lists them, and shows the rows with the ticked ones" begin
  s = sheet()
  click(middle(rect(head(2))))
  @test menu() && s.asking == 2
  @test K.values_of(s, 2) == [("NSW", 75), ("QLD", 75), ("VIC", 75), ("WA", 75)]
  shot("csv-file-values")
  press(s.parts[(:value, 2, "WA")])
  @test Set(column(2)) == Set(["WA"]) && length(column(2)) == 75
  press(s.parts[(:value, 2, "VIC")])
  @test Set(column(2)) == Set(["WA", "VIC"]) && length(column(2)) == 150
  # The top bar says how many rows show
  @test occursin("150 of 300 rows", e.buf.about) && any(t -> occursin("150 of 300 rows", t), texts(K.describe(e.nodes[:topbar])))
  # esc puts back what the column showed before its menu opened
  key(Keys.escape)
  @test !menu() && !haskey(s.picks, 2) && length(s.found) == 300
  click(middle(rect(head(2))))
  press(s.parts[(:value, 2, "QLD")])
  key(Keys.enter)
  @test !menu() && s.picks == Dict(2 => Set(["QLD"])) && length(s.found) == 75
  # Every value ticked is the same as none
  click(middle(rect(head(2))))
  foreach(st -> st == "QLD" || press(s.parts[(:value, 2, st)]), STATES)
  @test isempty(s.picks) && length(s.found) == 300
  key(Keys.enter)
end

@testset "any other column has a field, and shows the rows that have its words" begin
  s = sheet()
  click(middle(rect(head(4))))
  @test menu() && s.asking == 4 && w.focus === s.field.sub
  typed("note 2")
  @test !isempty(s.found) && all(n -> occursin("note 2", lowercase(n)), column(4))
  @test length(s.found) == 1 + 10 + 100   # notes 2, 20 to 29, and 200 to 299
  shot("csv-file-filter")
  key(Keys.enter)
  @test !menu() && s.filters == Dict(4 => "note 2")
  @test K.narrowed(s, 4) && !K.narrowed(s, 1)
  # esc puts back what the field held before
  click(middle(rect(head(4))))
  typed("9")
  @test s.filters == Dict(4 => "note 29")
  key(Keys.escape)
  @test !menu() && s.filters == Dict(4 => "note 2")
  # A filter and an order together
  click(middle(rect(head(1))))
  press(s.parts[(:sort, :desc)])
  key(Keys.enter)
  @test column(1)[1] == "Business 299" && all(n -> occursin("Note 2", n), column(4))
  # Words that no row has show no rows
  click(middle(rect(head(4))))
  typed("zzz")
  @test isempty(s.found)
  shot("csv-file-none")
  # An empty field shows every row again
  foreach(_ -> key(Keys.backspace), 1:20)
  key(Keys.enter)
  @test isempty(s.filters) && length(s.found) == 300
end

@testset "the table keeps what's chosen when the file changes" begin
  s = sheet()
  click(middle(rect(head(2))))
  press(s.parts[(:value, 2, "NSW")])
  key(Keys.enter)
  @test length(s.found) == 75
  sleep(1.1)   # so that the file's time changes
  open(jobs, "a") do io
    println(io, "Business 301,NSW,5,\"Note 301\"")
  end
  frames(3)
  @test sheet() !== s && length(sheet().table.rows) == 302
  @test sheet().picks == Dict(2 => Set(["NSW"])) && length(sheet().found) == 76
end

@testset "a table that's wider than the window scrolls sideways" begin
  wv = open_file(wide)
  s = wv.table::K.FileSheet
  @test sum(s.widths) > e.width
  left = rect(s.parts[(:head, 1)]).left
  at(middle(rect(s.parts[(:head, 5)])))
  onscroll(w, Vec2{px}(-10px, 0px))
  frames()
  @test s.across == 300px
  @test K.num(rect(s.parts[(:head, 1)]).left) ≈ K.num(left - 300px)
  shot("csv-file-wide")
  # It goes no further than the last column
  onscroll(w, Vec2{px}(-1000px, 0px))
  frames()
  @test K.num(s.across) ≈ K.num(sum(s.widths) - (e.width - 2K.SHEET_LINE))
  r = rect(s.parts[(:head, 30)])
  @test K.num(r.left + r.width) ≈ K.num(K.text_left(e) + e.width - K.SHEET_LINE)
  # A long cell stops with an …
  @test endswith(K.shown_cell(s, 2, 1, 100px), "…")
end
