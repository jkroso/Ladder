# Tests for changing a CSV file in its table, and for the kinds of its columns.
# See "changing a CSV file" and "a CSV file in the page" in main.jl. Run them
# with `julia -O0 --project=. test/csv_edit_test.jl`. They write CSV files into
# a temporary folder, and click and type in a window that isn't on the screen.
# Set `LADDER_SHOTS` to a folder, and they save pictures of the tables there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use Dates: Date
const px = K.px

const dir = mktempdir()
file(name, text) = (path = joinpath(dir, name); write(path, text); path)

const jobs = file("jobs.csv", """
Name,Price,Note
Paint,12,"Two coats, low sheen"
Timber,40,"The ""good"" pine"
Nails,3,Box of 100
""")
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
"True when the geometry `node` holds what a node of the type `T` draws"
has_node(node, T) = (hasproperty(node, :from) && node.from isa T) || (node isa K.GeometricUI && any(n -> has_node(n, T), node.children))
"The words of each Text in the geometry `node`"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end

"The names of the icons in the geometry `node`"
icon_names(node, out=String[]) = begin
  node isa K.Icon && push!(out, node.name)
  hasproperty(node, :from) && node.from isa K.Icon && push!(out, node.from.name)
  node isa K.GeometricUI && foreach(n -> icon_names(n, out), node.children)
  out
end

"Show the file at `path` in the page, and return its FileView"
open_file(path) = begin
  K.open!(e, path)
  e.scroll.offset = 0px
  frames(3)
  only(n for n in values(e.nodes) if n isa K.FileView && n.path == path)
end

v = open_file(jobs)
sheet() = v.table::K.FileSheet
head(c) = sheet().parts[(:head, c)]
"The middle of the cell in the `k`th row that shows, column `c`, in the window"
place(k, c) = begin
  s = sheet()
  f = s.parts[:frame].rect
  (K.num(f[1] + K.SHEET_LINE + sum(s.widths[1:c-1], init=0px) - s.across) + 8,
   K.num(f[2] + K.SHEET_LINE + K.HEAD_H + K.ROW_H * (k - 1) + K.ROW_H / 2))
end
"The cells of column `c` of the rows that show, in their order"
column(c) = [sheet().table.rows[r][c] for r in sheet().found]
disk() = read(jobs, String)

@testset "a CSV file is yours to change" begin
  b = e.buf
  @test b.view == :file && !K.readonly(b) && K.table_text(b) && K.writes(b)
  @test b.lines[1] == "Name,Price,Note"
  bar = K.describe(e.nodes[:topbar])
  # The top bar says what it said of the file, and has no lock
  @test any(t -> occursin("3 rows", t), texts(bar)) && !has_node(bar, K.ReadOnly)
  # No key types in the lines while the table shows
  typed("xyz")
  @test b.lines[1] == "Name,Price,Note" && b.saved == b.version
end

@testset "a click on a cell opens its field" begin
  b = e.buf
  click(place(1, 2))
  s = sheet()
  @test s.editing == (2, 2) && w.focus === s.input
  # The cell's text is selected, so what's typed takes its place
  @test s.input.text == "12" && s.input.anchor == 0 && s.input.cursor == 2
  shot("csv-edit-field")
  typed("15")
  @test b.lines[2] == "Paint,12,\"Two coats, low sheen\""   # nothing goes in the file until the field closes
  key(Keys.enter)
  # Return keeps it, and goes to the cell below. The rest of the row is as the file had it.
  @test b.lines[2] == "Paint,15,\"Two coats, low sheen\"" && b.saved != b.version
  @test sheet().editing == (3, 2) && sheet().input.text == "40"
  @test column(2) == ["15", "40", "3"]
  # Tab goes right, and from the end of a row to the start of the next
  key(Keys.tab)
  @test sheet().editing == (3, 3) && sheet().input.text == "The \"good\" pine"
  key(Keys.tab)
  @test sheet().editing == (4, 1)
  key(Keys.tab, Keys.shft)
  @test sheet().editing == (3, 3)
  # A quote and a comma go in quotes
  typed("A \"best\", pine")
  key(Keys.up)
  @test b.lines[3] == "Timber,40,\"A \"\"best\"\", pine\"" && sheet().table.rows[3][3] == "A \"best\", pine"
  @test sheet().editing == (2, 3)
  # Esc puts back what the cell held
  typed("gone")
  key(Keys.escape)
  @test sheet().editing === nothing && w.focus === e && b.lines[2] == "Paint,15,\"Two coats, low sheen\""
  # ⌘Z takes the changes back, one at a time
  key(Keys.z, Keys.cmd)
  @test b.lines[3] == "Timber,40,\"The \"\"good\"\" pine\""
  key(Keys.z, Keys.cmd)
  @test b.lines[2] == "Paint,12,\"Two coats, low sheen\"" && sheet().table.rows[2][2] == "12"
  key(Keys.z, Keys.cmd, Keys.shft)
  @test b.lines[2] == "Paint,15,\"Two coats, low sheen\""
  # ⌘S writes the file
  K.save!(b)
  @test disk() == "Name,Price,Note\nPaint,15,\"Two coats, low sheen\"\nTimber,40,\"The \"\"good\"\" pine\"\nNails,3,Box of 100\n"
  # A click anywhere else keeps what was typed
  click(place(3, 1))
  typed("Screws")
  K.focus(e)
  frames()
  @test sheet().editing === nothing && b.lines[4] == "Screws,3,Box of 100"
