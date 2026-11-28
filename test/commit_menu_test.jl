# Tests for the Commit button with a message that Claude writes, and the menu
# of the chevron beside it, in main.jl: see "Claude writes the commit's
# message". A script stands in for Claude: it keeps the diff and the words
# that it was given, and prints a message. Run them with
# `julia -O0 --project=. test/commit_menu_test.jl`. They make a repository in
# a temporary folder with the Mac's own git, and click in a window that isn't
# on the screen. With `LADDER_SHOTS` set to a folder, they save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive

const px = K.px
const G = K.Git

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const repo = joinpath(dir, "work")
mkpath(repo)
merge!(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
                 "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com"))
git(args...) = read(`git -C $repo -c commit.gpgsign=false $args`, String)
git("init", "-q", "-b", "main")
const page = joinpath(repo, "Readme.md")
const other = joinpath(repo, "notes.md")
# Changes at the top, in the middle and at the end are three changes, as git diff writes them
const COMMITTED = join(["# Work", "", "What this is.", "", "a", "", "b", "", "c", "", "d", "", "e", "", "Who it's for.", "", "f", "", "g", "", "h", "", "i", "", "j", "", "The end.", ""], "\n")
write(page, COMMITTED)
write(other, "# Notes\n")
git("add", "-A")
git("commit", "-q", "-m", "The first commit", "-m", "It has a body.", "-m", "Co-Authored-By: Someone <x@example.com>")

# The script that stands in for Claude keeps what it was given, and prints a message
script(body) = (f = joinpath(dir, "message-$(hash(body)).sh"); write(f, "#!/bin/sh\n" * body); chmod(f, 0o755); `/bin/sh $f`)
const WRITES = script("""cat > "$(joinpath(dir, "stdin.txt"))"\nprintf '%s' "\$1" > "$(joinpath(dir, "prompt.txt"))"\nprintf '```\\nSay what the page is for\\n\\nIt says who it is for too.\\n\\nCo-Authored-By: Claude Haiku <noreply@anthropic.com>\\n```\\n'\n""")
const SLOW = script("""cat > /dev/null\nsleep 1\necho "Say it slowly"\n""")
const FAILS = script("""cat > /dev/null\necho "Your credit is used up" >&2\nexit 1\n""")
given() = read(joinpath(dir, "stdin.txt"), String)
K.MESSAGE_COMMAND[] = WRITES

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 760px))
const (; frames, click, typed, key, shot) = drive(w, frames=3, pressed=1, latest=true, slide=false)
"Draw until git has answered, and then what it said is on the screen"
again() = (G.forget!(); frames(2); G.wait!(); frames(2))
"Draw until the message has come and the commit is made, for 10 seconds at the most"
committed() = (t = time(); while haskey(e.nodes, :writing) && time() - t < 10; frames(1); sleep(0.01) end; again())
"True while the list under the chevron shows"
list_open() = any(p -> p.key == K.COMMIT_LIST, popups(w))
"Click the chevron, and click the row of the way `way` in its list: :file, :part or :all"
choose(way) = (click(rect(e.nodes[:commit_more])); click(rect(e.nodes[(:commit_way, way)])); frames())
commit_button() = e.nodes[:commit]
said() = something(K.said_result(e), ("", 0.0))[1]
subjects() = split(chomp(git("log", "--format=%s")), '\n')
"Close the palette, and draw until it has slid away"
close_palette() = (K.close_palette!(e); t = time(); while K.palette_shows(e) && time() - t < 2; frames(1); sleep(0.02) end; frames())
status() = strip(git("status", "--porcelain"))
again()

@testset "a click on the Commit button commits the file, with the message that Claude writes" begin
  write(page, replace(COMMITTED, "What this is." => "What this is, and what it's for."))
  write(other, "# Notes\n\nMore.\n")
  K.refresh!(e.buf)
  again()
  b = commit_button()
  @test rect(b) !== nothing && rect(e.nodes[:commit_more]) !== nothing
  # The chevron is just right of the button
  @test 0 <= K.num(rect(e.nodes[:commit_more]).left - (rect(b).left + rect(b).width)) <= 4
  @test K.tip(b) == "Commit Readme.md, with a message that Claude writes"
  shot("commit-button")
  click(rect(b))
  committed()
  @test subjects() == ["Say what the page is for", "The first commit"]
  @test strip(git("log", "-1", "--format=%b")) == "It says who it is for too."   # the code fence and the line of who helped are gone
  # Claude read the file's diff, and the last messages with no lines that say who helped
  @test occursin("+What this is, and what it's for.", given()) && !occursin("notes.md", given())
  prompt = read(joinpath(dir, "prompt.txt"), String)
  @test occursin("The first commit", prompt) && occursin("It has a body.", prompt) && !occursin("Co-Authored-By", prompt)
  # The other file still has its change
  @test status() == "M notes.md"
  @test said() == "Committed Readme.md: Say what the page is for"
  @test isempty(K.commit_part(e))   # the file has no change now
