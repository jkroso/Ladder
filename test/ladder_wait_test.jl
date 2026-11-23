# Tests for the name that `ladder wait`, in plugin/bin/ladder, gives Ladder: the
# name of the agent that waits, which Ladder's Nudge button shows as a logo.
# Run them with `julia -O0 --project=. test/ladder_wait_test.jl`. They open no
# window: each wait has a home of its own, where a stand-in for Ladder's file
# says that Ladder is open.

@use Test: @test, @testset

const ladder = joinpath(@__DIR__, "..", "plugin", "bin", "ladder")

"""
The name that `ladder wait` writes for Ladder, with `env` set and `args` after
the page, from a shell that has no CLAUDECODE or GROK_AGENT of its own.
"""
waits_as(env::Pair...; args=String[]) = begin
  home = mktempdir()
  agents = joinpath(home, "Library", "Application Support", "Ladder", "agents")
  mkpath(agents)
  page = joinpath(home, "plan.md")
  write(page, "# Plan\n")
  # A Ladder that's open has a file named by its process. This process stands in for it.
  touch(joinpath(agents, "$(getpid()).app"))
  clean = filter(p -> first(p) ∉ ("CLAUDECODE", "GROK_AGENT", "LADDER_AGENT"), collect(ENV))
  cmd = Cmd(`$ladder wait $page --timeout 2 $args`; env=[["$k=$v" for (k, v) in clean]; ["HOME=$home"]; ["$k=$v" for (k, v) in env]])
  p = run(pipeline(ignorestatus(cmd), stdout=devnull, stderr=devnull), wait=false)
  name = nothing
  for _ in 1:100
    f = filter(endswith(".wait"), readdir(agents))
    isempty(f) || (name = split(read(joinpath(agents, only(f)), String), '\n')[2]; break)
    sleep(0.02)
  end
  wait(p)
  @test p.exitcode == 2   # the time ran out, as no Ladder sent the page
  name
end

@testset "the name of the agent that waits" begin
  @test waits_as("GROK_AGENT" => "1") == "Grok"
  @test waits_as("CLAUDECODE" => "1") == "Claude"
  # A Grok that was started from inside Claude Code is Grok
  @test waits_as("CLAUDECODE" => "1", "GROK_AGENT" => "1") == "Grok"
  @test waits_as() == "the agent"
  # A name that's said wins
  @test waits_as("GROK_AGENT" => "1"; args=["--as", "Codex"]) == "Codex"
  @test waits_as("LADDER_AGENT" => "Gemini") == "Gemini"
end
