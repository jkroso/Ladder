# Tests for the Pull and Push buttons of git's panel. See "push and pull" in
# main.jl. Run them with `julia -O0 --project=. test/push_pull_test.jl`. They
# make a repository that stands in for GitHub (a bare one), two copies of it in
# a temporary folder, with the Mac's own git, and click in a window that isn't
# on the screen. With `LADDER_SHOTS` set to a folder, they save a picture there.

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
const hub = joinpath(dir, "hub.git")
const repo = joinpath(dir, "work")
const other = joinpath(dir, "other")
const quiet = Dict("GIT_CONFIG_GLOBAL" => "/dev/null")
git(at, args...) = run(pipeline(setenv(`git -C $at -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false $args`,
                                       merge(ENV, quiet)), stdout=devnull, stderr=devnull))
commit(at, message) = git(at, "commit", "--allow-empty", "-m", message)
head(at, ref="HEAD") = strip(read(setenv(`git -C $at rev-parse $ref`, merge(ENV, quiet)), String))

run(pipeline(`git init --bare -b main $hub`, stdout=devnull, stderr=devnull))
mkpath(repo)
git(repo, "init", "-b", "main")
write(joinpath(repo, "Readme.md"), "# Work\n")
git(repo, "add", "-A")
commit(repo, "Start")
git(repo, "remote", "add", "origin", hub)
git(repo, "push", "-u", "origin", "main")
run(pipeline(`git clone $hub $other`, stdout=devnull, stderr=devnull))

const e = K.build_editor(joinpath(repo, "Readme.md"))
const w = Window(e, size=(1100px, 700px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
"Draw until git has answered, and then what it said is on the screen"
settle() = (frames(2); G.wait!(); frames(2); G.wait!(); frames(2))
"Ask git again now, as the window does after some seconds"
again() = (G.forget!(); settle())
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "push-pull-$name.png"), w)
at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
click(place) = begin
  at(place)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1)
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2)
end
middle(node) = (r = rect(node); (K.num(r.left) + K.num(r.width) / 2, K.num(r.top) + K.num(r.height) / 2))
button(what) = e.nodes[(:git_button, repo, what)]
"Draw until git has finished. It gives what Ladder said under the top bar."
finish() = begin
  t = time()
  while !isempty(K.GIT_RUNS) && time() - t < 30
    frames(1)
    sleep(0.05)
  end
  settle()
  first(e.nodes[:result])
end
"Click the Pull or the Push button, and draw until git has finished. It gives what Ladder said under the top bar."
press(what) = (click(middle(button(what))); finish())
# A merge makes a commit, as this test's own name
const me = Dict("GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
                "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com")
arrow() = e.nodes[(:pull_more, repo)]
"Click the arrow at the right of Pull, then the row of the way `way` in its list, and draw until git has finished"
join_by(way) = begin
  click(middle(arrow()))
  K.pull_list_open(e) || return "the list didn't open"
  withenv(me...) do
    click(middle(e.nodes[(:pull_way, repo, way)]))
  end
  finish()
end
"Write `text` into the file `name` of the copy at `at`, and commit it"
change(at, name, text) = (write(joinpath(at, name), text); git(at, "add", "-A"); commit(at, "Change $name in $(basename(at))"))
"Make each branch have a commit that the other hasn't, with a change to `name` in each, and let the window know"
part!(name="here.md", there="there.md") = begin
  git(other, "pull", "--ff-only")
  change(other, there, "There $(time())\n")
  git(other, "push")
  change(repo, name, "Here $(time())\n")
  git(repo, "fetch")
  again()
end

"""
The names of the commands that the palette of the window `o` lists. The
palette closes again at once, with no slide, so a click after it isn't lost.
"""
listed(o) = begin
  K.open_palette!(o)
  found = [K.palette_name(c.name) for c in K.palette(o).listed]
  K.close_palette!(o)
  K.palette(o).moved = 0.0
  o === e && frames(1)
  found
end

K.show_beside!(e, repo)
settle()

@testset "git's panel has a Pull and a Push button at the right of the branch's name" begin
  @test rect(button(:pull)) !== nothing && rect(button(:push)) !== nothing
  @test button(:pull).words == "Pull" && button(:push).words == "Push"
  @test !button(:pull).off && !button(:push).off
  shot("buttons")
end

@testset "Push sends the branch's new commits to the branch that it follows" begin
  commit(repo, "Work here")
  again()
  @test G.state(repo).ahead == 1
  @test button(:push).words == "Push 1" && button(:pull).words == "Pull"
  @test press(:push) == "Pushed main to origin/main."
  @test head(hub, "main") == head(repo)
  @test G.state(repo).ahead == 0 && button(:push).words == "Push"
  # The buttons have the numbers, so the line under the branch's name has none
  commit(repo, "Work here too")
  again()
  @test button(:push).words == "Push 1" && K.follow_words(G.state(repo)) == "Follows origin/main"
  @test press(:push) == "Pushed main to origin/main."
  @test press(:push) == "origin/main already has every commit of main."
