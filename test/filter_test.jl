# Tests for filter.jl. Run them with `julia -O0 --project=. test/filter_test.jl`.

@use Test: @test, @testset
@use "../blocks/filter" => F

const ROWS = [["Name", "City", "Total", "Joined", "Note"],
              ["Ann", "Sydney", "\$1,200", "2026-03-01", "pays late"],
              ["Bob", "Perth", "80", "2025-12-24", ""],
              ["Cy", "sydney", "\$450", "2026-11-02", "Smith, J"],
              ["Di", "Melbourne", "", "2024-07-15", "new"],
              ["Ed", "Hobart", "1500", "2026-01-30", "pays early"]]
const NUMBERS = [false, false, true, false, false]

names_of(s) = [ROWS[r][1] for r in s.rows]
shows(conditions...; kw...) = names_of(F.subset(F.query(collect(conditions)), ROWS, NUMBERS))

@testset "reading and writing the lines" begin
  f = F.query(["from: orders.json", "at: data.orders", "where: City is Sydney, Perth", "Total > 100",
               "show: Name, \"Total, all\"", "sort: Total, largest first", "colour: blue", ""])
  @test f.from == "orders.json" && f.at == "data.orders"
  @test f.conditions == ["City is Sydney, Perth", "Total > 100"]
  @test f.show == ["Name", "Total, all"] && f.sort == "Total" && F.down(f) && f.other == ["colour: blue"]
  @test F.written(f) == ["from: orders.json", "at: data.orders", "where: City is Sydney, Perth", "where: Total > 100",
                         "show: Name, \"Total, all\"", "sort: Total, largest first", "colour: blue"]
  @test isempty(F.written(F.query(String[])))
  # Words at the end of a sort line say which way, with or without a comma
  @test (F.query(["sort: Name Z to A"]).sort, F.down(F.query(["sort: Name Z to A"]))) == ("Name", true)
  @test (F.query(["sort: Name"]).sort, F.down(F.query(["sort: Name"]))) == ("Name", false)
  @test F.values_in("\"Smith, J\", Jones,  \"say \"\"hi\"\"\" ") == ["Smith, J", "Jones", "say \"hi\""]
  @test F.listed(["Smith, J", "Jones", "say \"hi\""]) == "\"Smith, J\", Jones, \"say \"\"hi\"\"\""
end

@testset "a condition is read against the names of the columns" begin
  names = ["Total", "Total tax", "Is it", "Name"]
  c = F.condition("Total tax > 5", names)
  @test c.column == 2 && c.test == :gt && c.values == ["5"] && c.problem == ""
  @test F.condition("total>5", names).column == 1
  @test F.condition("Is it is not empty", names).column == 3 && F.condition("Is it is not empty", names).test == :full
  @test F.condition("Name isn't Ann, Bob", names).test == :isnt && F.condition("Name isn't Ann, Bob", names).values == ["Ann", "Bob"]
  @test F.condition("Name has Smith, J", names).values == ["Smith, J"]
  @test F.condition("Total > \$1,200", names).values == ["\$1,200"]
  @test F.condition("Name has nothing", names).test == :has && F.condition("Name has nothing", names).values == ["nothing"]
  @test F.condition("Name has no x", names).test == :lacks
  # A column that isn't there, a condition with no test, and one with nothing to look for
  @test F.condition("Colour is red", names).problem == "No column is called “Colour”."
  @test occursin("has no test", F.condition("Name Ann", names).problem)
  @test occursin("doesn't say what to look for", F.condition("Name is", names).problem)
  @test occursin("doesn't name a column", F.condition("is red", names).problem)
end

