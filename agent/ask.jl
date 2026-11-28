# Ask Agent: a change to a thing, a request in place, a queue of requests, the card of an answer, and what the agents changed
#
# The command Ask Agent takes two things: what to change, and what you want
# in words, like "make this bar thinner". What to change is one of:
#
#   - A block of Julia code: in a file of Julia code, a piece of code that
#     starts at the top of the file, like a function with its documentation,
#     and on a page, a `julia` code block.
#   - A part of the window, like the block of a page that shows a bar. The
#     change is to the function that draws it.
#
# It starts as what the caret is on, but never as the whole page: see
# `chip_start`. The chip shows only a letter in a colour,
# A in blue, and a line of that colour with that letter goes round the thing
# in the window: see `chip_letters`. A click on the window chooses another: see
# `chip_click`. The palette's list has the rest, from the nearest.
#
# Ladder gives the words, with the file and the lines of the code, to an
# agent: the command `claude` of Claude Code, which it starts in the folder of
# that file. The agent changes the file. When it has ended, Ladder reads the
# file again and runs each part of its code that changed, in the module that
# the file made, so what the code draws is drawn the new way: see
# `reload_changed!`. A file that shows in a window shows its new lines, as it
# does after any change on the disk. Until the agent ends, a line stays round
# the block or the part, with a label that has your words. After, the label
# has what the agent said of its change, for a few seconds.
#
# The app that's installed writes its own files again each time it starts, so
# a change to one of them lasts until Ladder quits. The command Keep This
# Change keeps the function that the caret is in: it adds the function to the
# startup page, in a block of code that runs each time Ladder starts. See
# "the startup page".

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe reuse! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" draw ishovered cursor show_tooltip! redraw_in! rect popup! close_popup! placed!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/Recorder" stop!
@use "../markdown" Kind classify
@use "./waiters" => Agent
@use "./for_agents" on_main
@use "../blocks/changes" => Diffs
@use "github.com/jkroso/UI.jl/Interface/draw" popups popup_at
@use Colors: @colorant_str, RGBA
@use "../base" exports...
@use "../additions" exports...
@use "../blocks/changes_view" exports...
@use "../files/file_view" exports...
@use "../code/code_names" exports...
@use "../code/code_nav" exports...
@use "../page/page_extras" exports...
@use "./kinds" exports...
@use "./session" exports...
@use "./page" exports...
@use "./pane" exports...
@use "../code/code_thing" exports...
@use "../window/showed_before" note_place!

@use "../folders/git_page" change_diff
export start_agent, asking_words, request_words, agent_step, agent_text, ToChange, page_blocks, FILE_PARTS,
       file_parts, part_choice, drawn_parts, whole_file, thing_words, drawn_rect, shown_words, window_shows,
       part_words, change_ask, change_prompt, AskedChange, AGENT_CHANGES, asked_rect, ask_change!, agent_said,
       reload_files!, ask_ended!, ask_tick!, either_prompt, PickedText, picked_words, words_thing,
       selected_thing, line_thing, picked_rects, picked_box, ASK_BOXES, ASK_BOX_W, ASK_TEXT_W, ASK_TEXT,
       AskBox, box_answer, ask_boxes, box_key, box_about, add_answer!, asking_about, ask_editor,
       ask_selected!, show_answer!, open_ask!, new_field!, show_ask!, forget_ask!, ANSWER_MAX_H,
       answer_flows, unanswered, on_box, answer_part, AskClose, field_button, box_place, waiting,
       edit_request!, still_waits!, waits_note, reworded, take_back!, AskTakeBack, send_ask!, ask_box_tick!,
       box_label, labelled_requests, mark_labels, box_shows, close_tip!, close_words, labelled_box,
       typing_ask, close_ask!, hides_on_close, hide_ask!, reopen_ask!, open_about!, drop_request!, ask_agent!,
       ask_with!, agent_free, ask_queue, asks_ended, queued_label, label_words, queue_ask!, queue_tick!,
       ASK_ALLOWS, BRIEF_ASKS, asks_session, ask_session!, close_asks!, ask_in!, session_ask_tick!,
       quoted_lines, on_page_lines, thing_told, ask_sharer!, hand_change!, sharer_tick!, asked_label,
       working_agents, stop_agent!, stop_agents!, AskedAbout, same_things, follow_up!, talk_words, card!,
       ANSWER_WIDE, ANSWER_LINE, ANSWER_BACK, ANSWER_BUTTON, ANSWER_BUTTONS, answer_lines, answer_place,
       draw_answer, follow_up_on!, change_lines, change_page, show_change!, taken_out, newest_change,
       undo_change!, loaded, loaded_name, keep_change!, AsksState

"""
Start an agent with the command `command` and the words `prompt`, in the
folder `dir`. It gives the agent's process, and a task that reads what the
agent prints. Each step that the agent prints goes into the field `step` of
`into`, as words like "Reading main.jl", for the window to show. What the agent
writes to its errors is kept only for when it fails: Codex writes each of its
steps there.
"""
start_agent(command, prompt, dir, into) = begin
  out, err = Pipe(), Pipe()
  process = run(pipeline(Cmd(`$command $prompt`; env=command.env, dir=dir), stdin=devnull, stdout=out, stderr=err), wait=false)
  close(out.in)   # only the agent writes to them now, so reading ends when the agent does
  close(err.in)
  reading = @async begin
    wrong = @async read(err, String)
    printed = IOBuffer()
    for line in eachline(out)
      println(printed, line)
      step = agent_step(line)
      step === nothing || (into.step = step)
    end
    said = String(take!(printed))
    wrong = fetch(wrong)
    wait(process)
    success(process) || isempty(strip(wrong)) ? said : said * "\n" * wrong
  end
  (process, reading)
end

"What the label of a thing says while an agent works on it: what was asked, and what the agent is doing"
asking_words(words, step) = isempty(step) ? "Asked: $(request_words(words)) …" : "Asked: $(request_words(words))  ·  $step …"

"The words of a request as its label has them: the first 60 characters"
request_words(words) = length(words) > 60 ? first(words, 59) * "…" : words

"""
What an agent is doing, from a line that it printed as JSON, in a few words:
"Reading main.jl", "Changing main.jl", "Looking for wide(", or the start of
what it says. It's nothing for a line that doesn't say.
"""
agent_step(line::AbstractString) = begin
  o = agent_json(line)
  json_field(o, "type") == "assistant" || return nothing
  parts = json_field(json_field(o, "message"), "content")
  parts isa AbstractVector || return nothing
  step = nothing
  for p in parts
    kind = json_field(p, "type")
    if kind == "tool_use"
      name, input = json_field(p, "name"), json_field(p, "input")
      file = json_field(input, "file_path")
      look = something(json_field(input, "pattern"), "")
      step = name == "Read" && file isa String ? "Reading $(basename(file))" :
             name in ("Edit", "Write", "MultiEdit") && file isa String ? "Changing $(basename(file))" :
             name == "Grep" ? "Looking for $look" : name == "Glob" ? "Looking for files like $look" : "Using $name"
    elseif kind == "text" && json_field(p, "text") isa String
      said = strip(replace(json_field(p, "text"), r"\s+" => " "))
      isempty(said) || (step = said)
    end
  end
  step === nothing ? nothing : length(step) > 70 ? first(step, 69) * "…" : step
end

"""
What an agent said at its end, from all that it printed: the words of its
`result` line, when it printed JSON, or else the lines that it printed that
aren't JSON, like an error.
"""
agent_text(printed::AbstractString) = begin
  lines = split(printed, '\n')
  for line in Iterators.reverse(lines)
    o = agent_json(line)
    json_field(o, "type") == "result" && json_field(o, "result") isa String && return String(json_field(o, "result"))
  end
  join((l for l in lines if agent_json(l) === nothing), "\n")
end

"""
Something that Ask Agent can change: a block of a file of Julia code,
or a part of the window, by the function that draws it. `words` and `note`
are what the palette's list says of it. The code is lines `first` to `last`
of the file `file`. `node` is the part of the window, or nothing for a block.
`mod` is the module that runs the code after a change, or nothing when
Ladder hasn't run the file's code.
"""
struct ToChange
  words::String
  note::String
  file::String
  first::Int
  last::Int
  node::Any
  mod::Any
end

worded(c::ToChange) = c.words

sidenote(c::ToChange) = c.note

"The first line of code from line `i` of `lines` on, after blank lines, comments and documentation, or `i` when there's none"
code_start(lines::Vector{String}, i::Int) = begin
  k = i
  while k <= length(lines)
    line = strip(lines[k])
    if startswith(line, "\"\"\"")
      # Documentation of more than one line ends on a line of its own that ends with three quotes
      k = something(findnext(l -> endswith(strip(l), "\"\"\""), lines, k + (line == "\"\"\"" || !endswith(line[4:end], "\"\"\"") ? 1 : 0)), length(lines)) + 1
    elseif isempty(line) || startswith(line, '#') || startswith(line, '"')
      k += 1
    else
      return k
    end
  end
  i
end

"""
The blocks of Julia code in the window of `e`, in the order of its lines. In a
file of Julia code, each is a piece of code that starts at the top of the
file, like a function with its documentation: see `read_parts`. It's named as
Go To names it: a function with the values that it takes, or the first line
of its code. On a page, each is a `julia` code block.
"""
code_blocks(e) = begin
  b = e.buf
  isempty(b.path) && return ToChange[]
  file = page_key(b.path)
  b.view == :markdown && return page_blocks(b, file)
  julia_file(b) || return ToChange[]
  made = page_bounds(e)   # it reads the file's parts again after a change
  kept = kept_file_names(e)
  kept isa FileNames || return ToChange[]
  mod = something(loaded_module(file), Some(get(PAGE_MODULES, file, nothing)))
  out = ToChange[]
  starts = [p.first for p in kept.parts]
  for (k, from) in enumerate(starts)
    to = k == length(starts) ? length(b.lines) : starts[k+1] - 1
    while to > from && isempty(strip(b.lines[to])); to -= 1 end
    at = code_start(b.lines, from)
    # A block of only comments has nothing to change, and a line like `@use "../walls" Wall` only brings names in
    (at <= to && !occursin(r"^\s*(@use|using|import)\b", b.lines[at])) || continue
    j = findfirst(x -> x.span === nothing && x.at[1] == at, made)
    words = j === nothing ? String(strip(b.lines[at])) : signature(b.lines[at], made[j])
    length(words) > 70 && (words = first(words, 69) * "…")
    what = j === nothing || made[j].call ? "" : made[j].words
    push!(out, ToChange(words, isempty(what) ? "line $at" : "$what · line $at", file, from, to, nothing, mod))
  end
  out
end

"""
The `julia` code blocks of the page in `b`, whose file is `file`, as Ask For
Change offers them: the lines between the lines that open and close each. The
page's code runs when you run it, so a change runs nothing by itself.
"""
page_blocks(b::Buffer, file::AbstractString) = begin
  ks = kinds(b)
  out = ToChange[]
  for i in eachindex(ks)
    (ks[i].kind == Kind.fence && ks[i].level == 0 && lowercase(ks[i].lang) in JULIA) || continue
    found = julia_code(b, i + 1 <= length(ks) ? i + 1 : i)
    (found === nothing || found[1] > found[2]) && continue
    from, to = found
    at = code_start(b.lines, from)
    at <= to || (at = from)
    words = String(strip(b.lines[at]))
    length(words) > 70 && (words = first(words, 69) * "…")
    push!(out, ToChange(words, "julia block · line $from", file, from, to, nothing, nothing))
  end
  out
end

"The lines of the file at `file`, and the lines that the parts of its Julia code start on, read again only when the file changes: see `read_parts`"
const FILE_PARTS = Dict{String,Tuple{Float64,Vector{String},Vector{Int}}}()

file_parts(file::AbstractString) = begin
  at = mtime(file)
  kept = get(FILE_PARTS, file, nothing)
  kept !== nothing && kept[1] == at && return kept
  lines = text(file)
  FILE_PARTS[file] = (at, lines, [p.first for p in read_parts(lines, 1)])
end

