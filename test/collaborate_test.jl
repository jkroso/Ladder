# Tests for the command Collaborate, in main.jl: it starts a session of the
# agent that Settings chose, in a terminal, to work on the window's file. Run
# them with `julia -O0 --project=. test/collaborate_test.jl`. No terminal
# opens and no real agent runs: the agent here is a small script, and the
# tests run the script that Ladder writes for the terminal themselves. They
# draw windows that aren't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = realpath(mktempdir())
@eval K settings_file() = $(joinpath(dir, "settings"))
# A folder with a space and a quote in its name, as a person's folder can have
const notes = joinpath(dir, "Sam's notes")
mkpath(notes)
const page = joinpath(notes, "plan.md")
write(page, "# Plan\n\nBuy paint.\n")

# The agent writes down where it started, what it was called and what it was told
const told = joinpath(dir, "told.txt")
write(joinpath(dir, "ladder-test-agent"), """
#!/bin/sh
{ pwd; echo "\$LADDER_AGENT"; command -v ladder; echo "\$#"; printf '%s\\n' "\$@"; } > "$told"
""")
chmod(joinpath(dir, "ladder-test-agent"), 0o755)
const tester = K.AgentKind("Tester", "ladder-test-agent", [dir], String[], String[])

# No agent waits for a page in these tests, unless a test says so
K.Agent.place[] = mktempdir()

const e = K.build_editor(page)
const w = Window(e, size=(900px, 600px))
frames(win=w, n=2) = foreach(_ -> Base.invokelatest(frame, win), 1:n)
frames(w, 4)
K.focus(e)

"Press the key `k` in window `win` with the keys `held` down"
press(win, k, held...) = begin
  foreach(h -> win.keys |= h, held)
  onkey(win, KeyPress{k}(0, win))
  foreach(h -> win.keys ⊻= h, held)
  haskey(win.ui.nodes, :palette) && (win.ui.nodes[:palette].moved = 0.0)
  frames(win)
end
typed(win, s) = (foreach(c -> ontype(win, Typed(c, win)), s); frames(win))

# What Ladder asked the terminal for
const opened = Tuple{String,String}[]
K.SESSION_OPENER[] = (script, folder) -> (push!(opened, (script, folder)); "a test terminal")
push!(K.AGENT_KINDS, tester)
e.ai = "Tester"

try
  @testset "Collaborate starts the agent on the window's file, in a terminal" begin
    # What's typed and not saved is in the file before the agent reads it
    K.edit!(e.buf, (3, 10), (3, 10), " And a brush.")
    @test K.dirty(e.buf) && read(page, String) == "# Plan\n\nBuy paint.\n"
    press(w, Keys.p, Keys.cmd, Keys.shft)
    typed(w, "collaborate")
    @test first(K.palette_rows(e, K.palette(e))).name == "Collaborate"
    # It takes nothing, so it runs when it's taken
    press(w, Keys.enter)
    @test e.popup == :none
    @test occursin("And a brush.", read(page, String)) && !K.dirty(e.buf)
    script, folder = only(opened)
    # Git doesn't keep the file, so the session starts in the file's folder
    @test folder == notes
    @test endswith(script, ".command") && startswith(basename(script), "plan-") && Sys.isexecutable(script)
    @test e.nodes[:result][1] == "Started Tester in a test terminal. Its logo shows at the top right when it's ready."
    # The terminal runs the script. The agent starts in the folder, with its name and the `ladder` command, and gets the words.
    run(`$script`)
    got = readlines(told)
    @test got[1] == notes
    @test got[2] == "Tester"
    @test basename(got[3]) == "ladder"
    @test got[4] == "1"
    words = join(got[5:end], "\n")
    @test words == K.collaborate_words(page)
    @test startswith(words, "Work on the file $page with me.")
    # The command that the agent is told to run names the file whatever is in its path
    @test occursin("Run `ladder wait '$(replace(page, "'" => "'\\''"))'` in the background.", words)
  end

  @testset "each agent gets its words the way that it takes them" begin
    kind(name) = K.agent_kind(name)
    plain = "/Users/sam/My notes/plan-2.md"
    words = K.collaborate_words(plain)
    # Claude's words go first: --allowedTools takes all that comes after it. It may run `ladder wait` and change the file.
    @test K.session_words(kind("Claude"), plain) == [words, "--allowedTools", "Bash(ladder wait *)", "Edit(//Users/sam/My notes/plan-2.md)"]
    # A path that a rule can't hold gets no rule for the file
    @test K.session_words(kind("Claude"), page) == [K.collaborate_words(page), "--allowedTools", "Bash(ladder wait *)"]
    @test K.session_words(kind("Claude"), "/Users/sam/plan (old).md")[2:end] == ["--allowedTools", "Bash(ladder wait *)"]
    @test K.session_words(kind("Grok"), plain) == ["--allow", "Bash(ladder wait*)", words]
    @test K.session_words(kind("Gemini"), plain) == ["-i", words]
    @test K.session_words(kind("Codex"), plain) == [words]
  end

  @testset "a file that git keeps starts the session in the top folder of its repository" begin
    repo = joinpath(dir, "shop")
    mkpath(joinpath(repo, "docs"))
    run(pipeline(`git -C $repo init -q`, stdout=devnull, stderr=devnull))
    doc = joinpath(repo, "docs", "prices.md")
    write(doc, "# Prices\n")
    o = K.build_editor(doc)
    o.ai = "Tester"
    ow = Window(o, size=(700px, 500px))
    frames(ow, 3)
    empty!(opened)
    K.collaborate!(o)
    script, folder = only(opened)
    @test folder == repo
    run(`$script`)
    got = readlines(told)
    @test got[1] == repo
    @test startswith(got[5], "Work on the file $doc with me.")
  end

  @testset "Collaborate starts no second agent, and none for what isn't a file to change" begin
    # While an agent waits for the file, the command says so and opens nothing
    empty!(opened)
    write(joinpath(K.Agent.folder(), "$(getpid()).wait"), page * "\nClaude\n")
    delete!(e.nodes, :agents)
    @test_throws "Claude works on this file with you already." K.collaborate!(e)
    @test isempty(opened)
    rm(joinpath(K.Agent.folder(), "$(getpid()).wait"))
    delete!(e.nodes, :agents)
    @test K.works_here(e, Val(:collaborate))
    # A table of a CSV file is only shown, so no agent can wait for it
    write(joinpath(dir, "prices.csv"), "item,price\npaint,40\n")
    f = K.build_editor(joinpath(dir, "prices.csv"))
    fw = Window(f, size=(700px, 500px))
    frames(fw, 3)
    @test !K.works_here(f, Val(:collaborate))
    @test_throws "Collaborate needs a file on this Mac that Ladder can change." K.collaborate!(f)
    @test isempty(opened)
  end
finally
  K.SESSION_OPENER[] = nothing
  filter!(k -> k !== tester, K.AGENT_KINDS)
  K.Agent.place[] = ""
end
