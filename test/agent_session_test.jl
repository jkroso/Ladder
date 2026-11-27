# Tests for a session's file, in main.jl: a file whose name ends in .chat
# keeps a session of an agent, and opens as the session over the page's whole
# space. Run them with `julia -O0 --project=. test/agent_session_test.jl`. No
# real agent runs: the agents here are small scripts that read and print the
# lines of JSON that the real ones do. They draw a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype onfiledrop
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = realpath(mktempdir())
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const notes = joinpath(dir, "notes.md")
write(notes, "# Notes\n\nWords.\n")

# Claude's stand-in writes down each line that Ladder gives it. While the file `lost` is there, it says
# what Claude Code says of a session that it doesn't have, and ends.
const heard = joinpath(dir, "heard.txt")
const lost = joinpath(dir, "lost")
const agent = joinpath(dir, "test-agent")
write(agent, replace(raw"""
#!/bin/sh
say() { printf '%s\n' "$1"; }
done_() { say '{"type":"result","subtype":"success","is_error":false,"result":""}'; }
if [ -f "LOST" ]; then
  rm "LOST"
  echo "No conversation found with session ID: test-session" >&2
  say '{"type":"result","subtype":"error_during_execution","is_error":true}'
  exit 1
fi
# Its session has the name that it's told to go on with, as Claude Code's has
session=test-session
for given in "$@"; do [ "$was" = "--resume" ] && session="$given"; was="$given"; done
say '{"type":"system","subtype":"init","session_id":"'"$session"'"}'
while IFS= read -r line; do
  case "$line" in *'"initialize"'*) continue ;; esac   # Ladder's first line, which asks what the program can do
  printf '%s\n' "$line" >> "HEARD"
  case "$line" in
  *'a table'*)
    say '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/tmp/notes.md"}}]}}'
    say '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","is_error":false}]}}'
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"## Paint\n\n| Colour | Litres |\n|---|---|\n| Red | 2 |"}]}}'
    done_ ;;
  *'go slow'*)
    say '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t3","name":"Read","input":{"file_path":"/tmp/notes.md"}}]}}'
    sleep 1
    say '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t3","is_error":false}]}}'
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"Slow **words**."}]}}'
    done_ ;;
  *)
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"Plain **words**."}]}}'
    done_ ;;
  esac
done
""", "HEARD" => heard, "LOST" => lost))
chmod(agent, 0o755)
K.SESSION_COMMAND[] = Cmd([agent])
# Claude Code's models, so no real agent is asked for them
K.AGENT_MODELS["Claude"] = K.model_list([K.AgentModel("opus", "Opus 5.5", "", "claude-opus-5-5"), K.AgentModel("sonnet", "Sonnet 5.5", "", "claude-sonnet-5-5"),
                                         K.AgentModel("haiku", "Haiku 5.5", "", "claude-haiku-5-5")], K.AgentModel[], "claude-opus-5-5")   # `every` is only for older models

# Codex's stand-in is started for each thing that you say, with the agent's name, the session's name and your words
const turns = joinpath(dir, "turns.txt")
const turner = joinpath(dir, "turn-agent")
write(turner, replace(raw"""
#!/bin/sh
printf '%s|%s|%s\n' "$1" "$2" "$(printf '%s' "$3" | tr '\n' ' ')" >> "TURNS"
printf '%s\n' '{"type":"thread.started","thread_id":"sess-Codex"}'
printf '%s\n' '{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"It has paint."}}'
printf '%s\n' '{"type":"turn.completed","usage":{}}'
""", "TURNS" => turns))
chmod(turner, 0o755)

const e = K.build_editor(notes)
const w = Window(e, size=(1100px, 760px))
frames(win=w, n=2) = foreach(_ -> Base.invokelatest(frame, win), 1:n)
frames(w, 4)
K.focus(e)

"Draw frames until `f()` is true, for 5 seconds at the most. The agent's lines are read between frames."
until(f, win=w) = begin
  from = time()
  while time() - from < 5
    frames(win, 1)
    f() && return true
    sleep(0.02)
  end
  false