end

@testset "Pull brings the new commits of the branch that it follows" begin
  git(other, "pull", "--ff-only")
  commit(other, "Work there")
  git(other, "push")
  # The window knows of the new commit once git has fetched it
  @test button(:pull).words == "Pull"
  git(repo, "fetch")
  again()
  @test button(:pull).words == "Pull 1"
  @test press(:pull) == "Pulled the new commits of origin/main into main."
  @test head(repo) == head(other) && button(:pull).words == "Pull"
  @test press(:pull) == "main already has every commit of origin/main."
end

@testset "when each branch has commits that the other hasn't, git neither pulls nor pushes" begin
  commit(other, "More there")
  git(other, "push")
  commit(repo, "More here")
  mine = head(repo)
  @test press(:pull) == "main and origin/main each have commits that the other hasn't, so git didn't pull. To join them, click the arrow at the right of Pull, or run Merge or Rebase in the command palette."
  @test button(:pull).words == "Pull 1" && button(:push).words == "Push 1"
  @test press(:push) == "origin/main has commits that main hasn't got, so git didn't push. Pull them first."
  @test head(repo) == mine && head(hub, "main") == head(other)
  git(repo, "reset", "--hard", "origin/main")
end

@testset "while the branches have gone apart, an arrow at the right of Pull shows the ways to join them" begin
  again()
  @test !haskey(e.nodes, (:pull_more, repo)) || rect(arrow()) === nothing
  part!()
  @test K.diverged(G.state(repo))
  @test rect(arrow()) !== nothing
  # The arrow is beside Pull, and Push is after it
  @test K.num(rect(arrow()).left) > K.num(rect(button(:pull)).left) && K.num(rect(button(:push)).left) > K.num(rect(arrow()).left)
  # A click on Pull shows the list too, as git can't pull by itself
  click(middle(button(:pull)))
  @test K.pull_list_open(e) && isempty(K.GIT_RUNS)
  rows = [e.nodes[(:pull_way, repo, w)] for w in K.PULL_WAYS]
  @test all(r -> rect(r) !== nothing, rows)
  @test K.pull_way_words(rows[1]) == ("Merge origin/main into main", "adds a commit")
  @test K.pull_way_words(rows[2]) == ("Rebase main onto origin/main", "rewrites 1 commit")
  @test K.apart_words(G.state(repo)) == "main has 1 commit that origin/main hasn't got, and origin/main has 1 that main hasn't got."
  shot("ways")
  # A click on the arrow again takes the list away
  click(middle(arrow()))
  @test !K.pull_list_open(e)
end

@testset "Merge joins the other branch's commits to the branch's with a new commit" begin
  @test join_by(:merge) == "Merged origin/main into main."
  @test length(split(strip(read(`git -C $repo log -1 --format=%P`, String)))) == 2
  @test isfile(joinpath(repo, "there.md")) && isfile(joinpath(repo, "here.md"))
  @test !K.diverged(G.state(repo)) && rect(arrow()) === nothing
  @test press(:push) == "Pushed main to origin/main."
end

@testset "Rebase makes the branch's commits again, after the other branch's" begin
  part!("here2.md", "there2.md")
  @test join_by(:rebase) == "Rebased main onto origin/main."
  @test head(repo, "HEAD~1") == head(repo, "origin/main")
  @test length(split(strip(read(`git -C $repo log -1 --format=%P`, String)))) == 1
  @test isfile(joinpath(repo, "there2.md")) && isfile(joinpath(repo, "here2.md"))
  @test press(:push) == "Pushed main to origin/main."
end

@testset "git doesn't rebase while a file has a change that isn't committed" begin
  part!("here3.md", "there3.md")
  mine = head(repo)
  write(joinpath(repo, "Readme.md"), "# Work, not committed\n")
  @test join_by(:rebase) == "git doesn't rebase while files have changes that aren't committed, so nothing changed. Commit them, or merge."
  @test head(repo) == mine && read(joinpath(repo, "Readme.md"), String) == "# Work, not committed\n"
  git(repo, "checkout", "--", "Readme.md")
end

