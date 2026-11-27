# The agent's pane: what you type and what the agent says, the list of commands, pictures, replies you change, the outline, and a session's file

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe reuse! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" draw ishovered cursor show_tooltip! hide_tooltip! redraw_in! rect popup! close_popup! with_clip
@use "github.com/jkroso/UI.jl/Interface/image" image_aspect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/Recorder" stop!
@use "github.com/jkroso/UI.jl/Interface/media" picture_size
@use "../pictures" thumbnail
@use "../merge" unified
@use "../for_agents" => Offer
@use "../pasteboard" => Pasteboard
@use "github.com/jkroso/JSON.jl" JSONNumber write_json
@use "../web/browser" => Browsers
@use "../web/source" => Sources
@use "github.com/jkroso/UI.jl/Interface/draw" popups
@use "github.com/jkroso/URI.jl/FS" => FS AbstractDirectory
@use Colors: RGBA
@use InteractiveUtils: clipboard
@use "../look" exports...
@use "../flow" exports...
@use "../buffer" exports...
@use "../editor_type" exports...
@use "../faces" exports...
@use "../blocks" exports...
@use "../rich" end_room
@use "../strokes" exports...
@use "../shared" exports...
@use "../host" exports...
@use "../folder_page" exports...
@use "../git_marks" exports...
@use "../linkcard_view" exports...
@use "../webpage_view" exports...
@use "../git_page" exports...
@use "../run_code" exports...
@use "../code_nav" exports...
@use "./kinds" exports...
@use "./session" exports...
@use "./window" exports...
@use "./page" exports...

export pane_field!, reply_editor, talk_on_page, talk_zoom, page_symbols, pane_style!, page_inked,
       pane_layout!, show_reply!, agent_part_of, agent_key!, session!, pane_agent!, AGENT_MENU, AGENT_MENU_W,
       AgentMenu, AgentMenuRow, choose_agent!, pane_model!, MODEL_MENU, MODEL_MENU_W, ModelMenu, ModelMenuRow,
       EffortButton, EFFORTS, model_effort, model_rows, menu_rows, menu_efforts, effort_wide, model_menu_wide,
       row_choice, choose_model!, effort_slot, effort_button, text_between, MOST_PICKED, page_context,
       MOST_PARAGRAPH, html_picked, html_letters, page_letters, html_told, html_outline,
       send_words!, SLASH_MENU, SLASH_MOST, SLASH_ROW, SLASH_CROWN, SLASH_INSET, SlashMenu, SlashRow,
       SlashLens, slash_menu, slash_wide, slash_parts, slash_rows, field!, slash_tick!, look_for_sessions!,
       slash_key!, slash_pick!, run_own!, resume_session!, row_of, attached, AGENT_PICTURES, agent_pictures,
       made_pictures, attach!, unattach!, paste_for_agent!, give_files!, agent_pane_at, small_picture,
       attached_row, PICTURE_TALL, new_session!, close_agent!, session_tick!, pane_tick!, reply_tick!,
       reply_changed, changed_replies, changes_told, send_tip, pane_button, pane_face, pane_head, pane_talk,
       words_block, code_wrapped, talk_row, step_row, pane_foot, pane_slot, model_shows, pane_model, model_words,
       model_face, model_wide, MODEL_BUTTON_ROOM, MODEL_GAP, one_line, solid_on_glass, send_button, section_now,
       section_in_view, OUTLINE_STEP, widen_for_agent!, narrow_from_agent!, agent_mode!, end_agent_session!,
       CHAT_WIDE, PAGE_TALK, TALK_MARK, chats, pane_wide, pane_context, talk_mark, talk_body, talk_part,
       talk_text, read_talk, load_talk!, chat_part, TALK_SLIDE, TalkRoom, said_nothing, talk_page,
       talk_greeting, chat_tick!, close_chats!, new_agent_session!

"The editor of the words that you type to the agent, which the pane `p` of the window of `e` shows: lines that no file holds"
pane_field!(p::AgentPane) = begin
  sub = Editor()
  sub.buf = Buffer()
  sub.nodes[:input] = own!(sub, TextInput())
  sub.nodes[:agent_part] = (p, :field)
  setfield!(sub, :parent, p)
  p.field = sub
end

"The editor of a reply of the agent, which the pane `p` of the window of `e` shows as a page that's never changed. A link in it opens in the window."
reply_editor(p::AgentPane, e, dir) = begin
  sub = Editor()
  sub.buf = Buffer(path=reply_page(dir), fixed=true, reading=true)
  sub.nodes[:input] = own!(sub, TextInput())
  sub.nodes[:host] = e
  sub.nodes[:span] = (1, 1)
  sub.nodes[:agent_part] = (p, :reply)
  setfield!(sub, :parent, p)
  sub
end

"True while the talk that's being described is a session's file in the page, and not the pane of agent mode: see \"a session's file\""
const talk_on_page = Ref(false)

"How much bigger than its sizes in the pane the talk's text is now: the window's zoom, and in a session's file the page's bigger text"
talk_zoom(e) = e.zoom * (talk_on_page[] ? PAGE_TALK / REPLY_SIZE : 1.0)

"""
True when the window of `e` shows its page at the low level, as symbols: the
top bar shows the snake. The agent's replies and your words to it are then at
that level too. A file with more than one way to show, like a session's file,
and a block that fills the window, are at the high level here.
"""
page_symbols(e) = e.plain && e.buf.view == :markdown && full_block(e) === nothing

"Give the editor `sub` of a part of the agent's pane the colours and keys of the window of `e`, with the pane's own font and size, at the level of the window's page"
pane_style!(sub, e; own=false) = begin
  follow_host!(sub, e)
  # What the agent says in a session's file has the page's own font: `own` is true for it there
  sub.font, sub.zoom, sub.look, sub.spelling = own ? e.font : SANS, talk_zoom(e) * (REPLY_SIZE / TEXT_SIZE), :own, false
  talk_on_page[] || (sub.theme = :night)   # the pane is dark, so what's kept by the theme's name is kept apart from the page's
  sub.plain = page_symbols(e)   # at the snake, the run with the caret in a reply or in your words shows its markup too
  # Text that was laid out in other colours than the pane's is laid out again: each line keeps the colours that it was laid out in
  inks = (colours.ink, colours.dim, colours.accent)
  get(sub.nodes, :pane_inks, nothing) == inks || (sub.nodes[:pane_inks] = inks; empty!(sub.flows))
  sub
end

"True when some line that `sub` laid out has the page's colour of text, and not the pane's: it was laid out while the page's colours were in use"
page_inked(sub) = PAGE_KEPT.ink != colours.ink &&
  any(it -> it.content isa Flow && any(vl -> any(seg -> seg.face.color == PAGE_KEPT.ink, vl.segs), it.content.lines), sub.layout)

"""
Lay out the text of the editor `sub` of a part of the agent's pane, as wide
as `room`. Each line keeps the colours that it was laid out in, so lines
that have the page's colours are laid out again in the pane's.
"""
pane_layout!(sub, room) = begin
  layout!(sub, room)
  page_inked(sub) && (empty!(sub.flows); layout!(sub, room))
  sub
end

"Put the words of the reply `it` in its editor `sub`, when they changed since it last showed them"
show_reply!(sub, it::AgentReply) = begin
  sub.nodes[:reply] = it
  # What the agent still says can't be changed, as its next words would take the place of the change
  sub.buf.fixed = !it.whole
  get(sub.nodes, :shown, -1) == it.n && return sub
  b = sub.buf
  b.lines = String.(split(rstrip(it.text), '\n'))
  b.version = (stamp[] += 1)   # a number that no other version has had, as an edit gives
  b.caret = b.anchor = (1, 0)
  sub.nodes[:span] = (1, length(b.lines))
  sub.nodes[:shown] = it.n
  sub
end

"The part of the agent's pane of an editor `e` that the pane shows, with what kind of part it is: `:field` or `:reply`. Nothing for any other editor."
agent_part_of(e) = get(e.nodes, :agent_part, nothing)

"""
What a key does in a part of the agent's pane, before the part's editor does
what it does with a key. True when the key is done with. In the words that
you type, Return gives them to the agent, and ⇧Return starts a new line. A
command for the window runs in the window's page. Esc does nothing.
"""
agent_key!(e, w, K, command) = begin
  p, kind = agent_part_of(e)
  # While the list of commands shows over the words, the arrows, Tab and Return are the list's
  kind == :field && slash_key!(p, w, K) && return true
  kind == :field && K == Keys.enter && unmodified(w) && (send_words!(p); return true)
  K == Keys.escape && return true
  (command !== nothing && (command_kind(command) == :window || command in (:find, :find_next, :find_last))) || return false
  run!(editor(p), w, command, false)
  true
end

"The session of the pane `p` of the window of `e`, with its program running. The first words start it, in the top folder of the file's repository."
session!(p::AgentPane, e) = begin
  on_page(p) && p.session === nothing && load_talk!(p, e)   # a session's file has its session from the file
  s = p.session
  if s === nothing
    b = e.buf
    onmac = !isempty(b.path) && !isremote(b.path)
    top = repo_of(e)
    dir = !isempty(top) ? top : onmac ? (isdir(b.path) ? b.path : dirname(b.path)) : isempty(e.folder) ? homedir() : e.folder
    agent = pane_agent(p, e)
    s = AgentSession(agent=agent, dir=dir, page=writes(b) ? truepath(b.path) : "", turns=by_turns(agent), model=chosen_model(agent))
  end
  has_code(s) && beside!(s, p)
  # An agent that works by turns has no program between turns: `say!` starts one
  s.turns || running(s) || start!(s, session_command(s))
  p.session = s
end

"""
Make the agent called `name` the one of the pane `p`, as the command Switch
Agent does. A session with another agent ends: your next words start one
with the new agent.
"""
pane_agent!(p::AgentPane, name::AbstractString) = begin
  e = editor(p)
  agent_kind(e.ai).name == name || preferred_agent!(e, String(name))
  s = p.session
  s === nothing || s.agent == name || new_session!(p)
  redraw_in!(e, SOON)
  nothing
end

const AGENT_MENU = :agent_menu
const AGENT_MENU_W = 200px

"The menu of the agents, under the agent's name in the top bar. `over` is the row that the mouse or an arrow key is on, or 0."
@def mutable struct AgentMenu <: SemanticUI
  of::Any = nothing
  over::Int = 0
end

"A row of the menu of the agents: the agent called `name`, with its logo"
@def mutable struct AgentMenuRow <: SemanticUI
  menu::Any = nothing
  name::String = ""
  index::Int = 0
end

"""
Show the agents that Ladder lists, in a menu under `under`, the agent's
name in the top bar. Each has its logo before its name, and the pane's
agent has a tick. A click on one makes it the pane's agent. Settings says
which agents the menu lists: see `listed_agents`.
"""
choose_agent!(p::AgentPane, under, w) = begin
  any(q -> q.key == AGENT_MENU, popups(w)) && return (close_popup!(w, AGENT_MENU); nothing)
  e = editor(p)
  menu = node!(() -> AgentMenu(of=p), e, :agent_menu)
  menu.over = 0
  popup!(w, menu, anchor=under, placement=:below, gap=4px, width=AGENT_MENU_W, key=AGENT_MENU, theme=component_theme(e.zoom))
  nothing
end

describe(m::AgentMenu) = with_pane_colours() do
  p = m.of
  e = editor(p)
  names = listed_agents(e)
  Column(width(grow=grow), Alignment.Start, padding(4px), child_gap=1px, radius(8px), name="Agent menu",
         background(colours.float), border(1px, :solid, colours.line), shadow(0px, 6px, 20px, RGBA(0, 0, 0, 0.35)),
    (node!(() -> AgentMenuRow(menu=m, name=name), e, (:agent_row, name)) for name in names)...)
end

describe(r::AgentMenuRow) = begin
  p = r.menu.of
  e = editor(p)
  names = listed_agents(e)
  r.index = something(findfirst(==(r.name), names), 0)
  logo = agent_logo(r.name)
  here = try agent_path(agent_kind(r.name)); true catch; false end
  Row(width(grow=grow), height(30px), Alignment.Center, padding(8px, 0px), child_gap=9px, radius(5px), name="Agent row",
      background(ishovered(r) || r.menu.over == r.index ? on_glass(0.1) : clear),
    Box(fixed(16px), height(16px), Alignment.Center, justify=Alignment.Center,
        logo === nothing ? Icon("robot", size=15px, color=colours.dim) : Icon(logo[1], size=15px, color=logo[2])),
    Box(label(r.name, 13px, color=here ? colours.ink : colours.dim)),
    # An agent whose command isn't on this Mac says so. A click still chooses it, and the pane says how to install it.
    (here ? () : (Box(label("not installed", 11px, color=colours.faint)),))...,
    Box(width(grow=grow)),
    (pane_agent(p, e) == r.name ? (Icon("check", size=12px, color=colours.dim),) : ())...)
end

cursor(::AgentMenuRow) = :hand
onmouse(r::AgentMenuRow, ::MouseMove) = (r.menu.over = r.index; nothing)
onkey(r::AgentMenuRow, ev::KeyPress{Keys.mouse_left}) = (close_popup!(ev.window, AGENT_MENU); pane_agent!(r.menu.of, r.name); handled)
# The arrows move over the rows, and Return chooses the row that they're on
onkey(m::AgentMenu, ::KeyPress{Keys.down}) = (n = length(listed_agents(editor(m.of))); m.over = n == 0 ? 0 : mod1(m.over + 1, n); redraw_in!(editor(m.of), SOON); handled)
onkey(m::AgentMenu, ::KeyPress{Keys.up}) = (n = length(listed_agents(editor(m.of))); m.over = n == 0 ? 0 : mod1(m.over - 1, n); redraw_in!(editor(m.of), SOON); handled)
onkey(m::AgentMenu, ev::KeyPress{Keys.enter}) = begin
  names = listed_agents(editor(m.of))
  m.over in eachindex(names) || return handled
  close_popup!(ev.window, AGENT_MENU)
  pane_agent!(m.of, names[m.over])
  handled
end

"""
Make the model `id` the one of the agent of the pane `p`: of its session, and
of the sessions with that agent that you start after it. A session that
already works with that model goes on as it is.
"""
pane_model!(p::AgentPane, id::AbstractString) = begin
  e = editor(p)
  agent = pane_agent(p, e)
  model_chosen!(e, agent, id)
  s = p.session
  if s !== nothing
    m, x = model_of(agent, id), pane_model(p, e)
    x == id || (m !== nothing && x == m.is) ? (s.model = String(id)) : model!(s, id)
  end
  redraw_in!(e, SOON)
  nothing
end

const MODEL_MENU = :model_menu
const MODEL_MENU_W = 280px

"The menu of the models of the pane's agent, over the model's button. `over` is the row that the mouse or an arrow key is on, or 0."
@def mutable struct ModelMenu <: SemanticUI
  of::Any = nothing
  over::Int = 0
end

