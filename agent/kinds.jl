# The agents that Ladder can start, the models of each, and their logos
#
# Settings has the agent that Ladder starts for a change or a question, when
# no agent shares the page: Claude Code, Antigravity, Codex or Grok. Each is a
# command on this Mac that does one request and ends. Your words go last, after
# the options. Claude Code prints each step as a line of JSON, so the label on
# the thing says what it's doing: see `agent_step`. The others print only what
# they say at the end.

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "github.com/jkroso/JSON.jl" JSONObject json_value
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" icon_cache
@use "github.com/jkroso/UI.jl/Interface/Semantic/SVG" SVGPath
@use Colors: @colorant_str
@use "../look" exports...
@use "../editor_type" exports...
@use "../host" exports...

export AGENT_KINDS, AGENTS_RENAMED, agent_renamed, AGENTS_HIDDEN, agent_listed!, agent_path,
       agent_command, AgentModel, model_list, KNOWN_MODELS, AGENT_MODELS, MODELS_ASKING,
       MODELS_ASKED, agent_models, ask_models!, claude_models, claude_list, grok_models, grok_list,
       antigravity_models, antigravity_list, codex_models, pretty_model, model_of, model_name,
       MODELS_CHOSEN, chosen_model, model_chosen!, models_setting, json_field, agent_json,
       AGENT_COMMAND, CLAUDE_LOGO, GROK_LOGO, OPENAI_LOGO, GEMINI_LOGO, ANTIGRAVITY_LOGO,
       AGENT_LOGOS, agent_logo, listed_agents, kind_command, agent_kind