end

@testset "the button spins while Claude writes, and changes that aren't saved are saved first" begin
  K.MESSAGE_COMMAND[] = SLOW
  K.focus(e)
  e.buf.caret = e.buf.anchor = (5, 0)
  typed("A ")
  @test K.dirty(e.buf)
  again()
  click(rect(commit_button()))
  @test !K.dirty(e.buf) && startswith(readlines(page)[5], "A ")
  @test K.BUTTONS[:commit].busy(e) && K.tip(commit_button()) == "Claude is writing the commit message…"
  frames(2)
  # The button stays, with its spinner, though the window's text is saved and git hasn't said so yet
  @test !isempty(K.commit_part(e)) && rect(commit_button()) !== nothing
  spins(r) = (hasproperty(r.from, :name) && r.from.name == "Spinner") || any(spins, try collect(r.children) catch; [] end)
  @test spins(rect(commit_button()))
  shot("commit-writing")
  # A second click while Claude writes starts nothing more
  K.commit_now!(e, :file)
  committed()
  @test subjects()[1:2] == ["Say it slowly", "Say what the page is for"]
  K.MESSAGE_COMMAND[] = WRITES
end

@testset "when Claude can't write the message, the window says why, and the palette asks for one" begin
  K.MESSAGE_COMMAND[] = FAILS
  write(page, COMMITTED)
  K.refresh!(e.buf)
  again()
  click(rect(commit_button()))
  committed()
  @test occursin("Your credit is used up", said())
  @test e.popup == :commands && K.palette(e).command.name == :commit
  @test subjects()[1] == "Say it slowly"   # no commit
  close_palette()
  K.MESSAGE_COMMAND[] = WRITES
end

@testset "the chevron's list has the three ways, and a switch that makes you write the message" begin
  click(rect(e.nodes[:commit_more]))
  @test list_open()
  @test [K.way_words(e, way)[1] for way in K.COMMIT_WAYS] == ["Commit this file", "Commit part of this file", "Commit all changed files"]
  @test K.way_words(e, :file)[2] == "Readme.md" && endswith(K.way_words(e, :all)[2], "files")
  @test all(way -> rect(e.nodes[(:commit_way, way)]) !== nothing, K.COMMIT_WAYS)
  # One outline wraps the buttons and the list: the list's right edge is in line with the chevron's, and the outline goes over the buttons
  @test K.commit_list_open(e)
  l, t = rect(e.nodes[:commit_list]), K.commit_target(e)
  @test K.num(l.left + l.width) ≈ t.x + t.w atol=1
  @test K.num(l.top) ≈ t.y + t.h + K.COMMIT_GAP atol=1
  outline, inside, closed = K.commit_envelope((x=K.num(l.left), y=K.num(l.top), w=K.num(l.width), h=K.num(l.height)), t)
  @test minimum(last, outline) ≈ t.y + 0.5 atol=1
  @test maximum(last, outline) ≈ K.num(l.top + l.height) atol=1
  shot("commit-list")
  # The switch turns on, and the list stays for another click
  @test !e.own
  click(rect(e.nodes[:own_message]))
  @test e.own && list_open()
  shot("commit-list-own")
  # A way then asks for your words in the palette
  click(rect(e.nodes[(:commit_way, :file)]))
  @test !list_open()
  @test e.popup == :commands && K.palette(e).command.name == :commit
  close_palette()
  @test K.tip(commit_button()) == "Commit Readme.md, with a message that you write"
  # The settings keep the switch
  f = K.Editor()
  write(K.settings_file(), "ownmessage=true\n")
  K.load_settings!(f)
  @test f.own
  rm(K.settings_file())
end

@testset "with the switch on, Commit all changed files asks for your words, and commits them all" begin
  write(joinpath(repo, "fresh.md"), "# Fresh\n")
  again()
  choose(:all)
  p = K.palette(e)
  @test e.popup == :commands && p.command.name == :commit_all && [K.chip_name(c) for c in K.palette_chips(p)] == ["Message"]
  typed("Put the pages in order")
  key(Keys.enter); key(Keys.enter)
  @test e.popup == :none && subjects()[1] == "Put the pages in order"
  @test isempty(status())
  @test said() == "Committed all changed files"
  e.own = false
end

@testset "Commit all changed files commits each file that has a change, new ones too" begin
  write(page, COMMITTED * "\nMore.\n")
  write(joinpath(repo, "newer.md"), "# Newer\n")
  write(other, "# Notes\n\nMore and more.\n")
  K.refresh!(e.buf)
  again()
  choose(:all)
  committed()
  @test subjects()[1] == "Say what the page is for"
  @test isempty(status())
  @test occursin("newer.md", given()) && occursin("notes.md", given()) && occursin("Readme.md", given())
  @test said() == "Committed all changed files: Say what the page is for"
end