"""
A row of the menu of the models: one model, or one model with each effort
that it has, like Gemini 4 Neon with Low, Medium and High (see
`model_rows`). `name` is what the row says, `models` are its models, and
`model` is the one that a click on the row chooses, an `AgentModel`, with a
few words on what it's for.
"""
@def mutable struct ModelMenuRow <: SemanticUI
  menu::Any = nothing
  model::Any = nothing
  name::String = ""
  models::Vector{AgentModel} = AgentModel[]
  index::Int = 0
end

"A button in a row of the menu of the models for one effort of its model, like High. A click chooses `model`, the model with that effort."
@def mutable struct EffortButton <: SemanticUI
  row::Any = nothing
  model::Any = nothing
  effort::String = ""
end

"The efforts that a model can work with, from the least to the most, as the names of Antigravity's models say them: Gemini 4 Neon (High)"
const EFFORTS = ["Minimal", "Low", "Medium", "High", "XHigh", "Max"]

"The model that the name `name` names without its effort, and the effort, or nothing for a name with no effort in it"
model_effort(name::AbstractString) = begin
  m = match(r"^(.*\S)\s*\(([^()]+)\)$", name)
  m === nothing || !(m[2] in EFFORTS) ? nothing : (String(m[1]), String(m[2]))
end

"""
The rows of a menu of the models `models`: what each row says, and its
models. The models that are one model with each of its efforts are one row,
from the least effort to the most, in the place of the first of them.
"""
model_rows(models) = begin
  rows = Pair{String,Vector{AgentModel}}[]
  for model in models
    named = model_effort(model.name)
    k = named === nothing ? nothing : findfirst(r -> r.first == named[1] && model_effort(r.second[1].name) !== nothing, rows)
    k === nothing ? push!(rows, (named === nothing ? model.name : named[1]) => [model]) : push!(rows[k].second, model)
  end
  for r in rows
    model_effort(r.second[1].name) === nothing || sort!(r.second, by=m -> findfirst(==(model_effort(m.name)[2]), EFFORTS))
  end
  rows
end

"The rows of the menu of the models of the pane `p`: see `model_rows`"
menu_rows(p::AgentPane) = model_rows(agent_models(pane_agent(p, editor(p))).listed)

"The efforts that the rows of the menu of the models of the pane `p` have, from the least to the most. Each is a column of the menu."
menu_efforts(p::AgentPane) = begin
  had = Set(f[2] for r in menu_rows(p) for m in r.second for f in (model_effort(m.name),) if f !== nothing)
  filter(in(had), EFFORTS)
end

"How wide the button of the effort `effort` is: its word, and room at each side"
effort_wide(effort::AbstractString) = measure(Face(SANS, "", 11.5px, colours.dim, false), effort) + 14px

"""
How wide the menu of the models of the pane `p` is. A menu whose rows have
efforts is as wide as its longest name, the columns of the efforts, the tick
and the room round them need.
"""
model_menu_wide(p::AgentPane) = begin
  efforts = menu_efforts(p)
  isempty(efforts) && return MODEL_MENU_W
  names = maximum(measure(Face(SANS, "", 13px, colours.ink, false), r.first) for r in menu_rows(p))
  buttons = sum(effort_wide, efforts) + 2px * (length(efforts) - 1)
  # The menu's padding, the row's padding, the two gaps in the row, the tick, and a little more
  max(MODEL_MENU_W, px(ceil(num(names + buttons + 2 * 4px + 2 * 10px + 2 * 8px + 12px + 6px))))
end

"""
The model of `models`, one row of the menu, that a click on the row
chooses, when the agent of the pane works with the model `x`: `x`, when
it's in the row, else the one with the same effort as `x`, else the one with
Medium, else the first.
"""
row_choice(agent::AbstractString, models, x::AbstractString) = begin
  k = findfirst(m -> m.id == x || m.is == x, models)
  k === nothing || return models[k]
  now = model_of(agent, x)
  was = now === nothing ? nothing : model_effort(now.name)
  for effort in (was === nothing ? "Medium" : was[2], "Medium")
    k = findfirst(m -> (f = model_effort(m.name); f !== nothing && f[2] == effort), models)
    k === nothing || return models[k]
  end
  first(models)
end

"""
Show the models of the agent of the pane `p` in a menu over `under`, the
model's button, with its right edge in line with the button's. The model
that the agent works with has a tick. A click on one makes it the model of
the agent: see `pane_model!`.
"""
choose_model!(p::AgentPane, under, w) = begin
  any(q -> q.key == MODEL_MENU, popups(w)) && return (close_popup!(w, MODEL_MENU); nothing)
  r = rect(under)
  r === nothing && return nothing
  e = editor(p)
  menu = node!(() -> ModelMenu(of=p), e, :model_menu)
  menu.over = 0
  wide = model_menu_wide(p)
  popup!(w, menu, anchor=(r.left + r.width - wide, r.top, wide, r.height), placement=:top, gap=6px,
         width=wide, key=MODEL_MENU, theme=component_theme(e.zoom))
  nothing
end

# Agent mode's panes are dark, and a session's file has the page's colours
describe(m::ModelMenu) = with_pane_colours(!on_page(m.of)) do
  p = m.of
  e = editor(p)
  agent = pane_agent(p, e)
  x = pane_model(p, e)
  rows = Any[]
  for (name, models) in menu_rows(p)
    row = node!(() -> ModelMenuRow(menu=m), e, (:model_row, agent, name))
    row.name, row.models, row.model = name, models, row_choice(agent, models, x)
    push!(rows, row)
  end
  isempty(rows) && push!(rows, Row(height(32px), Alignment.Center, padding(10px, 0px), name="No models",
    Box(label(agent in MODELS_ASKING ? "Asking $agent for its models…" : "$agent didn't give a list of its models.", 12px, color=colours.dim))))
  Column(width(grow=grow), Alignment.Start, padding(4px), child_gap=1px, radius(8px), name="Model menu",
         background(colours.float), border(1px, :solid, colours.line), shadow(0px, 6px, 20px, RGBA(0, 0, 0, 0.35)),
    rows...)
end

describe(r::ModelMenuRow) = begin
  p = r.menu.of
  e = editor(p)
  model = r.model
  r.index = something(findfirst(x -> x.first == r.name, menu_rows(p)), 0)
  x = pane_model(p, e)
  face = Face(SANS, "", 11.5px, colours.dim, false)
  # A label is as tall as its capitals, so each line has a row as tall as a line of its words
  about = isempty(model.about) ? () :
    (Row(height(face.size * 1.4), Alignment.Center, label(l, face.size, color=colours.dim)) for l in wrapped(face, model.about, num(model_menu_wide(p) - 50px)))
  # An effort that the model hasn't got leaves its column empty, so each effort is under the same effort of the other rows
  efforts = model_effort(model.name) === nothing ? () :
    (Row(Alignment.Center, child_gap=2px, (effort_slot(r, effort, e) for effort in menu_efforts(p))...),)
  Row(width(grow=grow), Alignment.Center, padding(10px, 6px), child_gap=8px, radius(5px), name="Model row",
      background(ishovered(r) || r.menu.over == r.index ? on_glass(0.1) : clear),
    Column(width(grow=grow), Alignment.Start,
      Row(height(19px), Alignment.Center, label(r.name, 13px, color=colours.ink)),
      about...),
    efforts...,
    Box(fixed(12px), height(12px), Alignment.Center, justify=Alignment.Center,
      (any(m -> x == m.id || x == m.is, r.models) ? (Icon("check", size=12px, color=colours.dim),) : ())...))
end

"The button of the row `r` for the effort `effort`, or room as wide as one when its model hasn't got that effort"
effort_slot(r::ModelMenuRow, effort, e) = begin
  k = findfirst(m -> (f = model_effort(m.name); f !== nothing && f[2] == effort), r.models)
  k === nothing ? Box(fixed(effort_wide(effort)), height(20px)) : effort_button(r, r.models[k], e)
end

"The button of the row `r` for the model `model`, one of its efforts"
effort_button(r::ModelMenuRow, model, e) = begin
  b = node!(() -> EffortButton(), e, (:effort_button, r.name, model.id))
  b.row, b.model, b.effort = r, model, model_effort(model.name)[2]
  b
end

# The effort that the agent works with is filled
describe(b::EffortButton) = begin
  p = b.row.menu.of
  x = pane_model(p, editor(p))
  on = x == b.model.id || x == b.model.is
  Box(height(20px), Alignment.Center, justify=Alignment.Center, padding(7px, 0px), radius(4px), name="Effort",
      background(on ? on_glass(0.2) : ishovered(b) ? on_glass(0.1) : clear),
    label(b.effort, 11.5px, color=on ? colours.ink : colours.dim))
end

cursor(::EffortButton) = :hand
onkey(b::EffortButton, ev::KeyPress{Keys.mouse_left}) = (close_popup!(ev.window, MODEL_MENU); pane_model!(b.row.menu.of, b.model.id); handled)

cursor(::ModelMenuRow) = :hand
onmouse(r::ModelMenuRow, ::MouseMove) = (r.menu.over = r.index; nothing)
onkey(r::ModelMenuRow, ev::KeyPress{Keys.mouse_left}) = (close_popup!(ev.window, MODEL_MENU); pane_model!(r.menu.of, r.model.id); handled)
# The arrows move over the rows, and Return chooses the row that they're on
onkey(m::ModelMenu, ::KeyPress{Keys.down}) = (n = length(menu_rows(m.of)); m.over = n == 0 ? 0 : mod1(m.over + 1, n); redraw_in!(editor(m.of), SOON); handled)
onkey(m::ModelMenu, ::KeyPress{Keys.up}) = (n = length(menu_rows(m.of)); m.over = n == 0 ? 0 : mod1(m.over - 1, n); redraw_in!(editor(m.of), SOON); handled)
onkey(m::ModelMenu, ev::KeyPress{Keys.enter}) = begin
  p = m.of
  rows = menu_rows(p)
  m.over in eachindex(rows) || return handled
  close_popup!(ev.window, MODEL_MENU)
  e = editor(p)
  pane_model!(p, row_choice(pane_agent(p, e), rows[m.over].second, pane_model(p, e)).id)
  handled
end

"The text of the page `b` from the place `lo` to the place `hi`, each a line and how many characters are before it in the line"
text_between(b::Buffer, lo, hi) =
  lo[1] == hi[1] ? String(first(chop(b.lines[lo[1]], head=lo[2], tail=0), hi[2] - lo[2])) :
    join([String(chop(b.lines[lo[1]], head=lo[2], tail=0)); b.lines[lo[1]+1:hi[1]-1]; String(first(b.lines[hi[1]], hi[2]))], "\n")

const MOST_PICKED = 6000   # characters. A longer selection goes to the agent as its range only.

"""
What the window of `e` shows, for the agent: a few words for you, like the
heading that the caret is under, and the block that says it to the agent,
between `<ladder>` tags. The block has the section at the top of the window,
which the outline marks, the caret's line and column, and says whether text
is selected. The page that an HTML file makes has no lines: see `html_picked`. A selection has where it starts and ends,
and its exact text between `<selection>` tags, with nothing put before its
lines. So no text of the page can look like the block's end, but text that
holds the closing tag itself, which goes as its range only.
"""
page_context(e) = begin
  b = e.buf
  isempty(b.path) && return ("", "")
  path = isremote(b.path) ? b.path : truepath(b.path)
  # Ladder saves the page before each message. A page that it couldn't save still has changes that the file lacks.
  shows = "The window shows the file $path." * (dirty(b) ? " The window has changes that aren't in the file yet." : "")
  part = section_in_view(e)
  seen = part === nothing ? "" : "\nThe section in view is \"$(part.title)\"."
  if html_shown(e)
    picked, some = html_picked(e)
    return ((part === nothing ? name(b) : part.title) * some, "<ladder>\n$shows$seen\n$picked\n</ladder>")
  end
  if !(b.view in (:markdown, :code))
    # A thing that isn't text says what it shows now: see "the code that an agent runs"
    now = Offer.status(agent_shown(e))
    return (part === nothing ? name(b) : part.title, "<ladder>\n$shows$seen$(isempty(now) ? "" : "\n" * now)\n</ladder>")
  end
  n = b.caret[1]
  heads = filter(x -> x.level <= 6 && x.line <= n, page_outline(e))
  under = isempty(heads) ? "" : last(heads).title
  lo, hi = selection(b)
  # A column is counted from 1, as editors count it: the caret is before the character of that column
  picked = if lo == hi
    "Nothing is selected."
  else
    words = text_between(b, lo, hi)
    range = "The selection goes from line $(lo[1]), column $(lo[2] + 1) to line $(hi[1]), column $(hi[2] + 1)."
    length(words) > MOST_PICKED ? "$range It's $(length(words)) characters long, so read it in the file." :
      occursin("</selection>", words) ? "$range Read its text in the file." :
      "$range Its exact text:\n<selection>\n$words\n</selection>"
  end
  caret = "The caret is on line $n, column $(b.caret[2] + 1)" * (isempty(under) ? "" : ", under the heading \"$under\"") * "."
  told = "<ladder>\n$shows$seen\n$caret\n$picked\n</ladder>"
  # The few words for you say that a selection goes too
  some = lo == hi ? "" : lo[1] == hi[1] ? " · selection" : " · $(hi[1] - lo[1] + 1) lines selected"
  ((isempty(under) ? name(b) : under) * some, told)
end

const MOST_PARAGRAPH = 2000   # characters. A longer paragraph doesn't go to the agent with the selection or the caret in it.

"""
What the agent is told of the page that the HTML file of the window of `e`
makes: the lines for the `<ladder>` block about what's selected in it, or
about where you last clicked in it, and a few words for you. A selection
goes with the paragraph that holds it, as the page shows its words. A click
puts the caret, which the page doesn't draw: it goes as the words before
it, with its paragraph. Each goes with its line and column in the file, when
Ladder can tell where the page's words are in the HTML: see web/source.jl.
They're kept until the selection, the page or the file changes, since the
send button asks for them in each frame that the mouse is on it.
"""
html_picked(e) = begin
  v = html_part(e)
  b = html_browser(v)
  key = (b.picked, b.clicks[2], v.path, mtime(v.path))
  kept = get(e.nodes, :html_picked, nothing)
  kept !== nothing && kept[1] === b.view.page && kept[2] == key && return kept[3]
  told = html_told(e, v, b)
  e.nodes[:html_picked] = (b.view.page, key, told)
  told
end

"The text of the HTML file at `path`, and the letters of it that its page can show, kept until the file changes"
html_letters(e, path) = begin
  at = mtime(path)
  kept = get(e.nodes, :html_letters, nothing)
  kept !== nothing && kept[1] == (path, at) && return kept[2]
  html = isfile(path) ? read(path, String) : ""
  got = (html=html, seen=Sources.seen(html))
  e.nodes[:html_letters] = ((path, at), got)
  got
end

"The letters of the page that the Browser `b` shows, kept until it lays the page out again"
page_letters(e, b) = begin
  p = b.view.page
  kept = get(e.nodes, :page_letters, nothing)
  kept !== nothing && kept[1] === p && return kept[2]
  got = Sources.shown(Browsers.page_words(b))
  e.nodes[:page_letters] = (p, got)
  got
end

