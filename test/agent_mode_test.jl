# Tests for agent mode, in main.jl: the command Agent Mode puts an agent's
# session at the left of the page and the page's outline at its right, in a
# wider window, with the page between them on a card. Run them with
# `julia -O0 --project=. test/agent_mode_test.jl`. No real agent runs: the
# agent here is a small script that reads and prints the lines of JSON that
# Claude Code does. They draw a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype onfiledrop
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/save" save_scene
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring
const px = K.px

const dir = realpath(mktempdir())
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const page = joinpath(dir, "plan.md")
write(page, """
# The plan

Words before the first section.

## Paint

Buy paint.

### Colours

Red and blue.

## Brushes

$(join(("Line $i of the brushes." for i in 1:60), "\n\n"))

## Done

The end.
""")

# A page that the agent links to, with a space in its name, which a file:// address writes as %20
const notes = joinpath(dir, "my notes.md")
write(notes, "# Notes\n\n" * join(("Note $i." for i in 1:60), "\n\n") * "\n")

# The agent writes down each line that Ladder gives it, and answers by what your words hold
const heard = joinpath(dir, "heard.txt")
const agent = joinpath(dir, "test-agent")
write(agent, replace(raw"""
#!/bin/sh
say() { printf '%s\n' "$1"; }
done_() { say '{"type":"result","subtype":"success","is_error":false,"result":""}'; }
# It's given Claude Code's options. A model like sonnet is claude-sonnet-5-5, and with none it's Opus.
model=opus
session=test-session
# Ladder runs /usage beside a turn in a program of its own, which prints one line of JSON and ends, as `claude -p /usage --output-format json` does
case " $* " in *' /usage '*)
  say '{"type":"result","subtype":"success","is_error":false,"num_turns":0,"result":"Current week (all models): 50% used\nCurrent week (Fable): 11% used","local_command":"usage"}'
  exit 0 ;;
esac
while [ $# -gt 0 ]; do [ "$1" = "--model" ] && model="$2"; [ "$1" = "--resume" ] && session="$2"; shift; done
say '{"type":"system","subtype":"init","session_id":"'"$session"'","model":"claude-'"$model"'-5-5"}'
while IFS= read -r line; do
  # Ladder's first line asks what the program can do. Its answer lists Claude Code's commands.
  case "$line" in *'"initialize"'*)
    say '{"type":"control_response","response":{"subtype":"success","request_id":"ladder-start","response":{"commands":[{"name":"compact","description":"Free up context by summarizing the conversation so far","argumentHint":"<optional custom summarization instructions>"},{"name":"clear","description":"Start a new session with empty context","argumentHint":"[name]"},{"name":"context","description":"Show current context usage","argumentHint":""},{"name":"ladder:page","description":"(ladder) Show the user a page in Ladder.\nUse it for a plan.","argumentHint":""}]}}}'
    continue ;;
  esac
  printf '%s\n' "$line" >> "HEARD"
  case "$line" in
  *'"interrupt"'*)
    say '{"type":"result","subtype":"error_during_execution","is_error":true}' ;;
  *'"set_model"'*)
    asked=$(printf '%s' "$line" | sed 's/.*"request_id":"\([^"]*\)".*/\1/')
    wants=$(printf '%s' "$line" | sed -n 's/.*"model":"\([^"]*\)".*/\1/p')
    case "$wants" in
    bad-model)
      say '{"type":"control_response","response":{"subtype":"error","request_id":"'"$asked"'","error":"Model '"'"'bad-model'"'"' not found","model":"claude-'"$model"'-5-5"}}' ;;
    *)
      model=${wants:-opus}
      say '{"type":"control_response","response":{"subtype":"success","request_id":"'"$asked"'","response":{"model":"claude-'"$model"'-5-5"}}}' ;;
    esac ;;
  *'"control_response"'*)
    case "$line" in
    *'"allow"'*)
      say '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t2","is_error":false}]}}'
      say '{"type":"assistant","message":{"content":[{"type":"text","text":"It ran."}]}}' ;;
    *)
      say '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t2","is_error":true}]}}'
      say '{"type":"assistant","message":{"content":[{"type":"text","text":"I left it."}]}}' ;;
    esac
    done_ ;;
  *'a table'*)
    say '{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}}'
    say '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"## Paint\n\n| Colour | Litres |\n"}}}'
    say '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"|---|---|\n| Red | 2 |\n"}}}'
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"## Paint\n\n| Colour | Litres |\n|---|---|\n| Red | 2 |\n\n```ui\nerror(1)\n```\n\nSee `!1+1` too."}]}}'
    done_ ;;
  *'run it'*)
    say '{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"t2","name":"Bash","input":{}}}}'
    say '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"make paint","description":"Make the paint"}}]}}'
    say '{"type":"control_request","request_id":"r1","request":{"subtype":"can_use_tool","tool_name":"Bash","input":{"command":"make paint","description":"Make the paint"},"tool_use_id":"t2"}}' ;;
  *'go slow'*)
    say '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t3","name":"Read","input":{"file_path":"/tmp/notes.md"}}]}}' ;;
  *'wait your turn'*)
    ;;   # Claude Code says nothing of words that come while it works, till its turn has ended
  *'many steps'*)
    for n in 4 5 6 7 8; do
      say '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t'$n'","name":"Grep","input":{"pattern":"paint'$n'"}}]}}'
      say '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t'$n'","is_error":false}]}}'
    done
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"Five looks."}]}}'
    done_ ;;
  *'a link'*)
    # Antigravity names a file and its lines with a file:// address
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"Updated [plan.md](file://PAGE):\n\n- **[Paint](file://PAGE#L5-L7):** more paint.\n- **[A note](file://NOTES#L41):** a note."}]}}'
    done_ ;;
  *'the Commit button'*)
    # With no blank line after the first line, as Antigravity wrote one on 27 November 2026
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"```\nBuy less paint\nThe plan says why.\n```"}]}}'
    done_ ;;
  *)
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"Plain **words**."}]}}'
    done_ ;;
  esac
done
""", "HEARD" => heard, "PAGE" => page, "NOTES" => replace(notes, ' ' => "%20")))
chmod(agent, 0o755)
K.SESSION_COMMAND[] = Cmd([agent])

# The models of the agents, as Ladder would get them from Claude Code, Grok and Codex. No agent is asked for them.
const said_models = """{"type":"control_response","response":{"subtype":"success","request_id":"ladder-models","response":{"models":[
  {"value":"default","resolvedModel":"claude-opus-5-5","displayName":"Default (recommended)","description":"Opus 5.5 · Best for everyday, complex tasks"},
  {"value":"opus","resolvedModel":"claude-opus-5-5","displayName":"Opus 5.5","description":"For complex work and everyday tasks"},
  {"value":"sonnet","resolvedModel":"claude-sonnet-5-5","displayName":"Sonnet 5.5","description":"Most efficient for simpler tasks"},
  {"value":"haiku","resolvedModel":"claude-haiku-5-5","displayName":"Haiku 5.5","description":"Fastest for quick answers"},
  {"value":"claude-opus-4-8","resolvedModel":"claude-opus-4-8","displayName":"Opus 4.8","description":"Best for everyday, complex tasks"}]}}}"""
K.AGENT_MODELS["Claude"] = K.claude_list(replace(said_models, '\n' => ""))
K.AGENT_MODELS["Grok"] = K.grok_list("You are not authenticated.\n\nDefault model: grok-4.7\n\nAvailable models:\n  * grok-4.7 (default)\n  - grok-4.6\n")
K.AGENT_MODELS["Codex"] = K.model_list([K.AgentModel("gpt-5.5", "GPT-5.5"), K.AgentModel("gpt-5.4-mini", "GPT-5.4-Mini")])
# Some of what `agy models` printed on 27 November 2026: a model with each effort is a line for each, in no order of effort
K.AGENT_MODELS["Antigravity"] = K.antigravity_list("""
  gemini-4-neon-high	Gemini 4 Neon (High)
  gemini-4-neon-xhigh	Gemini 4 Neon (XHigh)
  gemini-4-neon-medium	Gemini 4 Neon (Medium)
  gemini-4-neon-low	Gemini 4 Neon (Low)
  gemini-4-carbon-medium	Gemini 4 Carbon (Medium)
  gemini-4-carbon-high	Gemini 4 Carbon (High)
  gemini-4-carbon-low	Gemini 4 Carbon (Low)
  gemini-pro-orchestrator-neon	Orchestrator (Neon)
  gemini-3.8-flash-high	Gemini 3.8 Flash (High)
  gemini-3.8-flash-low	Gemini 3.8 Flash (Low)
  gpt-oss-120b-medium	GPT-OSS 120B (Medium)
  """)

# An agent that works by turns: it's started for each thing that you say, with the agent's name, the session's name and your words.
# It prints the lines that Codex prints, as its source says.
const turns = joinpath(dir, "turns.txt")
const turner = joinpath(dir, "turn-agent")
write(turner, replace(raw"""
#!/bin/sh
agent="$1"; id="$2"; words="$3"
printf '%s|%s|%s\n' "$agent" "$id" "$(printf '%s' "$words" | tr '\n' ' ')" >> "TURNS"
say() { printf '%s\n' "$1"; }
case "$words" in
*'fail please'*) echo "warning: something small" >&2; echo "Error: no key for $agent" >&2; echo "at line 3" >&2; exit 1 ;;
*'go slow'*) exec sleep 30 ;;
esac
  say '{"type":"thread.started","thread_id":"sess-Codex"}'
  say '{"type":"turn.started"}'
  say '{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"I will read it."}}'
  say '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"cat plan.md","aggregated_output":"","status":"in_progress"}}'
  say '{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"cat plan.md","aggregated_output":"x","exit_code":0,"status":"completed"}}'
  say '{"type":"item.completed","item":{"id":"item_2","type":"agent_message","text":"It has paint."}}'
  say '{"type":"turn.completed","usage":{}}'
""", "TURNS" => turns))
chmod(turner, 0o755)