end

@testset "Return in the last row opens a new row" begin
  b = e.buf
  click(place(3, 1))
  key(Keys.enter)
  s = sheet()
  @test s.editing == (5, 1) && K.new_row(s) && length(s.table.rows) == 4
  # A new row that's left empty never goes in the file
  key(Keys.enter)
  @test sheet().editing === nothing && length(sheet().table.rows) == 4 && b.lines[end] == ""
  click(place(3, 2))
  key(Keys.enter)
  typed("7")
  key(Keys.tab)
  @test b.lines[5] == ",7," && length(sheet().table.rows) == 5 && sheet().editing == (5, 3)
  typed("New")
  key(Keys.enter)
  @test b.lines[5] == ",7,New" && b.lines[6] == "" && sheet().editing == (6, 3)
  key(Keys.escape)
  @test length(sheet().table.rows) == 5
end

@testset "rows are added and taken away" begin
  b = e.buf
  K.add_row!(v, 2, false)
  @test b.lines[2] == ",," && sheet().editing == (2, 1)
  typed("Glue")
  key(Keys.escape)   # the row stays, empty
  @test length(sheet().table.rows) == 6 && sheet().table.rows[2] == ["", "", ""]
  K.delete_row!(v, 2)
  @test b.lines[2] == "Paint,15,\"Two coats, low sheen\"" && length(sheet().table.rows) == 5
  K.add_row!(v, 5, true)
  @test b.lines[6] == ",," && b.lines[7] == ""
  K.stop_edit!(v)
  K.delete_row!(v, 6)
  K.delete_row!(v, 5)
  @test b.lines[end-1] == "Screws,3,Box of 100" && b.lines[end] == ""
end

@testset "a heading's menu changes the column" begin
  b = e.buf
  click(middle(rect(head(2))))
  s = sheet()
  @test s.asking == 2 && haskey(s.parts, (:action, :rename))
  press(s.parts[(:action, :rename)])
  @test sheet().editing == (1, 2) && sheet().input.text == "Price"
  typed("Cost")
  key(Keys.enter)
  @test b.lines[1] == "Name,Cost,Note" && sheet().editing == (2, 2)
  key(Keys.escape)
  click(middle(rect(head(1))))
  press(sheet().parts[(:action, :add)])
  @test b.lines[1] == "Name,,Cost,Note" && b.lines[3] == "Timber,,40,\"The \"\"good\"\" pine\""
  @test sheet().editing == (1, 2)
  typed("Size")
  key(Keys.enter)
  key(Keys.escape)
  @test b.lines[1] == "Name,Size,Cost,Note"
  click(middle(rect(head(2))))
  press(sheet().parts[(:action, :delete)])
  @test b.lines[1] == "Name,Cost,Note" && b.lines[3] == "Timber,40,\"The \"\"good\"\" pine\""
  # One ⌘Z takes back the whole column
  key(Keys.z, Keys.cmd)
  @test b.lines[1] == "Name,Size,Cost,Note"
  key(Keys.z, Keys.cmd, Keys.shft)
  K.save!(b)
end

@testset "the text of the file is the same lines" begin
  b = e.buf
  K.put_cell!(v, 2, 1, "Paints")
  K.file_level!(e, :text)
  @test b.view == :text && !K.readonly(b) && b.lines[2] == "Paints,15,\"Two coats, low sheen\"" && b.saved != b.version
  b.caret = b.anchor = (4, 0)
  frames()
  typed("Big ")
  @test b.lines[4] == "Big Screws,3,Box of 100"
  K.file_level!(e, :file)
  frames(3)
  v2 = only(n for n in values(e.nodes) if n isa K.FileView && n.path == jobs)
  @test (v2.table::K.FileSheet).table.rows[4][1] == "Big Screws"
  # The bytes are the file's, so what isn't saved is written first
  K.file_level!(e, :hex)
  @test b.view == :hex && occursin("Big Screws", disk())
  K.file_level!(e, :file)
  frames(3)
  @test e.buf.view == :file && K.table_text(e.buf) && e.buf.lines[4] == "Big Screws,3,Box of 100"
end