"""
What Ask Agent offers for the part `x` of the window: the function that
draws it, where that function is in a file on this Mac. It's nothing for a
part that no such function draws.
"""
part_choice(x) = begin
  x isa SemanticUI || return nothing
  m = drawn_by(x)
  place = m === nothing ? nothing : code_place(m)
  place === nothing && return nothing
  file, line = place
  _, lines, starts = file_parts(file)
  line = settled_line(m, lines, line)
  k = max(1, searchsortedlast(starts, line))
  from, to = starts[k], k == length(starts) ? length(lines) : starts[k+1] - 1
  while to > from && isempty(strip(lines[to])); to -= 1 end
  ToChange(x isa TextRun ? x.kind : worded(typeof(x)), "drawn at $(code_label(m))", file, from, to, x, m.module)
end

"A block of a kind that a file defines holds what the file's function made, which that file draws. It comes before the block."
drawn_parts(x) = x isa FileBlock && x.value isa SemanticUI ? (x.value, x) : (x,)

"""
What Ask Agent offers to change in the window of `e`, from the nearest:
the block of Julia code that the caret is in, each part of the window in
focus that a function in a file on this Mac draws, and the other blocks of
Julia code in the window.
"""
choices_for(::Type{ToChange}, e) = begin
  blocks = code_blocks(e)
  line = e.buf.caret[1]
  k = findfirst(c -> c.first <= line <= c.last, blocks)
  out = k === nothing ? ToChange[] : [popat!(blocks, k)]
  for y in command_focus(e), x in drawn_parts(y)
    c = part_choice(x)
    c === nothing || any(o -> (o.file, o.first) == (c.file, c.first), out) || push!(out, c)
  end
  append!(out, blocks)
end

"""
What the caret was on when the command was taken is the one to change, unless
you choose another. With the caret in a paragraph, the nearest part is the
whole page, which isn't what the caret is on: the chip starts with nothing
then, and draws no line round the page. The list still offers the page.
"""
chip_start(::Type{ToChange}, e) = begin
  found = choices_for(ToChange, e)
  (isempty(found) || first(found).node isa Document) ? nothing : first(found)
end

"""
What a click at the mouse of the window `w` chooses for Ask Agent: the
nearest part of the window that a function in a file on this Mac draws. On
the page's text, it's the block of Julia code there, if there's one, unless
the mouse is on something that a file other than Ladder's own draws, like the
bar of a `progress` block.
"""
chip_click(::Type{ToChange}, e, w) = begin
  chain = Any[]
  node = text_run(under_palette(w, palette(e)), w)
  while node !== nothing
    push!(chain, node)
    node = node.parent
  end
  found = [c for x in chain for c in (part_choice(y) for y in drawn_parts(x)) if c !== nothing]
  k = findfirst(x -> x isa Document, chain)
  if k !== nothing && !any(c -> !ladder_file(c.file) && any(x -> c.node === x, chain[1:k-1]), found)
    i = locate(e, w.mouse)[1]
    blocks = code_blocks(e)
    j = findfirst(c -> c.first <= i <= c.last, blocks)
    j === nothing || return blocks[j]
  end
  isempty(found) ? nothing : first(found)
end

shown_at(e, c::ToChange) = asked_rect(e, c)

"True when `c` is the whole of its file, which ⌥↑ gives from a block of it"
whole_file(c::ToChange) = c.node === nothing && c.first == 1 && c.note == "the whole file"

"""
What holds the thing `c` of Ask Agent, for ⌥↑: for a part of the window,
the nearest part round it that a function in a file on this Mac draws, and
for a block of Julia code, the whole file that it's in. A part that covers
the same place on the screen, like one that only holds another, is passed
over, so each ⌥↑ shows a bigger line.
"""
chip_wider(c::ToChange, e) = begin
  c.node isa PickedText && return nothing
  if c.node !== nothing
    place(x) = (r = try rect(x) catch; nothing end; r === nothing ? nothing : (r.left, r.top, r.width, r.height))
    was = place(c.node)
    y = c.node.parent
    while y !== nothing
      found = part_choice(y)
      found === nothing || (found.file, found.first) == (c.file, c.first) || place(y) == was || return found
      y = y.parent
    end
    return nothing
  end
  whole_file(c) && return nothing
  b = e.buf
  n = !isempty(b.path) && page_key(b.path) == c.file ? length(b.lines) : length(text(c.file))
  ToChange(basename(c.file), "the whole file", c.file, 1, n, nothing, c.mod)
end

"""
What the thing `c` of Ask Agent is, in words for an agent, and the first
line of its code. A part of the window is told with the words that it shows
and what the window shows, so that a question about what it says, like "is
this spelt right?", has an answer: see `part_words`.
"""
thing_words(c::ToChange) = begin
  c.node isa PickedText && return ("words that the user selected in a file", picked_words(c.node))
  lines = text(c.file)
  start = 1 <= c.first <= length(lines) ? lines[code_start(lines, c.first)] : ""
  what = c.node !== nothing ? "a part of its window, a $(pick_name(c.node)).$(part_words(c.node)) The function that draws that part" :
         whole_file(c) ? "the whole of a file" :
         endswith(c.file, ".jl") ? "a block of the file's Julia code" : "a block of Julia code on a page of Markdown"
  (what, start)
end

"Where the last frame drew the part `x` of the window, or nothing when it wasn't drawn"
drawn_rect(x) = (node = shown_now(x); node === nothing ? nothing : try rect(node) catch; nothing end)

"""
The words that the part `x` of the window showed in the last frame, in the
order that it drew them: the words of each piece of text in it, no more than
1,000 characters in all. A part that draws its own text, like a paragraph of
the page, has none, and so does a part that wasn't drawn.
"""
shown_words(x) = begin
  r = drawn_rect(x)
  out, room = String[], Ref(1000)
  walk(u) = room[] <= 0 ? nothing :
    u isa ConcreteText ? (s = String(strip(replace(u.from.content, r"\s+" => " "))); isempty(s) || (push!(out, s); room[] -= length(s))) :
    u isa ConcreteRect ? foreach(walk, u.children) : nothing
  r === nothing || walk(r)
  out
end

"The file, folder or address that the window with the part `x` shows, or \"\" when `x` isn't in a window of the editor"
window_shows(x) = begin
  while x !== nothing && !(x isa Editor)
    x = try x.parent catch; nothing end
  end
  x === nothing ? "" : x.buf.path
end

"""
What an agent is told of what the part `x` of the window shows: the words in
it, and the file or folder that the window shows. Without them, the agent
can't tell which line of a list, or which button, the user means. It's "" for
a part that wasn't drawn in the last frame.
"""
part_words(x) = begin
  drawn_rect(x) === nothing && return ""
  words, shows = shown_words(x), window_shows(x)
  told = isempty(words) ? "" : " It shows these words: " * join(("\"$w\"" for w in words), ", ") * "."
  isempty(shows) ? told : told * " The window shows $shows."
end

"What an agent is told after it's told what to change: the user's words, and how to change the files in the folders `dirs`"
change_ask(words, dirs) = """
  The user's words: $words

  Change that code, or the code that it uses, as the user asks. Change only files in $(join(dirs, " and ")). Keep the change small, and write code that looks like the code around it. Ladder runs the changed code as soon as you end, so leave the file in a state that runs. Then say what you changed, in one short sentence.
  """

"What an agent is told when a change to `c` is asked for: what it is, where its code is, and the user's words"
change_prompt(c::ToChange, words) = begin
  what, start = thing_words(c)
  """
  The user of the app Ladder asked for a change to $what.

  It's in the file $(c.file), lines $(c.first) to $(c.last). It starts:

      $start

  """ * change_ask(words, [dirname(c.file)])
end

"""
What an agent is told when a change to several things is asked for. The window
marks each with a letter, A, B and on, so the user's words can name them so.
"""
change_prompt(cs::AbstractVector, words) = begin
  length(cs) == 1 && return change_prompt(only(cs), words)
  parts = map(enumerate(cs)) do (n, c)
    what, start = thing_words(c)
    "$('A' + n - 1): $what, in the file $(c.file), lines $(c.first) to $(c.last). It starts:\n\n    $start\n"
  end
  """
  The user of the app Ladder asked for a change. The user marked these things in the window with letters, and the user's words can name them by their letters:

  $(join(parts, "\n"))
  """ * change_ask(words, unique(dirname(c.file) for c in cs))
end

"The text of each part of the Julia code of `lines`, with the line that the part starts on: see `read_parts`"
part_texts(lines::Vector{String}) = begin
  ps = read_parts(lines, 1)
  [(p.first, String(rstrip(join(view(lines, p.first:(k == length(ps) ? length(lines) : ps[k+1].first - 1)), "\n")))) for (k, p) in enumerate(ps)]
end





"""
A change that an agent was asked to make to `places`, the things of Ask
Agent. `before` and `after` have the text of each file that the things are
in, before the agent started and after it ended. `said` is what there is to
say when it has ended, at the time `ended`. `label` is where the label with
those words was drawn last, for a click on it. `undone` is true once Undo
Change put its files back. `step` is what the agent is doing now, in a few
words. `stopped` is true when you stopped the agent before it ended.

A change that went to the agent that works on a page with you has the
agent's name in `by`, and the page's path in `page`: see "ask the agent of the
page". `sent` is true once the agent has it. `talk` has the questions that
were asked about the things before, each with its answer: see `follow_up!`.

`asks` is true when the words can ask a question as well as for a change, as
Ask Agent's do: see "ask an agent". An answer that changes nothing then shows
in a card: see "the card of an answer".
"""
@def mutable struct AskedChange
  words::String = ""
  places::Vector{Any} = Any[]
  before::Dict{String,String} = Dict{String,String}()
  after::Dict{String,String} = Dict{String,String}()
  process::Any = nothing
  out::Any = nothing         # a task that reads what the agent prints
  gone::Float64 = 0.0        # when the agent's process was first seen to have ended
  step::String = ""
  said::String = ""
  failed::Bool = false
  changed::Bool = false
  ended::Float64 = 0.0
  label::Any = nothing
  undone::Bool = false
  stopped::Bool = false
  by::String = ""
  page::String = ""
  sent::Bool = false
  talk::Vector{Tuple{String,String}} = Tuple{String,String}[]
  asks::Bool = false
  reply::String = ""         # the file that the page's agent writes its answer to, for words that can be a question
  session::Any = nothing     # the session that works on it, for an agent whose program stays: see "a request that a session answers"
  mark::Int = 0              # how many things that session held when it got the request. What comes after is about the request.
end

"Each change that an agent made since Ladder started, the last last, for Show Change and Undo Change"
const AGENT_CHANGES = AskedChange[]

"""
Where the window of `e` shows what an agent is changing, `c`: the part of the
window, or the lines of the block while the window shows its file. It's
nothing when the window shows neither.
"""
asked_rect(e, c::ToChange) = begin
  c.node isa PickedText && return picked_box(e, c)
  if c.node !== nothing
    # A paragraph or a heading of the page is made again on each frame, so it's this frame's one that shows
    node = shown_now(c.node)
    return node === nothing ? nothing : try rect(node) catch; nothing end
  end
  b = e.buf
  (!isempty(b.path) && page_key(b.path) == c.file && !isempty(e.layout) && c.first <= c.last <= length(b.lines)) || return nothing
  top, bottom = item(e, c.first), item(e, c.last)
  y = e.origin[2] + top.top
  (left=e.origin[1] - 8px, top=y, width=e.width + 16px, height=e.origin[2] + bottom.top + bottom.tall - y)
end

asked_rect(e, ::Nothing) = nothing



