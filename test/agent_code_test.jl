# Tests for the Julia code that an agent runs inside Ladder: repl.jl,
# for_agents.jl, "the code that an agent runs" in main.jl, and cad/agent.jl
# for a SolidCraft design. Run them with
# `julia -O0 --project=. test/agent_code_test.jl`. No real agent runs: the
# agent here is a small script that prints the lines of JSON that Claude
# Code does, and the test itself calls the tool, through the socket that an
# agent's program would use. The design's checks need SolidCraft.app on this
# Mac. They draw a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "../repl" => Repls
@use "../for_agents" => Offer
@use "../guard" => Guard
@use "../cad/engine" => Engines
@use "../cad/design" => Models
@use "github.com/jkroso/JSON.jl" => JSON
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = realpath(mktempdir())
K.SETTINGS_FILE[] = joinpath(dir, "settings")
K.AGENT_LOOKS[] = joinpath(dir, "looks")
K.AGENT_MODELS["Claude"] = K.model_list([K.AgentModel("opus", "Opus 5.5")])

# The agent writes down what it's started with and each line that Ladder gives it, and answers with a few words
const heard = joinpath(dir, "heard.txt")
const agent = joinpath(dir, "test-agent")
write(agent, replace(raw"""
#!/bin/sh
for given in "$@"; do printf 'option %s\n' "$given" >> "HEARD"; done
printf '%s\n' '{"type":"system","subtype":"init","session_id":"test-session","model":"claude-opus-5-5"}'
while IFS= read -r line; do
  printf '%s\n' "$line" >> "HEARD"
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"Plain words."}]}}'
  printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"result":""}'
done
""", "HEARD" => heard))
chmod(agent, 0o755)
K.SESSION_COMMAND[] = Cmd([agent])
heard_lines() = isfile(heard) ? readlines(heard) : String[]

"A thing that a window could show, with one function for an agent"
module Lamps
  mutable struct Lamp
    on::Bool
  end
  switch!(l::Lamp) = (l.on = !l.on)
end
Offer.about(::Lamps.Lamp) = "A lamp."
Offer.status(l::Lamps.Lamp) = l.on ? "It's on." : "It's off."
Offer.tools(::Lamps.Lamp) = [Offer.Tool(Lamps.switch!, "switch!(shown)", "Turn it on or off.")]

@testset "A thing says what it is, and its functions are the guide" begin
  @test Offer.guide(Lamps.Lamp(false)) == "A lamp.\n\nIts functions:\n\n- `switch!(shown)`: Turn it on or off."
  @test Offer.status(Lamps.Lamp(true)) == "It's on."
  # A thing that says nothing has no functions, and a page of text is changed in its file
  @test Offer.status(1) == "" && isempty(Offer.tools(1))
  @test occursin("your own tools", Offer.guide(1)) && occursin("its file", Offer.guide(nothing))
end

