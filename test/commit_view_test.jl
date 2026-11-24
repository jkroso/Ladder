# Tests for a commit's page: a click on a commit in git's panel shows what the
# commit holds in the page beside the panel. See "a commit's page" in main.jl,
# and `shown` in git.jl. Run them with `julia -O0 --project=. test/commit_view_test.jl`.
# They make a repository in a temporary folder with the Mac's own git, and click
# in a window that isn't on the screen. With `LADDER_SHOTS` set to a folder,
# they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

const px = K.px
const G = K.Git

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
const repo = joinpath(dir, "work")
mkpath(joinpath(repo, "src"))
git(args...) = run(pipeline(setenv(`git -C $repo -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false $args`,
                                   merge(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null"))), stdout=devnull, stderr=devnull))
git("init", "-b", "main")
write(joinpath(repo, "Readme.md"), "# Work\n\nWhat this is.\n")
write(joinpath(repo, "src", "a.jl"), join(["a$i = $i" for i in 1:40], "\n") * "\n")
write(joinpath(repo, "old name.md"), "# A page that moves\n\nIts words stay the same.\n")
write(joinpath(repo, "gone.md"), "# Gone\n")
git("add", "-A")
git("commit", "-m", "The first commit")
# The second commit changes a file, adds two, deletes one and moves one
write(joinpath(repo, "src", "a.jl"), join(["a$i = $(i == 20 ? 200 : i)" for i in 1:40], "\n") * "\nb = 2\n")
write(joinpath(repo, "src", "big.jl"), join(["x$i = $i" for i in 1:(K.OPEN_MOST + 10)], "\n") * "\n")
write(joinpath(repo, "dot.png"), UInt8[0x89, 0x50, 0x4e, 0x47, 0x00, 0x01, 0x02, 0x00, 0xff])
rm(joinpath(repo, "gone.md"))
git("mv", "old name.md", "new name.md")
git("add", "-A")
git("commit", "-m", """Change a, and add a big file

The first paragraph is wrapped by hand,
as git's messages are.

- one thing
- another thing

Co-Authored-By: Someone <someone@example.com>""")
const second = strip(read(`git -C $repo rev-parse --short HEAD`, String))
const first_commit = strip(read(`git -C $repo rev-parse --short "HEAD~1"`, String))

const e = K.build_editor(joinpath(repo, "Readme.md"))
e.panel = true   # the sidebar is open, with no slide
const w = Window(e, size=(1300px, 800px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
"Draw until git has answered, and then what it said is on the screen"
settle() = (frames(2); G.wait!(); frames(2); G.wait!(); frames(2))

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "commit-$name.png"), w)
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = begin
  at(place)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1)
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2)
end
middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
"The words of every Text in the geometry `g`"
texts(g) = g isa K.Text ? [String(g.content)] : reduce(vcat, map(texts, try collect(g.children) catch; Any[] end), init=String[])
"The line of git's panel for the commit `hash`"
line(hash) = e.nodes[(:commit_line, repo, hash)]
"What the page shows of the repository: its files, or a commit"
page() = K.page_view(e, K.page_object(e))

K.show_beside!(e, repo)
settle()

"What git says the commit `hash` holds, once it has answered"
asked(hash) = (G.shown(repo, hash); G.wait!(); G.shown(repo, hash))

@testset "git says what a commit holds, file by file" begin
  s = asked(second)
  @test s !== nothing && s.known
  @test s.author == "Test"
  @test startswith(s.message, "Change a, and add a big file\n\n")
  files = Dict(f.path => f for f in s.files)
  @test sort!(collect(keys(files))) == ["dot.png", "gone.md", "new name.md", "src/a.jl", "src/big.jl"]
  @test files["dot.png"].kind == :new && files["dot.png"].binary
  @test files["gone.md"].kind == :deleted
  @test files["new name.md"].kind == :renamed && files["new name.md"].from == "old name.md"
  @test files["src/a.jl"].kind == :changed
  @test files["src/big.jl"].kind == :new
  # A commit that isn't there is nothing, once git has said so
  @test asked("0123abc") === nothing
  # A name in quotes, as git writes one with odd characters in it
  @test G.diff_path("\"a/odd \\\"name\\\".md\"") == "odd \"name\".md"
  @test G.git_line_path("diff --git a/x y.md b/x y.md") == "x y.md"
end

@testset "a commit's message shows as paragraphs, and a list and a trailer keep their lines" begin
  lines = K.message_lines(G.shown(repo, second).message)
  @test lines == ["Change a, and add a big file", "",
                  "The first paragraph is wrapped by hand, as git's messages are.", "",
                  "- one thing", "- another thing", "",
                  "Co-Authored-By: Someone <someone@example.com>"]
  @test K.message_lines("") == String[]
end

@testset "a click on a commit in git's panel shows it in the page" begin
  @test page() isa K.RepoView
  l = line(second)
  click(middle(l))
  settle()
  v = page()
  @test v isa K.CommitView
  @test v.hash == second
  @test e.buf.path == repo   # the window still shows the repository
  @test v.scroll.scrollbar_inset == 0px   # its scrollbar is at the page's right edge, as the editor's is
  words = texts(K.describe(v))
  @test "Change a, and add a big file" in words
  @test "The first paragraph is wrapped by hand, as git's messages are." in words
  @test "5 files changed" in words
  @test any(startswith("Test  ·  "), words)
  # The commit is lit in the panel, and no other is
  @test K.shown_commit(e, repo) == second
  @test K.shown_commit(e, joinpath(dir, "elsewhere")) == ""
  # The lines of the changes are as wide as the page's column, which is beside git's panel
  s = G.shown(repo, second)
  a = v.views[findfirst(f -> f.path == "src/a.jl", s.files)].parts[(:hunk, 1)]
  r = rect(a)
  @test K.num(r.width) ≈ v.wide - 2 atol=1
  @test K.num(rect(e.nodes[(:git_panel, repo)]).left) >= K.num(r.left) + K.num(r.width)
  shot("page")
end

@testset "each file of the commit has a row, and its lines, unless they're too many" begin
  v = page()
  s = G.shown(repo, second)
  k(path) = findfirst(f -> f.path == path, s.files)
  # A file with more lines than a page opens with starts hidden, and a picture shows no lines
  @test v.open[k("src/a.jl")]
  @test !v.open[k("src/big.jl")]
  @test v.open[k("dot.png")]
  @test "Ladder can't show the lines of this file, because it isn't text." in texts(K.describe(v))
  @test "Its 1,510 changed lines are hidden, as they're many. A click on its row shows them." in texts(K.describe(v))
  @test K.file_tally(v, s, k("src/a.jl")) == (2, 1)
  @test K.file_tally(v, s, k("src/big.jl")) == (K.OPEN_MOST + 10, 0)
  # The changed file shows its change, drawn as a block of changes draws one
  c = v.views[k("src/a.jl")]
  @test c isa K.ChangesView
  # Its lines are laid out as wide as the page's column
  @test K.diff_wide(c) ≈ v.wide - 2
  # The hidden file's lines were never read
  @test !haskey(v.views, k("src/big.jl"))
  # A click on the row of a hidden file shows its lines, and a click again hides them
  row = v.rows[(:file, k("src/big.jl"))]
  # It's under the bottom of the window, so the page scrolls to it first
  v.scroll.offset += px(K.num(rect(row).top) - 300)
  frames()
  @test 0 < K.num(rect(row).top) < 800
  click(middle(row))
  @test v.open[k("src/big.jl")]
  @test haskey(v.views, k("src/big.jl"))
  # Its lines show under its row, and they're as many as the file has
  @test K.num(rect(v.views[k("src/big.jl")].parts[(:hunk, 1)]).height) > (K.OPEN_MOST + 10) * K.DIFF_ROW
  shot("big-file")
  click(middle(v.rows[(:file, k("src/big.jl"))]))
  @test !v.open[k("src/big.jl")]
  v.scroll.offset = 0px
  # A file that moved, and one that's gone, say so in their row
  @test K.touched_words(s.files[k("new name.md")]) == "Moved from old name.md"
  @test K.touched_words(s.files[k("gone.md")]) == "Deleted"
  # A file with lines that only moved has no lines to show, and says so
  v.open[k("new name.md")] = true
  frames()
  @test "Its lines are the same as before." in texts(K.describe(v))
end

@testset "a click on the commit again, or going back, shows the repository's files again" begin
  click(middle(line(second)))
  settle()
  @test page() isa K.RepoView
  @test K.shown_commit(e, repo) == ""
  # Another commit shows, and going back shows the files, with the window on the repository
  click(middle(line(first_commit)))
  settle()
  @test page() isa K.CommitView
  @test page().hash == first_commit
  @test "The first commit" in texts(K.describe(page()))
  # A click on another commit shows that one in its place
  click(middle(line(second)))
  settle()
  @test page().hash == second
  K.go_back!(e)
  frames()
  @test page() isa K.RepoView
  @test e.buf.path == repo
  # The arrow at the top of the page goes back too
  click(middle(line(second)))
  settle()
  click(middle(page().parts[(:button, :close)]))
  frames()
  @test page() isa K.RepoView
end

@testset "a file's button shows the file as it is now" begin
  click(middle(line(second)))
  settle()
  v = page()
  s = G.shown(repo, second)
  ka = findfirst(f -> f.path == "src/a.jl", s.files)
  # A file that's gone has no button
  @test !haskey(v.parts, (:button, (:show, findfirst(f -> f.path == "gone.md", s.files))))
  b = v.parts[(:button, (:show, ka))]
  click(middle(b))
  @test e.buf.path == joinpath(repo, "src", "a.jl")
  # Going back shows the repository's page with the commit, as it was
  K.go_back!(e)
  settle()
  @test e.buf.path == repo
  @test page() isa K.CommitView
end

@testset "the old lines show beside the new lines, or under them" begin
  v = page()
  was = e.beside
  click(middle(v.parts[(:button, :beside)]))
  @test e.beside
  frames()
  s = G.shown(repo, second)
  c = v.views[findfirst(f -> f.path == "src/a.jl", s.files)]
  @test K.laid(c, 1).beside
  shot("beside")
  click(middle(v.parts[(:button, :under)]))
  @test !e.beside
  frames()
  @test !K.laid(c, 1).beside
  e.beside = was
end