"""
Ask an agent to make the change to the things `places` that `words` say. The
picker of the window of `e` shows how it goes. `prompt` is what the agent is
told, when it's other than the words that ask for a change, as for Fix Check.
`talk` has the questions that were asked about the things before, each with
its answer.
"""
ask_change!(e, places::AbstractVector, words::AbstractString; prompt=change_prompt(places, words), asks=false, talk=follow_up!(e, places)) = begin
  t = code_picker(e)
  files = unique(c.file for c in places)
  # The agent reads the files, so what a window shows of one and didn't write goes to its file first
  for o in editors
    !isempty(o.buf.path) && page_key(o.buf.path) in files && dirty(o.buf) && writes(o.buf) && save!(o.buf)
  end
  before = Dict(f => read(f, String) for f in files)
  a = AskedChange(words=words, places=collect(places), before=before, asks=asks, talk=talk)
  # What you asked about the things before, from the card of an answer, goes with your words
  prompt *= talk_words(talk)
  try
    if asks_session(e)
      # An agent whose program stays gets the request in a session of the window: see "a request that a session answers"
      ask_in!(a, ask_session!(e, dirname(first(files))), prompt)
    else
      a.process, a.out = start_agent(agent_command(e), prompt, dirname(first(files)), a)
    end
  catch err
    a.said, a.failed, a.ended = "The agent didn't start. " * trouble(err), true, time()
  end
  t.asked = a
  redraw_in!(e, 0)
  nothing
end

ask_change!(e, c::ToChange, words::AbstractString) = ask_change!(e, [c], words)

"The last lines of what an agent printed that have words: what it said of its change"
agent_said(printed::AbstractString) = begin
  parts = filter(!isempty, strip.(split(printed, r"\n\s*\n")))
  isempty(parts) ? "" : String(replace(last(parts), r"\s+" => " "))
end

"""
Run the code of each file in `texts`, a file's text by its path, that's new
since the file had that text, in the module that the things `places` say for
it. It gives how many parts ran, and what went wrong with the first that
failed, or "".
"""
reload_files!(places, texts::Dict{String,String}) = begin
  ran, failed = 0, ""
  for (f, was) in texts
    k = findfirst(c -> c.file == f, places)
    n, why = reload_changed!(k === nothing ? nothing : places[k].mod, f, text_lines(was))
    ran += n
    isempty(failed) && (failed = why)
  end
  (ran, failed)
end

"""
The agent that worked on the request `a` has ended, well or not, and
`printed` is what it said. Ladder runs the code that it changed, and the
label of the thing says how it went. An answer to a question shows under
the words that it's about, or in a card beside the thing.
"""
ask_ended!(e, t::CodePicker, a::AskedChange, printed::AbstractString, well::Bool) = begin
  # What an agent that you stopped changed can be half done, so it doesn't run
  ran, failed = a.stopped ? (0, "") : reload_files!(a.places, a.before)
  a.after = Dict(f => read(f, String) for f in keys(a.before) if isfile(f))
  a.changed = a.after != a.before
  a.failed = !well || !isempty(failed)
  a.said = a.stopped ? (a.changed ? "You stopped the agent. Ladder didn't run what it changed. Undo Change puts it back." : "You stopped the agent. Nothing changed.") :
           !well ? "The agent stopped. " * agent_said(printed) :
           !isempty(failed) ? "The new code doesn't run. " * failed :
           !a.changed ? "Nothing changed. " * agent_said(printed) : agent_said(printed)
  a.ended = time()
  a.changed && push!(AGENT_CHANGES, a)
  # Words that asked a question get the agent's answer in a card beside the thing
  if a.asks && !a.changed && !a.failed && !a.stopped
    said = String(strip(printed))
    if !isempty(a.places) && first(a.places).node isa PickedText
      # A question asked in place is answered in place, under its words: see "a request in place"
      a.said = "$(isempty(a.by) ? e.ai : a.by) answered."
      show_answer!(e, a, isempty(said) ? "The agent said nothing." : said)
    else
      said = strip(replace(said, "**" => ""))
      card!(e, AskedAbout(words=a.words, places=a.places, talk=a.talk, answer=isempty(said) ? "The agent said nothing." : String(said)))
      t.asked = nothing
    end
  end
  a
end

"In each frame: when the agent that was asked for a change has ended, run the code that it changed, and say how it went"
ask_tick!(e) = begin
  t = made_picker(e)
  t isa CodePicker || return nothing
  queue_tick!(e, t)
  t.asked === nothing && return nothing
  a = t.asked
  a.ended == 0 && a.session !== nothing && return session_ask_tick!(e, t, a)
  a.ended == 0 && !isempty(a.by) && return sharer_tick!(e, t, a)
  if a.ended == 0
    yield()   # the agent's end is noticed by a task, which gets its turn here
    process_exited(a.process) && a.gone == 0 && (a.gone = time())
    # What it printed is all read a moment after it ends. A program that it left running can hold that up, so the wait has an end.
    if a.gone > 0 && (istaskdone(a.out) || time() - a.gone > 2)
      ask_ended!(e, t, a, agent_text(istaskdone(a.out) && !istaskfailed(a.out) ? fetch(a.out) : ""), success(a.process))
    end
    redraw_in!(e, 0.1)
  elseif time() - a.ended > (a.failed ? 15 : 8)
    t.asked = nothing
    redraw_in!(e, 0)
  else
    redraw_in!(e, 0.5)
  end
  nothing
end

# --- ask an agent ---
#
# Ask Agent takes a thing (see "ask for a change to a thing"), and words that
# ask for a change or ask a question: "make this bar thinner", or "why is
# this bar red?". The agent does what the words ask. A change shows with a
# label on the thing, and an answer shows in a card beside the thing: see "the
# card of an answer".
# The line round a thing that a click with ⌘ and ⌥ down chose has a button
# for it, which is the agent's logo: see `CODE_BUTTONS`. The agent is the one
# that shares the page, if one does, or else the one that Settings chose.

"What an agent is told when the user's words `words` about the things `cs` can ask for a change, or ask a question"
either_prompt(cs::AbstractVector, words) = begin
  parts = map(enumerate(cs)) do (n, c)
    what, start = thing_words(c)
    "$('A' + n - 1): $what, in the file $(c.file), lines $(c.first) to $(c.last). It starts:\n\n    $start\n"
  end
  marked = length(cs) == 1 ? "marked this thing in its window as A" : "marked these things in its window with letters, and the user's words can name them by their letters"
  """
  The user of the app Ladder $marked:

  $(join(parts, "\n"))
  The user's words: $words

  The words ask for a change, or ask a question. For a change, change that, or the code that it uses. Change only files in $(join(unique(dirname(c.file) for c in cs), " and ")). Keep the change small, and write code that looks like the code around it. Ladder runs the changed code as soon as you end, so leave the file in a state that runs. Then say what you changed, in one short sentence.

  For a question, don't change any file. Read the code, or the files that the window shows, to find the answer. Answer in a few short sentences of plain words, with no Markdown, as the answer shows in a small card beside the thing.
  """
end

"""
Words of a file that you selected, as a thing of Ask Agent: the words, and
where they start and end. The page's menu gives them: see `ask_selected!`.
"""
struct PickedText
  text::String
  from::Tuple{Int,Int}
  to::Tuple{Int,Int}
end

"The words of `t` for an agent to read, each line after the first indented, and no more than 2,000 characters"
picked_words(t::PickedText) = (s = length(t.text) > 2000 ? first(t.text, 1999) * "…" : t.text; replace(s, "\n" => "\n    "))

"The words of the page in `b` from `lo` to `hi`, as a thing of Ask Agent, or nothing when they're only spaces"
words_thing(b, lo, hi) = begin
  text = excerpt(b, lo, hi)
  isempty(strip(text)) && return nothing
  short = replace(strip(text), r"\s+" => " ")
  # A selection of whole lines ends at the start of the line after them
  stop = hi[2] == 0 && hi[1] > lo[1] ? hi[1] - 1 : hi[1]
  ToChange("“" * (length(short) > 40 ? first(short, 39) * "…" : short) * "”", "selected · line $(lo[1])",
           page_key(b.path), lo[1], stop, PickedText(text, lo, hi), nothing)
end

"The words that are selected in the window of `e`, as a thing of Ask Agent, or nothing when none are"
selected_thing(e) = (b = e.buf; selecting(b) && !isempty(b.path) ? words_thing(b, selection(b)...) : nothing)

"""
The words of the line that the caret is on, as a thing of Ask Agent, or nothing
for a line with no words. When the caret is on a part as a whole, like a
formula on lines of its own, it's all of the part's lines.
"""
line_thing(e) = begin
  b = e.buf
  isempty(b.path) && return nothing
  s, t = something(picked(b), (b.caret[1], b.caret[1]))
  words_thing(b, (s, 0), line_end(b, t))
end

"""
The places in the window of `e` that show the words of `c`, which you
selected: a rectangle for each run of them on a line as it's laid out. A part of
the page that doesn't show its line as words, like a table, gives all of its place.
"""
picked_rects(e, c::ToChange) = begin
  t = c.node::PickedText
  b = e.buf
  out = NamedTuple{(:left, :top, :width, :height),NTuple{4,px}}[]
  (!isempty(b.path) && page_key(b.path) == c.file && !isempty(e.layout) && t.to[1] <= length(b.lines)) || return out
  x, y = e.origin
  seen = Set{Int}()
  for i in t.from[1]:t.to[1]
    it = item(e, i)
    f = it.content
    if f isa Flow && it.first == it.last
      from, to = i == t.from[1] ? t.from[2] : 0, i == t.to[1] ? t.to[2] : length(b.lines[i])
      for (x1, x2, top, high) in stretches(f, from, to)
        push!(out, (left=x + x1, top=y + it.top + top, width=x2 - x1, height=high))
      end
    elseif !(it.first in seen)
      push!(seen, it.first)
      push!(out, (left=x, top=y + it.top, width=e.width, height=it.tall))
    end
  end
  out
end

"The box round the words of `c`, which you selected, in the window of `e`, or nothing when they don't show"
picked_box(e, c::ToChange) = begin
  rs = picked_rects(e, c)
  isempty(rs) && return nothing
  left, top = minimum(r.left for r in rs) - 3px, minimum(r.top for r in rs) - 1px
  right, bottom = maximum(r.left + r.width for r in rs) + 3px, maximum(r.top + r.height for r in rs) + 1px
  (left=left, top=top, width=right - left, height=bottom - top)
end

# --- a request in place ---
#
# Ask Claude… in the page's menu draws a box round the words that are
# selected, or round the caret's line when none are, and a field under them for
# what you want. Return gives the words and what you typed to the agent, as Ask
# Agent does. The box stays round the words while the agent works, with a
# label that says how it goes, and then what the agent did or its answer. A
# click on the label opens the field, with the questions and answers about the
# words, and what the agent is doing. The × at the end of the label takes the
# box away, with its field and answers, and stops an agent that Ladder started
# for it.
# The Close button closes only the field: the box stays, and a click on its
# label opens the field again. A field with no answer and nothing typed in it
# goes with its box. Nothing else closes a field: not Esc, not a click on the
# page or on the field, and not another field that opens, as all are easy to
# do by mistake. The field keeps what you typed, and a click in it gives it
# the keyboard again. A click on the field goes to the field, even where a
# request's label is under it. The field follows its words as the page
# scrolls.
#
# An answer stays until you click the × on its box, so that you never lose
# one that you haven't read. Each of the words that you asked about has a
# field of its own, and the fields of other words stay open while you ask
# about these. A question that you ask in the field of an answer hides the
# field while the agent works on it, and the field shows again with the new
# answer under the ones before. If the request ends with no answer, as when
# you stop the agent, the field shows again as it was. An answer to
# another question about the same words. When the window shows another file,
# each field hides until the page shows again.

const ASK_BOXES = :ask_boxes   # the key in a page's editor of its fields of requests in place
const ASK_BOX_W = 380px
const ASK_TEXT_W = ASK_BOX_W - 32px   # how wide the text of the field is, inside the popup's padding and the field's
const ASK_TEXT = 13px                 # how big the text of the field is, before the page's zoom

