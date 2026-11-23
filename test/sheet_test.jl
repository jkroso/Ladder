# Tests for sheet.jl: a sheet that works a row out backwards, from the answer
# that a row under it must come to. Run them with
# `julia -O0 --project=. test/sheet_test.jl`.

@use Test: @test, @testset
@use "../sheet" => S

texts(rows) = [r.text for r in S.tally(rows)]

@testset "a sheet from the top down" begin
  @test texts([("Wall length", "12m"), ("Wall height", "2.4m"), ("Area", "wall length * wall height")]) == ["12m", "2.4m", "28.8m²"]
  @test S.tally([("A", "nope")])[1].failed
  # A row can define a function, and a row under it can use the function
  @test texts([("", "double(x) = 2x"), ("B", "double(4)")])[2] == "8"
end

@testset "a row with a ? and what comes after it" begin
  @test S.unknown("? 12m") == "12m" && S.unknown(" ?") == "" && S.unknown("12m") === nothing
  # With no answer under it, the row is the value after the ?
  @test texts([("Wall length", "? 12m"), ("Twice", "wall length * 2")]) == ["12m", "24m"]
  @test texts([("N", "?")]) == ["1"]
end

@testset "a row that says what it must come to" begin
  ids = Set([:litres, :area])
  @test S.goal(Meta.parse("ceil(litres / 4) = 3"), ids) !== nothing && S.goal(Meta.parse("area * 2 = 30"), ids) !== nothing
  @test S.goal(Meta.parse("double(x) = 2x"), ids) === nothing && S.goal(Meta.parse("area * 2"), ids) === nothing
  @test S.goal(Meta.parse("area == 3"), ids) === nothing
end

@testset "the sheet works a row out backwards" begin
  rows = [("Wall length", "? 12m"), ("Wall height", "2.4m"), ("Area", "wall length * wall height"),
          ("Litres", "area * 2 / (16m^2 / litre) = 6litre"), ("Tins", "ceil(litres / 4litre)")]
  out = S.tally(rows)
  @test [r.text for r in out] == ["20m", "2.4m", "48m²", "6litre", "2"]
  @test out[1].solved && !out[1].failed && !any(r -> r.solved, out[2:end])
  # The value of each name is the one that the answer gives
  @test string(Dict(S.name_values(rows))["wall_length"]) == "20m"
  # A plain number, and a sum that isn't a straight line
  @test texts([("Side", "?"), ("Area", "side^2 = 49")]) == ["7", "49"]
  @test texts([("Rate", "? 50"), ("Hours", "38"), ("Pay", "rate * hours + 100 = 3140")])[1] == "80"
  # A sum that goes up in steps: any wall that takes 3 tins is an answer
  out = S.tally([("Wall", "? 10m"), ("Litres", "wall * 2.4m * 2 / (16m^2 / litre)"), ("Tins", "ceil(litres / 4litre) = 3")])
  @test out[1].solved && out[3].text == "3"
  # Nothing gives the answer
  out = S.tally([("X", "?"), ("Y", "x * 0 = 5")])
  @test out[1].failed && !out[1].solved
  # The answer has another kind of unit than the sum
  @test S.tally([("X", "? 1m"), ("Y", "x * 2 = 5litre")])[1].failed
  # A second row with a ?, after the first one's answer
  @test texts([("A", "?"), ("B", "a * 2 = 10"), ("C", "? 1m"), ("D", "c * b = 30m")]) == ["5", "10", "3m", "30m"]
  # The sheet has names from outside it
  @test [r.text for r in S.tally([("Tile", "? 0.1m^2"), ("Tiles", "floor / tile = 100")]; given=[("Floor", "50m^2")])] == ["0.5m²", "100"]
end

@testset "a row over a range" begin
  @test S.ends("8m to 20m", String[]) == ("8m", "20m") && S.ends("8m", String[]) === nothing
  # The word in a name, or in a string, makes no range
  @test S.ends("door to wall * 2", ["Door to wall"]) === nothing && S.ends("\"a to b\"", String[]) === nothing
  @test S.steps(12) == 24 && S.steps(1) == 20 && S.steps(0.37) == 37 && S.steps(0) == 1
  rows = [("Wall height", "2.4m"), ("Wall length", "8m to 20m"), ("Area", "wall length * wall height"), ("Coats", "2"),
          ("Litres", "area * coats / (16m^2 / litre)"), ("", "wall length * 2")]
  @test S.ranged(rows) == 2 && S.ranged(rows[1:1]) == 0
  # Each row shows what it comes to at the two ends
  @test texts(rows) == ["2.4m", "8m to 20m", "19.2m² to 48m²", "2", "2.4litre to 6litre", "16m to 40m"]
  # One place of the range
  @test [r.text for r in S.tally(rows; at=0.5)] == ["2.4m", "14m", "33.6m²", "2", "4.2litre", "28m"]
  c = S.cases(rows)
  @test c.table[1] == ["Wall length", "Area", "Litres"] && length(c.table) == 26 && c.places[1] == 0 && c.places[end] == 1
  @test c.table[2] == ["8m", "19.2m²", "2.4litre"] && c.table[3][1] == "8.5m" && c.table[end] == ["20m", "48m²", "6litre"]
  @test S.cases(rows[1:1]) === nothing && S.cases([("A", "1 to 5")]) === nothing
  # A plain number, and names from outside the sheet
  c = S.cases([("Tiles", "floor / (side * side)")]; given=[("Floor", "36m^2"), ("Side", "0.2m to 0.6m")])
  @test c.table[1] == ["Side", "Tiles"] && c.table[2] == ["0.2m", "900"] && c.table[end] == ["0.6m", "100"]
  # A sheet can have a row over a range and a row that's worked out backwards
  @test texts([("Long", "2 to 4"), ("Wide", "?"), ("Area", "long * wide = 12")]) == ["2 to 4", "6 to 3", "12"]