# Claude's words go straight after -p. An option that takes a list, like --allowedTools, would take them as part of its list.
const AGENT_KINDS = [
  AgentKind("Claude", "claude", ["~/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "~/.claude/local"],
            ["--output-format", "stream-json", "--verbose", "--permission-mode", "acceptEdits", "--allowedTools", "Read,Edit,Grep,Glob", "-p"],
            ["--output-format", "stream-json", "--verbose", "--allowedTools", "Read,Grep,Glob", "-p"],
            # Haiku writes a message in a few seconds. Safe mode starts with no plugins, MCP servers or hooks, so it starts quickly.
            ["--model", "haiku", "--output-format", "text", "--safe-mode", "--no-session-persistence", "-p"], true),
  # Google's Antigravity. In its plan mode it reads files, and the plan that it writes goes in a folder of its own, not in yours.
  AgentKind("Antigravity", "agy", ["~/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"],
            ["--mode", "accept-edits", "-p"], ["--mode", "plan", "-p"]),
  AgentKind("Codex", "codex", ["/opt/homebrew/bin", "/usr/local/bin", "~/.local/bin"],
            ["exec", "--sandbox", "workspace-write", "--skip-git-repo-check"],
            ["exec", "--sandbox", "read-only", "--skip-git-repo-check"]),
  # Grok takes text that's piped to it as something to read with a tool, so it gets it in the words
  AgentKind("Grok", "grok", ["~/.grok/bin", "/opt/homebrew/bin", "/usr/local/bin", "~/.local/bin"],
            ["--permission-mode", "acceptEdits", "-p"], ["--permission-mode", "plan", "-p"],
            ["--permission-mode", "plan", "--no-memory", "--disable-web-search", "-p"], false)]

"""
The agents that Ladder started by another name before, by that name.
Antigravity took the place of Gemini CLI, as Antigravity has Google's newest
models. A setting or a session's file that names Gemini means Antigravity.
"""
const AGENTS_RENAMED = Dict("Gemini" => "Antigravity")

"The name of the agent that Ladder knew as `name` before, or `name`"
agent_renamed(name::AbstractString) = get(AGENTS_RENAMED, name, String(name))

"The agent called `name` that Ladder can start, or Claude Code when there's none of that name"
agent_kind(name::AbstractString) = (name = agent_renamed(name); AGENT_KINDS[something(findfirst(k -> k.name == name, AGENT_KINDS), 1)])

"The names of the agents that you took out of Ladder's lists in Settings. Every window has them, and the settings file keeps them."
const AGENTS_HIDDEN = Ref(Set{String}())

"""
The names of the agents that Ladder lists for you to choose from: in the
menu of agent mode, in Settings and for the command Switch Agent. Settings
has a box for each agent. The agent that's chosen now is always listed.
"""
listed_agents(e) = [k.name for k in AGENT_KINDS if !(k.name in AGENTS_HIDDEN[]) || k.name == agent_kind(e.ai).name]

"List the agent called `name` for you to choose from, or with `on` false take it out of the lists. The settings keep it."
agent_listed!(e, name::AbstractString, on::Bool) = begin
  any(k -> k.name == name, AGENT_KINDS) || error("Ladder can't start an agent called $name.")
  (on ? delete! : push!)(AGENTS_HIDDEN[], String(name))
  save_settings!(e)
  foreach(o -> (rerun!(o, :agents); redraw_in!(o, 0)), editors)
  e
end

"""
Where the command of the agent `k` is. An app that the Finder opened doesn't
have the terminal's PATH, so the agent's usual folders are tried too.
"""
agent_path(k::AgentKind) = begin
  found = Sys.which(k.command)
  found === nothing || return found
  for dir in k.places
    file = joinpath(expanduser(dir), k.command)
    isfile(file) && return file
  end
  error("Ladder can't find the command `$(k.command)` of $(k.name). Install it, or choose another agent with the command Switch Agent.")
end

"""
The command that the agent that Settings chose for `e` is started with. The
words go after it. The command's own folder and Homebrew's are on its PATH,
as a command of Node, like Codex's, needs `node`.
"""
agent_command(e) = begin
  AGENT_COMMAND[] === nothing || return AGENT_COMMAND[]
  k = agent_kind(e.ai)
  kind_command(k, k.change)
end

"The command of the agent `k` with the options `options`, which the words go after, with its own folder and Homebrew's on its PATH"
kind_command(k::AgentKind, options) = begin
  found = agent_path(k)
  path = join(unique([dirname(found), "/opt/homebrew/bin", "/usr/local/bin", split(get(ENV, "PATH", "/usr/bin:/bin"), ':')...]), ':')
  addenv(Cmd([found; options]), "PATH" => path)
end

# --- the models of the agents ---
#
# Each agent can work with more than one model. The agent's pane shows the
# model of its session beside the send button, and a click there chooses
# another. Ladder asks Claude Code, Antigravity and Grok for their lists of
# models once, while the app runs, and reads the list that Codex keeps.

"""
A model that an agent can work with. `id` is the name that the agent's
command is given, `name` is the one that Ladder shows, `about` is a few
words on what it's for, and `is` is the model's full name, which the agent
gives when it says which model it works with.
"""
struct AgentModel
  id::String
  name::String
  about::String
  is::String
end
AgentModel(id, name, about="") = AgentModel(id, name, about, id)

"""
The models of an agent: `listed` are the ones to choose from, `every` also
has older ones that only name a model, and `default` is the full name of the
model that the agent works with when it's given none, or "".
"""
const ModelList = NamedTuple{(:listed, :every, :default),Tuple{Vector{AgentModel},Vector{AgentModel},String}}
model_list(listed, every=listed, default="") = ModelList((listed, every, default))

"""
The models that Ladder knows of before it asks. Claude Code's names, like
opus, are for the newest model of their kind.
"""
const KNOWN_MODELS = Dict(
  "Claude" => model_list([AgentModel("opus", "Opus"), AgentModel("fable", "Fable"), AgentModel("sonnet", "Sonnet"), AgentModel("haiku", "Haiku")]))

"The models of each agent, by the agent's name, as the agent gave them. A test puts lists of its own here."
const AGENT_MODELS = Dict{String,ModelList}()

"The agents whose models Ladder asks for now"
const MODELS_ASKING = Set{String}()

"The agents whose models Ladder asked for since the app started"
const MODELS_ASKED = Set{String}()

"""
The models of the agent called `name`. The first time, Ladder asks the agent
for them, and meanwhile it gives the ones it knows already: see
`ask_models!`.
"""
agent_models(name::AbstractString) = begin
  haskey(AGENT_MODELS, name) && return AGENT_MODELS[name]
  ask_models!(name)
  get(() -> model_list(AgentModel[]), KNOWN_MODELS, name)
end

"""
Ask the agent called `name` for its models, once while the app runs. A task
asks, and the list is there when it's done: a window that's waiting for it
gives the task its turns (see `pane_tick!`). An agent that isn't on this Mac
gives no list, and Ladder keeps the names that it knows.
"""
ask_models!(name::AbstractString) = begin
  (name in MODELS_ASKED || !(name in ("Claude", "Antigravity", "Grok", "Codex"))) && return nothing
  name = String(name)
  push!(MODELS_ASKED, name)
  push!(MODELS_ASKING, name)
  @async try
    list = name == "Claude" ? claude_models() : name == "Antigravity" ? antigravity_models() : name == "Grok" ? grok_models() : codex_models()
    list === nothing || (AGENT_MODELS[name] = list)
  catch
  finally
    delete!(MODELS_ASKING, name)
    redraw_windows!()
  end
  nothing
end

"""
Claude Code's models, as its program gives them when it starts: the names
like opus to choose from, and the older models that it names in full, which
only name a model. Its first answer is its list. It ends when it has no more
to read.
"""
claude_models() = begin
  k = agent_kind("Claude")
  command = kind_command(k, ["-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose", "--safe-mode", "--no-session-persistence"])
  ask = """{"type":"control_request","request_id":"ladder-models","request":{"subtype":"initialize"}}\n"""
  claude_list(read(pipeline(Cmd(command; dir=homedir()), stdin=IOBuffer(ask), stderr=devnull), String))
end

"The models in `said`, what Claude Code printed when it was asked for them, or nothing"
claude_list(said::AbstractString) = begin
  for line in split(said, '\n')
    o = agent_json(line)
    json_field(o, "type") == "control_response" || continue
    found = json_field(json_field(json_field(o, "response"), "response"), "models")
    found isa AbstractVector || return nothing
    listed, every, default = AgentModel[], AgentModel[], ""
    for m in found
      id, name, about, is = (json_field(m, key) for key in ("value", "displayName", "description", "resolvedModel"))
      (id isa String && name isa String) || continue
      is = is isa String ? is : id
      id == "default" && (default = is; continue)
      model = AgentModel(id, name, about isa String ? about : "", is)
      push!(every, model)
      startswith(id, "claude-") || push!(listed, model)
    end
    return isempty(listed) ? nothing : model_list(listed, every, default)
  end
  nothing
end

"Grok's models, as `grok models` lists them: one to a line, with a * before the one that it uses when it's given none"
grok_models() = grok_list(read(pipeline(kind_command(agent_kind("Grok"), ["models"]), stderr=devnull), String))

"The models in `said`, what `grok models` printed, or nothing"
grok_list(said::AbstractString) = begin
  listed, default = AgentModel[], ""
  for line in split(said, '\n')
    m = match(r"^\s*([*-])\s+(\S+)", line)
    m === nothing && continue
    push!(listed, AgentModel(m[2], pretty_model(m[2])))
    m[1] == "*" && (default = String(m[2]))
  end
  isempty(listed) ? nothing : model_list(listed, listed, default)
end

"Antigravity's models, as `agy models` lists them: one to a line, the name that its command is given, a tab, and the name that it shows"
antigravity_models() = antigravity_list(read(pipeline(kind_command(agent_kind("Antigravity"), ["models"]), stderr=devnull), String))

"""
The models in `said`, what `agy models` printed, or nothing. A model of
Antigravity is the same model with each effort, like Gemini 4 Neon (Low) and
Gemini 4 Neon (High). The menu shows them in one row: see `model_rows`. Its
program doesn't say which model it works with when it's given none.
"""
antigravity_list(said::AbstractString) = begin
  listed = AgentModel[]
  for line in split(said, '\n')
    m = match(r"^(\S+)\t(.+?)\s*$", line)
    m === nothing || push!(listed, AgentModel(m[1], m[2]))
  end
  isempty(listed) ? nothing : model_list(listed)
end

"Codex's models, from the list that it keeps of the models that it shows, and the one that its settings choose"
codex_models() = begin
  file = joinpath(homedir(), ".codex", "models_cache.json")
  found = json_field(json_value(read(file)), "models")
  found isa AbstractVector || return nothing
  listed = AgentModel[]
  for m in found
    json_field(m, "visibility") == "list" || continue
    id, name, about = (json_field(m, key) for key in ("slug", "display_name", "description"))
    id isa String || continue
    push!(listed, AgentModel(id, name isa String ? name : pretty_model(id), about isa String ? about : ""))
  end
  settings = joinpath(homedir(), ".codex", "config.toml")
  m = isfile(settings) ? match(r"^model\s*=\s*\"([^\"]+)\""m, read(settings, String)) : nothing
  isempty(listed) ? nothing : model_list(listed, listed, m === nothing ? "" : String(m[1]))
end

"""
The name to show for the model `x` of a program, like claude-opus-5-5, when
the agent's list doesn't name it: Opus 5.5. A date at the end is left out.
"""
pretty_model(x::AbstractString) = begin
  words = String[]
  for w in split(replace(String(x), r"^claude-" => "", r"-\d{8}$" => ""), '-')
    isempty(w) && continue
    if !isempty(words) && occursin(r"^\d+$", w) && occursin(r"\d$", words[end])
      words[end] *= "." * w   # 5-5 is 5.5
    else
      push!(words, w == "gpt" ? "GPT" : uppercasefirst(w))
    end
  end
  join(words, ' ')
end

"The model of the agent called `agent` that `x` names, by the name that its command is given or by its full name, or nothing"
model_of(agent::AbstractString, x::AbstractString) = begin
  list = agent_models(agent)
  for models in (list.listed, list.every)
    k = findfirst(m -> m.id == x || m.is == x, models)
    k === nothing || return models[k]
  end
  nothing
end

"The name that Ladder shows for the model `x` of the agent called `agent`"
model_name(agent::AbstractString, x::AbstractString) = (m = model_of(agent, x); m === nothing ? pretty_model(x) : m.name)

"The model of each agent that you chose last, by the name that its command is given. An agent that's not in it uses its own choice. The settings file keeps it."
const MODELS_CHOSEN = Ref(Dict{String,String}())

"The model of the agent called `agent` that a new session starts with, or \"\" for the agent's own choice"
chosen_model(agent::AbstractString) = get(MODELS_CHOSEN[], agent, "")

"Make the model `id` the one that new sessions of the agent called `agent` start with. The settings keep it."
model_chosen!(e, agent::AbstractString, id::AbstractString) = begin
  chosen_model(agent) == id && return e
  MODELS_CHOSEN[][String(agent)] = String(id)
  save_settings!(e)
  e
end

"The line of the settings file that keeps the model of each agent: each agent's name, a colon and the model, with commas between them"
models_setting() = join(("$agent:$id" for (agent, id) in sort!(collect(MODELS_CHOSEN[])) if !isempty(id)), ',')

"The value of `key` in the JSON object `o`, or nothing"
json_field(o, key) = o isa JSONObject && (k = findfirst(==(key), o.keys); k !== nothing) ? o.values[k] : nothing

"A line that an agent printed, read as JSON, or nothing for a line that isn't JSON"
agent_json(line::AbstractString) = startswith(line, '{') ? (try json_value(Vector{UInt8}(line)) catch; nothing end) : nothing

"The command that changes code when it's asked to in words. Nothing means the command of the agent that Settings chose. A test puts a command of its own here."
const AGENT_COMMAND = Ref{Any}(nothing)

# The logos of the agents that Ladder knows. Each is one shape in a square 24
# wide, from Simple Icons (Claude, OpenAI, Gemini) and Lobe Icons (Grok, Antigravity).
const CLAUDE_LOGO = "m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z"
const GROK_LOGO = "M9.27 15.29l7.978-5.897c.391-.29.95-.177 1.137.272.98 2.369.542 5.215-1.41 7.169-1.951 1.954-4.667 2.382-7.149 1.406l-2.711 1.257c3.889 2.661 8.611 2.003 11.562-.953 2.341-2.344 3.066-5.539 2.388-8.42l.006.007c-.983-4.232.242-5.924 2.75-9.383.06-.082.12-.164.179-.248l-3.301 3.305v-.01L9.267 15.292M7.623 16.723c-2.792-2.67-2.31-6.801.071-9.184 1.761-1.763 4.647-2.483 7.166-1.425l2.705-1.25a7.808 7.808 0 00-1.829-1A8.975 8.975 0 005.984 5.83c-2.533 2.536-3.33 6.436-1.962 9.764 1.022 2.487-.653 4.246-2.34 6.022-.599.63-1.199 1.259-1.682 1.925l7.62-6.815"
const OPENAI_LOGO = "M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z"
const GEMINI_LOGO = "M11.04 19.32Q12 21.51 12 24q0-2.49.93-4.68.96-2.19 2.58-3.81t3.81-2.55Q21.51 12 24 12q-2.49 0-4.68-.93a12.3 12.3 0 0 1-3.81-2.58 12.3 12.3 0 0 1-2.58-3.81Q12 2.49 12 0q0 2.49-.96 4.68-.93 2.19-2.55 3.81a12.3 12.3 0 0 1-3.81 2.58Q2.49 12 0 12q2.49 0 4.68.96 2.19.93 3.81 2.55t2.55 3.81"
const ANTIGRAVITY_LOGO = "M21.751 22.607c1.34 1.005 3.35.335 1.508-1.508C17.73 15.74 18.904 1 12.037 1 5.17 1 6.342 15.74.815 21.1c-2.01 2.009.167 2.511 1.507 1.506 5.192-3.517 4.857-9.714 9.715-9.714 4.857 0 4.522 6.197 9.714 9.715z"

"""
The logo of each agent that Ladder knows, by the first word of the name that
the agent calls itself, in small letters: the logo's shape, and its colour,
or nothing for the colour of the page's text.
"""
const AGENT_LOGOS = Dict("claude" => (CLAUDE_LOGO, colorant"#D97757"),
                         "grok" => (GROK_LOGO, nothing),
                         "codex" => (OPENAI_LOGO, nothing), "chatgpt" => (OPENAI_LOGO, nothing), "openai" => (OPENAI_LOGO, nothing),
                         "gemini" => (GEMINI_LOGO, colorant"#8E75B2"), "antigravity" => (ANTIGRAVITY_LOGO, colorant"#3186FF"))

"""
The name of the icon of the logo of the agent called `name`, like \"Claude\",
and the logo's colour: nothing for an agent that Ladder has no logo of. The
logo goes among UI.jl's icons the first time that it's asked for, as the
snake does: see `snake`.
"""
agent_logo(name::AbstractString) = begin
  word = match(r"[A-Za-z]+", name)
  word === nothing && return nothing
  key = lowercase(word.match)
  found = get(AGENT_LOGOS, key, nothing)
  found === nothing && return nothing
  shape, colour = found
  icon = "agent-" * key
  kept = get(icon_cache, icon, nothing)
  (kept === nothing || first(kept.paths).d != shape) && (icon_cache[icon] = (paths=[SVGPath(d=shape, evenodd=key == "grok")], viewbox=(0f0, 0f0, 24f0, 24f0)))
  (icon, something(colour, colours.ink))
end