"""
The field under the words that you selected, for a request to the agent. Its
text is an editor of its own, as a part of another page has (see
`part_editor`), so the keys work in it as they do in a page: ↑ and ↓ go from
line to line, ⌘Z takes a change back, and long lines wrap.
"""
@def mutable struct AskBox <: SemanticUI
  of::Any = nothing                       # the editor
  thing::Any = nothing                    # the words, as a thing of Ask Agent
  side::Symbol = :bottom                  # the side of the words that it's on
  error::String = ""                      # why the last request didn't go, or ""
  parts::Dict{Any,Any} = Dict{Any,Any}()  # the editor of its text, as :text
  answers::Vector{Any} = Any[]            # the agent's answers about the words, oldest first, over the field: see `box_answer`
  editing::Any = nothing                  # the request that waits, whose words the field changes, or nothing: see "change a request that waits"
  sent::Bool = false                      # a question from the field went to the agent, so it hides until the answer comes: see `send_ask!`
  closed::Bool = false                    # its Close button hid it, and a click on the label of its box shows it again: see `hide_ask!`
  label::Any = nothing                    # where the label of the box round its words was drawn last, for a click on it, or nothing
end

"An answer of an agent in the field of a request in place: the question `asked`, the agent's `answer` in Markdown, and who answered"
box_answer(asked, answer, by) = (asked=String(asked), answer=String(answer), by=String(by))

"The fields of requests in place that the editor `e` of a page shows, in the order they opened"
ask_boxes(e) = get(e.nodes, ASK_BOXES, AskBox[])

"The key of the popup of the field `a`. Each field has a popup of its own."
box_key(a::AskBox) = Symbol("ask_box_", objectid(a))

"The field of the request in place about the thing `c`, or nothing when `c` has none"
box_about(e, c) = (k = findfirst(a -> a.editing === nothing && same_things([a.thing], [c]), ask_boxes(e)); k === nothing ? nothing : ask_boxes(e)[k])

"Put the agent's answer `x` under the answers of the field `a`, and scroll to it. A field that hid while the agent worked shows again."
add_answer!(a::AskBox, x) = (push!(a.answers, x); a.sent = a.closed = false; a.parts[:to_end] = true; redraw_in!(a.of, 0); a)

"True while a request about the words of the field `a` waits in the queue, or an agent works on it"
asking_about(e, a::AskBox) = begin
  t = code_picker(e)
  any(((q, _),) -> same_things(q.places, [a.thing]), ask_queue(e)) ||
    (t.asked !== nothing && t.asked.ended == 0 && !t.asked.stopped && same_things(t.asked.places, [a.thing]))
end

"The editor of the text of the field `a` of a request in place: lines that no file holds, in the window's colours, at a field's size"
ask_editor(a::AskBox) = begin
  e = a.of
  sub = small_editor(a)
  follow_host!(sub, e)
  sub.font, sub.zoom, sub.look = SANS, e.zoom * ASK_TEXT / TEXT_SIZE, :own
  sub
end

"""
What a key does in the text of a request in place, before its editor does
what it does with a key: `handled` when the key is done with, or :text when
it's the editor's. Return gives the request to the agent, and ⇧Return starts
a new line. A command for the window runs in the window's page. Esc does
nothing: only the Close button closes the field.
"""
owner_key!(a::AskBox, e, w, K, command, select) = begin
  K == Keys.enter && unmodified(w) && (send_ask!(a, w); return handled)
  K == Keys.escape && return handled
  command !== nothing && command_kind(command) == :window && (run!(a.of, w, command, false); return handled)
  :text
end

"""
Draw a box round the words that are selected, or the caret's line, and open
a field under them for a request to the agent. The item Ask Agent… of the
page's menu does this, with the agent's name. See "a request in place".
"""
ask_selected!(e) = begin
  c = something(selected_thing(e), Some(line_thing(e)))
  c === nothing && return nothing
  # Words that have a field already, with an answer or with what you typed, give it the keyboard. One that hid while
  # the agent works on a question from it, or that its Close button hid, shows again.
  a = box_about(e, c)
  a === nothing || (a.sent = a.closed = false)
  a === nothing && (a = open_ask!(e, AskBox(of=e, thing=c)))
  a === nothing || focus(a.parts[:text])
  nothing
end

"""
Show the agent's answer `said` to the question of the request `a` under its
words, with a field under the answer to ask more. When the words have a
field already, the answer goes in it, under the answers before. The keyboard
stays where it is. When the thing doesn't show now, the answer is in a card,
so that it's never lost. See "a request in place".
"""
show_answer!(e, a::AskedChange, said) = begin
  isempty(a.places) && return nothing
  x = box_answer(a.words, said, isempty(a.by) ? e.ai : a.by)
  had = box_about(e, first(a.places))
  had === nothing || (add_answer!(had, x); return nothing)
  shown = open_ask!(e, AskBox(of=e, thing=first(a.places), answers=Any[x]))
  shown === nothing && card!(e, AskedAbout(words=a.words, places=a.places, talk=a.talk, answer=said))
  nothing
end

"""
Show the field `a` under its words: it gives `a`, or nothing when the words
don't show. The fields that show already stay, even those with nothing in
them: only a field's Close button takes it away, so that no click by mistake
loses what you typed. `anyway` keeps `a` when its words don't show, and it
shows when they do.
"""
open_ask!(e, a::AskBox; anyway=false) = begin
  w = window_of(e)
  r = w === nothing ? nothing : box_place(e, a)
  r === nothing && !anyway && return nothing
  new_field!(a)
  push!(get!(Vector{AskBox}, e.nodes, ASK_BOXES), a)
  r === nothing || show_ask!(e, w, a, r)
  redraw_in!(e, 0)
  a
end

"Give the field `a` a new editor for its text, with nothing in it"
new_field!(a::AskBox) = (a.parts[:text] = ask_editor(a))

"Show the popup of the field `a` in the window `w` of `e`, under the place `r` of its words"
show_ask!(e, w, a::AskBox, r) =
  # It isn't modal, so a click on the page goes to the page and leaves the field as it is
  popup!(w, a, anchor=(r.left, r.top, r.width, r.height), placement=:bottom, gap=9px, width=ASK_BOX_W, key=box_key(a),
         theme=component_theme(), modal=false, onclose=() -> forget_ask!(e, a))

"Stop keeping the field `a` of `e`"
forget_ask!(e, a::AskBox) = (haskey(e.nodes, ASK_BOXES) && filter!(o -> o !== a, e.nodes[ASK_BOXES]); redraw_in!(e, 0); nothing)

const ANSWER_MAX_H = 320px   # the most of an answer that shows over the field at once. A longer one scrolls.

"The lines of the answer `text`, laid out as the page's text is, a little smaller, as wide as the field of a request in place of `e`"
answer_flows(e, text) = begin
  lines = String.(split(text, '\n'))
  ks = classify(lines)
  zoom = e.zoom
  e.zoom = zoom * PAGE_ZOOM
  try
    [laid(e, lines[i], ks[i], false, -1, ASK_TEXT_W * zoom) for i in eachindex(lines)]
  finally
    e.zoom = zoom
  end
end

"""
The requests about the words of the field `a` that have no answer yet: the one
that an agent works on, and those that wait. Each is its words, and how it
goes, like "Grok is working on it.".
"""
unanswered(e, a::AskBox) = begin
  t = code_picker(e)
  out = Tuple{String,String}[]
  x = t.asked
  if x !== nothing && x.ended == 0 && !x.stopped && on_box(x, a)
    who = isempty(x.by) ? e.ai : x.by
    push!(out, (x.words, !isempty(x.by) && !x.sent ? "$who gets it when it waits for the page again." :
                         isempty(x.step) ? "$who is working on it." : "$who is working on it: $(x.step)"))
  end
  for (n, (q, _)) in enumerate(ask_queue(e))
    on_box(q, a) && push!(out, (q.words, "Number $n in the queue."))
  end
  out
end

"True when the label of the request `q` is on the words of the field `a`: its first thing is their thing"
on_box(q, a::AskBox) = !isempty(q.places) && same_things(q.places[1:1], [a.thing])

"""
What shows over the field of `a` when it has the agent's answers, or
requests about its words that have none yet: who answered, the answers, which
scroll when they're long, and then each request that waits with how it goes.
With more than one, each answer has the question that it answers over it, and
a new one scrolls into sight.
"""
answer_part(a::AskBox) = begin
  e = a.of
  dim = found_colours().dim
  face = Face(SANS, "", 12px, dim, false)
  waits = unanswered(e, a)
  several = length(a.answers) + length(waits) > 1
  rows, total = Any[], 0px
  # Lines of `words` in the colour `colour`, wrapped to the field's width, and a gap between two answers or requests
  say(words, colour) = for l in wrapped(Face(face, color=colour), replace(words, r"\s+" => " "), num(ASK_TEXT_W))
    push!(rows, Row(height(17px), Alignment.Center, label(l, 12px, color=colour)))
    total += 17px
  end
  gap() = isempty(rows) || (push!(rows, Box(width(grow=grow), height(12px))); total += 12px)
  for (k, x) in enumerate(a.answers)
    several && (gap(); say("You asked: " * x.asked, dim))
    flows = get!(() -> answer_flows(e, x.answer), a.parts, (:answer, k, x.answer, e.zoom, e.theme))
    append!(rows, [describe(e, Item(0, 0, 0px, tall(f), f), f) for f in flows])
    total += sum(tall, flows, init=0px)
  end
  for (words, goes) in waits
    gap()
    say("You asked: " * words, dim)
    say(goes, colours.ink)
  end
  scroll = get!(() -> Scroll(width(grow=grow)), a.parts, :answer_scroll)
  scroll.height = height(min(total, ANSWER_MAX_H))
  pop!(a.parts, :to_end, false) && (scroll.offset = max(0px, total - ANSWER_MAX_H))
  reuse!(scroll, Column(width(grow=grow), Alignment.Start, rows...))
  heading = isempty(a.answers) ? () :
    (Row(height(20px), Alignment.Center, label(length(a.answers) > 1 ? "$(last(a.answers).by)'s answers" : "$(last(a.answers).by)'s answer", 12px, color=dim)),)
  Column(width(grow=grow), Alignment.Start, child_gap=2px, padding(4px, 8px, 6px, 10px),   # top, right, bottom, left
    heading..., scroll)
end

# It looks as the floating lists do (see `float_list`), with a field that's as tall as its lines
describe(a::AskBox) = begin
  c = found_colours()
  e = a.of
  note = !isempty(a.error) ? a.error : a.editing !== nothing ? waits_note(e, a.editing) : "Return asks $(asks_whom(e)). ⇧Return adds a line."
  face = Face(SANS, "", 12px, isempty(a.error) ? c.dim : PICK_FAILED, false)
  # The note wraps before the buttons at its right: Close, and Take Back for a request that waits
  room = num(ASK_BOX_W) - (a.editing === nothing ? 110 : 200)
  rows = [Row(height(17px), Alignment.Center, label(l, 12px, color=face.color)) for l in wrapped(face, note, room)]
  # The text is laid out as a page is, as wide as the field
  sub = a.parts[:text]
  layout!(sub, ASK_TEXT_W * e.zoom)
  tall = isempty(sub.layout) ? ASK_TEXT * e.zoom : lowest(sub, sub.layout)
  doc = Box(width(grow=grow), height(tall), Alignment.Start, node!(Document, sub, :document))
  # With nothing typed, the field says what it's for, under where the text goes
  empty = sub.buf.lines == [""]
  prompt = isempty(a.answers) ? "Ask $(asks_whom(e)) for a change, or ask a question" : "Ask $(asks_whom(e)) more, or for a change"
  text = empty ? Stack(width(grow=grow), height(tall), Alignment.Start,
                       Row(width(grow=grow), height(tall), Alignment.Center, label(prompt, ASK_TEXT * e.zoom, color=colours.faint)), doc) : doc
  field = Box(width(grow=grow), padding(2px, 2px),
              Box(width(grow=grow), padding(8px, 7px), radius(6px), border(1px, :solid, c.line), background(c.frame), text))
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Ask",
    Column(width(grow=grow), Alignment.Start, child_gap=4px, (isempty(a.answers) && isempty(unanswered(e, a)) ? () : (answer_part(a),))..., field,
      Row(width(grow=grow), padding(4px, 2px, 4px, 8px), Alignment.Center, child_gap=6px,   # top, right, bottom, left
        Column(width(grow=grow), Alignment.Start, rows...),
        (a.editing === nothing ? () : (get!(() -> own!(a, AskTakeBack(of=a)), a.parts, :take_back),))...,
        get!(() -> own!(a, AskClose(of=a)), a.parts, :close))))