"What `html_picked` tells the agent of the page that the HTMLPage `v` shows with the Browser `b`"
html_told(e, v, b) = begin
  S = Browsers.Select
  ws = Browsers.page_words(b)
  lo, hi = Browsers.selection(b)
  # The line and the column of the file that the first letter at a place of the page is from, and that the last letter before it ends at
  src, page = html_letters(e, v.path), page_letters(e, b)
  spot(i) = i === nothing ? nothing : Sources.line_column(src.html, i)
  starts(place) = spot(Sources.start(src.seen, page, place))
  ends(place) = spot(Sources.finish(src.seen, page, place))
  # The paragraph that holds the start, which goes when it holds the end too
  from, to = S.paragraph(ws, lo)
  para = hi <= to ? S.copied(ws, from, to) : ""
  (length(para) > MOST_PARAGRAPH || occursin("</paragraph>", para)) && (para = "")
  inside = isempty(para) ? "." : " in this paragraph:\n<paragraph>\n$para\n</paragraph>"
  if lo < hi
    words = S.copied(ws, lo, hi)
    a, z = starts(lo), ends(hi)
    range = a === nothing || z === nothing ? "" : "In the file, the selection goes from line $(a[1]), column $(a[2]) to line $(z[1]), column $(z[2]). "
    told = length(words) > MOST_PICKED || occursin("</selection>", words) ?
      "$(range)Text is selected. It's $(length(words)) characters long, from \"$(first(words, 60))\" to \"$(last(words, 60))\"." :
      "$(isempty(range) ? "The selection's" : range * "Its") exact text, as the page shows it:\n<selection>\n$words\n</selection>"
    # A whole paragraph that's selected has nothing round it
    isempty(para) || (from, to) == (lo, hi) || (told *= "\nIt's" * inside)
    (told, " · selection")
  elseif b.clicks[2] == lo
    before = S.copied(ws, from, lo)
    # The last few words before the caret, which are enough to find it
    near = length(before) <= 40 ? before : (t = last(before, 40); i = findfirst(' ', t); i === nothing ? t : t[nextind(t, i):end])
    near = strip(near)
    c = starts(lo)
    file = c === nothing ? "" : ", at line $(c[1]), column $(c[2]) of the file"
    at = isempty(near) ? (isempty(para) ? "." : ", at the start of this paragraph:\n<paragraph>\n$para\n</paragraph>") : ", after \"$near\"" * inside
    ("The caret is where the user last clicked$file$at\nNothing is selected.", "")
  else
    ("Nothing is selected.", "")
  end
end

"""
The outline of what the page of `e` shows, or nothing when what it shows has
none: see `page_outline(e, o)`. The page asks the object of its file or
folder while it shows one, and else its text. Agent mode shows the outline at
the right only for a page that has one.
"""
page_outline(e) = (o = page_object(e); page_outline(e, o === nothing ? e.buf : o))

"A file or a folder has no outline, unless its kind has a method of `page_outline` that gives one"
page_outline(e, o) = nothing

"""
The outline of the page's text: its headings and its components, or the
places of a file of code. Text at a lower level, like its bytes, has none.
It's kept until the text changes.
"""
page_outline(e, b::Buffer) = begin
  b.view in (:markdown, :code) || return nothing
  kept = get(e.nodes, :pane_outline, nothing)
  kept !== nothing && kept[1] === b && kept[2] == b.version && return kept[3]::Vector{Entry}
  found = b.view == :markdown ? outline(b) :
          [Entry(h.line, h.what == "section" ? 1 : 2, h.words, h.what == "section" ? "text-left" : "braces", h.line) for h in code_places(e)]
  e.nodes[:pane_outline] = (b, b.version, found)
  found
end

"An HTML file, as the page that its HTML makes"
const HTMLFile = Union{FS.File{:html},FS.File{:htm},FS.File{:HTML},FS.File{:HTM}}

"The outline of an HTML file at its highest level: the headings of the page that its HTML makes"
page_outline(e, ::HTMLFile) = html_shown(e) ? html_outline(e)[1] : nothing

"""
The headings of the page that the HTML file of the window of `e` makes, as
the outline lists them, and how far down the page the top of each one is,
in px. That page has no lines, so a heading's `line` is its place in the
list. They're kept until the page is laid out again.
"""
html_outline(e) = begin
  b = html_browser(html_part(e))
  p = b.view.page
  kept = get(e.nodes, :html_outline, nothing)
  kept !== nothing && kept[1] === p && return (kept[2], kept[3])
  heads = Browsers.headings(b)
  found = Entry[Entry(i, h.level, h.words, "type-h$(h.level)", i) for (i, h) in enumerate(heads)]
  tops = Float64[h.top for h in heads]
  e.nodes[:html_outline] = (p, found, tops)
  (found, tops)
end

"""
Give the agent the words that you typed in the pane `p`. The page is saved
first, so that the agent reads what the window shows. The session starts
with the first words.
"""
send_words!(p::AgentPane) = begin
  e = editor(p)
  words = String(strip(join(p.field.buf.lines, "\n")))
  pictures = filter(isfile, attached(p))
  edited = p.session === nothing ? AgentReply[] : changed_replies(p.session)
  isempty(words) && isempty(pictures) && isempty(edited) && return nothing
  # A command that Ladder does itself, like /resume, doesn't go to the agent
  named = slash_named(words)
  named !== nothing && own_command(p, named[1]) !== nothing && return (run_own!(p, named...); nothing)
  b = e.buf
  s = try
    writes(b) && (dirty(b) || !isfile(b.path)) && save!(b)
    session!(p, e)
  catch err
    p.error = err isa ErrorException ? err.msg : sprint(showerror, err)
    redraw_in!(e, SOON)
    return nothing
  end
  p.error = ""
  if goes_bare(s, words)
    # A command of the agent's goes as you typed it, with nothing before it, as the agent reads a command only at the start of a message
    say!(s, words; bare=true)
  else
    about, told = pane_context(p, e)
    changes = changes_told(s)
    guide = on_page(p) ? "" : guide_once!(s, e)
    say!(s, words, about, join(filter(!isempty, [guide, told, changes]), "\n\n"); pictures=pictures, changed=length(edited))
    # The agent knows what each reply says now
    foreach(it -> it isa AgentReply && (it.saw = nothing), s.items)
  end
  p.follow = true
  # A new field takes the keyboard, when the old one had it
  w = window_of(e)
  typing = w !== nothing && w.focus === p.field
  pane_field!(p)
  typing && focus(p.field)
  redraw_in!(e, SOON)
  nothing
end

# --- the list of commands over the field ---

const SLASH_MENU = :slash_menu
const SLASH_MOST = 8        # how many rows of the list show at once. The arrows bring the others.
const SLASH_ROW = 34px      # how tall a row of the list is
const SLASH_CROWN = 12.0    # how round the list's top corners are
const SLASH_INSET = 4px     # the room between the list's outline and its rows

"""
The list over the field of the pane `of`, while its words start with a
slash. `rows` are what it lists now, each a kind and a thing: a command, an
earlier session, a model, or a line of words. `over` is the row that the
arrows or the mouse are on, and `top` the first row that shows. `typed` is
the text that `over` was last set for.
"""
@def mutable struct SlashMenu <: SemanticUI
  of::Any = nothing
  rows::Vector{Any} = Any[]
  over::Int = 1
  top::Int = 1
  typed::String = ""
  open::Bool = false
  woke::Bool = false
  mode::Symbol = :none
end

"A row of the list of commands: the one that shows in place `slot`, from the top"
@def mutable struct SlashRow <: SemanticUI
  menu::Any = nothing
  slot::Int = 1
end

"""
What draws the list of commands of `menu` as one shape with the slot under
it, as the command palette's list is one shape with its bar: the list's sides
come down and flare out onto the slot's top line, and the slot's line goes
between them. `fill` and `line` are the slot's colours, and `shade` the
colour of the list's shadow. It's one pixel at the list's corner, so it takes
no clicks, and it draws where the list's popup is.
"""
@def mutable struct SlashLens <: SemanticUI
  menu::Any = nothing
  fill::Any = clear
  line::Any = clear
  shade::Any = clear
end

"The list of commands of the pane `p`"
slash_menu(p::AgentPane) = get!(() -> SlashMenu(of=p), p.parts, :slash_menu)

"""
How wide the list of commands is over a slot whose place is `r`: narrower
than the slot by a tenth of it at each side, as the command palette's list is
over its bar. Each end leaves room for the slot's round end and the foot that
flares out onto the slot.
"""
slash_wide(r) = begin
  w, ends = num(r.width), num(r.from.radius.tl)
  inset = max(48.0, round(w * 0.1))
  px(max(0.0, min(max(320.0, w - 2inset), w - 2(ends + OMNI_FOOT))))
end

"The name after the slash that `text` starts with, and what comes after the space behind it, or nothing while no space is typed yet"
slash_parts(text::AbstractString) = begin
  m = match(r"^/(\S*)(\s(.*))?$"s, text)
  (String(m[1]), m[2] === nothing ? nothing : String(strip(m[3])))
end

"True when `words`, in small letters, hold each word of `asked`"
holds_words(words::AbstractString, asked::AbstractString) = (w = lowercase(words); all(x -> occursin(x, w), split(lowercase(asked))))

"""
What the list over the field of the pane `p` holds for `text`, the words in
the field: the commands whose names start with what's typed, and then those
that have it. After `/resume` and a space it's the earlier sessions, and
after `/model` and a space the models, each time those that have the words
typed after it. Nothing shows for words that don't start with a slash.
"""
slash_rows(p::AgentPane, text::AbstractString) = begin
  rows = Any[]
  (startswith(text, "/") && !occursin('\n', text)) || return rows
  e = editor(p)
  s = p.session
  name, rest = slash_parts(text)
  if rest === nothing
    q = lowercase(name)
    all = slash_commands(p)
    append!(rows, ((:command, c) for c in all if startswith(lowercase(c.name), q)))
    append!(rows, ((:command, c) for c in all if !startswith(lowercase(c.name), q) && occursin(q, lowercase(c.name))))
  elseif name == "resume" && own_command(p, name) !== nothing
    who = pane_agent(p, e)
    if s === nothing || s.earlier === nothing
      push!(rows, (:note, "Looking for the earlier sessions of this folder…"))
    else
      append!(rows, ((:session, x) for x in s.earlier if holds_words(x.title, rest)))
      isempty(rows) && push!(rows, (:note, s.looking ? "Looking for the earlier sessions of this folder…" :
                                           isempty(s.earlier) ? "$who has no earlier session of this folder." : "No earlier session has those words in its title."))
    end
  elseif name == "model" && own_command(p, name) !== nothing
    append!(rows, ((:model, m) for m in agent_models(pane_agent(p, e)).listed if holds_words(m.name * " " * m.id, rest)))
    isempty(rows) && push!(rows, (:note, "No model has those words in its name."))
  else
    k = findfirst(c -> c.name == name, slash_commands(p))
    k === nothing || push!(rows, (:hint, slash_commands(p)[k]))
  end
  rows
end

"Put `text` in the field of the pane `p`, with the caret after it. The pictures that go with the words stay."
field!(p::AgentPane, text::AbstractString) = begin
  e = editor(p)
  w = window_of(e)
  was = p.field
  typing = w !== nothing && was !== nothing && w.focus === was
  pane_field!(p)
  if was !== nothing
    for key in (:pictures, :made_pictures)
      haskey(was.nodes, key) && (p.field.nodes[key] = was.nodes[key])
    end
  end
  b = p.field.buf
  b.lines = [String(text)]
  b.caret = b.anchor = (1, length(text))
  typing && focus(p.field)
  redraw_in!(e, SOON)
  p
end

"""
In each frame: show the list of commands over the field of the pane `p`
while the field has the keyboard and its words start with a slash, and take
it away when they don't. The first slash starts the agent's program, which
lists the agent's commands. `/resume` and a space looks for the earlier
sessions.
"""
slash_tick!(p::AgentPane, e) = begin
  w = window_of(e)
  (w === nothing || p.field === nothing) && return nothing
  menu = slash_menu(p)
  text = join(p.field.buf.lines, "\n")
  rows = w.focus === p.field ? slash_rows(p, text) : Any[]
  text == menu.typed || (menu.typed = text; menu.over = menu.top = 1)
  menu.rows = rows
  mode = isempty(rows) ? :none : first(first(rows)) == :note ? (startswith(text, "/resume") ? :session : :model) : first(first(rows))
  if mode != :none && !menu.woke
    menu.woke = true
    try session!(p, e) catch end   # an agent that isn't on this Mac has no commands of its own. Your words say so when you send them.
  end
  mode == :none && (menu.woke = false)
  mode == :session && menu.mode != :session && look_for_sessions!(p)
  menu.mode = mode
  k = menu.open ? findfirst(q -> q.key == SLASH_MENU && q.content === menu, popups(w)) : nothing
  r = rect(pane_slot(p))
  if isempty(rows) || r === nothing
    menu.open && (close_popup!(w, SLASH_MENU); menu.open = false)
  elseif k === nothing
    # It's beside the slot's place, not the slot: the words in the slot are a part of the pane, so a list beside the slot itself would count as hidden.
    # It stands on the slot's top line, so the two are one shape.
    popup!(w, menu, anchor=(r.left, r.top, r.width, r.height), placement=:top, gap=0px, width=slash_wide(r), key=SLASH_MENU, modal=false, theme=component_theme(e.zoom))
    menu.open = true
  else
    # The slot moves when the window's size changes, and when the field of a session's file slides down
    q = popups(w)[k]
    q.anchor, q.width = (r.left, r.top, r.width, r.height), slash_wide(r)
  end
  # The agent's program lists its commands a moment after it starts
  s = p.session
  mode == :command && s !== nothing && !s.turns && running(s) && !haskey(AGENT_COMMANDS, (s.agent, s.dir)) && (yield(); redraw_in!(e, 0.1))
  nothing
end

"Look for the earlier sessions of the folder of the pane `p`: Ladder reads Claude Code's, and asks an agent that speaks ACP for its own"
look_for_sessions!(p::AgentPane) = begin
  e = editor(p)
  s = try session!(p, e) catch; return nothing end
  s.turns && return nothing
  if speaks_acp(s)
    s.looking = true
    acp_list!(s)
  else
    s.earlier = claude_sessions(s)
  end
  nothing
end

"""
What a key does while the list of commands shows over the field of the pane
`p`. True when the key is done with. The arrows move over the rows. Tab
writes the row's command in the field, for you to add to. Return runs the
row: see `slash_pick!`.
"""
slash_key!(p::AgentPane, w, K) = begin
  (K in (Keys.down, Keys.up, Keys.tab, Keys.enter) && unmodified(w)) || return false
  rows = slash_rows(p, join(p.field.buf.lines, "\n"))
  isempty(rows) && return false
  menu = slash_menu(p)
  n = length(rows)
  over = clamp(menu.over, 1, n)
  if K == Keys.down || K == Keys.up
    menu.over = mod1(over + (K == Keys.down ? 1 : -1), n)
    redraw_in!(editor(p), SOON)
    return true
  end
  slash_pick!(p, rows[over]; fill=K == Keys.tab) || K == Keys.tab
