# Tests for the page skill, plugin/skills/page/SKILL.md. When Claude Code loads
# a skill, it runs a `!` and a code span as a shell command if the `!` starts a
# line or follows a space, even in a code block. One such example once made a
# file named 2e9USD and stopped the skill from loading. So the examples of sums
# in a line of text are in sums.md, which an agent reads with its own tools.
# Run them with `julia -O0 --project=. test/page_skill_test.jl`.

@use Test: @test, @testset

const folder = joinpath(@__DIR__, "..", "plugin", "skills", "page")
const skill = read(joinpath(folder, "SKILL.md"), String)
const sums = read(joinpath(folder, "sums.md"), String)

@testset "Claude Code runs no command when it loads the page skill" begin
  @test isempty(collect(eachmatch(r"(?:^|\s)!`"m, skill)))
  @test !occursin("```!", skill)
end

@testset "the skill sends an agent to the examples of sums" begin
  @test occursin("`sums.md`", skill)
  @test occursin("!`wall_area = l * h`", sums)
  @test occursin("!`farm_cost > 2e9USD", sums)
end

exit()
