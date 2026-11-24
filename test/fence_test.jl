# Tests for the fences of code blocks in markdown.jl: which line opens a block,
# and which line closes it. Run them with `julia -O0 --project=. test/fence_test.jl`.
# They open no window.

@use Test: @test, @testset
@use "../markdown" Kind classify

kinds(lines) = [k.kind for k in classify(lines)]
langs(lines) = [k.lang for k in classify(lines)]

@testset "a fence of three closes a fence of three" begin
  @test kinds(["```julia", "x = 1", "```", "text"]) == [Kind.fence, Kind.code, Kind.fence, Kind.paragraph]
  @test [k.level for k in classify(["```julia", "x = 1", "```"])] == [0, 0, 1]
  @test langs(["```julia", "x = 1", "```"]) == ["julia", "julia", ""]
  @test kinds(["~~~", "x", "~~~"]) == [Kind.fence, Kind.code, Kind.fence]
end

@testset "a fence of four holds a fence of three, as on GitHub" begin
  lines = ["````", "```progress", "done: 0.7", "```", "````", "", "This block is for `progress.jl`."]
  @test kinds(lines) == [Kind.fence, Kind.code, Kind.code, Kind.code, Kind.fence, Kind.blank, Kind.paragraph]
  @test [k.level for k in classify(lines)[[1, 5]]] == [0, 1]
  # Its language is the one after the four backticks
  @test langs(["````markdown", "```julia", "```", "````"]) == ["markdown", "markdown", "markdown", ""]
  # More backticks close it too
  @test kinds(["````", "x", "`````", "text"]) == [Kind.fence, Kind.code, Kind.fence, Kind.paragraph]
end

@testset "only a fence like the one that opened the block closes it" begin
  # A line with a language opens a block, and never closes one
  @test kinds(["```", "```julia", "```"]) == [Kind.fence, Kind.code, Kind.fence]
  # Tildes don't close backticks, and backticks don't close tildes
  @test kinds(["```", "~~~", "```"]) == [Kind.fence, Kind.code, Kind.fence]
  @test kinds(["~~~", "```", "~~~"]) == [Kind.fence, Kind.code, Kind.fence]
  # Spaces after the fence still close it
  @test kinds(["```", "x", "```  ", "text"]) == [Kind.fence, Kind.code, Kind.fence, Kind.paragraph]
end

@testset "a page of the Readme's kind" begin
  lines = ["A folder's page:", "", "````", "This disk is a media library.", "", "```julia",
           "@use \"github.com/jkroso/Media.lad\" => Media", "```", "````", "", "- Ladder runs the page."]
  @test kinds(lines) == [Kind.paragraph, Kind.blank, Kind.fence, Kind.code, Kind.code, Kind.code,
                         Kind.code, Kind.code, Kind.fence, Kind.blank, Kind.bullet]
end