const kinds = file("kinds.csv", """
day,by,liked,price,file
2026-11-25,Grok,yes,\$12.50,item 10.md
25/11/2024,Jake,,\$3,item 2.md
3 Jan 2026,Max,no,n/a,item 1.md
2026-01-04 10:30,Grok,yes,\$100,item 20.md
""")

@testset "each column holds a kind of thing" begin
  global v = open_file(kinds)
  s = sheet()
  @test s.kinds == [:day, :text, :yesno, :number, :text]
  # A column of days has a calendar before its name, and a column of text has nothing
  @test "calendar3" in icon_names(K.describe(head(1))) && isempty(intersect(icon_names(K.describe(head(2))), values(K.KIND_ICONS)))
  shot("csv-kinds")
  # Days go by their time, whatever way they're written
  click(middle(rect(head(1))))
  @test K.ORDER_WORDS[:day] == ("Oldest first", "Newest first")
  press(sheet().parts[(:sort, :asc)])
  @test column(1) == ["25/11/2024", "3 Jan 2026", "2026-01-04 10:30", "2026-11-25"]
  key(Keys.escape)
  # Yes comes before no, and empty cells go last
  click(middle(rect(head(3))))
  press(sheet().parts[(:sort, :asc)])
  @test column(3) == ["yes", "yes", "no", ""]
  key(Keys.enter)
  # A cell that isn't a number goes after the numbers
  click(middle(rect(head(4))))
  press(sheet().parts[(:sort, :desc)])
  @test column(4) == ["\$100", "\$12.50", "\$3", "n/a"]
  key(Keys.enter)
  # Text has its numbers in order
  click(middle(rect(head(5))))
  press(sheet().parts[(:sort, :asc)])
  @test column(5) == ["item 1.md", "item 2.md", "item 10.md", "item 20.md"]
  key(Keys.enter)
end

@testset "a column of numbers or days shows the rows between two values" begin
  s = sheet()
  s.sort = nothing
  click(middle(rect(head(4))))
  s = sheet()
  @test w.focus === s.field && s.field.placeholder == "\$3" && s.upto.placeholder == "\$100"
  typed("5")
  @test Set(column(4)) == Set(["\$12.50", "\$100"])
  key(Keys.tab)
  @test w.focus === s.upto
  typed("50")
  @test column(4) == ["\$12.50"] && K.narrowed(s, 4)
  shot("csv-between")
  key(Keys.enter)
  @test s.bounds == Dict(4 => ("5", "50"))
  # Esc puts back what the fields held when the menu opened
  click(middle(rect(head(4))))
  typed("0")
  @test isempty(column(4))
  key(Keys.escape)
  @test sheet().bounds == Dict(4 => ("5", "50"))
  click(middle(rect(head(4))))
  foreach(_ -> key(Keys.backspace), 1:3)
  key(Keys.tab)
  foreach(_ -> key(Keys.backspace), 1:3)
  key(Keys.enter)
  @test isempty(sheet().bounds) && length(sheet().found) == 4
  # Days are typed as a form's field reads them
  click(middle(rect(head(1))))
  typed("1 Jan 2026")
  key(Keys.tab)
  typed("2026-01-04")
  @test Set(column(1)) == Set(["3 Jan 2026", "2026-01-04 10:30"])
  key(Keys.enter)
end

@testset "a CSV file with nothing in it" begin
  empty = file("empty.csv", "")
  global v = open_file(empty)
  b = e.buf
  @test K.table_text(b) && sheet().table.rows == [[""]]
  # Under its heading with no name is an empty row to write in
  click(place(1, 1))
  @test sheet().editing == (2, 1)
  typed("Milk")
  key(Keys.enter)
  @test b.lines == ["\"\"", "Milk", ""]
  click(middle(rect(head(1))))
  press(sheet().parts[(:action, :rename)])
  typed("Item")
  key(Keys.enter)
  key(Keys.escape)
  K.save!(b)
  @test read(empty, String) == "Item\nMilk\n"
end

@testset "a file's line ends stay as Windows has them" begin
  windows = file("windows.csv", "A,B\r\n1,2\r\n3,4\r\n")
  global v = open_file(windows)
  K.put_cell!(v, 3, 2, "5")
  K.save!(e.buf)
  @test read(windows, String) == "A,B\r\n1,2\r\n3,5\r\n"
end

@testset "a file that the Mac marks as read-only is only shown" begin
  locked = file("locked.csv", "A,B\n1,2\n")
  chmod(locked, 0o444)
  global v = open_file(locked)
  b = e.buf
  @test b.fixed && !K.sheet_edits(v)
  @test has_node(K.describe(e.nodes[:topbar]), K.ReadOnly)
  click(place(1, 1))
  @test sheet().editing === nothing && b.lines[2] == "1,2"
  K.put_cell!(v, 2, 1, "9")
  @test b.lines[2] == "1,2"
  chmod(locked, 0o644)
end