end

"""
The button at the bottom right of the field of a request in place, that
closes the field. The box round its words stays when the field has answers
or words that you typed, and a click on the box's label shows the field
again. Nothing else closes the field: not Esc, not a click on the page, and
not another field that opens.
"""
@def mutable struct AskClose <: SemanticUI
  of::Any = nothing
end

"A button at the bottom of the field of a request in place, with a line round it so that it looks like one: `inside` is what it shows"
field_button(x, name, inside...) =
  Box(height(24px), padding(10px, 0px), radius(6px), Alignment.Center, name=name, border(1px, :solid, colours.line),   # across, down
      background(ishovered(x) ? colours.hover : clear), inside...)

describe(x::AskClose) = field_button(x, "Close",
  Row(height(24px), Alignment.Center, child_gap=6px, Icon("x-lg", size=10px, color=colours.ink), label("Close", 12px)))
cursor(::AskClose) = :hand
onkey(x::AskClose, ev::KeyPress{Keys.mouse_left}) = hide_ask!(x.of, ev.window)
# A tooltip in a popup is put by its rectangle: the form that takes a node closes at once there
onmouse(x::AskClose, ev::MouseMove) = begin
  r = rect(x)
  tip = hides_on_close(x.of) ? "Close this. A click on the label of the box round the words opens it again." :
        x.of.editing === nothing ? "Close without asking" : "Close, and leave the request as it was"
  r === nothing || show_tooltip!(ev.window, tip_label(tip), r.left, r.top, r.width, r.height; placement=:bottom, gap=6px)
  handled
end

placed!(a::AskBox, side) = (a.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, a::AskBox) = caret(ctx, ui, a.side, box_place(a.of, a))

"""
Where the field `a` of `e` goes under: its words, or, when they don't show,
the label of a request about them, as a thing that doesn't show has its
label under the top bar. Nothing when neither shows.
"""
box_place(e, a::AskBox) = begin
  r = asked_rect(e, a.thing)
  r === nothing || return r
  for q in labelled_requests(code_picker(e))
    if on_box(q, a) && q.label !== nothing
      left, top, wide, tall = q.label
      return (left=px(left), top=px(top), width=px(wide), height=px(tall))
    end
  end
  nothing
end

# --- change a request that waits ---
#
# A request waits while an agent works on one before it (see "a queue of
# requests"), or until the agent of the page waits for it again (see "ask the
# agent of the page"). A click on its label opens a field under its thing, as
# a request in place has, with its words in it. Return gives the request the
# words of the field, and it keeps its place. Take Back takes the request
# out, and Close leaves it as it was. If the request starts before you press
# Return, the field says so, and Return then asks with the field's words as a
# new request.

"True while the request `a` of the window of `e` waits, so that its words can change: in the queue, or for the agent of the page to wait again"
waiting(e, a::AskedChange) =
  any(((x, _),) -> x === a, ask_queue(e)) || (code_picker(e).asked === a && a.ended == 0 && !isempty(a.by) && !a.sent && !a.stopped)

"Open a field under the thing of the request `a`, which waits, with its words in it, or give the keyboard to the field that it has"
edit_request!(e, a::AskedChange) = begin
  isempty(a.places) && return nothing
  k = findfirst(o -> o.editing === a, ask_boxes(e))
  o = k === nothing ? open_ask!(e, AskBox(of=e, thing=first(a.places), editing=a); anyway=true) : ask_boxes(e)[k]
  k === nothing && edit!(o.parts[:text].buf, (1, 0), (1, 0), a.words)
  # A thing that doesn't show has its field when it shows
  box_place(e, o) === nothing || focus(o.parts[:text])
  redraw_in!(e, 0)
  nothing
end

"""
True while the request of the field `a` waits. Once it has started, the field
says so, and becomes a field for a new request, with the words that it has.
"""
still_waits!(a::AskBox) = begin
  waiting(a.of, a.editing) && return true
  a.error = "$(asks_whom(a.of)) started on it before you changed it. Return asks again with these words."
  a.editing = nothing
  redraw_in!(a.of, 0)
  false
end

"What the field of the request `a`, which waits, says under its words"
waits_note(e, a::AskedChange) = begin
  k = findfirst(((x, _),) -> x === a, ask_queue(e))
  k === nothing ? "Return changes the request. $(a.by) gets it when it waits for the page again." :
                  "Return changes the request. It stays number $k in the queue."
end

"The prompt `prompt` of a request whose words were `words`, after you changed them to `said` while it waited: it ends with your words"
reworded(prompt, words, said) = said == words ? prompt : prompt * "\nThe user's own words about this: $said\n"

"Take the request `a` back while it waits: out of the queue, or from the agent of the page, which then no longer shares the page"
take_back!(e, a::AskedChange) = begin
  q = ask_queue(e)
  k = findfirst(((x, _),) -> x === a, q)
  k === nothing ? (waiting(e, a) && stop_agents!(e, Any[a])) : deleteat!(q, k)
  redraw_in!(e, 0)
  nothing
end

"The button beside Close in the field of a request that waits, that takes the request back"
@def mutable struct AskTakeBack <: SemanticUI
  of::Any = nothing
end

describe(x::AskTakeBack) = field_button(x, "Take Back", label("Take Back", 12px))
cursor(::AskTakeBack) = :hand
onkey(x::AskTakeBack, ev::KeyPress{Keys.mouse_left}) = begin
  a = x.of
  a.editing === nothing || take_back!(a.of, a.editing)
  close_ask!(a, ev.window)
end

# The keys go to the editor of its text: see `owner_key!` of an AskBox

"""
Give the agent what was typed in the field of `a`, about its words. If the
agent can't take it, the field stays and says why. A field with answers hides
while the agent works, and shows again with the new answer under them, or
as it was when the request ends with no answer: only its Close button takes
it away.
"""
send_ask!(a::AskBox, w) = begin
  words = String(strip(join(a.parts[:text].buf.lines, "\n")))
  isempty(words) && return handled
  # The field of a request that waits gives it the new words: see "change a request that waits"
  if a.editing !== nothing
    still_waits!(a) || return handled
    a.editing.words = words
    return close_ask!(a, w)
  end
  # A question after an answer goes with the questions and the answers before it: see `follow_up!`
  isempty(a.answers) || (state_of(a.of, AsksState).follow_up = (places=[a.thing], talk=[(x.asked, x.answer) for x in a.answers]))
  try
    ask_agent!(a.of, a.thing, words)
  catch err
    a.error = trouble(err)
    return handled
  end
  isempty(a.answers) && return close_ask!(a, w)
  a.error = ""
  new_field!(a)
  a.sent = true
  close_popup!(w, box_key(a))
  focus(a.of)
  redraw_in!(a.of, 0)
  handled
end

"""
In each frame, for the field of a request in place `a`: draw the box round
its words, with its label, and keep the field under them as the page scrolls.
When the window shows another file, the field of words of that page hides,
and shows again with the page. A field that opened while its words didn't
show shows when they do. A field that its Close button hid stays hidden: its
box and label stay. `placed` has the labels drawn already, which the box's
label moves off.
"""
ask_box_tick!(ctx, w, e, a::AskBox, placed=nothing) = begin
  b = e.buf
  key = box_key(a)
  shown = any(p -> p.key == key, popups(w))
  a.label = nothing
  # Words of the page are in its file. A part of the window is in the file of the code that draws it.
  away = a.thing.node isa PickedText && (isempty(b.path) || page_key(b.path) != a.thing.file)
  if away
    shown && close_popup!(w, key)
    return nothing
  end
  # A field that a question went from hides while the agent works on it, and the request has its own line and label.
  # It shows again when the answer comes, or when the request ends with none.
  if a.sent
    asking_about(e, a) && (shown && close_popup!(w, key); return nothing)
    a.sent = false
  end
  r = box_place(e, a)
  # A request that waits has its own line and label, and so does any request about the words, whose label is the box's
  if a.editing !== nothing
    still_waits!(a)
  elseif r !== nothing && !labelled_box(e, a)
    a.label = pick_mark(ctx, w, r, box_label(a); avoid=placed, close=true)
  end
  r === nothing && return nothing
  a.closed && (shown && close_popup!(w, key); return nothing)
  shown || (show_ask!(e, w, a, r); redraw_in!(e, 0); return nothing)
  for p in popups(w)
    p.key == key && (p.anchor = (r.left, r.top, r.width, r.height))
  end
  nothing
end

"What the label of the box round the words of the field `a` says. A field that its Close button hid opens with a click on it."
box_label(a::AskBox) = begin
  n = length(a.answers)
  name = n == 0 ? "Ask $(asks_whom(a.of))" : n == 1 ? "$(last(a.answers).by)'s answer" : "$(last(a.answers).by)'s answers"
  a.closed ? name * "  ·  Click to open" : name
end

"""
The requests of the window of the picker `t` that have a label on their thing:
the one that an agent works on or ended a moment ago, those that wait in the
queue, and those that ended while others waited.
"""
labelled_requests(t::CodePicker) = begin
  out = Any[]
  t.asked === nothing || push!(out, t.asked)
  foreach(((q, _),) -> push!(out, q), ask_queue(t.editor))
  append!(out, asks_ended(t.editor))
end

"Where each label of a request, and of the box round the words of a field, was drawn last, for a click on it"
mark_labels(t::CodePicker) = Any[(x.label for x in labelled_requests(t))..., (o.label for o in ask_boxes(t.editor))...]

"True when the field of the words of the request `a` shows in the window `w` of `e`"
box_shows(e, w, a::AskedChange) = begin
  o = isempty(a.places) ? nothing : box_about(e, first(a.places))
  o !== nothing && any(p -> p.key == box_key(o), popups(w))
end

"""
Over the × at the end of the label of a request, or of the box round the
words of a field, show a tooltip that says what a click on it does, and tint
the ×. True while the mouse is over one, so that the page doesn't take the move.
"""
close_tip!(t::CodePicker, w) = begin
  e = t.editor
  mx, my = num(w.mouse[1]), num(w.mouse[2])
  over(r) = r !== nothing && (s = close_spot(r); s[1] <= mx <= s[1] + s[3] && s[2] <= my <= s[2] + s[4])
  marks = Any[labelled_requests(t)..., ask_boxes(e)...]
  k = popup_at(w, w.mouse) === nothing ? findfirst(m -> over(m.label), marks) : nothing
  asks = state_of(e, AsksState)
  was, asks.over_close = asks.over_close, false
  (was || k !== nothing) && redraw_in!(e, 0)
  k === nothing && return false
  asks.over_close = true
  x, y, wide, tall = close_spot(marks[k].label)
  show_tooltip!(w, tip_label(close_words(e, marks[k])), px(x), px(y), px(wide), px(tall); placement=:bottom, gap=6px)
  true
end

"What a click on the × at the end of the label of `x`, a request or the box round the words of a field, does, for its tooltip"
close_words(e, o::AskBox) = isempty(o.answers) ? "Take the box away" : "Take the box and its answers away"
close_words(e, a::AskedChange) = begin
  t = code_picker(e)
  o = isempty(a.places) ? nothing : box_about(e, first(a.places))
  with = o === nothing || isempty(o.answers) ? "" : ", with the answers"
  any(((q, _),) -> q === a, ask_queue(e)) ? "Take the request out of the queue" * with :
  a.ended > 0 || t.asked !== a ? "Take this away" * with :
  waiting(e, a) ? "Take the request back" * with :
  isempty(a.by) ? "Stop the agent" * with :
  "Hide this$with. $(a.by) still has the request."
end

"True when the label of a request is on the words of the field `a` of `e`, so that the field's box has no label of its own"
labelled_box(e, a::AskBox) = begin
  t = code_picker(e)
  (t.asked !== nothing && on_box(t.asked, a)) || any(((q, _),) -> on_box(q, a), ask_queue(e)) || any(q -> on_box(q, a), asks_ended(e))
end

"True while the field of a request in place, in the window `w` of `e`, has the keyboard"
typing_ask(e, w) = any(a -> w.focus === a.parts[:text], ask_boxes(e))

