# Tests for signature.jl. Run them with `julia -O0 --project=. test/signature_test.jl`.

@use Test: @test, @testset
@use "../blocks/signature" => S
@use Dates: DateTime

const BLOCK = ["name: Sam Lee", "signed: 2026-11-18 09:14", "pen 52,80 60,71.5 74,90", "pen 90,62 96,88"]
const NOW = DateTime(2026, 11, 18, 9, 14, 37)

@testset "reading and writing" begin
  s = S.signature(BLOCK)
  @test s.name == "Sam Lee" && s.when == DateTime(2026, 11, 18, 9, 14) && S.issigned(s)
  @test s.strokes == [[(52.0, 80.0), (60.0, 71.5), (74.0, 90.0)], [(90.0, 62.0), (96.0, 88.0)]] && isempty(s.other)
  @test S.written(s) == BLOCK && S.written(S.signature(S.written(s))) == BLOCK
  # The lines can be in any order, with spaces round them, and the keys in capitals
  t = S.signature(["  pen 90,62 96,88", "", "Signed : 2026-11-18 09:14", "NAME:   Sam Lee  "])
  @test S.written(t) == ["name: Sam Lee", "signed: 2026-11-18 09:14", "pen 90,62 96,88"]
  # A block with nothing in it isn't signed, and writes no lines
  @test !S.issigned(S.signature(String[])) && isempty(S.written(S.Signature())) && S.written(S.Signature()) isa Vector{String}
  # A name with nothing after it is no name
  @test S.signature(["name:"]).name == "" && isempty(S.written(S.signature(["name:  "])))
end

@testset "lines that are wrong" begin
  wrong = ["signed: yesterday", "signed: 2026-13-45 09:14", "pen 1,2", "pen 1,2 x", "pen", "box 1,1 2,2", "named: Sam", "pen 1,2 " * "9"^400 * ",3"]
  s = S.signature(wrong)
  # None of them signs the block or names anyone, and each one is kept as it is
  @test !S.issigned(s) && s.when === nothing && s.name == "" && s.other == wrong && S.written(s) == wrong
  # The lines that are right are read from among them
  s = S.signature(["what", BLOCK..., "pen 1,2"])
  @test length(s.strokes) == 2 && s.name == "Sam Lee" && S.written(s) == [BLOCK..., "what", "pen 1,2"]
  # Strokes with no day are a signature all the same
  s = S.signature(["pen 1,2 3,4"])
  @test S.issigned(s) && S.caption(s) == "Signed"
end

@testset "signing" begin
  s = S.signature(["name: Sam Lee"])
  # A click by mistake doesn't sign the page
  @test !S.sign!(s, [(50.0, 60.0)], NOW) && !S.sign!(s, S.Place[], NOW) && !S.issigned(s) && s.when === nothing
  # The first stroke writes the day and the time, to the minute
  @test S.sign!(s, [(50.0, 60.0), (60.0, 80.0), (70.0, 60.0)], NOW)
  @test S.written(s) == ["name: Sam Lee", "signed: 2026-11-18 09:14", "pen 50,60 60,80 70,60"]
  # A later stroke leaves the day as it is. One place alone is a dot now.
  @test S.sign!(s, [(80.0, 40.0)], DateTime(2026, 11, 19, 10, 0)) && S.sign!(s, [(90.0, 60.0), (95.5, 70.26)], DateTime(2026, 11, 19, 10, 0))
  @test S.written(s)[2:end] == ["signed: 2026-11-18 09:14", "pen 50,60 60,80 70,60", "pen 80,40 80,40", "pen 90,60 95.5,70.3"]
  # The places that are on the line between their neighbours are left out
  s = S.Signature()
  S.sign!(s, [(Float64(x), 50.0) for x in 10:60], NOW)
  @test s.strokes == [[(10.0, 50.0), (60.0, 50.0)]]
  # A stroke of a block whose day couldn't be read writes the day, and the line that was wrong goes
  s = S.signature(["signed: yesterday", "note"])
  S.sign!(s, [(1.0, 1.0), (9.0, 9.0)], NOW)
  @test S.written(s) == ["signed: 2026-11-18 09:14", "pen 1,1 9,9", "note"]
  # So does a stroke of a block that had strokes and no day
  s = S.signature(["pen 1,2 3,4"])
  S.sign!(s, [(1.0, 1.0), (9.0, 9.0)], NOW)
  @test s.when == DateTime(2026, 11, 18, 9, 14) && length(s.strokes) == 2
end

@testset "clearing" begin
  s = S.signature([BLOCK..., "signed: soon", "note"])
  S.clear!(s)
  @test !S.issigned(s) && S.written(s) == ["name: Sam Lee", "note"]
end

@testset "what it says under the signature" begin
  s = S.signature(BLOCK)
  @test S.day(s.when) == "18 November 2026" && S.day(DateTime(2027, 3, 4)) == "4 March 2027"
  @test S.caption(s) == "Signed by Sam Lee on 18 November 2026"
  s.name = ""
  @test S.caption(s) == "Signed on 18 November 2026"
end

@testset "a signature as a picture" begin
  s = S.signature(BLOCK)
  @test S.curve(s.strokes[1]) == "M52 80 Q60 71.5 67 80.8 L74 90" && S.curve(s.strokes[2]) == "M90 62 L96 88"
  svg = S.svg(s, ink="#111", line="#ccc", mark="#888")
  @test startswith(svg, "<svg ") && endswith(svg, "</svg>") && occursin("viewBox=\"0 0 420 130\"", svg)
  @test count("stroke=\"#111\"", svg) == 2 && occursin("d=\"M90 62 L96 88\"", svg) && occursin("stroke-linecap=\"round\"", svg)
  @test occursin("aria-label=\"Signed by Sam Lee on 18 November 2026\"", svg)
  # The line to sign on and its ✕ are there before anyone signs, and no strokes
  empty = S.svg(S.signature(["name: A <b> & Co"]), ink="#111", line="#ccc", mark="#888")
  @test !occursin("#111", empty) && count("stroke=\"#888\"", empty) == 2 && occursin("aria-label=\"A place to sign\"", empty)
  # A name can't break the picture
  named = S.svg(S.signature(["name: A <b> & \"Co\"", "pen 1,2 3,4"]), ink="#111", line="#ccc", mark="#888")
  @test occursin("Signed by A &lt;b&gt; &amp; &quot;Co&quot;", named) && !occursin("<b>", named)
end