end

"""
Take the row `row` of the list of commands of the pane `p`. A command of
Ladder's own runs, and one that needs a choice, like `/resume`, is written
in the field with a space, which lists what to choose from. A command of
the agent's goes to the agent as it is. With `fill`, as for Tab, a command
is written in the field, for you to add to. An earlier session is gone on with, and a model is
chosen. False for a row that's only words, which leaves the key to the field.
"""
slash_pick!(p::AgentPane, row; fill::Bool=false) = begin
  kind, x = row
  if kind == :command
    if fill || (x.own && x.name in ("resume", "model"))
      field!(p, "/$(x.name) ")
    elseif x.own
      run_own!(p, x.name, "")
    else
      field!(p, "/$(x.name)")
      send_words!(p)
    end
  elseif kind == :session
    resume_session!(p, x)
  elseif kind == :model
    field!(p, "")
    pane_model!(p, x.id)
  else
    return false
  end
  true
end

"""
Run the command of Ladder's own called `name` in the pane `p`, with `rest`
after it. `/new` and `/clear` end the session: agent mode's pane starts with
nothing, and a session's file gets a new file beside it. `/resume` and
`/model` take the first session or model that has the words after them, and
with no words they list what to choose from.
"""
run_own!(p::AgentPane, name::AbstractString, rest::AbstractString) = begin
  e = editor(p)
  if name in ("new", "clear")
    field!(p, "")
    on_page(p) ? new_agent_session!(e, dirname(p.file)) : new_session!(p)
  else
    rows = isempty(rest) ? Any[] : slash_rows(p, "/$name $rest")
    k = findfirst(r -> first(r) in (:session, :model), rows)
    k === nothing ? field!(p, isempty(rest) ? "/$name " : "/$name $rest") : slash_pick!(p, rows[k])
  end
  nothing
end

"""
Go on with the earlier session `x` in the pane `p`. What the pane showed
goes, and what was said in that session shows in its place. A session's
file then keeps that session. The agent must have done with what you said.
"""
resume_session!(p::AgentPane, x::EarlierSession) = begin
  e = editor(p)
  s = p.session
  s === nothing && return nothing
  if s.busy
    p.error = "Stop $(s.agent) before you go on with another session."
    redraw_in!(e, SOON)
    return nothing
  end
  p.error = ""
  field!(p, "")
  empty!(p.open)
  filter!(((k, _),) -> !(k isa Tuple && k[1] == :reply), p.parts)
  p.scroll.offset, p.follow = 0px, true
  resume!(s, x)
  try
    session!(p, e)
  catch err
    p.error = err isa ErrorException ? err.msg : sprint(showerror, err)
  end
  redraw_in!(e, SOON)
  nothing
end

# Agent mode's panes are dark, and a session's file has the page's colours
describe(m::SlashMenu) = with_pane_colours(!on_page(m.of)) do
  p = m.of
  e = editor(p)
  n = length(m.rows)
  m.over = clamp(m.over, 1, max(1, n))
  # The row that the arrows are on is always one of those that show
  m.top = clamp(m.top, max(1, m.over - SLASH_MOST + 1), m.over)
  m.top = clamp(m.top, 1, max(1, n - SLASH_MOST + 1))
  shown = min(SLASH_MOST, n - m.top + 1)
  more = n > SLASH_MOST ? (Row(width(grow=grow), height(20px), Alignment.Center, padding(10px, 0px), name="More rows",
                               Box(label("$(m.top)–$(m.top + shown - 1) of $n  ·  ↑↓ for the rest", 11px, color=colours.faint))),) : ()
  # The list has the slot's colours, as the slot's border lies on its background
  page = on_page(p)
  lens = get!(() -> own!(m, SlashLens(menu=m)), p.parts, :slash_lens)
  lens.fill, lens.line = solid_on_glass(e, 0.07; page), solid_on_glass(e, 0.07 + 0.93 * 0.1; page)
  lens.shade = RGBA(0, 0, 0, page ? 0.14 : 0.5)
  # A line under each row, as the command palette has, which starts and ends where the row's words do.
  # The row that the arrows are on has none at its top or foot, so its colour is whole.
  rows = Any[]
  for k in 1:shown
    push!(rows, get!(() -> own!(m, SlashRow(menu=m, slot=k)), p.parts, (:slash_row, k)))
    push!(rows, Row(width(grow=grow), height(1px), padding(10px, 0px),
                    Box(width(grow=grow), height(1px), background(m.over in (m.top + k - 1, m.top + k) ? clear : on_glass(0.06)))))
  end
  # The rows are a little inside the list's own outline, and stop a little over the slot's top line
  card = Column(width(grow=grow), Alignment.Start, radius(SLASH_CROWN * px - SLASH_INSET), clip=true, rows..., more...)
  Stack(width(grow=grow), Alignment.Start, name="Commands", lens, Box(width(grow=grow), padding(SLASH_INSET, SLASH_INSET, SLASH_INSET, SLASH_INSET), card))   # top, right, bottom, left
end

describe(::SlashLens) = Box(fixed(1px), height(1px))

draw(ctx, size, ui::ConcreteRect, lens::SlashLens) = begin
  m = lens.menu
  w = window_of(editor(m.of))
  w === nothing && return
  k = findfirst(q -> q.key == SLASH_MENU && q.content === m, popups(w))
  (k === nothing || popups(w)[k].scene === nothing) && return
  q = popups(w)[k]
  s, (x, y, wide, tall) = q.scene, num.(q.anchor)
  f = (x=num(s.left), y=num(s.top), w=num(s.width), h=num(s.height))
  # It's one shape with the slot while it stands on the slot's top line. Where the window has no room for that, it's a card of its own.
  outline, inside, closed = if abs(f.y + f.h - y) < 1
    lens_shapes((frame=f, target=(x=x, y=y, w=wide, h=tall), kind=:attach); q=SLASH_CROWN)
  else
    l, t, r, b, c, quarter = f.x + 0.5, f.y + 0.5, f.x + f.w - 0.5, f.y + f.h - 0.5, SLASH_CROWN, pi / 2
    ps = [omni_arc(l + c, t + c, c, 2quarter, 3quarter); omni_arc(r - c, t + c, c, 3quarter, 4quarter);
          omni_arc(r - c, b - c, c, 0.0, quarter); omni_arc(l + c, b - c, c, quarter, 2quarter)]
    (ps, ps, true)
  end
  # The list's shadow, which stops at the slot
  with_clip(ctx, px(f.x - 40), px(f.y - 40), px(f.w + 80), px(min(y, f.y + f.h) - f.y + 40)) do
    shade = ink(lens.shade)
    blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, 9f0, true)
    Skia.sk_paint_set_maskfilter(shade, blur)
    shape = path_through([(f.x, f.y + 4); (f.x + f.w, f.y + 4); (f.x + f.w, f.y + f.h + 4); (f.x, f.y + f.h + 4)], true)
    Skia.sk_canvas_draw_path(ctx, shape, shade)
    Skia.sk_path_delete(shape)
    Skia.sk_maskfilter_unref(blur)
    Skia.sk_paint_delete(shade)
  end
  paint = ink(lens.fill)
  shape = path_through(inside, true)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_path_delete(shape)
  Skia.sk_paint_delete(paint)
  trace(ctx, outline, lens.line, 1; closed)
end

"The row of the list that the row `r` shows now, a kind and a thing, with its place in the list, or nothing"
row_of(r::SlashRow) = (k = r.menu.top + r.slot - 1; k in eachindex(r.menu.rows) ? (k, r.menu.rows[k]) : nothing)

describe(r::SlashRow) = begin
  m = r.menu
  p = m.of
  e = editor(p)
  found = row_of(r)
  found === nothing && return Box(height(0px))
  k, (kind, x) = found
  rp = rect(pane_slot(p))
  room = (rp === nothing ? 300px : slash_wide(rp)) - 2SLASH_INSET - 20px   # less the list's own room and the row's
  face(colour, size=13px) = Face(SANS, "", size, colour, false)
  parts = if kind in (:command, :hint)
    name = "/" * x.name
    left = room - measure(face(colours.ink), name) - 10px
    hint = shortened(face(colours.faint, 12px), x.hint, max(0px, min(left, room * 0.4)))
    left -= isempty(hint) ? 0px : measure(face(colours.faint, 12px), hint) + 10px
    about = left > 40px ? shortened(face(colours.dim, 12px), x.about, left) : ""
    (Box(label(name, 13px, color=colours.ink)),
     (isempty(hint) ? () : (Box(label(hint, 12px, color=colours.faint)),))...,
     (isempty(about) ? () : (Box(label(about, 12px, color=colours.dim)),))...)
  elseif kind == :session
    ago = ago_words(x.at)
    left = room - measure(face(colours.faint, 12px), ago) - 20px   # the row's two gaps, before and after the room between
    (Box(label(shortened(face(colours.ink), x.title, left), 13px, color=colours.ink)), Box(width(grow=grow)),
     Box(label(ago, 12px, color=colours.faint)))
  elseif kind == :model
    now = pane_model(p, e)
    (Box(label(x.name, 13px, color=colours.ink)), Box(width(grow=grow)),
     (now == x.id || now == x.is ? (Icon("check", size=12px, color=colours.dim),) : ())...)
  else
    (Box(label(shortened(face(colours.dim), x, room), 13px, color=colours.dim)),)
  end
  picks = kind in (:command, :session, :model)
  # The top row's top corners follow the list's own, as far in as the rows are from the list's outline
  Row(width(grow=grow), height(SLASH_ROW), Alignment.Center, padding(10px, 0px), child_gap=10px, radius(r.slot == 1 ? SLASH_CROWN * px - SLASH_INSET : 6px, 6px),
      clip=true, name="Command row",
      background(picks && m.over == k ? on_glass(0.1) : clear), parts...)
end

cursor(r::SlashRow) = (found = row_of(r); found !== nothing && first(found[2]) in (:command, :session, :model) ? :hand : :arrow)
onmouse(r::SlashRow, ::MouseMove) = (found = row_of(r); found === nothing || r.menu.over == found[1] || (r.menu.over = found[1]; redraw_in!(editor(r.menu.of), SOON)); nothing)
# A click takes the row, as Return does, and the field keeps the keyboard
onkey(r::SlashRow, ev::KeyPress{Keys.mouse_left}) = begin
  p = r.menu.of
  found = row_of(r)
  found === nothing || slash_pick!(p, found[2])
  p.field === nothing || focus(p.field)
  handled
end

# --- pictures that go with your words ---

"The pictures that go with the words in the field of the pane `p`, as files. A new field starts with none."
attached(p::AgentPane) = get!(() -> String[], p.field.nodes, :pictures)

"A test puts a folder of its own here, for the pictures that agent mode keeps"
const AGENT_PICTURES = Ref("")

"""
The folder that keeps the pictures that you paste for the agent of the pane
`p`. A session's file has them in the media folder beside it, so the file
shows them again when it's opened. Agent mode has them in Ladder's caches,
since nothing keeps its session after the window closes.
"""
agent_pictures(p::AgentPane) = begin
  dir = on_page(p) && !isempty(p.file) ? joinpath(dirname(abspath(p.file)), PAGE_MEDIA) :
        isempty(AGENT_PICTURES[]) ? joinpath(homedir(), "Library", "Caches", "Ladder", "Agent pictures") : AGENT_PICTURES[]
  mkpath(dir)
  dir
end

"The files that Ladder wrote for the pictures in the field of the pane `p`, which go when a picture is taken away before it's sent"
made_pictures(p::AgentPane) = get!(() -> String[], p.field.nodes, :made_pictures)

"""
Put the picture at `path` with the words of the pane `p`. `made` is true for
a file that Ladder wrote for it. A picture in a folder of temporary files, like
a screenshot app's, is copied first, since macOS removes it later.
"""
attach!(p::AgentPane, path; made=false) = begin
  if any(t -> startswith(path, t), PASSING)
    path = cp(path, unused(agent_pictures(p), splitext(basename(path))...))
    made = true
  end
  made && push!(made_pictures(p), path)
  path in attached(p) || push!(attached(p), path)
  redraw_in!(editor(p), SOON)
  path
end

"Take the picture at `path` away from the words of the pane `p`. A file that Ladder wrote for it goes too."
unattach!(p::AgentPane, path) = begin
  filter!(!=(path), attached(p))
  path in made_pictures(p) && (filter!(!=(path), made_pictures(p)); rm(path, force=true))
  redraw_in!(editor(p), SOON)
  nothing
end

"""
Paste into the field `sub` of the pane `p`. A picture goes with your words,
whether it was copied as a file in the Finder or as itself, like a
screenshot. Another file goes in as its path, and anything else as text.
"""
paste_for_agent!(p::AgentPane, sub) = begin
  paths = Pasteboard.files()
  if isempty(paths)
    text = Sys.isapple() ? Pasteboard.text() : clipboard()
    # A picture that's copied from a web page comes with its address as text, and the picture is what's wanted
    found = isempty(strip(text)) || occursin(r"^\s*\w+://\S+\s*$", text) ? Pasteboard.media() : nothing
    if found !== nothing && ispicture("pasted." * found[1])
      path = unused(agent_pictures(p), "pasted-" * Libc.strftime("%Y%m%d-%H%M%S", time()), "." * found[1])
      write(path, found[2])
      return attach!(p, path; made=true)
    end
    return each_selection!(() -> type!(sub, replace(text, "\r\n" => "\n", '\r' => '\n', '\t' => "  ")), sub)
  end
  give_files!(p, paths)
end

"Give the files and folders at `paths` to the agent of the pane `p` with your words: a picture goes with them, and anything else goes into them as its path"
give_files!(p::AgentPane, paths) = begin
  p.field === nothing && pane_field!(p)
  sub = p.field
  paths = [rstrip(String(path), '/') for path in paths if ispath(path)]
  pictures = [path for path in paths if isfile(path) && ispicture(path)]
  foreach(path -> attach!(p, path), pictures)
  others = [occursin(' ', path) ? "\"$path\"" : path for path in paths if !(path in pictures)]
  isempty(others) || each_selection!(() -> type!(sub, join(others, " ")), sub)
  nothing
end

"The agent's pane that the mouse is on in the window `w` of `e`, or nothing: agent mode's pane, or a session's file that the page shows"
agent_pane_at(e, w) = begin
  x, y = w.mouse
  for p in (chat_shown(e) ? chat_part(e) : nothing, agent_shows(e) ? agent_pane(e) : nothing)
    p === nothing && continue
    r = rect(p)
    r !== nothing && r.left <= x < r.left + r.width && r.top <= y < r.top + r.height && return p
  end
  nothing
end

"""
The key of a small picture of the file at `path`, with how wide and how tall
it shows: `tall` high and no more than three times as wide. The key is nothing
when macOS has no picture for the file, which then shows as a square.
"""
picture_size(path, tall) = begin
  key = isfile(path) ? thumbnail(path, 400) : nothing
  key === nothing && return (nothing, tall, tall)
  shape = image_aspect(key)
  wide, high = tall * shape > 3tall ? (3tall, 3tall / shape) : (tall * shape, tall)
  (key, px(round(num(wide))), px(round(num(high))))
