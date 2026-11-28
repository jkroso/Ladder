# Tests for save.jl, which reads the lines of a `save` block and writes the
# rows that it saves as text. Run them with `julia -O0 --project=. test/save_test.jl`.

@use Test: @test, @testset
@use "../blocks/save" => S

@testset "the lines of a save block" begin
  s = S.query(["to: big orders.csv", "From: Orders", "as: JSON", "method: put", "key: shop", "note: hi"])
  @test (s.to, s.from, s.as, s.method, s.key) == ("big orders.csv", "Orders", "JSON", "put", "shop")
  @test S.format(s) == "json" && S.method(s) == "PUT"
  @test S.query(["to:"]).to == ""
  # Writing a line changes the first line that says it, and leaves the others alone
  @test S.with_line(["key: a", "to: x.csv"], :to, "y.csv") == ["key: a", "to: y.csv"]
  @test S.with_line(["key: a"], :to, "y.csv") == ["to: y.csv", "key: a"]
  @test S.with_line(["into: x.csv"], :to, "y.csv") == ["to: y.csv"]
end

@testset "where the rows go, and how" begin
  @test S.isurl("https://example.com/x") && S.isurl(" HTTP://a.b") && !S.isurl("orders.csv")
  @test S.host("https://user:pw@api.example.com:8443/v1/rows?x=1") == "api.example.com"
  @test S.islocal("http://localhost:8080/x") && S.islocal("http://127.0.0.1/x") && !S.islocal("http://example.com")
  @test S.format(S.query(["to: a.tsv"])) == "tsv"
  @test S.format(S.query(["to: a.txt"])) == "csv"
  @test S.format(S.query(["to: https://x.com"])) == "json"
  @test S.format(S.query(["to: https://x.com", "as: csv"])) == "csv"
  @test S.format(S.query(["as: xml"])) === nothing
  @test S.method(S.query(String[])) == "POST" && S.method(S.query(["method: GET"])) === nothing
  @test S.content_type("tsv") == "text/tab-separated-values"
end

@testset "what can't be saved" begin
  @test S.problem(S.query(["to: a.csv"])) == ""
  @test occursin("csv, tsv or json", S.problem(S.query(["as: xml"])))
  @test occursin("POST, PUT or PATCH", S.problem(S.query(["to: https://x.com", "method: DELETE"])))
  # A key goes only over https, or to this Mac
  @test occursin("https://", S.problem(S.query(["to: http://x.com/rows", "key: k"])))
  @test S.problem(S.query(["to: http://localhost:3000/rows", "key: k"])) == ""
  @test S.problem(S.query(["to: http://x.com/rows"])) == ""
end

@testset "the rows as text" begin
  @test S.delimited([["Name", "Note"], ["Ann", "says \"hi\", then goes"], ["Bob", ""]]) ==
        "Name,Note\nAnn,\"says \"\"hi\"\", then goes\"\nBob,\n"
  @test S.delimited([["a", "b,c"]], '\t') == "a\tb,c\n"
  @test occursin(S.PLAIN_NUMBER, "-3.5") && occursin(S.PLAIN_NUMBER, "1e6") && occursin(S.PLAIN_NUMBER, "0")
  @test !occursin(S.PLAIN_NUMBER, "007") && !occursin(S.PLAIN_NUMBER, "\$12") && !occursin(S.PLAIN_NUMBER, "1,200")
  @test S.rows_words(1) == "1 row" && S.rows_words(1200) == "1,200 rows"
end

@testset "what a server said" begin
  @test S.answer(201) == "201 Created" && S.answer(418) == "418"
  @test S.said("<html><body>Nope</body></html>") == ""
  @test S.said("Bad token\nmore") == "Bad token"
  @test length(S.said("x"^500)) == 200
  @test S.curl_words("curl: (6) Could not resolve host: nowhere.example\n") == "Could not resolve host: nowhere.example"
end
