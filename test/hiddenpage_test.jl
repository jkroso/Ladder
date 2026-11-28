# Tests for hiddenpage.jl: what Ladder tells the program that holds a site's
# pages, and what it takes from the program's lines. Run them with
# `julia -O0 --project=. test/hiddenpage_test.jl`. A shell script stands in for
# the program, so they use neither WebKit nor the web, and they draw no window.

@use Test: @test, @testset
@use "../web/hiddenpage" => H
@use "github.com/jkroso/JSON.jl" parse_json

const dir = mktempdir()
const heard = joinpath(dir, "heard.txt")   # each command that the stand-in was told, a line each

# The stand-in writes down each command, and answers the ones that the tests look at
const script = """
while IFS= read -r line; do
  printf '%s\\n' "\$line" >> "$heard"
  case "\$line" in
    *'"do":"open"'*) echo '{"event":"loaded","page":"home","url":"https:\\/\\/example.com\\/"}'
                     printf 'the answer' > "$dir/1.json"
                     echo '{"event":"data","page":"home","url":"https:\\/\\/example.com\\/api","status":200,"file":"$dir/1.json"}' ;;
    *'"do":"run"'*) echo '{"event":"value","page":"home","id":1,"value":"Home"}' ;;
    *'"do":"signin"'*) echo '{"event":"signin","open":true}'; echo '{"event":"signin","open":false}'; echo '{"event":"signed","in":true}' ;;
    *'"do":"signout"'*) echo '{"event":"signed","in":false}' ;;
    *'"do":"fail"'*) echo 'error: no WebKit' >&2; exit 1 ;;
  esac
done
"""

"Start the stand-in as hiddenpage.jl starts the program"
stand_in(s) = begin
  to, out = Pipe(), Pipe()
  mkpath(H.folder(s.name))
  process = run(pipeline(`sh -c $script`, stdin=to, stdout=out, stderr=joinpath(H.folder(s.name), "problem.txt")), wait=false)
  close(out.in)
  close(to.out)
  (process, to, out)
end

"Wait until `done()` is true, for 5 seconds at most, and give whether it was"
until(done) = (t = time(); while !done() && time() - t < 5; sleep(0.02); end; done())

H.STARTER[] = stand_in

@testset "a site's program is told commands and its lines come as events" begin
  s = H.site("test.example")
  @test s === H.site("test.example") && !H.running(s) && s.signed === nothing && isempty(H.events!(s))
  @test H.open!(s, "home", "https://example.com/", capture="/api")
  @test H.running(s)
  @test until(() -> length(s.events) == 2)
  loaded, data = H.events!(s)
  @test loaded["event"] == "loaded" && loaded["url"] == "https://example.com/" && loaded["page"] == "home"
  @test data["event"] == "data" && data["status"] == 200 && data["url"] == "https://example.com/api"
  @test isempty(H.events!(s))   # an event is given once
  # The answer's text is read from its file, and the file goes
  @test H.body!(data) == "the answer" && !isfile(data["file"]) && H.body!(data) === nothing
  told = parse_json(readlines(heard)[1])
  @test told["do"] == "open" && told["page"] == "home" && told["url"] == "https://example.com/" && told["capture"] == "/api"

  # What JavaScript returns comes with the number that `run!` gave
  id = H.run!(s, "home", "return document.title")
  @test id == 1 && until(() -> !isempty(s.events))
  value = only(H.events!(s))
  @test value["id"] == 1 && value["value"] == "Home"
  @test parse_json(readlines(heard)[2])["js"] == "return document.title"
end

@testset "signing in and out" begin
  s = H.site("test.example")
  @test H.sign_in!(s, "https://example.com/login", cookie="who", title="Sign in to Example")
  @test until(() -> s.signed === true)
  @test !s.asking && [e["event"] for e in H.events!(s)] == ["signin", "signin", "signed"]
  told = parse_json(readlines(heard)[3])
  @test told["do"] == "signin" && told["cookie"] == "who" && told["title"] == "Sign in to Example"
  @test H.sign_out!(s) && until(() -> s.signed === false)
  H.events!(s)
  # A test can stand in for the program's lines too
  H.said!(s, Dict("event" => "signin", "open" => true))
  @test s.asking && only(H.events!(s))["open"] === true
  H.said!(s, Dict("event" => "signin", "open" => false))
  H.events!(s)
end

@testset "the program ends when Ladder says, and says why when it stops by itself" begin
  s = H.site("test.example")
  process = s.process
  H.stop!(s)
  @test !H.running(s) && until(() -> !process_running(process))
  @test isempty(s.problem) && isempty(H.events!(s))
  # It starts again when it's next told something
  @test H.tell!(s, Dict("do" => "fail"))
  @test until(() -> !isempty(s.problem))
  @test s.problem == "no WebKit" && !H.running(s)
  stopped = only(H.events!(s))
  @test stopped["event"] == "stopped" && stopped["why"] == "no WebKit"
  # A page that isn't open is closed without starting the program
  @test H.close!(s, "home") == false && !H.running(s)
end

@testset "where the program and its files are" begin
  @test endswith(H.folder("x.com"), "/Library/Caches/Ladder/hidden/x.com")
  @test endswith(H.folder("a b/c"), "/hidden/a_b_c")   # a store's name makes one folder, whatever it holds
  # From the source, the program's file has one name, so WebKit keeps its stores in one place
  c = H.command(["x.com", "/tmp/x"], dir=dir)
  @test occursin("/hiddenpage-", join(c.exec, ' ')) && occursin(H.PROGRAM, join(c.exec, ' ')) && c.exec[end-1:end] == ["x.com", "/tmp/x"]
end