"Take the field of `a` and its box away, and give the keyboard back to the page"
close_ask!(a::AskBox, w) = begin
  close_popup!(w, box_key(a))
  forget_ask!(a.of, a)
  focus(a.of)
  handled
end

"True when the Close button of the field `a` hides it and leaves its box: when it has answers, or words that you typed"
hides_on_close(a::AskBox) = a.editing === nothing && (!isempty(a.answers) || a.parts[:text].buf.lines != [""])

"""
What the Close button of the field `a` does: it hides the field, and the box
round its words stays, so that a click on the box's label shows it again. A
field with nothing in it, and the field of a request that waits, go, as
there's nothing to show again: the label of a request stays.
"""
hide_ask!(a::AskBox, w) = begin
  hides_on_close(a) || return close_ask!(a, w)
  a.closed = true
  close_popup!(w, box_key(a))
  focus(a.of)
  redraw_in!(a.of, 0)
  handled
end

"Show the field `a` again, after its Close button hid it or while an agent works on a question from it, and give it the keyboard"
reopen_ask!(a::AskBox) = begin
  e = a.of
  a.sent = a.closed = false
  w = window_of(e)
  r = w === nothing ? nothing : box_place(e, a)
  r === nothing || any(p -> p.key == box_key(a), popups(w)) || show_ask!(e, w, a, r)
  r === nothing || focus(a.parts[:text])
  redraw_in!(e, 0)
  nothing
end

"""
Show the field of the words of the request `a`, with the questions and
answers about them, and what the agent is doing: a click on the label of the
request does this. Words with no field get one.
"""
open_about!(e, a::AskedChange) = begin
  isempty(a.places) && return nothing
  o = box_about(e, first(a.places))
  o === nothing || return reopen_ask!(o)
  o = open_ask!(e, AskBox(of=e, thing=first(a.places)); anyway=true)
  box_place(e, o) === nothing || focus(o.parts[:text])
  nothing
end

"""
Take the request `a` away, with the field of its words: the × on its label
does this. It stops an agent that works on it, takes it out of the queue, or
back from the agent of the page while it waits. A page's agent that has it
works on in its own terminal, and Ladder no longer shows it. The label of a
request that an agent was stopped on stays a few seconds to say what came
of it.
"""
drop_request!(e, a::AskedChange, w) = begin
  t = code_picker(e)
  q = ask_queue(e)
  k = findfirst(((x, _),) -> x === a, q)
  if k !== nothing
    deleteat!(q, k)
  elseif t.asked === a
    a.ended > 0 ? (t.asked = nothing) : waiting(e, a) ? take_back!(e, a) : stop_agents!(e, Any[a])
  else
    filter!(x -> x !== a, asks_ended(e))
  end
  o = isempty(a.places) ? nothing : box_about(e, first(a.places))
  o === nothing || close_ask!(o, w)
  redraw_in!(e, 0)
  nothing
end

"""
Ask an agent for a change to `node`, or a question about it, in the words of
`request`, like "make this bar thinner" or "why is this bar red?". `node` is
a block of Julia code, or a part of the window, which the agent changes the
function that draws. ⇧ and a click give it more than one, and the words can
name each by its letter: "make A look like B". The agent changes the code,
or its answer shows in a card beside the thing. See "ask an agent".
"""
ask_agent!(e, node::Union{ToChange,Things}, request::String) = begin
  words = String(strip(request))
  isempty(words) && error("Say what you want, in a few words.")
  name = sharer(e)
  agent_free(e, command=isempty(name))
  places = collect(each_thing(node))
  # What you asked about the things before, from the card of an answer, goes with your words
  talk = follow_up!(e, places)
  # It waits while an agent works on a request before it: see "a queue of requests"
  queue_ask!(e, words, places, isempty(name) ? said -> ask_change!(e, places, said, prompt=either_prompt(places, said), asks=true, talk=talk) :
                                               said -> ask_sharer!(e, name, places, said, asks=true, talk=talk))
end
add_command!(ask_agent!, title="Ask an agent for a change to a block of code or a part of the window, or a question about it, in your own words")

"""
Open the palette with the command `command`, like Ask Agent, with the part
`x` of the window as its thing, and the keyboard in the words. The agent's
logo on the line round a thing that a click with ⌘ and ⌥ down chose does
this.
"""
ask_with!(e, command::Symbol, x) = begin
  c = part_choice(x)
  c === nothing && return nothing
  open_palette!(e, command)
  p = palette(e)
  chips = palette_chips(p)
  isempty(chips) && return nothing
  say!(p, chips, 1, c)
  go_chip!(e, p, 2)
  nothing
end

"""
It's an error, with `command` true, when this Mac has no agent that Ladder
can start. A request while an agent works isn't one: it waits in the queue.
See "a queue of requests".
"""
agent_free(e; command=true) = (command && agent_command(e); nothing)

# --- a queue of requests ---
#
# A request that you make while an agent still works on one in the same
# window waits in a queue, and starts when the one before it ends. Its thing
# has a grey line round it, with its place in the queue on its label, like
# "Number 1 in the queue". A click on that label opens a field under its thing
# with its words, to change them: see "change a request that waits". When a
# request ends while others wait, its label stays a few seconds with what came of it,
# as it does when none wait. The × on the label of the request that an agent
# works on stops that agent, and the next request then starts.

"What a window keeps of the requests of Ask Agent, between frames"
@def mutable struct AsksState
  queue::Vector{Tuple{AskedChange,Function}} = Tuple{AskedChange,Function}[]   # the requests that wait, the next first: see `ask_queue`
  ended::Vector{AskedChange} = AskedChange[]                                   # the requests that ended while others waited
  session::Union{Nothing,AgentSession} = nothing                               # the session that the requests share: see `ask_session!`
  # The questions and answers that go with the next question: `places`, the things that they are about, and `talk`,
  # each question with its answer. They go once: see `follow_up!`.
  follow_up::Union{Nothing,NamedTuple} = nothing
  over_close::Bool = false                                                     # the mouse was over the × of a label in the last frame
end

"The requests that wait in the window of `e`, the next first: each as its label shows it, with what starts it"
ask_queue(e) = state_of(e, AsksState).queue

"The requests of the window of `e` that ended while others waited. Each shows what came of it for a few seconds."
asks_ended(e) = state_of(e, AsksState).ended

"What the label on the thing of the request that's number `n` in the queue says"
queued_label(n, words) = "Number $n in the queue: $(request_words(words))  ·  Click to change it"

"Words for a label, cut to 140 characters"
label_words(words) = length(words) > 140 ? first(words, 139) * "…" : words

"""
Start a request with `start` now, or put it in the queue while an agent still
works on one in the window of `e`. `words` and `places` are what the request
says and what it's about, for its label while it waits. `start` takes the
words, which you can change while the request waits.
"""
queue_ask!(e, words, places, start::Function) = begin
  t = code_picker(e)
  q = ask_queue(e)
  if (t.asked === nothing || t.asked.ended > 0) && isempty(q)
    # The label of the request before stays as long as it would have
    t.asked === nothing || (push!(asks_ended(e), t.asked); t.asked = nothing)
    start(String(words))
  else
    push!(q, (AskedChange(words=String(words), places=collect(places)), start))
    redraw_in!(e, 0)
  end
  nothing
end

"In each frame: start the next request of the queue once the one before it has ended, and take away the labels of those that ended a while ago"
queue_tick!(e, t::CodePicker) = begin
  done = asks_ended(e)
  filter!(a -> time() - a.ended <= (a.failed ? 15 : 8), done)
  isempty(done) || redraw_in!(e, 0.5)
  q = ask_queue(e)
  isempty(q) && return nothing
  a = t.asked
  (a === nothing || a.ended > 0) || return nothing
  a === nothing || push!(done, a)
  t.asked = nothing
  next, start = popfirst!(q)
  start(next.words)
  redraw_in!(e, 0)
  nothing
end

# --- a request that a session answers ---
#
# Grok and Antigravity have a program that stays for a session: see
# "Antigravity and Grok, which ask you before a step". So a request of Ask
# Agent to one of them goes to a session of the window, not to a program
# that does one thing and ends. The next request goes to the same session,
# so the agent knows what you asked before. The agent has the tool that runs
# Julia code in Ladder, so it can change the thing that the window shows.
# The session ends with the window. A reading companion of a folder of news
# is such a session too, with a file of its own: see "a reading companion
# for a folder of news".
#
# No pane shows the session while it works on a request, so you can't
# answer what the agent asks before a step. Ladder allows a step that reads,
# searches the web or changes a file, and refuses any other, like a shell
# command, or Julia code that the sandbox stops.

"The tools of a step that Ladder allows for the session of a request, where no pane shows the question"
const ASK_ALLOWS = ("Read", "Edit", "Write", "MultiEdit", "Grep", "Glob", "List", "WebSearch", "WebFetch", "TodoWrite")

"What the session for the requests of Ask Agent is told of where it is"
const BRIEF_ASKS = "You are in Ladder, a Markdown app on the user's Mac. The user marks a thing in the window and asks you to change it, or asks you a question about it. Each message says what the thing is and where its code is. Ladder shows the last thing that you say beside the thing. So end with a few short sentences of Markdown: the answer to the question, or what you changed."

"True when a request of Ask Agent in the window of `e` goes to a session: the program of the agent that Settings chose stays for a session, and no test has put a command in the agent's place"
asks_session(e) = AGENT_COMMAND[] === nothing && haskey(ACP_OPTIONS, agent_kind(e.ai).name)

"""
The session that works on the requests of Ask Agent in the window of `e`,
with its program running. The agent works in the folder `dir`. A request for
another folder, or after you chose another agent, ends the session and
starts a new one. In the agent's Julia code, `shown` is what the window
shows.
"""
ask_session!(e, dir) = begin
  e = top_editor(e)
  agent, dir = agent_kind(e.ai).name, String(dir)
  s = state_of(e, AsksState).session
  if !(s isa AgentSession && s.agent == agent && s.dir == dir)
    s isa AgentSession && close!(s)
    s = state_of(e, AsksState).session = AgentSession(agent=agent, dir=dir, model=chosen_model(agent), brief=BRIEF_ASKS)
    r = repl!(s)
    r.shown = () -> agent_shown(e)
    r.look = () -> on_main(() -> window_picture(e))
  end
  running(s) || start!(s, session_command(s))
  s
end

"End the session of the requests of Ask Agent in the window of `e`: the window has closed"
close_asks!(e) = (asks = state_of(e, AsksState); s = asks.session; asks.session = nothing; s isa AgentSession && close!(s); nothing)

"Give the session `s` the words `words` of the request `a`. The request keeps the session, and how much the session held before."
ask_in!(a::AskedChange, s::AgentSession, words::AbstractString) = begin
  s.turns || running(s) || start!(s, session_command(s))
  say!(s, words)
  a.session, a.mark = s, length(s.items)
  a
end

"""
In each frame while a session works on the request `a`: answer what the
agent asks before a step, show its last step on the thing's label, and when
the agent has done, take the last thing that it said as what it says of the
request. Something that went wrong in the session, like a program that
didn't start, fails the request with those words.
"""
session_ask_tick!(e, t::CodePicker, a::AskedChange) = begin
  s = a.session
  yield()   # the session's lines are read by a task, which gets its turn here
  since = s.items[min(a.mark, length(s.items))+1:end]
  for it in since
    it isa AgentWants && it.answer == :none && answer!(s, it, !(it.input isa Channel) && it.tool in ASK_ALLOWS)
  end
  k = findlast(it -> it isa AgentStep, since)
  k === nothing || (a.step = since[k].words)
  if !s.busy
    said = [it.text for it in since if it isa AgentReply && !isempty(strip(it.text))]
    wrong = [it.words for it in since if it isa SessionNote && it.bad]
    ask_ended!(e, t, a, !isempty(wrong) ? join(wrong, " ") : isempty(said) ? "" : last(said), isempty(wrong))
  end
  redraw_in!(e, 0.1)
  nothing
end

