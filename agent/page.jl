# A page that an agent waits for: the button that sends it, and what the agent changed in it
#
# An agent like Claude Code writes a page, shows it here and waits (see
# waiters.jl). While it waits, the top bar has a button with a bell that sends the page: it
# saves the file and tells the agent which lines you changed. ⌘Return does the
# same. The agent can change the file while you type, and the page keeps both.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" describe focus
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "../merge" changes follow
@use "./waiters" => Agent
@use "../look" exports...
@use "../buffer" exports...
@use "../editor_type" exports...
@use "../shared" exports...
@use "../host" exports...
@use "../folder_page" exports...
@use "./kinds" exports...
@use "../git_page" AgentMarks

export waiters, agents, elsewhere, send!, hand_over!, agent_part, toggle_marks!, whose, sharer,
       PageAgents, page_agents, forget_waiters!, marking

"What a window keeps about the agents that its page is shared with"
@def mutable struct PageAgents
  waiters::Tuple{Float64,Vector{Agent.Waiter}} = (0.0, Agent.Waiter[])   # when the folder that lists the agents that wait was last read, and every agent that it listed, for any page
  sent::Union{Nothing,Tuple{String,Int,String}} = nothing                # the page that was last sent to an agent, its version then, and the agent's name
  last::String = "the agent"                                             # the name of the agent that last waited for a page that the window showed
  # What the lines that an agent changed were last worked out for, and the runs of those lines: see `theirs`
  changed::Union{Nothing,Tuple{Tuple{UInt,UInt,Int},Vector{UnitRange{Int}}}} = nothing
end

"What the window of `e` keeps about the agents that its page is shared with: see `PageAgents`"
page_agents(e) = state_of(e, PageAgents)

"Read the folder that lists the agents that wait again, the next time that the window of `e` asks for them"
forget_waiters!(e) = (page_agents(e).waiters = (0.0, Agent.Waiter[]); nothing)

"Every agent that waits, for any page. The folder that lists them is read twice a second."
waiters(e) = begin
  at, found = page_agents(e).waiters
  time() - at < 0.5 && return found
  Agent.announce()
  found = Agent.waiters()
  page_agents(e).waiters = (time(), found)
  found
end

"The agents that wait for the file at `path`"
agents(e, path) = begin
  ws = waiters(e)
  (isempty(ws) || isempty(path)) && return ws[1:0]
  at = truepath(path)
  filter(w -> w.page == at, ws)
end

"The agents that wait for the page that's showing"
agents(e) = readonly(e.buf) ? Agent.Waiter[] : agents(e, e.buf.path)

"The agents that wait for a page that isn't the one that's showing"
elsewhere(e) = begin
  ws = waiters(e)
  isempty(ws) && return ws
  at = isempty(e.buf.path) ? "" : truepath(e.buf.path)
  filter(w -> w.page != at, ws)
end

"Save the page and tell each agent that waits for it what you changed. Nothing happens if no agent waits."
send!(e) = begin
  b = e.buf
  forget_waiters!(e)
  ws = agents(e)
  isempty(ws) && return
  save!(b)
  lo, hi = selection(b)
  hand_over!(e, ws, Agent.report(b.path, b.told, b.lines, lo[1], selecting(b) ? excerpt(b, lo, hi) : ""))
end

"Give the agents `ws`, which wait for the page of `e`, the text `text`, which tells them of the page as it is now"
hand_over!(e, ws, text) = begin
  b = e.buf
  foreach(w -> Agent.send(w, text), ws)
  # The agent knows the page as it is now, and none of the lines are its changes any more
  b.sent = b.told = copy(b.lines)
  state_of(e, AgentMarks).page = ""
  page_agents(e).sent = (b.path, b.version, first(ws).name)
  forget_waiters!(e)
  nothing
end