@testset "Code runs in a session's own module, which keeps its names, and long answers are cut short" begin
  lamp = Lamps.Lamp(false)
  asked = String[]
  yes = Ref(false)
  r = Repls.Repl("Test", dir; shown=() -> lamp, look=() -> "/a/picture.png", ask=(action, code) -> (push!(asked, action.words); yes[]))
  @test Repls.run_code(r, "1 + 1") == ("2", false)
  @test Repls.run_code(r, "guide(shown)") == (Offer.guide(lamp), false)
  # The thing's function has its own name in the code, and a name of the code's keeps its value
  @test Repls.run_code(r, "was = status(shown); switch!(shown); status(shown)") == ("It's on.", false)
  @test lamp.on
  @test Repls.run_code(r, "was") == ("It's off.", false)
  @test Repls.run_code(r, "println(\"said\"); 3") == ("said\n3", false)
  @test Repls.run_code(r, "nothing") == ("It ran, and came to nothing.", false)
  @test Repls.run_code(r, "look()") == ("/a/picture.png", false)
  # Another session has names of its own
  other = Repls.Repl("Test", dir)
  @test last(Repls.run_code(other, "was"))
  @test Repls.run_code(other, "shown") == ("It ran, and came to nothing.", false)
  # A long list shows with its middle left out, and a long text is cut, with how much more there is
  list, failed = Repls.run_code(r, "big = collect(1:5000)")
  @test !failed && occursin("5000-element", list) && occursin("⋮", list) && length(list) < 400
  text, _ = Repls.run_code(r, "repeat(\"word \", 3000)")
  @test length(text) < Repls.MOST + 200 && occursin("cut short: 11000 more characters", text)
  @test length(first(Repls.run_code(r, "repeat(\"word \", 3000)"; most=20_000))) == 15_000
  # Code that Julia can't read, and code that fails, say why
  said, failed = Repls.run_code(r, "1 +")
  @test failed && occursin("premature end of input", said) && length(said) < 300
  said, failed = Repls.run_code(r, "nowhere")
  @test failed && occursin("`nowhere` not defined", said)
  said, failed = Repls.run_code(r, "error(\"No.\")")
  @test failed && said == "No."

  # The sandbox: a sum goes on, and a step that could harm waits for your answer
  file = joinpath(dir, "written.txt")
  said, failed = Repls.run_code(r, "write($(repr(file)), \"x\")")
  @test failed && occursin("The user didn't allow it in Ladder.", said) && !isfile(file)
  @test length(asked) == 1 && occursin("write to written.txt", asked[1])
  # A yes lets the code go on from where it stopped, and lasts for the session
  yes[] = true
  @test Repls.run_code(r, "before = 1; write($(repr(file)), \"x\"); before + 1") == ("2", false)
  @test read(file, String) == "x" && length(asked) == 2
  @test Repls.run_code(r, "write($(repr(file)), \"xy\")") == ("2", false)
  @test length(asked) == 2
  # A part of Ladder isn't the code's to call
  yes[] = false
  said, failed = Repls.run_code(r, "Guard = parentmodule(typeof(shown)); 1")
  @test !failed
  said, failed = Repls.run_code(r, "ccall(:getpid, Cint, ())")
  @test failed && occursin("sandbox stopped", said)
  Repls.close!(r)
  Repls.close!(other)
end

