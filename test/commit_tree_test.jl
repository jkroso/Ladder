# Tests for the tree of commits in git's panel: each commit's line has a dot in
# the lane of its branch, and the lines to the commits that it was made on. See
# `CommitLine` in main.jl, and `tree` in git.jl. Run them with
# `julia -O0 --project=. test/commit_tree_test.jl`. They make a repository with a
# branch, a merge, a tag and a branch of another copy, in a temporary folder with
# the Mac's own git, and draw a window that isn't on the screen. With
# `LADDER_SHOTS` set to a folder, they save a picture there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window MouseMove onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect onscroll
@use GeometryBasics: Vec2
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./drive" drive

const px = K.px
const G = K.Git

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const repo = joinpath(dir, "work")
mkpath(repo)
# Each commit is a minute after the one before, so git lists them in a known order
const minute = Ref(0)
git(args...) = run(pipeline(setenv(`git -C $repo -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false $args`,
                                   merge(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null",
                                                   "GIT_AUTHOR_DATE" => "2026-11-01T10:$(lpad(minute[], 2, '0')):00+1100",
                                                   "GIT_COMMITTER_DATE" => "2026-11-01T10:$(lpad(minute[], 2, '0')):00+1100"))),
                           stdout=devnull, stderr=devnull))
commit(message) = (minute[] += 1; git("commit", "--allow-empty", "-m", message))
hash(ref) = strip(read(`git -C $repo rev-parse --short $ref`, String))

git("init", "-b", "main")
write(joinpath(repo, "Readme.md"), "# Work\n")
git("add", "-A")
commit("Start")
git("tag", "v1")
git("checkout", "-b", "side")
commit("Work on the side branch, with a first line long enough to wrap in the panel")
git("checkout", "main")
commit("Work on main")
# A branch of another copy, as `git fetch` leaves one
git("update-ref", "refs/remotes/origin/main", "HEAD")
minute[] += 1
git("merge", "--no-ff", "-m", "Merge the side branch", "side")

const start, side, work, merged = hash("v1"), hash("side"), hash("main~1"), hash("main")

const e = K.build_editor(joinpath(repo, "Readme.md"))
e.panel = true   # the sidebar is open, with no slide
const w = Window(e, size=(1100px, 700px))
const (; frames, shot) = drive(w, frames=3, latest=true)
"Draw until git has answered, and then what it said is on the screen"
settle() = (frames(2); G.wait!(); frames(2); G.wait!(); frames(2))
"The words of every Text in the geometry `g`"
texts(g) = g isa K.Text ? [String(g.content)] : reduce(vcat, map(texts, try collect(g.children) catch; Any[] end), init=String[])
"The line of git's panel for the commit `hash`"
line(hash) = e.nodes[(:commit_line, repo, hash)]

K.show_beside!(e, repo)
settle()

@testset "git lists the commits of every branch, each before the commits it was made on" begin
  @test [c.hash for c in G.commits(repo, 30)] == [merged, work, side, start]
  @test [c.subject for c in G.commits(repo, 30)][[1, 4]] == ["Merge the side branch", "Start"]
end

@testset "each commit's line has its place in the tree" begin
  ls = line.([merged, work, side, start])
  @test all(l -> rect(l) !== nothing, ls)
  @test all(l -> l.lanes == 2, ls)
  @test all(l -> l.branch == "main", ls)
  # The merge has a line down its own lane and one across to the side branch's lane
  m = ls[1].row
  @test m.lane == 1 && isempty(m.above) && m.below == [(1, 1, 1), (1, 2, 2)]
  @test length(ls[1].commit.parents) == 2 && ls[1].commit.head
  # The side branch's commit is in the second lane, in the second colour
  @test ls[3].row.lane == 2 && ls[3].row.hue == 2
  # The first commit is where the two lanes meet again
  @test ls[4].row.lane == 1 && ls[4].row.above == [(1, 1, 1), (2, 1, 2)] && isempty(ls[4].row.below)
end

@testset "the branches and the tags at a commit are over its first line" begin
  @test "main" in texts(K.describe(line(merged)))
  @test "origin/main" in texts(K.describe(line(work)))
  @test "side" in texts(K.describe(line(side)))
  @test "v1" in texts(K.describe(line(start)))
  @test length(collect(K.describe(line(merged)).children)) == 3
  shot("tree-panel")
end

@testset "a repository whose commits are one after another has a tree of one lane" begin
  plain = joinpath(dir, "plain")
  mkpath(plain)
  run(pipeline(`git -C $plain init -b main`, stdout=devnull, stderr=devnull))
  for m in ("One", "Two")
    run(pipeline(setenv(`git -C $plain -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit --allow-empty -m $m`,
                        merge(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null"))), stdout=devnull, stderr=devnull))
  end
  K.show_beside!(e, plain)
  settle()
  ls = [n for n in values(e.nodes) if n isa K.CommitLine && n.root == plain]
  @test length(ls) == 2
  @test all(l -> l.lanes == 1 && l.row.lane == 1, ls)
  # A commit with no branch or tag at it has only its first line and the line under it
  one = only(l for l in ls if l.commit.subject == "One")
  @test isempty(one.commit.refs) && length(collect(K.describe(one).children)) == 2
  shot("tree-one-lane")
end

@testset "the last commits have a scroll of their own, so the panel needs none" begin
  long = joinpath(dir, "long")
  mkpath(long)
  run(pipeline(`git -C $long init -b main`, stdout=devnull, stderr=devnull))
  for k in 1:40
    run(pipeline(setenv(`git -C $long -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit --allow-empty -m "Commit number $k, with words enough to wrap onto a second line in the panel"`,
                        merge(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null"))), stdout=devnull, stderr=devnull))
  end
  K.show_beside!(e, long)
  settle()
  p = e.nodes[(:git_panel, long)]
  "The scroll of the last commits, as the last frame laid it out"
  log_of(r) = begin
    r.from isa K.Scroll && r.from.name == "Log" && return r
    for c in (try r.children catch; () end)
      found = log_of(c)
      found === nothing || return found
    end
    nothing
  end
  newest = e.nodes[(:commit_line, long, strip(read(`git -C $long rev-parse --short HEAD`, String)))]
  oldest = e.nodes[(:commit_line, long, last(G.commits(long, 30)).hash)]
  # The panel has nothing to scroll: the commits fill the rest of its height, and go on past the window's foot
  @test p.scroll.content_height <= p.scroll.viewport + 0.5px
  # It goes down to the foot of the window, less the panel's padding
  @test K.num(log_of(rect(p)).top) + K.num(log_of(rect(p)).height) ≈ 700 atol=8
  @test K.num(rect(newest).top) < 400 && K.num(rect(oldest).top) > 700
  shot("tree-long")
  # The wheel over the commits scrolls them, and the parts over them stay
  top = K.num(rect(newest).top)
  x, y = K.num(rect(newest).left) + 40, K.num(rect(newest).top) + 10
  w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1)
  onscroll(w, Vec2{px}(0px, -4px), false)
  frames(2)
  @test K.num(rect(newest).top) < top - 50
  @test p.scroll.offset == 0px
  # With so many changes that the commits would have less than their least room, the panel scrolls too
  foreach(k -> write(joinpath(long, "new-$k.md"), "New\n"), 1:20)
  G.forget!()
  settle()
  @test p.scroll.content_height > p.scroll.viewport
  # The commits keep their least room, under the changes
  @test log_of(rect(p)).height == K.LOG_LEAST
end