end

"A small picture of the file at `path`, `tall` high, with its corners rounded: see `picture_size`"
small_picture(path, tall) = begin
  key, wide, high = picture_size(path, tall)
  key === nothing ? Box(fixed(wide), height(high), radius(8px), Alignment.Center, justify=Alignment.Center, background(on_glass(0.12)),
                        Icon("image", size=tall / 3, color=colours.faint)) :
                    Image(key, fixed(wide), height(high), radius(8px))
end

"The pictures that go with the words in the field of the pane `p`, in a row, each with a button in its corner that takes it away"
attached_row(p::AgentPane, e) = begin
  tall = PICTURE_TALL * talk_zoom(e)
  Row(height(tall), Alignment.End, child_gap=8px, name="Pictures",
    (begin
       _, wide, high = picture_size(path, tall)
       Stack(fixed(wide), height(high), Alignment.Start, name="Picture", small_picture(path, tall),
         Row(width(grow=grow), justify=Alignment.End, padding(4px), pane_button(p, :unattach, path)))
     end for path in attached(p))...)
end

# How tall a picture is in the field and in what you said, at the pane's own size
const PICTURE_TALL = 64px

"End the session of the pane `p`, and start with nothing. The next words start a new session."
new_session!(p::AgentPane) = begin
  p.session === nothing || close!(p.session)
  p.session = nothing
  p.error = ""
  empty!(p.open)
  filter!(((k, _),) -> !(k isa Tuple && k[1] == :reply), p.parts)
  p.scroll.offset, p.follow = 0px, true
  redraw_in!(editor(p), SOON)
  nothing
end

"End the session of the window of `e`: the window has closed"
close_agent!(e) = begin
  p = get(e.nodes, :agent_pane, nothing)
  p isa AgentPane && p.session !== nothing && close!(p.session)
  nothing
end

"""
Give the task that reads what the agent prints its turn, and draw the window
again when the session of the window of `e` has something new. While the
agent works, that's twenty times a second.
"""
session_tick!(e) = begin
  p = get(e.nodes, :agent_pane, nothing)
  p isa AgentPane && pane_tick!(p, e)
  nothing
end

"Give the task that reads what the agent of the pane `p` prints its turn, and draw the window of `e` again when its session has something new"
pane_tick!(p::AgentPane, e) = begin
  # The task that asks an agent for its models gets its turns too, till it's done
  isempty(MODELS_ASKING) || (yield(); redraw_in!(e, 0.1))
  slash_tick!(p, e)
  s = p.session
  s === nothing && return nothing
  if s.busy || s.loading || s.looking
    yield()
    redraw_in!(e, 0.05)
  end
  for (key, sub) in p.parts
    key isa Tuple && first(key) == :reply && reply_tick!(p, sub)
  end
  s.version == p.seen || (p.seen = s.version; redraw_in!(e, SOON))
  nothing
end

"""
What happens in each frame to the reply `sub` of the pane `p`, as to a page:
a number that you drag in it changes, its sums run again, and its blocks
write their lines. Once the agent has said the whole reply, what you changed
in it is the reply, so a session's file keeps it. The reply keeps what the
agent saw of it, for your next words to say what changed.
"""
reply_tick!(p::AgentPane, sub) = begin
  blocks_tick!(sub)
  scrub_tick!(sub)
  inline_tick!(sub)
  it, s = get(sub.nodes, :reply, nothing), p.session
  if it isa AgentReply && it.whole && s !== nothing && get(sub.nodes, :shown, -1) == it.n
    text = join(sub.buf.lines, "\n")
    if text != rstrip(it.text)
      it.saw === nothing && (it.saw = String(rstrip(it.text)))
      it.text = text
      s.version += 1
    end
  end
  sub
end

# --- what you change in a reply ---
#
# Once the agent has said all of a reply, the reply is a page that you can
# change: type in it, drag a number, choose an answer of an `ask` block, move
# its slider or pick its colour. The reply keeps what the agent last saw of
# it. Your next words to the agent start with what you changed in each reply
# since then, as a diff, between <changes> and </changes>. With nothing
# typed, the send button sends only the changes. So the agent can ask a
# question with a slider or a colour picker, and read your answer.

"True when you changed the reply `it` since the agent last saw it"
reply_changed(it::AgentReply) = it.saw !== nothing && it.saw != rstrip(it.text)

"The replies of the session `s` that you changed since the agent last saw them"
changed_replies(s::AgentSession) = AgentReply[it for it in s.items if it isa AgentReply && reply_changed(it)]

"""
What the agent of the session `s` is told of the replies that you changed:
for each, its place among the agent's replies, how it started, and a diff
from what the agent last saw to what it says now. "" when you changed none.
"""
changes_told(s::AgentSession) = begin
  replies = [it for it in s.items if it isa AgentReply]
  told = String[]
  for (k, it) in enumerate(replies)
    reply_changed(it) || continue
    was, now = split(it.saw, '\n'), split(rstrip(it.text), '\n')
    start = first(String(strip(first(was))), 80)
    push!(told, "Your reply $k of the $(length(replies)) in this session, which started \"$start\":\n" * rstrip(unified(was, now)))
  end
  isempty(told) ? "" : "<changes>\n" * join(told, "\n\n") * "\n</changes>"
end

"The tooltip of the send button of the pane `p`: it says what goes with your words"
send_tip(p::AgentPane) = begin
  more = String[]
  isempty(first(pane_context(p, editor(p)))) || push!(more, "context")
  p.session === nothing || isempty(changed_replies(p.session)) || push!(more, "your changes")
  (isempty(more) ? "Send" : "Send with " * join(more, " and ")) * "  ⏎"
end

"Keep the newest words of the pane `p` in sight, until you scroll up from them. Back at the end, it follows them again."
follow!(p::AgentPane) = begin
  sc = p.scroll
  bottom = max(0px, sc.content_height - sc.viewport)
  sc.offset < p.put - 2px && (p.follow = false)
  sc.offset >= bottom - 4px && (p.follow = true)
  p.follow && (sc.offset = bottom)
  p.put = sc.offset
  p
end

"The button of the pane `p` that does `action` to `what`. It's kept between frames."
pane_button(p::AgentPane, action::Symbol, what=nothing) =
  get!(() -> own!(p, PaneButton(of=p, action=action, what=what)), p.parts, (:button, action, what === nothing ? 0 : what isa Int ? what : objectid(what)))

"The face of the words of the agent's pane, in `colour`"
pane_face(e, colour=colours.ink; size=REPLY_SIZE) = Face(SANS, "", size * talk_zoom(e), colour, false)

describe(p::AgentPane) = on_page(p) ? talk_page(p) : with_pane_colours() do
  e = editor(p)
  p.field === nothing && pane_field!(p)
  follow!(p)
  room = agent_wide(e) - PANE_LEFT - PANE_X
  Column(width(grow=grow), height(grow=grow), Alignment.Start, name="Agent",
    PaneColours(on=true, across=true),
    Box(width(grow=grow), height(max(above_page(e), SIDE_GAP) - 1px)),   # under the top bar, which has the pane's heading: see `pane_head`
    reuse!(p.scroll, pane_talk(p, e, room)),
    pane_foot(p, e, room),
    PaneColours(on=false, across=true))
end

cursor(::AgentPane) = :arrow
# A click on the pane, where nothing else takes it, gives the keyboard to the words that you type
onkey(p::AgentPane, ::KeyPress{Keys.mouse_left}) = (p.field === nothing || focus(p.field); handled)

"""
The heading of the agent's pane: the agent's logo and name, which a click
opens into a menu of the agents, how its session goes, and the button
that starts a new session. It's in the top bar, over
the pane, between the window's own buttons and the two arrows, so the talk
has all of the pane's height. A name that's too long for a narrow pane is
cut off at the button.
"""
pane_head(p::AgentPane, e) = begin
  s = p.session
  goes = s === nothing ? "No session yet" : s.busy ? "Working" : !(s.turns || running(s)) ? "Stopped" : "In $(basename(s.dir))"
  (Row(width(grow=grow), height(grow=grow), Alignment.Center, padding(0px, 6px, 0px, 0px), child_gap=4px, clip=true, name="Agent head",
     pane_button(p, :agent),
     Box(label(goes, 12px, color=colours.dim))),
   (s === nothing ? () : (Box(fixed(30px), height(grow=grow), Alignment.Center, justify=Alignment.Center, pane_button(p, :new)),))...)
end

"What you and the agent said, from the first words to the newest, as wide as `room`"
pane_talk(p::AgentPane, e, room) = begin
  s = p.session
  items = s === nothing ? Any[] : s.items
  rows = Any[]
  k = 1
  while k <= length(items)
    it = items[k]
    if it isa AgentStep
      # More than three steps in a row show as one line, which a click opens, once the agent has gone on from them
      j = k
      while j < length(items) && items[j+1] isa AgentStep; j += 1 end
      if j - k >= 3 && !(k in p.open) && !(s.busy && j == length(items))
        push!(rows, pane_button(p, :steps, k))
        pane_button(p, :steps, k).what = (k, j - k + 1)
      else
        j - k >= 3 && (push!(rows, pane_button(p, :steps, k)); pane_button(p, :steps, k).what = (k, 0))
        append!(rows, (step_row(e, items[i], room) for i in k:j))
      end
      k = j + 1
      continue
    end
    push!(rows, talk_row(p, e, it, room))
    k += 1
  end
  # While the agent thinks, with nothing of its own under way to show it
  waits = s !== nothing && s.busy && (isempty(items) || !(last(items) isa AgentStep && last(items).state == :going) &&
                                                         !(last(items) isa AgentReply && !last(items).whole) &&
                                                         !(last(items) isa AgentWants && last(items).answer == :none))
  loads = s !== nothing && s.loading
  (waits || loads) && push!(rows, Row(height(24px), Alignment.Center, child_gap=8px,
                           Box(fixed(16px), height(16px), Alignment.Center, justify=Alignment.Center, Spinner(size=12px)),
                           Box(label(loads ? "Opening the session" : "Thinking", 13px * talk_zoom(e), color=colours.dim))))
  isempty(p.error) || push!(rows, words_block(e, p.error, PICK_FAILED, room))
  isempty(rows) && return Column(width(grow=grow), Alignment.Start, padding(40px, PANE_X, 20px, PANE_LEFT), child_gap=6px, name="Talk",
    words_block(e, "Ask about this page, or say what to change in it.", colours.dim, room),
    words_block(e, "What the agent says shows here as a page: tables, diagrams and charts, not a terminal's text.", colours.faint, room),
    words_block(e, "Type / for commands, like /resume to go on with an earlier session.", colours.faint, room))
  Column(width(grow=grow), Alignment.Start, padding(on_page(p) ? 24px : 6px, PANE_X, 20px, PANE_LEFT), child_gap=10px, name="Talk", rows...)
end

"The words `words` in `colour`, wrapped to `room`, each line of them in turn"
words_block(e, words, colour, room; size=13px) = begin
  face = pane_face(e, colour; size)
  Column(Alignment.Start, [Row(height(face.size * 1.45), Alignment.Center, label(l, face.size, color=colour))
                           for para in split(words, '\n') for l in wrapped(face, para, num(room))]...)
end

"Your words to the agent, at the right of the pane on a shape of their own, under what the window showed then"
talk_row(p::AgentPane, e, it::YouSaid, room) = begin
  inside = min(room * 0.86, 520px) - 26px
  about = isempty(it.about) ? () :
    (Row(height(18px), Alignment.Center, child_gap=5px, Icon("file-earmark-text", size=11px, color=colours.faint),
         Box(label(shortened(pane_face(e, colours.faint; size=11.5px), it.about, inside), 11.5px * talk_zoom(e), color=colours.faint))),)
  pictures = isempty(it.pictures) ? () :
    (Row(Alignment.End, child_gap=8px, padding(2px, 0px, 2px, 0px), name="Your pictures", (small_picture(path, PICTURE_TALL * talk_zoom(e)) for path in it.pictures)...),)
  words = isempty(it.words) ? () : (Box(padding(13px, 8px), radius(12px), background(on_glass(0.09)), words_block(e, it.words, colours.ink, inside; size=REPLY_SIZE)),)
  changes = it.changed == 0 ? () :
    (Row(height(18px), Alignment.Center, child_gap=5px, name="Your changes", Icon("pencil", size=11px, color=colours.faint),
         Box(label("Your changes to $(it.changed == 1 ? "a reply" : "$(it.changed) replies")", 11.5px * talk_zoom(e), color=colours.faint))),)
  Column(width(grow=grow), Alignment.End, child_gap=3px, padding(6px, 0px, 2px, 0px), name="You said",
    about..., changes..., pictures..., words...)
end

"What the agent said, as a page of Ladder's as wide as `room`"
talk_row(p::AgentPane, e, it::AgentReply, room) = begin
  sub = get!(() -> reply_editor(p, e, p.session.dir), p.parts, (:reply, objectid(it)))
  show_reply!(sub, it)
  # It shows a caret only while it has the keyboard, as a part of another page does
  w = window_of(e)
  (w !== nothing && w.focus === sub) || (sub.buf.reading = true)
  pane_style!(sub, e; own=talk_on_page[])
  pane_layout!(sub, room)
  tall = isempty(sub.layout) ? 0px : lowest(sub, sub.layout)
  Box(width(grow=grow), height(tall), Alignment.Start, name="Reply", node!(Document, sub, :document))
end

"""
The line of code `line` broken into lines no wider than `room` in `face`, with
each of its characters, spaces too. A line breaks after its last space that
fits, or between two characters when no space fits. A line that a break makes
starts at the indent of `line`, when the indent takes half of `room` or less.
"""
code_wrapped(line::AbstractString, face::Face, room) = begin
  chars = collect(replace(line, '\t' => "    "))
  sizes = Dict{Char,Any}()
  wide(c) = get!(() -> measure(face, string(c)), sizes, c)
  lead = something(findfirst(!isspace, chars), 1) - 1
  pad = sum(wide, chars[1:lead], init=0px) <= room / 2 ? String(chars[1:lead]) : ""
  out = String[]
  # Where this line starts in `chars`, how wide it is so far, its last space after a word, and whether a word has started in it
  from, x, gap, word = 1, 0px, 0, false
  for (i, c) in pairs(chars)
    if i > from && x + wide(c) > room
      cut = gap > 0 ? gap : i - 1
      push!(out, (isempty(out) ? "" : pad) * String(chars[from:cut]))
      from, gap, word = cut + 1, 0, cut < i - 1   # after the last space, the rest of a word goes on to the new line
      x = sum(wide, pad, init=0px) + sum(wide, chars[from:i-1], init=0px)
    end
    x += wide(c)
    c == ' ' && word && (gap = i)
    isspace(c) || (word = true)
  end
  push!(out, (isempty(out) ? "" : pad) * String(chars[from:end]))
end