# Antigravity's program for a session, `agy acp`: it reads the lines of JSON-RPC that Ladder writes, writes each down, and
# answers by what they hold, with lines like those that `agy acp` 1.5.18 printed on 27 November 2026.
# A session that comes with rules is Grok's, and "make it taller" gets lines like those that `grok agent stdio` 1.0.94 printed that day.
const acp_heard = joinpath(dir, "acp-heard.txt")
const acp_agent = joinpath(dir, "acp-agent")
write(acp_agent, replace(raw"""
#!/bin/sh
say() { printf '%s\n' "$1"; }
answer() { say '{"jsonrpc":"2.0","result":'"$2"',"id":"'"$1"'"}'; }
update() { say '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"'"$sid"'","update":'"$1"'}}'; }
run() { printf '{"sessionUpdate":"%s","toolCallId":"call_2","name":"run_command","status":"%s","kind":"execute","title":"make paint","rawInput":{"CommandLine":"make paint","toolSummary":"Make the paint"}}' "$1" "$2"; }
model=gemini-4-neon-low
sid=""
prompt=""
while IFS= read -r line; do
  printf '%s\n' "$line" >> "HEARD"
  id=$(printf '%s' "$line" | sed -n 's/.*"id":"\(ladder-[0-9]*\)".*/\1/p')
  case "$line" in
  *'"optionId":"allow"'*)
    update "$(run tool_call_update completed)"
    update '{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"It ran."}}'
    answer "$prompt" '{"stopReason":"end_turn"}' ;;
  *'"optionId":"deny"'*)
    update "$(run tool_call_update failed)"
    update '{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"I left it."}}'
    answer "$prompt" '{"stopReason":"end_turn"}' ;;
  *'"outcome":"cancelled"'*) ;;
  *'"initialize"'*)
    answer "$id" '{"protocolVersion":1,"agentCapabilities":{"loadSession":true},"agentInfo":{"name":"Antigravity ACP Server","version":"1.5.18"}}' ;;
  *'"session/list"'*)
    answer "$id" '{"sessions":[{"sessionId":"old-1","cwd":"DIR","title":"Paint prices","updatedAt":"2026-11-26T12:28:58Z"},{"sessionId":"far","cwd":"/somewhere/else","title":"Elsewhere","updatedAt":"2026-11-27T02:00:00Z"},{"sessionId":"old-2","cwd":"DIR","title":"Brush sizes","updatedAt":"2026-11-27T01:00:00.944933+00:00"},{"sessionId":"bad","cwd":"DIR","title":"A lost one","updatedAt":"2026-11-20T01:00:00Z"}]}' ;;
  *'"session/load"'*)
    case "$line" in
    *'"sessionId":"bad"'*) say '{"jsonrpc":"2.0","error":{"code":-32002,"message":"Resource not found: bad"},"id":"'"$id"'"}' ;;
    *)
      sid=$(printf '%s' "$line" | sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p')
      update '{"sessionUpdate":"user_message_chunk","content":{"type":"text","text":"<ladder>\nThe window shows the file /tmp/plan.md.\nNothing is selected.\n</ladder>\n\nWhat does paint cost?"}}'
      update '{"sessionUpdate":"agent_thought_chunk","content":{"type":"text","text":"Prices need a look."}}'
      update '{"sessionUpdate":"tool_call","toolCallId":"call_9","name":"view_file","status":"completed","kind":"read","title":"prices.md","rawInput":{"AbsolutePath":"/tmp/prices.md"}}'
      update '{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"Paint costs **40**."}}'
      update '{"sessionUpdate":"session_info_update","title":"Paint prices"}'
      answer "$id" '{"models":{"currentModelId":"'"$model"'"}}' ;;
    esac ;;
  *'"session/new"'*'"rules":'*)
    sid=grok-1
    answer "$id" '{"sessionId":"grok-1","models":{"availableModels":[{"modelId":"grok-4.7","name":"Grok 4.7"},{"modelId":"grok-4.6","name":"Grok 4.6"}],"currentModelId":"grok-4.7"},"configOptions":[]}'
    update '{"sessionUpdate":"available_commands_update","availableCommands":[{"name":"context","description":"Show context window usage and session stats","input":null}]}' ;;
  *'"session/new"'*)
    sid=acp-1
    answer "$id" '{"sessionId":"acp-1","models":{"availableModels":[{"modelId":"gemini-4-neon-low","name":"Gemini 4 Neon (Low)"}],"currentModelId":"'"$model"'"},"modes":{"currentModeId":"default"}}'
    update '{"sessionUpdate":"available_commands_update","availableCommands":[{"name":"goal","description":"Run until the specified goal is completely finished.","input":{"hint":"<objective>"}},{"name":"compact","description":"Compact the conversation now.","input":null},{"name":"goal","description":"A skill with the same name","input":null}]}' ;;
  *'"session/resume"'*)
    case "$line" in
    *'"sessionId":"gone"'*) say '{"jsonrpc":"2.0","error":{"code":-32002,"message":"Resource not found: gone"},"id":"'"$id"'"}' ;;
    *) sid=$(printf '%s' "$line" | sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p'); answer "$id" '{"sessionId":"'"$sid"'","models":{"currentModelId":"'"$model"'"}}' ;;
    esac ;;
  *'"session/set_mode"'*) answer "$id" '{}' ;;
  *'"session/set_model"'*)
    case "$line" in
    *'"modelId":"bad-model"'*) say '{"jsonrpc":"2.0","error":{"code":-32602,"message":"invalid model selection: model bad-model is not recognized\nAvailable models:\n  Gemini 4 Neon (High)"},"id":"'"$id"'"}' ;;
    *) model=$(printf '%s' "$line" | sed -n 's/.*"modelId":"\([^"]*\)".*/\1/p'); answer "$id" '{}' ;;
    esac ;;
  *'"session/cancel"'*) answer "$prompt" '{"stopReason":"cancelled"}' ;;
  *'"session/prompt"'*)
    prompt=$id
    case "$line" in
    *'run it'*)
      update "$(run tool_call in_progress)"
      update "$(run tool_call_update pending)"
      say '{"jsonrpc":"2.0","method":"session/request_permission","params":{"sessionId":"'"$sid"'","toolCall":'"$(run tool_call pending)"',"options":[{"optionId":"allow","name":"Allow","kind":"allow_once"},{"optionId":"deny","name":"Deny","kind":"reject_once"}]},"id":"7"}' ;;
    *'make it taller'*)
      say '{"jsonrpc":"2.0","method":"_x.ai/mcp/init_progress","params":{"total":19,"connected":0,"sessionId":"grok-1"}}'
      say '{"jsonrpc":"2.0","method":"_x.ai/ask_user_question","params":{"sessionId":"grok-1"},"id":"g9"}'
      update '{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"I will make it taller."}}'
      say '{"jsonrpc":"2.0","method":"_x.ai/session_notification","params":{"sessionId":"grok-1","update":{"sessionUpdate":"tool_call_delta_chunk","tool_call_id":"c1","tool_index":0,"name":"use_tool"}}}'
      update '{"sessionUpdate":"tool_call","toolCallId":"c1","title":"use_tool","rawInput":{"tool_name":"ladder__julia","tool_input":{"code":"tall = 25"}},"_meta":{"x.ai/tool":{"version":1,"name":"use_tool","kind":"use_tool","namespace":"grok_build","label":"Use Tool","read_only":false}}}'
      update '{"sessionUpdate":"tool_call_update","toolCallId":"c1","kind":"other","title":"ladder__julia","locations":[],"rawInput":{"variant":"UseTool","tool_name":"ladder__julia","tool_input":{"code":"tall = 25"}},"_meta":{"x.ai/tool":{"version":1,"name":"use_tool","kind":"use_tool","namespace":"grok_build","label":"Use Tool","read_only":false}}}'
      update '{"sessionUpdate":"tool_call_update","toolCallId":"c1","status":"completed","rawOutput":{"type":"MCP","tool_name":"julia","server_name":"ladder","output":{"OkayOutput":"25"}}}'
      update '{"sessionUpdate":"tool_call","toolCallId":"c2","title":"read_file","rawInput":{"target_file":"/tmp/plan.md"},"_meta":{"x.ai/tool":{"version":1,"name":"read_file","kind":"read","namespace":"grok_build","label":"Read","read_only":true}}}'
      update '{"sessionUpdate":"tool_call_update","toolCallId":"c2","kind":"read","title":"Read `/tmp/plan.md`","locations":[{"path":"/tmp/plan.md"}],"rawInput":{"variant":"ReadFile","target_file":"/tmp/plan.md"},"_meta":{"x.ai/tool":{"version":1,"name":"read_file","kind":"read","namespace":"grok_build","label":"Read","read_only":true,"input":{"path":"/tmp/plan.md"}}}}'
      update '{"sessionUpdate":"tool_call_update","toolCallId":"c2","status":"completed","content":[{"type":"content","content":{"type":"text","text":"paint"}}],"rawOutput":{"type":"ReadFile"}}'
      update '{"sessionUpdate":"tool_call","toolCallId":"c3","title":"run_terminal_command","rawInput":{"command":"ls -la","description":"List the files"},"_meta":{"x.ai/tool":{"version":1,"name":"run_terminal_command","kind":"execute","namespace":"grok_build","label":"Run Command","read_only":false}}}'
      update '{"sessionUpdate":"tool_call_update","toolCallId":"c3","kind":"execute","title":"Execute `ls -la`","content":[],"locations":[],"rawInput":{"variant":"Bash","command":"ls -la","description":"List the files","is_background":false},"_meta":{"x.ai/tool":{"version":1,"name":"run_terminal_command","kind":"execute","namespace":"grok_build","label":"Run Command","read_only":false,"input":{"command":"ls -la"}}}}'
      update '{"sessionUpdate":"tool_call_update","toolCallId":"c3","status":"in_progress","content":[],"rawOutput":{"type":"Bash","exit_code":0,"command":"ls -la"}}'
      update '{"sessionUpdate":"tool_call_update","toolCallId":"c3","status":"completed","content":[],"rawOutput":{"type":"Bash","exit_code":0,"command":"ls -la"}}'
      update '{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"It is 25 tall."}}'
      answer "$id" '{"stopReason":"end_turn","_meta":{"sessionId":"grok-1","modelId":"grok-4.7"}}' ;;
    *'go slow'*)
      update '{"sessionUpdate":"tool_call","toolCallId":"call_3","name":"view_file","status":"in_progress","kind":"read","title":"notes.md","rawInput":{"AbsolutePath":"/tmp/notes.md"}}' ;;
    *)
      update '{"sessionUpdate":"agent_thought_chunk","content":{"type":"text","text":"The plan needs reading."}}'
      update '{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"I will read"}}'
      update '{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":" it."}}'
      update '{"sessionUpdate":"tool_call","toolCallId":"call_1","name":"view_file","status":"in_progress","kind":"read","title":"plan.md","rawInput":{"AbsolutePath":"/tmp/plan.md"}}'
      update '{"sessionUpdate":"tool_call_update","toolCallId":"call_1","name":"view_file","status":"completed","kind":"read","title":"plan.md","rawInput":{"AbsolutePath":"/tmp/plan.md"}}'
      update '{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"It has paint."}}'
      update '{"sessionUpdate":"usage_update","used":12679,"size":1048576}'
      answer "$id" '{"stopReason":"end_turn","usage":{"inputTokens":1}}' ;;
    esac ;;
  esac
done
""", "HEARD" => acp_heard, "DIR" => dir))
chmod(acp_agent, 0o755)
K.ACP_COMMAND[] = Cmd([acp_agent])
"The lines of JSON-RPC that Antigravity's stand-in has heard"
acp_lines() = isfile(acp_heard) ? readlines(acp_heard) : String[]

const e = K.build_editor(page)
const w = Window(e, size=(900px, 700px))
frames(win=w, n=2) = foreach(_ -> Base.invokelatest(frame, win), 1:n)
frames(w, 4)
K.focus(e)

"Draw frames until `f()` is true, for 5 seconds at the most. The agent's lines are read between frames."
until(f) = begin
  from = time()
  while time() - from < 5
    frames(w, 1)
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
click(x, y) = (w.mouse = typeof(w.mouse)(x, y); onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames())
"Every rectangle in `r`, as it was last drawn"
flat(r, out=Any[]) = (push!(out, r); try foreach(c -> flat(c, out), r.children) catch end; out)
"The rectangle with the name `name` in the window, or nothing"
named(name) = (k = findfirst(r -> hasproperty(r.from, :name) && r.from.name == name, flat(K.rect(e))); k === nothing ? nothing : flat(K.rect(e))[k])
heard_lines() = isfile(heard) ? readlines(heard) : String[]
const pane = K.agent_pane(e)
items() = pane.session.items
"Move the mouse to `x`, `y`"
mouse_to(x, y) = (w.mouse = typeof(w.mouse)(x, y); onmouse(w, MouseMove(w.mouse, w)); frames())
"Move the mouse onto the box that you type in, at its left end, where no button is, so the model's button shows"
on_slot() = (r = K.rect(K.pane_slot(pane)); mouse_to(r.left + 12px, r.top + r.height / 2))
"Click the model's button, which shows only while the mouse is over the box that you type in"
model_click() = (on_slot(); b = named("Model"); click(b.left + 10px, b.top + 10px); frames())

