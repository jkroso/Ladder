# Tests for the sums that the scripts of a `view` block get from their
# document, in main.jl: `ladder.sums`, `ladder.shown` and the event `sums`.
# Run them with `julia -O0 --project=. test/web_sums_test.jl`. They draw in a
# window that isn't on the screen, and ask the web for nothing.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/Units.jl" m mm g kg kW W yr Percent J
@use "github.com/jkroso/Units.jl/Money" => Cash
const px = K.px

# Nothing here needs the web, so what stands in for `curl` gets nothing
K.WEB_GETTER[] = (address, file, about) -> () -> false

const dir = mktempdir()
const page = joinpath(dir, "sizes.md")
write(page, """
# A wing

The wing spans !`span = 70m`, and the sun is out !`sun = 98Percent` of the time. Cells cost !`cell = 0.30USD/W`,
and each square metre weighs !`foil = 500g`. It's !`kind = "a roll"`. !`span * 2`

```view
<p id=out style="margin:0;height:20px">no sums</p>
<script>
  var heard = 0
  addEventListener('sums', () => {
    heard += 1
    document.getElementById('out').textContent = ladder.shown.span + ' wide'
  })
</script>
```

Under the block, the wing and its twin span !`both = span * 2`.
""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 700px))
frames(n=3) = foreach(_ -> frame(w), 1:n)
frames()
const b = e.nodes[(:block, K.VIEW_BLOCK, page, 1)].browser
live(code) = K.Browsers.Live.evaluate(b.view.live, code)
"The number or the words that the page's script has for the sum `name`"
got(name) = live("ladder.sums[$(repr(name))]")

@testset "an amount is a number in SI units" begin
  @test K.script_value(70m) == 70 && K.script_value(20mm) == 0.02 && K.script_value(150kW) == 150_000
  # Units.jl's base for mass is the gram, and a watt is in kilograms already
  @test K.script_value(500g) == 0.5 && K.script_value(375kg) == 375 && K.script_value(5J) == 5
  @test K.script_value(2.5kg/kW) ≈ 0.0025 && K.script_value(0.5kg/m^2) == 0.5
  @test K.script_value(98Percent) ≈ 0.98 && K.script_value(1Percent/yr) ≈ 0.01 / K.script_value(1yr)
  # Money is a number of its currency
  @test K.script_value(100Cash.USD) == 100 && K.script_value(25Cash.USD/W) == 25 && K.script_value(3Cash.AUD/kg) == 3
  @test K.script_value(3) === 3.0 && K.script_value(true) === true && K.script_value("words") == "words"
  @test K.script_value([1, 2]) === nothing && K.script_value(nothing) === nothing
end

@testset "the page's script gets the sums that give a name" begin
  @test got("span") == 70 && got("sun") ≈ 0.98 && got("cell") ≈ 0.3 && got("foil") == 0.5 && got("kind") == "a roll"
  # A sum under the block counts too, and one that gives no name doesn't
  @test got("both") == 140 && live("Object.keys(ladder.sums).length") == 6
  # The text that the document shows for each, and the event that tells the page
  @test live("ladder.shown.span") == "70m" && live("ladder.shown.sun") == "98%"
  @test live("document.getElementById('out').textContent") == "70m wide"
  heard = live("heard")
  frames()
  # Frames with no change tell it nothing
  @test live("heard") == heard
end

@testset "a sum that changes, as while it's dragged, tells the page again" begin
  i = findfirst(l -> occursin("span = 70m", l), e.buf.lines)
  col = length(e.buf.lines[i], 1, findfirst("70m", e.buf.lines[i])[1])
  heard = live("heard")
  K.edit!(e.buf, (i, col - 1), (i, col + 1), "85", typing=true)
  frames()
  @test got("span") == 85 && got("both") == 170 && live("ladder.shown.span") == "85m"
  @test live("document.getElementById('out').textContent") == "85m wide" && live("heard") > heard
end

exit()