"Something that the agent asks to do, with the buttons that allow it and refuse it, and then what you answered"
talk_row(p::AgentPane, e, it::AgentWants, room) = begin
  inside = room - 26px
  ends = it.answer == :none ? Row(Alignment.Center, child_gap=8px, pane_button(p, :allow, it), pane_button(p, :refuse, it)) :
    Box(label(it.answer == :allowed ? "You allowed it." : it.answer == :refused ? "You refused it." : "It wasn't answered.", 12px * talk_zoom(e), color=colours.dim))
  # The command or code wraps onto more lines, so each of its characters shows
  size = 12px * talk_zoom(e)
  face = Face(codefont(), codestyle(), size, colours.ink, false)
  lines = isempty(it.detail) ? String[] : [l for line in first(split(it.detail, '\n'), 6) for l in code_wrapped(line, face, inside - 16px)]
  detail = isempty(lines) ? () :
    (Box(width(grow=grow), padding(8px, 6px), radius(6px), Alignment.Start, background(on_glass(0.06)), clip=true, name="Agent asks to run",
       Column(Alignment.Start, [Row(height(17px * talk_zoom(e)), Alignment.Center, Text(l, size=size, family=codefont(), subfamily=codestyle(), color=colours.ink, wrap=WrapMode.none))
                                for l in lines]...)),)
  Column(width(grow=grow), Alignment.Start, padding(13px, 11px), radius(10px), child_gap=9px, name="Agent asks",
         background(on_glass(0.05)), border(1px, :solid, on_glass(0.14)),
    words_block(e, "$(p.session.agent) asks to do this: $(it.words)", colours.ink, inside),
    detail..., ends)
end

"A line that the session says of itself"
talk_row(p::AgentPane, e, it::SessionNote, room) = words_block(e, it.words, it.bad ? PICK_FAILED : colours.dim, room; size=12.5px)

"A step of the agent as a line: a ring that turns while it's under way, and then the icon of its tool"
step_row(e, it::AgentStep, room) = begin
  mark = it.state == :going ? Spinner(size=12px) :
         it.state == :failed ? Icon("exclamation-triangle", size=13px, color=PICK_FAILED) : Icon(tool_icon(it.tool), size=13px, color=colours.faint)
  face = pane_face(e, colours.dim; size=13px)
  Row(width(grow=grow), height(22px), Alignment.Center, child_gap=8px, name="Step",
    Box(fixed(16px), height(16px), Alignment.Center, justify=Alignment.Center, mark),
    Box(label(shortened(face, it.words, room - 26px), face.size, color=colours.dim)))
end

"""
The foot of the agent's pane: the field that you type in, with the button
that sends or stops at its right. With one line of words it's one line
tall. The words wrap before the button, which stays at the last line. While
the mouse is over the field, the model's button shows beside it, and the last
line of words ends before that too.
"""
pane_foot(p::AgentPane, e, room) = begin
  s = p.session
  sub = p.field
  pane_style!(sub, e)
  line = REPLY_SIZE * talk_zoom(e) * 1.5
  slot = on_page(p)
  # The field is a slot: with one line of words its ends are half circles, and more lines keep ends as round.
  # Its button has the same middle as the round end at the foot, which is the middle of the last line.
  sides(one) = begin
    ends = (max(one + 8px, 28px) + 14px) / 2   # one line of words, the room over and under it, and the border
    (ends, max(6px, ends - 15px), max(14px, ends - 5px))   # the ends, and the room at the right and the left of the words
  end
  # The words are as wide as the slot leaves them: less the room at each side of the slot, its border, its ends, the send
  # button and the gap before it. The model's button lies over the end of the last line of words. It's a whole number of
  # pixels, as a box a hair narrower than its words would grow the pane by that hair.
  room_for(one) = begin
    _, right, left = sides(one)
    max(40px, px(floor(num(pane_wide(p, e) - 2(PANE_X - 4px) - 2px - left - right - SEND_ROOM))))
  end
  # While the model's button shows, the words flow round it: the last line ends before it, and its last words go onto
  # a new line when they'd reach it. The room stays while the mouse is on the send button, whose pill then covers it.
  model_room = model_shows(p, e) ? model_wide(p, e) + MODEL_GAP : 0px
  end_room(sub) == model_room || (sub.nodes[:end_room] = model_room)
  # The ends come from the first line as it was last laid out. When it's laid out at another height, the words go again.
  pane_layout!(sub, room_for(one_line(sub, line)))
  one = one_line(sub, line)
  inside = room_for(one)
  sub.width == inside || pane_layout!(sub, inside)
  tall = min(isempty(sub.layout) ? line : lowest(sub, sub.layout), 9line)
  ends, right, left = sides(one)
  drop = max(0px, ends - 21px)   # 21px: the button's half, the room under the words, and the border
  # Pictures that go with the words are over them, in the slot
  pictures = isempty(attached(p)) ? () : (Box(width(grow=grow), height(PICTURE_TALL * talk_zoom(e) + 8px), Alignment.Start, padding(4px, 4px, 4px, 0px), attached_row(p, e)),)   # top, right, bottom, left
  above = isempty(pictures) ? 0px : PICTURE_TALL * talk_zoom(e) + 8px
  # The button's box is as tall as the words' box. A Row leaves a child where it is when the alignment would move it 1.5px or less.
  over = max(above + tall + 8px, 28px + drop) - 28px - drop
  doc = Box(width(grow=grow), height(tall), Alignment.Start, clip=true, name="Typed words", node!(Document, sub, :document))
  who = pane_agent(p, e)
  # The model's button shows only while the mouse is over the slot, or while its menu is open.
  # While the mouse is on the send button, that opens over where the model's button would be.
  shows = model_shows(p, e) && !ishovered(pane_button(p, :send))
  # What the slot leaves for its words: less its ends, the send button and the gap before it, and the room at each side of the words.
  # While the model's button shows, the words of the hint stop before it.
  words_room = pane_wide(p, e) - 2(PANE_X - 4px) - left - right - (SEND_ROOM - 28px) - 28px - 8px - (shows ? model_wide(p, e) + SEND_ROOM - 28px : 0px)
  empty = sub.buf.lines == [""]
  text = empty ? Stack(width(grow=grow), height(tall), Alignment.Start,
                       Row(width(grow=grow), height(tall), Alignment.Center,
                           label(shortened(pane_face(e, colours.faint), slot ? "Ask $who, or say what to do" : "Ask $who, or say what to change", words_room - 2px), REPLY_SIZE * talk_zoom(e), color=colours.faint)), doc) : doc
  # The words, with room at their right for the send button
  words = Row(width(grow=grow), Alignment.End, child_gap=SEND_ROOM - 28px,
    Column(width(grow=grow), Alignment.Start, pictures..., Box(width(grow=grow), padding(0px, 4px), text)),   # one line of words is as tall as the button, or taller
    Box(fixed(28px), height(over + 28px + drop)))
  # The buttons are over the words, at their right end. The last line of words ends before the model's button, and the send button opens over it.
  buttons = Row(width(grow=grow), Alignment.Start, justify=Alignment.End, child_gap=SEND_ROOM - 28px,
    (shows ? (Box(padding(over, 0px, drop, 0px), pane_button(p, :model)),) : ())...,
    Box(padding(over, 0px, drop, 0px), pane_button(p, s !== nothing && s.busy && empty ? :stop : :send)))
  holder = pane_slot(p)
  holder.inside = Row(width(grow=grow), padding(6px, right, 6px, left), radius(ends),   # top, right, bottom, left
                      background(on_glass(0.07)), border(1px, :solid, on_glass(0.1)),
                    Stack(width(grow=grow), Alignment.Start, words, buttons))
  Box(width(grow=grow), padding(4px, PANE_X - 4px, slot ? 18px : PANE_X - 4px, PANE_X - 4px), name="Agent foot", holder)
end

"The slot of the pane `p`, kept between frames: see `PaneSlot`"
pane_slot(p::AgentPane) = get!(() -> own!(p, PaneSlot(of=p)), p.parts, :slot)

"""
True while the model's button of the pane `p` shows: while the mouse is over
the slot that you type in, as it was last drawn, and while the button's menu
is open.
"""
model_shows(p::AgentPane, e) = begin
  w = window_of(e)
  w === nothing && return false
  any(q -> q.key == MODEL_MENU, popups(w)) && return true
  r = rect(pane_slot(p))
  r === nothing && return false
  x, y = w.mouse
  r.left <= x < r.left + r.width && r.top <= y < r.top + r.height
end

"""
The model of the agent of the pane `p`, as Ladder knows it: the one that the
agent says it works with, else the one that you chose, else the agent's own
choice. It's a name that the agent's command is given or the model's full
name, or "" when Ladder doesn't know the agent's own choice.
"""
pane_model(p::AgentPane, e) = begin
  s, agent = p.session, pane_agent(p, e)
  s !== nothing && !isempty(s.running) && return s.running
  chosen = s === nothing ? chosen_model(agent) : s.model
  isempty(chosen) ? agent_models(agent).default : chosen
end

"The words on the model's button of the pane `p`: the model's name, or Default when Ladder doesn't know which model the agent chooses"
model_words(p::AgentPane, e) = (x = pane_model(p, e); isempty(x) ? "Default" : model_name(pane_agent(p, e), x))

"The face of the words on the model's button"
model_face(e, colour=colours.dim) = pane_face(e, colour; size=12.5px)

"How wide the model's button of the pane `p` is: its words, the chevron and the room round them"
model_wide(p::AgentPane, e) = px(ceil(num(measure(model_face(e), model_words(p, e)) + MODEL_BUTTON_ROOM)))

const MODEL_BUTTON_ROOM = 33px   # the room on the model's button that's not its words: 10px at each end, the chevron and the gap before it
const MODEL_GAP = 6px            # the least room between the words and the model's button, while the button shows

"How tall one line of the words in `sub` is, as it lays them out: as tall as its first line. Before it lays them out, `line`."
one_line(sub, line) = begin
  isempty(sub.layout) && return line
  it = sub.layout[1]
  f = it.content
  f isa Flow && length(f.lines) > 1 ? it.top + f.above + f.lines[1].high + f.below : it.top + it.tall
end

describe(b::PaneButton) = begin
  p, e = b.of, editor(b.of)
  over = ishovered(b)
  if b.action == :send
    send_button(p, e, over)
  elseif b.action == :stop
    Box(fixed(28px), height(28px), radius(14px), Alignment.Center, justify=Alignment.Center, name="Stop", background(over ? tint(colours.ink, 0.85) : colours.ink),
      Icon("stop-fill", size=11px, color=colours.bg))
  elseif b.action == :agent
    who = pane_agent(p, e)
    logo = agent_logo(who)
    Row(height(28px), Alignment.Center, padding(7px, 0px), child_gap=7px, radius(6px), name="Agent name", background(over ? on_glass(0.1) : clear),
      (logo === nothing ? Icon("robot", size=16px, color=colours.dim) : Icon(logo[1], size=16px, color=logo[2])),
      Box(label(who, 13px, weight="Semibold")),
      Icon("chevron-down", size=9px, color=colours.faint))
  elseif b.action == :new
    Box(fixed(28px), height(28px), radius(6px), Alignment.Center, justify=Alignment.Center, name="New session", background(over ? on_glass(0.1) : clear),
      Icon("plus-lg", size=14px, color=colours.dim))
  elseif b.action == :model
    w = window_of(e)
    open = w !== nothing && any(q -> q.key == MODEL_MENU, popups(w))
    ink = over || open ? colours.ink : colours.dim
    # It's over the end of your words, so its colour is the slot's with nothing see-through in it, which hides them
    Row(fixed(model_wide(p, e)), height(28px), Alignment.Center, padding(10px, 0px), child_gap=5px, radius(14px), name="Model",
        background(solid_on_glass(e, over || open ? 0.16 : 0.07)),
      Box(label(model_words(p, e), model_face(e).size, color=ink)),
      Icon("chevron-down", size=8px, color=ink))
  elseif b.action == :unattach
    Box(fixed(20px), height(20px), radius(10px), Alignment.Center, justify=Alignment.Center, name="Take away",
        background(over ? RGBA(0, 0, 0, 0.85) : RGBA(0, 0, 0, 0.6)),
      Icon("x-lg", size=9px, color=RGBA(1, 1, 1, 1)))
  elseif b.action == :steps
    # A run of steps as one line. `what` is where the run starts and how many it holds, or 0 while they show.
    k, n = b.what
    Row(height(22px), Alignment.Center, child_gap=8px, radius(5px), name="Steps",
      Box(fixed(16px), height(16px), Alignment.Center, justify=Alignment.Center, Icon(n == 0 ? "chevron-down" : "chevron-right", size=9px, color=colours.faint)),
      Box(label(n == 0 ? "Hide the steps" : "$n steps", 13px * talk_zoom(e), color=over ? colours.ink : colours.dim)))
  else
    allow = b.action == :allow
    Box(height(26px), padding(12px, 0px), radius(6px), Alignment.Center, name=allow ? "Allow" : "Refuse",
        background(allow ? (over ? tint(colours.ink, 0.85) : colours.ink) : over ? on_glass(0.1) : clear), border(1px, :solid, allow ? clear : on_glass(0.2)),
      label(allow ? "Allow" : "Refuse", 12px * talk_zoom(e), color=allow ? colours.bg : colours.ink, weight="Semibold"))
  end
end
cursor(::PaneButton) = :hand

"""
The colour of the panes' ink at `strength` on the window's glass, as a
colour with nothing see-through, which hides what's under it. With `page`
true, it's on the page's paper, as a session's file has it.
"""
solid_on_glass(e, strength; page=talk_on_page[]) = begin
  g, k = page ? convert(RGBA{Float64}, colours.bg) : glass_colour(e), convert(RGBA{Float64}, colours.ink)
  RGBA(g.r + (k.r - g.r) * strength, g.g + (k.g - g.g) * strength, g.b + (k.b - g.b) * strength, 1.0)
end

"""
The button that sends your words: a round button at the right of the words.
While the mouse is on it, it opens to the left to show what goes to the
agent with your words: the heading that the caret is under, or the file's
name, and whether text is selected. The open part lies over your words and
moves none of them. It shuts when the mouse leaves.
"""
send_button(p::AgentPane, e, over::Bool) = begin
  ready = p.field.buf.lines != [""] || (p.session !== nothing && !isempty(changed_replies(p.session)))
  about = over ? first(pane_context(p, e)) : ""
  # Whether it's open, since when, and the words in it, which stay while it shuts
  kept = get(p.parts, :send_open, (false, 0.0, ""))
  kept[1] == !isempty(about) || (kept = (!isempty(about), time(), kept[3]))
  isempty(about) || (kept = (kept[1], kept[2], about))
  p.parts[:send_open] = kept
  t = clamp((time() - kept[2]) / SEND_GROWS, 0.0, 1.0)
  t < 1 && redraw_in!(e, SOON)
  t = 1 - (1 - t)^3   # quick at the start, slow at the end
  open = kept[1] ? t : 1 - t
  face = pane_face(e, colours.bg; size=12px)
  words = shortened(face, kept[3], max(40px, pane_wide(p, e) - 2PANE_X - 90px))
  wide = px(round(num((measure(face, words) + 36px) * open)))
  shows = wide >= 1px
  # Over your words, the button's colour has nothing see-through in it
  back = ready ? (over ? solid_on_glass(e, 0.85) : colours.ink) : shows ? solid_on_glass(e, 0.24) : on_glass(0.12)
  ink = ready ? colours.bg : shows ? colours.ink : colours.bg
  # The button keeps its place and its size in the row. Its open part reaches out to the left of that.
  Box(fixed(28px), height(28px), Alignment.Start, name="Send",
    Row(fixed(wide + 28px), height(28px), radius(14px), Alignment.Center, background(back), offset_x=-wide, name="Send pill",
      (shows ? (Box(fixed(wide), height(28px), clip=true,
                  Row(height(28px), Alignment.Center, padding(0px, 0px, 0px, 12px), child_gap=6px, name="About",   # top, right, bottom, left
                    Icon("file-earmark-text", size=12px, color=ink),
                    Box(label(words, face.size, color=ink)))),) : ())...,
      Box(fixed(28px), height(28px), Alignment.Center, justify=Alignment.Center, Icon("arrow-up", size=14px, color=ink))))