@testset "An agent's program reaches the code through a socket, and the code runs in a thread of its own" begin
  lamp = Lamps.Lamp(false)
  r = Repls.Repl("Test", dir; shown=() -> lamp)
  program, given = Repls.command(r)
  @test program == "/usr/bin/nc" && given == ["-U", r.socket] && ispath(r.socket)
  @test filemode(dirname(r.socket)) & 0o077 == 0     # only you read the socket's folder
  p = open(`$program $given`, "r+")
  ask(o) = begin
    write(p, JSON.json(o), '\n')
    flush(p)
    t = @async JSON.parse_json(readline(p), JSON.Object)
    while !istaskdone(t); sleep(0.01); end   # the main thread gives the thing that's shown meanwhile
    fetch(t)
  end
  hello = ask(JSON.Object("jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => JSON.Object("protocolVersion" => "2025-06-18")))
  @test hello["id"] == 1 && hello["result"]["protocolVersion"] == "2025-06-18" && haskey(hello["result"]["capabilities"], "tools")
  tools = ask(JSON.Object("jsonrpc" => "2.0", "id" => 2, "method" => "tools/list"))["result"]["tools"]
  @test length(tools) == 1 && tools[1]["name"] == "julia" && tools[1]["inputSchema"]["required"] == ["code"]
  call(code) = ask(JSON.Object("jsonrpc" => "2.0", "id" => 3, "method" => "tools/call",
                               "params" => JSON.Object("name" => "julia", "arguments" => JSON.Object("code" => code))))["result"]
  got = call("switch!(shown); (status(shown), Threads.threadid())")
  @test got["isError"] == false && got["content"][1]["text"] == "(\"It's on.\", $(Threads.nthreads() > 0 ? 2 : 1))" && lamp.on
  got = call("oops(")
  @test got["isError"] == true
  @test ask(JSON.Object("jsonrpc" => "2.0", "id" => 4, "method" => "resources/list"))["error"]["code"] == -32601
  # When the session ends, the program that joined the two ends too
  Repls.close!(r)
  sleep(0.3)
  @test !process_running(p) && !ispath(r.socket)
end

@testset "Antigravity reads a picture that look() saved without a question" begin
  s = K.AgentSession(agent="Antigravity", dir=dir)
  asks(tool, path) = K.acp_asks!(s, "1", K.agent_json("""{"toolCall":{"name":"$tool","rawInput":{"AbsolutePath":"$path"}},"options":[{"optionId":"allow","kind":"allow_once"}]}"""))
  asks("view_file", joinpath(K.agent_looks(), "window-1.png"))
  @test isempty(s.items)
  # Another file, a path that leaves the folder, and a change to a picture are still asked for
  asks("view_file", joinpath(dir, "notes.md"))
  asks("view_file", joinpath(K.agent_looks(), "..", "notes.md"))
  asks("write_to_file", joinpath(K.agent_looks(), "window-1.png"))
  @test length(s.items) == 3 && all(it -> it isa K.AgentWants && it.answer == :none, s.items)
end

if !Engines.available()
  @info "SolidCraft isn't on this Mac, so the checks of a design are skipped."
else
  const file = joinpath(dir, "block.sc")
  # A design of its own: a block of 40 by 20 by 10 from a sketch, with a parameter for its height
  let e = Engines.start(joinpath(dir, "new.sc"))
    Engines.tell(e, "new_design")
    Engines.ask(e, "parameters.add", JSON.Object("name" => "tall", "expression" => "10 mm"))
    Engines.ask(e, "sketch.create", JSON.Object("plane" => "XY", "name" => "Base"))
    Engines.ask(e, "sketch.rectangle.center", JSON.Object("center" => Any[0, 0], "corner" => Any[20, 10]))
    Engines.ask(e, "sketch.finish")
    Engines.ask(e, "solid.extrude", JSON.Object("distance" => "tall", "name" => "Block"))
    Engines.ask(e, "file.save", JSON.Object("path" => file))
    Engines.stop!(e)
  end

  const e = K.build_editor(file)
  const w = Window(e, size=(1300px, 860px))
  frames(n=2) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
  view() = e.nodes[(:design, file)]
  "Draw frames until `f()` is true, for `limit` seconds at the most"
  until(f; limit=60) = begin
    from = time()
    while time() - from < limit
      frames(1)
      f() && return true
      sleep(0.01)
    end
    false
  end
  until(() -> view().model !== nothing && !Models.busy(view().model) && !isempty(view().model.shapes))
  K.agent_mode!(e)
  frames(3)
  const pane = K.agent_pane(e)
  "Run `code` as the agent's tool would, in its thread, while the window draws, and give its words and whether it failed"
  run(code) = begin
    s = pane.session
    t = Threads.@spawn Repls.run_code(s.repl, $code)
    waits() = !isempty(s.items) && s.items[end] isa K.AgentWants && s.items[end].answer == :none
    until(() -> istaskdone(t) || waits())
    # What the sandbox asks for is refused, as you would with the pane's button
    waits() && K.answer!(s, s.items[end], false)
    until(() -> istaskdone(t); limit=20) || error("The code didn't end: $code")
    fetch(t)
  end

  try
    @testset "The agent's program is started with the tool, and is told of it" begin
      foreach(c -> ontype(w, Typed(c, w)), "What is this?")
      onkey(w, KeyPress{Keys.enter}(0, w))
      @test until(() -> any(l -> occursin("What is this?", l), heard_lines()); limit=10)
      s = pane.session
      options = [l[8:end] for l in heard_lines() if startswith(l, "option ")]
      k = findfirst(==("--mcp-config"), options)
      config = JSON.parse_json(options[k+1], JSON.Object)
      @test config["mcpServers"]["ladder"] == JSON.Object("command" => "/usr/bin/nc", "args" => Any["-U", s.repl.socket])
      @test ispath(s.repl.socket)
      # Claude Code runs the code without asking, since the sandbox asks, and reads the pictures of the window
      k = findfirst(==("--allowedTools"), options)
      @test "mcp__ladder__julia" in options[k+1:end] && "Read(/$(K.agent_looks())/**)" in options[k+1:end]
      @test occursin("You have a tool named julia", K.session_brief(s))
      # An agent that works by turns has no tool, and isn't told of one
      @test !occursin("tool named julia", K.session_brief(K.AgentSession(agent="Grok", turns=true)))
      # The first words with a design have what the design says of itself, and each has what it shows now
      said = first(l for l in heard_lines() if occursin("What is this?", l))
      @test occursin("<ladder-guide>\\nThe window shows a SolidCraft design", said) && occursin("run!(shown, id; name=value, …)", said)
      @test occursin("The window shows a SolidCraft design with 1 body, 2 steps, 1 sketch and", said)
      @test occursin("Nothing is selected in it.\\n</ladder>", said)
      @test K.guide_once!(s, e) == ""
      # A step with the tool says what it runs
      @test K.tool_words("mcp__ladder__julia", K.agent_json("{\"code\":\"bodies(shown)\"}")) == "Running bodies(shown)"
    end

    @testset "The agent's code reads the design and changes it in the window" begin
      v = view()
      @test run("shown === nothing") == ("false", false)
      @test run("bodies(shown)") == ("1-element Vector{String}:\n \"Body1\"", false)
      @test run("[s[\"name\"] for s in steps(shown)]") == ("2-element Vector{String}:\n \"Base\"\n \"Block\"", false)
      @test run("only(p[\"name\"] for p in parameters(shown) if p[\"name\"] == \"tall\")") == ("tall", false)
      @test v.model.shapes[1].high[3] == 10.0
      # A parameter's new value makes the design again, and the code waits until the window has it
      said, failed = run("set!(shown, \"tall\", \"25 mm\"); nothing")
      @test !failed
      @test v.model.shapes[1].high[3] == 25.0
      @test occursin("changes that aren't in its file", Offer.status(v))
      # One of SolidCraft's commands, found by a word and run by its id
      found, failed = run("fillets = commands(shown, \"fillet\"); length(fillets)")
      @test !failed && parse(Int, found) >= 1
      @test first(run("any(startswith(\"solid.fillet\"), fillets)")) == "true"
      @test !last(run("about = command(shown, \"solid.fillet\"); nothing"))
      edges = length(v.model.shapes[1].edges)
      said, failed = run("run!(shown, \"solid.fillet\"; edges=[[20, 10, 12.5]], radius=\"2 mm\"); length(steps(shown))")
      @test (said, failed) == ("3", false)
      @test length(v.model.shapes[1].edges) > edges
      # ⌘Z's step takes it back, and a command that SolidCraft can't do says why
      @test !last(run("undo!(shown)"))
      @test length(Models.timeline(v.model)) == 2
      said, failed = run("run!(shown, \"solid.fillet\"; edges=[[500, 500, 500]], radius=\"2 mm\")")
      @test failed && !isempty(said)
      # The design itself isn't the code's to change, but with your yes
      said, failed = run("shown.tab = \"Surface\"")
      @test failed && occursin("The user didn't allow it", said) && v.tab == "Model"
      @test pane.session.items[end] isa K.AgentWants && pane.session.items[end].answer == :refused
    end

    @testset "The pane asks before a step of the code that could harm, and the code waits" begin
      s = pane.session
      target = joinpath(dir, "made.txt")
      t = Threads.@spawn Repls.run_code(s.repl, $("write($(repr(target)), \"made\"); 7"))
      @test until(() -> s.items[end] isa K.AgentWants && s.items[end].answer == :none && s.items[end].tool == "Julia"; limit=10)
      it = s.items[end]
      @test occursin("write to made.txt", it.words) && occursin("write(", it.detail)
      @test !istaskdone(t) && !isfile(target)
      K.answer!(s, it, true)
      @test until(() -> istaskdone(t); limit=10)
      @test fetch(t) == ("7", false) && read(target, String) == "made" && it.answer == :allowed
      # Your yes was for changes to the files of that folder, so the next one goes on without a question
      asks = count(it -> it isa K.AgentWants, s.items)
      @test run("write($(repr(target)), \"made again\"); 8") == ("8", false)
      @test count(it -> it isa K.AgentWants, s.items) == asks
      # A turn that ends answers no for what still waits
      t = Threads.@spawn Repls.run_code(s.repl, "run(`touch $(repr(target * ".2"))`)")
      @test until(() -> s.items[end] isa K.AgentWants && s.items[end].answer == :none; limit=10)
      @test occursin("run the program touch", s.items[end].words)
      K.settle!(s)
      @test until(() -> istaskdone(t); limit=10)
      @test last(fetch(t)) && !isfile(target * ".2") && s.items[end].answer == :gone
    end

    @testset "look() saves a picture of the window, with the design in it" begin
      path, failed = run("see!(shown, \"front\"); picture = look()")
      @test !failed && isfile(path) && startswith(path, K.agent_looks()) && endswith(path, ".png")
      @test filesize(path) > 20_000
      haskey(ENV, "LADDER_SHOTS") && cp(path, joinpath(ENV["LADDER_SHOTS"], "agent-look.png"), force=true)
      # The window draws on as before
      frames(3)
      @test view().stage !== nothing
    end
  finally
    pane.session === nothing || K.close!(pane.session)
    foreach(K.Designs.close!, K.designs(e))
  end
end