try
  @testset "Agent Mode widens the window, with the agent at the left, the page on a card and the outline at the right" begin
    @test haskey(K.COMMANDS, :agent_mode)
    @test !K.agent_mode(e) && named("Agent") === nothing
    K.agent_mode!(e)
    frames(w, 3)
    @test K.agent_mode(e) && K.agent_shows(e)
    @test w.size[1] > 900px && w.size[2] == 700px
    left, card, right = named("Agent"), named("Page card"), named("Outline")
    @test left !== nothing && card !== nothing && right !== nothing
    # The outline ends at the window's right edge, the card is beside it, and the pane has all the rest
    @test right.left + right.width == w.size[1]
    @test card.left + card.width + K.PAGE_CARD_GAP == right.left
    @test left.left == 0px && left.left + left.width + K.PAGE_CARD_GAP == card.left
    @test abs(left.width - K.AGENT_W) <= 8px
    @test card.top == K.PAGE_CARD_GAP && card.top + card.height == w.size[2] - K.PAGE_CARD_GAP
    # Each corner of the card is beside a pane, so all four have the card's own radius
    @test (card.from.radius.tl, card.from.radius.tr, card.from.radius.br, card.from.radius.bl) == ntuple(_ -> K.PAGE_CARD_ROUND, 4)
    # The card has the shape of a sheet of paper that stands up, and the page's text is on it
    @test isapprox(K.num(card.height) / K.num(card.width), √2, atol=0.01)
    @test e.origin[1] >= card.left + K.PAGE_X && e.origin[1] + e.width <= card.left + card.width - K.PAGE_X
    # The words that you type have the keyboard
    @test w.focus === pane.field
    # A wider window gives the agent's pane the new room. The card keeps its width, beside the outline.
    was = (left.width, card.width, right.width)
    w.size = typeof(w.size)(w.size[1] + 300px, w.size[2])
    frames(w, 3)
    left, card, right = named("Agent"), named("Page card"), named("Outline")
    @test left.width == was[1] + 300px - (right.width - was[3]) && card.width == was[2]
    @test card.left + card.width + K.PAGE_CARD_GAP == right.left && left.width + K.PAGE_CARD_GAP == card.left
    w.size = typeof(w.size)(w.size[1] - 300px, w.size[2])
    frames(w, 3)
  end

  @testset "The outline lists the page's headings, and a click goes to one" begin
    rows = [r.from.from for r in flat(K.rect(e)) if hasproperty(r.from, :from) && r.from.from isa K.OutlineRow]
    @test [r.title for r in rows] == ["Paint", "Colours", "Brushes", "Done"]
    @test [r.depth for r in rows] == [0, 1, 0, 0]
    @test rows[1].opens && !rows[2].opens
    # The page's one biggest heading is the pane's title, and its sections are the headings a level down
    words = [r.from.content for r in flat(named("Outline")) if hasproperty(r.from, :content)]
    @test "The plan" in words && "3 sections" in words
    # The page is at its top, so the first section is the one that shows
    brushes = rows[3]
    at = K.rect(brushes)
    click(at.left + at.width - 20px, at.top + at.height / 2)
    @test e.buf.caret[1] == findfirst(==("## Brushes"), e.buf.lines)
    frames(w, 3)
    @test brushes.now && e.scroll.offset > 0px
    # A click on a heading's arrow hides the headings under it
    paint = K.rect(rows[1])
    click(paint.left + 14px, paint.top + paint.height / 2)
    rows = [r.from.from for r in flat(K.rect(e)) if hasproperty(r.from, :from) && r.from.from isa K.OutlineRow]
    @test [r.title for r in rows] == ["Paint", "Brushes", "Done"] && rows[1].folded
  end

  @testset "The outline of an HTML file lists the headings of its page, and the agent is told the one in view" begin
    html = joinpath(dir, "shop.html")
    write(html, """<!DOCTYPE html><title>Our shop</title>
      <body style="margin:0;font:16px/20px Helvetica">
      <h2 style="position:absolute;left:-9999px;width:1px;height:1px;overflow:hidden">Skip to the words</h2>
      <h1 style="margin:0">The shop <a href="#">#</a></h1><p style="height:200px">Words.</p>
      <h2>Paint</h2><div style="height:900px"></div>
      <h3>Colours</h3><div style="height:900px"></div>
      <h2>Brushes</h2><p>Buy <b>soft</b> brushes for the walls.</p><div style="height:900px"></div>
      <h2> </h2>
      <h2>Done</h2><div style="height:900px"></div></body>""")
    eh = K.build_editor(html)
    wh = Window(eh, size=(900px, 700px))
    frames(wh, 3)
    K.agent_mode!(eh)
    frames(wh, 3)
    @test K.html_shown(eh) && K.agent_shows(eh)
    b = eh.nodes[(:html, html)].browser
    all_rects = flat(K.rect(eh))
    rows = [r.from.from for r in all_rects if hasproperty(r.from, :from) && r.from.from isa K.OutlineRow]
    # A heading as small as a dot and one with no words are left out, and so is the # that links to a heading
    @test [r.title for r in rows] == ["Paint", "Colours", "Brushes", "Done"]
    @test [r.depth for r in rows] == [0, 1, 0, 0] && rows[1].opens
    words = [r.from.content for r in all_rects if hasproperty(r.from, :content)]
    @test "The shop" in words && "3 sections" in words
    # At the top of the page, the section in view is the page's title. The agent hears no caret: the page has none.
    @test K.page_context(eh) == ("The shop", "<ladder>\nThe window shows the file $html.\nThe section in view is \"The shop\".\nNothing is selected.\n</ladder>")
    # A click on a heading puts it near the top of the window, and the outline marks it
    brushes = rows[3]
    at = K.rect(brushes)
    wh.mouse = typeof(wh.mouse)(at.left + at.width - 20px, at.top + at.height / 2)
    onkey(wh, KeyPress{Keys.mouse_left}(0, wh))
    frames(wh, 3)
    top = K.html_outline(eh)[2][brushes.line]   # the page's title is the first of its headings
    @test abs(K.Browsers.scrolled(b) - (top - 24)) < 1 && brushes.now && !rows[1].now
    @test K.page_context(eh) == ("Brushes", "<ladder>\nThe window shows the file $html.\nThe section in view is \"Brushes\".\nNothing is selected.\n</ladder>")
    # Two clicks on a word select it, and the agent gets its exact text and the paragraph that holds it, as the page shows them
    ws = K.Browsers.page_words(b)
    t = String(reduce(vcat, [w.letters for w in ws]))
    soft = length(SubString(t, 1, prevind(t, first(findfirst("soft", t)))))   # the place before "soft" in the page's words
    spot(place) = (w = ws[K.Browsers.Select.words_at(ws, place)]; r = K.rect(b);
                   (r.left + px(w.edges[place - w.from + 1] + 0.5), r.top + px(w.top + w.tall / 2 - K.Browsers.scrolled(b))))
    hit((x, y)) = begin
      wh.mouse = typeof(wh.mouse)(x, y)
      onmouse(wh, MouseMove(wh.mouse, wh))
      wh.keys |= Keys.mouse_left; onkey(wh, KeyPress{Keys.mouse_left}(0, wh))
      wh.keys ⊻= Keys.mouse_left; onkey(wh, KeyRelease{Keys.mouse_left}(0, wh))
    end
    hit(spot(soft + 2)); hit(spot(soft + 2))
    frames(wh, 2)
    @test K.Browsers.selected_words(b) == "soft"
    # It goes with where it is in the file, as the file's line and columns
    L = findfirst(l -> occursin("<b>soft", l), readlines(html))
    line = readlines(html)[L]
    C = length(SubString(line, 1, prevind(line, first(findfirst("soft", line))))) + 1
    @test K.page_context(eh) == ("Brushes · selection", "<ladder>\nThe window shows the file $html.\nThe section in view is \"Brushes\".\n" *
      "In the file, the selection goes from line $L, column $C to line $L, column $(C + 4). Its exact text, as the page shows it:\n" *
      "<selection>\nsoft\n</selection>\nIt's in this paragraph:\n<paragraph>\nBuy soft brushes for the walls.\n</paragraph>\n</ladder>")
    # One click puts the caret there: the agent gets the words before it, and its paragraph
    sleep(0.5)
    hit(spot(soft))
    frames(wh, 2)
    @test K.Browsers.selected_words(b) == ""
    @test endswith(K.page_context(eh)[2], "\nThe caret is where the user last clicked, at line $L, column $C of the file, after \"Buy\" in this paragraph:\n" *
      "<paragraph>\nBuy soft brushes for the walls.\n</paragraph>\nNothing is selected.\n</ladder>")
    # What the agent is told at the start says how to read these
    @test occursin("<paragraph>", K.session_brief()) && occursin("where the user last clicked", K.session_brief()) && occursin("lines and columns in the HTML file", K.session_brief())
    # The wheel moves the page on, and the outline follows it
    K.Browsers.scroll!(b, K.html_outline(eh)[2][rows[4].line] - 10)
    frames(wh, 3)
    @test rows[4].now && !brushes.now && first(K.page_context(eh)) == "Done"
    # A page with no headings still has its outline, which says so, with the title that its HTML gives it
    write(html, "<title>Bare</title><p>Words.</p>")
    for _ in 1:250
      frames(wh, 1)
      isempty(K.html_outline(eh)[1]) && break
      sleep(0.02)
    end
    frames(wh, 2)
    words = [r.from.content for r in flat(K.rect(eh)) if hasproperty(r.from, :content)]
    @test "Bare" in words && "No headings" in words
    @test K.page_context(eh) == ("shop.html", "<ladder>\nThe window shows the file $html.\nNothing is selected.\n</ladder>")
    K.close_agent!(eh)
  end

  @testset "A file of a kind that has no outline, like a table, has nothing at the right, and the window grows only for the agent and the card" begin
    csv = joinpath(dir, "sizes.csv")
    write(csv, "name,size\nsmall,1\nbig,2\n")
    ec = K.build_editor(csv)
    wc = Window(ec, size=(900px, 700px))
    frames(wc, 3)
    @test ec.right   # the setting shows the panel at the right, so only the missing outline hides it
    K.agent_mode!(ec)
    frames(wc, 3)
    @test K.agent_shows(ec) && K.page_outline(ec) === nothing && K.right_view(ec) === nothing
    rects = flat(K.rect(ec))
    card = rects[findfirst(r -> hasproperty(r.from, :name) && r.from.name == "Page card", rects)]
    @test !any(r -> hasproperty(r.from, :name) && r.from.name == "Outline", rects)
    @test card.left + card.width + K.PAGE_CARD_GAP == wc.size[1]
    @test card.from.radius.tr == card.from.radius.br == K.WINDOW_ROUND - K.PAGE_CARD_GAP
    # The top bar has no button for an outline
    @test !any(r -> hasproperty(r.from, :from) && r.from.from isa K.ToolButton && r.from.from.action == :right_panel, rects)
    # The agent's pane and a card in the shape of a sheet of paper fit in 900px, so the window stays as wide as it was
    @test wc.size[1] == 900px
    # The table's text, a level down, has no outline either
    K.level!(ec, 3)
    frames(wc, 3)
    @test ec.buf.view == :text && K.page_outline(ec) === nothing && K.right_view(ec) === nothing
    K.close_agent!(ec)
  end

  @testset "A page of text with no headings yet has its outline, which says so" begin
    blank = joinpath(dir, "blank.md")
    write(blank, "Words with no heading.\n")
    eb = K.build_editor(blank)
    wb = Window(eb, size=(900px, 700px))
    frames(wb, 3)
    K.agent_mode!(eb)
    frames(wb, 3)
    @test K.page_outline(eb) == K.Entry[] && K.right_view(eb) isa K.OutlinePane
    rects = flat(K.rect(eb))
    @test any(r -> hasproperty(r.from, :name) && r.from.name == "Outline", rects)
    @test "No headings yet" in [r.from.content for r in rects if hasproperty(r.from, :content)]
    # The window grew for the outline too
    @test wb.size[1] > 900px
    K.close_agent!(eb)
  end

  @testset "Return gives your words to the agent, with what the window shows, and its answer shows as a page" begin
    K.focus(pane.field)
    # The field is one line tall, with the round send button at its right
    foot, send = named("Agent foot"), named("Send")
    @test foot.height < 70px && send.width == 28px && named("About") === nothing
    # It's a slot, as in a session's file: its ends are half circles, and the button has the same middle as its round end
    slot = foot.children[1]
    @test K.num(slot.from.radius.tl) ≈ K.num(slot.from.radius.br) ≈ K.num(slot.height) / 2
    @test abs(K.num(send.top + send.height / 2 - (slot.top + slot.height / 2))) < 0.5
    @test abs(K.num(slot.left + slot.width - (send.left + send.width / 2) - slot.height / 2)) < 0.5
    typed("Make a table")
    @test pane.field.buf.lines == ["Make a table"]
    # The words are laid out as wide as the box that shows them, less part of a pixel, so the box doesn't cut off the end of a full line
    @test 0px <= named("Typed words").width - pane.field.width < 1px
    sleep(2K.SEND_GROWS); frames()
    @test named("About") === nothing && named("Agent foot").height == foot.height
    # With the mouse on the button, it opens to the left over the words, to show what goes with them. Nothing else moves.
    words = (pane.field.width, length(pane.field.layout))
    w.mouse = typeof(w.mouse)(send.left + 14px, send.top + 14px)
    onmouse(w, MouseMove(w.mouse, w)); frames(w, 3); sleep(2K.SEND_GROWS); frames()
    about, pill = named("About"), named("Send pill")
    @test about !== nothing && pill.width > 28px + about.width - 1px && pill.left < send.left && pill.left + pill.width == send.left + send.width
    # The model's button doesn't show beside it then, though the mouse is over the box that you type in
    @test named("Model") === nothing
    @test (named("Send").left, named("Send").width, named("Agent foot").height) == (send.left, 28px, foot.height)
    @test (pane.field.width, length(pane.field.layout)) == words && pill.left < send.left - 40px
    # The tooltip says that the words go with what the button shows
    tip = only(p for p in K.popups(w) if p.key == :tooltip)
    @test any(r -> occursin("Send with context  ⏎", sprint(show, r.from)), flat(tip.scene))
    # It shuts when the mouse leaves
    w.mouse = typeof(w.mouse)(send.left - 200px, send.top - 300px)
    onmouse(w, MouseMove(w.mouse, w)); frames(w, 3); sleep(2K.SEND_GROWS); frames()
    @test named("About") === nothing && named("Send pill").width == 28px
    press(Keys.enter)
    @test pane.session !== nothing && pane.field.buf.lines == [""]
    @test w.focus === pane.field
    ok = until(() -> !pane.session.busy)
    @test ok
    said = heard_lines()
    @test length(said) == 1 && occursin("\"type\":\"user\"", said[1]) && occursin("Make a table", said[1])
    # The outline's click put the section Brushes at the top of the window
    @test occursin("<ladder>\\nThe window shows the file $page.\\nThe section in view is \\\"Brushes\\\".\\nThe caret is on line", said[1]) && occursin("under the heading \\\"Brushes\\\".\\nNothing is selected.\\n</ladder>\\n\\nMake a table", said[1])
    @test pane.session.id == "test-session"
    # The pane's heading is in the top bar, after the window's own buttons, so the talk starts right under the bar
    head, plus = named("Agent head"), named("New session")
    @test head !== nothing && head.top >= 0px && head.top + head.height <= K.TOPBAR_H && head.left >= 70px
    @test plus !== nothing && plus.top + plus.height <= K.TOPBAR_H && head.left + head.width <= plus.left < named("Agent").width
    @test items()[1] isa K.YouSaid && items()[1].words == "Make a table" && items()[1].about == "Brushes"
    # The words came in pieces, and they're one reply
    @test length(items()) == 2 && items()[2] isa K.AgentReply && items()[2].whole
    sub = pane.parts[(:reply, objectid(items()[2]))]
    @test sub.buf.lines[1] == "## Paint"
    # The table is a table, not its text
    @test any(it -> !(it.content isa K.Flow), sub.layout)
    @test named("Reply") !== nothing && named("You said") !== nothing
    # What the agent says runs as a page does: a sum in a line shows what it comes to. agent_session_test has more.
    @test !K.foreign(sub.buf.path)
    @test K.made(sub, "1 + 1", 1) == ("2", false)
  end

  @testset "The panes are dark whatever colours the page has, and the page keeps its own" begin
    sub = pane.parts[(:reply, objectid(items()[2]))]
    inks(ed) = unique(seg.face.color for it in ed.layout if it.content isa K.Flow for vl in it.content.lines for seg in vl.segs)
    @test e.theme == :sepia
    @test K.NIGHT.ink in inks(sub) && !(K.SEPIA.ink in inks(sub))
    @test K.SEPIA.ink in inks(e) && !(K.NIGHT.ink in inks(e))
    # After a frame, the page's colours are in use again
    @test K.colours.ink == K.SEPIA.ink && !K.pane_dark[]
    # Lines that were laid out in the page's colours, as before the pane was dark, are laid out again in the pane's
    empty!(sub.flows)
    K.layout!(sub, sub.width)
    @test K.SEPIA.ink in inks(sub)
    frames(w, 2)
    @test K.NIGHT.ink in inks(sub) && !(K.SEPIA.ink in inks(sub))
    # The agent's name and the outline's lines have the pane's colours, and the file's name in the top bar has the page's
    colour(words) = (k = findfirst(r -> hasproperty(r.from, :content) && r.from.content == words, flat(K.rect(e))); flat(K.rect(e))[k].from.color)
    @test colour("Claude") == K.NIGHT.ink
    @test colour("3 sections") == K.NIGHT.dim
    @test colour("plan.md") in (K.SEPIA.ink, K.SEPIA.dim)
  end

  @testset "The agent gets the caret's column, and the selection with where it starts and ends" begin
    b = e.buf
    i = findfirst(==("Buy paint."), b.lines)
    b.anchor, b.caret = (i, 4), (i, 9)
    pane.field.buf.lines = ["What is this?"]
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy)
    said = last(heard_lines())
    @test ok && occursin("The caret is on line $i, column 10, under the heading \\\"Paint\\\".", said)
    @test occursin("The selection goes from line $i, column 5 to line $i, column 10. Its exact text:\\n<selection>\\npaint\\n</selection>\\n</ladder>\\n\\nWhat is this?", said)
    # A selection over several lines has each of its lines, and one that's very long has only where it is
    j = findfirst(==("Red and blue."), b.lines)
    b.anchor, b.caret = (i, 4), (j, 3)
    @test K.text_between(b, (i, 4), (j, 3)) == "paint.\n\n### Colours\n\nRed"
    # The lines of the selection are as they are in the file, with nothing before them
    @test endswith(K.page_context(e)[2], "to line $j, column 4. Its exact text:\n<selection>\npaint.\n\n### Colours\n\nRed\n</selection>\n</ladder>")
    b.anchor, b.caret = (1, 0), K.line_end(b, length(b.lines))
    @test length(join(b.lines, "\n")) < K.MOST_PICKED && occursin("Its exact text:", K.page_context(e)[2])
    # The agent is told when nothing is selected, so it knows that Ladder left nothing out
    b.anchor = b.caret = (i, 0)
    @test !occursin("<selection>", K.page_context(e)[2]) && occursin("line $i, column 1,", K.page_context(e)[2])
    @test endswith(K.page_context(e)[2], "\nNothing is selected.\n</ladder>")
    # Selected text that holds the closing tag would end the block early, so only its place goes
    was = b.lines[i]
    b.lines[i] = "Buy </selection> paint."
    b.anchor, b.caret = (i, 0), (i, 20)
    told = K.page_context(e)[2]
    @test !occursin("<selection>", told) && occursin("to line $i, column 21. Read its text in the file.\n</ladder>", told)
    # A page with changes that aren't in its file says so. Ladder saves before a message, so that's a page it couldn't save.
    @test !K.dirty(b) && !occursin("aren't in the file", told)
    b.version += 1
    @test K.dirty(b) && occursin("The window shows the file $page. The window has changes that aren't in the file yet.\n", K.page_context(e)[2])
    b.version -= 1
    b.lines[i] = was
    b.anchor = b.caret = (i, 0)
    # What the agent is told at the start says how to read the block
    @test occursin("<ladder>", K.session_brief()) && occursin("column 1 is before the first character", K.session_brief())
  end

  @testset "A reply in plain words needs no pieces" begin
    pane.field.buf.lines = ["Say hello"]
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy)
    @test ok && last(items()) isa K.AgentReply && last(items()).text == "Plain **words**."
  end

  @testset "At the snake, the run with the caret in a reply shows its markup, as it does in the page" begin
    sub = pane.parts[(:reply, objectid(last(items())))]
    drawn() = join(seg.text for it in sub.layout if it.content isa K.Flow for vl in it.content.lines for seg in vl.segs)
    K.focus(sub)
    sub.buf.caret = sub.buf.anchor = (1, 9)   # in the bold words
    K.touch!(sub)
    frames()
    @test !e.plain && drawn() == "Plain words."
    # ⌘E in the reply takes the window down a level, and the reply and your words go down with it
    press(Keys.e, Keys.cmd)
    @test e.plain && K.low(e) && w.focus === sub
    @test sub.plain && pane.field.plain && drawn() == "Plain **words**."
    # With the caret in plain words, no run shows its markup
    sub.buf.caret = sub.buf.anchor = (1, 2)
    K.touch!(sub)
    frames()
    @test drawn() == "Plain words."
    # ⌘E again goes back up, in the page and in the reply
    sub.buf.caret = sub.buf.anchor = (1, 9)
    K.touch!(sub)
    press(Keys.e, Keys.cmd)
    @test !e.plain && !sub.plain && !pane.field.plain && drawn() == "Plain words."
    K.focus(pane.field)
    frames()
  end

  @testset "The agent asks before a command, and Allow lets it run" begin
    pane.field.buf.lines = ["Please run it"]
    K.send_words!(pane)
    ok = until(() -> last(items()) isa K.AgentWants)
    @test ok
    wants = last(items())
    step = items()[end-1]
    @test step isa K.AgentStep && step.words == "Make the paint" && step.state == :going
    @test wants.tool == "Bash" && wants.detail == "make paint" && wants.answer == :none
    frames(w, 3)   # the pane scrolls to what's new
    @test named("Agent asks") !== nothing && named("Allow") !== nothing && named("Refuse") !== nothing
    allow = named("Allow")
    click(allow.left + allow.width / 2, allow.top + allow.height / 2)
    @test wants.answer == :allowed
    ok = until(() -> !pane.session.busy)
    @test ok && step.state == :done && last(items()).text == "It ran."
    answer = last(heard_lines())
    @test occursin("\"control_response\"", answer) && occursin("\"request_id\":\"r1\"", answer) && occursin("\"behavior\":\"allow\"", answer)
    # The agent gets back what it asked to run
    @test occursin("\"updatedInput\":{\"command\":\"make paint\",\"description\":\"Make the paint\"}", answer)
    # Refuse says no
    pane.field.buf.lines = ["Now run it again"]
    K.send_words!(pane)
    ok = until(() -> last(items()) isa K.AgentWants)
    frames(w, 3)
    refuse = named("Refuse")
    click(refuse.left + refuse.width / 2, refuse.top + refuse.height / 2)
    ok = until(() -> !pane.session.busy)
    @test ok && occursin("\"behavior\":\"deny\"", last(heard_lines())) && last(items()).text == "I left it."
  end

  @testset "More than three steps in a row fold into one line, and the Stop button stops the agent" begin
    pane.field.buf.lines = ["Take many steps"]
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy)
    @test ok && count(it -> it isa K.AgentStep && startswith(it.words, "Looking for paint"), items()) == 5
    frames(w, 2)
    fold = named("Steps")
    @test fold !== nothing && count(r -> hasproperty(r.from, :name) && r.from.name == "Step", flat(K.rect(e))) == 1   # the one step of the command before
    click(fold.left + 30px, fold.top + fold.height / 2)
    @test count(r -> hasproperty(r.from, :name) && r.from.name == "Step", flat(K.rect(e))) == 6
    # A step that's under way keeps the agent busy, and the button at the foot stops it
    pane.field.buf.lines = ["Now go slow"]
    K.send_words!(pane)
    ok = until(() -> last(items()) isa K.AgentStep)
    @test ok && pane.session.busy && last(items()).words == "Reading notes.md" && last(items()).state == :going
    frames(w, 3)
    stop = named("Stop")
    @test stop !== nothing && named("Send") === nothing
    click(stop.left + stop.width / 2, stop.top + stop.height / 2)
    ok = until(() -> !pane.session.busy)
    @test ok && occursin("\"interrupt\"", last(heard_lines()))
    @test last(items()) isa K.SessionNote && !last(items()).bad && items()[end-1].state == :done
  end

  @testset "A key for the window works from the agent's pane, and Esc leaves your words" begin
    K.focus(pane.field)
    typed("half a thought")
    press(Keys.escape)
    @test pane.field.buf.lines == ["half a thought"] && w.focus === pane.field && K.agent_mode(e)
    # The agent is what agent mode is for, so nothing hides its pane. The sidebar's button and ⌘\ show the sidebar, with
    # its tabs and the folder's files, at the pane's left. The pane and the card give it the room, and both stay.
    buttons = [r.from.from.action for r in flat(K.rect(e)) if hasproperty(r.from, :from) && r.from.from isa K.ToolButton]
    @test :panel in buttons && :right_panel in buttons && :back in buttons
    @test !e.panel && named("Files") === nothing && named("Agent").left == 0px
    was = (named("Agent").width, named("Page card").left, named("Agent head").left)
    card_end = named("Page card").left + named("Page card").width
    window_was = (w.size[1], w.position[1])
    outline_was = named("Outline").width
    press(Keys.backslash, Keys.cmd)
    e.slid = 0.0
    frames(w, 3)
    files, agent, card = named("Files"), named("Agent"), named("Page card")
    @test e.panel && K.agent_shows(e) && files !== nothing && agent !== nothing
    @test files.left == 0px && files.width == K.panel_w(e) && agent.left == files.width
    @test agent.width >= K.AGENT_MIN && agent.left + agent.width + K.PAGE_CARD_GAP == card.left
    # The window grows by the sidebar's width where the screen has room, so the pane and the card keep their widths.
    # The outline is a part of the window's width until it's `OUTLINE_W`, so a wider window can give it a little of the pane's room.
    grew = w.size[1] - window_was[1]
    more = named("Outline").width - outline_was
    @test 0px <= grew <= files.width && card.left + card.width == card_end + grew - more && card.width >= K.PAGE_CARD_NARROWEST
    @test grew < files.width || ((agent.width, card.left) == (was[1] - more, was[2] + grew - more) && w.position[1] <= window_was[2])
    # It lists the folder's files, on the window's glass
    @test any(r -> hasproperty(r.from, :name) && r.from.name == "Folder", flat(files)) && files.from.background.color.alpha == 0
    # The agent's heading is over the agent's pane, and the two arrows are at the pane's right end
    @test named("Agent head").left >= files.width
    arrows = [r for r in flat(K.rect(e)) if hasproperty(r.from, :from) && r.from.from isa K.ToolButton && r.from.from.action in (:back, :forward)]
    @test length(arrows) == 2 && all(r -> files.width < r.left && r.left + r.width <= card.left, arrows)
    # The button's click hides the sidebar again, and the pane and the card are as they were
    press(Keys.backslash, Keys.cmd)
    e.slid = 0.0
    frames(w, 3)
    @test !e.panel && named("Files") === nothing && (w.size[1], w.position[1]) == window_was
    @test (named("Agent").width, named("Page card").left, named("Agent head").left) == was
    # A window that can't grow, like one that fills a screen, keeps its size: the pane and the card give the sidebar its room
    e.full_screen = true
    press(Keys.backslash, Keys.cmd)
    e.slid = 0.0
    frames(w, 3)
    files, agent, card = named("Files"), named("Agent"), named("Page card")
    @test e.panel && w.size[1] == window_was[1] && agent.left == files.width && card.left + card.width == card_end
    @test K.AGENT_MIN <= agent.width < was[1] && agent.left + agent.width + K.PAGE_CARD_GAP == card.left
    press(Keys.backslash, Keys.cmd)
    e.slid = 0.0
    e.full_screen = false
    frames(w, 3)
    @test !e.panel && w.size[1] == window_was[1] && (named("Agent").width, named("Page card").left) == was[1:2]
    # The button at the right end of the top bar hides the outline. The card stays beside the window's edge, and the agent has the room.
    K.toggle_right!(e)
    e.nodes[:right_slid] = (0.0, 0.0)
    frames(w, 2)
    @test named("Outline") === nothing && named("Page card").left + named("Page card").width + K.PAGE_CARD_GAP == w.size[1]
    @test named("Agent").width > was[1]
    # The card's right corners are in the window's corners, and have the window's curve, the gap less round
    r = named("Page card").from.radius
    @test r.tl == r.bl == K.PAGE_CARD_ROUND && r.tr == r.br == K.WINDOW_ROUND - K.PAGE_CARD_GAP
    K.toggle_right!(e)
    e.nodes[:right_slid] = (1.0, 0.0)
    frames(w, 2)
    @test named("Outline") !== nothing && (named("Agent").width, named("Page card").left) == was[1:2]
  end

  @testset "A drag of the strip beside the card gives the agent or the page more of the window" begin
    move(x, y) = (w.mouse = typeof(w.mouse)(x, y); onmouse(w, MouseMove(w.mouse, w)); frames(w, 2))
    hold() = (w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(w, 1))
    drop() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(w, 2))
    edge, card, left = named("Card edge"), named("Page card"), named("Agent")
    # The strip fills the gap between the agent's pane and the card
    @test edge !== nothing && edge.left == left.left + left.width && edge.left + edge.width == card.left
    @test K.PAGE_CARD_CHOSEN[] === nothing
    was = (agent=left.width, card=card.width, right=card.left + card.width, text=e.width)
    x, y = edge.left + 4px, edge.top + 300px
    # A drag to the right gives the agent 100px of the card. The card's right edge stays, and the page's text wraps in the new width.
    move(x, y); hold(); move(x + 60px, y); move(x + 100px, y); drop()
    card, left = named("Page card"), named("Agent")
    @test left.width == was.agent + 100px && card.width == was.card - 100px
    @test card.left + card.width == was.right && left.width + K.PAGE_CARD_GAP == card.left
    @test e.width == was.text - 100px
    @test K.PAGE_CARD_CHOSEN[] == card.width
    # A mouse that moves with no button down changes nothing
    move(x + 300px, y)
    @test named("Page card").width == was.card - 100px
    # A wider window gives the agent the new room, as before
    w.size = typeof(w.size)(w.size[1] + 200px, w.size[2]); frames(w, 3)
    @test named("Page card").width == was.card - 100px
    @test named("Agent").width == w.size[1] - named("Outline").width - named("Page card").width - 2K.PAGE_CARD_GAP > was.agent + 100px
    w.size = typeof(w.size)(w.size[1] - 200px, w.size[2]); frames(w, 3)
    # A drag to the left gives the page more, and stops while the agent still has its least width
    edge = named("Card edge")
    x = edge.left + 4px
    move(x, y); hold(); move(x - 150px, y); drop()
    @test named("Page card").width == was.card + 50px && named("Agent").width == was.agent - 50px
    edge = named("Card edge"); x = edge.left + 4px
    move(x, y); hold(); move(x - 2000px, y); drop()
    @test named("Agent").width == K.AGENT_MIN && named("Page card").left == K.AGENT_MIN + K.PAGE_CARD_GAP
    # A drag far to the right leaves the card its least width
    edge = named("Card edge"); x = edge.left + 4px
    move(x, y); hold(); move(x + 3000px, y); drop()
    @test named("Page card").width == K.PAGE_CARD_NARROWEST && named("Page card").left + K.PAGE_CARD_NARROWEST == was.right
    # Two clicks on the strip give the card a page's shape again
    edge = named("Card edge"); x = edge.left + 4px
    move(x, y); hold(); drop(); hold(); drop()
    @test K.PAGE_CARD_CHOSEN[] === nothing
    @test named("Page card").width == was.card && named("Agent").width == was.agent && e.width == was.text
  end

  @testset "The card's width is kept in the settings file" begin
    e.remember = true
    K.page_card!(e, 500px)
    @test occursin("\npagecard=500.0\n", read(K.settings_file(), String))
    K.PAGE_CARD_CHOSEN[] = nothing
    K.load_settings!(e)
    @test K.PAGE_CARD_CHOSEN[] == 500px
    frames(w, 2)
    @test named("Page card").width == 500px
    K.page_card!(e, nothing)
    @test occursin("\npagecard=\n", read(K.settings_file(), String))
    K.PAGE_CARD_CHOSEN[] = 500px
    K.load_settings!(e)
    @test K.PAGE_CARD_CHOSEN[] === nothing
    e.remember = false
    frames(w, 2)
  end

  @testset "Agent Mode again puts the window back, and the session stays" begin
    s = pane.session
    K.agent_mode!(e)
    frames(w, 3)
    @test !K.agent_mode(e) && w.size[1] == 900px
    @test named("Agent") === nothing && named("Page card") === nothing && named("Outline") === nothing
    @test !e.panel
    @test pane.session === s && K.running(s)
    K.agent_mode!(e)
    frames(w, 3)
    @test named("Reply") !== nothing && pane.field.buf.lines == ["half a thought"]
    # End Agent Session ends the program, and the next words start another
    K.end_agent_session!(e)
    ok = until(() -> !K.running(s))
    @test ok && pane.session === nothing && named("Reply") === nothing
  end

  @testset "A click on the agent's name lists the agents, and Codex works by turns" begin
    name = named("Agent name")
    @test name !== nothing && name.top + name.height <= K.TOPBAR_H
    click(name.left + 10px, name.top + 10px)
    frames()
    menus = [p for p in K.popups(w) if p.key == K.AGENT_MENU]
    @test length(menus) == 1
    # Each agent has a row with its logo, and the pane's agent has a tick
    rows() = [r for r in flat(only(p for p in K.popups(w) if p.key == K.AGENT_MENU).scene) if hasproperty(r.from, :name) && r.from.name == "Agent row"]
    icons(r) = [x.from.from.name for x in flat(r) if hasproperty(x.from, :from) && x.from.from isa K.Icon]
    @test [r.from.from.name for r in rows()] == ["Claude", "Antigravity", "Codex", "Grok"]
    @test icons(rows()[1]) == ["agent-claude", "check"] && icons(rows()[4]) == ["agent-grok"]
    @test all(r -> r.top >= K.TOPBAR_H - 12px, rows())
    # A click on a row makes that agent the pane's, and shuts the menu
    grok = rows()[4]
    click(grok.left + 20px, grok.top + 10px)
    @test e.ai == "Grok" && K.pane_agent(pane, e) == "Grok" && !any(p -> p.key == K.AGENT_MENU, K.popups(w))
    K.pane_agent!(pane, "Claude")
    # Settings says which agents are listed. One that's taken out goes from the menu, and the one that's chosen stays whatever its box says.
    e.remember = true
    K.agent_listed!(e, "Codex", false)
    K.agent_listed!(e, "Claude", false)
    @test K.listed_agents(e) == ["Claude", "Antigravity", "Grok"]
    @test [c.name for c in K.choices_for(K.AgentChoice, e)] == ["Claude", "Antigravity", "Grok"]
    @test occursin("\nagentshidden=Claude,Codex\n", read(K.settings_file(), String))
    click(name.left + 10px, name.top + 10px)
    frames()
    @test [r.from.from.name for r in rows()] == ["Claude", "Antigravity", "Grok"]
    K.close_popup!(w, K.AGENT_MENU)
    empty!(K.AGENTS_HIDDEN[])
    K.load_settings!(e)
    @test K.AGENTS_HIDDEN[] == Set(["Claude", "Codex"])
    K.agent_listed!(e, "Codex", true)
    K.agent_listed!(e, "Claude", true)
    @test K.listed_agents(e) == ["Claude", "Antigravity", "Codex", "Grok"] && occursin("\nagentshidden=\n", read(K.settings_file(), String))
    e.remember = false
    frames()
    K.TURN_COMMAND[] = Cmd([turner])
    for (agent, step) in (("Codex", "Running cat plan.md"),)
      K.pane_agent!(pane, agent)
      frames()
      @test e.ai == agent && pane.session === nothing && K.pane_agent(pane, e) == agent
      pane.field.buf.lines = ["Read the plan"]
      K.send_words!(pane)
      s = pane.session
      @test s.turns && s.agent == agent && s.busy
      ok = until(() -> !s.busy && !K.running(s))
      its = items()
      @test ok && [typeof(i) for i in its] == [K.YouSaid, K.AgentReply, K.AgentStep, K.AgentReply]
      @test its[2].text == "I will read it." && its[2].whole && its[4].text == "It has paint." && its[4].whole
      @test its[3].words == step && its[3].state == :done
      @test s.id == "sess-$agent"
      # The second turn names the session, so the agent goes on with it. No program runs between turns, and the pane says so.
      frames()
      @test named("Reply") !== nothing
      pane.field.buf.lines = ["And then?"]
      K.send_words!(pane)
      ok = until(() -> !s.busy && !K.running(s))
      said = readlines(turns)
      @test ok && pane.session === s && length(items()) == 8
      # The agent reads what Ladder says of itself before the first words
      @test startswith(said[end-1], "$agent||<ladder-brief> You are in Ladder") && endswith(said[end-1], "Read the plan")
      @test occursin("</ladder-brief>  <ladder>", said[end-1])
      @test startswith(said[end], "$agent|sess-$agent|<ladder>") && endswith(said[end], "And then?")
    end
    s = pane.session
    # What you say while a turn is under way waits for the turn's end. Stop ends the turn and what waited.
    pane.field.buf.lines = ["go slow"]
    K.send_words!(pane)
    pane.field.buf.lines = ["Later words"]
    K.send_words!(pane)
    @test s.busy && K.running(s) && length(s.queue) == 1
    n = length(readlines(turns))
    K.stop!(s)
    ok = until(() -> !s.busy && !K.running(s))
    @test ok && isempty(s.queue) && length(readlines(turns)) == n
    @test last(items()) isa K.SessionNote && last(items()).words == "You stopped Codex." && !last(items()).bad
    # A turn whose program fails says the line of what it wrote that names the error
    pane.field.buf.lines = ["fail please"]
    K.send_words!(pane)
    ok = until(() -> !s.busy && !K.running(s))
    @test ok && last(items()) isa K.SessionNote && last(items()).bad && last(items()).words == "Codex stopped: Error: no key for Codex"
    # Claude again ends the session with Codex
    K.pane_agent!(pane, "Claude")
    frames()
    @test e.ai == "Claude" && pane.session === nothing
    K.TURN_COMMAND[] = nothing
  end

  @testset "Antigravity's program stays for the session, and asks before a command, which Allow or Refuse answers" begin
    K.agent_mode(e) || (K.agent_mode!(e); frames(w, 3))
    K.pane_agent!(pane, "Antigravity")
    frames()
    @test e.ai == "Antigravity" && pane.session === nothing
    pane.field.buf.lines = ["Read the plan"]
    K.send_words!(pane)
    s = pane.session
    @test !s.turns && K.running(s) && s.busy
    ok = until(() -> !s.busy)
    its = items()
    @test ok && [typeof(i) for i in its] == [K.YouSaid, K.AgentReply, K.AgentStep, K.AgentReply]
    @test its[2].text == "I will read it." && its[2].whole && its[4].text == "It has paint." && its[4].whole
    @test its[3].words == "Reading plan.md" && its[3].state == :done
    # The program stays, with its session, and the agent says which model it works with
    @test K.running(s) && s.id == "acp-1" && s.running == "gemini-4-neon-low"
    # Ladder said what it can do, asked for a session in the folder with what it says of itself, and for the accept-edits mode
    said = acp_lines()
    @test occursin("\"method\":\"initialize\"", said[1]) && occursin("\"terminal\":false", said[1])
    @test occursin("\"method\":\"session/new\"", said[2]) && occursin("\"cwd\":\"$(s.dir)\"", said[2]) && occursin("\"append\":\"You are in Ladder", said[2])
    @test occursin("\"method\":\"session/set_mode\"", said[3]) && occursin("\"modeId\":\"accept-edits\"", said[3])
    @test occursin("\"method\":\"session/prompt\"", said[4]) && occursin("\"sessionId\":\"acp-1\"", said[4]) && occursin("Read the plan", said[4])
    # A command that its settings make it ask for shows Allow and Refuse, and Allow lets it run
    pane.field.buf.lines = ["Please run it"]
    K.send_words!(pane)
    ok = until(() -> last(items()) isa K.AgentWants)
    @test ok
    wants, step = last(items()), items()[end-1]
    @test step isa K.AgentStep && step.words == "Running make paint" && step.state == :going
    @test wants.tool == "Bash" && wants.detail == "make paint" && wants.words == "running make paint" && wants.answer == :none
    frames(w, 3)
    @test named("Agent asks") !== nothing
    allow = named("Allow")
    click(allow.left + allow.width / 2, allow.top + allow.height / 2)
    @test wants.answer == :allowed
    ok = until(() -> !s.busy)
    @test ok && step.state == :done && last(items()).text == "It ran."
    @test any(l -> occursin("\"id\":\"7\"", l) && occursin("\"optionId\":\"allow\"", l), acp_lines())
    # Refuse says no, and the step fails
    pane.field.buf.lines = ["Now run it again"]
    K.send_words!(pane)
    ok = until(() -> last(items()) isa K.AgentWants)
    frames(w, 3)
    refuse = named("Refuse")
    click(refuse.left + refuse.width / 2, refuse.top + refuse.height / 2)
    ok = until(() -> !s.busy)
    @test ok && any(l -> occursin("\"optionId\":\"deny\"", l), acp_lines()) && last(items()).text == "I left it." && items()[findlast(it -> it isa K.AgentStep, items())].state == :failed
    # What you say while the agent works waits for it. Stop cancels the turn, and what waited never goes.
    pane.field.buf.lines = ["go slow"]
    K.send_words!(pane)
    pane.field.buf.lines = ["Later words"]
    K.send_words!(pane)
    ok = until(() -> last(items()) isa K.AgentStep)
    @test ok && s.busy && length(s.talk.held) == 1 && last(items()).words == "Reading notes.md"
    K.stop!(s)
    ok = until(() -> !s.busy)
    @test ok && occursin("\"method\":\"session/cancel\"", last(acp_lines())) && isempty(s.talk.held)
    @test last(items()) isa K.SessionNote && last(items()).words == "You stopped Antigravity." && !last(items()).bad
    @test !any(l -> occursin("Later words", l), acp_lines()) && K.running(s)
    # Stop while the agent asks cancels what it asked
    pane.field.buf.lines = ["Please run it"]
    K.send_words!(pane)
    ok = until(() -> last(items()) isa K.AgentWants)
    wants = last(items())
    K.stop!(s)
    ok = ok && until(() -> !s.busy)
    @test ok && wants.answer == :gone && any(l -> occursin("\"id\":\"7\"", l) && occursin("\"outcome\":\"cancelled\"", l), acp_lines())
    # A program that starts again goes on with the session of its name
    K.close!(s)
    ok = until(() -> !K.running(s))
    pane.field.buf.lines = ["Read the plan again"]
    K.send_words!(pane)
    ok = ok && until(() -> !s.busy && last(items()) isa K.AgentReply)
    @test ok && pane.session === s && any(l -> occursin("\"method\":\"session/resume\"", l) && occursin("\"sessionId\":\"acp-1\"", l), acp_lines())
    # When the agent hasn't got that session any more, a new one starts, and gets your words
    K.close!(s)
    ok = until(() -> !K.running(s))
    s.id = "gone"
    pane.field.buf.lines = ["Read the plan once more"]
    K.send_words!(pane)
    ok = ok && until(() -> !s.busy && last(items()) isa K.AgentReply)
    notes = [it.words for it in items() if it isa K.SessionNote]
    @test ok && s.id == "acp-1" && last(notes) == "Antigravity doesn't have this session any more, so a new one starts here. It doesn't know what was said before."
    @test occursin("Read the plan once more", last(filter(l -> occursin("session/prompt", l), acp_lines())))
    K.pane_agent!(pane, "Claude")
    frames()
    ok = until(() -> !K.running(s))
    @test ok && e.ai == "Claude" && pane.session === nothing
  end

  @testset "Grok's program stays for the session too: it takes Ladder's words as rules, has the julia tool, and changes its model at once" begin
    K.pane_agent!(pane, "Grok")
    frames()
    @test e.ai == "Grok" && pane.session === nothing && !K.by_turns("Grok")
    before = length(acp_lines())
    pane.field.buf.lines = ["make it taller"]
    K.send_words!(pane)
    s = pane.session
    @test !s.turns && K.speaks_acp(s) && K.has_code(s) && K.running(s) && s.busy
    @test K.session_command(K.AgentSession(agent="Grok")) == K.ACP_COMMAND[] && K.ACP_OPTIONS["Grok"] == ["agent", "stdio"]
    ok = until(() -> !s.busy)
    its = items()
    @test ok && [typeof(i) for i in its] == [K.YouSaid, K.AgentReply, K.AgentStep, K.AgentStep, K.AgentStep, K.AgentReply]
    @test its[2].text == "I will make it taller." && its[6].text == "It is 25 tall."
    # Grok reaches Ladder's tool through its own `use_tool`, and a later update gives each step another title. The step keeps its tool.
    @test K.code_tool(its[3].tool) && its[3].words == "Running tall = 25" && its[3].state == :done
    @test its[4].tool == "Read" && its[4].words == "Reading plan.md" && its[4].state == :done
    @test its[5].tool == "Bash" && its[5].words == "List the files" && its[5].state == :done
    @test K.tool_words("search_tool", nothing) == "Looking for a tool" && K.tool_icon("search_tool") == "search"
    @test K.running(s) && s.id == "grok-1" && s.running == "grok-4.7"
    # The session comes with what Ladder says of itself as rules, and with the tool server. Grok has no accept-edits mode to ask for.
    said = acp_lines()[before+1:end]
    @test occursin("\"method\":\"initialize\"", said[1])
    @test occursin("\"method\":\"session/new\"", said[2]) && occursin("\"rules\":\"You are in Ladder", said[2]) && occursin("\"name\":\"ladder\"", said[2])
    @test occursin("tool named julia", K.session_brief(s))
    @test occursin("\"method\":\"session/prompt\"", said[3]) && !any(l -> occursin("session/set_mode", l), said)
    # A request of Grok's own that Ladder doesn't do gets an error, so Grok doesn't wait for an answer
    @test any(l -> occursin("\"id\":\"g9\"", l) && occursin("-32601", l), said)
    # The model changes while the program runs
    K.model!(s, "grok-4.6")
    ok = until(() -> s.running == "grok-4.6")
    @test ok && occursin("\"method\":\"session/set_model\"", last(acp_lines())) && occursin("\"modelId\":\"grok-4.6\"", last(acp_lines()))
    # A program that starts again goes on with the session of its name, which keeps its rules
    K.close!(s)
    ok = until(() -> !K.running(s))
    pane.field.buf.lines = ["Read the plan"]
    K.send_words!(pane)
    ok = ok && until(() -> !s.busy && last(items()) isa K.AgentReply)
    @test ok && any(l -> occursin("\"method\":\"session/resume\"", l) && occursin("\"sessionId\":\"grok-1\"", l), acp_lines())
    K.pane_agent!(pane, "Claude")
    frames()
    ok = until(() -> !K.running(s))
    @test ok && e.ai == "Claude" && pane.session === nothing
    empty!(K.MODELS_CHOSEN[])
    rm(acp_heard, force=true)   # the tests after this one look for a change of model in what the stand-in heard
  end

  @testset "The model's button shows the agent's model, and its menu changes it, also while the agent's program runs" begin
    K.agent_mode(e) || (K.agent_mode!(e); frames(w, 3))
    K.new_session!(pane)
    empty!(K.MODELS_CHOSEN[])
    frames()
    # The lists that the agents gave
    @test [m.id for m in K.agent_models("Claude").listed] == ["opus", "sonnet", "haiku"] && K.agent_models("Claude").default == "claude-opus-5-5"
    @test K.model_name("Claude", "claude-opus-4-8") == "Opus 4.8" && K.model_name("Claude", "claude-fable-5-2") == "Fable 5.2"
    @test [m.id for m in K.agent_models("Grok").listed] == ["grok-4.7", "grok-4.6"] && K.agent_models("Grok").default == "grok-4.7"
    @test K.pretty_model("claude-haiku-4-5-20251001") == "Haiku 4.5" && K.pretty_model("gemini-2.5-pro") == "Gemini 2.5 Pro" && K.pretty_model("grok-4.7-build-fast") == "Grok 4.7 Build Fast"
    # The button shows only while the mouse is over the box that you type in, so the words have the box's whole width
    away() = mouse_to(named("Agent").left + 20px, named("Agent").top + 200px)
    away()
    @test named("Model") === nothing && named("Send") !== nothing
    "The lines on the screen of the last line of your words, and where the last of them ends"
    screen_lines() = pane.field.layout[end].content.lines
    words_end() = (s = last(last(screen_lines()).segs); s.x + s.w)
    pane.field.buf.lines = ["Calculate the value of compute"]
    frames()
    words = (pane.field.width, length(screen_lines()), named("Agent foot").height)
    on_slot()
    # Before a session, the button shows the model that Claude Code chooses by itself. It's beside the send button, in line with it.
    button, send = named("Model"), named("Send")
    @test button !== nothing && K.model_words(pane, e) == "Opus 5.5"
    @test button.left + button.width <= send.left && button.top == send.top && button.height == send.height
    # Words that end before it move for none of it
    @test (pane.field.width, length(screen_lines()), named("Agent foot").height) == words
    @test named("Typed words").left + words_end() + K.MODEL_GAP <= button.left
    # A click beside it still goes to the words, and one on it goes to it
    mouse_to(button.left - 20px, button.top + 14px)
    @test named("Model") !== nothing && K.editor(K.hittest(w)) === pane.field
    mouse_to(button.left + 10px, button.top + 10px)
    @test K.hittest(w) isa K.PaneButton && K.hittest(w).action == :model
    # Words whose last line would go under it flow round it: the last words of that line go onto a new line, which ends before
    # the button. The lines above keep the box's whole width.
    away()
    text = "Calculate the current value of a gigawatt of compute, and the cost of it in a year"
    pane.field.buf.lines = [text]
    frames()
    while words_end() <= pane.field.width - K.model_wide(pane, e) - K.MODEL_GAP
      text *= " more"
      pane.field.buf.lines = [text]
      frames()
    end
    before = [[s.text for s in vl.segs] for vl in screen_lines()]
    tall = named("Agent foot").height
    on_slot()
    button, send = named("Model"), named("Send")
    after = [[s.text for s in vl.segs] for vl in screen_lines()]
    @test length(after) == length(before) + 1 && after[1:end-2] == before[1:end-1]
    @test named("Typed words").left + words_end() + K.MODEL_GAP <= button.left
    @test named("Agent foot").height > tall && button.top == send.top
    # Its words are all still there, and the caret goes on them as they show
    @test join(join.(after)) == text
    pane.field.buf.anchor = pane.field.buf.caret = (1, length(text))
    frames()
    @test K.spot(pane.field.layout[end].content, length(text))[1] == length(after)
    # When the mouse leaves, the words go back to the box's whole width
    away()
    @test [[s.text for s in vl.segs] for vl in screen_lines()] == before && named("Agent foot").height == tall
    pane.field.buf.lines = [""]
    # Its menu is over it, with the models that Claude Code lists and a tick on the one that it uses
    model_click()
    rows() = [r for r in flat(only(p for p in K.popups(w) if p.key == K.MODEL_MENU).scene) if hasproperty(r.from, :name) && r.from.name == "Model row"]
    icons(r) = [x.from.from.name for x in flat(r) if hasproperty(x.from, :from) && x.from.from isa K.Icon]
    @test [r.from.from.model.name for r in rows()] == ["Opus 5.5", "Sonnet 5.5", "Haiku 5.5"]
    @test icons(rows()[1]) == ["check"] && isempty(icons(rows()[2]))
    @test all(r -> r.top + r.height <= button.top, rows()) && last(rows()).left + last(rows()).width <= button.left + button.width
    # Before a session, a click chooses the model that the session starts with, and the settings keep it
    sonnet = rows()[2]
    click(sonnet.left + 20px, sonnet.top + 10px)
    @test !any(p -> p.key == K.MODEL_MENU, K.popups(w))
    @test K.chosen_model("Claude") == "sonnet" && K.model_words(pane, e) == "Sonnet 5.5"
    pane.field.buf.lines = ["Hello"]
    K.send_words!(pane)
    s = pane.session
    ok = until(() -> !s.busy)
    options = K.session_options(s)
    @test ok && s.model == "sonnet" && options[findfirst(==("--model"), options) + 1] == "sonnet"
    @test s.running == "claude-sonnet-5-5" && K.model_words(pane, e) == "Sonnet 5.5"
    # While the program runs, a click on another model asks Claude Code to change, and the session says when it has
    n = length(items())
    model_click()
    haiku = rows()[3]
    click(haiku.left + 20px, haiku.top + 10px)
    ok = until(() -> s.running == "claude-haiku-5-5")
    @test ok && K.running(s) && s.model == "haiku" && K.chosen_model("Claude") == "haiku" && K.model_words(pane, e) == "Haiku 5.5"
    @test occursin(r"\"subtype\":\"set_model\"", last(heard_lines())) && occursin("\"model\":\"haiku\"", last(heard_lines()))
    @test length(items()) == n + 1 && last(items()) isa K.SessionNote && last(items()).words == "The model is now Haiku 5.5." && !last(items()).bad
    # A model that Claude Code doesn't have leaves the model as it was, and the session says why
    K.pane_model!(pane, "bad-model")
    ok = until(() -> length(items()) == n + 2)
    @test ok && last(items()).bad && last(items()).words == "Claude didn't change its model: Model 'bad-model' not found"
    @test s.model == "haiku" && s.running == "claude-haiku-5-5" && K.chosen_model("Claude") == "haiku"
    # The same model again changes nothing
    K.pane_model!(pane, "haiku")
    frames()
    @test length(items()) == n + 2
    # While the agent works, the note waits for it to finish, so it doesn't split what the agent says
    pane.field.buf.lines = ["go slow"]
    K.send_words!(pane)
    ok = until(() -> any(it -> it isa K.AgentStep, items()[n+3:end]))
    K.pane_model!(pane, "opus")
    ok = ok && until(() -> s.running == "claude-opus-5-5")
    @test ok && s.busy && !(last(items()) isa K.SessionNote)
    K.stop!(s)
    ok = until(() -> !s.busy)
    @test ok && [it.words for it in items()[end-1:end]] == ["The model is now Opus 5.5.", "You stopped Claude."]
    # Antigravity says which model its session has
    K.pane_agent!(pane, "Antigravity")
    frames()
    @test K.model_words(pane, e) == "Default"
    pane.field.buf.lines = ["Read the plan"]
    K.send_words!(pane)
    g = pane.session
    ok = until(() -> !g.busy)
    @test ok && K.running(g) && g.running == "gemini-4-neon-low" && K.model_words(pane, e) == "Gemini 4 Neon (Low)"
    @test !any(l -> occursin("session/set_model", l), acp_lines())
    # Antigravity's menu has a row for each model, with a button for each of its efforts, from the least to the most
    model_click()
    button = named("Model")
    menu = only(p for p in K.popups(w) if p.key == K.MODEL_MENU)
    efforts(r) = [x.from.from.effort for x in flat(r) if hasproperty(x.from, :from) && x.from.from isa K.EffortButton]
    filled(r) = [x.from.from.effort for x in flat(r) if hasproperty(x.from, :from) && x.from.from isa K.EffortButton && K.pane_model(pane, e) == x.from.from.model.id]
    @test [r.from.from.name for r in rows()] == ["Gemini 4 Neon", "Gemini 4 Carbon", "Orchestrator (Neon)", "Gemini 3.8 Flash", "GPT-OSS 120B"]
    @test [efforts(r) for r in rows()] == [["Low", "Medium", "High", "XHigh"], ["Low", "Medium", "High"], String[], ["Low", "High"], ["Medium"]]
    @test icons(rows()[1]) == ["check"] && filled(rows()[1]) == ["Low"] && isempty(icons(rows()[2]))
    # It's wider than a menu of models with no efforts, and it's all in the window, over the button
    whole = only(x for x in flat(menu.scene) if hasproperty(x.from, :name) && x.from.name == "Model menu")
    @test whole.width == K.model_menu_wide(pane) > K.MODEL_MENU_W && whole.left >= 0px && all(r -> r.top + r.height <= button.top, rows())
    # Each effort is in a column, under the same effort of the other rows, and no name pushes them
    lefts(effort) = unique(x.left for r in rows() for x in flat(r) if hasproperty(x.from, :from) && x.from.from isa K.EffortButton && x.from.from.effort == effort)
    @test all(effort -> length(lefts(effort)) == 1, ["Low", "Medium", "High", "XHigh"])
    # Every button of an effort is in its row
    @test all(r -> all(x -> x.left + x.width <= r.left + r.width, [x for x in flat(r) if hasproperty(x.from, :from) && x.from.from isa K.EffortButton]), rows())
    # A click on an effort chooses that model with that effort
    high = only(x for x in flat(rows()[1]) if hasproperty(x.from, :from) && x.from.from isa K.EffortButton && x.from.from.effort == "High")
    click(high.left + 5px, high.top + 5px)
    @test !any(p -> p.key == K.MODEL_MENU, K.popups(w))
    # Its program changes the model while it runs, and the session says when it has
    ok = until(() -> g.running == "gemini-4-neon-high")
    @test ok && g.model == "gemini-4-neon-high" && K.model_words(pane, e) == "Gemini 4 Neon (High)" && last(g.items).words == "The model is now Gemini 4 Neon (High)."
    @test occursin("\"modelId\":\"gemini-4-neon-high\"", last(acp_lines()))
    # A click on a model's name keeps the effort, and Medium is for a model that hasn't that effort
    model_click()
    carbon = rows()[2]
    click(carbon.left + 20px, carbon.top + 10px)
    @test g.model == "gemini-4-carbon-high"
    @test K.row_choice("Antigravity", K.model_rows(K.agent_models("Antigravity").listed)[4].second, "gemini-4-neon-xhigh").id == "gemini-3.8-flash-low"
    @test K.row_choice("Antigravity", K.model_rows(K.agent_models("Antigravity").listed)[1].second, "gemini-4-carbon-high").id == "gemini-4-neon-high"
    ok = until(() -> g.running == "gemini-4-carbon-high")
    @test ok && occursin("\"modelId\":\"gemini-4-carbon-high\"", last(acp_lines()))
    # A model that Antigravity hasn't got: the model before stays, and the session says why with the first line of what the agent said
    n = length(g.items)
    K.pane_model!(pane, "bad-model")
    ok = until(() -> length(g.items) == n + 1)
    @test ok && g.model == "gemini-4-carbon-high" && g.running == "gemini-4-carbon-high" && K.chosen_model("Antigravity") == "gemini-4-carbon-high"
    @test last(g.items) isa K.SessionNote && last(g.items).bad
    @test last(g.items).words == "Antigravity didn't change its model to Bad Model: invalid model selection: model bad-model is not recognized"
    # A new program starts with the model that you chose
    K.close!(g)
    ok = until(() -> !K.running(g))
    pane.field.buf.lines = ["Read the plan"]
    K.send_words!(pane)
    ok = ok && until(() -> !g.busy)
    started = acp_lines()[findlast(l -> occursin("session/resume", l), acp_lines()):end]
    @test ok && occursin("\"modelId\":\"gemini-4-carbon-high\"", started[3]) && occursin("session/prompt", started[4])
    options = K.turn_options(K.AgentSession(agent="Codex", model="gpt-5.4-mini", id="sess", turns=true))
    @test options[findfirst(==("-m"), options) + 1] == "gpt-5.4-mini"
    # The settings file keeps the model of each agent. One that Gemini had before Antigravity took its place is left out.
    e.remember = true
    K.model_chosen!(e, "Antigravity", "gemini-4-neon-high")
    @test occursin("\nmodels=Antigravity:gemini-4-neon-high,Claude:opus\n", read(K.settings_file(), String))
    empty!(K.MODELS_CHOSEN[])
    K.load_settings!(e)
    @test K.MODELS_CHOSEN[] == Dict("Claude" => "opus", "Antigravity" => "gemini-4-neon-high")
    write(K.settings_file(), replace(read(K.settings_file(), String), "models=" => "models=Gemini:pro,"))
    K.load_settings!(e)
    @test K.MODELS_CHOSEN[] == Dict("Claude" => "opus", "Antigravity" => "gemini-4-neon-high")
    e.remember = false
    K.pane_agent!(pane, "Claude")
    empty!(K.MODELS_CHOSEN[])
    frames()
  end

  @testset "A pasted picture goes with your words, and its button takes it away" begin
    K.agent_mode(e) || (K.agent_mode!(e); frames(w, 3))
    # ⌘V reads a clipboard that only this test uses
    pb = K.Pasteboard.private_board()
    K.Pasteboard.other[] = pb
    put(kind, value::String) = (msg(pb, "clearContents"); ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), pb, sel("setString:forType:"), nsstring(value), nsstring(kind)))
    put(kind, bytes::Vector{UInt8}) = begin
      msg(pb, "clearContents")
      data = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt8}, UInt), cls("NSData"), sel("dataWithBytes:length:"), bytes, length(bytes))
      ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}), pb, sel("setData:forType:"), data, nsstring(kind))
    end
    kept = joinpath(dir, "kept pictures")
    K.AGENT_PICTURES[] = kept
    try
      # A screenshot app's picture is a file in a folder of temporary files, which is where this test's folder is
      shot = joinpath(dir, "Screenshot 1.png")
      save_scene(shot, K.Row(K.width(160px), K.height(80px), K.background(K.colorant"rgb(60,120,200)")), (160px, 80px))
      @test any(t -> startswith(shot, t), K.PASSING)
      K.focus(pane.field); frames()
      put("public.file-url", "file://" * replace(shot, " " => "%20"))
      press(Keys.v, Keys.cmd)
      @test K.attached(pane) == [joinpath(kept, "Screenshot 1.png")] && read(K.attached(pane)[1]) == read(shot) && pane.field.buf.lines == [""]
      # It shows over the words, in the slot, at its own shape, with its button in its corner. The slot's ends stay as round.
      foot, picture, x, send = named("Agent foot"), named("Picture"), named("Take away"), named("Send")
      slot = foot.children[1]
      @test picture !== nothing && picture.height == K.PICTURE_TALL && picture.width == 2K.PICTURE_TALL && picture.top > slot.top && picture.top + picture.height < send.top
      # It starts where the words do
      @test abs(K.num(picture.left - slot.children[1].left)) < 1
      @test x !== nothing && abs(K.num(x.left + x.width - (picture.left + picture.width - 4px))) < 0.01 && abs(K.num(x.top - picture.top - 4px)) < 0.01
      r = K.num(slot.from.radius.tl)
      @test abs(K.num(slot.top + slot.height - (send.top + send.height / 2)) - r) < 0.5 && abs(K.num(slot.left + slot.width - (send.left + send.width / 2)) - r) < 0.5
      # A picture that's copied as itself, like a screenshot that went to the clipboard, is written to a file
      put("public.png", read(shot))
      press(Keys.v, Keys.cmd)
      @test length(K.attached(pane)) == 2 && startswith(basename(K.attached(pane)[2]), "pasted-") && dirname(K.attached(pane)[2]) == kept
      # Its button takes it away, and the file that Ladder wrote for it
      second = K.attached(pane)[2]
      xs = [r for r in flat(K.rect(e)) if hasproperty(r.from, :name) && r.from.name == "Take away"]
      @test length(xs) == 2
      click(xs[2].left + 10px, xs[2].top + 10px)
      @test K.attached(pane) == [joinpath(kept, "Screenshot 1.png")] && !isfile(second)
      # A file that isn't a picture goes in as its path, and text as text
      notes = joinpath(dir, "notes.txt"); write(notes, "x")
      put("public.file-url", "file://" * notes)
      press(Keys.v, Keys.cmd)
      put("public.utf8-plain-text", " in it?")
      press(Keys.v, Keys.cmd)
      @test pane.field.buf.lines == [notes * " in it?"] && length(K.attached(pane)) == 1
      # An app that takes dictation puts its words on the clipboard, presses ⌘V, and soon puts back what the clipboard
      # held before, like a screenshot. The words go in, though the paste reads the clipboard after the picture is back.
      paste = K.COMMANDS[:paste]
      K.COMMANDS[:paste] = K.Command(:paste, "Paste", :edit, "cmd+v", (e, w, s) -> (put("public.png", read(shot)); paste.run(e, w, s)))
      put("public.utf8-plain-text", " Yes.")
      try press(Keys.v, Keys.cmd) finally K.COMMANDS[:paste] = paste end
      @test pane.field.buf.lines == [notes * " in it? Yes."] && length(K.attached(pane)) == 1
      # A picture that's dropped anywhere on the agent's pane goes with the words too, and the words take the keyboard
      dropped = joinpath(dir, "dropped.png"); cp(shot, dropped)
      K.focus(e); frames()
      agent = named("Agent")
      w.mouse = typeof(w.mouse)(agent.left + 40px, agent.top + 200px)
      onfiledrop(w, [dropped]); frames()
      @test K.attached(pane)[end] == joinpath(kept, "dropped.png") && w.focus === pane.field && length(K.attached(pane)) == 2
      K.unattach!(pane, K.attached(pane)[end])
      @test length(K.attached(pane)) == 1 && !isfile(joinpath(kept, "dropped.png")) && isfile(dropped)
      # Claude gets the picture before your words, and the words say which file it's in
      pane.field.buf.lines = ["What's in this?"]
      n = length(heard_lines())
      press(Keys.enter)
      ok = until(() -> pane.session !== nothing && !pane.session.busy)
      said = heard_lines()[n+1:end]
      kept_shot = joinpath(kept, "Screenshot 1.png")
      @test ok && length(said) == 1 && occursin("\"type\":\"image\"", said[1]) && occursin("\"media_type\":\"image/png\"", said[1]) &&
            occursin(K.base64encode(read(shot)), said[1]) && occursin("What's in this?\\n\\nThe pictures with these words are also in these files:\\n$kept_shot", said[1])
      @test isempty(K.attached(pane)) && isfile(kept_shot)
      you = items()[findlast(it -> it isa K.YouSaid, items())]
      @test you.pictures == [kept_shot] && you.words == "What's in this?"
      frames(w, 3)
      @test named("Your pictures") !== nothing && named("Picture") === nothing
      # Only pictures, with no words, can go too
      put("public.png", read(shot))
      press(Keys.v, Keys.cmd)
      press(Keys.enter)
      ok = until(() -> !pane.session.busy)
      @test ok && items()[findlast(it -> it isa K.YouSaid, items())].words == "" && occursin("\"type\":\"image\"", last(heard_lines()))
      # A picture of a kind that Claude doesn't take goes as a PNG file, and one with too many bytes goes smaller
      tiff = joinpath(dir, "shot.tiff")
      run(pipeline(`sips -s format tiff $shot --out $tiff`, stdout=devnull))
      @test endswith(K.sendable_picture(tiff), ".png") && K.sendable_picture(shot) == shot
      @test K.picture_block(joinpath(dir, "none.png")) === nothing
      # The file of a session keeps the pictures
      s = pane.session
      back = K.read_talk(K.talk_text(s))
      kept_back = [it.pictures for it in back.items if it isa K.YouSaid]
      @test kept_back[end-1:end] == [[kept_shot], items()[findlast(it -> it isa K.YouSaid, items())].pictures] && length(kept_back[end]) == 1
    finally
      K.Pasteboard.other[] = C_NULL
      K.AGENT_PICTURES[] = ""
    end
  end

  @testset "A click on a link in a reply shows the file and the line that it names, from a file:// address too" begin
    K.agent_mode(e) || (K.agent_mode!(e); frames(w, 3))
    # URI.jl reads a link as one in the page's file
    @test K.linked_file(e, "file:///Users/sam/my%20plan.md#L3-L9") == ("/Users/sam/my plan.md", "L3-L9")
    @test K.linked_file(e, "my%20notes.md#L41") == (notes, "L41") && K.linked_file(e, "#L5") == (page, "L5")
    @test K.linked_file(e, "~/Mail") == (joinpath(homedir(), "Mail"), "") && K.linked_file(e, "https://example.com/#L3") === nothing
    # Lines of a file that isn't there are no lines to go to
    @test !K.go_lines!(e, joinpath(dir, "none.md") * "#L3")
    pane.field.buf.lines = ["Give me a link"]
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy)
    @test ok && occursin("file://$page#L5-L7", last(items()).text)
    frames(w, 3)
    sub = pane.parts[(:reply, objectid(last(items())))]
    "The middle of the words of the link to `url` in the reply, in the window, or nothing"
    link_place(url) = begin
      for it in sub.layout
        f = it.content
        f isa K.Flow || continue
        for vl in f.lines, seg in vl.segs
          seg.link == url && return (sub.origin[1] + seg.x + seg.w / 2, sub.origin[2] + it.top + f.above + vl.top + vl.high / 2)
        end
      end
      nothing
    end
    paint = link_place("file://$page#L5-L7")
    talk = named("Agent")
    @test paint !== nothing && talk.top < paint[2] < talk.top + talk.height
    # The page is scrolled down, away from its line 5
    e.scroll.offset = 400px
    frames(w, 3)
    click(paint...)
    frames(w, 3)
    @test e.buf.path == page && e.buf.caret[1] == 5 && e.buf.lines[5] == "## Paint"
    @test w.focus === e && e.scroll.offset < 400px
    # A link to lines of another file shows that file, with the line near the top of the window
    click(link_place("file://$(replace(notes, ' ' => "%20"))#L41")...)
    frames(w, 3)
    @test e.buf.path == notes && e.buf.caret[1] == 41 && e.buf.lines[41] == "Note 20." && e.scroll.offset > 0px
    @test K.agent_mode(e)
    K.open!(e, page); frames(w, 3)
  end

  @testset "Words that start with a slash list the commands, Ladder's own and then the agent's, and the arrows, Tab and Return choose from them" begin
    K.agent_mode(e) || (K.agent_mode!(e); frames(w, 3))
    K.new_session!(pane); frames()
    empty!(K.AGENT_COMMANDS)
    menu = K.slash_menu(pane)
    shows() = any(q -> q.key == K.SLASH_MENU, K.popups(w))
    names() = [x.name for (_, x) in menu.rows]
    K.focus(pane.field)
    @test !shows() && pane.session === nothing
    typed("/")
    # The first slash starts Claude Code's program, which lists its commands. Ladder's own come first, and its /clear is the one that shows.
    ok = until(() -> pane.session !== nothing && haskey(K.AGENT_COMMANDS, ("Claude", pane.session.dir)) && length(menu.rows) == 7)
    @test ok && shows() && K.running(pane.session) && !pane.session.busy
    @test names() == ["resume", "new", "clear", "model", "compact", "context", "ladder:page"]
    @test all(((kind, x),) -> kind == :command && x.own == (x.name in ("resume", "new", "clear", "model")), menu.rows)
    # A command's words are one line
    @test menu.rows[7][2].about == "(ladder) Show the user a page in Ladder."
    # The list stands on the slot's top line, over its middle, and narrower, so its feet can flare out onto the slot as the command palette's do
    list, slot = only(q for q in K.popups(w) if q.key == K.SLASH_MENU).scene, K.rect(K.pane_slot(pane))
    @test abs(K.num(list.top + list.height - slot.top)) < 1 && abs(K.num(list.left + list.width / 2 - slot.left - slot.width / 2)) < 1
    @test list.left - K.OMNI_FOOT * px >= slot.left + slot.from.radius.tl && list.width >= min(320px, slot.width - 2(slot.from.radius.tl + K.OMNI_FOOT * px))
    @test any(r -> occursin("/compact", sprint(show, r.from)), flat(list))
    # What you type after the slash leaves the commands that have it, those that start with it first
    typed("co")
    @test names() == ["compact", "context"] && menu.over == 1
    press(Keys.down)
    @test menu.over == 2 && pane.field.buf.lines == ["/co"]
    press(Keys.down)
    @test menu.over == 1
    press(Keys.up)
    @test menu.over == 2
    # Tab writes the command in the field, with a space to add to. The list then shows that command alone.
    press(Keys.tab)
    @test pane.field.buf.lines == ["/context "] && w.focus === pane.field && pane.field.buf.caret == (1, 9)
    @test menu.rows == Any[(:hint, menu.rows[1][2])] && menu.rows[1][2].name == "context"
    # Return gives the agent the command as you typed it, with nothing of Ladder's before it
    press(Keys.enter)
    ok = until(() -> !pane.session.busy && !isempty(heard_lines()) && occursin("/context", last(heard_lines())))
    @test ok && occursin("\"content\":\"/context\"", last(heard_lines())) && !occursin("<ladder>", last(heard_lines()))
    @test items()[1] isa K.YouSaid && items()[1].words == "/context" && isempty(items()[1].about)
    @test pane.field.buf.lines == [""] && !shows()
    # Return on a row of the list runs that command
    typed("/comp")
    @test names() == ["compact"] && shows()
    press(Keys.enter)
    ok = until(() -> !pane.session.busy && occursin("/compact", last(heard_lines())))
    @test ok && occursin("\"content\":\"/compact\"", last(heard_lines())) && pane.field.buf.lines == [""]
    # Words that start with a slash and are no command go as other words do, with what the window shows
    pane.field.buf.lines = ["/tmp/plan.md is which file?"]
    frames()
    @test !shows()
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy && occursin("which file", last(heard_lines())))
    @test ok && occursin("<ladder>", last(heard_lines()))
    # A click on a row takes it, as Return does, and the field keeps the keyboard
    typed("/cont")
    row = only(r for r in flat(only(q for q in K.popups(w) if q.key == K.SLASH_MENU).scene) if hasproperty(r.from, :name) && r.from.name == "Command row")
    n = length(heard_lines())
    click(row.left + 30px, row.top + 10px)
    ok = until(() -> !pane.session.busy && length(heard_lines()) > n)
    @test ok && occursin("\"content\":\"/context\"", last(heard_lines())) && w.focus === pane.field
    # /model and a space lists the models, and Return chooses one
    typed("/model so")
    @test [(kind, x.id) for (kind, x) in menu.rows] == [(:model, "sonnet")]
    press(Keys.enter)
    ok = until(() -> pane.session.running == "claude-sonnet-5-5")
    @test ok && pane.session.model == "sonnet" && pane.field.buf.lines == [""]
    K.pane_model!(pane, "opus")
    until(() -> pane.session.running == "claude-opus-5-5")
    # /new ends the session, as the + button does
    s = pane.session
    typed("/new")
    press(Keys.enter)
    ok = until(() -> !K.running(s))
    @test ok && pane.session === nothing && pane.field.buf.lines == [""]
    # An agent that works by turns has no earlier sessions to go on with
    K.pane_agent!(pane, "Codex")
    typed("/")
    @test names() == ["new", "clear", "model"]
    K.field!(pane, "")
    K.pane_agent!(pane, "Claude")
    frames()
  end

  @testset "/usage, while the agent works, runs at once in a program of its own, and the reply that the agent was writing goes on over it and over words that wait" begin
    K.agent_mode(e) || (K.agent_mode!(e); frames(w, 3))
    K.new_session!(pane); frames()
    pane.field.buf.lines = ["go slow"]
    K.send_words!(pane)
    s = pane.session
    # The agent reads a file and goes on with its turn. Earlier tests said "go slow" too, so the step shows that this turn started.
    ok = until(() -> any(x -> x isa K.AgentStep && x.state == :going, items()) && haskey(K.AGENT_COMMANDS, ("Claude", s.dir)))
    @test ok && s.busy
    # Claude Code lists /usage for a plan's account. With an API key it has none, and the words go to the agent.
    pane.field.buf.lines = ["/usage"]
    @test !K.goes_beside(s, "/usage")
    listed = K.AGENT_COMMANDS[("Claude", s.dir)]
    push!(listed, K.SlashCommand("usage", "Show session cost, plan usage, and what's contributing to your limits", "", false))
    # The agent is writing a reply when you give the command
    K.take_line!(s, """{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}}""")
    K.take_line!(s, """{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Half "}}}""")
    n = length(heard_lines())
    K.send_words!(pane)
    it = last(items())
    @test it isa K.RanBeside && it.words == "/usage" && !it.reply.whole && s.busy && pane.field.buf.lines == [""]
    frames()
    @test named("Ran beside") !== nothing
    ok = until(() -> it.reply.whole)
    @test ok && !it.bad && it.reply.text == "Current week (all models): 50% used\nCurrent week (Fable): 11% used"
    # The agent's program never got it, and goes on with its turn
    @test s.busy && length(heard_lines()) == n
    # Words that you give now wait for the turn to end
    pane.field.buf.lines = ["Then wait your turn"]
    K.send_words!(pane)
    ok = until(() -> length(heard_lines()) > n)
    @test ok && occursin("wait your turn", last(heard_lines())) && items()[end] isa K.YouSaid && items()[end].words == "Then wait your turn"
    # The agent's words go on in the reply that it was writing, over the command and your words, and show once
    K.take_line!(s, """{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"and the rest."}}}""")
    @test items()[end-2].text == "Half and the rest." && !items()[end-2].whole && count(x -> x isa K.AgentReply, items()) == 1
    K.take_line!(s, """{"type":"assistant","message":{"content":[{"type":"text","text":"Half and the rest."}]}}""")
    @test items()[end-1] === it && items()[end-2] isa K.AgentReply && items()[end-2].text == "Half and the rest." && items()[end-2].whole
    @test count(x -> x isa K.AgentReply, items()) == 1
    # A reply of a new turn comes after your words
    K.take_line!(s, """{"type":"result","subtype":"success","is_error":false,"result":""}""")
    K.take_line!(s, """{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}}""")
    K.take_line!(s, """{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Now yours."}}}""")
    @test items()[end] isa K.AgentReply && items()[end].text == "Now yours." && items()[end-1] isa K.YouSaid
    K.take_line!(s, """{"type":"assistant","message":{"content":[{"type":"text","text":"Now yours."}]}}""")
    frames()
    # A session's file keeps the command and its answer as your words and a reply
    text = K.talk_text(s)
    @test occursin("<!-- ladder:you -->\n/usage\n", text) && occursin("Current week (Fable): 11% used", text)
    @test [typeof(x) for x in K.read_talk(text).items][end-4:end] == [K.AgentReply, K.YouSaid, K.AgentReply, K.YouSaid, K.AgentReply]
    # With no turn under way, it goes to the agent's program as its other commands do
    pane.field.buf.lines = ["/usage"]
    K.send_words!(pane)
    ok = until(() -> !s.busy && occursin("\"content\":\"/usage\"", last(heard_lines())))
    @test ok && any(x -> x isa K.YouSaid && x.words == "/usage", items())
    filter!(c -> c.name != "usage", listed)
  end

  @testset "/resume lists the earlier sessions of the folder, also those of a terminal, and goes on with the one that you choose" begin
    # The files that Claude Code keeps for the folder: a session with a title, one with only its first words, and a program that ran once
    kept = K.CLAUDE_SESSIONS[] = joinpath(dir, "claude-sessions")
    mkpath(kept)
    write(joinpath(kept, "aaaa-1111.jsonl"), join([
      """{"type":"user","message":{"role":"user","content":"<ladder>\\nThe window shows the file /tmp/x.md.\\n</ladder>\\n\\nPaint the fence"},"uuid":"1"}""",
      """{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"A fence."}]}}""",
      """{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"u1","name":"Read","input":{"file_path":"/tmp/fence.md"}}]}}""",
      """{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"u1","content":"x"}]}}""",
      """{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"u2","name":"Bash","input":{"command":"paint","description":"Paint it"}}]}}""",
      """{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"u2","content":"no","is_error":true}]}}""",
      """{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"The fence is **painted**."}]}}""",
      """{"type":"ai-title","aiTitle":"Fence \\"painting\\"","sessionId":"aaaa-1111"}""",
      """{"type":"user","isSidechain":true,"message":{"role":"user","content":"Words to an agent that Claude started"}}""",
      """{"type":"user","isMeta":true,"message":{"role":"user","content":"Words that Claude Code wrote"}}""",
      """{"type":"user","message":{"role":"user","content":"<command-name>/compact</command-name>\\n<command-message>compact</command-message>\\n<command-args>keep the fence</command-args>"}}""",
      """{"type":"user","message":{"role":"user","content":"<local-command-stdout>Compacted</local-command-stdout>"}}"""], "\n") * "\n")
    write(joinpath(kept, "bbbb-2222.jsonl"), """{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Count the brushes\\nand the tins"}]}}\n""")
    write(joinpath(kept, "cccc-3333.jsonl"), """{"type":"last-prompt","sessionId":"cccc-3333"}\n""")
    run(`touch -t 202611200900 $(joinpath(kept, "bbbb-2222.jsonl"))`)
    @test K.claude_title(joinpath(kept, "aaaa-1111.jsonl")) == "Fence \"painting\"" && K.claude_title(joinpath(kept, "cccc-3333.jsonl")) == ""
    # What Ladder put round your words isn't your words
    @test K.your_words("<ladder>\nThe file.\n</ladder>\n\n<changes>\nx\n</changes>\n\nHello\n\nThe pictures with these words are also in these files:\n/tmp/a.png") == "Hello"
    @test K.your_words("<task-notification>done</task-notification>") == "" && K.your_words("A <b>bold</b> word") == "A <b>bold</b> word"
    @test K.ago_words(1000.0, 1000.0 + 300) == "5 min ago" && K.ago_words(1000.0, 1000.0 + 7200) == "2 hr ago" && K.ago_words(1000.0, 1000.0 + 30 * 3600) == "yesterday"
    @test K.iso_time("2026-11-27T01:00:00.944933+00:00") - K.iso_time("2026-11-26T12:28:58Z") == 12 * 3600 + 31 * 60 + 2
    menu = K.slash_menu(pane)
    K.new_session!(pane); frames()
    K.focus(pane.field)
    # Return on /resume writes it out with a space, which lists the sessions, the newest first
    typed("/res")
    press(Keys.enter)
    frames()
    @test pane.field.buf.lines == ["/resume "]
    @test [(kind, x.id, x.title) for (kind, x) in menu.rows] == [(:session, "aaaa-1111", "Fence \"painting\""), (:session, "bbbb-2222", "Count the brushes")]
    # The words after it leave the sessions whose titles have them
    typed("BRUSH")
    @test [x.id for (_, x) in menu.rows] == ["bbbb-2222"]
    typed("x")
    @test menu.rows == Any[(:note, "No earlier session has those words in its title.")]
    press(Keys.enter)   # nothing to go on with, so the words stay
    @test pane.field.buf.lines == ["/resume BRUSHx"] && isempty(pane.session.items)
    K.field!(pane, "/resume fence")
    frames()
    was = pane.session.process
    press(Keys.enter)
    s = pane.session
    # What was said in that session shows, without what an agent of Claude's was told, and without Ladder's own lines
    @test s.id == "aaaa-1111" && pane.field.buf.lines == [""]
    @test [typeof(i) for i in s.items] == [K.YouSaid, K.AgentStep, K.AgentStep, K.AgentReply, K.YouSaid]
    @test s.items[1].words == "Paint the fence" && s.items[2].words == "Reading fence.md" && s.items[2].state == :done && s.items[3].state == :failed
    @test s.items[4].text == "The fence is **painted**." && s.items[4].whole && s.items[5].words == "/compact keep the fence"
    # Claude Code's program started again, with that session's name
    @test K.running(s) && s.process !== was && "aaaa-1111" in K.session_options(s) && "--resume" in K.session_options(s)
    frames(w, 3)
    @test named("Reply") !== nothing
    pane.field.buf.lines = ["And the gate"]
    K.send_words!(pane)
    ok = until(() -> !s.busy && last(s.items) isa K.AgentReply)
    @test ok && s.id == "aaaa-1111" && occursin("And the gate", last(heard_lines())) && length(s.items) == 7
    # The list no longer has the session that the pane goes on with
    typed("/resume ")
    @test [x.id for (_, x) in menu.rows] == ["bbbb-2222"]
    K.field!(pane, "")
    # A long session shows its newest part
    long = Any[]
    for k in 1:40
      push!(long, K.YouSaid(words="Question $k"), K.AgentReply(text="Answer $k", whole=true))
    end
    part = K.recent_part(long)
    @test part[1] isa K.SessionNote && part[2].words == "Question 11" && length(part) == 61 && K.recent_part(long[1:20]) === long[1:20] || length(K.recent_part(long[1:20])) == 20
    K.new_session!(pane)
    K.CLAUDE_SESSIONS[] = ""
    frames()
  end

  @testset "Antigravity and Grok list their own commands and their earlier sessions, and say again what was said in the one that you choose" begin
    K.pane_agent!(pane, "Antigravity")
    frames()
    menu = K.slash_menu(pane)
    K.focus(pane.field)
    typed("/")
    ok = until(() -> pane.session !== nothing && length(menu.rows) == 6)
    s = pane.session
    # A name that the agent lists twice shows once
    @test ok && [x.name for (_, x) in menu.rows] == ["resume", "new", "clear", "model", "goal", "compact"] && menu.rows[5][2].hint == "<objective>"
    @test s.id == "acp-1" && !s.busy
    typed("resume ")
    ok = until(() -> s.earlier !== nothing && !s.looking && first(first(menu.rows)) == :session)
    # Only the sessions of this folder, the newest first
    @test ok && [(x.id, x.title) for (_, x) in menu.rows] == [("old-2", "Brush sizes"), ("old-1", "Paint prices"), ("bad", "A lost one")]
    @test any(l -> occursin("\"method\":\"session/list\"", l) && occursin("\"cwd\":\"$(s.dir)\"", l), acp_lines())
    press(Keys.down)
    press(Keys.enter)
    @test s.loading && pane.field.buf.lines == [""]
    ok = until(() -> !s.loading && s.talk.ready)
    # The same program loaded the session, and what was said in it shows: your words without Ladder's block, the step, the reply
    @test ok && s.id == "old-1" && K.running(s) && !s.busy
    @test [typeof(i) for i in s.items] == [K.YouSaid, K.AgentStep, K.AgentReply]
    @test s.items[1].words == "What does paint cost?" && s.items[2].words == "Reading prices.md" && s.items[2].state == :done
    @test s.items[3].text == "Paint costs **40**." && s.items[3].whole
    said = acp_lines()
    k = findlast(l -> occursin("\"method\":\"session/load\"", l), said)
    @test k !== nothing && occursin("\"sessionId\":\"old-1\"", said[k]) && occursin("\"method\":\"session/set_mode\"", said[k+1]) && count(l -> occursin("\"method\":\"initialize\"", l), said[k:end]) == 0
    # A command of the agent's goes as you typed it, to the session that was loaded
    pane.field.buf.lines = ["/goal paint it all"]
    K.send_words!(pane)
    ok = until(() -> !s.busy)
    asked = last(filter(l -> occursin("session/prompt", l), acp_lines()))
    @test ok && occursin("\"text\":\"/goal paint it all\"", asked) && occursin("\"sessionId\":\"old-1\"", asked)
    # A session that the agent can't open leaves the pane as it was, and says so
    n = length(s.items)
    typed("/resume lost")
    ok = until(() -> !s.looking && first(first(menu.rows)) == :session)   # Ladder asks for the list again, as a session may have come since
    @test ok && [x.id for (_, x) in menu.rows] == ["bad"]
    press(Keys.enter)
    ok = until(() -> !s.loading && s.talk.ready)
    @test ok && s.id == "old-1" && length(s.items) == n + 1 && last(s.items) isa K.SessionNote && last(s.items).bad
    @test last(s.items).words == "Antigravity couldn't open that session: Resource not found: bad"
    # Grok's session keeps the rules that it was made with, so one of a terminal is told of Ladder with your next words
    K.pane_agent!(pane, "Grok")
    frames()
    typed("/resume ")
    ok = until(() -> pane.session !== nothing && pane.session.earlier !== nothing && !pane.session.looking && first(first(menu.rows)) == :session)
    s = pane.session
    @test ok && s.agent == "Grok"
    press(Keys.enter)
    ok = until(() -> !s.loading && s.talk.ready)
    @test ok && s.id == "old-2" && s.unbriefed
    pane.field.buf.lines = ["/context"]
    K.send_words!(pane)
    ok = until(() -> !s.busy)
    @test ok && s.unbriefed && occursin("\"text\":\"/context\"", last(filter(l -> occursin("session/prompt", l), acp_lines())))
    pane.field.buf.lines = ["Hello again"]
    K.send_words!(pane)
    ok = until(() -> !s.busy)
    asked = last(filter(l -> occursin("session/prompt", l), acp_lines()))
    @test ok && !s.unbriefed && occursin("<ladder-brief>\\nYou are in Ladder", asked) && occursin("Hello again", asked)
    K.pane_agent!(pane, "Claude")
    frames()
    until(() -> !K.running(s))
  end

  @testset "Once you have talked with the agent, it writes the message of a commit in the conversation, after the turn that's under way" begin
    # The page's folder is made a repository, and the page has a change since its first commit
    merge!(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
                     "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com"))
    git(args...) = read(`git -C $dir -c commit.gpgsign=false $args`, String)
    K.agent_shows(e) || (K.agent_mode!(e); frames(w, 3))
    now = read(page, String)
    write(page, replace(now, "Buy paint." => "Buy a little paint."))
    git("init", "-q", "-b", "main"); git("add", "plan.md"); git("commit", "-q", "-m", "Make the plan")
    write(page, now)
    empty!(K.GIT_TOPS); K.Git.forget!()
    frames()
    tip() = K.BUTTONS[:commit].tip(e)
    # With nothing said yet, the agent of Settings writes it in a run of its own
    @test pane.session === nothing && K.commit_talk(e) === nothing && tip() == "Commit plan.md, with a message that Claude writes"
    pane.field.buf.lines = ["Hello"]
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy)
    s = pane.session
    @test ok && K.commit_talk(e) === pane && tip() == "Commit plan.md, with a message that Claude writes in the conversation"
    # While the agent works on what you said, the commit waits
    pane.field.buf.lines = ["go slow"]
    K.send_words!(pane)
    ok = until(() -> any(l -> occursin("go slow", l), heard_lines()))
    n = length(heard_lines())
    K.BUTTONS[:commit].run(e)
    foreach(_ -> (frames(w, 1); sleep(0.02)), 1:10)
    @test ok && s.busy && length(heard_lines()) == n && haskey(e.nodes, :writing) && tip() == "Claude is writing the commit message…"
    # When that turn ends, the agent is asked, and its reply is the message
    K.stop!(s)
    ok = until(() -> !haskey(e.nodes, :writing))
    @test ok && strip(git("log", "-1", "--format=%B")) == "Buy less paint\n\nThe plan says why."
    @test isempty(strip(git("status", "--porcelain", "plan.md"))) && startswith(e.nodes[:result][1], "Committed plan.md: Buy less paint")
    # The pane shows the question and the message. The diff and the last messages went to the agent, though the pane doesn't show them.
    asked = s.items[findlast(it -> it isa K.YouSaid, s.items)]
    @test asked.words == "Write the commit message for plan.md." && last(s.items) isa K.AgentReply && !s.busy
    line = last(filter(l -> occursin("the Commit button", l), heard_lines()))
    @test occursin("-Buy a little paint.\\n+Buy paint.", line) && occursin("Make the plan", line) && occursin("Write the commit message for plan.md.", line)
  end

  @testset "Closing the window ends the agent's program" begin
    pane.field.buf.lines = ["One more"]
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy)
    s = pane.session
    @test ok && K.running(s)
    K.close_agent!(e)
    ok = until(() -> !K.running(s))
    @test ok
  end
finally
  K.SESSION_COMMAND[] = nothing
  K.TURN_COMMAND[] = nothing
  K.ACP_COMMAND[] = nothing
  pane.session === nothing || K.close!(pane.session)
end