end

@testset "a sheet under another sheet with a range has a range of its own" begin
  above = [("Age", "0 to 40"), ("Power", "age * 2")]
  @test [r.text for r in S.tally([("Age", "0 to 10"), ("Twice", "age * 2")]; given=above)] == ["0 to 10", "0 to 20"]
  @test S.cases([("Age", "0 to 10"), ("Twice", "age * 2")]; given=above).table[end] == ["10", "20"]
  # A sheet with no range of its own is over the range of the name that it has from outside it
  @test [r.text for r in S.tally([("Twice", "age * 2")]; given=above)] == ["0 to 80"]
end

@testset "money, and power in gigawatts" begin
  @test texts([("Price", "22USD/W"), ("Power", "1GW"), ("Cost", "price * power")]) == ["22USD/W", "1GW", "22 billion USD"]
  @test texts([("Launch", "500USD/kg * 35200ton")]) == ["17.6 billion USD"]
  # An amount under a million shows its cents, unless it has none
  @test texts([("A", "22USD"), ("B", "1500.5USD"), ("C", "0.5AUD"), ("D", "-3e9USD"), ("E", "2.5e6EUR")]) ==
        ["22 USD", "1,500.50 USD", "0.50 AUD", "-3 billion USD", "€2.5 million"]
  @test texts([("Energy", "convert(TWh, 1GW * 5yr)"), ("Each", "1GW / 1MW")]) == ["43.8TWh", "1,000"]
  @test texts([("Per watt", "22/W")]) == ["22W⁻¹"]
  # Money over money is a number
  @test texts([("Orbit", "10USD"), ("Ground", "3USD"), ("Times", "orbit / ground")])[3] == "3.3333"
  @test texts([("Each", "convert(USD/MWh, 48.3e9USD / 43.8TWh)")]) == ["1,102.74USD/MW·hr"]
end

@testset "a value in another unit" begin
  @test texts([("", "1m in cm"), ("", "2.5km in m"), ("", "1m in ft"), ("", "25°C in °F")]) == ["100cm", "2,500m", "3.2808'", "77°F"]
  # A unit made of others, and a sum on the left
  @test texts([("", "90km/hr in m/s"), ("", "20000cm^2 in m^2"), ("", "2m + 50cm in mm")]) == ["25m/s", "2m²", "2,500mm"]
  # The names of rows, and a function that a row defines
  @test texts([("Wall length", "12m"), ("Wall height", "2.4m"), ("", "wall length * wall height in cm^2")])[3] == "288,000cm²"
  @test texts([("", "metres(x) = x in m"), ("", "metres(300cm)")])[2] == "3m"
  # A unit that measures something else goes wrong, as convert does
  @test S.tally([("", "1m in s")])[1].failed
  # in keeps its meaning for anything that isn't a unit
  @test texts([("", "3 in [1, 2, 3]"), ("", "4 in (1, 2)"), ("", "[x for x in 1:3]")]) == ["true", "false", "[1, 2, 3]"]
  # A row that a sheet works out backwards, from an answer in another unit
  @test texts([("Side", "? 1m"), ("", "side * side in cm^2 = 40000cm^2")]) == ["2m", "40,000cm²"]
end

# How many times a sheet has worked out the sum that it reads in the next test set. It's in Main, as
# test/hot runs this file in a module of its own, which a sheet's code can't name.
const RUNS = Core.eval(Main, :(sheet_test_runs = Ref(0)))

@testset "a sheet over a range works out what it reads from outside it once" begin
  given = [("Price", "(Main.sheet_test_runs[] += 1; 22USD/W)"), ("Unread", "5")]
  rows = [("Power", "1MW to 3MW"), ("Cost", "price * power")]
  c = S.cases(rows; given)
  @test c.table[2] == ["1MW", "22 million USD"] && c.table[end] == ["3MW", "66 million USD"] && length(c.table) == 22
  # Once for the 21 places of the range, and not again for the same names
  @test RUNS[] == 1
  @test [r.text for r in S.tally(rows; given)] == ["1MW to 3MW", "22 million USD to 66 million USD"] && RUNS[] == 1
  # A sum that the sheet doesn't read changes, as it does while it's dragged, and the sheet has nothing to work out
  @test S.cases(rows; given=[given[1], ("Unread", "6")]) == c && RUNS[] == 1
  # A sum that it reads changes
  @test S.cases(rows; given=[("Price", "(Main.sheet_test_runs[] += 1; 20USD/W)")]).table[end] == ["3MW", "60 million USD"] && RUNS[] == 2
  @test [r.text for r in S.tally(rows; given, at=0.5)] == ["2MW", "44 million USD"] && RUNS[] == 2
  # A sum under the one that counts changes, as on each step of a drag, and the sums over it don't run again
  wide = [("Power", "1MW to 3MW"), ("Cost", "price * power * scale")]
  @test S.cases(wide; given=[given[1], ("Scale", "2")]).table[end] == ["3MW", "132 million USD"] && RUNS[] == 2
  @test S.cases(wide; given=[given[1], ("Scale", "3")]).table[end] == ["3MW", "198 million USD"] && RUNS[] == 2
  @test [r.text for r in S.tally(wide; given=[given[1], ("Scale", "4")])] == ["1MW to 3MW", "88 million USD to 264 million USD"] && RUNS[] == 2
  # A page keeps them in a place of its own, so a page that opens works them out again
  page = Dict{Any,Any}()
  @test S.cases(rows; given, cache=page) == c && RUNS[] == 3 && !isempty(page)
  @test S.cases(rows; given, cache=page) == c && RUNS[] == 3
end