end

onkey(b::PaneButton, ev::KeyPress{Keys.mouse_left}) = begin
  p, s = b.of, b.of.session
  b.action == :agent && return (hide_tooltip!(ev.window); choose_agent!(p, b, ev.window); handled)
  b.action == :model && return (hide_tooltip!(ev.window); choose_model!(p, b, ev.window); handled)
  b.action == :send && send_words!(p)
  b.action == :stop && s !== nothing && stop!(s)
  b.action == :new && new_session!(p)
  b.action == :unattach && unattach!(p, b.what)
  b.action in (:allow, :refuse) && s !== nothing && answer!(s, b.what, b.action == :allow)
  b.action == :steps && (k = b.what[1]; k in p.open ? delete!(p.open, k) : push!(p.open, k))
  hide_tooltip!(ev.window)
  redraw_in!(editor(p), SOON)
  handled
end

# A tooltip in the pane is put by the button's rectangle
onmouse(b::PaneButton, ev::MouseMove) = begin
  # The send button shows what goes with your words while the mouse is on it, so its tooltip says that they go together
  tip = b.action == :send ? send_tip(b.of) :
        b.action == :stop ? "Stop the agent. What it changed so far stays." :
        b.action == :new ? "End this session, and start a new one" : b.action == :agent ? "Choose the agent" :
        b.action == :model ? "Choose the model" :
        b.action == :unattach ? "Don't send this picture" : ""
  r = isempty(tip) ? nothing : rect(b)
  r === nothing || show_tooltip!(ev.window, tip_label(tip), r.left, r.top, r.width, r.height; placement=:bottom, gap=6px)
  nothing
end

# --- the outline ---

"The line of the heading that the top of the window of `e` is in: the last of `entries` that starts above the first lines that show, or 0. A page that an HTML file makes has no lines, and gives the heading's place in `entries`."
section_now(e, entries) = begin
  isempty(entries) && return 0
  if html_shown(e)
    found, tops = html_outline(e)
    edge = Browsers.scrolled(html_browser(html_part(e))) + 70   # a heading counts once it's near the top of the window
    k = findlast(<=(edge), tops)
    return k === nothing ? 0 : found[k].line
  end
  isempty(e.layout) && return 0
  edge = e.scroll.offset + 70px   # a heading counts once it's near the top of the window
  line = 1
  for it in e.layout
    it.top + PAGE_TOP > edge && break
    line = it.last
  end
  k = findlast(x -> x.level <= 6 && x.line <= line, entries)
  k === nothing ? 0 : entries[k].line
end

"The heading of the section that's at the top of the window of `e`, which the outline marks, or nothing"
section_in_view(e) = begin
  entries = something(page_outline(e), Entry[])
  now = section_now(e, entries)
  k = findfirst(x -> x.line == now && x.level <= 6, entries)
  k === nothing ? nothing : entries[k]
end

describe(o::OutlinePane) = with_pane_colours() do
  e = editor(o)
  b = e.buf
  entries = something(page_outline(e), Entry[])
  heads = filter(x -> x.level <= 6, entries)
  top = isempty(heads) ? 1 : minimum(x -> x.level, heads)
  # A page that starts with its one biggest heading has that for its title, and its sections are the headings a level down
  titled = !isempty(heads) && first(heads).level == top && count(x -> x.level == top, heads) == 1 && first(heads).line == first(entries).line
  base = titled && length(heads) > 1 ? minimum(x -> x.level, heads[2:end]) : top
  # A page that HTML makes has a title of its own
  said = html_shown(e) ? html_browser(html_part(e)).title : ""
  named = titled ? first(heads).title : !isempty(said) ? said : isempty(b.path) ? "Untitled" : title(b.path)
  sections = count(x -> x.level == base, titled ? heads[2:end] : heads)
  now = section_now(e, entries)
  wide = right_w(e)
  rows = Any[]
  under, depth = 0, 0   # the level of a folded heading, whose lines are left out, and how far in the last heading is
  for (k, x) in enumerate(entries)
    titled && k == 1 && continue   # the title is at the top of the pane
    under > 0 && x.level > under && continue
    under = 0
    x.level <= 6 && (depth = x.level - base)
    opens = k < length(entries) && entries[k+1].level > x.level
    folded = opens && (x.level, x.title) in o.folded
    folded && (under = x.level)
    r = get!(() -> own!(o, OutlineRow(of=o)), o.rows, length(rows) + 1)
    r.line, r.caret, r.level, r.title, r.icon = x.line, x.caret, x.level, x.title, x.icon
    r.depth, r.opens, r.folded, r.now = max(0, x.level <= 6 ? depth : depth + 1), opens, folded, now == x.line
    push!(rows, r)
  end
  face = Face(SANS, "Semibold", 14px, colours.ink, false)
  Column(width(grow=grow), height(grow=grow), Alignment.Start, name="Outline",
    PaneColours(on=true, across=true),
    Column(width(grow=grow), height(44px), Alignment.Start, padding(PANE_X, 0px), child_gap=2px, justify=Alignment.Center,   # across, down
      Row(height(18px), Alignment.Center, label(shortened(face, named, wide - 2PANE_X), 14px, weight="Semibold")),
      Row(height(16px), Alignment.Center, label(isempty(rows) ? (html_shown(e) ? "No headings" : "No headings yet") : sections == 1 ? "1 section" : "$sections sections", 12px, color=colours.dim))),
    reuse!(o.scroll, Column(width(grow=grow), Alignment.Start, padding(4px, 8px, 16px, 8px), child_gap=1px, rows...)),
    PaneColours(on=false, across=true))
end

const OUTLINE_STEP = 14px   # how far in each level of the outline is

describe(r::OutlineRow) = begin
  e = editor(r)
  heading = r.level <= 6
  colour = r.now || ishovered(r) ? colours.ink : colours.dim
  face = Face(SANS, r.depth == 0 && heading ? "Medium" : "", 13px, colour, false)
  room = right_w(e) - 16px - 16px - OUTLINE_STEP * r.depth - 14px - 7px - 14px - 7px
  Row(width(grow=grow), height(30px), Alignment.Center, radius(7px), padding(0px, 8px, 0px, 8px + OUTLINE_STEP * r.depth), child_gap=7px, name="Outline row",
      background(r.now ? on_glass(0.09) : ishovered(r) ? on_glass(0.05) : clear),
    Box(fixed(14px), height(14px), Alignment.Center, justify=Alignment.Center,
        (r.opens ? (Icon(r.folded ? "chevron-right" : "chevron-down", size=9px, color=colours.dim),) : ())...),
    Icon(heading ? "text-left" : r.icon, size=13px, color=r.now ? colours.ink : colours.faint),
    Box(label(shortened(face, r.title, max(room, 20px)), 13px, color=colour, weight=face.style)))
end
cursor(::OutlineRow) = :hand

# A click on the arrow of a heading hides the lines under it, or shows them. A click anywhere else on a line goes to it in the page.
onkey(r::OutlineRow, ev::KeyPress{Keys.mouse_left}) = begin
  e, o = editor(r), r.of
  at = rect(r)
  if r.opens && at !== nothing && ev.window.mouse[1] < at.left + 8px + OUTLINE_STEP * r.depth + 18px
    key = (r.level, r.title)
    key in o.folded ? delete!(o.folded, key) : push!(o.folded, key)
  elseif html_shown(e)
    # The heading goes near the top of the window. A page that HTML makes has no caret to move.
    tops = html_outline(e)[2]
    1 <= r.line <= length(tops) && Browsers.scroll!(html_browser(html_part(e)), tops[r.line] - 24)
  else
    note_place!(e)   # ⌘⌥← comes back here
    show_line!(e, r.caret)
    # The heading goes near the top of the window. The next frame does it, once it has laid out the page.
    e.nodes[:hold] = (r.line, 24px - PAGE_TOP)
  end
  redraw_in!(e, SOON)
  handled
end

# --- into agent mode, and out of it ---

"""
Make the window `w` of `e` wider for agent mode: as wide as the agent's
pane, the page's card and the outline need, or as wide as its screen. The
page stays where it is on the screen, as far as the screen allows. A window
that fills a screen of its own stays as it is.
"""
widen_for_agent!(e, w, p::AgentPane, side_was) = begin
  (w === nothing || e.full_screen) && return nothing
  wide, tall = w.size
  x, y = w.position
  screen = w.screen
  outline = e.right && right_view(e) !== nothing ? OUTLINE_W : 0px   # a page of a kind that has no outline has none
  card = something(PAGE_CARD_CHOSEN[], page_shape_wide(tall))
  want = AGENT_W + card + outline + 2PAGE_CARD_GAP
  new = px(round(num(min(max(want, wide), max(screen.size[1], wide)))))
  # The middle of the page's space before, and of the card's room after
  middle = x + side_was + (wide - side_was) / 2
  left = middle - (new - outline - PAGE_CARD_GAP - card / 2)   # the card is beside the outline
  left = px(round(num(clamp(left, screen.position[1], max(screen.position[1], screen.position[1] + screen.size[1] - new)))))
  p.was = (p.was..., grew=new - wide, moved=left - x)
  w.position = typeof(w.position)(left, y)
  w.size = typeof(w.size)(new, tall)
  nothing
end

"Make the window `w` of `e` as wide as it was before agent mode, where it was, less what you changed since"
narrow_from_agent!(e, w, p::AgentPane) = begin
  (w === nothing || e.full_screen || p.was === nothing || !haskey(p.was, :grew)) && return nothing
  wide, tall = w.size
  x, y = w.position
  w.size = typeof(w.size)(max(wide - p.was.grew, 400px), tall)
  w.position = typeof(w.position)(x - p.was.moved, y)
  nothing
end

"""
Show an agent's session at the left of the page and the page's outline at
its right, in a wider window, with the page between them on a card. A page
of a kind that has no outline, like a design, has nothing at its right. Run it
again to put the window back as it was. The session stays, for the next time.
"""
agent_mode!(e) = begin
  e = top_editor(e)
  p = agent_pane(e)
  w = window_of(e)
  if agent_mode(e)
    e.nodes[:agent_mode] = false
    see_through!(e, w, false)
    narrow_from_agent!(e, w, p)
    p.was === nothing || (e.panel = p.was.panel)
    e.slid = 0.0   # the sidebar is where it was at once
    focus(e)
  else
    side_was = side_w(e)
    p.was = (panel=e.panel,)
    e.nodes[:agent_mode] = true
    e.panel = true
    e.slid = 0.0
    widen_for_agent!(e, w, p, side_was)
    see_through!(e, w, GLASS_ALPHA < 1)
    p.field === nothing && pane_field!(p)
    focus(p.field)
  end
  empty!(e.flows)   # the page's text is as wide as its new place allows
  redraw_in!(e, SOON)
  nothing
end
works_here(e, ::Val{:agent_mode}) = agent_mode(e) || !nofile(e)
"End the session of agent mode. Your next words there start a new one."
end_agent_session!(e) = (new_session!(agent_pane(top_editor(e))); nothing)
works_here(e, ::Val{:end_agent_session}) = agent_mode(e) && agent_pane(e).session !== nothing

# --- a session's file ----------------------------------------------------------------------
#
# A file whose name ends in .chat keeps a session of an agent: what you and
# the agent said, the steps that the agent took, and the name that the agent
# gives the session. Such a file opens as the session, which covers the
# page's whole space. It's the talk of agent mode's pane with the page to
# itself, in the page's own colours. It does what a terminal with an agent in
# it does, but what the agent says shows as a page: headings, tables,
# diagrams and charts. That's the file's highest level, over its bits, its
# bytes in hexadecimal and its text, so ⌘E shows the text.
#
# New Agent Session, in a folder's menu and in the command palette, makes
# such a file for the agent that Settings chose, and shows it. The agent
# works in the folder that the file is in. Its program starts with your first words. It
# works on while the window shows other files, as a terminal's shell does.
# It ends when the window closes, and when the agent has done and its file
# has no tab.
#
# The file is Markdown, so any app reads it. A comment starts each part and
# says what the part is: `<!-- ladder:you -->` before your words,
# `<!-- ladder:agent -->` before the agent's, `<!-- ladder:step … -->`
# before a step. The first line names the agent, its folder and the session.
# With that name the agent goes on with the session on another day: your
# next words start its program again, and it knows what was said. The file
# is written when the agent has done, and every two seconds while it works.

const CHAT_WIDE = 780px                  # how wide the talk of a session's file is at most, before the page's zoom
const PAGE_TALK = 16px                   # how tall the text of a session's file is, before the page's zoom
const TALK_MARK = "<!-- ladder:"         # what the line that starts a part of a session's file starts with

"True when the page shows a session's file at one of its levels: as the session, its text, its bytes in hexadecimal or its bits"
chat_page(b::Buffer) = b.view in FILE_VIEWS && lowercase(splitext(b.path)[2]) in CHATS && isfile(b.path)

"True when the page shows a session's file as the session"
chat_shown(e) = e.buf.view == :file && hosted(e) === nothing && chat_page(e.buf)

"The sessions' files of the window of `e`: the pane of each one that it has shown and that's still there"
chats(e) = get!(() -> Any[], e.nodes, :chats)

"How wide the pane `p` is: the pane of agent mode has what the page's card leaves, and a session's file has a column in the middle of the page"
pane_wide(p::AgentPane, e) = on_page(p) ? px(round(num(clamp(page_room(e)[1] - 16px, 260px, CHAT_WIDE * e.zoom)))) : agent_wide(e)

"What goes to the agent with your words from the pane `p`: what the page beside it shows (see `page_context`). A session's file has no page beside it."
pane_context(p::AgentPane, e) = on_page(p) ? ("", "") : page_context(e)

"The line that starts a part of a session's file: the kind of part, and with `about` what else the part has, as JSON"
talk_mark(kind, about=nothing) = TALK_MARK * kind * (about === nothing ? "" : " " * replace(sprint(write_json, about), "--" => "-\\u002d")) * " -->"

"The words `text` as lines of a session's file. A line that looks like the start of a part gets a \\ before it, which reading takes away."
talk_body(text) = join((occursin(r"^\\*<!-- ladder:", l) ? "\\" * l : l for l in split(text, '\n')), "\n")

