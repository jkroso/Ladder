# A session with an agent: what it holds, how each agent speaks, and the commands and earlier sessions it has
#
# A session is a talk with one agent, in one folder: what you said, what the
# agent replied, each step that it took, and what it asks you before a step.
# It has no window of its own. The agent's pane shows it in agent mode (see
# pane.jl), a session's file shows it in the page, and Ask Agent can
# give a request to it (see ask.jl).
#
# Each agent speaks to Ladder in its own way. Claude Code's program stays for
# the session and prints a line of JSON for each thing that it does.
# Antigravity and Grok speak the Agent Client Protocol (ACP). Codex does one
# thing and ends, so a session with it starts it again for each turn.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/Semantic/Recorder" stop!
@use "../for_agents" => Offer
@use "../for_agents" on_main
@use "../repl" => Repls
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/JSON.jl" JSONObject json_value write_json
@use Dates: Dates
@use Base64: base64encode
@use "../base" exports...
@use "./kinds" exports...

export YouSaid, AgentReply, AgentStep, AgentWants, SessionNote, RanBeside, newest, agent_newest, AgentSession, SESSION_COMMAND, BRIEF_SHOWS,
       session_brief, session_command, session_options, running, note!, start!, ended!, tell!, user_message,
       pictures_note, AGENT_PICTURE_KINDS, AGENT_PICTURE_MOST, picture_block, sendable_picture, model!,
       model_note!, close!, step_of, open_reply, take_line!, model_answer!, stream_event!, step_file,
       tool_words, tool_icon, ACP_COMMAND, AcpTalk, ACP_OPTIONS, speaks_acp, by_turns, acp_call!, acp_reply!,
       acp_start!, acp_session!, acp_model!, acp_ready!, acp_failed!, acp_prompt!, acp_message, acp_stop!,
       acp_line!, acp_answer!, acp_update!, acp_tool, acp_input, acp_step!, acp_asks!, acp_choose!, has_code,
       agent_shown, repl!, AGENT_LOOKS, agent_looks, a_look, LOOK_MOST, window_picture, code_asks!,
       release_code!, code_config, code_servers, code_step, code_tool, guide_once!, BRIEF_CODE, BRIEF_SHOWN,
       TURN_COMMAND, TOOL_NAMES, turn_command, turn_options, fault_line, turn_ended!, more_words!, end_words!,
       tool_step!, step_ended!, turn_step, turn_line!, fault_words, antigravity_input, ANTIGRAVITY_KEYS,
       opening_line, codex_line!, SlashCommand, OWN_COMMANDS, AGENT_COMMANDS, EarlierSession, commands!,
       one_line_of, claude_commands, acp_commands, own_command, slash_commands, slash_named, goes_bare,
       BESIDE_COMMANDS, goes_beside, beside_command, run_beside!, beside_said,
       ran_note!, your_words, HISTORY_MOST, recent_part, iso_time, ago_words, CLAUDE_SESSIONS, SESSIONS_MOST,
       TITLE_READS, claude_folders, quick_field, claude_said, claude_title, claude_sessions, claude_history,
       acp_list!, acp_sessions, session_loaded!, resume!, pane_agent, on_page

"Words that you gave the agent. `about` is what the window showed then, like the heading that the caret was under. `pictures` are the files of the pictures that went with them, and `changed` is how many of the agent's replies you had changed."
@def mutable struct YouSaid
  words::String = ""
  about::String = ""
  pictures::Vector{String} = String[]
  changed::Int = 0
end

"""
What the agent said, as Markdown. `whole` is false while its words still
come, and `n` goes up with each change to them. `saw` is what the agent last
saw of it, when you changed it since: see "what you change in a reply".
"""
@def mutable struct AgentReply
  text::String = ""
  whole::Bool = false
  n::Int = 0
  saw::Union{Nothing,String} = nothing
end

"A step that the agent took with a tool, like reading a file. `words` say what it does, and `state` is :going, :done or :failed."
@def mutable struct AgentStep
  id::String = ""
  tool::String = ""
  words::String = ""
  state::Symbol = :going
end

"""
Something that the agent asks to do, which your settings make it ask for.
`detail` is the command of a shell command. `answer` is :none until you
allow it or refuse it.
"""
@def mutable struct AgentWants
  id::String = ""
  tool::String = ""
  words::String = ""
  detail::String = ""
  input::Any = nothing
  answer::Symbol = :none
end

"A line that the session says of itself, like that the agent stopped. `bad` is true for something that went wrong."
@def mutable struct SessionNote
  words::String = ""
  bad::Bool = false
end

"""
A command of the agent's, like /usage, that you gave while the agent worked,
and that a program of its own ran beside the turn: see `run_beside!`. `words`
are the command, and `reply` is what it printed, whole once the command has
done. `bad` is true when it failed, and `reply` then says why.
"""
@def mutable struct RanBeside
  words::String = ""
  reply::AgentReply = AgentReply()
  bad::Bool = false
end

"""
The newest of `items` that's part of the agent's turns or of your words, or
nothing. A command that ran beside a turn is no part of them: the agent's
words go on in the reply that it was writing when you gave the command.
"""
newest(items) = (k = findlast(it -> !(it isa RanBeside), items); k === nothing ? nothing : items[k])

"""
The newest of `items` that the agent's turns made, or nothing. Words that
you gave while the agent worked come after it, and wait for its turn to end,
so the reply that it was writing goes on over them. So does a command that
ran beside the turn.
"""
agent_newest(items) = (k = findlast(it -> !(it isa RanBeside || it isa YouSaid), items); k === nothing ? nothing : items[k])

"""
A session of an agent in a window: the program, the folder that it runs in,
and all that you and it said, in order. `page` is the file that the window
showed when it started, which the agent can change without asking. `id` is
the name that the agent gives the session, to go on with it after its
program has stopped. `busy` is true while the agent works on what you said.
`version` goes up with each thing that changes, so the window knows to draw.
"""
@def mutable struct AgentSession
  agent::String = "Claude"
  dir::String = ""
  page::String = ""
  process::Any = nothing
  to::Any = nothing            # the agent reads this: each line is a message
  items::Vector{Any} = Any[]
  busy::Bool = false
  id::String = ""
  version::Int = 0
  closing::Bool = false        # Ladder ended the program itself
  asked::Int = 0               # how many messages of its own Ladder has sent the program
  turns::Bool = false          # the agent's program runs once for each thing that you say: see "an agent that works by turns"
  stopped::Bool = false        # you stopped the turn that's under way
  queue::Vector{String} = String[]   # what you said while a turn was under way, for the turns after it
  file::String = ""            # the file that keeps the session, or "" for the session of agent mode: see "a session's file"
  sent::String = ""            # the last thing that Ladder gave the program from you
  model::String = ""           # the model that you chose, by the name that the agent's command is given, or "" for the agent's own choice
  running::String = ""         # the model that the agent says it works with now, by its full name, or "" before it says
  was_model::String = ""       # the model before the change that Ladder asked Claude Code for, which comes back if Claude Code says no
  later::Any = nothing         # a note on a new model, with whether it's bad, to show when the agent has done: see `model_note!`
  talk::Any = nothing          # Ladder's talk with Antigravity's program: see `AcpTalk`
  repl::Any = nothing          # the Julia code that the agent runs inside Ladder: see "the code that an agent runs"
  brief::String = ""           # what the agent is told of where it is, when it's other than what a pane's session is told
  earlier::Any = nothing       # the earlier sessions of the folder, the newest first, once Ladder has looked for them: see "the commands of a session"
  looking::Bool = false        # Ladder waits for the agent's list of its earlier sessions
  loading::Bool = false        # the agent gives what was said in an earlier session, which the session goes on with
  before::Any = nothing        # the session's name and what it showed before it went on with an earlier one, which come back if the agent can't open that one
  unbriefed::Bool = false      # the agent's session was made outside Ladder, so your next words tell it what Ladder says of itself
  beside::Int = 0              # how many of the agent's commands run beside its turn now, each in a program of its own: see `run_beside!`
end

"A command that a test puts in the place of the agent's: a program that reads and prints the same lines of JSON. Nothing means the agent that Settings chose."
const SESSION_COMMAND = Ref{Any}(nothing)

"What every session is told of how Ladder shows the agent's words"
const BRIEF_SHOWS = "Ladder draws what you say as a page, not as a terminal's text: Markdown with headings, lists, tables, to-do boxes, maths, `mermaid` diagrams and `chart` blocks. So answer as a short page, and use a table, a diagram or a chart where it says a thing better than words. A chart is a `chart` code block: a line `kind: bars`, `kind: lines` or `kind: pie`, an empty line, then rows with ` | ` between the cells, and the names of the columns in the first row. Ladder draws these kinds of Mermaid diagram and no others: flowchart, sequenceDiagram, stateDiagram-v2, classDiagram, pie, mindmap, erDiagram, gantt and timeline. Your answers can also have the parts of a page that run code, and they work as they do in a page. A sum in a line of text is a `!` and then Julia code between backticks, like !`area = 4m * 2.5m`: Ladder shows what it comes to, the user can drag a number in it, like the 4m, and each sum that uses its name follows. A number can have a unit of Units.jl, like m, kg, hr or USD. Write 70% as 0.7. A `sheet` block is a list of rows, each a name, `=`, and a number or a sum, like `Width = 4m`. A `ui` block holds Julia code that makes one of UI.jl's components, like `ProgressBar(value=0.7)`, and shows it. A block in a language that a Julia file of the folder you started in defines, like `progress` for progress.jl, shows what that file makes. A `julia` block shows as code and doesn't run. To ask the user a question, write an `ask` block: the question on its first lines, then `( ) answer` for each answer when the user picks one, or `[ ] answer` when they can pick many. In an `ask` block, a line like `Size: 48px (16px to 96px)` is a slider, and a line like `Colour: #e8632b` is a colour to pick. The user can change what you said: type in it, drag a number, choose an answer, move a slider or pick a colour. Ladder writes each change into your words. The user's next message then starts with what they changed since you last saw it, between <changes> and </changes>: a diff of each reply that changed, from what you last saw to what it says now. A message can be only that block, when the user sent their changes with no words. If you have a skill for Ladder's pages, it says more about what a page can show."