end

"Press the key `k` in the window with the keys `held` down"
press(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
"Every rectangle in `r`, as it was last drawn"
flat(r, out=Any[]) = (push!(out, r); try foreach(c -> flat(c, out), r.children) catch end; out)
"The rectangle with the name `name` in the window of `ed`, or nothing"
named(name, ed=e) = (k = findfirst(r -> hasproperty(r.from, :name) && r.from.name == name, flat(K.rect(ed))); k === nothing ? nothing : flat(K.rect(ed))[k])
heard_lines() = isfile(heard) ? readlines(heard) : String[]
const chat = joinpath(dir, "Claude.chat")
pane() = e.nodes[(:chat, chat)]
"The editor of what the agent said in a new session's file in `folder`, whose reply is `text`"
reply_shown(folder, text) = begin
  mkpath(folder)
  said = joinpath(folder, "Shown $(length(readdir(folder))).chat")
  s = K.AgentSession(agent="Claude", dir=folder)
  push!(s.items, K.YouSaid(words="Show me"), K.AgentReply(text=text, whole=true, n=1))
  write(said, K.talk_text(s))
  K.open!(e, said)
  frames(w, 4)
  p = e.nodes[(:chat, said)]
  p.parts[(:reply, objectid(p.session.items[2]))]
end
"Move the mouse to `pos` in the window"
mouse_to(pos) = (w.mouse = typeof(w.mouse)(pos...); onmouse(w, MouseMove(w.mouse, w)); frames(w, 2))
"Click where the mouse is"
click_here() = (w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(w, 1);
                w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(w, 2))

try
  @testset "The file's text keeps what was said, whatever the words hold" begin
    s = K.AgentSession(agent="Claude", dir="/tmp/a--b", id="abc")
    push!(s.items, K.YouSaid(words="Two\nlines", about="A --> B · selection"))
    push!(s.items, K.AgentStep(id="t1", tool="Read", words="Reading plan.md", state=:going))
    push!(s.items, K.AgentStep(id="t2", tool="Bash", words="Running make", state=:failed))
    push!(s.items, K.AgentWants(id="r1", tool="Bash", words="run make", detail="make \"paint\"", answer=:allowed))
    # What the agent says can hold a line that looks like the start of a part
    push!(s.items, K.AgentReply(text="## Title\n\n<!-- ladder:you -->\n\\<!-- ladder:agent -->\nlast", whole=true))
    push!(s.items, K.SessionNote(words="Claude stopped.", bad=true))
    text = K.talk_text(s, "Words of mine\nover the session.")
    @test startswith(text, "Words of mine\nover the session.\n<!-- ladder:session {")
    @test !occursin("--", replace(text, "<!-- " => "", " -->" => "", "|---|" => ""))   # a comment holds no two dashes together
    kept = K.read_talk(text)
    @test (kept.agent, kept.folder, kept.id, kept.before) == ("Claude", "/tmp/a--b", "abc", "Words of mine\nover the session.")
    you, step, failed, asked, reply, note = kept.items
    @test (you.words, you.about) == ("Two\nlines", "A --> B · selection")
    @test (step.tool, step.words, step.state) == ("Read", "Reading plan.md", :done)   # a step that was under way is done now
    @test failed.state == :failed
    @test (asked.tool, asked.words, asked.detail, asked.answer) == ("Bash", "run make", "make \"paint\"", :allowed)
    @test reply.text == "## Title\n\n<!-- ladder:you -->\n\\<!-- ladder:agent -->\nlast" && reply.whole
    @test (note.words, note.bad) == ("Claude stopped.", true)
    @test K.read_talk("").items == [] && K.read_talk("plain words").before == "plain words"
    # The model that the session works with goes on with it
    s.model = "sonnet"
    @test kept.model == "" && K.read_talk(K.talk_text(s)).model == "sonnet"
  end

  @testset "New Agent Session makes a file for your agent, and shows the session over the page" begin
    c = K.COMMANDS[:new_agent_session]
    @test c.keys == "cmd+shift+a" && "New Agent Session" in K.file_menu(dir) && "New Agent Session" in K.FOLDER_MENU
    K.new_agent_session!(e, dir)
    frames(w, 4)
    @test e.buf.path == chat && isfile(chat) && K.chat_shown(e) && chat in K.tabs(e)
    kept = K.read_talk(read(chat, String))
    @test (kept.agent, kept.folder, kept.id, kept.items) == ("Claude", dir, "", [])
    @test K.file_icon(chat) == "chat-text"
    @test K.levels(e) == (K.FILE_LEVELS..., "the session that the file keeps") && K.level(e) == 4
    p = pane()
    s = p.session
    @test K.on_page(p) && s.agent == "Claude" && s.dir == dir && s.file == chat && !K.running(s)
    # The words that you type have the keyboard, and the top bar says which agent it is and where it works
    @test w.focus === p.field && e.buf.about == "Claude in $(basename(dir))"
    # The talk is a column in the middle of the page, with the field under it. It has the page's colours.
    talk, foot = named("Talk"), named("Agent foot")
    @test talk !== nothing && foot !== nothing && named("Page card") === nothing && named("Agent head") === nothing
    @test talk.width == foot.width == K.pane_wide(p, e) <= K.CHAT_WIDE
    @test abs((talk.left + talk.width / 2) - w.size[1] / 2) <= 1px && foot.top + foot.height <= w.size[2] && foot.height < 90px
    @test !K.pane_dark[] && p.field.theme == e.theme
    @test any(r -> r.from isa K.Icon && r.from.name == "agent-claude", (x.from for x in flat(talk) if hasproperty(x.from, :from)))
    # Before anything is said, the field is in the middle of the page, under the greeting. It's a slot: its ends are half circles.
    whole, slot = named("Agent"), foot.children[1]
    @test abs((slot.top + slot.height / 2) - (whole.top + whole.height / 2)) <= 1px && talk.top + talk.height <= foot.top
    @test K.num(slot.from.radius.tl) ≈ K.num(slot.from.radius.br) ≈ K.num(slot.height) / 2
    # The send button has the same middle as the slot's round end
    send = named("Send")
    @test abs(K.num(send.top + send.height / 2 - (slot.top + slot.height / 2))) < 0.5
    @test abs(K.num(slot.left + slot.width - (send.left + send.width / 2) - slot.height / 2)) < 0.5
  end

  @testset "Return gives your words to the agent, its answer shows as a page, and the file keeps both" begin
    p = pane()
    typed("Make a table")
    @test p.field.buf.lines == ["Make a table"]
    press(Keys.enter)
    s = p.session
    @test s.busy && p.field.buf.lines == [""] && w.focus === p.field
    # The field slides down from the middle of the page to its foot, and stays there
    whole, foot = named("Agent"), named("Agent foot")
    @test p.parts[:slid][1] > 100px && foot.top + foot.height < whole.top + whole.height - 100px
    sleep(K.TALK_SLIDE)
    frames(w, 2)
    whole, foot = named("Agent"), named("Agent foot")
    @test foot.top + foot.height == whole.top + whole.height && named("Talk").top < whole.top + 40px
    ok = until(() -> !s.busy)
    @test ok && K.running(s) && s.id == "test-session"
    # No page is beside the session, so nothing goes with the words
    said = heard_lines()
    @test length(said) == 1 && occursin("\"content\":\"Make a table\"", said[1]) && !occursin("<ladder>", said[1])
    @test !occursin("<ladder>", K.session_brief(s)) && occursin("mermaid", K.session_brief(s)) && occursin("<ladder>", K.session_brief())
    @test map(typeof, s.items) == [K.YouSaid, K.AgentStep, K.AgentReply] && s.items[1].about == ""
    frames(w, 3)
    reply = named("Reply")
    @test reply !== nothing && named("You said") !== nothing && named("Step") !== nothing
    sub = p.parts[(:reply, objectid(s.items[3]))]
    @test any(it -> it.content isa K.Grid, sub.layout)   # the table is a table, not its text
    @test sub.font == e.font && sub.theme == e.theme && sub.zoom ≈ e.zoom * K.PAGE_TALK / K.TEXT_SIZE
    # The file has it once the agent has done
    ok = until(() -> p.kept == s.version)
    kept = K.read_talk(read(chat, String))
    @test ok && kept.id == "test-session" && map(typeof, kept.items) == [K.YouSaid, K.AgentStep, K.AgentReply]
    @test kept.items[1].words == "Make a table" && kept.items[2].words == "Reading notes.md" && startswith(kept.items[3].text, "## Paint\n\n| Colour")
    @test p.stamp == mtime(chat)
  end

  @testset "A picture that's dropped on the session goes with your words, and its copy is beside the file" begin
    p = pane()
    shot = joinpath(mktempdir(), "drop shot.png")
    cp(joinpath(@__DIR__, "..", "app", "icon.png"), shot)
    w.mouse = typeof(w.mouse)(w.size[1] / 2, w.size[2] / 3)
    onfiledrop(w, [shot]); frames()
    copy = joinpath(dirname(chat), ".media", "drop shot.png")
    @test K.attached(p) == [copy] && read(copy) == read(shot) && w.focus === p.field
    frames()
    @test named("Picture") !== nothing
    # Its button takes it away, with the copy
    K.unattach!(p, copy)
    @test isempty(K.attached(p)) && !isfile(copy)
  end

  @testset "⌘E shows the file's text, and the session comes back as it was" begin
    p = pane()
    s = p.session
    press(Keys.e, Keys.cmd)
    frames(w, 3)
    @test !K.chat_shown(e) && e.buf.view == :text && named("Talk") === nothing
    @test startswith(e.buf.lines[1], "<!-- ladder:session ") && "Make a table" in e.buf.lines
    K.level!(e, 4)
    frames(w, 3)
    @test K.chat_shown(e) && pane() === p && p.session === s && K.running(s) && length(s.items) == 3 && named("Reply") !== nothing
    @test w.focus === p.field
  end

  @testset "The agent works on while the window shows another file, and its tab has the ring" begin
    p = pane()
    s = p.session
    p.field.buf.lines = ["go slow"]
    K.send_words!(p)
    K.open!(e, notes)
    frames(w, 3)
    @test e.buf.path == notes && s.busy && w.focus === e
    @test length(K.tab_marks(e, chat)) == 1   # the ring that turns
    ok = until(() -> !s.busy)
    @test ok && last(s.items) isa K.AgentReply && last(s.items).text == "Slow **words**." && isempty(K.tab_marks(e, chat))
    ok = until(() -> p.kept == s.version)
    @test ok && last(K.read_talk(read(chat, String)).items).text == "Slow **words**."
    @test K.running(s)   # its file has a tab, so its program stays
    K.open!(e, chat)
    frames(w, 3)
    @test K.chat_shown(e) && pane() === p && length(s.items) == 6
  end

  @testset "A change to the file under the session shows in the session" begin
    p = pane()
    s = p.session
    text = read(chat, String)
    sleep(0.02)
    write(chat, replace(text, "Slow **words**." => "Quick **words**."))
    frames(w, 3)
    @test pane() === p && p.session === s && last(s.items).text == "Quick **words**." && K.running(s)
  end

  @testset "Another window shows what was said, and goes on with the session by its name" begin
    e2 = K.build_editor(chat)
    w2 = Window(e2, size=(900px, 700px))
    frames(w2, 4)
    p2 = e2.nodes[(:chat, chat)]
    s2 = p2.session
    @test K.chat_shown(e2) && s2.id == "test-session" && s2.dir == dir && length(s2.items) == 6 && !K.running(s2)
    @test named("Reply", e2) !== nothing && named("You said", e2) !== nothing
    # Claude Code no longer has the session: a new one starts with the same words
    touch(lost)
    n = length(heard_lines())
    p2.field.buf.lines = ["And again"]
    K.send_words!(p2)
    ok = until(() -> !s2.busy && length(heard_lines()) > n, w2)
    @test ok && K.running(s2) && s2.id == "test-session" && !isfile(lost)
    @test occursin("And again", last(heard_lines()))
    tail = s2.items[end-2:end]
    @test tail[1] isa K.YouSaid && tail[2] isa K.SessionNote && !tail[2].bad && occursin("doesn't have this session any more", tail[2].words)
    @test tail[3] isa K.AgentReply && tail[3].text == "Plain **words**."
    # Closing the window ends its agent's program, and the file has all of it
    K.onclose(e2, w2)
    ok = until(() -> !K.running(s2))
    @test ok && length(K.read_talk(read(chat, String)).items) == 9
    frames(w, 3)   # the first window reads the file again
    @test length(pane().session.items) == 9
  end

  @testset "A session with an agent that works by turns goes on by its name" begin
    K.TURN_COMMAND[] = turner
    e.ai = "Codex"
    K.new_agent_session!(e, dir)
    frames(w, 4)
    codex = joinpath(dir, "Codex.chat")
    @test e.buf.path == codex && K.chat_shown(e)
    p = e.nodes[(:chat, codex)]
    s = p.session
    @test s.agent == "Codex" && s.turns && e.buf.about == "Codex in $(basename(dir))"
    p.field.buf.lines = ["Read the plan"]
    K.send_words!(p)
    ok = until(() -> !s.busy)
    @test ok && s.id == "sess-Codex" && last(s.items).text == "It has paint."
    ok = until(() -> p.kept == s.version)
    @test ok && K.read_talk(read(codex, String)).id == "sess-Codex"
    p.field.buf.lines = ["And more"]
    K.send_words!(p)
    ok = until(() -> !s.busy)
    @test ok && startswith(readlines(turns)[1], "Codex||<ladder-brief> You are in Ladder") && endswith(readlines(turns)[1], "Read the plan") && readlines(turns)[2] == "Codex|sess-Codex|And more"
    e.ai = "Claude"
    K.TURN_COMMAND[] = nothing
  end

  @testset "A session's file keeps its model, and the model's button is beside the send button" begin
    empty!(K.MODELS_CHOSEN[])
    file = joinpath(dir, "Haiku.chat")
    write(file, K.talk_mark("session", Dict("agent" => "Claude", "folder" => dir, "id" => "", "model" => "haiku")) * "\n")
    e3 = K.build_editor(file)
    w3 = Window(e3, size=(900px, 700px))
    frames(w3, 4)
    p3 = e3.nodes[(:chat, file)]
    s3 = p3.session
    @test K.chat_shown(e3) && s3.model == "haiku" && K.model_words(p3, e3) == "Haiku 5.5"
    # It shows only while the mouse is over the box that you type in
    @test named("Model", e3) === nothing
    r = K.rect(K.pane_slot(p3))
    w3.mouse = typeof(w3.mouse)(r.left + 12px, r.top + r.height / 2); onmouse(w3, MouseMove(w3.mouse, w3)); frames(w3, 2)
    button, send = named("Model", e3), named("Send", e3)
    @test button !== nothing && button.left + button.width <= send.left && button.top == send.top
    # Another model goes into the file, and the next program starts with it
    K.pane_model!(p3, "sonnet")
    ok = until(() -> K.read_talk(read(file, String)).model == "sonnet", w3)
    @test ok && s3.model == "sonnet" && isempty(s3.items) && K.chosen_model("Claude") == "sonnet"
    options = K.session_options(s3)
    @test options[findfirst(==("--model"), options) + 1] == "sonnet"
    K.onclose(e3, w3)
    empty!(K.MODELS_CHOSEN[])
  end

  @testset "A session whose file has no tab ends its program, and one whose file has gone ends" begin
    K.open!(e, chat)
    frames(w, 3)
    p = pane()
    s = p.session
    p.field.buf.lines = ["Hello"]
    K.send_words!(p)
    ok = until(() -> !s.busy)
    @test ok && K.running(s)
    K.close_tab!(e, chat)
    frames(w, 3)
    ok = until(() -> !K.running(s))
    @test ok && e.buf.path != chat && p in K.chats(e)
    @test last(K.read_talk(read(chat, String)).items).text == "Plain **words**."
    rm(chat)
    frames(w, 3)
    @test !(p in K.chats(e)) && !haskey(e.nodes, (:chat, chat))
  end

  @testset "⌘⇧A starts a session in the folder of the file that shows, from a page and from a session" begin
    K.open!(e, notes)
    frames(w, 3)
    K.focus(e)
    press(Keys.a, Keys.cmd, Keys.shft)
    frames(w, 4)
    first_one = e.buf.path
    @test first_one != notes && dirname(first_one) == dir && occursin(r"^Claude( \d+)?\.chat$", basename(first_one)) && K.chat_shown(e) && e.popup == :none
    p = e.nodes[(:chat, first_one)]
    @test w.focus === p.field && isempty(p.session.items) && p.session.agent == "Claude"
    # From the words of a session, the key is the window's
    press(Keys.a, Keys.cmd, Keys.shft)
    frames(w, 4)
    @test e.buf.path != first_one && endswith(e.buf.path, ".chat") && K.chat_shown(e) && isfile(first_one)
  end

  @testset "The agent works in the folder that the file is in: in a repository's folder too, and when the file names another folder" begin
    repo = joinpath(dir, "repo")
    inner = joinpath(repo, "pages")
    mkpath(inner)
    run(`git init -q $repo`)
    moved = joinpath(inner, "Moved.chat")
    write(moved, K.talk_mark("session", Dict("agent" => "Claude", "folder" => dir, "id" => "")) * "\n")
    K.open!(e, moved)
    frames(w, 3)
    p = e.nodes[(:chat, moved)]
    @test K.chat_shown(e) && p.session.dir == inner && e.buf.about == "Claude in pages"
  end

  @testset "What the agent says runs as a page does: sums, a block of your own and a ui block work, and a drag on a number stays in the file" begin
    folder = joinpath(dir, "parts")
    mkpath(folder)
    cp(joinpath(@__DIR__, "..", "pages", "progress.jl"), joinpath(folder, "progress.jl"))
    kept_file = joinpath(folder, "keep.txt")
    write(kept_file, "")
    said = joinpath(folder, "Parts.chat")
    s = K.AgentSession(agent="Claude", dir=folder)
    push!(s.items, K.YouSaid(words="Show me"), K.AgentReply(text="""
      A wall that is !`l = 16m` long and 2.4m high has an area of !`area = l * 2.4m`.

      ```progress
      done: 0.25
      label: Framing
      ```

      ```ui
      ProgressBar(value = 0.5)
      ```

      ```julia
      rm("$kept_file")
      ```""", whole=true, n=1))
    write(said, K.talk_text(s))
    K.open!(e, said)
    frames(w, 4)
    p = e.nodes[(:chat, said)]
    it = p.session.items[2]
    sub = p.parts[(:reply, objectid(it))]
    made(code) = K.made(sub, code, 1)[1]
    @test !K.foreign(sub.buf.path)
    @test made("l = 16m") == "16m" && made("area = l * 2.4m") == "38.4m²"
    # The block that progress.jl defines draws its bar, and the ui block shows what its code makes
    @test [v.state for v in K.file_blocks(sub)] == [:made]
    @test count(x -> x.content isa K.Live, sub.layout) == 2
    # A julia block shows its code, and doesn't run
    @test isfile(kept_file)
    # A drag on the number changes it, and the sum that uses its name follows
    line = K.item(sub, 1)
    seg, vl = first((seg, vl) for vl in line.content.lines for seg in vl.segs if seg.atomic && seg.node === nothing)
    start = (sub.origin[1] + seg.x + seg.w / 2, sub.origin[2] + line.top + line.content.above + vl.top + vl.high / 2)
    @test K.scrub_at(sub, start) == (1, 21, 23)
    at(pos) = (w.mouse = typeof(w.mouse)(pos...); onmouse(w, MouseMove(w.mouse, w)); frames(w, 1))
    at(start)
    w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(w, 1)
    at(start .+ (10px, 0px))
    @test occursin("!`l = 18m`", sub.buf.lines[1]) && made("area = l * 2.4m") == "43.2m²"
    w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(w, 2)
    @test !haskey(sub.nodes, :scrub)
    # The reply is what the drag left, and the file keeps it
    @test occursin("!`l = 18m`", it.text)
    ok = until(() -> occursin("!`l = 18m`", read(said, String)))
    @test ok
    # While the reply shows no caret, a key changes nothing, even with the keyboard. A click puts a caret there: see the next test.
    K.focus(sub)
    @test w.focus === sub
    ontype(w, Typed('x', w)); press(Keys.backspace)
    @test occursin("!`l = 18m`", sub.buf.lines[1]) && sub.buf.lines == split(rstrip(it.text), '\n')
  end

  @testset "You can change what the agent said, and your next words tell it what changed" begin
    folder = joinpath(dir, "changes")
    mkpath(folder)
    said = joinpath(folder, "Changes.chat")
    s = K.AgentSession(agent="Claude", dir=folder)
    push!(s.items, K.YouSaid(words="How should the logo look?"), K.AgentReply(text="""
      Pick what you like.

      ```ask
      How should the logo look?
      Size: 48px (16px to 96px)
      Colour: #e8632b
      ```""", whole=true, n=1))
    write(said, K.talk_text(s))
    K.open!(e, said)
    frames(w, 4)
    p = e.nodes[(:chat, said)]
    it = p.session.items[2]
    sub = p.parts[(:reply, objectid(it))]
    @test !sub.buf.fixed && sub.buf.reading && !K.writes(sub.buf)
    @test occursin("<changes>", K.session_brief(p.session)) && occursin("Colour: #e8632b", K.session_brief(p.session))
    # A click on the words puts the caret there, and what you type changes them
    line = K.item(sub, 1)
    vl = first(line.content.lines)
    spot = (sub.origin[1] + 1px, sub.origin[2] + line.top + line.content.above + vl.top + vl.high / 2)
    w.mouse = typeof(w.mouse)(spot...); onmouse(w, MouseMove(w.mouse, w)); frames(w, 1)
    w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(w, 1)
    w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(w, 2)
    @test w.focus === sub && !sub.buf.reading && sub.buf.caret == (1, 0)
    typed("Please ")
    @test sub.buf.lines[1] == "Please Pick what you like." && w.focus === sub
    # The slider and the colour picker of its question write what you set into its lines
    v = sub.nodes[(:block, K.ASK, sub.buf.path, 1)]
    K.ask_field(v, 1).value = 64.0
    K.ask_field(v, 2).color = K.HSV(210, 0.8, 0.86)
    frames(w, 2)
    colour = K.colour_hex(K.ask_field(v, 2).color)
    @test sub.buf.lines[5:6] == ["Size: 64px (16px to 96px)", "Colour: $colour"]
    # The reply is what you changed it to, and keeps what the agent saw, as the file does
    @test K.reply_changed(it) && startswith(it.text, "Please Pick") && startswith(it.saw, "Pick what you like.")
    ok = until(() -> occursin("\"saw\"", read(said, String)))
    kept = K.read_talk(read(said, String)).items[2]
    @test ok && kept.saw == it.saw && kept.text == it.text
    # With nothing typed, the send button sends your changes
    @test K.send_tip(p) == "Send with your changes  ⏎"
    K.focus(p.field)
    before = length(heard_lines())
    press(Keys.enter)
    ok = until(() -> !p.session.busy)
    @test ok && length(heard_lines()) == before + 1
    told = heard_lines()[end]
    @test occursin("<changes>", told) && occursin("Your reply 1 of the 1 in this session", told)
    @test occursin("-Pick what you like.", told) && occursin("+Please Pick what you like.", told)
    @test occursin("-Size: 48px (16px to 96px)", told) && occursin("+Size: 64px (16px to 96px)", told) && occursin("+Colour: $colour", told)
    you = p.session.items[3]
    @test you isa K.YouSaid && you.words == "" && you.changed == 1
    frames(w, 3)
    @test named("Your changes") !== nothing
    # The agent knows the reply as it is now, so there's nothing more to send
    @test it.saw === nothing && !K.reply_changed(it) && K.send_tip(p) == "Send  ⏎"
    ok = until(() -> p.kept == p.session.version)
    kept = K.read_talk(read(said, String))
    @test ok && kept.items[2].saw === nothing && kept.items[3].changed == 1
  end

  @testset "A chart in what the agent says shows its buttons while the mouse is on it, as on a page, and a click on one opens its list" begin
    sub = reply_shown(joinpath(dir, "chart"), """
      | Chip | Rent |
      |---|---|
      | H100 | 4.4 |
      | B200 | 9.8 |

      ```chart
      title: Rent
      ```""")
    v = sub.nodes[(:block, K.CHART, sub.buf.path, 1)]
    r = K.rect(v)
    mouse_to((r.left + r.width / 2, r.top + r.height / 2))
    @test K.chart_buttons_shown(v) && K.hittest(w) isa K.PlotArea
    kind = v.parts[:kind]
    r = K.rect(kind)
    mouse_to((r.left + r.width / 2, r.top + r.height / 2))
    click_here()
    @test kind.open
    press(Keys.escape)
    @test !kind.open
  end

  @testset "The commands after a slash work in a session's file: /resume puts an earlier session in the file, and /new makes a new file" begin
    kept = K.CLAUDE_SESSIONS[] = joinpath(dir, "claude-sessions")
    mkpath(kept)
    write(joinpath(kept, "aaaa-1111.jsonl"), """{"type":"user","message":{"role":"user","content":"Paint the fence"}}\n{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"It is **painted**."}]}}\n""")
    K.new_agent_session!(e, dir)
    frames(w, 4)
    file = e.buf.path
    p = e.nodes[(:chat, file)]
    @test K.chat_shown(e) && w.focus === p.field
    menu = K.slash_menu(p)
    typed("/resume ")
    # The list is over the field, which is in the middle of the page before anything is said
    list, slot = only(q for q in K.popups(w) if q.key == K.SLASH_MENU).scene, K.rect(K.pane_slot(p))
    @test [x.title for (_, x) in menu.rows] == ["Paint the fence"] && list.top + list.height <= slot.top && list.top > 0px
    press(Keys.enter)
    s = p.session
    @test s.id == "aaaa-1111" && [typeof(i) for i in s.items] == [K.YouSaid, K.AgentReply] && K.running(s) && p.field.buf.lines == [""]
    ok = until(() -> p.kept == s.version)
    saved = K.read_talk(read(file, String))
    # The file keeps that session now, and the agent goes on with it
    @test ok && saved.id == "aaaa-1111" && saved.items[1].words == "Paint the fence" && saved.items[2].text == "It is **painted**."
    @test "aaaa-1111" in K.session_options(s)
    typed("And the gate")
    press(Keys.enter)
    ok = until(() -> !s.busy && last(s.items) isa K.AgentReply)
    @test ok && s.id == "aaaa-1111" && length(s.items) == 4 && occursin("And the gate", last(heard_lines()))
    # /new makes a new file for a new session beside this one, which stays
    typed("/new")
    press(Keys.enter)
    frames(w, 4)
    @test e.buf.path != file && K.chat_shown(e) && isfile(file) && isempty(K.read_talk(read(e.buf.path, String)).items)
    @test K.read_talk(read(file, String)).id == "aaaa-1111"
    K.CLAUDE_SESSIONS[] = ""
  end
finally
  K.SESSION_COMMAND[] = nothing
  K.TURN_COMMAND[] = nothing
  foreach(p -> p.session === nothing || K.close!(p.session), K.chats(e))
end
