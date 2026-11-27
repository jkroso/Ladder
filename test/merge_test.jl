# Tests for merge.jl and agent/waiters.jl. Run them with `julia -O0 --project=. test/merge_test.jl`.

@use Test: @test, @testset
@use Random
@use "../merge" changes combine follow unified
@use "../agent/waiters" => Agent

"Text `a` with the changes `cs` that make it `b`"
apply(a, b, cs) = begin
  out = String[]
  i = 1
  for (x, y) in cs
    append!(out, a[i:first(x)-1]); append!(out, b[y])
    i = last(x) + 1
  end
  append!(out, a[i:end])
end

"How many lines the longest list of lines that `a` and `b` share has, worked out the slow way"
shared(a, b) = begin
  t = zeros(Int, length(a) + 1, length(b) + 1)
  for i in 1:length(a), j in 1:length(b)
    t[i+1, j+1] = a[i] == b[j] ? t[i, j] + 1 : max(t[i, j+1], t[i+1, j])
  end
  t[end, end]
end

letters(range, most) = [string(rand(range)) for _ in 1:rand(0:most)]

@testset "changes" begin
  @test changes(["a", "b"], ["a", "b"]) == []
  @test changes(["a", "b"], ["a", "c"]) == [(2:2, 2:2)]
  @test changes(String[], ["a"]) == [(1:0, 1:1)]
  @test changes(["a"], String[]) == [(1:1, 1:0)]
  @test changes(["a", "b", "c"], ["a", "x", "b", "c"]) == [(2:1, 2:2)]
  Random.seed!(1)
  for _ in 1:2000
    a, b = letters('a':'e', 14), letters('a':'e', 14)
    cs = changes(a, b)
    @test apply(a, b, cs) == b
    # It finds as many lines that stay as there are
    @test length(a) - sum(length(c[1]) for c in cs; init=0) == shared(a, b)
    @test all(i -> isempty(b) || 1 <= follow(cs, i) <= length(b), 1:length(a))
  end
end

@testset "follow" begin
  cs = changes(["a", "b", "c"], ["new", "a", "B", "c"])
  @test follow(cs, 1) == 2
  @test follow(cs, 2) == 3
  @test follow(cs, 3) == 4
end

@testset "combine" begin
  base = ["one", "two", "three", "four", "five"]
  mine = ["one", "TWO", "three", "four", "five"]
  @test combine(base, mine, ["one", "two", "three", "four", "FIVE", "six"]) == ["one", "TWO", "three", "four", "FIVE", "six"]
  # Both changed the same line
  @test combine(base, mine, ["one", "2", "three", "four", "five"]) == mine
  @test combine(base, mine, ["one", "2", "three", "four", "five"], keep=:theirs) == ["one", "2", "three", "four", "five"]
  # A line that I added beside a line that they changed
  @test combine(base, ["one", "note", "two", "three", "four", "five"], ["one", "2", "three", "four", "five"]) == ["one", "note", "2", "three", "four", "five"]
  @test combine(base, ["one", "two", "note", "three", "four", "five"], ["one", "2", "three", "four", "five"]) == ["one", "2", "note", "three", "four", "five"]
  # Both added a line at the same place
  @test combine(base, ["one", "a", "two", "three", "four", "five"], ["one", "b", "two", "three", "four", "five"]) == ["one", "a", "two", "three", "four", "five"]
  # They removed lines that I changed
  @test combine(base, ["one", "two", "3", "four", "five"], ["one", "five"]) == ["one", "two", "3", "four", "five"]
  @test combine(base, ["one", "two", "3", "four", "five"], ["one", "five"], keep=:theirs) == ["one", "five"]
  @test combine(["a"], ["a", "m"], ["z", "a"]) == ["z", "a", "m"]
  Random.seed!(2)
  edit(t) = begin
    t = copy(t)
    for _ in 1:rand(0:3)
      r = rand(1:3)
      if r == 1 || isempty(t)
        insert!(t, rand(1:length(t)+1), string(rand('p':'z')))
      elseif r == 2
        deleteat!(t, rand(1:length(t)))
      else
        t[rand(1:length(t))] = string(rand('p':'z'))
      end
    end
    t
  end
  for _ in 1:2000
    base = letters('a':'h', 12)
    mine, theirs = edit(base), edit(base)
    @test combine(base, mine, base) == mine
    @test combine(base, base, theirs) == theirs
    @test combine(base, mine, mine) == mine
    @test all(l -> l in mine || l in theirs, combine(base, mine, theirs))
  end
end

@testset "unified" begin
  @test unified(["a"], ["a"]) == ""
  @test unified(String[], ["x"]) == "@@ -0,0 +1,1 @@\n+x\n"
  # `patch` reads what it writes, and makes the new text from the old
  dir = mktempdir()
  old, new, diff, made = joinpath.(dir, ("old", "new", "diff", "made"))
  Random.seed!(3)
  for _ in 1:100
    a, b = [letters('a':'e', 30); "end"], [letters('a':'e', 30); "end"]
    a == b && continue
    write(old, join(a, "\n") * "\n")
    write(diff, "--- old\n+++ new\n" * unified(a, b))
    run(pipeline(`patch -s -o $made $old $diff`, stdout=devnull))
    @test read(made, String) == join(b, "\n") * "\n"
  end
  rm(dir, recursive=true)
end

@testset "an agent that waits" begin
  Agent.place[] = mktempdir()
  dir = Agent.folder()
  me = getpid()
  # This process stands in for a script that waits. 99999999 is a script that has stopped.
  foreach(n -> write(joinpath(dir, n), "/notes/plan.md\nClaude\n"), ["$me.wait", "99999999.wait", "99999999.sent"])
  write(joinpath(dir, "other.txt"), "")
  ws = Agent.waiters()
  @test length(ws) == 1
  @test (ws[1].page, ws[1].name) == ("/notes/plan.md", "Claude")
  @test sort(readdir(dir)) == sort(["$me.wait", "$me.seen", "other.txt"])
  @test Agent.waiting("/notes/plan.md") == ws
  @test isempty(Agent.waiting("/notes/other.md"))
  text = Agent.report("/notes/plan.md", ["- [ ] Redis", "End"], ["- [x] Redis", "End"], 2, "End")
  @test occursin("-- [ ] Redis\n+- [x] Redis\n", text)
  @test occursin("The user selected this text, at line 2:\n\nEnd\n", text)
  @test occursin("The user changed nothing in it.", Agent.report("/notes/plan.md", ["a"], ["a"]))
  Agent.send(ws[1], text)
  @test read(joinpath(dir, "$me.sent"), String) == text
  @test isempty(Agent.waiters())
  rm(dir, recursive=true)
  Agent.place[] = ""
end