# --- ask the agent of the page ---
#
# A page can be shared with an agent: an agent like Claude Code wrote it, and
# waits for you to send it back (see "a page that an agent waits for"). Then
# Ask Agent asks that agent, not a new one. It knows what the page is
# for, and a new agent wouldn't. The agent gets your words and what you marked,
# as `ladder wait` prints them, with the lines that you changed in the page, as
# the Nudge button sends them. Ladder knows that the agent has done the change
# when it waits for the page again. Then Ladder runs the code that changed, as
# it does after a new agent's change.
#
# An agent that's still working on what you sent last gets the change when it
# waits for the page again. Until then the label on the thing says so, and a
# click on the label opens a field to change the words, or take the change
# back: see "change a request that waits". After Take Back, Ladder no longer
# counts the page as shared, so the next change goes to a new agent.

"Lines `from` to `to` of `lines`, each indented, for an agent to read: no more than 12 lines, and no more than 400 characters of each"
quoted_lines(lines, from, to) = begin
  shown = [length(l) > 400 ? first(l, 399) * "…" : l for l in lines[from:min(to, from + 11)]]
  to > from + 11 && push!(shown, "…")
  join(("    " * l for l in shown), "\n")
end

"""
The first and the last line of the page of `e` that the part `x` of the window
shows, or nothing. A part inside a block of the page, like a bar in a block
of a kind that a file defines, gives the lines of that block.
"""
on_page_lines(e, x) = begin
  b = e.buf
  x = something(shown_now(x), x)
  while x !== nothing
    at = findfirst(it -> it.content isa Live && it.content.node === x, e.layout)
    found = x isa Union{TextRun,CommentCard} ? (x.line, x.line) :
            x isa Union{Block,FileBlock} ? (x.first, x.last) :
            at === nothing ? nothing : (e.layout[at].first, e.layout[at].last)
    found !== nothing && 1 <= found[1] <= found[2] <= length(b.lines) && return found
    x = x isa SemanticUI ? x.parent : nothing
  end
  nothing
end

"The thing `c` of Ask Agent, in words for the agent of the page of `e`: what it is, the page's lines that show it, and the code that draws it"
thing_told(e, c::ToChange) = begin
  if c.node isa PickedText
    where = c.first == c.last ? "line $(c.first)" : "lines $(c.first) to $(c.last)"
    of = !isempty(e.buf.path) && page_key(e.buf.path) == c.file ? "the page" : "the file $(c.file)"
    return "Words that the user selected, on $where of $of:\n\n    $(picked_words(c.node))"
  end
  lines = c.node === nothing ? nothing : on_page_lines(e, c.node)
  if lines === nothing
    what, start = thing_words(c)
    return "$what, in the file $(c.file), lines $(c.first) to $(c.last). It starts:\n\n    $start"
  end
  from, to = lines
  where = from == to ? "line $from" : "lines $from to $to"
  shows = c.node isa CommentCard ? "A comment in the margin of the page, on $where. It says: $(join(c.node.lines, " "))" :
                                   "A $(pick_name(c.node)) of the page, on $where:\n\n$(quoted_lines(e.buf.lines, from, to))"
  "$shows\n\nLadder draws it with the code in the file $(c.file), lines $(c.first) to $(c.last)."
end

"""
Ask the agent called `name`, which works on the page of `e` with you, for the
change that `words` say to the things `places`. It gets them now if it waits
for the page, and when it waits again if it doesn't. See "ask the agent of the
page".
"""
ask_sharer!(e, name, places::AbstractVector, words::AbstractString; asks=false, talk=follow_up!(e, places)) = begin
  t = code_picker(e)
  # What you asked about the things before, from the card of an answer, goes with your words
  a = AskedChange(words=words, places=collect(places), by=name, page=e.buf.path, talk=talk, asks=asks)
  t.asked = a
  hand_change!(e, a)
  redraw_in!(e, 0)
  nothing
end

"Give the change `a` to the agent that waits for its page, while the window of `e` shows that page. It gives true when the agent got it."
hand_change!(e, a::AskedChange) = begin
  b = e.buf
  b.path == a.page || return false
  forget_waiters!(e)
  ws = agents(e)
  # With no agent that waits for the page, an article of a folder of news has the folder's reading companion, which gets one request at a time
  p = isempty(ws) ? companion_pane(e, b.path) : nothing
  isempty(ws) && (p === nothing || p.session.busy) && return false
  files = unique(c.file for c in a.places)
  # The agent reads the files, so the page, and what a window shows of a file and didn't write, go to their files first
  save!(b)
  for o in editors
    !isempty(o.buf.path) && page_key(o.buf.path) in files && dirty(o.buf) && writes(o.buf) && save!(o.buf)
  end
  a.before = Dict(f => read(f, String) for f in files if isfile(f))
  if p !== nothing
    # The companion's session gets the words itself, and what it says last is the answer: see "a request that a session answers"
    s = session!(p, e)
    ask_in!(a, s, Agent.request(b.path, b.lines, b.lines, a.words, [thing_told(e, c) for c in a.places], talk_words(a.talk), question=a.asks))
    a.by, a.sent = s.agent, true
    return true
  end
  # Words that can be a question get a file for the answer, which shows under the things: see `show_answer!`
  a.asks && isempty(a.reply) && (a.reply = Agent.answer_file())
  hand_over!(e, ws, Agent.request(b.path, b.told, b.lines, a.words, [thing_told(e, c) for c in a.places], talk_words(a.talk), question=a.asks, reply=a.reply))
  a.by, a.sent = first(ws).name, true
  true
end

"In each frame while the agent of the page has a change: give it the change when it waits, and when it waits again, run the code that it changed"
sharer_tick!(e, t::CodePicker, a::AskedChange) = begin
  if a.stopped
    t.asked = nothing
    # It never got the change, and may never wait again, so the next change goes to a new agent
    a.sent || (page_agents(e).sent = nothing)
  elseif !a.sent
    hand_change!(e, a)
  elseif !isempty(a.reply) && isfile(a.reply) && time() - mtime(a.reply) > 0.3
    # The agent answered the question. A file that's still being written is left a moment.
    said = String(strip(read(a.reply, String)))
    rm(a.reply, force=true)
    a.said, a.ended = "$(a.by) answered.", time()
    show_answer!(e, a, said)
  elseif !isempty(agents(e, a.page))
    ran, failed = reload_files!(a.places, a.before)
    a.after = Dict(f => read(f, String) for f in keys(a.before) if isfile(f))
    a.changed = a.after != a.before
    a.failed = !isempty(failed)
    a.said = a.failed ? "The new code doesn't run. " * failed : "$(a.by) has done it."
    a.ended = time()
    a.changed && push!(AGENT_CHANGES, a)
  end
  redraw_in!(e, 0.5)
  nothing
end

"""
What the label on the thing of the change `a` says. A click on the label of
one that an agent works on opens the field of its words, unless `open` is
false because the field shows already. The × at the label's end takes it away.
"""
asked_label(a::AskedChange; open=true) =
  a.ended > 0 ? (a.changed ? "$(a.said)  ·  Show Change" : a.said) :
  isempty(a.by) ? asking_words(a.words, a.step) * (open ? "  ·  Click to open" : "") :
  a.sent ? "Asked $(a.by): $(request_words(a.words)) …" * (open ? "  ·  Click to open" : "") :
  "For $(a.by) when it waits for the page again: $(request_words(a.words))  ·  Click to change it"

# --- stop an agent ---
#
# The × on its label stops the agent that's working on a request. So does the
# command Stop Agent. Esc doesn't, as it's easy to press by mistake. What the agent changed before it stopped stays in its
# files, and doesn't run, because it can be half done. Undo Change puts it
# back, and Show Change shows it.

"The agents that are working in the window of `e` now: the one that works on a request, if one does"
working_agents(e) = begin
  t = made_picker(e)
  t isa CodePicker && t.asked !== nothing && t.asked.ended == 0 ? Any[t.asked] : Any[]
end

"""
Stop the agent that's working on a request in the window of `e`. What it
changed so far stays in its files, and doesn't run. Undo Change puts it back. See "stop an agent".
"""
stop_agent!(e) = begin
  found = working_agents(e)
  isempty(found) && error("No agent is working now.")
  stop_agents!(e, found)
end
add_command!(stop_agent!, title="Stop the agent that's working now. What it changed so far stays, for Undo Change")

"Stop each agent of `found`, which are working in the window of `e`, as `stop_agent!` does"
stop_agents!(e, found) = begin
  for a in found
    a.process === nothing || process_exited(a.process) || kill(a.process)
    a.session === nothing || stop!(a.session)
    a.stopped = true
  end
  redraw_in!(e, 0)
  nothing
end

works_here(e, ::Val{:stop_agent}) = !isempty(working_agents(e))

# --- the card of an answer ---
#
# When the words of Ask Agent ask a question, and the agent changes nothing,
# its answer shows in a card beside the thing. Ask More on the card opens Ask
# Agent with the same things, and the agent gets the questions and answers so
# far with the new words. A click on the card takes it away. Esc and a click
# anywhere else leave it, and so does a new answer: the card's answer then
# goes to a field under its thing, as an answer in place does.

"""
An agent's answer `answer` to the words `words` about `places`, which changed
nothing: see "the card of an answer". `talk` has the questions that were
asked about the things before, each with its answer. `card` is where the card
was drawn last, and `button` where its button Ask More was, for a click on
them.
"""
@def mutable struct AskedAbout
  words::String = ""
  places::Vector{Any} = Any[]
  talk::Vector{Tuple{String,String}} = Tuple{String,String}[]
  answer::String = ""
  card::Any = nothing
  button::Any = nothing
end

"True when `as` and `bs` are the same things, in the same order"
same_things(as, bs) = length(as) == length(bs) && all(((a, b),) -> (a.file, a.first, a.last, a.node) == (b.file, b.first, b.last, b.node), zip(as, bs))

"""
The questions and answers about the things `places` that the card of an answer
handed on, when you clicked Ask More on it, or that a field of a request in
place has. They go once. Other things have none.
"""
follow_up!(e, places) = begin
  asks = state_of(e, AsksState)
  f, asks.follow_up = asks.follow_up, nothing
  f !== nothing && same_things(f.places, places) ? f.talk : Tuple{String,String}[]
end

"What an agent is told of the questions and answers `talk` that came before, or \"\" when there were none"
talk_words(talk) = isempty(talk) ? "" :
  "\nBefore this, the user asked about it, and an agent answered:\n\n" * join(("Question: $q\nAnswer: $a\n" for (q, a) in talk), "\n")

"""
Show the card of the answer `q`. The answer of a card that shows already goes
to a field under its thing, as an answer in place does, so that a new answer
never takes the place of one that you haven't read. See "a request in place".
"""
card!(e, q::AskedAbout) = begin
  t = code_picker(e)
  was = t.about
  t.about = q
  (was === nothing || was === q || isempty(was.places)) && return q
  x = box_answer(was.words, was.answer, e.ai)
  had = box_about(e, first(was.places))
  had === nothing ? open_ask!(e, AskBox(of=e, thing=first(was.places), answers=Any[x]), anyway=true) : add_answer!(had, x)
  q
end

const ANSWER_WIDE = 380.0   # how wide the card of an answer is, at most
const ANSWER_LINE = 17.0    # how tall each line of it is
const ANSWER_BACK = colorant"rgb(50,50,50)"   # the dark grey of a tooltip
const ANSWER_BUTTON = colorant"rgb(82,82,82)"
const ANSWER_BUTTONS = 34.0   # the room at the bottom of the card for its button

"The lines of the card of an answer: the question, then the answer, each paragraph wrapped to `room` px, as many as `most`"
answer_lines(q::AskedAbout, room, most) = begin
  ask, say = Face(SANS, "Semibold", 12px, TIP_INK, false), Face(SANS, "", 12px, TIP_INK, false)
  lines = Any[(ask, l) for l in wrapped(ask, q.words, room)]
  push!(lines, (say, ""))
  paragraphs = split(q.answer, r"\n\s*\n")
  for (k, para) in enumerate(paragraphs)
    k > 1 && push!(lines, (say, ""))
    append!(lines, [(say, l) for l in wrapped(say, replace(para, r"\s+" => " "), room)])
  end
  length(lines) <= most && return lines
  [lines[1:most-1]; (say, "…")]