@testset "the rows that meet the conditions" begin
  @test shows() == ["Ann", "Bob", "Cy", "Di", "Ed"]
  # Capitals don't count, and commas give a choice of values
  @test shows("City is sydney") == ["Ann", "Cy"]
  @test shows("City is Sydney, Perth") == ["Ann", "Bob", "Cy"]
  @test shows("City = Perth") == ["Bob"] && shows("City != Perth") == ["Ann", "Cy", "Di", "Ed"]
  @test shows("City is not Sydney, Perth") == ["Di", "Ed"]
  # Numbers compare as numbers, with their marks, and an empty cell is no number
  @test shows("Total > 450") == ["Ann", "Ed"]
  @test shows("Total >= 450") == ["Ann", "Cy", "Ed"]
  @test shows("Total < \$1,000") == ["Bob", "Cy"]
  @test shows("Total is 1200") == ["Ann"]
  # Dates written as 2026-11-21 go in the order of their days
  @test shows("Joined >= 2026-01-01") == ["Ann", "Cy", "Ed"]
  @test shows("Note has pays") == ["Ann", "Ed"] && shows("Note has no pays") == ["Bob", "Cy", "Di"]
  @test shows("Note starts with PAYS", "Note ends with late") == ["Ann"]
  @test shows("Note is empty") == ["Bob"] && shows("Note is not empty") == ["Ann", "Cy", "Di", "Ed"]
  # Every condition must hold
  @test shows("City is Sydney", "Total > 1000") == ["Ann"]
  # A condition with a problem leaves the rows as they are, and says so
  s = F.subset(F.query(["Colour is red", "City is Perth"]), ROWS, NUMBERS)
  @test names_of(s) == ["Bob"] && s.problems == ["No column is called “Colour”."]
end

@testset "the order and the columns" begin
  @test shows("sort: Total") == ["Bob", "Cy", "Ann", "Ed", "Di"]
  @test shows("sort: Total, largest first") == ["Ed", "Ann", "Cy", "Bob", "Di"]
  @test shows("sort: name, Z to A") == ["Ed", "Di", "Cy", "Bob", "Ann"]
  # Empty cells go last both ways
  @test shows("sort: Note")[end] == "Bob" && shows("sort: Note, Z to A")[end] == "Bob"
  s = F.subset(F.query(["show: Total, name, Colour", "sort: Colour"]), ROWS, NUMBERS)
  @test s.columns == [3, 1] && s.sorted == 0 && length(s.problems) == 2
  @test F.subset(F.query(["show: Colour"]), ROWS, NUMBERS).columns == 1:5
  # A row that's too short has empty cells
  @test F.subset(F.query(["Note is empty"]), [["Name", "Note"], ["A"], ["B", "x"]], [false, false]).rows == [2]
end

@testset "a click on a column writes the lines" begin
  names = ROWS[1]
  f = F.query(["from: people.csv", "Total > 100"])
  F.look_for!(f, names, 2, :is, ["Sydney", "Perth, WA"])
  @test f.conditions == ["Total > 100", "City is Sydney, \"Perth, WA\""]
  @test F.looked_for(f, names, 2, :is) == ["Sydney", "Perth, WA"]
  F.look_for!(f, names, 2, :is, ["Perth, WA"])
  @test f.conditions == ["Total > 100", "City is \"Perth, WA\""]
  F.look_for!(f, names, 2, :is, String[])
  @test f.conditions == ["Total > 100"]
  F.look_for!(f, names, 5, :has, ["pays la"])
  @test f.conditions == ["Total > 100", "Note has pays la"] && F.looked_for(f, names, 5, :has) == ["pays la"]
  F.sort_by!(f, names, 3, true, true)
  @test F.written(f)[end] == "sort: Total, largest first"
  F.sort_by!(f, names, 1, true, false)
  @test F.written(f)[end] == "sort: Name, Z to A"
  F.sort_by!(f, names, 1, false, false)
  @test F.written(f)[end] == "sort: Name"
  F.sort_by!(f, names, 0, false, false)
  @test !any(startswith("sort"), F.written(f))
  F.hide!(f, names, 2, 1:5)
  @test f.show == ["Name", "Total", "Joined", "Note"]
  @test F.summary(12, 340) == "12 of 340 rows" && F.summary(1, 1) == "1 row" && F.summary(2, 6000, more=true) == "2 of the first 6,000 rows"
end