@testset "Commit Part of This File commits the ticked changes, and leaves the file as it is" begin
  now = replace(COMMITTED, "What this is." => "What this is now.", "Who it's for." => "Who it's for now.", "The end." => "The end now.")
  write(page, now)
  K.refresh!(e.buf)
  again()
  choose(:part)
  @test K.choosing(e) && K.diffing(e)
  gone = K.gone_now(e)
  @test length(gone.diff.changes) == 3
  # Nothing is ticked yet, so the button has nothing to commit
  @test K.tip(commit_button()) == "Tick the changes to commit" && K.off(commit_button())
  click(rect(e.nodes[(:tick_change, 1)]))
  # The last change is further down: a tick box shows only beside a change on screen
  e.scroll.offset = max(0px, gone.tops[3] - 200px)
  frames()
  click(rect(e.nodes[(:tick_change, 3)]))
  @test K.ticked(e) == [1, 3]
  e.scroll.offset = 0px
  frames()
  @test K.tip(commit_button()) == "Commit the 2 ticked changes, with a message that Claude writes"
  shot("commit-ticks")
  # A tick stays with its change while the lines above it move
  K.focus(e)
  e.buf.caret = e.buf.anchor = (1, 0)
  typed("x")
  @test K.ticked(e) == [1, 3] || K.ticked(e) == [2, 4]
  K.undo!(e.buf)
  frames()
  @test K.ticked(e) == [1, 3]
  click(rect(commit_button()))
  committed()
  @test subjects()[1] == "Say what the page is for"
  # The commit has the first and the last change, and not the middle one
  @test git("show", "HEAD:Readme.md") == replace(COMMITTED, "What this is." => "What this is now.", "The end." => "The end now.")
  # The file is as it was, and the middle change is still a change that isn't staged
  @test read(page, String) == now
  @test status() == "M Readme.md"
  @test isempty(strip(git("diff", "--cached")))
  @test occursin("+Who it's for now.", git("diff"))
  # Claude read only the ticked changes
  @test occursin("+What this is now.", given()) && !occursin("Who it's for now.", given())
  @test !K.choosing(e)
end

@testset "with the switch on, the ticked changes are committed with your words" begin
  git("checkout", "--", "Readme.md")
  before = git("show", "HEAD:Readme.md")
  now = replace(before, "What this is now." => "What this is today.", "The end now." => "The end today.")
  write(page, now)
  K.refresh!(e.buf)
  again()
  e.own = true
  choose(:part)
  click(rect(e.nodes[(:tick_change, 1)]))
  @test K.tip(commit_button()) == "Commit the ticked change, with a message that you write"
  click(rect(commit_button()))
  p = K.palette(e)
  @test e.popup == :commands && p.command.name == :commit_ticked && [K.chip_name(c) for c in K.palette_chips(p)] == ["Message"]
  typed("Say what it is today")
  key(Keys.enter); key(Keys.enter)
  @test e.popup == :none && subjects()[1] == "Say what it is today"
  @test git("show", "HEAD:Readme.md") == replace(before, "What this is now." => "What this is today.")
  @test read(page, String) == now
  @test said() == "Committed the ticked changes of Readme.md"
  e.own = false
end

@testset "the agent that Settings chose writes the message, and the button names it" begin
  # An agent that reads only its words, as Grok does, gets the diff after them
  bin = mkpath(joinpath(dir, "bin"))
  fake = joinpath(bin, "fake-agent")
  write(fake, """#!/bin/sh
  for a; do last="\$a"; done
  printf '%s' "\$last" > "$(joinpath(dir, "words.txt"))"
  printf '%s' "\$1" > "$(joinpath(dir, "first.txt"))"
  cat > "$(joinpath(dir, "piped.txt"))"
  echo 'Say who it is for'
  """)
  chmod(fake, 0o755)
  push!(K.AGENT_KINDS, K.AgentKind("Fake", "fake-agent", [bin], String[], String[], ["--quick", "-p"], false))
  K.MESSAGE_COMMAND[] = nothing
  e.ai = "Fake"
  K.refresh!(e.buf)
  again()
  @test !isempty(K.commit_part(e)) && K.tip(commit_button()) == "Commit Readme.md, with a message that Fake writes"
  click(rect(commit_button()))
  @test e.nodes[:writing].who == "Fake"
  committed()
  @test subjects()[1] == "Say who it is for" && said() == "Committed Readme.md: Say who it is for"
  words = read(joinpath(dir, "words.txt"), String)
  @test read(joinpath(dir, "first.txt"), String) == "--quick" && isempty(read(joinpath(dir, "piped.txt"), String))
  @test occursin("comes at the end of these words", words) && occursin("The diff:", words) && occursin("+The end today.", words)
  # Claude Code reads the diff on its stdin, and Haiku writes it
  e.ai = "Claude"
  k = K.agent_kind("Claude")
  @test k.piped && "haiku" in k.message && last(k.message) == "-p"
  pop!(K.AGENT_KINDS)
  K.MESSAGE_COMMAND[] = WRITES
end

K.MESSAGE_COMMAND[] = nothing
close(w)