"The mark and the words of the part of a session's file that keeps `it`, something that a session holds"
talk_part(it::YouSaid) = begin
  about = Dict{String,Any}()
  isempty(it.about) || (about["about"] = it.about)
  isempty(it.pictures) || (about["pictures"] = it.pictures)
  it.changed == 0 || (about["changed"] = it.changed)
  (talk_mark("you", isempty(about) ? nothing : about), it.words)
end
talk_part(it::AgentReply) = (talk_mark("agent", reply_changed(it) ? Dict("saw" => it.saw) : nothing), rstrip(it.text))
talk_part(it::AgentStep) = (talk_mark("step", Dict("tool" => it.tool, "state" => String(it.state))), it.words)
talk_part(it::AgentWants) = (talk_mark("asked", Dict("tool" => it.tool, "answer" => String(it.answer), "detail" => it.detail)), it.words)
talk_part(it::SessionNote) = (talk_mark("note", it.bad ? Dict("bad" => true) : nothing), it.words)

"""
The text of the file that keeps the session `s`: a line with the agent, its
folder and the session's name, and then each thing that you and the agent
said, in order. `before` is what the file had over that line, which stays.
"""
talk_text(s::AgentSession, before="") = begin
  io = IOBuffer()
  isempty(before) || print(io, before, "\n")
  head = Dict("agent" => s.agent, "folder" => s.dir, "id" => s.id)
  isempty(s.model) || (head["model"] = s.model)
  println(io, talk_mark("session", head))
  for it in s.items
    mark, words = talk_part(it)
    print(io, "\n", mark, "\n", talk_body(words), "\n")
  end
  String(take!(io))
end

"""
What `text`, the text of a session's file, holds: the agent's name, its
folder, the session's name, and what you and the agent said, in order.
`before` is the text over the first part, which is no part of the session.
A step that was under way when the file was written is done now.
"""
read_talk(text::AbstractString) = begin
  agent, folder, id, model, before, items = "", "", "", "", String[], Any[]
  kind, about, body = "", nothing, String[]
  said(key) = (v = json_field(about, key); v isa String ? v : "")
  part!() = begin
    words = String(strip(join(body, "\n"), '\n'))
    empty!(body)
    if kind == "session"
      agent, folder, id, model = said("agent"), said("folder"), said("id"), said("model")
      # An agent that has another name now is another program, which can't go on with the session or use its model
      haskey(AGENTS_RENAMED, agent) && ((agent, id, model) = (AGENTS_RENAMED[agent], "", ""))
    elseif kind == "you"
      pictures = json_field(about, "pictures")
      n = json_field(about, "changed")
      push!(items, YouSaid(words=words, about=said("about"), pictures=pictures isa AbstractVector ? String[p for p in pictures if p isa AbstractString] : String[],
                           changed=n isa JSONNumber ? something(tryparse(Int, n.text), 0) : 0))
    elseif kind == "agent"
      saw = json_field(about, "saw")
      push!(items, AgentReply(text=words, whole=true, n=1, saw=saw isa AbstractString ? String(saw) : nothing))
    elseif kind == "step"
      push!(items, AgentStep(id="kept-$(length(items))", tool=said("tool"), words=words, state=said("state") == "failed" ? :failed : :done))
    elseif kind == "asked"
      answer = said("answer")
      push!(items, AgentWants(tool=said("tool"), words=words, detail=said("detail"), answer=answer == "allowed" ? :allowed : answer == "refused" ? :refused : :gone))
    elseif kind == "note"
      push!(items, SessionNote(words=words, bad=json_field(about, "bad") === true))
    end
  end
  for line in split(text, '\n')
    m = match(r"^<!-- ladder:(\w+)(?: (.*))? -->\s*$", line)
    if m !== nothing
      part!()
      kind, about = String(m[1]), m[2] === nothing ? nothing : agent_json(m[2])
    elseif isempty(kind)
      push!(before, line)
    else
      push!(body, occursin(r"^\\+<!-- ladder:", line) ? line[2:end] : line)
    end
  end
  part!()
  (agent=agent, folder=folder, id=id, model=model, items=items, before=String(rstrip(join(before, "\n"))))
end

"""
Read the file of the pane `p`, a session's file, into its session: what was
said, and the name that the agent goes on with. A file with no agent in it
gets the agent that Settings chose. The agent works in the folder that the
file is in, also when the file names another one: the file was moved there.
"""
load_talk!(p::AgentPane, e) = begin
  kept = read_talk(try read(p.file, String) catch; "" end)
  s = p.session
  if s === nothing
    agent = !isempty(kept.agent) ? kept.agent : SESSION_COMMAND[] === nothing ? agent_kind(e.ai).name : e.ai
    s = p.session = AgentSession(agent=agent, dir=dirname(abspath(p.file)), file=p.file, turns=by_turns(agent), model=chosen_model(agent))
  end
  s.id, s.items = kept.id, kept.items
  # The model that the session worked with goes on with it. A file with none has the model that you chose last.
  isempty(kept.model) || (s.model = kept.model)
  s.version += 1
  p.kept, p.stamp = s.version, mtime(p.file)
  p.parts[:before] = kept.before
  empty!(p.open)
  filter!(((k, _),) -> !(k isa Tuple && k[1] == :reply), p.parts)
  p.follow = true
  p
end

"Write the session of the pane `p` to its file, when the file doesn't have all of it yet"
keep_talk!(p::AgentPane) = begin
  s = p.session
  (s === nothing || isempty(p.file) || s.version == p.kept) && return p
  # A disk that says no is asked again with the next thing that the session has
  try
    write(p.file, talk_text(s, get(p.parts, :before, "")))
    p.stamp = mtime(p.file)
  catch
  end
  p.kept, p.wrote = s.version, time()
  p
end

"""
The session of the session's file that the page shows, in the page's space.
The words that you type have the keyboard while nothing else has taken it:
the field that finds text, the sidebar and the command palette take it and
give it back. The top bar says which agent it is, and where it works.
"""
chat_part(e) = begin
  b = e.buf
  p = node!(e, (:chat, b.path)) do
    made = AgentPane(file=b.path)
    push!(chats(e), made)
    made
  end
  s = p.session
  # The file changed under the session, as when you changed its text a level down. The session shows what the file has now.
  (s === nothing || (!s.busy && mtime(p.file) != p.stamp)) && load_talk!(p, e)
  s = p.session
  p.field === nothing && pane_field!(p)
  w = window_of(e)
  if w !== nothing
    (w.focus === e || w.focus === nothing) && e.popup == :none && focus(p.field)
    w.focus === p.field && e.popup != :none && focus(e)   # what floats over the page, like the command palette, has the keys
  end
  b.about = s.busy ? "$(s.agent) is working in $(basename(s.dir))" : "$(s.agent) in $(basename(s.dir))"
  p
end

const TALK_SLIDE = 0.4   # seconds for the field of a session's file to slide from the middle of the page to its foot

"The room under the field of a session's file while nothing is said yet. It's as tall as the room over the field, so the field is in the middle."
@def mutable struct TalkRoom <: SemanticUI end
describe(::TalkRoom) = Box(width(grow=grow), height(grow=grow))

"True when nothing is said yet in the session of the pane `p`: the page shows the greeting, with the field under it in the middle of the page"
said_nothing(p::AgentPane) = (s = p.session; isempty(p.error) && (s === nothing || (isempty(s.items) && !s.busy && !s.loading)))

"""
A session's file in the page: what you and the agent said in a column in
the middle, and under it the field that you type in. Before anything is
said, the field is in the middle of the page, under the greeting. Your
first words make it slide down to the foot of the page, where it stays.
"""
talk_page(p::AgentPane) = begin
  was = talk_on_page[]
  talk_on_page[] = true
  try
    e = editor(p)
    p.field === nothing && pane_field!(p)
    follow!(p)
    wide = pane_wide(p, e)
    room = wide - PANE_LEFT - PANE_X
    middle(x) = Row(width(grow=grow), Alignment.Start, justify=Alignment.Center, Box(fixed(wide), Alignment.Start, x))
    under = get!(() -> own!(p, TalkRoom()), p.parts, :room)
    if said_nothing(p)
      p.parts[:middle] = true
      # The greeting is at the foot of the room over the field. That room and the one under the field share what's left, so the field is in the middle.
      # The foot has 14px more room under its slot than over it, which the gap over the foot evens out.
      return Column(width(grow=grow), height(grow=grow), Alignment.Start, name="Agent",
        Column(width(grow=grow), height(grow=grow), Alignment.Start, justify=Alignment.End, middle(talk_greeting(p, e, room))),
        Box(width(grow=grow), height(14px)),
        middle(pane_foot(p, e, room)),
        under)
    end
    # On the first frame after your first words, the field starts to slide down from where it was in the middle
    if pop!(p.parts, :middle, false)
      r = rect(under)
      r === nothing || (p.parts[:slid] = (r.height, time()))
    end
    from, at = get(p.parts, :slid, (0px, 0.0))
    time() - at < TALK_SLIDE && redraw_in!(e, 0)
    lift = px(round(num(eased(from, 0px, at; take=TALK_SLIDE))))
    Column(width(grow=grow), height(grow=grow), Alignment.Start, name="Agent",
      reuse!(p.scroll, middle(pane_talk(p, e, room))),
      middle(pane_foot(p, e, room)),
      Box(width(grow=grow), height(lift)))
  finally
    talk_on_page[] = was
  end
end

"What a session's file shows before anything is said: the agent's logo and name, and the folder that it works in"
talk_greeting(p::AgentPane, e, room) = begin
  who = pane_agent(p, e)
  logo = agent_logo(who)
  dir = p.session === nothing ? dirname(p.file) : p.session.dir
  z = talk_zoom(e)
  line(words, size, colour; weight="") = Row(width(grow=grow), height(size * 1.5), Alignment.Center, justify=Alignment.Center, Box(label(words, size, color=colour, weight=weight)))
  face = pane_face(e, colours.dim; size=13px)
  Column(width(grow=grow), Alignment.Start, padding(20px, PANE_X, 14px, PANE_LEFT), child_gap=4px, name="Talk",
    Row(width(grow=grow), height(48px), Alignment.Center, justify=Alignment.Center,
      Box(fixed(40px), height(40px), Alignment.Center, justify=Alignment.Center,
          logo === nothing ? Icon("robot", size=40px, color=colours.dim) : Icon(logo[1], size=40px, color=logo[2]))),
    Box(height(6px)),
    line("A session with $who", 22px * z, colours.ink; weight="Semibold"),
    line(shortened(face, "In $(tilde(dir))", room), face.size, colours.dim),
    Box(height(10px)),
    line("Ask anything, or say what to do in this folder.", face.size, colours.dim),
    line("What $who says shows here as a page: tables, diagrams and charts.", face.size, colours.faint),
    line("Type / for commands, like /resume to go on with an earlier session.", face.size, colours.faint))
end

"""
See to the sessions' files of the window of `e`. Each one's agent gets its
turn, also while the window shows another file, and what it said goes into
its file: at once when it has done, and every two seconds while it works.
A session that isn't shown gives the keyboard back. Its program ends when
the agent has done and the file has no tab: your next words start it again.
One whose file has gone ends.
"""
chat_tick!(e) = begin
  haskey(e.nodes, :chats) || return nothing
  shown = chat_shown(e) ? get(e.nodes, (:chat, e.buf.path), nothing) : nothing
  w = window_of(e)
  for p in copy(chats(e))
    s = p.session
    if p !== shown
      w !== nothing && p.field !== nothing && w.focus === p.field && focus(e)
      if !isfile(p.file)
        s === nothing || close!(s)
        delete!(e.nodes, (:chat, p.file))
        Base.filter!(o -> o !== p, chats(e))
        continue
      end
      # A reading companion's session has no tab of its own: it ends with its folder's tab
      s !== nothing && !s.busy && running(s) && !(p.file in tabs(e)) && !is_companion(p) && close!(s)
    end
    pane_tick!(p, e)
    s !== nothing && s.version != p.kept && (!s.busy || time() - p.wrote > 2) && keep_talk!(p)
  end
  nothing
end

"End the agent of every session's file of the window of `e`, and write each file: the window has closed"
close_chats!(e) = begin
  haskey(e.nodes, :chats) || return nothing
  end_companions!(e)
  for p in chats(e)
    s = p.session
    s === nothing && continue
    was = s.busy
    close!(s)
    was && (s.version += 1)   # what was under way is whole now
    keep_talk!(p)
  end
  empty!(chats(e))
  nothing
end

"""
Start a session with the agent that Settings chose, in a file of its own in
the folder `dir`, and show it. The session fills the page: what the agent
says shows as a page, not as a terminal's text. The agent works in the top
folder of the folder's repository, or in the folder itself.
"""
new_agent_session!(e, dir) = begin
  e = top_editor(e)
  who = agent_kind(e.ai).name
  path = free_path(e, dir, who, first(CHATS))
  top = git_top(dir)
  try write(path, talk_mark("session", Dict("agent" => who, "folder" => isempty(top) ? String(dir) : top, "id" => "")) * "\n") catch; return end   # the disk said no
  open!(e, path)
  list_files!(e)
  nothing
end
new_agent_session!(e, d::AbstractDirectory) = new_agent_session!(e, path_of(d))

# --- the conversation writes the message of a commit ---
#
# The Commit button asks the agent of agent mode's conversation for the
# message of a commit: see "an agent writes the commit's message" in
# git_page.jl.

"The pane of the conversation beside the page of `e`, while agent mode shows and you have said something in it, or nothing"
commit_talk(e) = begin
  agent_shows(e) || return nothing
  p = get(e.nodes, :agent_pane, nothing)
  p isa AgentPane && p.session !== nothing && any(it -> it isa YouSaid, p.session.items) ? p : nothing
end

"""
Give the agent of the pane `p` the words `shown`, which the pane shows, with
`told` before them, which it doesn't, and give back its last reply once its
turn has ended. It waits first for the turn that's under way. It fails when
the turn ends with no reply, when you stop it, and when the agent fails.
Call it in a task on the window's thread: it waits while the window goes on.
"""
ask_talk!(p::AgentPane, shown, told) = begin
  e = editor(p)
  while p.session !== nothing && (p.session.busy || p.session.loading)
    sleep(0.05)
  end
  s = session!(p, e)
  say!(s, shown, "", told)
  asked = s.items[findlast(it -> it isa YouSaid, s.items)]
  p.follow = true
  redraw_in!(e, SOON)
  while s.busy
    sleep(0.05)
  end
  k = findlast(it -> it === asked, s.items)
  k === nothing && error("$(s.agent) went on with another session, so it wrote no message.")
  after = s.items[k+1:end]
  # A turn that you stopped, or that went wrong, ends with a note that says so
  n = findfirst(it -> it isa SessionNote && (it.bad || startswith(it.words, "You stopped")), after)
  n === nothing || error(after[n].bad ? after[n].words : "You stopped $(s.agent), so nothing was committed.")
  replies = filter(it -> it isa AgentReply, after)
  isempty(replies) && error("$(s.agent) didn't write a message.")
  last(replies).text
end