"""
What the agent is told of where it is, on top of what it's always told: that
its words show as a page, and how to read the block at the start of each
message. With `alone`, the session has the window to itself, and no page is
beside it: see "a session's file".
"""
session_brief(alone::Bool=false) = alone ? """
You are in Ladder, a Markdown app on the user's Mac. The user's window shows this conversation and nothing else, in place of a terminal. $BRIEF_SHOWS A link to a file, like [notes.md](notes.md), opens that file in the user's window when the user clicks it. Paths in links are from the folder that you started in.""" : """
You are in Ladder, a Markdown app on the user's Mac. The user's window shows a page, with this conversation beside it. $BRIEF_SHOWS Answer a question here, in the conversation, and change the page only when the user asks for a change to it.

Each message of the user starts with a block between <ladder> and </ladder>. Ladder wrote the block, not the user. It says which file the window shows, which section of it is in view, where the caret is, and what is selected. The section in view is the one at the top of the window. A web page that an HTML file makes has no lines or columns. Its block gives the exact text of a selection, and the paragraph that holds it between <paragraph> and </paragraph>. When nothing is selected, the caret is where the user last clicked, and the block gives the words before it and its paragraph. These are the words as the page shows them. Where Ladder can tell, the block also gives their lines and columns in the HTML file, which can have tags and entities between the words. Lines and columns count from 1. A column is a place between characters: column 1 is before the first character of its line, so a selection ends before the character at its end column. The exact text of a selection is between <selection> and </selection>: it starts after the line break that follows <selection>, and ends before the line break in front of </selection>. Ladder saves the page to its file before each message, so the file has what the window shows, unless the block says otherwise. When the user asks for a change to the page, change its file: Ladder shows the change at once. Don't run `ladder show` or `ladder wait`: the page is open already, and the user talks to you here."""

"What the agent of the session `s` is told of where it is: a session with a file of its own has no page beside it"
session_brief(s::AgentSession) = (isempty(s.brief) ? session_brief(!isempty(s.file)) : s.brief) * (has_code(s) ? "\n\n" * BRIEF_CODE * (isempty(s.file) ? " " * BRIEF_SHOWN : "") : "")

"""
The command that starts the program of the session `s`: Claude Code, which
reads and prints lines of JSON. It asks Ladder before anything that your
settings make it ask for, and it changes the session's page without asking.
When the session has a name, it goes on with the session of that name.
Antigravity's is `agy acp` and Grok's is `grok agent stdio`: see
"Antigravity and Grok, which ask you before a step".
"""
session_command(s::AgentSession) = begin
  speaks_acp(s) && return ACP_COMMAND[] === nothing ? kind_command(agent_kind(s.agent), ACP_OPTIONS[agent_kind(s.agent).name]) : ACP_COMMAND[]
  SESSION_COMMAND[] === nothing || return `$(SESSION_COMMAND[]) $(session_options(s))`
  kind_command(agent_kind(s.agent), session_options(s))
end

"The options of the command that starts the program of the session `s`: see `session_command`"
session_options(s::AgentSession) = begin
  page, id = s.page, s.id
  # A rule with // names a file from the top of the disk. A rule can't hold some characters, so such a file has none, and the agent asks.
  rule = !isempty(page) && occursin(r"^[\w \-./@+~]+$", page) ? ["Edit(/$page)"] : String[]
  # The agent runs Julia code in Ladder without asking, since the sandbox asks you for what could harm, and it reads the pictures that `look()` saves
  looks = occursin(r"^[\w \-./@+~]+$", agent_looks()) ? ["Read(/$(agent_looks())/**)"] : String[]
  # --allowedTools takes all that comes after it as its list, so it's last
  ["-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose", "--include-partial-messages",
   "--permission-prompt-tool", "stdio", "--append-system-prompt", session_brief(s),
   (isempty(s.model) ? String[] : ["--model", s.model])..., (isempty(id) ? String[] : ["--resume", id])...,
   "--mcp-config", code_config(s), "--allowedTools", "mcp__ladder__julia", looks..., rule...]
end

"True while the program of the session `s` runs"
running(s::AgentSession) = s.process !== nothing && process_running(s.process)

"Put the line `words` in what the session `s` shows, as something that the session says of itself"
note!(s::AgentSession, words, bad=false) = (push!(s.items, SessionNote(words=String(words), bad=bad)); s.version += 1; s)

"""
Start the program of the session `s` with `command`. A task reads each line
that it prints, as the window gives it its turn: see `session_tick!`.
"""
start!(s::AgentSession, command::Cmd) = begin
  to, out, err = Pipe(), Pipe(), Pipe()
  process = run(pipeline(Cmd(command; dir=s.dir), stdin=to, stdout=out, stderr=err), wait=false)
  close(out.in)   # only the program writes to them now, so reading ends when the program does
  close(err.in)
  close(to.out)
  s.process, s.to, s.closing = process, to, false
  speaks_acp(s) && acp_start!(s)
  # Claude Code's first answer lists its commands: see "the commands of a session"
  s.turns || speaks_acp(s) || tell!(s, Dict("type" => "control_request", "request_id" => "ladder-start", "request" => Dict("subtype" => "initialize")))
  wrong = @async read(err, String)
  @async begin
    for line in eachline(out)
      s.process === process || break   # the session has another program now: see `resume!`
      try
        take_line!(s, line)
      catch err
        note!(s, "Ladder couldn't read a line that $(s.agent) printed: $(sprint(showerror, err))", true)
      end
    end
    said = try fetch(wrong) catch; "" end
    wait(process)
    # A program that Ladder started since has the session now
    s.process === process && ended!(s, said)
  end
  s
end

"The program of the session `s` has ended, and `wrong` is what it wrote of what went wrong"
ended!(s::AgentSession, wrong) = begin
  was = s.busy
  settle!(s)
  s.looking = false
  # An earlier session that the program was still loading isn't there: the one before comes back
  s.loading && ((s.loading = false); s.before === nothing || ((s.id, s.items) = s.before); s.before = nothing)
  s.repl === nothing || Repls.hang_up!(s.repl)   # the program that reached the code has gone
  # The agent no longer has a session that a file kept, like one of another Mac. A new one starts, with the words that you just said.
  if !s.closing && !isempty(s.id) && !isempty(s.sent) && occursin("No conversation found", wrong)
    s.id = ""
    k = something(findlast(it -> it isa YouSaid, s.items), 0)
    deleteat!(s.items, [i for i in k+1:length(s.items) if s.items[i] isa SessionNote])   # what the lost session said of its end
    note!(s, "$(s.agent) doesn't have this session any more, so a new one starts here. It doesn't know what was said before.")
    started = try
      start!(s, session_command(s))
      tell!(s, user_message(s.sent, k == 0 ? String[] : s.items[k].pictures))
      true
    catch err
      note!(s, err isa ErrorException ? err.msg : "Ladder couldn't start $(s.agent): $(sprint(showerror, err))", true)
      false
    end
    s.busy = started
    s.version += 1
    return s
  end
  if !s.closing
    lines = filter(!isempty, strip.(split(wrong, '\n')))
    note!(s, isempty(lines) ? "$(s.agent) stopped. Your next words start it again." : "$(s.agent) stopped: $(last(lines))", was || !success(s.process))
  end
  s.version += 1
  s
end

"The agent has done with what you said: nothing of the session `s` is still under way"
settle!(s::AgentSession) = begin
  s.busy = false
  release_code!(s)
  for it in s.items
    it isa AgentReply && !it.whole && (it.whole = true; it.n += 1)
    it isa AgentStep && it.state == :going && (it.state = :done)
    it isa AgentWants && it.answer == :none && (it.answer = :gone)
  end
  s.later === nothing || (note!(s, s.later...); s.later = nothing)
  s
end

"Write the message `o` to the program of the session `s`, as a line of JSON. A task writes it, so a program that's slow to read holds nothing up."
tell!(s::AgentSession, o) = begin
  to, line = s.to, sprint(write_json, o) * "\n"
  to === nothing || @async try write(to, line) catch end
  nothing
end

"Give the agent of the session `s` the words `words`. `about` is what the window shows, and `told` says it to the agent."
say!(s::AgentSession, words, about="", told=""; pictures=String[], changed=0, bare=false) = begin
  push!(s.items, YouSaid(words=String(words), about=String(about), pictures=copy(pictures), changed=changed))
  # A session that was made outside Ladder doesn't know of Ladder yet. A command of the agent's goes as it is: see `send_words!`.
  if s.unbriefed && !bare
    told = join(filter(!isempty, ["<ladder-brief>\n$(session_brief(s))\n</ladder-brief>", String(told)]), "\n\n")
    s.unbriefed = false
  end
  content = join(filter(!isempty, [String(told), String(words), isempty(pictures) ? "" : pictures_note(s, pictures)]), "\n\n")
  s.sent = content
  if speaks_acp(s)
    acp_prompt!(s, acp_message(content, pictures))
  elseif !s.turns
    tell!(s, user_message(content, pictures))
  elseif s.busy
    push!(s.queue, content)   # the agent's program takes one thing at a time
  else
    turn!(s, content)
  end
  s.busy = true
  s.version += 1
  s
end

"""
What Ladder writes to Claude's program for your words: the message with
`content`, the text, and before it each of `pictures` as a picture, for
Claude to see. A picture that can't be read is left out: its file's path is
in the text.
"""
user_message(content, pictures=String[]) = begin
  shown = filter(!isnothing, [picture_block(path) for path in pictures])
  said = isempty(shown) ? content : Any[shown..., Dict("type" => "text", "text" => content)]
  Dict("type" => "user", "message" => Dict("role" => "user", "content" => said))
end

"The words that say which files the pictures `pictures` are in. An agent that works by turns has only these words, and reads the files."
pictures_note(s::AgentSession, pictures) =
  (s.turns ? "With these words come these pictures, in files that you can read:\n" : "The pictures with these words are also in these files:\n") * join(pictures, "\n")

# The kinds of picture that Claude takes, and how many bytes one can have. Claude takes 5 MB of base64, which is 3.75 MB of bytes.
const AGENT_PICTURE_KINDS = Dict(".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg", ".gif" => "image/gif", ".webp" => "image/webp")
const AGENT_PICTURE_MOST = 3_500_000

"The picture in the file at `path` as a part of a message to Claude, or nothing when it can't be read"
picture_block(path) = try
  file = sendable_picture(path)
  Dict("type" => "image", "source" => Dict("type" => "base64", "media_type" => AGENT_PICTURE_KINDS[lowercase(splitext(file)[2])], "data" => base64encode(read(file))))
catch
  nothing
end

"""
The file at `path`, or a copy of it that Claude takes: a PNG file, or a JPEG
file when the PNG has too many bytes, no more than 1568 pixels on its longer
side. Claude makes a picture that size itself, so nothing is lost. macOS's
`sips` makes the copy.
"""
sendable_picture(path) = begin
  haskey(AGENT_PICTURE_KINDS, lowercase(splitext(path)[2])) && filesize(path) <= AGENT_PICTURE_MOST && return path
  out = joinpath(mktempdir(), "picture.png")
  run(pipeline(`sips -Z 1568 -s format png $path --out $out`, stdout=devnull, stderr=devnull))
  filesize(out) <= AGENT_PICTURE_MOST && return out
  jpeg = joinpath(dirname(out), "picture.jpg")
  run(pipeline(`sips -s format jpeg -s formatOptions 80 $out --out $jpeg`, stdout=devnull, stderr=devnull))
  jpeg
end

