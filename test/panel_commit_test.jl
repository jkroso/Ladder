# Tests for the tick boxes of the changes in git's panel, and its Commit button.
# See "commits from git's panel" in main.jl. Run them with
# `julia -O0 --project=. test/panel_commit_test.jl`. They make a repository in a
# temporary folder with the Mac's own git, and click in a window that isn't on
# the screen. A script stands in for Claude. With `LADDER_SHOTS` set to a
# folder, they save a picture there.

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
const quiet = Dict("GIT_CONFIG_GLOBAL" => "/dev/null")
git(args...) = run(pipeline(setenv(`git -C $repo -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false $args`,
                                   merge(ENV, quiet)), stdout=devnull, stderr=devnull))
said(args...) = strip(read(setenv(`git -C $repo $args`, merge(ENV, quiet)), String))
mkpath(repo)
git("init", "-b", "main")
write(joinpath(repo, "Readme.md"), "# Work\n")
write(joinpath(repo, "a.md"), "A\n")
write(joinpath(repo, "b.md"), "B\n")
git("add", "-A")
git("commit", "-m", "Start")
write(joinpath(repo, "a.md"), "A, changed\n")
write(joinpath(repo, "b.md"), "B, changed\n")
write(joinpath(repo, "c.md"), "C, new\n")

# The script that stands in for Claude prints a message
const WRITES = (f = joinpath(dir, "message.sh"); write(f, "#!/bin/sh\ncat > /dev/null\necho 'Say what changed'\n"); chmod(f, 0o755); `/bin/sh $f`)
K.MESSAGE_COMMAND[] = WRITES
# A commit has this test's own name
const me = Dict("GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
                "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com")

const e = K.build_editor(joinpath(repo, "Readme.md"))
e.own = false   # Claude writes the message
const w = Window(e, size=(1100px, 700px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
"Draw until git has answered, and then what it said is on the screen"
settle() = (frames(2); G.wait!(); frames(2); G.wait!(); frames(2))
again() = (G.forget!(); settle())
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "panel-commit-$name.png"), w)
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = begin
  at(place)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1)
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2)
end
middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
tick(rel) = e.nodes[(:file_tick, repo, rel)]
button() = e.nodes[(:git_button, repo, :commit)]
"The files that git has for the next commit"
staged() = sort(split(said("diff", "--cached", "--name-only"), '\n', keepempty=false))
"Click the tick box of the file `rel`, and draw until git has answered"
tick!(rel) = (click(middle(tick(rel))); again())
"Click the Commit button, and draw until the commit is made. It gives what Ladder said under the top bar."
commit!() = begin
  withenv(me...) do
    click(middle(button()))
  end
  t = time()
  while haskey(e.nodes, :writing) && time() - t < 10
    withenv(() -> frames(1), me...)
    sleep(0.02)
  end
  again()
  first(e.nodes[:result])
end
"The files that the last commit changed"
last_files() = sort(split(said("show", "--name-only", "--format=", "HEAD"), '\n', keepempty=false))

K.show_beside!(e, repo)
settle()

@testset "each changed file has a tick box, and the Commit button commits all of them while none is ticked" begin
  @test all(rel -> rect(tick(rel)) !== nothing, ["a.md", "b.md", "c.md"])
  @test isempty(G.state(repo).staged)
  @test button().words == "Commit all" && !button().off
  # The tick box is at the left of the file's letter, and the button at the right of the heading
  row = e.nodes[(:git_panel, repo)].rows[(:change, "a.md")]
  @test K.num(rect(tick("a.md")).left) < K.num(rect(row).left) + 20
  @test K.num(rect(button()).left) > K.num(rect(row).left) + K.num(rect(row).width) / 2
end

@testset "a tick puts the file in the next commit, and a click on it again takes it out" begin
  tick!("a.md")
  @test staged() == ["a.md"]
  @test "a.md" in G.state(repo).staged
  @test button().words == "Commit 1"
  # A file that git doesn't keep yet goes in too, and comes out again as a file that git doesn't keep
  tick!("c.md")
  @test staged() == ["a.md", "c.md"] && button().words == "Commit 2"
  shot("ticked")
  tick!("c.md")
  @test staged() == ["a.md"] && button().words == "Commit 1"
  @test G.state(repo).changes["c.md"] == :new
  # A click on the box doesn't show the file's changes, as a click on the rest of its row does
  @test e.buf.path == repo
end

@testset "the Commit button commits the ticked files alone" begin
  @test commit!() == "Committed the ticked files: Say what changed"
  @test last_files() == ["a.md"]
  @test said("log", "-1", "--format=%s") == "Say what changed"
  @test sort(collect(keys(G.state(repo).changes))) == ["b.md", "c.md"]
  @test isempty(G.state(repo).staged) && button().words == "Commit all"
end

@testset "with no file ticked, the Commit button commits every changed file" begin
  @test commit!() == "Committed all changed files: Say what changed"
  @test last_files() == ["b.md", "c.md"]
  @test isempty(G.state(repo).changes)
  @test !haskey(e.nodes, (:git_button, repo, :commit)) || rect(button()) === nothing
end

@testset "a tick saves the window's changes to the file first, so the commit has them" begin
  page = joinpath(repo, "a.md")
  # The file has a change on the disk, so it's in the list, and more in a window
  write(page, "A, changed on the disk\n")
  o = K.build_editor(page)
  push!(K.editors, o)
  try
    K.type!(o, "Unsaved. ")
    @test K.dirty(o.buf)
    again()
    tick!("a.md")
    @test !K.dirty(o.buf)
    @test occursin("Unsaved.", said("show", ":a.md"))
  finally
    filter!(x -> x !== o, K.editors)
  end
  git("reset", "-q", "--hard")
end

@testset "with the setting on, the Commit button asks for your words" begin
  write(joinpath(repo, "b.md"), "B, changed again\n")
  again()
  tick!("b.md")
  e.own = true
  click(middle(button()))
  @test haskey(e.nodes, :palette) && K.palette_shows(e)
  e.own = false
  K.close_palette!(e)
  frames()
end
