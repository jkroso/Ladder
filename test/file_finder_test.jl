# Tests for the file finder that ⌘O opens, a bar near the top of the window
# with the folder's pages in a list under it, and the project picker that ⌘P
# opens, which lists projects the same way. Both look like the command
# palette. See "the file finder and the project picker" in main.jl. Run them with
# `julia -O0 --project=. test/file_finder_test.jl`. They use windows that
# aren't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype MouseMove onmouse
@use GeometryBasics: Vec2
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
const px = K.px

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
@eval K settings_file() = $(joinpath(dir, "settings"))

const NAMES = ["components", "counter", "julia", "schedule", "welcome"]
foreach(n -> write(joinpath(dir, "$n.md"), "# $n\n\nWords.\n"), NAMES)

"A window that isn't on the screen, `wide` by `high`, on welcome.md"
window(wide=1000, high=700) = begin
  e = K.build_editor(joinpath(dir, "welcome.md"))
  w = Window(e, size=(px(wide), px(high)))
  frame(w); frame(w)
  K.focus(e)
  e, w
end
frames(w) = (frame(w); frame(w))
press(w, k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames(w)
end
typed(w, s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames(w))
"Move the mouse to the middle of `node`"
over(w, node) = begin
  r = rect(node)
  x, y = r.left + r.width / 2, r.top + r.height / 2
  w.mouse = typeof(w.mouse)(x, y)
  onmouse(w, MouseMove(Vec2{px}(x, y), w))
  frames(w)
end
"The rows of the finder's list, in order"
rows(e) = [e.nodes[(:pick, n, p)] for (n, p) in enumerate(K.finder_shown(e))]
names(e) = [splitext(basename(r.path))[1] for r in rows(e)]
"The colour of the window at `(x, y)`, as it draws it now"
colour_at(w, x, y, wide) = begin
  file = joinpath(dir, "shot.png")
  save_png(file, w)
  p = pixels(file)
  s = size(p, 2) / wide   # the picture can have more than one pixel for each point
  p[round(Int, y * s), round(Int, x * s)]
end

@testset "the finder has the palette's look, and its list is as wide as its field" begin
  e, w = window()
  page = colour_at(w, 900, 600, 1000)
  press(w, Keys.o, Keys.cmd)
  @test e.popup == :finder
  @test names(e) == NAMES
  # The page isn't dimmed behind it, as it isn't behind the palette
  @test colour_at(w, 900, 600, 1000) == page
  # The field has the palette's font
  @test K.input(e).font_family == K.omni_font() && K.input(e).font_size == 15px
  # Each row is as tall as a row of the palette's lists
  @test all(r -> K.num(rect(r).height) == K.OMNI_ROW_ONE, rows(e))
  # The list is under the field, in the same box, and its rows go as far left and right as each other
  # inside the field's sides: only the 6px round the card and the card's line are between them
  field = rect(e.nodes[:finder_input])
  first_row = rect(first(rows(e)))
  @test K.num(first_row.top) >= K.num(field.top + field.height)
  @test K.num(first_row.left - field.left) == 7
  @test K.num((field.left + field.width) - (first_row.left + first_row.width)) == 7
  press(w, Keys.escape)
  @test e.popup == :none
end

@testset "the letters typed are bold where a name has them, in order" begin
  @test K.letter_runs("components.md", "me") == [("co", false), ("m", true), ("pon", false), ("e", true), ("nts.md", false)]
  @test K.letter_runs("Welcome.md", "WE") == [("We", true), ("lcome.md", false)]
  @test K.letter_runs("julia.md", "") == [("julia.md", false)]
  e, w = window()
  press(w, Keys.o, Keys.cmd)
  typed(w, "me")
  @test names(e) == ["components", "welcome"]
  typed(w, "zzz")
  @test isempty(rows(e)) && isempty(K.finder_shown(e))
  press(w, Keys.escape)
end

@testset "the mouse over a row chooses it, and Return opens that page" begin
  e, w = window()
  press(w, Keys.o, Keys.cmd)
  over(w, rows(e)[3])
  @test e.picked == 3
  press(w, Keys.enter)
  @test e.popup == :none && basename(e.buf.path) == "julia.md"
end

@testset "a short window lists only the rows that fit, and ↓ stops at the last of them" begin
  e, w = window(700, 330)
  press(w, Keys.o, Keys.cmd)
  shown = length(rows(e))
  @test 1 <= shown < length(NAMES)
  @test K.num(rect(last(rows(e))).top + rect(last(rows(e))).height) <= 330
  foreach(_ -> press(w, Keys.down), 1:length(NAMES))
  @test e.picked == shown
  press(w, Keys.enter)
  @test basename(e.buf.path) == "$(NAMES[shown]).md"
end

"A folder at `path` in `home` that's a git repository, which git last wrote in at `when`, as `touch -t` writes a time"
repository(home, path, when) = begin
  p = mkpath(joinpath(home, path))
  mkpath(joinpath(p, ".git", "logs"))
  files = (joinpath(p, ".git", "HEAD"), joinpath(p, ".git", "index"), joinpath(p, ".git", "logs", "HEAD"))
  foreach(touch, files)
  foreach(f -> run(`touch -t $when $f`), (joinpath(p, ".git"), files...))
  p
end

@testset "⌘P lists the favourites, then the git repositories of the home folder, newest first, and opens one in the window" begin
  home = mkpath(joinpath(dir, "home"))
  old = repository(home, "Desktop/Old", "202601011200")
  new = repository(home, "Desktop/Code/New", "202611011200")
  mid = repository(home, "work/Mid", "202606011200")
  # None of these is a project: it's hidden, in Library, in node_modules, or in a repository
  repository(home, ".config/Hidden", "202611021200")
  repository(home, "Library/Kept", "202611021200")
  repository(home, "work/node_modules/package", "202611021200")
  repository(home, "Desktop/Code/New/inside", "202611021200")
  @test Set(K.Folders.repositories(home)) == Set([old, new, mid])
  @test K.Folders.newest_first([old, mid, new]) == [new, mid, old]
  # A favourite comes first, in the order of the favourites, whether it's a repository or not
  K.Folders.FILE[] = joinpath(dir, "favourites")
  notes = mkpath(joinpath(home, "Notes"))
  K.Folders.favourite!(notes); K.Folders.favourite!(mid)
  K.HOME[] = home
  K.Folders.forget_projects!()
  try
    e, w = window()
    press(w, Keys.p, Keys.cmd)
    @test e.popup == :projects && K.input(e).placeholder == "Find a project"
    t = K.Folders.searching()
    t === nothing || wait(t)
    frames(w)
    @test names(e) == ["Notes", "Mid", "New", "Old"]
    # The letters typed keep the projects whose names have them, in order
    typed(w, "new")
    @test names(e) == ["New"]
    typed(w, "zzz")
    @test isempty(rows(e)) && K.picker_none(e) == "No project has that name"
    foreach(_ -> press(w, Keys.backspace), 1:3)
    @test K.input(e).text == "new" && names(e) == ["New"]
    # Return opens the project in the window. The sidebar lists its folder, and stays hidden.
    press(w, Keys.enter)
    @test e.popup == :none && e.folder == new
    # ⌘O still finds a page of the folder
    press(w, Keys.o, Keys.cmd)
    @test e.popup == :finder && K.input(e).placeholder == "Find a file, or type a web address"
    press(w, Keys.escape)
  finally
    K.HOME[] = ""
    K.Folders.FILE[] = ""
    K.Folders.forget_projects!()
  end
end

@testset "a project's row says where the project is, with ~ for the home folder" begin
  @test K.project_place(joinpath(homedir(), "Desktop", "Canon")) == "~/Desktop"
  @test K.project_place(joinpath(homedir(), "Notes")) == "~"
  @test K.project_place("/opt/work/thing") == "/opt/work"
end