"Stop what the agent of the session `s` is doing. The session goes on, and what the agent changed so far stays."
stop!(s::AgentSession) = begin
  s.busy || return s
  if s.turns
    # The turn's program ends, and with it what you said after. The session's name stays, so your next words go on from here.
    s.stopped = true
    empty!(s.queue)
    running(s) && try kill(s.process) catch end
  elseif speaks_acp(s)
    acp_stop!(s)
  else
    tell!(s, Dict("type" => "control_request", "request_id" => "ladder-$(s.asked += 1)", "request" => Dict("subtype" => "interrupt")))
  end
  s
end

"Allow what the agent asks to do with `it`, or with `allow` false refuse it"
answer!(s::AgentSession, it::AgentWants, allow::Bool) = begin
  it.answer == :none || return s
  it.answer = allow ? :allowed : :refused
  if it.input isa Channel
    isready(it.input) || put!(it.input, allow)   # the agent's code waits for this: see `code_asks!`
  elseif speaks_acp(s)
    acp_choose!(s, it, allow ? "allow_once" : "reject_once")
  else
    said = allow ? Dict("behavior" => "allow", "updatedInput" => it.input) : Dict("behavior" => "deny", "message" => "The user refused this in Ladder.")
    tell!(s, Dict("type" => "control_response", "response" => Dict("subtype" => "success", "request_id" => it.id, "response" => said)))
  end
  s.version += 1
  s
end

