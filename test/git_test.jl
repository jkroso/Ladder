# Tests for git.jl: what git knows about a folder. Run them with
# `julia -O0 --project=. test/git_test.jl`. They make a repository in a
# temporary folder, with the Mac's own git, and draw no window.

@use Test: @test, @testset
@use "../folders/git" => G

const dir = mktempdir()
const repo = joinpath(dir, "work")
mkpath(joinpath(repo, "src", "deep"))
git(args...) = run(pipeline(setenv(`git -C $repo -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false $args`,
                                   merge(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null"))), stdout=devnull, stderr=devnull))
"What git says now, and not what it said a moment ago"
now_state() = (G.forget!(); G.state(repo); G.wait!(); G.state(repo))

git("init", "-b", "main")
write(joinpath(repo, "one.md"), "# One\n")
write(joinpath(repo, "two words.md"), "# Two\n")
write(joinpath(repo, "src", "a.jl"), "a = 1\n")
write(joinpath(repo, "src", "deep", "b.jl"), "b = 2\n")
write(joinpath(repo, "gone.md"), "# Gone\n")
write(joinpath(repo, "old name.md"), "# A page with enough lines\n\nthat git sees it is the same page\nunder its new name\n")
git("add", "-A")
git("commit", "-m", "The first commit")

@testset "the top folder of a repository" begin
  @test G.top(repo) == repo
  @test G.top(joinpath(repo, "src", "deep")) == repo
  @test G.top(joinpath(repo, "src", "a.jl")) == repo
  @test G.istop(repo) && !G.istop(joinpath(repo, "src"))
  @test G.top(dir) == ""   # a temporary folder is in no repository
end

@testset "a repository with no changes" begin
  @test !G.state(repo).known   # git hasn't answered yet, and nothing waited for it
  @test G.wait!()
  s = G.state(repo)
  @test s.known && s.branch == "main"
  @test isempty(s.changes) && s.follows == "" && s.ahead == 0
  @test G.mark(s, "one.md") === nothing
end

@testset "each kind of change" begin
  write(joinpath(repo, "one.md"), "# One\n\nMore.\n")
  write(joinpath(repo, "src", "deep", "b.jl"), "b = 3\n")
  write(joinpath(repo, "new.md"), "# New\n")
  mkpath(joinpath(repo, "fresh"))
  write(joinpath(repo, "fresh", "inside.md"), "# Inside\n")
  write(joinpath(repo, "added.md"), "# Added\n")
  git("add", "added.md")
  rm(joinpath(repo, "gone.md"))
  git("mv", "old name.md", "new name.md")
  s = now_state()
  @test G.mark(s, "one.md") == :changed
  @test G.mark(s, "two words.md") === nothing
  @test G.mark(s, "new.md") == :new
  @test G.mark(s, "added.md") == :added
  @test G.mark(s, "gone.md") == :deleted
  @test G.mark(s, "new name.md") == :renamed
  @test !haskey(s.changes, "old name.md")
  # A folder that git doesn't keep yet is one entry, and what's in it is new too
  @test G.mark(s, "fresh") == :new
  @test G.mark(s, "fresh/inside.md") == :new
  # A folder with a change in it says so, at each level
  @test G.mark(s, "src") == :inside
  @test G.mark(s, "src/deep") == :inside
  @test G.mark(s, "src/deep/b.jl") == :changed
  @test G.mark(s, "src/a.jl") === nothing
  @test "added.md" in s.staged && "new name.md" in s.staged && !("one.md" in s.staged)
  @test first.(G.changed(s)) == ["added.md", "fresh", "gone.md", "new name.md", "new.md", "one.md", "src/deep/b.jl"]
end

@testset "the last commits" begin
  git("add", "-A")
  git("commit", "-m", "A second commit, with a longer line")
  G.forget!()
  G.commits(repo)
  @test G.wait!()
  found = G.commits(repo)
  @test [c.subject for c in found] == ["A second commit, with a longer line", "The first commit"]
  @test found[1].author == "Test" && length(found[1].hash) >= 7
  @test abs(found[1].time - time()) < 120
  # Each commit knows the commits that it was made on, by their whole hash, and the branches at it
  @test length(found[1].id) == 40 && startswith(found[1].id, found[1].hash)
  @test found[1].parents == [found[2].id] && isempty(found[2].parents)
  @test found[1].refs == ["refs/heads/main"] && found[1].head
  @test isempty(found[2].refs) && !found[2].head
  @test isempty(now_state().changes)
end

@testset "a branch that follows another" begin
  other = joinpath(dir, "copy")
  run(pipeline(`git clone $repo $other`, stdout=devnull, stderr=devnull))
  write(joinpath(other, "one.md"), "# One\n\nChanged in the copy.\n")
  run(pipeline(`git -C $other -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -am "Ahead"`, stdout=devnull, stderr=devnull))
  G.state(other)
  @test G.wait!()
  s = G.state(other)
  @test s.follows == "origin/main" && s.ahead == 1 && s.behind == 0
end

@testset "a commit with no branch" begin
  git("checkout", "--detach")
  s = now_state()
  @test length(s.branch) == 7 && s.branch != "(detached)"
  git("checkout", "main")
end

@testset "what git printed is read as it's written" begin
  s = G.read_status("# branch.oid abc\0# branch.head main\0# branch.upstream origin/main\0# branch.ab +2 -3\0" *
                    "1 .M N... 100644 100644 100644 aaa bbb a file.md\0" *
                    "2 R. N... 100644 100644 100644 aaa bbb R100 new.md\0old.md\0" *
                    "u UU N... 100644 100644 100644 100644 a b c both.md\0? dir/\0")
  @test (s.branch, s.follows, s.ahead, s.behind) == ("main", "origin/main", 2, 3)
  @test s.changes == Dict("a file.md" => :changed, "new.md" => :renamed, "both.md" => :clash, "dir" => :new)
end

@testset "how long ago" begin
  now = 1.0e9
  @test G.ago(now - 30, now) == "just now"
  @test G.ago(now - 600, now) == "10 min ago"
  @test G.ago(now - 7200, now) == "2 h ago"
  @test G.ago(now - 86400, now) == "yesterday"
  @test G.ago(now - 5 * 86400, now) == "5 days ago"
end

@testset "the branches and the tags that git names at a commit" begin
  @test G.read_refs("HEAD -> refs/heads/main, refs/remotes/origin/main, refs/remotes/origin/HEAD, tag: refs/tags/v1.0") ==
        (["refs/heads/main", "refs/remotes/origin/main", "refs/tags/v1.0"], true)
  @test G.read_refs("HEAD") == (String[], true)   # a commit with no branch, checked out
  @test G.read_refs("") == (String[], false)
  @test G.ref_kind.(["refs/heads/a/b", "refs/remotes/origin/main", "refs/tags/v1", "refs/stash"]) == [:branch, :remote, :tag, nothing]
  @test G.ref_name.(["refs/heads/a/b", "refs/remotes/origin/main", "refs/tags/v1"]) == ["a/b", "origin/main", "v1"]
end

@testset "the tree that commits make" begin
  c(id, parents...) = G.Commit(id=id, parents=collect(String, parents))
  # Commits one after another sit in one lane, with a line down from each to the next
  rows = G.tree([c("c", "b"), c("b", "a"), c("a")])
  @test [r.lane for r in rows] == [1, 1, 1] && [r.lanes for r in rows] == [1, 1, 1]
  @test isempty(rows[1].above) && rows[1].below == [(1, 1, 1)]
  @test rows[2].above == [(1, 1, 1)] && rows[2].below == [(1, 1, 1)]
  @test rows[3].above == [(1, 1, 1)] && isempty(rows[3].below)
  # A merge: a line goes from it to a second lane, and the two lanes meet again at the commit that both were made on
  rows = G.tree([c("m", "a", "b"), c("a", "r"), c("b", "r"), c("r")])
  @test [r.lane for r in rows] == [1, 1, 2, 1]
  @test [r.hue for r in rows] == [1, 1, 2, 1]
  @test rows[1].below == [(1, 1, 1), (1, 2, 2)]
  @test rows[2].above == [(2, 2, 2), (1, 1, 1)] && rows[2].below == [(2, 2, 2), (1, 1, 1)]
  @test rows[3].above == [(1, 1, 1), (2, 2, 2)] && rows[3].below == [(1, 1, 1), (2, 2, 2)]
  @test rows[4].above == [(1, 1, 1), (2, 1, 2)] && isempty(rows[4].below)
  @test all(r -> r.lanes == 2, rows)
  # Two branches that no commit merged: the second one starts a lane of its own
  rows = G.tree([c("x", "r"), c("y", "r"), c("r")])
  @test [r.lane for r in rows] == [1, 2, 1] && [r.hue for r in rows] == [1, 2, 1]
  @test isempty(rows[2].above[2:end]) && rows[2].above == [(1, 1, 1)]
  @test rows[3].above == [(1, 1, 1), (2, 1, 2)]
  # A lane that's free again is used by the next branch, so the tree stays narrow
  rows = G.tree([c("x", "r"), c("y", "r"), c("r", "q"), c("z", "q"), c("q")])
  @test [r.lane for r in rows] == [1, 2, 1, 2, 1] && rows[4].lanes == 2
  # A commit whose parent isn't in the list has a line down to the bottom of its row
  @test G.tree([c("a", "elsewhere")])[1].below == [(1, 1, 1)]
  @test G.tree(G.Commit[]) == G.TreeRow[]
end
