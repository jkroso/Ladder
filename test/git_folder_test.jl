# Tests for a folder with a git repository in it: the marks in the sidebar, the
# line over the sidebar's list, and the repository's page. See "a folder with a
# git repository in it" in main.jl, and git.jl. Run them with
# `julia -O0 --project=. test/git_folder_test.jl`. They make a repository in a
# temporary folder with the Mac's own git, and click in a window that isn't on
# the screen. With `LADDER_SHOTS` set to a folder, they save pictures there.

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
const hold = joinpath(dir, "code")
const repo = joinpath(hold, "work")
mkpath(joinpath(repo, "src", "deep"))
mkpath(joinpath(hold, "plain"))
git(args...) = run(pipeline(setenv(`git -C $repo -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false $args`,
                                   merge(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null"))), stdout=devnull, stderr=devnull))
git("init", "-b", "main")
write(joinpath(repo, "Readme.md"), "# Work\n\nWhat this is.\n")
write(joinpath(repo, "notes.md"), "# Notes\n")
write(joinpath(repo, "src", "a.jl"), "a = 1\n")
write(joinpath(repo, "src", "deep", "b.jl"), "b = 2\n")
git("add", "-A")
# A first line this long has to wrap in git's panel
git("commit", "-m", "The first commit, with a first line that is long enough to need a second line in git's panel")
write(joinpath(repo, "notes.md"), "# Notes\n\nMore.\n")
write(joinpath(repo, "src", "deep", "b.jl"), "b = 3\n")
write(joinpath(repo, "new.md"), "# New\n")

const e = K.build_editor(joinpath(repo, "Readme.md"))
e.panel = true   # the sidebar is open, with no slide
const w = Window(e, size=(1100px, 760px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
"Draw until git has answered, and then what it said is on the screen"
settle() = (frames(2); G.wait!(); frames(2))
"Ask git again now, as the window does after some seconds"
again() = (G.forget!(); settle())
settle()

shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "git-$name.png"), w)
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = begin
  at(place)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1)
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2)
end
middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
"The name in the trail at the top of the sidebar of the folder at `path`"
trail_name(path) = only(n for n in values(e.nodes) if n isa K.TrailName && n.path == path && rect(n) !== nothing)
"The words of every Text in the geometry `g`"
texts(g) = g isa K.Text ? [String(g.content)] : reduce(vcat, map(texts, try collect(g.children) catch; Any[] end), init=String[])
"The words of what follows the name of the folder or the file at `path` in the sidebar"
marks(path) = [m.children[1] isa K.Text ? m.children[1].content : "dot" for m in K.entry_marks(e, K.object(e, path))]

@testset "a folder with a .git in it is a folder that git keeps, and so is each folder in it" begin
  @test K.directory(e) isa K.GitDirectory
  @test K.object(e, joinpath(repo, "src")) isa K.GitDirectory
  @test K.FS.get(K.FSPath(joinpath(repo, "src", "deep"))) isa K.GitDirectory
  @test K.FS.get(K.FSPath(joinpath(hold, "plain"))) isa K.FS.Directory
  @test K.FS.get(K.FSPath(hold)) isa K.FS.Directory
end

@testset "a changed file has a letter in the sidebar, and a folder with one has a dot" begin
  @test marks(joinpath(repo, "notes.md")) == ["M"]
  @test marks(joinpath(repo, "new.md")) == ["U"]
  @test marks(joinpath(repo, "Readme.md")) == []
  @test marks(joinpath(repo, "src")) == ["dot"]
  shot("sidebar")
end

@testset "the sidebar has no line of git's over its list, and a saved file gets its letter" begin
  # Git's panel beside the repository's page says what that line said
  @test K.folder_view(e, K.directory(e)).bar === nothing
  @test !haskey(e.nodes, :git_bar)
  @test length(G.state(repo).changes) == 3
  # A file that's saved gets its letter when git is asked again
  write(joinpath(repo, "Readme.md"), "# Work\n\nWhat this is now.\n")
  again()
  @test marks(joinpath(repo, "Readme.md")) == ["M"]
  @test length(G.state(repo).changes) == 4
end

@testset "a click on the repository's name in the sidebar shows its page, with git's panel at the right" begin
  # The name is the last of the trail at the top of the sidebar, and a click on it shows the folder's page
  t = trail_name(repo)
  @test K.goes(t)
  click(middle(t))
  @test e.buf.path == repo
  @test e.folder == repo
  v = e.nodes[(:repo, repo)]
  @test v isa K.RepoView
  @test rect(v) !== nothing
  @test v.scroll.scrollbar_inset == e.scroll.scrollbar_inset == 0px   # its scrollbar is at the page's right edge, as the editor's is
  # The page has the folder's table, with a row for each folder and file of the top folder that the sidebar lists
  tb = e.nodes[(:folder_table, repo)]
  @test tb isa K.FolderTable && rect(tb) !== nothing
  @test sort!([basename(it.path) for it in tb.items]) == ["Readme.md", "new.md", "notes.md", "src"]
  # The line under its name says how big the repository is, with its .git folder, which the table leaves out.
  # git writes in .git while it's asked things, so the bytes are read until they're the same.
  bytes_in(path) = sum((lstat(joinpath(r, f)).size for (r, _, fs) in walkdir(path) for f in fs), init=0)
  sized() = (tb.read = 0.0; frames(1); tb.bytes == bytes_in(repo))
  t0 = time(); while !sized() && time() - t0 < 10; sleep(0.05) end
  @test sized() && tb.bytes > bytes_in(joinpath(repo, ".git"))
  @test K.holds_words(tb) == "1 folder  ·  3 files  ·  " * K.Zips.size_words(tb.bytes)
  @test sort!([k[2] for k in keys(tb.rows) if k[1] == :item]) == sort!(joinpath.(repo, ["Readme.md", "new.md", "notes.md", "src"]))
  # Each row has git's mark, as the sidebar has
  line(name) = tb.rows[(:item, joinpath(repo, name))]
  words(r) = reduce(vcat, map(texts, collect(r.parts)), init=String[])
  @test "M" in words(line("notes.md"))
  @test "U" in words(line("new.md"))
  # git's panel is at the right of the window, beside the list, and has what git says
  p = e.nodes[(:git_panel, repo)]
  @test p isa K.GitPanel
  r, q = rect(v), rect(p)
  @test q !== nothing
  @test K.num(q.left) >= K.num(r.left) + K.num(r.width) - 1
  @test K.num(q.left) + K.num(q.width) ≈ 1100 atol=1
  @test sort!([k[2] for k in keys(p.rows) if k[1] == :change]) == ["Readme.md", "new.md", "notes.md", "src/deep/b.jl"]
  # The long first line of the commit wraps, so it doesn't push the lines of the panel past its edge
  @test all(x -> K.num(rect(x).left) + K.num(rect(x).width) <= K.num(q.left) + K.num(q.width) + 0.5, values(p.rows))
  @test K.follow_words(G.state(repo)) == "Follows no other branch"
  # Each change has a tick box, which puts it in the next commit
  @test all(rel -> rect(e.nodes[(:file_tick, repo, rel)]) !== nothing, ["Readme.md", "new.md", "notes.md", "src/deep/b.jl"])
  # The file's name in the top bar is over the middle of the list, not of the space beside the sidebar
  t = rect(e.nodes[:title])
  @test K.num(t.left) + K.num(t.width) / 2 ≈ K.num(r.left) + K.num(r.width) / 2 atol=40
  shot("page")
end

@testset "a click on a row of the repository's page shows its file, or opens its folder" begin
  tb = e.nodes[(:folder_table, repo)]
  # The rows are in the order of their times, so a row moves when its folder's time is known. Wait for every time.
  t0 = time()
  while !(tb.read = 0.0; frames(1); all(it -> it.known && it.sized, tb.items)) && time() - t0 < 10
    sleep(0.05)
  end
  @test all(it -> it.known && it.sized, tb.items)
  frames()
  click(middle(tb.rows[(:item, joinpath(repo, "notes.md"))]))
  @test e.buf.path == joinpath(repo, "notes.md")
  # git's panel and its button are only beside the page of the repository
  @test K.right_view(e) === nothing
  @test K.right_part(e) == ()
  K.go_back!(e)
  frames()
  @test e.buf.path == repo
  @test K.right_part(e) != ()
  # A folder opens in the page, as its own table, and the sidebar lists it
  click(middle(tb.rows[(:item, joinpath(repo, "src"))]))
  src = joinpath(repo, "src")
  @test e.folder == src && e.buf.path == src
  @test e.nodes[(:folder_page, src)] isa K.FolderPage
  K.open_folder!(e, repo)
  settle()
  @test e.folder == repo && e.buf.path == repo
end

@testset "a click on a file in git's panel shows the file" begin
  p = e.nodes[(:git_panel, repo)]
  click(middle(p.rows[(:change, "notes.md")]))
  @test e.buf.path == joinpath(repo, "notes.md")
  # What changed in it is marked, as the diff button marks it, and the caret is at its first change
  @test K.diffing(e)
  d = K.diff_now(e)
  @test d !== nothing && length(d.changes) == 1
  @test e.buf.caret == (3, 0)   # "More." is the new line
  # The arrow that goes back shows the repository's page again
  K.go_back!(e)
  settle()
  @test e.buf.path == repo
  # A file that git doesn't keep yet is new from its first line
  click(middle(p.rows[(:change, "new.md")]))
  @test e.buf.path == joinpath(repo, "new.md")
  @test K.diffing(e) && e.buf.caret[1] == 1   # at the start of the heading's words, after its #
  K.go_back!(e)
  settle()
  # A change far down a long file is in sight
  write(joinpath(repo, "story.md"), join(["Line $i." for i in 1:300], "\n\n") * "\n")
  git("add", "story.md")
  git("commit", "-m", "A long page", "--", "story.md")
  write(joinpath(repo, "story.md"), join([i == 200 ? "Line 200, changed." : "Line $i." for i in 1:300], "\n\n") * "\n")
  again()
  click(middle(p.rows[(:change, "story.md")]))
  @test e.buf.path == joinpath(repo, "story.md")
  @test e.buf.caret == (399, 0)   # line 200 of the text is line 399 of the file, with an empty line after each
  frames()
  y = K.num(K.PAGE_TOP + K.item(e, 399).top - e.scroll.offset)
  @test 0 < y < 300   # near the top of the window, so the lines under it show too
  shot("file-changes")
  K.go_back!(e)
  git("checkout", "--", "story.md")   # the tests after this count the files with changes
  again()
  @test e.buf.path == repo
  # A file in a folder shows too, and the sidebar lists its folder
  click(middle(p.rows[(:change, "src/deep/b.jl")]))
  @test e.buf.path == joinpath(repo, "src", "deep", "b.jl")
  @test e.folder == joinpath(repo, "src", "deep")
  settle()
  @test K.directory(e) isa K.GitDirectory
  @test K.folder_view(e, K.directory(e)).bar === nothing   # nor over the list of a folder in the repository
  # The repository's name in the trail shows its page from there too, and the sidebar lists the repository
  click(middle(trail_name(repo)))
  @test e.buf.path == repo && e.folder == repo
  @test marks(joinpath(repo, "src", "deep", "b.jl")) == ["M"]
end

@testset "the button at the right end of the top bar hides git's panel, and shows it again" begin
  K.go_folder!(e, repo)
  K.show_beside!(e, repo)
  settle()
  b = e.nodes[:right_panel]
  @test rect(b) !== nothing
  @test K.num(rect(b).left) > 1000   # at the right end
  @test K.tip(b) == "Hide git's panel"
  wide = K.num(rect(e.nodes[(:repo, repo)]).width)
  click(middle(b))
  @test !e.right
  sleep(K.SLIDE_TIME)
  frames()
  @test K.right_panel(e) == ()
  @test rect(e.nodes[(:git_panel, repo)]) === nothing
  # The list has the room that the panel had
  @test K.num(rect(e.nodes[(:repo, repo)]).width) > wide + 200
  @test K.tip(b) == "Show git's panel"
  shot("panel-hidden")
  # The palette has the command too
  @test K.works_here(e, Val(:right_panel))
  click(middle(b))
  @test e.right
  sleep(K.SLIDE_TIME)
  frames()
  @test rect(e.nodes[(:git_panel, repo)]) !== nothing
end

@testset "the settings keep whether git's panel shows" begin
  f = K.Editor()
  write(K.settings_file(), "right=false\n")
  K.load_settings!(f)
  @test !f.right
  write(K.settings_file(), "right=true\n")
  K.load_settings!(f)
  @test f.right
  rm(K.settings_file())
end

@testset "a repository in the list of the folder that it's in has its branch and its changes" begin
  K.go_folder!(e, hold)
  settle()
  @test marks(repo) == ["main", "4"]
  @test marks(joinpath(hold, "plain")) == []
  shot("list")
end

@testset "a window that's opened on a repository shows its first page of text" begin
  other = K.build_editor(repo)
  @test other.buf.path == joinpath(repo, "new.md")
  @test K.directory(other) isa K.GitDirectory
end

@testset "a page of its own gives a folder in a repository another kind" begin
  desk = joinpath(repo, "desk")
  mkpath(desk)
  write(joinpath(desk, ".ladder"), "```julia\nLadder.DesktopDirectory\n```\n")
  K.folder_pages!(desk)
  @test Base.invokelatest(K.FS.get, K.FSPath(desk)) isa K.DesktopDirectory
end

close(w)