"""
Make the model `id` the one that the agent of the session `s` works with.
The programs of Claude Code, Antigravity and Grok change their model while
they run, and say when they have: see `take_line!` and `acp_answer!`. Any
other agent, and a program that has stopped, gets the model when it starts
again, with your next words. So does an ACP program while it starts.
"""
model!(s::AgentSession, id::AbstractString) = begin
  id = String(id)
  if speaks_acp(s) && running(s) && s.talk !== nothing && s.talk.ready && !isempty(id)
    was, s.model = s.model, id
    acp_call!(s, "session/set_model", Dict("sessionId" => s.id, "modelId" => id), (:model, id, was))
  elseif !s.turns && !speaks_acp(s) && running(s)
    s.was_model = s.model
    s.model = id
    request = Dict{String,Any}("subtype" => "set_model")
    isempty(id) || (request["model"] = id)   # with no model, Claude Code goes back to its own choice
    tell!(s, Dict("type" => "control_request", "request_id" => "ladder-model-$(s.asked += 1)", "request" => request))
  else
    s.model == id && return s
    s.model, s.running = id, ""
    isempty(s.items) || model_note!(s, "The model is now $(isempty(id) ? "$(s.agent)'s own choice" : model_name(s.agent, id)).")
  end
  s.version += 1
  s
end

"""
Show the note `words` on the model of the session `s`. While the agent
works, it waits for the agent to finish, so it doesn't split what the
agent says.
"""
model_note!(s::AgentSession, words, bad=false) = s.busy ? (s.later = (String(words), bad); s) : note!(s, words, bad)

"End the program of the session `s`"
close!(s::AgentSession) = begin
  s.closing = true
  settle!(s)
  s.to === nothing || try close(s.to) catch end
  s.repl === nothing || Repls.close!(s.repl)
  running(s) && try kill(s.process) catch end
  s
end

"The step of the session `s` that the agent names `id`, or nothing"
step_of(s::AgentSession, id) = (k = findlast(it -> it isa AgentStep && it.id == id, s.items); k === nothing ? nothing : s.items[k])

"The reply that the agent of the session `s` is writing, or nothing. Your words that wait for its turn to end can come after it, and so can a command that ran beside the turn."
open_reply(s::AgentSession) = (it = agent_newest(s.items); it isa AgentReply && !it.whole ? it : nothing)

"""
Take a line that the program of the session `s` printed. Each line is JSON
with a `type`:

- `stream_event` is a piece of what the agent is writing now: the start of a
  block of words or of a tool's use, or more words of a block.
- `assistant` is a block that's whole: its words, or a tool with what it's given.
- `user` holds what a tool came to, which ends its step.
- `control_request` asks you whether the agent may use a tool.
- `result` ends the agent's work on what you said.
"""
take_line!(s::AgentSession, line::AbstractString) = begin
  o = agent_json(line)
  o === nothing && return s
  # Antigravity's program prints lines of JSON-RPC
  speaks_acp(s) && (acp_line!(s, o); s.version += 1; return s)
  kind = json_field(o, "type")
  # What an agent that this one started says to it is theirs. This session shows only the step that started it.
  json_field(o, "parent_tool_use_id") === nothing || return s
  if kind == "system"
    id, model = json_field(o, "session_id"), json_field(o, "model")
    json_field(o, "subtype") == "init" && id isa String && (s.id = id)
    # Each turn starts with this, and it names the model that works on it
    json_field(o, "subtype") == "init" && model isa String && (s.running = model)
    # Its commands changed, as when a skill was added
    json_field(o, "subtype") == "commands_changed" && commands!(s, claude_commands(json_field(o, "commands")))
    # Its /compact, or Claude Code itself when the session grew long
    json_field(o, "subtype") == "compact_boundary" && note!(s, "$(s.agent) summed up what was said so far, to make room.")
  elseif kind == "control_response"
    r = json_field(o, "response")
    json_field(r, "request_id") == "ladder-start" ? commands!(s, claude_commands(json_field(json_field(r, "response"), "commands"))) : model_answer!(s, r)
  elseif kind == "stream_event"
    stream_event!(s, json_field(o, "event"))
  elseif kind == "assistant"
    parts = json_field(json_field(o, "message"), "content")
    for p in (parts isa AbstractVector ? parts : ())
      what = json_field(p, "type")
      if what == "text" && json_field(p, "text") isa String
        # Its words came piece by piece already, when the program sends pieces. This is all of them.
        reply = open_reply(s)
        reply === nothing && (reply = AgentReply(); push!(s.items, reply))
        reply.text, reply.whole = json_field(p, "text"), true
        reply.n += 1
      elseif what == "tool_use"
        id, name = json_field(p, "id"), json_field(p, "name")
        (id isa String && name isa String) || continue
        step = step_of(s, id)
        step === nothing && (step = AgentStep(id=id, tool=name); push!(s.items, step))
        step.words = tool_words(name, json_field(p, "input"))
      end
    end
  elseif kind == "user"
    parts = json_field(json_field(o, "message"), "content")
    for p in (parts isa AbstractVector ? parts : ())
      json_field(p, "type") == "tool_result" || continue
      step = step_of(s, json_field(p, "tool_use_id"))
      step === nothing || (step.state = json_field(p, "is_error") === true ? :failed : :done)
    end
  elseif kind == "control_request"
    r = json_field(o, "request")
    id, name = json_field(o, "request_id"), json_field(r, "tool_name")
    if json_field(r, "subtype") == "can_use_tool" && id isa String && name isa String
      input = json_field(r, "input")
      command = json_field(input, "command")
      push!(s.items, AgentWants(id=id, tool=name, input=input, words=lowercasefirst(tool_words(name, input)),
                                detail=name == "Bash" && command isa String ? command : ""))
    end
  elseif kind == "result"
    settle!(s)
    said = json_field(o, "result")
    # A turn that you stopped ends with an error of its own, which is no news
    json_field(o, "is_error") === true && json_field(o, "subtype") != "error_during_execution" &&
      note!(s, said isa String && !isempty(said) ? said : "$(s.agent) couldn't do that.", true)
    json_field(o, "subtype") == "error_during_execution" && note!(s, "You stopped $(s.agent).")
    json_field(o, "is_error") === true || ran_note!(s, said isa String ? said : "")
  end
  s.version += 1
  s
end

"""
Take Claude Code's answer `r` to a change of model that Ladder asked for: the
model that it works with now. When it says no, the model before stays, and
the session says why.
"""
model_answer!(s::AgentSession, r) = begin
  asked = json_field(r, "request_id")
  (asked isa String && startswith(asked, "ladder-model-")) || return s
  if json_field(r, "subtype") == "success"
    model = json_field(json_field(r, "response"), "model")
    model isa String && (s.running = model)
    isempty(s.items) || model_note!(s, "The model is now $(model_name(s.agent, s.running)).")
  else
    model = json_field(r, "model")
    model isa String && (s.running = model)
    # A new session would start with the model that failed, so it starts with the one before
    chosen_model(s.agent) == s.model && (MODELS_CHOSEN[][s.agent] = s.was_model)
    s.model = s.was_model
    why = json_field(r, "error")
    model_note!(s, "$(s.agent) didn't change its model" * (why isa String && !isempty(why) ? ": $why" : "."), true)
  end
  s
end

"Take a piece of what the agent of the session `s` is writing now: the start of a block, or more of a block's words"
stream_event!(s::AgentSession, ev) = begin
  kind = json_field(ev, "type")
  if kind == "content_block_start"
    block = json_field(ev, "content_block")
    what = json_field(block, "type")
    if what == "text"
      open_reply(s) === nothing && push!(s.items, AgentReply())
    elseif what == "tool_use"
      id, name = json_field(block, "id"), json_field(block, "name")
      id isa String && name isa String && step_of(s, id) === nothing && push!(s.items, AgentStep(id=id, tool=name, words=tool_words(name, nothing)))
    end
  elseif kind == "content_block_delta"
    delta = json_field(ev, "delta")
    more = json_field(delta, "text")
    if json_field(delta, "type") == "text_delta" && more isa String
      reply = open_reply(s)
      reply === nothing && (reply = AgentReply(); push!(s.items, reply))
      reply.text *= more
      reply.n += 1
    end
  end
  s
end

"The name of the file at `path`, for a step's words"
step_file(path) = path isa String ? basename(path) : "a file"

"""
What a step with the tool `name` does, in a few words, from what the tool is
given: "Reading main.jl", "Changing main.jl", "Looking for wide(". `input`
is nothing while the agent still writes it.
"""
tool_words(name::AbstractString, input) = begin
  get(key) = (v = json_field(input, key); v isa String ? replace(strip(v), r"\s+" => " ") : "")
  # Other agents than Claude call a file's place by other names
  file = something(json_field(input, "file_path"), json_field(input, "target_file"), json_field(input, "absolute_path"), json_field(input, "path"), Some(nothing))
  name == "Read" ? "Reading $(step_file(file))" :
  name in ("Edit", "Write", "MultiEdit", "NotebookEdit") ? "Changing $(step_file(something(file, json_field(input, "notebook_path"), Some(nothing))))" :
  name == "Grep" ? "Looking for $(isempty(get("pattern")) ? get("query") : get("pattern"))" :
  name == "List" ? "Listing $(file isa String ? basename(rstrip(file, '/')) : "a folder")" :
  name == "Glob" ? "Looking for files like $(get("pattern"))" :
  name == "Bash" ? (isempty(get("description")) ? (isempty(get("command")) ? "Running a command" : "Running $(get("command"))") : get("description")) :
  name == "WebSearch" ? "Searching the web for $(get("query"))" :
  name == "WebFetch" ? "Reading $(get("url"))" :
  name in ("Task", "Agent") ? (isempty(get("description")) ? "Starting an agent" : "An agent: $(get("description"))") :
  name == "TodoWrite" ? "Planning the work" :
  name == "Skill" ? "Using the skill $(get("skill"))" :
  name == "search_tool" ? "Looking for a tool" :   # Grok looks through the tools of its tool servers before it uses one
  code_tool(name) ? code_step(json_field(input, "code")) :
  startswith(name, "mcp__") ? "Using $(replace(replace(name, r"^mcp__" => ""), "__" => ": ", "_" => " "))" : "Using $name"
end

"The icon of a step with the tool `name`"
tool_icon(name::AbstractString) =
  name == "Read" ? "file-earmark-text" : name in ("Edit", "Write", "MultiEdit", "NotebookEdit") ? "pencil" :
  name in ("Grep", "Glob", "search_tool") ? "search" : name == "List" ? "folder" : name == "Bash" || code_tool(name) ? "terminal" : name in ("WebSearch", "WebFetch") ? "globe" :
  name in ("Task", "Agent") ? "robot" : name == "TodoWrite" ? "list-task" : "gear"

# --- Antigravity and Grok, which ask you before a step ---
#
# Antigravity's program `agy acp` stays for a whole session, as Claude
# Code's does, and so does Grok's, `grok agent stdio`. Each speaks the Agent
# Client Protocol (ACP), which editors like Zed speak with their agents:
# lines of JSON-RPC both ways. Ladder asks the program for a new session, or
# for the one of the session's name, and gives it your words with
# `session/prompt`. The agent tells Ladder each piece of its words and each
# step with `session/update`. Before a step that its settings make it ask
# for, like a shell command, it sends `session/request_permission`, and the
# pane shows Allow and Refuse. Ladder ran `agy -p` and `grok -p` before, which
# have no one to ask, and which can't take a tool from Ladder.
#
# A session with Antigravity is in its accept-edits mode: it changes files in
# the session's folder without asking, and asks before anything else that its
# settings don't allow. Grok has no such mode to set. It asks as its own
# settings say: with `permission_mode = "always-approve"` in
# ~/.grok/config.toml it never asks.
#
# Grok's program also sends lines of its own, whose method starts with
# `_x.ai/`: how its tool servers start, its hooks, its notices. Ladder
# leaves them out.

"A command that a test puts in the place of `agy acp` or `grok agent stdio`: a program that reads and prints the same lines of JSON-RPC"
const ACP_COMMAND = Ref{Any}(nothing)

"""
What Ladder keeps of its talk with the ACP program of a session: the number
of its last request, what each request that has no answer yet is for,
whether the program has the session, so that your words can go to it, and
what you said that waits for that, or for the end of the turn under way.
"""
@def mutable struct AcpTalk
  n::Int = 0
  calls::Dict{String,Any} = Dict{String,Any}()
  ready::Bool = false
  held::Vector{Any} = Any[]
end

"What comes after an agent's command to start its ACP program: `agy acp`, `grok agent stdio`"
const ACP_OPTIONS = Dict("Antigravity" => ["acp"], "Grok" => ["agent", "stdio"])

"True when the agent of the session `s` speaks ACP: Antigravity and Grok do"
speaks_acp(s::AgentSession) = haskey(ACP_OPTIONS, agent_kind(s.agent).name)

"True when the agent called `name` works by turns: see \"an agent that works by turns\". The programs of Claude Code, Antigravity and Grok stay for the session."
by_turns(name::AbstractString) = !(agent_kind(name).name in ("Claude", "Antigravity", "Grok"))

"Send the ACP program of the session `s` the request `method` with `params`. `what` says what the answer is for: see `acp_answer!`."
acp_call!(s::AgentSession, method, params, what) = begin
  t = s.talk
  id = "ladder-$(t.n += 1)"
  t.calls[id] = what
  tell!(s, Dict("jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params))
  id
end

"Answer the request `id` of the ACP program of the session `s` with `result`"
acp_reply!(s::AgentSession, id, result) = tell!(s, Dict("jsonrpc" => "2.0", "id" => id, "result" => result))

"Start the talk with the ACP program that was just started for the session `s`. Ladder reads no files and runs no terminal for the agent: the agent does those itself."
acp_start!(s::AgentSession) = begin
  s.talk = AcpTalk()
  acp_call!(s, "initialize", Dict("protocolVersion" => 1,
    "clientCapabilities" => Dict("fs" => Dict("readTextFile" => false, "writeTextFile" => false), "terminal" => false)), :start)
  s
end

"""
Ask the ACP program of the session `s` for the session of its name, or for
a new one. What Ladder says of itself goes in the agent's instructions, as
`--append-system-prompt` does for Claude Code. Grok takes it as rules, and
a session of Grok's keeps the rules that it was made with.
"""
acp_session!(s::AgentSession) = begin
  brief = agent_kind(s.agent).name == "Grok" ? Dict("rules" => session_brief(s)) :
          Dict("antigravity" => Dict("systemPrompt" => Dict("append" => session_brief(s))))
  params = Dict{String,Any}("cwd" => s.dir, "mcpServers" => code_servers(s), "_meta" => brief)
  isempty(s.id) && return acp_call!(s, "session/new", params, :new)
  params["sessionId"] = s.id
  # An earlier session that you chose is loaded: the agent then says again all that was said in it. See "the commands of a session".
  s.loading ? acp_call!(s, "session/load", params, :load) : acp_call!(s, "session/resume", params, :resume)
end

"The program of the session `s` has the session. It gets the session's model, when that's another than the one it works with, and then what you said meanwhile."
acp_model!(s::AgentSession) = isempty(s.model) || s.model == s.running ? acp_ready!(s) :
  acp_call!(s, "session/set_model", Dict("sessionId" => s.id, "modelId" => s.model), (:model, s.model, nothing))

"The program of the session `s` has the session: what you said meanwhile goes to the agent"
acp_ready!(s::AgentSession) = begin
  s.talk.ready = true
  s.looking && acp_list!(s)   # you asked for the earlier sessions while the program started
  isempty(s.talk.held) || acp_prompt!(s, popfirst!(s.talk.held))
  s
end

"The ACP program of the session `s` couldn't start the session. The program ends, the session says why, and your next words start it again."
acp_failed!(s::AgentSession, words) = (note!(s, words, true); close!(s))

"""
Give the agent of the session `s` what you said: `message`, the parts of a
message. It waits while the program gets the session, or while the agent
works on what you said before.
"""
acp_prompt!(s::AgentSession, message) = begin
  t = s.talk
  t === nothing && return s
  (t.ready && !(:prompt in values(t.calls))) || (push!(t.held, message); return s)
  acp_call!(s, "session/prompt", Dict("sessionId" => s.id, "prompt" => message), :prompt)
  s
end

"The message for the ACP program with `content`, the text, and before it each of `pictures` that can be read, for the agent to see"
acp_message(content, pictures=String[]) = begin
  shown = Any[]
  for path in pictures
    b = picture_block(path)
    b === nothing || push!(shown, Dict("type" => "image", "mimeType" => b["source"]["media_type"], "data" => b["source"]["data"]))
  end
  Any[shown..., Dict("type" => "text", "text" => content)]
end

"""
Stop what the agent of the session `s` does: the turn under way, and what
you said after it. Each request of the agent's that has no answer is
cancelled, as ACP asks. The agent then ends the turn with `cancelled`.
"""
acp_stop!(s::AgentSession) = begin
  t = s.talk
  t === nothing && return s
  empty!(t.held)
  for it in s.items
    it isa AgentWants && it.answer == :none && (acp_choose!(s, it, "cancelled"); it.answer = :gone)
  end
  if :prompt in values(t.calls)
    tell!(s, Dict("jsonrpc" => "2.0", "method" => "session/cancel", "params" => Dict("sessionId" => s.id)))
  else
    # The program was still getting the session, so no turn was under way
    settle!(s)
    note!(s, "You stopped $(s.agent).")
  end
  s
end

"""
Take a line that the ACP program of the session `s` printed, read as JSON:
an answer to a request of Ladder's, an update, or a request of the agent's.
Ladder said that it reads no files and has no terminal, so the agent asks
only for leave to take a step. Another request gets an error, as one with
no answer would hold the agent up.
"""
acp_line!(s::AgentSession, o) = begin
  method, id = json_field(o, "method"), json_field(o, "id")
  if method === nothing
    id isa String && acp_answer!(s, pop!(s.talk.calls, id, nothing), json_field(o, "result"), json_field(o, "error"))
  elseif method == "session/update"
    acp_update!(s, json_field(json_field(o, "params"), "update"))
  elseif method == "session/request_permission"
    acp_asks!(s, id, json_field(o, "params"))
  elseif id !== nothing
    tell!(s, Dict("jsonrpc" => "2.0", "id" => id, "error" => Dict("code" => -32601, "message" => "Ladder doesn't do $method.")))
  end
  s
end

"""
Take the answer of the ACP program of the session `s` to a request of
Ladder's: `result` when the program did it, or `error`. `what` says what
the request was for. Starting takes a request for each step, and each
answer sends the next: the session, its mode, its model, and then what you
said meanwhile. The answer to what you said ends the turn.
"""
acp_answer!(s::AgentSession, what, result, error) = begin
  why = error === nothing ? "" : opening_line(fault_words(error, "it didn't say why."))
  if what == :start
    error === nothing ? acp_session!(s) : acp_failed!(s, "$(s.agent) didn't start: $why")
  elseif what == :resume && error !== nothing
    # The agent no longer has the session of that name, like one of another Mac. A new one starts, and gets the words that wait.
    s.id = ""
    note!(s, "$(s.agent) doesn't have this session any more, so a new one starts here. It doesn't know what was said before.")
    acp_session!(s)
  elseif what == :load && error !== nothing
    # The session before comes back, with what it showed
    s.loading = false
    s.before === nothing || ((s.id, s.items) = s.before)
    s.before = nothing
    note!(s, "$(s.agent) couldn't open that session: $why", true)
    acp_session!(s)
  elseif what == :list
    s.looking = false
    s.earlier = error === nothing ? acp_sessions(s, json_field(result, "sessions")) : EarlierSession[]
  elseif what in (:new, :resume, :load)
    error === nothing || return acp_failed!(s, "$(s.agent) couldn't start a session: $why")
    what == :load && session_loaded!(s)
    id = json_field(result, "sessionId")
    id isa String && (s.id = id)
    model = json_field(json_field(result, "models"), "currentModelId")
    model isa String && (s.running = model)
    # Grok has no accept-edits mode: it asks as its own settings say
    agent_kind(s.agent).name == "Antigravity" ? acp_call!(s, "session/set_mode", Dict("sessionId" => s.id, "modeId" => "accept-edits"), :mode) : acp_model!(s)
  elseif what == :mode
    error === nothing || note!(s, "$(s.agent) didn't take its accept-edits mode, so it can ask before each change: $why", true)
    acp_model!(s)
  elseif what isa Tuple && first(what) == :model
    _, asked, was = what
    if error === nothing
      s.running = asked
      was === nothing || isempty(s.items) || model_note!(s, "The model is now $(model_name(s.agent, asked)).")
    else
      # The model before stays, and a new session starts with it
      back = something(was, "")
      chosen_model(s.agent) == asked && (MODELS_CHOSEN[][s.agent] = back)
      s.model == asked && (s.model = back)
      model_note!(s, "$(s.agent) didn't change its model to $(model_name(s.agent, asked)): $why", true)
    end
    was === nothing && acp_ready!(s)
  elseif what == :prompt
    settle!(s)
    stop = json_field(result, "stopReason")
    if error !== nothing
      note!(s, why, true)
    elseif stop == "cancelled"
      note!(s, "You stopped $(s.agent).")
    elseif stop isa String && stop != "end_turn"
      note!(s, "$(s.agent) stopped: $(replace(stop, '_' => ' ')).", true)
    else
      ran_note!(s)
    end
    isempty(s.talk.held) || (acp_prompt!(s, popfirst!(s.talk.held)); s.busy = true)
  end
  s
end

"""
Take an update of the ACP program of the session `s`: a piece of the
agent's words, or a step with a tool, which starts, changes or ends. The
pane doesn't show the agent's thoughts, its plan, its title for the session
or how much of its context it has used.
"""
acp_update!(s::AgentSession, u) = begin
  kind = json_field(u, "sessionUpdate")
  if kind == "agent_message_chunk"
    words = json_field(json_field(u, "content"), "text")
    words isa String && more_words!(s, words)
  elseif kind in ("tool_call", "tool_call_update")
    acp_step!(s, u)
  elseif kind == "available_commands_update"
    commands!(s, acp_commands(json_field(u, "availableCommands")))
  elseif kind == "user_message_chunk" && s.loading
    # What you said in an earlier session, which the agent says again as it loads the session
    words = json_field(json_field(u, "content"), "text")
    end_words!(s)
    words isa String && !isempty(your_words(words)) && push!(s.items, YouSaid(words=your_words(words)))
  end
  s
end

"""
The tool of the step that `u` tells of, by Claude Code's name where it has
one, which `tool_words` and `tool_icon` know. Antigravity gives the tool's
name. Grok gives it in `_meta`, and as the step's first title, which a
later update changes to words like "Execute `ls`". Grok reaches a tool of
a tool server through its own tool `use_tool`, whose input names the tool.
"""
acp_tool(u) = begin
  name = something(json_field(json_field(json_field(u, "_meta"), "x.ai/tool"), "name"), json_field(u, "name"), json_field(u, "title"), Some(nothing))
  name == "use_tool" && (name = something(json_field(json_field(u, "rawInput"), "tool_name"), Some(name)))
  name isa String ? get(TOOL_NAMES, name, name) : "a tool"
end

"""
What the tool of a step was given, by the names that Claude Code gives them,
which `tool_words` knows. `input` is the step's `rawInput`. For a tool that
Grok reaches through `use_tool`, it's what that tool is given.
"""
acp_input(input) = begin
  inner = json_field(input, "tool_input")
  antigravity_input(json_field(input, "tool_name") isa String && inner !== nothing ? inner : input)
end

"""
The step of the session `s` that the update `u` tells of. Its first update
makes it, and each can say what the tool is given and whether it's done.
The agent's name for a step is its own in the session, so it needs no
turn's number, as the names of an agent that works by turns do.
"""
acp_step!(s::AgentSession, u) = begin
  id = json_field(u, "toolCallId")
  id isa String || return nothing
  step = step_of(s, id)
  if step === nothing
    end_words!(s)
    step = AgentStep(id=id, tool=acp_tool(u))
    push!(s.items, step)
  end
  input = json_field(u, "rawInput")
  (input !== nothing || isempty(step.words)) && (step.words = tool_words(step.tool, acp_input(input)))
  state = json_field(u, "status")
  state == "completed" ? (step.state = :done) : state == "failed" && (step.state = :failed)
  step
end

"""
The agent of the session `s` asks before a step, with the request `id` of
its program. The pane shows what the step does, with Allow and Refuse.
`params` has the step and the answers that the agent takes, which the
request keeps for `acp_choose!`.
"""
acp_asks!(s::AgentSession, id, params) = begin
  call = json_field(params, "toolCall")
  # A request can name a step without saying its tool again: the step that the session shows has it
  step = step_of(s, json_field(call, "toolCallId"))
  tool = step === nothing ? acp_tool(call) : step.tool
  # The agent's Julia code runs in Ladder without this question: the sandbox asks you before a step of it that could harm
  code_tool(tool) && return acp_choose!(s, AgentWants(input=(id, json_field(params, "options"))), "allow_once")
  input = acp_input(json_field(call, "rawInput"))
  # Nor does reading a picture that `look()` saved, which is in a folder of Ladder's and not in the session's
  tool == "Read" && a_look(json_field(input, "file_path")) && return acp_choose!(s, AgentWants(input=(id, json_field(params, "options"))), "allow_once")
  command = json_field(input, "command")
  push!(s.items, AgentWants(id=id isa String ? id : sprint(write_json, id), tool=tool, input=(id, json_field(params, "options")),
                            words=lowercasefirst(tool_words(tool, input)), detail=tool == "Bash" && command isa String ? command : ""))
  s
end

"""
Answer the request of the agent of the session `s` that `it` shows, with
the answer of the kind `kind` that the request offers, like allow_once, or
else one like it, such as allow_always. With neither, it's cancelled.
"""
acp_choose!(s::AgentSession, it::AgentWants, kind) = begin
  it.input isa Tuple || return s
  id, options = it.input
  options isa AbstractVector || (options = Any[])
  like = first(split(kind, '_')) * "_"
  k = something(findfirst(o -> json_field(o, "kind") == kind, options),
                findfirst(o -> (x = json_field(o, "kind"); x isa String && startswith(x, like)), options), Some(nothing))
  outcome = k === nothing ? Dict("outcome" => "cancelled") : Dict("outcome" => "selected", "optionId" => json_field(options[k], "optionId"))
  acp_reply!(s, id, Dict("outcome" => outcome))
  s
end

# --- the code that an agent runs --------------------------------------------------------
#
# An agent whose program stays for the session has a tool called `julia`,
# which runs Julia code inside Ladder: see repl.jl. In that code `shown` is
# the thing that the window shows, and the thing itself says what it is and
# gives the functions that change it: see for_agents.jl. So an agent can work
# with a kind of thing that it has never seen, like a SolidCraft design, and
# you watch the thing change.
#
# The first time that a kind of thing shows in a session, what it says of
# itself goes to the agent with your words, between <ladder-guide> tags. What
# it shows now goes with each thing that you say, in the <ladder> block.
#
# The code runs in the sandbox, in a thread of its own. Before a step that
# could harm, the pane asks you, with Allow and Refuse, as it does for a
# command of the shell. The code waits for your answer.

"True when the agent of the session `s` has the tool that runs Julia code in Ladder: its program stays for the session, and takes a tool from Ladder"
has_code(s::AgentSession) = !s.turns

"""
The thing that the page of `e` shows, for an agent: what `page_view` gives
for the page's file or folder, or else the file's or the folder's object.
It's nothing for a page of text, which an agent changes in its file.
"""
agent_shown(e) = begin
  o = page_object(e)
  o === nothing && return nothing
  v = page_view(e, o)
  v === nothing ? o : v
end

"The Julia code of the session `s`, made when it's first asked for"
repl!(s::AgentSession) = begin
  s.repl === nothing || return s.repl
  s.repl = Repls.Repl(s.agent, s.dir; ask=(action, code) -> code_asks!(s, action, code))
end

"Make the window that the pane `p` is in the one that the code of the session `s` works with: `shown` is what its page shows, and `look()` is its picture"
beside!(s::AgentSession, p) = begin
  r = repl!(s)
  r.shown = () -> on_page(p) ? nothing : agent_shown(editor(p))
  r.look = () -> on_main(() -> window_picture(editor(p)))
  s
end

"The folder of the pictures that `look()` saves for agents. A test names one of its own."
const AGENT_LOOKS = Ref("")
agent_looks() = isempty(AGENT_LOOKS[]) ? joinpath(homedir(), "Library", "Caches", "Ladder", "Agent looks") : AGENT_LOOKS[]

"True when `path` is a file in the folder of the pictures that `look()` saves"
a_look(path) = path isa AbstractString && startswith(normpath(path), joinpath(normpath(agent_looks()), ""))

const LOOK_MOST = 1568                   # px: the longer side of a picture that an agent takes whole

"""
Save a picture of the window of `e` as it is now, for an agent to read, and
give the PNG file's path. The picture has no more pixels than an agent takes
whole. Each window keeps one picture, so the folder doesn't fill.
"""
window_picture(e) = begin
  w = window_of(e)
  w === nothing && error("The session's window is closed.")
  path = joinpath(mkpath(agent_looks()), "window-$(objectid(w) % 100000).png")
  k = min(2.0, LOOK_MOST / max(num(w.size[1]), num(w.size[2]), 1))
  save_png(path, w; scale=(k, k))
  path
end

"""
The sandbox stopped the code `code` of the agent of the session `s` before
the action `action`. The pane asks you, and this waits for your answer on
the code's thread: true when you allow it. A turn that ends, or that you
stop, answers no.
"""
code_asks!(s::AgentSession, action, code) = begin
  box = Channel{Bool}(1)
  on_main() do
    push!(s.items, AgentWants(id="ladder-code-$(length(s.items))", tool="Julia", words="$(action.words), with this Julia code", detail=String(code), input=box))
    s.version += 1
  end
  take!(box)
end

"Answer no to each thing that the code of the session `s` waits to be allowed, when nothing will answer it any more"
release_code!(s::AgentSession) = begin
  for it in s.items
    it isa AgentWants && it.answer == :none && it.input isa Channel && !isready(it.input) && put!(it.input, false)
  end
  s
end

"What Claude Code is given to reach the tool of the session `s`: its tool servers, as JSON"
code_config(s::AgentSession) = begin
  program, given = Repls.command(repl!(s))
  sprint(write_json, Dict("mcpServers" => Dict("ladder" => Dict("command" => program, "args" => given))))
end

"The tool servers that an ACP program is given for the session `s`"
code_servers(s::AgentSession) = begin
  has_code(s) || return Any[]
  program, given = Repls.command(repl!(s))
  Any[Dict("name" => "ladder", "command" => program, "args" => given, "env" => Any[])]
end

"What a step that runs the Julia code `code` in Ladder shows as: the code's first line"
code_step(code) = begin
  lines = code isa String ? filter(!isempty, strip.(split(code, '\n'))) : []
  isempty(lines) ? "Running Julia code" : "Running $(first(lines))"
end

"True when `name` is how an agent's program names the tool that runs Julia code in Ladder"
code_tool(name) = name isa AbstractString && occursin(r"ladder.*julia"i, name)

"""
What the thing that the page of `e` shows says of itself, for the agent of
the session `s`, the first time that a thing of its kind shows in the
session: what it is and the functions that change it, between
<ladder-guide> tags. After that, and for a page of text, it's "".
"""
guide_once!(s::AgentSession, e) = begin
  (has_code(s) && s.repl !== nothing) || return ""
  x = agent_shown(e)
  (x === nothing || typeof(x) in s.repl.guided) && return ""
  (isempty(Offer.about(x)) && isempty(Offer.tools(x))) && return ""
  push!(s.repl.guided, typeof(x))
  "<ladder-guide>\n$(Offer.guide(x))\n</ladder-guide>"
end

"What every session whose agent has the tool is told of it"
const BRIEF_CODE = "You have a tool named julia, from the tool server named ladder, which runs Julia code inside Ladder, in a module that is yours for this session: a name that you give a value keeps it, so hold a long result by a name and look only at the part that you need. `look()` saves a picture of the user's window and gives the PNG file's path, which you can read to see what the user sees. The code runs in a sandbox, and Ladder asks the user before a step that could harm, like changing a file."

"What a session beside a page is told of the thing that the page shows, after `BRIEF_CODE`"
const BRIEF_SHOWN = "In that code, `shown` is the thing that the user's window shows now, `guide(shown)` says what it is and lists the functions that read it and change it, and `status(shown)` says what it shows now. When the window shows something that isn't text, like a 3D design, the <ladder> block says what it shows now, and the first message with a thing of that kind also has a block between <ladder-guide> and </ladder-guide>: what the thing is, and its functions. Change such a thing only with the julia tool, and never by reading or changing its file: Ladder holds the thing in memory, with changes that the file doesn't have, and the user watches it change."

# --- an agent that works by turns ---
#
# Claude Code's program stays for a whole session, and so do Antigravity's
# and Grok's: see "Antigravity and Grok, which ask you before a step". The
# program of Codex does one thing and ends. So a session with it starts
# its program again for each thing that you say, with the name that the
# agent gave the session, and the agent goes on from where it was. It
# prints lines of JSON while it works, in a form of its own, and Ladder shows
# them as it shows Claude's: words, steps, and the end of the turn. Such an
# agent can't ask you before a step, and has no tool from Ladder. It runs
# with the same options as for a change that you ask for in the page: it
# changes files, and what else it may do is in the agent's own settings.

"A command that a test puts in the place of an agent that works by turns. It's given the agent's name, the session's name or \"\", and your words."
const TURN_COMMAND = Ref{Any}(nothing)

"The names that other agents give their tools, as Claude Code's names, which `tool_words` and `tool_icon` know"
const TOOL_NAMES = Dict(
  "read_file" => "Read", "read_many_files" => "Read", "write_file" => "Write", "replace" => "Edit", "search_replace" => "Edit", "edit" => "Edit",
  "run_terminal_command" => "Bash", "run_shell_command" => "Bash", "grep" => "Grep", "grep_search" => "Grep", "search_file_content" => "Grep",
  "glob" => "Glob", "list_dir" => "List", "list_directory" => "List", "web_search" => "WebSearch", "google_web_search" => "WebSearch",
  "web_fetch" => "WebFetch", "todo_write" => "TodoWrite", "write_todos" => "TodoWrite", "spawn_subagent" => "Task",
  # Antigravity's
  "view_file" => "Read", "write_to_file" => "Write", "edit_file" => "Edit", "replace_file_content" => "Edit", "multi_replace_file_content" => "Edit",
  "sed_file" => "Edit", "run_command" => "Bash", "find_by_name" => "Glob", "search_web" => "WebSearch", "read_url_content" => "WebFetch",
  "invoke_subagent" => "Task", "browser_subagent" => "Task", "notebook_edit" => "NotebookEdit")

"""
The command for one turn of the session `s`, with `words` for the agent.
After the first turn it names the session, so the agent goes on with it.
Grok takes what Ladder says of itself as rules. The others get that at the
start of the first words: see `turn!`.
"""
turn_command(s::AgentSession, words::AbstractString) = begin
  TURN_COMMAND[] === nothing || return `$(TURN_COMMAND[]) $(s.agent) $(s.id) $words`
  kind_command(agent_kind(s.agent), [turn_options(s); words])
end

"The options of the command for a turn of the session `s`, which your words go after: see `turn_command`"
turn_options(s::AgentSession) = begin
  again = !isempty(s.id)
  model = isempty(s.model) ? String[] : ["-m", s.model]
  ["exec", "--json", "--sandbox", "workspace-write", "--skip-git-repo-check", model..., (again ? ["resume", s.id] : String[])...]
end

"""
Start the program of the session `s` for one turn, with `words` for the
agent. A task reads each line that it prints. When the program ends, the
turn has ended, and the next thing that you said meanwhile starts a turn.
"""
turn!(s::AgentSession, words::AbstractString) = begin
  # The agent reads what Ladder says of itself before your words, until its session has a name to go on with
  first_words = isempty(s.id)
  s.asked += 1
  s.stopped = false
  process = try
    out, err = Pipe(), Pipe()
    command = turn_command(s, first_words ? "<ladder-brief>\n$(session_brief(s))\n</ladder-brief>\n\n$words" : words)
    process = run(pipeline(Cmd(command; dir=s.dir), stdin=devnull, stdout=out, stderr=err), wait=false)
    close(out.in)
    close(err.in)
    wrong = @async read(err, String)
    @async begin
      for line in eachline(out)
        try
          turn_line!(s, line)
        catch err
          note!(s, "Ladder couldn't read a line that $(s.agent) printed: $(sprint(showerror, err))", true)
        end
      end
      said = try fetch(wrong) catch; "" end
      wait(process)
      # A turn that Ladder started since has the session now
      s.process === process && turn_ended!(s, said)
    end
    process
  catch err
    empty!(s.queue)
    s.busy = false
    note!(s, err isa ErrorException ? err.msg : "Ladder couldn't start $(s.agent): $(sprint(showerror, err))", true)
    return s
  end
  s.process, s.to, s.closing = process, nothing, false
  s
end

"The line of `wrong`, which a program wrote of what went wrong, that says the most: the first that names an error, or the last"
fault_line(wrong) = begin
  lines = filter(!isempty, strip.(split(wrong, '\n')))
  isempty(lines) && return ""
  k = findfirst(l -> occursin(r"^\S*error"i, l), lines)
  String(lines[something(k, length(lines))])
end

"The program of a turn of the session `s` has ended, and `wrong` is what it wrote of what went wrong"
turn_ended!(s::AgentSession, wrong) = begin
  settle!(s)
  if s.closing
    empty!(s.queue)
  elseif s.stopped
    note!(s, "You stopped $(s.agent).")
  elseif !success(s.process)
    said = fault_line(wrong)
    empty!(s.queue)
    # An agent that said what went wrong in its last line has it in the session already
    told = !isempty(s.items) && last(s.items) isa SessionNote && last(s.items).bad
    told || note!(s, isempty(said) ? "$(s.agent) stopped before it had done." : "$(s.agent) stopped: $said", true)
  end
  s.stopped = false
  isempty(s.queue) || (turn!(s, popfirst!(s.queue)); s.busy = running(s))
  s.version += 1
  s
end

"More of the words that the agent of the session `s` is saying now"
more_words!(s::AgentSession, text::AbstractString) = begin
  reply = open_reply(s)
  reply === nothing && (reply = AgentReply(); push!(s.items, reply))
  reply.text *= text
  reply.n += 1
  s
end

"The words that the agent of the session `s` was saying are whole: a step comes after them"
end_words!(s::AgentSession) = (reply = open_reply(s); reply === nothing || (reply.whole = true; reply.n += 1); s)

"A step of the agent of the session `s` with the tool `name`, as the agent calls it, on `input`. `id` is the step's name."
tool_step!(s::AgentSession, id, name, input) = begin
  (id isa String && name isa String) || return nothing
  end_words!(s)
  tool = get(TOOL_NAMES, name, name)
  id = turn_step(s, id)
  step = step_of(s, id)
  step === nothing && (step = AgentStep(id=id, tool=tool); push!(s.items, step))
  step.words = tool_words(tool, input)
  step
end

"The step `id` of the session `s` has ended, well or not"
step_ended!(s::AgentSession, id, well::Bool) = (step = id isa String ? step_of(s, turn_step(s, id)) : nothing; step === nothing || (step.state = well ? :done : :failed); s)

"The name of the step that the agent calls `id` in this turn of the session `s`. Codex starts its names again in each turn, so the turn's number goes before."
turn_step(s::AgentSession, id::AbstractString) = "$(s.asked)/$id"

"""
Take a line that the program of a turn of the session `s` printed: JSON with
a `type`, in the form of the session's agent. A notice before the JSON on a
line is left out.
"""
turn_line!(s::AgentSession, line::AbstractString) = begin
  at = findfirst('{', line)
  at === nothing && return s
  o = agent_json(SubString(line, at))
  o === nothing && return s
  kind = json_field(o, "type")
  kind isa String || return s
  codex_line!(s, o, kind)
  s.version += 1
  s
end

"What the line `o` says went wrong, or `other`"
fault_words(o, other) = begin
  for key in ("message", "error", "data")
    v = json_field(o, key)
    v isa String && !isempty(v) && return v
    m = json_field(v, "message")
    m isa String && !isempty(m) && return m
  end
  other
end

"""
What a tool of Antigravity was given, by the names that Claude Code gives
them, which `tool_words` knows: Path is file_path, CommandLine is command.
The others are in small letters.
"""
antigravity_input(input) = input isa JSONObject ?
  JSONObject([get(ANTIGRAVITY_KEYS, k, lowercase(k)) for k in input.keys], copy(input.values)) : input

const ANTIGRAVITY_KEYS = Dict("Path" => "file_path", "AbsolutePath" => "file_path", "TargetFile" => "file_path", "DirectoryPath" => "path",
                              "SearchPath" => "path", "SearchDirectory" => "path", "CommandLine" => "command", "Url" => "url")

"The first line of `words`, as an error that goes on to list what it could be has it"
opening_line(words::AbstractString) = String(strip(first(split(strip(words), '\n'))))

# Codex prints `thread.started` with the session's name, an `item` when each thing starts and ends (its words, a command,
# a change to files, a search), and `turn.completed` or `turn.failed`
codex_line!(s::AgentSession, o, kind) = begin
  if kind == "thread.started"
    id = json_field(o, "thread_id")
    id isa String && (s.id = id)
  elseif kind in ("item.started", "item.updated", "item.completed")
    item = json_field(o, "item")
    id, what = json_field(item, "id"), json_field(item, "type")
    ended = kind == "item.completed"
    if what == "agent_message"
      words = json_field(item, "text")
      ended && words isa String && (end_words!(s); push!(s.items, AgentReply(text=words, whole=true, n=1)))
    elseif what == "command_execution"
      tool_step!(s, id, "Bash", item)
      ended && step_ended!(s, id, json_field(item, "status") != "failed")
    elseif what == "file_change"
      changes = json_field(item, "changes")
      path = changes isa AbstractVector && !isempty(changes) ? json_field(first(changes), "path") : nothing
      tool_step!(s, id, "Edit", JSONObject(["file_path"], Any[path]))
      ended && step_ended!(s, id, json_field(item, "status") != "failed")
    elseif what == "web_search"
      tool_step!(s, id, "WebSearch", item)
      ended && step_ended!(s, id, true)
    elseif what == "mcp_tool_call"
      server, tool = json_field(item, "server"), json_field(item, "tool")
      tool_step!(s, id, "mcp__$(server)__$(tool)", item)
      ended && step_ended!(s, id, json_field(item, "status") != "failed")
    elseif what == "todo_list"
      tool_step!(s, id, "TodoWrite", item)
      ended && step_ended!(s, id, true)
    elseif what == "error"
      note!(s, fault_words(item, "$(s.agent) couldn't do that."), true)
    end
  elseif kind == "turn.completed"
    settle!(s)
  elseif kind == "turn.failed"
    settle!(s)
    s.stopped || note!(s, fault_words(o, "$(s.agent) couldn't do that."), true)
  elseif kind == "error"
    note!(s, fault_words(o, "$(s.agent) couldn't do that."), true)
  end
  s
end

# --- the commands of a session ---
#
# Words that start with a slash are a command, as in the agent's own
# terminal. While you type one, a list of the commands shows over the
# field: the arrows move in it, Tab writes the command out for you to add
# to, and Return runs it.
#
# Ladder does a few commands itself. `/resume` lists the earlier sessions of
# the folder, also the ones that you had in a terminal, and goes on with the
# one that you choose: what was said in it shows in the pane. `/new` ends the
# session and starts with nothing, and `/model` chooses the model.
#
# The rest are the agent's own, as the agent's program lists them: its
# commands, like `/compact`, and its skills. Such a command goes to the agent
# as you typed it, with nothing of Ladder's before it, because the agent
# reads a command only at the start of a message. An agent that works by
# turns has no commands of its own, and no earlier session to go on with.

"""
A command that you type after a slash. `about` says what it does in a few
words, `hint` is what can come after its name, and `own` is true for one
that Ladder does itself.
"""
struct SlashCommand
  name::String
  about::String
  hint::String
  own::Bool
end

"The commands that Ladder does itself, in the order that the list shows them"
const OWN_COMMANDS = [
  SlashCommand("resume", "Go on with an earlier session of this folder", "[words of its title]", true),
  SlashCommand("new", "End this session, and start a new one", "", true),
  SlashCommand("clear", "End this session, and start a new one", "", true),
  SlashCommand("model", "Choose the model that the agent works with", "[its name]", true)]

"The commands of each agent in each folder, as the agent's program last listed them, by the agent's name and the folder"
const AGENT_COMMANDS = Dict{Tuple{String,String},Vector{SlashCommand}}()

"An earlier session of an agent: the name that the agent goes on with it by, its title, when it was last used, and for Claude Code the file that keeps it"
struct EarlierSession
  id::String
  title::String
  at::Float64
  file::String
end

"The session `s` has the list `found` of its agent's commands, or nothing when the agent's program gave none"
commands!(s::AgentSession, found) = (found === nothing || (AGENT_COMMANDS[(s.agent, s.dir)] = found); s.version += 1; s)

"The first line of `words`, with one space where it had more"
one_line_of(words::AbstractString) = String(replace(opening_line(words), r"\s+" => " "))

"The commands in `found`, Claude Code's list: each has a name, what it does and what comes after it. Nothing when it's no list."
claude_commands(found) = begin
  found isa AbstractVector || return nothing
  list = SlashCommand[]
  for c in found
    name, about, hint = json_field(c, "name"), json_field(c, "description"), json_field(c, "argumentHint")
    name isa String && !isempty(name) && push!(list, SlashCommand(name, about isa String ? one_line_of(about) : "", hint isa String ? hint : "", false))
  end
  list
end

"The commands in `found`, the list of an agent that speaks ACP: each has a name, what it does, and a hint of what comes after it. Nothing when it's no list."
acp_commands(found) = begin
  found isa AbstractVector || return nothing
  list = SlashCommand[]
  for c in found
    name, about, hint = json_field(c, "name"), json_field(c, "description"), json_field(json_field(c, "input"), "hint")
    name isa String && !isempty(name) && push!(list, SlashCommand(name, about isa String ? one_line_of(about) : "", hint isa String ? hint : "", false))
  end
  list
end

"The command of Ladder's own called `name` that the pane `p` has, or nothing. An agent that works by turns has no earlier session to go on with."
own_command(p::AgentPane, name::AbstractString) = begin
  k = findfirst(c -> c.name == name, OWN_COMMANDS)
  k === nothing && return nothing
  name == "resume" && by_turns(pane_agent(p, editor(p))) && return nothing
  OWN_COMMANDS[k]
end

"The commands that the pane `p` lists: Ladder's own, and then the agent's own, each name once"
slash_commands(p::AgentPane) = begin
  e = editor(p)
  s = p.session
  list = SlashCommand[c for c in OWN_COMMANDS if own_command(p, c.name) !== nothing]
  s === nothing && return list
  for c in get(AGENT_COMMANDS, (s.agent, s.dir), SlashCommand[])
    any(o -> o.name == c.name, list) || push!(list, c)
  end
  list
end

"The name of the command that `words` start with, and what comes after it, or nothing when they don't start with a command"
slash_named(words::AbstractString) = begin
  m = match(r"^/([\w:.-]+)(?:\s+(.*))?$"s, words)
  m === nothing ? nothing : (String(m[1]), m[2] === nothing ? "" : String(strip(m[2])))
end

"""
True when `words` go to the agent of the session `s` as they are, with
nothing before them: they start with a command of the agent's. Before the
agent has listed its commands, any words that start like a command do.
"""
goes_bare(s::AgentSession, words::AbstractString) = begin
  named = slash_named(words)
  (named === nothing || s.turns) && return false
  known = get(AGENT_COMMANDS, (s.agent, s.dir), nothing)
  known === nothing || any(c -> c.name == named[1], known)
end

# --- a command beside a turn ---
#
# Claude Code runs a command that you give while it works only when its turn
# has ended, though its terminal shows /usage at once. Some commands show
# the same in each session, like /usage, which shows how much of your plan
# you have used. Ladder runs such a command in a program of its own, beside
# the turn, as soon as you give it: the answer shows under your words a few
# seconds later, and the agent goes on with its turn. The command costs no
# tokens, as the agent's program answers it itself.

"Claude Code's commands that show the same in each session, so a program of their own can run them beside a turn. /cost and /stats are other names of /usage."
const BESIDE_COMMANDS = ("usage", "cost", "stats")

"""
True when `words` are a command that a program of its own runs beside the
turn that the agent of the session `s` works on now. The agent must have
listed the command: with an API key, Claude Code has no /usage, and the
words would go to the model.
"""
goes_beside(s::AgentSession, words::AbstractString) = begin
  named = slash_named(words)
  (named === nothing || !s.busy || s.turns || speaks_acp(s) || agent_kind(s.agent).name != "Claude") && return false
  named[1] in BESIDE_COMMANDS && any(c -> c.name == named[1], get(AGENT_COMMANDS, (s.agent, s.dir), SlashCommand[]))
end

"The command that runs the agent's command `words` in a program of its own, beside the session `s`. Safe mode starts with no plugins, MCP servers or hooks, so it starts quickly."
beside_command(s::AgentSession, words::AbstractString) = begin
  options = ["-p", String(words), "--output-format", "json", "--safe-mode", "--no-session-persistence"]
  SESSION_COMMAND[] === nothing ? kind_command(agent_kind(s.agent), options) : `$(SESSION_COMMAND[]) $options`
end

"""
Run the agent's command `words`, like /usage, in a program of its own, while
the program of the session `s` works on its turn. Your words show at once,
and what the command printed shows under them when it has done. A task waits
for the program: the window gives it its turns (see `pane_tick!`).
"""
run_beside!(s::AgentSession, words::AbstractString) = begin
  it = RanBeside(words=String(words))
  push!(s.items, it)
  s.beside += 1
  s.version += 1
  command = Cmd(beside_command(s, words); dir=s.dir)
  @async begin
    out, err = IOBuffer(), IOBuffer()
    ok = try
      success(pipeline(command, stdin=devnull, stdout=out, stderr=err))
    catch e
      print(err, sprint(showerror, e))
      false
    end
    text, bad = beside_said(String(take!(out)), String(take!(err)), ok)
    it.reply.text, it.bad = isempty(text) ? "$(s.agent) ran $(first(split(words))). It gave nothing to show here." : text, bad
    it.reply.whole = true
    it.reply.n += 1
    s.beside -= 1
    s.version += 1
  end
  s
end

"""
What a command that ran beside a turn printed, from `out`, the line of JSON
that Claude Code printed, and `err`, what it wrote of a fault. `ok` is false
when the program failed. Gives the text and whether it says what went wrong.
"""
beside_said(out::AbstractString, err::AbstractString, ok::Bool) = begin
  o = nothing
  for line in split(out, '\n')
    x = agent_json(line)
    json_field(x, "type") == "result" && (o = x)
  end
  said = json_field(o, "result")
  said = said isa String ? String(strip(said)) : ""
  if o === nothing || !ok || json_field(o, "is_error") === true
    why = isempty(said) ? fault_line(err) : said
    return (isempty(why) ? "The command didn't run." : why, true)
  end
  (said, false)
end

"""
The agent of the session `s` has done with what you said. When that was a
command of the agent's and nothing came of it to show, the session says that
the command ran, with `said`, what the agent's program says of it, if
anything. Some commands only show something in the agent's own terminal.
"""
ran_note!(s::AgentSession, said::AbstractString="") = begin
  it = newest(s.items)
  (it isa YouSaid && isempty(it.about) && slash_named(it.words) !== nothing) || return s
  note!(s, isempty(strip(said)) ? "$(s.agent) ran $(first(split(it.words))). It gave nothing to show here." : String(strip(said)))
end

"""
What you said, from `text`, a message as the agent got it: without what
Ladder put before your words and after them. A command that you typed in a
terminal is the command. What a terminal wrote itself, like what a command
printed, is "".
"""
your_words(text::AbstractString) = begin
  t = replace(text, r"<ladder-brief>.*?</ladder-brief>\s*"s => "", r"<ladder-guide>.*?</ladder-guide>\s*"s => "",
              r"<ladder>.*?</ladder>\s*"s => "", r"<changes>.*?</changes>\s*"s => "")
  t = replace(t, r"\s*(The pictures with these words are also in these files:|With these words come these pictures, in files that you can read:)\n.*\z"s => "")
  m = match(r"<command-name>/?([^<]+)</command-name>", t)
  if m !== nothing
    given = match(r"<command-args>([^<]*)</command-args>", t)
    return String(strip("/" * m[1] * " " * (given === nothing ? "" : given[1])))
  end
  t = strip(t)
  occursin(r"^<[a-z][\w-]*>", t) ? "" : String(t)
end

const HISTORY_MOST = 30   # an earlier session shows no more than this many of the things that you said, the newest, with what came of them

"The newest part of `items`, what was said in an earlier session: a long session shows from one of your later messages on"
recent_part(items) = begin
  yours = findall(it -> it isa YouSaid, items)
  length(yours) <= HISTORY_MOST && return items
  Any[SessionNote(words="What was said before this isn't shown here. The agent still knows it."); items[yours[end-HISTORY_MOST+1]:end]]
end

"When the day and time `text` says was, like 2026-11-26T12:28:58Z, in seconds, or 0.0. It's read as the time at Greenwich, as the agents write it."
iso_time(text) = begin
  m = text isa AbstractString ? match(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d", text) : nothing
  m === nothing ? 0.0 : try Dates.datetime2unix(Dates.DateTime(m.match)) catch; 0.0 end
end

"How long ago `at` was, in a few words: \"5 min ago\", \"3 hr ago\", \"yesterday\", or the day"
ago_words(at::Real, now::Real=time()) = begin
  at <= 0 && return ""
  d = now - at
  d < 90 ? "just now" : d < 3600 ? "$(round(Int, d / 60)) min ago" : d < 86400 ? "$(round(Int, d / 3600)) hr ago" : d < 2 * 86400 ? "yesterday" :
    Dates.format(Dates.unix2datetime(at) + (Dates.now() - Dates.now(Dates.UTC)), "d u")
end

# --- the earlier sessions of Claude Code ---
#
# Claude Code keeps each session of a folder in a file of its own, in a
# folder of ~/.claude/projects that's named for the session's folder. Each
# line of the file is JSON: what you said, what Claude said, a title that
# Claude gave the session. Claude Code's program has no request that lists
# them, so Ladder reads the files.

"A folder that a test puts in the place of the one where Claude Code keeps the sessions of a folder. \"\" means Claude Code's own."
const CLAUDE_SESSIONS = Ref("")
const SESSIONS_MOST = 40        # how many earlier sessions the list has at most
const TITLE_READS = 96 * 1024   # how many bytes of each end of a session's file Ladder reads for its title

"The folders where Claude Code keeps the sessions of the folder `dir`: it names the folder by the path, with a - for each character that's no letter or digit"
claude_folders(dir) = begin
  isempty(CLAUDE_SESSIONS[]) || return [CLAUDE_SESSIONS[]]
  top = joinpath(get(ENV, "CLAUDE_CONFIG_DIR", joinpath(homedir(), ".claude")), "projects")
  unique([joinpath(top, replace(d, r"[^A-Za-z0-9]" => "-")) for d in (dir, truepath(dir))])
end

"The text of the JSON string that follows `key` in `line`, or nothing: a quick look, for a line that's too long to read whole"
quick_field(line, key) = begin
  m = match(Regex("\"" * key * "\"\\s*:\\s*(\"(?:[^\"\\\\]|\\\\.)*\")"), line)
  m === nothing && return nothing
  v = try json_value(Vector{UInt8}(m[1])) catch; nothing end
  v isa AbstractString ? String(v) : nothing
end

"What you said in the line `o` of a session's file of Claude Code, or \"\" when the line isn't something that you said"
claude_said(o) = begin
  (json_field(o, "type") == "user" && json_field(o, "isMeta") !== true && json_field(o, "isSidechain") !== true &&
   json_field(o, "isCompactSummary") !== true) || return ""
  content = json_field(json_field(o, "message"), "content")
  content isa AbstractString && return your_words(content)
  content isa AbstractVector || return ""
  your_words(join((t for t in (json_field(part, "text") for part in content if json_field(part, "type") == "text") if t isa AbstractString), "\n"))
end

"""
The title of the session that Claude Code keeps in `file`: the one that you
gave it, else the one that Claude gave it, else the first thing that you
said. "" for a file with none of them, like one of a program that ran once
for Ladder. Only the two ends of a long file are read.
"""
claude_title(file) = begin
  size = filesize(file)
  head, tail = open(file) do io
    head = String(read(io, min(size, TITLE_READS)))
    size > 2TITLE_READS ? (seek(io, size - TITLE_READS); (head, String(read(io)))) : (head * String(read(io)), "")
  end
  for (kind, key) in (("custom-title", "customTitle"), ("ai-title", "aiTitle")), part in (tail, head)
    title = ""
    for line in eachsplit(part, '\n')
      occursin("\"$kind\"", line) || continue
      found = quick_field(line, key)
      found === nothing || (title = found)
    end
    isempty(title) || return one_line_of(title)
  end
  for line in eachsplit(head, '\n')
    occursin("\"user\"", line) || continue
    said = claude_said(agent_json(line))
    isempty(said) || return first(one_line_of(said), 90)
  end
  ""
end

"The earlier sessions that Claude Code keeps for the folder of the session `s`, the newest first, without the one that `s` goes on with"
claude_sessions(s::AgentSession) = begin
  files = String[]
  for folder in claude_folders(s.dir)
    isdir(folder) && append!(files, (joinpath(folder, f) for f in readdir(folder) if endswith(f, ".jsonl")))
  end
  found = EarlierSession[]
  for file in first(sort!(files, by=mtime, rev=true), 3SESSIONS_MOST)
    id = String(chop(basename(file), tail=6))
    id == s.id && continue
    title = try claude_title(file) catch; "" end
    isempty(title) || push!(found, EarlierSession(id, title, mtime(file), file))
    length(found) >= SESSIONS_MOST && break
  end
  found
end

"""
What was said in the session that Claude Code keeps in `file`, as the things
that a session shows: your words, Claude's replies, and its steps. What an
agent that Claude started said to it is left out, and so is what Claude
thought.
"""
claude_history(file) = begin
  items = Any[]
  steps = Dict{String,AgentStep}()
  for line in eachline(file)
    (occursin("\"user\"", line) || occursin("\"assistant\"", line)) || continue
    o = agent_json(line)
    kind = json_field(o, "type")
    (kind in ("user", "assistant") && json_field(o, "isSidechain") !== true && json_field(o, "isMeta") !== true) || continue
    content = json_field(json_field(o, "message"), "content")
    if kind == "user"
      if json_field(o, "isCompactSummary") === true
        push!(items, SessionNote(words="Claude summed up what was said before this, to make room."))
        continue
      end
      said = claude_said(o)
      isempty(said) || push!(items, YouSaid(words=said))
      for part in (content isa AbstractVector ? content : ())
        json_field(part, "type") == "tool_result" || continue
        step = get(steps, something(json_field(part, "tool_use_id"), ""), nothing)
        step === nothing || json_field(part, "is_error") !== true || (step.state = :failed)
      end
    else
      for part in (content isa AbstractVector ? content : ())
        what = json_field(part, "type")
        if what == "text"
          text = json_field(part, "text")
          text isa AbstractString && !isempty(strip(text)) && push!(items, AgentReply(text=String(text), whole=true, n=1))
        elseif what == "tool_use"
          id, name = json_field(part, "id"), json_field(part, "name")
          (id isa String && name isa String) || continue
          step = AgentStep(id=id, tool=name, words=tool_words(name, json_field(part, "input")), state=:done)
          steps[id] = step
          push!(items, step)
        end
      end
    end
  end
  items
end

# --- the earlier sessions of an agent that speaks ACP ---

"Ask the ACP program of the session `s` for the earlier sessions of its folder. While the program still starts, `acp_ready!` asks."
acp_list!(s::AgentSession) = begin
  t = s.talk
  (t !== nothing && t.ready && !(:list in values(t.calls))) && acp_call!(s, "session/list", Dict("cwd" => s.dir), :list)
  s
end

"The earlier sessions in `found`, the list of the ACP program of the session `s`: those of its folder, the newest first, without the one that `s` has now"
acp_sessions(s::AgentSession, found) = begin
  list = EarlierSession[]
  found isa AbstractVector || return list
  here = truepath(s.dir)
  for o in found
    id, dir, title = json_field(o, "sessionId"), json_field(o, "cwd"), json_field(o, "title")
    (id isa String && id != s.id && dir isa String && truepath(dir) == here) || continue
    push!(list, EarlierSession(id, title isa String && !isempty(strip(title)) ? one_line_of(title) : "A session with no title", iso_time(json_field(o, "updatedAt")), ""))
  end
  first(sort!(list, by=x -> x.at, rev=true), SESSIONS_MOST)
end

"""
The agent of the session `s` has said again all that was said in the earlier
session that it loaded. Each thing of it is whole. A session of Grok's keeps
the rules that it was made with, so one that was made outside Ladder is told
of Ladder with your next words.
"""
session_loaded!(s::AgentSession) = begin
  s.loading, s.before = false, nothing
  for it in s.items
    it isa AgentReply && !it.whole && (it.whole = true; it.n += 1)
    it isa AgentStep && it.state == :going && (it.state = :done)
  end
  s.items = recent_part(s.items)
  s.unbriefed = agent_kind(s.agent).name == "Grok"
  s
end

"""
Make the session `s` go on with the earlier session `x`. Claude Code's
program starts again with that session's name, and Ladder reads what was
said from the session's file. An agent that speaks ACP loads the session,
and says again what was said. The caller starts the program when this ends
it: see `resume_session!`.
"""
resume!(s::AgentSession, x::EarlierSession) = begin
  if speaks_acp(s)
    live = running(s) && s.talk !== nothing && s.talk.ready && isempty(s.talk.calls)
    live || (close!(s); s.process = s.to = nothing)
    s.before = (s.id, s.items)
    s.id, s.items, s.loading = x.id, Any[], true
    live && (s.talk.ready = false; acp_session!(s))
  else
    close!(s)
    s.process = s.to = nothing
    s.id, s.items = x.id, recent_part(claude_history(x.file))
  end
  s.sent, s.earlier, s.looking, s.unbriefed = "", nothing, false, false
  s.version += 1
  s
end

"The name of the agent of the pane `p`: the one of its session, or the one that Settings chose, which the next session is with"
pane_agent(p::AgentPane, e) = p.session !== nothing ? p.session.agent : SESSION_COMMAND[] === nothing ? agent_kind(e.ai).name : e.ai

"True when the pane `p` is a session's file in the page, and not the pane of agent mode"
on_page(p::AgentPane) = !isempty(p.file)