@testset "when both branches change the same lines, Ladder undoes the merge or the rebase" begin
  git(repo, "reset", "--hard", "origin/main")
  part!("same.md", "same.md")
  mine = head(repo)
  ours = read(joinpath(repo, "same.md"), String)
  @test join_by(:merge) == "main and origin/main change the same lines of same.md, so Ladder undid the merge. Nothing changed."
  @test head(repo) == mine && !isfile(joinpath(repo, ".git", "MERGE_HEAD")) && read(joinpath(repo, "same.md"), String) == ours
  @test join_by(:rebase) == "main and origin/main change the same lines of same.md, so Ladder undid the rebase. Nothing changed."
  @test head(repo) == mine && !isdir(joinpath(repo, ".git", "rebase-merge")) && read(joinpath(repo, "same.md"), String) == ours
  @test isempty(G.state(repo).changes)
  git(repo, "reset", "--hard", "origin/main")
end

@testset "a branch that follows none has no Pull, and Push sends it to origin and follows it there" begin
  git(repo, "checkout", "-b", "side")
  commit(repo, "On the side")
  again()
  @test isempty(G.state(repo).follows)
  @test button(:pull).off
  @test !("Pull" in listed(e)) && "Push" in listed(e)
  @test press(:push) == "Pushed side to origin."
  @test head(hub, "side") == head(repo)
  @test G.state(repo).follows == "origin/side"
  @test !button(:pull).off
end

@testset "a button says what it's doing while git runs, and the other does nothing then" begin
  K.GIT_RUNS[repo] = (what=:push, run=(run(`sleep 5`, wait=false), IOBuffer()), e=e, since=time(), branch="side", follows="origin/side")
  frames(2)
  @test button(:push).words == "Pushing…" && button(:push).off && button(:pull).off
  p = first(K.GIT_RUNS[repo].run)
  kill(p)
  wait(p)
  frames(2)
  @test isempty(K.GIT_RUNS)
  @test button(:push).words == "Push" && !button(:push).off
end

# --- the same from the command palette ---

"A window that isn't on the screen, on the file at `path`"
window_on(path) = (o = K.build_editor(path); v = Window(o, size=(900px, 600px)); foreach(_ -> Base.invokelatest(frame, v), 1:2); o)
"Run the palette's command called `name`. It gives the words under the top bar while git runs."
run_command(name) = (K.open_palette!(e, K.COMMANDS[name]); first(e.nodes[:result]))

@testset "the command palette has Push and Pull in a repository, and not outside one" begin
  again()
  @test "Push" in listed(e) && "Pull" in listed(e)
  @test !("Merge" in listed(e)) && !("Rebase" in listed(e))
  # A file in the repository has them too, where git's panel doesn't show
  @test "Push" in listed(window_on(joinpath(repo, "Readme.md")))
  write(joinpath(dir, "loose.md"), "# Not in a repository\n")
  outside = listed(window_on(joinpath(dir, "loose.md")))
  @test !("Push" in outside) && !("Pull" in outside) && "Theme" in outside
end

@testset "Push and Pull from the palette say what git does, and then what came of it" begin
  commit(repo, "From the palette")
  again()
  @test run_command(:push) == "Pushing side to origin/side…"
  @test e.popup != :commands   # the palette closed when the command ran
  @test finish() == "Pushed side to origin/side."
  @test head(hub, "side") == head(repo)
  git(other, "fetch")
  git(other, "checkout", "side")
  commit(other, "Side there")
  git(other, "push")
  git(repo, "fetch")
  again()
  @test run_command(:pull) == "Pulling the new commits of origin/side into side…"
  @test finish() == "Pulled the new commits of origin/side into side."
  @test head(repo) == head(other)
end

@testset "while the branches have gone apart, the palette has Merge and Rebase" begin
  part!("palette-here.md", "palette-there.md")
  @test K.diverged(G.state(repo))
  @test "Merge" in listed(e) && "Rebase" in listed(e)
  @test run_command(:pull) == "Pulling the new commits of origin/side into side…"
  @test finish() == "side and origin/side each have commits that the other hasn't, so git didn't pull. To join them, click the arrow at the right of Pull, or run Merge or Rebase in the command palette."
  withenv(me...) do
    @test run_command(:merge) == "Merging origin/side into side…"
    @test finish() == "Merged origin/side into side."
  end
  @test length(split(strip(read(`git -C $repo log -1 --format=%P`, String)))) == 2
  @test !("Merge" in listed(e))
end

@testset "the palette doesn't start git while it runs in the repository" begin
  K.GIT_RUNS[repo] = (what=:push, run=(run(`sleep 5`, wait=false), IOBuffer()), e=e, since=time(), branch="side", follows="origin/side")
  K.open_palette!(e, K.COMMANDS[:pull])
  @test K.palette(e).fault == "Command failed: git hasn't finished the push that it's doing in this repository"
  @test K.GIT_RUNS[repo].what == :push
  K.close_palette!(e)
  p = first(K.GIT_RUNS[repo].run)
  kill(p)
  wait(p)
  frames(2)
  @test isempty(K.GIT_RUNS)
end
