# Tests for centient.jl. Run them with `julia -O0 --project=. test/centient_test.jl`.
# They talk to a small program that answers as Centient's server does, so they
# need no Centient and change no books.

@use Test: @test, @testset, @test_throws
@use "../centient" => C

@testset "JSON" begin
  @test C.json(Dict("a" => [1, 2.5, "x", nothing, true])) == """{"a":[1,2.5,"x",null,true]}"""
  @test C.json("tab\t \"quoted\" \\ line\nend \x01") == "\"tab\\t \\\"quoted\\\" \\\\ line\\nend \\u0001\""
  @test C.parse_json(""" {"a": [1, 2.5e1, "x", null, true, false], "b": {"c": {}} , "d": []} """) ==
        Dict("a" => Any[1.0, 25.0, "x", nothing, true, false], "b" => Dict("c" => Dict{String,Any}()), "d" => Any[])
  @test C.parse_json("\"m\\u00b2 \\ud83d\\ude00 \\n \\/ é\"") == "m² 😀 \n / é"
  for value in (Dict{String,Any}("name" => "20mm \"conduit\"\n", "price" => 4.2, "tags" => Any["a", nothing]), Any[], "m²", 12.0, nothing)
    @test C.parse_json(C.json(value)) == value
  end
  @test_throws Exception C.parse_json("{\"a\": 1")
end

# centient_fake.jl answers as Centient's server does
fake() = `$(Base.julia_cmd()) --startup-file=no $(joinpath(@__DIR__, "centient_fake.jl"))`

"Wait until `r` has its answer, for as long as `most` seconds"
settle(s, r, most=30) = begin
  t = time()
  while !C.finished(r) && time() - t < most
    C.check!(s)
    sleep(0.02)
  end
  r
end

@testset "asking" begin
  s = C.Server()
  a = C.ask("search_catalogue", Dict("query" => "conduit"), s=s, cmd=fake())
  b = C.ask("find_contacts", Dict("query" => "smith"), s=s, cmd=fake())
  @test C.running(s) && !C.finished(a)
  settle(s, a); settle(s, b)
  @test s.ready && s.company == "sample-co"
  @test a.value["tool"] == "search_catalogue" && a.value["asked"] && !C.failed(a)
  @test [r["ref"] for r in a.value["items"]] == ["item 1", "acme 77"] && a.value["items"][1]["price"] == 4.2
  @test b.value["tool"] == "find_contacts" && !b.value["asked"] && b.value["contacts"][1]["name"] == "J Smith"
  @test !C.check!(s)   # nothing waits now
  f = settle(s, C.ask("fail", s=s, cmd=fake()))
  @test C.failed(f) && f.problem == "Centient has no contact called Nobody" && f.value === nothing
  e = settle(s, C.ask("error", s=s, cmd=fake()))
  @test C.failed(e) && e.problem == "Unknown tool: error"
  # The tool that makes a job from a project page says what it made. The next time, it has the job.
  page = Dict("progress" => "http://host/projects/1/tasks?key=ab12", "title" => "12/40 Wattle Street")
  job = settle(s, C.ask("make_job_from_page", page, s=s, cmd=fake()))
  @test job.value["job"] == 12 && job.value["title"] == "12/40 Wattle Street" && job.value["asked"] == page
  @test (job.value["tasks"], job.value["steps"], job.value["added"], job.value["existed"]) == (5, 10, 10, false)
  again = settle(s, C.ask("make_job_from_page", page, s=s, cmd=fake()))
  @test (again.value["added"], again.value["existed"]) == (2, true)
  lost = settle(s, C.ask("make_job_from_page", Dict("progress" => "http://unreachable/projects/1/tasks"), s=s, cmd=fake()))
  @test C.failed(lost) && lost.problem == "Couldn't reach the walkthrough service. Check the internet connection."
  # A program that stops takes what waits for it with it, and says its last words
  slow = C.ask("slow", s=s, cmd=fake())
  q = settle(s, C.ask("quit", s=s, cmd=fake()))
  @test C.failed(q) && q.problem == "Centient's program stopped: The books are locked"
  @test C.failed(slow) && !C.running(s)
  # The next request starts it again
  again = settle(s, C.ask("lookup_items", s=s, cmd=fake()))
  @test again.value["tool"] == "lookup_items"
  # A program that's told to stop does, with no more than the end of what it reads
  program = s.process
  C.stop!(s)
  @test !C.running(s)
  @test timedwait(() -> process_exited(program), 10) == :ok
  # A command that can't run
  none = C.ask("lookup_items", s=C.Server(), cmd=`/nowhere/julia`)
  @test C.failed(none) && none.problem == "Ladder couldn't start Centient's program"
end