end

"""
Where the card of an answer goes for the thing at `r`, when it's `wide` by
`tall` and the window is `room`: at its right, or under it, or over it, or
else in the window's bottom right corner.
"""
answer_place(r, wide, tall, room) = begin
  W, H = room
  r === nothing && return (16.0, 64.0)
  x, y, w, h = num(r.left), num(r.top), num(r.width), num(r.height)
  top = clamp(y, 40.0, max(40.0, H - tall - 8))
  x + w + 10 + wide <= W - 8 && return (x + w + 10, top)
  left = clamp(x, 8.0, max(8.0, W - wide - 8))
  y + h + 10 + tall <= H - 8 && return (left, y + h + 10)
  y - 10 - tall >= 40 && return (left, y - 10 - tall)
  (max(8.0, W - wide - 16), max(40.0, H - tall - 16))
end

"The card with an agent's answer, beside the thing that it's about, with a line round each thing"
draw_answer(ctx, w, t::CodePicker) = begin
  q = t.about
  q === nothing && return nothing
  e = t.editor
  for (n, c) in enumerate(q.places)
    r = asked_rect(e, c)
    r === nothing || pick_mark(ctx, w, r, length(q.places) > 1 ? string('A' + n - 1) : ""; colour=CHIP_MARKS[mod1(n, length(CHIP_MARKS))])
  end
  W, H = num(w.size[1]), num(w.size[2])
  wide = min(ANSWER_WIDE, W - 32)
  lines = answer_lines(q, wide - 24, max(3, floor(Int, (H - 120) / ANSWER_LINE)))
  tall = length(lines) * ANSWER_LINE + 20 + ANSWER_BUTTONS
  x, y = answer_place(asked_rect(e, first(q.places)), wide, tall, (W, H))
  round_box(ctx, x, y, wide, tall, 8; fill=ANSWER_BACK)
  for (k, (face, words)) in enumerate(lines)
    isempty(words) || write_ink(ctx, words, x + 12, y + 10 + k * ANSWER_LINE - 4, face)
  end
  # A button at the bottom asks more about the same things
  face = Face(SANS, "Medium", 12px, TIP_INK, false)
  left, top = x + 12, y + tall - ANSWER_BUTTONS + 2
  across = num(measure(face, "Ask More")) + 20
  round_box(ctx, left, top, across, 24, 6; fill=ANSWER_BUTTON)
  write_ink(ctx, "Ask More", left + 10, top + 16, face)
  q.button = (left, top, across, 24.0)
  q.card = (x, y, wide, tall)
  nothing
end

"""
What a click on the button Ask More of the card of the answer `q` does: it
opens the palette with Ask Agent, with the same things in its first chip and
the keyboard in its words. The questions and answers so far go to the agent
with the words: see `follow_up!`.
"""
follow_up_on!(e, q::AskedAbout) = begin
  state_of(e, AsksState).follow_up = (places=q.places, talk=[q.talk; (q.words, q.answer)])
  open_palette!(e, :ask_agent)
  p = palette(e)
  chips = palette_chips(p)
  isempty(chips) && return nothing
  say!(p, chips, 1, length(q.places) == 1 ? only(q.places) : Things(q.places))
  go_chip!(e, p, 2)
  nothing
end

# --- what the agents changed ---
#
# The command Show Change opens a page with each change that an agent made
# since Ladder started, the newest first. Each has what you asked, what the
# agent said, and a `changes` block: the lines that went in red and the lines
# that came in green. A change whose lines are in its file now is marked as
# accepted, and one whose lines were taken out again as rejected. Reject on one
# takes it out of its file again, and Reject all takes out all of an agent's
# change. A file of code that Ladder loaded runs the code that changed. A click
# on the label that says what the agent did shows the page too. Undo Change
# puts every file of the newest change back as it was before the agent
# started, and runs its code. Again, it does the same to the change before.



"""
The lines of a `changes` block for each file of the change `a`, with each of
its changes marked by what its file has now: accepted when its new lines are
there, and rejected when its old lines are there again.
"""
change_lines(a::AskedChange) = begin
  out = String[]
  for f in sort!(collect(keys(a.before)))
    a.before[f] == a.after[f] && continue
    c = Diffs.changes(change_diff(f, a.before[f], a.after[f]))
    now, _, _ = Diffs.read_lines(f)
    for h in c.hunks
      h.state = first(Diffs.apply(now, h)) == :already ? :accepted : first(Diffs.apply(now, h; back=true)) == :already ? :rejected : :open
    end
    append!(out, Diffs.written(c))
  end
  out
end

"The page of the changes `changes`, the newest first: for each, when it ended, what was asked, what the agent said, and its change to each file"
change_page(changes::AbstractVector) = begin
  lines = String["# What the agents changed", "",
                 "Each change that an agent made since Ladder started, the newest first. Reject a part of a change to take it out of its file again, or Reject all to take out all of the change.", ""]
  for a in Iterators.reverse(changes)
    push!(lines, "## $(lowercase(Libc.strftime("%-I:%M %p", a.ended))): $(a.words)", "")
    isempty(a.said) || push!(lines, "The agent said: $(a.said)", "")
    push!(lines, "```$CHANGES")
    append!(lines, change_lines(a))
    push!(lines, "```", "")
  end
  join(lines, "\n")
end
change_page(a::AskedChange) = change_page([a])

"Show each change that an agent made since Ladder started, the newest first, in a window beside this one. Reject takes a part of a change out of its file again."
show_change!(e) = begin
  isempty(AGENT_CHANGES) && error("No agent has changed anything since Ladder started.")
  page = joinpath(tempdir(), "ladder-changes", "what the agents changed.md")
  mkpath(dirname(page))
  write(page, change_page(AGENT_CHANGES))
  # A window that shows the page already reads it again, and comes to the front. A window that closed has no editor in the list.
  k = findfirst(o -> !isempty(o.buf.path) && page_key(o.buf.path) == page_key(page) && window_of(o) !== nothing, editors)
  if k !== nothing
    shown = editors[k]
    w = window_of(shown)
    isopen(w) && front!(w)
    shown.buf.caret = shown.buf.anchor = (1, 0)
    shown.scroll.offset = 0px
    return shown
  end
  shown = build_editor(page)
  same_settings!(shown, e)
  shown.remember = false
  shown.panel = false
  by = window_of(e)
  size, at = window_beside(by)
  shown.size = size
  show_window!(window!(shown, title="What the agents changed", size=size, position=at), by)
  shown
end
add_command!(show_change!, title="Show each change that an agent made, the newest first, and reject any part of one")

"True when each file of the change `a` has the text that it had before the agent started: it was taken out again"
taken_out(a::AskedChange) = all(((f, was),) -> isfile(f) && read(f, String) == was, a.before)

"The newest change that an agent made that's still in its files, or nothing"
newest_change() = (k = findlast(a -> !a.undone && !taken_out(a), AGENT_CHANGES); k === nothing ? nothing : AGENT_CHANGES[k])

"Put back each file that the newest change of an agent changed, as it was before the agent started, and run its code as it was"
undo_change!(e) = begin
  a = newest_change()
  a === nothing && error(isempty(AGENT_CHANGES) ? "No agent has changed anything since Ladder started." : "Each change that an agent made is undone.")
  for (f, now) in a.after
    (isfile(f) && read(f, String) == now) || error("$(basename(f)) has changed since the agent's change, so Ladder didn't put it back. Show Change can take out a part of the change.")
  end
  for (f, was) in a.before
    write(f, was)
  end
  ran, failed = reload_files!(a.places, a.after)
  a.undone = true
  isempty(failed) || error("The files are as they were, but some of the code doesn't run: " * failed)
  nothing
end
add_command!(undo_change!, title="Put back the files that an agent changed last, as they were before")

works_here(e, ::Val{:show_change}) = !isempty(AGENT_CHANGES)
works_here(e, ::Val{:undo_change}) = any(a -> !a.undone, AGENT_CHANGES)

"The module of the file of code that Ladder loaded whose path ends with `name`, like \"Ladder/main.jl\". The startup page uses it to keep a change: see `keep_change!`."
loaded(name::AbstractString) = begin
  found = [m for (path, m) in Kip.modules if m isa Module && endswith(path, "/" * name)]
  length(found) == 1 || error(isempty(found) ? "Ladder loaded no file called $name." : "Ladder loaded more than one file called $name.")
  only(found)
end

"The shortest end of the path `file` that names one file of the code that Ladder loaded, like \"Ladder/main.jl\""
loaded_name(file::AbstractString) = begin
  parts = splitpath(file)
  for k in 2:length(parts)
    name = join(parts[end-k+1:end], "/")
    count(path -> endswith(path, "/" * name), keys(Kip.modules)) == 1 && return name
  end
  String(file)
end

"The first and the last line of the part of the code of `lines` that line `i` is in, without the blank lines after it: see `read_parts`"
part_lines(lines::Vector{String}, i::Int) = begin
  ps = read_parts(lines, 1)
  k = something(findlast(p -> p.first <= i, ps), 1)
  first, last = ps[k].first, k == length(ps) ? length(lines) : ps[k+1].first - 1
  while last > first && isempty(strip(lines[last])); last -= 1 end
  (first, last)
end

"""
Keep the function that the caret is in, for each time that Ladder starts. It's
for a function of Ladder's own code, in the app that's installed: that app
writes its own files again when it starts, so a change to one lasts only
until Ladder quits. This adds the function to the startup page, in a block of
code that runs it in the module of its file. A function that was kept before
is kept as it is now.
"""
keep_change!(e) = begin
  b = e.buf
  file = page_key(b.path)
  mod = loaded_module(file)
  mod === nothing && error("Ladder didn't load this file, so there's no change to Ladder to keep.")
  file in values(SOURCE_FILES) || error("Ladder doesn't write this file again when it starts. ⌘S keeps the change.")
  first, last = part_lines(b.lines, b.caret[1])
  code = join(b.lines[first:last], "\n")
  isempty(strip(code)) && error("The caret isn't in a function.")
  made = [m for m in page_bounds(e) if m.span === nothing && first <= m.at[1] <= last]
  isempty(made) && error("The caret isn't in a function.")
  name = loaded_name(file)
  heading = "## Kept: `$(signature(b.lines[made[1].at[1]], made[1]))` of $name"
  # The function is as it's kept from now, in the app that runs too
  Base.include_string(mod, code, file)
  block = [heading, "", "```julia", "@eval Ladder.loaded(\"$name\") begin", split(code, '\n')..., "end", "```"]
  page = startup_page()
  lines = isfile(page) ? text(page) : String[]
  at = findfirst(==(heading), lines)
  if at === nothing
    while !isempty(lines) && isempty(strip(lines[end])); pop!(lines) end
    append!(lines, ["", block..., ""])
  else
    stop = something(findnext(l -> startswith(l, "## "), lines, at + 1), length(lines) + 1) - 1
    splice!(lines, at:stop, [block..., ""])
  end
  write(page, join(lines, "\n"))
  redraw_windows!()
  nothing
end
add_command!(keep_change!, name=:keep_this_change, title="Keep the function at the caret for each time that Ladder starts: a change to Ladder's own code")

# Show Code takes the same node as Ask Agent: see "the code of a thing"
"""
Show the code of `node`: the function that draws a part of the window, in a
window beside this one, or a block of Julia code. `node` starts as what the
caret is on, as the node of Ask Agent does, and a click chooses another.
"""
show_code!(e, node::ToChange) = begin
  if node.node !== nothing
    m = drawn_by(node.node)
    m === nothing || return show_code!(e, m)
  end
  lines = text(node.file)
  line = code_start(lines, node.first)
  b = e.buf
  # A block of the page or the file that this window shows is shown here
  if !isempty(b.path) && page_key(b.path) == node.file
    note_place!(e)   # ⌘⌥← comes back here
    show_line!(e, line)
    hold!(e, line, 24px - PAGE_TOP)
    return e
  end
  show_place!(e, node.file, line)
end
add_command!(show_code!, title="Show the code that draws a part of the window, or a block of Julia code")