"""
What the top bar shows of the agent: a button while one waits, and a few
words after you sent the page. The button that shows the agent's changes is
beside the diff button (see `diff_part`).
"""
agent_part(e) = begin
  b = e.buf
  ws = agents(e)
  sent = page_agents(e).sent
  if !isempty(ws)
    page_agents(e).sent = nothing
    page_agents(e).last = first(ws).name
    (node!(SendButton, e, :send),)
  elseif sent !== nothing && sent[1] == b.path && sent[2] == b.version
    # The button shows that the page was sent, until the agent waits again or the text changes
    (node!(SendButton, e, :send),)
  else
    ()
  end
end

"""
The runs of lines of the page that were changed from outside, by an agent,
since you last sent the page, or since it was opened. Lines that were removed
leave nothing to show.
"""
theirs(e) = begin
  b = e.buf
  none = UnitRange{Int}[]
  (readonly(b) || b.sent === b.told) && return none
  # They're worked out again when the text changes, or what the agent knows
  key = (objectid(b.sent), objectid(b.told), b.version)
  kept = page_agents(e).changed
  kept !== nothing && kept[1] == key && return kept[2]
  mine = changes(b.told, b.lines)   # your own changes since, which move the agent's lines down or up
  runs = UnitRange{Int}[]
  for (_, new) in changes(b.sent, b.told)
    isempty(new) && continue
    lo, hi = follow(mine, first(new)), follow(mine, last(new))
    push!(runs, min(lo, hi):max(lo, hi))
  end
  page_agents(e).changed = (key, runs)
  runs
end

"True while the bars beside the agent's changes stay on the page that's showing"
marking(e) = state_of(e, AgentMarks).page == e.buf.path

"Show the bars beside the agent's changes until this is called again. The page goes to the first change if none is on screen."
toggle_marks!(e) = begin
  marking(e) && return (state_of(e, AgentMarks).page = ""; nothing)
  state_of(e, AgentMarks).page = e.buf.path
  runs = theirs(e)
  (isempty(runs) || isempty(e.layout)) && return
  touches(it) = any(r -> first(r) <= it.last && last(r) >= it.first, runs)
  _, h = window_size(e)
  seen = filter(it -> it.top + it.tall > e.scroll.offset && it.top < e.scroll.offset + h - above_page(e) - PAGE_TOP, e.layout)
  any(touches, seen) && return
  i = findfirst(touches, e.layout)
  i === nothing || (e.scroll.offset = max(0px, e.layout[i].top - 80px))
  nothing
end

"The name of the agent that works on the page, as the owner of something: \"Claude's\""
whose(e) = page_agents(e).last * "'s"

"The name of the agent that the page of `e` is shared with: the one that waits for it, or the last that it was sent to. It's \"\" when there's neither."
sharer(e) = begin
  ws = agents(e)
  isempty(ws) || return first(ws).name
  # An article of a folder of news has the folder's reading companion
  p = readonly(e.buf) ? nothing : companion_pane(e, e.buf.path)
  p === nothing || return p.session.agent
  sent = page_agents(e).sent
  sent !== nothing && sent[1] == e.buf.path ? sent[3] : ""
end

# The button is the logo of the agent, or a bell for an agent that Ladder has no
# logo of, the size of the other buttons in the top bar. It's in the logo's
# colour, or the bell in the accent colour, while an agent waits. After a click
# it's dim, the bell only an outline, and it does nothing.
describe(s::SendButton) = begin
  e = editor(s)
  ishovered(s) || (s.quiet = false)
  waits = !isempty(agents(e))
  logo = agent_logo(sharer(e))
  icon = logo === nothing ? Icon(waits ? "bell-fill" : "bell", size=15px, color=waits ? colours.accent : colours.dim) :
                            Icon(logo[1], size=16px, color=waits ? logo[2] : colours.dim)
  Box(width(30px), height(28px), radius(6px), Alignment.Center, name="Nudge",
      background(waits && ishovered(s) ? colours.hover : clear), icon)
end

cursor(s::SendButton) = isempty(agents(editor(s))) ? :arrow : :hand

onkey(s::SendButton, ::KeyPress{Keys.mouse_left}) = (e = editor(s); send!(e); hush!(s); focus(e))
