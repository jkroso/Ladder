# Code that runs where it is: what each piece of a code block or of a file of Julia code comes to, in a box under it
#
# In a code block in the language `julia`, ⌘Return runs the expression that the
# caret is in, and shows what it comes to in a small box after the end of the
# expression's last line. ⇧Return does the same and then puts the caret at the
# next expression, so pressing it again and again goes down the block. With a
# selection, they run the code that's selected. With the caret in the line that
# opens or closes the block, they run every expression of the block.
#
# The code of a sum in a line of text runs the same way. With the caret in the
# code, ⌘Return runs the whole sum, and with a selection in it, like one name,
# it runs what's selected. The box is under that code, so it covers none of
# it, and it goes when the caret leaves the sum. See `run_sum_here!`.
#
# In a Julia file, the command Run All (⌘⇧P) runs every expression of the
# file, from the top, and shows what each one comes to. An expression that
# fails doesn't stop the ones under it, so every result shows. Then the first
# one that failed comes in sight. See `run_all!`.
#
# The code runs in a thread of its own, so the window goes on drawing while it
# runs. Its box shows at once. A result that comes within a tenth of a second
# shows straight away. A box whose code takes longer has a spinner in it until
# the result comes. Pieces of code run one at a time, in the order that they
# were asked for. A name that acts on the window, like `page_theme!`, does it
# on the main thread. See `run_pieces!`.
#
# The code of a page runs in a module of the page's own, so a name that one
# block makes is there for the next, and isn't on another page. The module has
# the names that a live block has, like Slider and px, and the units of a
# sheet. Code can use any of those names for a thing of its own, like
# `width = 2.4`. That doesn't change what the name means in a live block.
#
# The box shows the first line of the value. A value that has more, like a
# matrix, has an arrow in its box: click the box to show the rest under it, and
# click again to hide it. Such a box changes colour under the mouse while it's
# closed. An open box doesn't, since it's one piece with the rest under it.
# Text that the code printed shows before the value.
# An open box and the rest under it are one piece, with one line around both
# and nothing between them. The rest starts under the left of the box. When the
# window has no room for it there, it starts further left, and the box stands
# on top of it like a tab. A box that would end just short of the right edge of
# the rest is as wide as it takes to end there, so there's no small step.
# A value has the colours that a code block gives Julia code: its numbers, its
# strings and the names of its types.
# What went wrong shows in red. On a page, a value that's a UI node shows as the
# node. The box of a struct opens to show a line for each of the struct's
# fields: the field's name and its value. In a file of code, a UI node shows
# that way too, with a line for each of its children under its fields. A line
# whose value has parts of its own has an arrow: click it to show them under
# it. A list that has a struct or a node in it opens to a line for each item.
# A type that the page's code made shows by its name alone, like `Wall`, with
# no module in front of it.
#
# The box of a function opens to show its documentation and a table of its methods.
# The box of a module opens to show its readme, or its documentation when it has
# no readme, and a table of the names that it defines, with a field that
# searches them. A
# check mark means that the code came to nothing and printed nothing. Code that
# ends with a semicolon shows no value, as it does at Julia's prompt.
#
# A box stays while its code is as it was when it ran. It goes when you change
# that code, and Escape takes every box off the page.

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI GeometricUI WrapMode describe reuse! handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor redraw_in! MouseScroll
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./pictures" natural
@use "./markdown" Kind
@use "./highlight" tokens
@use "./sheet" parts units shown
@use "./for_agents" on_main
@use Colors: RGBA
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./additions" exports...
@use "./folder_page" exports...
@use "./julia_levels" exports...
@use "./fill_view" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./live_view" exports...
@use "./schedule_view" exports...
@use "./timelog_view" exports...
@use "./result_block" exports...
@use "./showed_before" note_place!

export OUTCOME_GAP, OUTCOME_LINES, OUTCOME_COLS, OUTCOME_NODE_W, OUTCOME_EDGE, MEMBERS, MEMBER_COLS,
       MEMBER_INDENT, MEMBERS_LEAST, Outcome, Member, statements, window_names!, acts_on_window,
       window_call, RUNNING_WINDOW, FRONT_WINDOW, acting_window, run_code, with_printed, code_ran!,
       written_in, clipped, Unset, Unlisted, NODE_LINKS, plainly_shown, field_pairs, members,
       find_members, has_members, brief_text, member_lines, unfolded, printed_rest, member_cols,
       outcome_line, outcome_wide, outcomes, outcome!, SPIN_TURN, SPIN_FRAME, CodeRun, run_pieces!,
       run_piece, run_tick!, came_back!, run_here!, sum_code_at, run_sum_here!, in_its_sum,
       sum_box_place, run_all!, bring_failed!, follow_outcomes!, forget_outcomes!, outcome_over,
       value_row, isvalue, members_view, Spinner, inside_corner, CodeRuns, made_workspace

const OUTCOME_GAP = 14px        # between the end of a line of code and the box of what it came to
const OUTCOME_LINES = 30        # the most lines of a value that Julia writes
const OUTCOME_COLS = 100        # and the most characters of each
const OUTCOME_NODE_W = 420px    # how wide a value that's a UI node shows
const OUTCOME_EDGE = 12px       # the least space between a box and the right edge of the window
const MEMBERS = 100             # the most items of a list that the open box of an outcome lists
const MEMBER_COLS = 80          # the most characters of a value on a line of that list
const MEMBER_INDENT = 2         # how many characters further in the parts of a part start
const MEMBERS_LEAST = 6         # how many lines of the list show at least, in a box that's near the bottom of the window

"The font of what code came to, which is the font of the code, at `size` and in the colour `ink`"
outcome_face(size, ink=colours.ink) = Face(codefont(), codestyle(), size, ink, false)

"What a piece of the code of a `julia` code block came to when it ran. It shows in a box after the code's last line."
@def mutable struct Outcome <: SemanticUI
  first::Int = 0                    # the lines of the document that ran
  last::Int = 0
  code::Vector{String} = String[]   # those lines as they were then
  total::Int = 0                    # how many lines the document had when the code was last seen on those lines
  brief::String = ""                # the first line of what it came to
  full::String = ""                 # all of it
  printed::Int = 0                  # how many lines of it, from the first, are text that the code printed
  failed::Bool = false
  node::Any = nothing               # a Shown, when the value is a UI node
  subject::Any = nothing            # the value itself, when it's a function, a module or a type, which has more to show than its text
  whole::Any = nothing              # the value itself, when the open box lists its parts: a struct, or a UI node in a file of code
  open::Bool = false                # the rest shows under the box
  body::Any = nothing               # the OutcomeBody that shows the rest
  source::Any = nothing             # what the levels under the value show the code of: a Defined or a Thunk, or nothing
  form::Int = 1                     # which of a function's methods and sets of types those levels show
  views::Dict{Any,Any} = Dict{Any,Any}()   # the top line and the lines of each level that has shown, for each set of types
  since::Float64 = 0.0              # when its code was asked to run, while what the code came to isn't here. It's 0 once it is.
  cols::Any = nothing               # for code of a sum in a line of text, the columns of its line that ran. The box is under them.
  # Each frame sets these, for the room that the window has
  shown::String = ""                # as much of `brief` as fits
  rest::String = ""                 # what shows under the box when it's open
  from::Int = 1                     # the line of `full` that `rest` starts at
  more::Bool = false                # there's more than the box shows
  low::Any = nothing                # the Lowered that it shows while its code is down a level, or nothing at the level of the value
  size::px = 12px                   # of its text
  high::px = 20px
  across::px = 0px                  # how wide the box is while it's open
  steps::Tuple{px,px} = (0px, 0px)  # how far the rest under an open box goes on past the left of the box, and past its right
end

"A part of a value, on a line of its own in the open box of an outcome: a field of a struct, an item of a list, or a child of a UI node"
@def mutable struct Member <: SemanticUI
  of::Any = nothing       # the OutcomeBody that it's in
  name::String = ""       # the field's name, the item's place in its list, or its key
  value::Any = nothing
  text::String = ""       # the value as Julia writes it on one line
  depth::Int = 0          # how many parts it's inside
  more::Bool = false      # the value has parts of its own
  room::Bool = false      # a line of its list has an arrow, so each line of the list has room for one
  inside::Any = nothing   # the Member of each of them, made when the line first opens
  open::Bool = false      # they show under the line
end

"""
The first and last line of the code of the `julia` code block that line `i` is
in, or nothing when the line isn't in one. The lines that open and close the
block are in the block, and aren't code.
"""
julia_code(b::Buffer, i::Int) = begin
  ks = kinds(b)
  # A file of code is one block, with no lines that open and close it
  b.view == :code && return lowercase(ks[i].lang) in JULIA ? (1, length(b.lines)) : nothing
  ks[i].kind in (Kind.fence, Kind.code) || return nothing
  s, t = codeblock(b, i)
  (t > s && ks[s].kind == Kind.fence && ks[s].level == 0 && ks[t].kind == Kind.fence && ks[t].level == 1) || return nothing
  lowercase(ks[s].lang) in JULIA ? (s + 1, t - 1) : nothing
end

"""
The lines of each piece of the Julia code in `lines` that runs on its own: an
expression at the top level, with the comments above it. Expressions that
share a line are one piece.
"""
statements(lines::AbstractVector{<:AbstractString}) = begin
  out = UnitRange{Int}[]
  isempty(lines) && return out
  src = join(lines, "\n")
  starts = cumsum([1; Int[ncodeunits(l) + 1 for l in lines[1:end-1]]])   # the byte that each line starts at
  line_of(byte) = searchsortedlast(starts, byte)
  pos = 1
  while pos <= ncodeunits(src)
    ex, next = try
      Meta.parse(src, pos; raise=false)
    catch
      (Expr(:error), ncodeunits(src) + 1)
    end
    next > pos || break
    # The parser takes the blank lines above an expression with it, and the end of the expression's last line
    text = SubString(src, pos, prevind(src, next))
    if ex !== nothing && !isempty(strip(text))
      lo = line_of(pos + ncodeunits(text) - ncodeunits(lstrip(text)))
      hi = line_of(pos + ncodeunits(rstrip(text)) - 1)
      if !isempty(out) && lo <= last(out[end])
        out[end] = first(out[end]):max(hi, last(out[end]))
      else
        push!(out, lo:hi)
      end
    end
    pos = next
  end
  out
end

"""
The module that the `julia` code blocks of the page run in: the page's own,
which each window that shows the page uses. See `page_module`. A page with no
file has one in its window.
"""
workspace(e) = begin
  isempty(e.buf.path) || return page_module(e, e.buf.path)
  own = window_modules(e)
  own.workspace === nothing && (own.workspace = usual_module(e, Symbol("⭒untitled")))
  own.workspace::Module
end

"The module of the page's `julia` code, or nothing when it has none yet"
made_workspace(e) = isempty(e.buf.path) ? window_modules(e).workspace : get(PAGE_MODULES, page_key(e.buf.path), nothing)

"""
A new module called `name`, with what a Julia file that Kip loads has, like
`@use`, and the names that the window `e` gives a page's code: see
`window_names!`. With `key`, the path of a page, the module is for each
window that shows the page.
"""
usual_module(e, name::Symbol, key=nothing) = begin
  m = Module(name)
  # Kip by the module that's loaded here, not by name, as the window's module has it
  Core.eval(m, :(const Kip = $Kip))
  Core.eval(m, :(using .Kip))
  Core.eval(m, :(eval(x) = Core.eval($m, x)))
  Core.eval(m, :(include(file) = Base.include($m, file)))
  # The window's names go in a module that has no others, not even Julia's own, so each one that Julia has too goes in
  Core.eval(m, :(const Usual = $(Module(:Usual, false))))
  Core.eval(m, :(using .Usual))
  window_names!(m, e, key)
end

"""
Give the module `m` of a page's code each name that the window `e` gives a
page's code (see `sandbox`), and each unit of a sheet, that `m` hasn't got
yet. A window that's newer than the module can have more names, like ones
that code from the startup page added since. It gives `m`.

The names come in with `using`, so the page's code can give any of them a new
meaning. Julia's own name would come before one that comes in that way, so a
name of the window that Julia has too, like `Text`, is a constant of the
module itself, as it is in the window's module. The page's code can still
give it a new meaning, as a page that loads UI.jl's names does. A unit with a
name that Julia has stays out. With `key`, a name that acts on a window acts
on the one that `acting_window` gives.
"""
window_names!(m::Module, e, key=nothing) = begin
  usual = Base.invokelatest(getglobal, m, :Usual)
  from = sandbox(e)
  # The modules can be new, so their names are asked for as they are now
  share(source, n) = begin
    hidden = startswith(string(n), '#') || n in (nameof(source), :eval, :include, :Kip, :SheetUnits)
    (hidden || Base.invokelatest(isdefined, usual, n) || !Base.invokelatest(isdefined, source, n)) && return
    julias = Base.isexported(Base, n)
    source !== from && julias && return
    value = Base.invokelatest(getglobal, source, n)
    # A name that acts on a window does it on the main thread, as the code of a page runs in a thread of its own: see `on_main`
    if acts_on_window(value)
      value = key !== nothing ? window_call(key, n, source) : (f -> (args...; kw...) -> on_main(() -> f(args...; kw...)))(value)
    end
    Core.eval(usual, :(const $n = $value))
    Core.eval(usual, Expr(:export, n))
    julias && !(try Base.which(m, n) === m catch; false end) && Core.eval(m, :(const $n = $value))
  end
  foreach(n -> share(from, n), Base.invokelatest(names, from, all=true, imported=true))
  units = Base.invokelatest(getglobal, from, :SheetUnits)
  foreach(n -> share(units, n), Base.invokelatest(names, units))
  m
end

"True when `f` is a function that acts on one window, as `page_theme!` does: it holds the window"
acts_on_window(f) = f isa Function && any(i -> isdefined(f, i) && getfield(f, i) isa Editor, 1:nfields(f))

"""
A function that calls the function `name` of the window that the names of
the module of the page at `key` act on: see `acting_window`. When that window
is older than the name and hasn't got it, it calls the one of `given`, the
module of the window that gave the page's module the name. It runs on the
main thread: see `on_main`.
"""
window_call(key::String, name::Symbol, given::Module) = (args...; kw...) -> on_main() do
  from = sandbox(acting_window(key))
  Base.invokelatest(isdefined, from, name) || (from = given)
  Base.invokelatest(Base.invokelatest(getglobal, from, name), args...; kw...)
end

"The window whose page's code runs now, or nothing between runs"
const RUNNING_WINDOW = Ref{Any}(nothing)

"The window in front, as macOS last said, or nothing"
const FRONT_WINDOW = Ref{Any}(nothing)

"""
Run `f` with the module of the page's code, for code that the window `e` runs
in it now. A name of the module that acts on a window acts on `e` while the
code runs, and after that until another window runs code in the module.
"""
running_code(f, e) = begin
  foreign(e.buf.path) && error("An email runs no code.")
  m = workspace(e)
  isempty(e.buf.path) || (PAGE_WINDOWS[page_key(e.buf.path)] = e)
  was = RUNNING_WINDOW[]
  RUNNING_WINDOW[] = e
  try
    f(m)
  finally
    RUNNING_WINDOW[] = was
  end
end

"""
The window that a name of the module of the page at `key` acts on, like
`page_theme!`: the window whose code runs in the module now, or else the
front window when it shows the page, as it does when you click a button that
the page's code made, or else the window whose code ran in the module last.
"""
acting_window(key::String) = begin
  for w in (RUNNING_WINDOW[], FRONT_WINDOW[])
    w !== nothing && !isempty(w.buf.path) && page_key(w.buf.path) == key && return w
  end
  PAGE_WINDOWS[key]
end

"""
Run `code` in the module of the page's `julia` code blocks. It gives the
value that the code came to, the text that the code printed, and true when the
code failed. Then the value is the error.
"""
run_code(e, code::String) = begin
  path, dir = run_place(e)
  # The code can load the drawing methods of a node, so the window draws one more frame soon after
  one_more_frame!(e)
  out = with_printed(() -> cd(() -> running_code(m -> run_in(m, code, path), e), dir))
  code_ran!(path)
  out
end

"""
The path that the page's code runs as, and the folder that it runs in. Kip
finds a path like "./widgets.jl" from the folder of the document, as it does
for a live block.
"""
run_place(e) = (isempty(e.buf.path) ? joinpath(e.folder, "untitled.md") : e.buf.path, isdir(docdir(e)) ? docdir(e) : pwd())

"""
Run `f`, and keep the text that it prints. It gives the value that `f` came
to, that text, and true when `f` failed. Then the value is the error.
"""
with_printed(f) = begin
  screen = stdout
  rd, wr = redirect_stdout()
  printed = @async read(rd, String)
  value, failed = try
    (f(), false)
  catch err
    (err isa LoadError ? err.error : err, true)
  finally
    redirect_stdout(screen)
    close(wr)
  end
  (value, fetch(printed), failed)
end

"""
What happens after code of the page at `path` ran: the page's `check` blocks
run again, and the windows draw again when the code ran in a module of
Ladder's own, since it can give a thing a new way to draw itself (see "the
code of a thing").
"""
code_ran!(path) = begin
  CODE_RUNS[] += 1
  # The page's `result` blocks run again, since the code could have made a name that they use
  isempty(path) || (key = page_key(path); PAGE_RUNS[key] = get(PAGE_RUNS, key, 0) + 1)
  loaded_module(page_key(path)) === nothing || redraw_windows!()
  nothing
end

"""
`value` as the text that Julia shows for it, with the middle of a long list or
a big table left out. With the module `home`, a type that the module made has
no module's name in front of its own.
"""
value_text(value, home=nothing) = begin
  io = IOBuffer()
  Base.invokelatest(show, written_in(io, home), MIME"text/plain"(), value)
  String(take!(io))
end

"`io` with what tells Julia to leave out the middle of a long value, and to write the types of the module `home` by their names alone"
written_in(io, home) = begin
  io = IOContext(io, :limit => true, :displaysize => (OUTCOME_LINES, OUTCOME_COLS))
  home === nothing ? io : IOContext(io, :module => home)
end

"No more of `text` than an outcome shows: a few more lines than Julia writes for a value, and a few more characters of each"
clipped(text) = begin
  lines = split(text, '\n')
  length(lines) > OUTCOME_LINES + 10 && (lines = [lines[1:OUTCOME_LINES+10]; "…"])
  join((length(l) > OUTCOME_COLS + 20 ? first(l, OUTCOME_COLS + 20) * "…" : l for l in lines), "\n")
end

"What a line shows for a field that has no value yet"
struct Unset end
Base.show(io::IO, ::Unset) = print(io, "#undef")

"What the last line of a list shows when the list has more items than `MEMBERS`: how many more"
struct Unlisted
  count::Int
end
Base.show(io::IO, u::Unlisted) = print(io, u.count, " more")

"The fields that join a UI node to the nodes around it, and that hold what the window keeps for it. They aren't the node's own."
const NODE_LINKS = (fieldnames(Backdrop)..., :from)

"True when Julia writes a value of the type `T` its usual way: the type's name, and the value's fields in brackets"
plainly_shown(T::Type) = try
  which(show, Tuple{IO,T}) === which(show, Tuple{IO,Any}) &&
    which(show, Tuple{IO,MIME"text/plain",T}) === which(show, Tuple{IO,MIME"text/plain",Any})
catch
  false
end

"The name and the value of each field of `value`, without the fields that `skip` names"
field_pairs(value, skip=()) =
  Pair{String,Any}[string(name) => (isdefined(value, name) ? getfield(value, name) : Unset())
                   for name in fieldnames(typeof(value)) if !(name in skip)]

"""
The parts of `value` that the open box of an outcome lists, each with its
name. It's empty for a value that has none, like a number or a string.

- A struct has its fields, when Julia writes it its usual way. A struct that
  has a way of its own to show, like a date or a colour, is one value.
- A UI node has its own fields, and then its children by their place.
- A vector and a tuple have their items by their place, and a dictionary has
  its values by their keys. A long one has its first `MEMBERS`.
"""
members(value) = try
  Base.invokelatest(find_members, value)
catch
  Pair{String,Any}[]
end

find_members(value) = begin
  none = Pair{String,Any}[]
  value isa Union{Number,AbstractString,Symbol,Char,Nothing,Missing,Function,Module,Type,AbstractRange,Unset,Unlisted} && return none
  if value isa Union{SemanticUI,GeometricUI}
    out = field_pairs(value, NODE_LINKS)
    # The children as they are now. Asking a node for its children can make them.
    child = hasfield(typeof(value), :firstchild) ? getfield(value, :firstchild) : nothing
    k = 0
    while child !== nothing && k < MEMBERS
      push!(out, string(k += 1) => child)
      child = getfield(child, :nextsibling)
    end
    return out
  end
  value isa NamedTuple && return Pair{String,Any}[string(k) => v for (k, v) in pairs(value)]
  if value isa Union{AbstractVector,Tuple,AbstractDict}
    out = value isa AbstractDict ? Pair{String,Any}[brief_text(k, 30) => v for (k, v) in Iterators.take(value, MEMBERS)] :
          Pair{String,Any}[string(i) => (value isa Tuple || isassigned(value, i) ? value[i] : Unset()) for i in Iterators.take(eachindex(value), MEMBERS)]
    length(value) > MEMBERS && push!(out, "…" => Unlisted(length(value) - MEMBERS))
    return out
  end
  T = typeof(value)
  (isstructtype(T) && fieldcount(T) > 0 && plainly_shown(T)) ? field_pairs(value) : none
end

"""
True when the open box of an outcome lists the parts of `value`: a struct, a UI
node, or a list that has one of those in it. A list of numbers or of strings
shows as Julia writes it.
"""
has_members(value) = begin
  found = members(value)
  isempty(found) && return false
  value isa Union{AbstractVector,Tuple,NamedTuple,AbstractDict} || return true
  any(p -> !isempty(members(p.second)), found)
end

"`value` as Julia writes it on one line, in no more than `cols` characters. `home` is as it is for `value_text`."
brief_text(value, cols=MEMBER_COLS; home=nothing) = begin
  text = try
    # A long string is cut before it's written, so that writing it stays quick
    value isa AbstractString && length(value) > cols && (value = first(value, cols))
    io = IOBuffer()
    Base.invokelatest(show, written_in(io, home), value)
    String(take!(io))
  catch
    string(typeof(value))
  end
  text = replace(text, r"\s*\n\s*" => " ")
  length(text) > cols ? first(text, cols - 1) * "…" : text
end

"A line for each part of `value`, in the open box `d` of an outcome. They are `depth` parts inside the value that the code came to."
member_lines(d, value, depth) = begin
  home = workspace(editor(d))
  found = [(name, v, !isempty(members(v))) for (name, v) in members(value)]
  room = any(last, found)
  Member[own!(d, Member(of=d, name=name, value=v, text=brief_text(v; home), depth=depth, more=more, room=room)) for (name, v, more) in found]
end

"The lines that the list shows now, from the lines `rows` of the value's own parts: each of them, and under one that's open, the lines of its parts"
unfolded(rows, out=Member[]) = begin
  for m in rows
    push!(out, m)
    m.open && m.inside !== nothing && unfolded(m.inside, out)
  end
  out
end

"""
The lines of text that the code printed and that the box of `o` doesn't show.
They are over the list of the value's parts. What Julia writes for the value
isn't there, because the list says it.
"""
printed_rest(o::Outcome) = (lines = split(o.rest, '\n'); lines[1:clamp(o.printed - o.from + 1, 0, length(lines))])

"How many characters wide the line `m` is: how far in it starts, the room for its arrow, its name and its value"
member_cols(m::Member) = MEMBER_INDENT * (m.depth + m.room) + length(m.name) + 2 + length(m.text)

"The colour of the line around the box of `o`, and around the rest under it"
outcome_line(o::Outcome) = o.failed ? RGBA(SPELL_RED, 0.45) : colours.line

"How wide the box of `o` is when it's as wide as what it shows: its text in characters `cell` wide, its arrow, and the space around them"
outcome_wide(o::Outcome, cell) = cell * length(o.shown) + o.size * 0.8 + 20px

"What the code of the page came to, for each piece of it that ran and hasn't changed since"
outcomes(e) = get!(() -> Outcome[], e.nodes, (:outcomes, e.buf.path))::Vector{Outcome}

"""
Run the code on the lines `r` of the page, and show what it comes to after the
last of them. `code` is the part of those lines that runs. It gives the
outcome, which waits for the code when the code takes longer than `RUN_WAIT`.
"""
outcome!(e, r::UnitRange{Int}, code::String=join(e.buf.lines[r], "\n")) = only(run_pieces!(e, [r], [code]))

"How many seconds the ring of a spinner takes to go round once, and how often it moves"
const SPIN_TURN = 0.9
const SPIN_FRAME = 1 / 30

"""
Pieces of the code of a page that run one after another in a thread of their
own: the window that runs them, the outcome and the code of each piece, and
what the thread sends back for each piece as it ends.
"""
mutable struct CodeRun
  e::Any
  key::Any                 # the key in `e.nodes` of the list that the outcomes are in
  path::String             # the path that the code runs as
  outcomes::Vector{Outcome}
  codes::Vector{String}
  came::Channel{Any}       # what each piece came to, as it ends: see `run_piece`
  task::Task               # the task that runs the pieces
  failed::Int              # the first piece that failed, or 0
  after::Any               # what to do when every piece has come back, or nothing
end

"The code of a window's pages that runs now, in threads of its own"
@def mutable struct CodeRuns
  list::Vector{CodeRun} = CodeRun[]   # one for each run that has pieces still to come back
end

"""
Run the code on the lines of each range in `rs` of the page, one piece after
another, and show what each piece comes to after its last line. `codes` are the
parts of those lines that run. With `stop`, a piece that fails stops the pieces
after it, and their boxes go. `after(e, o)` runs when every piece has come
back, with the outcome of the first piece that failed, or nothing. It gives
the outcome of each piece.

The code runs in a thread of its own, so the window goes on drawing while it
runs, and the box of each piece shows at once. Code that comes back within
`RUN_WAIT` seconds shows what it came to straight away, as if the window had
waited for it. A box whose code takes longer shows a spinner until then.
"""
run_pieces!(e, rs::AbstractVector, codes::AbstractVector; stop=false, after=nothing) = begin
  b = e.buf
  path, dir = run_place(e)
  m = cd(() -> workspace(e), dir)
  isempty(b.path) || (PAGE_WINDOWS[page_key(b.path)] = e)
  # A UI node shows as itself on a page. In a file of code, it's a value like any other.
  nodes = b.view != :code
  list, asked = outcomes(e), time()
  made = Outcome[]
  for r in rs
    o = own!(e, Outcome(first=first(r), last=last(r), code=b.lines[r], total=length(b.lines), since=asked))
    # It takes the place of what any of those lines came to before
    Base.filter!(p -> p.last < o.first || p.first > o.last, list)
    push!(list, o)
    push!(made, o)
  end
  came = Channel{Any}(Inf)
  before = LAST_RUN[]
  task = Threads.@spawn begin
    before === nothing || try wait(before) catch end
    for (k, code) in enumerate(codes)
      piece = Base.invokelatest(run_piece, k, code, m, path, dir, nodes)
      put!(came, piece)
      piece.failed && stop && break
    end
  end
  LAST_RUN[] = task
  push!(state_of(e, CodeRuns).list, CodeRun(e, (:outcomes, b.path), path, made, String.(codes), came, task, 0, after))
  while !istaskdone(task) && time() < asked + RUN_WAIT[]
    sleep(0.002)
  end
  run_tick!(e)
  made
end

"""
Run `code`, piece `k` of a run, in the module `m`, as the file at `path` and in
the folder `dir`. It gives what the outcome of the piece shows: the value, the
text that the code printed, true when the code failed, the world that it ran
in, and the value as text. With `nodes`, a UI node shows as itself, and its
text is its type's name. The text is made here, straight after the code runs,
so a piece after it that changes the value doesn't change what it shows.
"""
run_piece(k, code, m, path, dir, nodes) = begin
  world = Base.get_world_counter()
  value, printed, failed = with_printed(() -> cd(() -> Base.invokelatest(run_in, m, code, path), dir))
  # Code that ends with a semicolon shows no value, as it does at Julia's prompt
  shows = !failed && endswith(rstrip(code), ';') ? nothing : value
  node = whole = wrong = false
  text = try
    if failed
      Base.invokelatest(sprint, showerror, value)
    elseif nodes && shows isa Union{SemanticUI,GeometricUI}
      node = true
      string(nameof(typeof(shows)))
    else
      # In a file of code a node is a value like any other, and its box lists its fields and its children
      whole = has_members(shows)
      shows === nothing ? "" : declared(shows) ? type_brief(shows, m) : value_text(shows, m)
    end
  catch err
    # A value whose own `show` fails
    wrong = true
    sprint(showerror, err)
  end
  (k=k, value=value, shows=shows, printed=printed, failed=failed, wrong=failed || wrong, world=world, text=text, node=node, whole=whole)
end

"""
What happens in each frame to the code that runs in a thread of its own: each
piece that came back shows what it came to, and while a piece still runs, the
window draws again soon, which turns the spinners.
"""
run_tick!(e) = begin
  runs = state_of(e, CodeRuns).list
  isempty(runs) && return
  for run in copy(runs)
    # It's asked whether the task ended before what it sent is taken, so nothing comes after the last take
    ended = istaskdone(run.task)
    while isready(run.came)
      came_back!(run, take!(run.came))
    end
    ended || continue
    Base.istaskfailed(run.task) && @error "The code of the page couldn't run" exception=TaskFailedException(run.task)
    # A piece that didn't run, after one that failed, has no box
    list = get(e.nodes, run.key, nothing)
    list === nothing || Base.filter!(o -> o.since == 0 || !any(p -> p === o, run.outcomes), list)
    Base.filter!(r -> r !== run, runs)
    run.after === nothing || run.after(e, run.failed == 0 ? nothing : run.outcomes[run.failed])
  end
  isempty(runs) || redraw_in!(e, SPIN_FRAME)
  nothing
end

"Show what a piece of the code `run` came to, in its outcome. `piece` is what `run_piece` gave."
came_back!(run::CodeRun, piece) = begin
  e = run.e
  o, code = run.outcomes[piece.k], run.codes[piece.k]
  # The code can load the drawing methods of a node, so the window draws one more frame soon after
  one_more_frame!(e)
  code_ran!(run.path)
  piece.wrong && run.failed == 0 && (run.failed = piece.k)
  # The levels under the value show the code of what ran
  source = piece.failed ? nothing : source_of(code, piece.value, piece.world)
  said = String(rstrip(piece.printed))
  full = clipped(join(filter(!isempty, [said, piece.text]), "\n"))
  o.brief, o.full = String(first(split(full, '\n'))), full
  o.printed = isempty(said) ? 0 : count('\n', said) + 1
  o.failed = piece.wrong
  o.node = piece.node ? own!(e, Shown(value=piece.shows, inline=true)) : nothing
  o.whole = piece.whole ? piece.shows : nothing
  o.subject = !piece.wrong && (piece.shows isa Union{Function,Module} || declared(piece.shows)) ? piece.shows : nothing
  # A node shows at once, because its name alone says little
  o.open = o.node !== nothing || o.whole isa Union{SemanticUI,GeometricUI}
  o.source = source
  # Code that runs while its block is down a level has its box open, since the code under it is what the level is for
  source !== nothing && code_depth(e, o.first) > 0 && (o.open = true)
  o.since = 0.0
  o
end

"""
Run the code that the caret is in, for ⌘Return and ⇧Return. It's false when
the caret isn't in a `julia` code block or in the code of a sum, so the key
does what it does in other places. With `step`, the caret goes on to the next
expression.
"""
run_here!(e; step=false) = begin
  b = e.buf
  (caretless(b) || readonly(b)) && return false
  found = julia_code(b, b.caret[1])
  (found !== nothing && julia_code(b, b.anchor[1]) == found) || return run_sum_here!(e)
  from, to = found
  lo, hi = minmax(b.caret, b.anchor)
  if lo != hi
    # The code that's selected. A selection that ends at the start of a line doesn't take that line.
    code = excerpt(b, lo, hi)
    until = hi[2] == 0 && hi[1] > lo[1] ? hi[1] - 1 : hi[1]
    lo[1] >= from && until <= to && !isempty(strip(code)) && outcome!(e, lo[1]:until, code)
    touch!(e)
    return true
  end
  runs = [r .+ (from - 1) for r in statements(b.lines[from:to])]
  i = b.caret[1]
  if i < from || i > to
    # The line that opens or closes the block runs all of it, as far as the first piece that fails
    run_pieces!(e, runs, [join(b.lines[r], "\n") for r in runs], stop=true)
  else
    k = findfirst(r -> i in r, runs)
    # A blank line runs the piece above it
    k === nothing && (k = findlast(r -> last(r) < i, runs))
    if k !== nothing
      outcome!(e, runs[k])
      step && (b.caret = b.anchor = k < length(runs) ? (first(runs[k+1]), 0) : line_end(b, last(runs[k])))
    end
  end
  touch!(e)
  true
end

"""
The code of the sum in a line of text that the place `p` is in: its line, and
the columns where its code starts and ends, between the !` and the last `. It's
nothing when `p` isn't in the code of a sum.
"""
sum_code_at(b::Buffer, (i, col)::Pos) = begin
  (b.view == :markdown && 1 <= i <= length(b.lines) && occursin(INLINE, b.lines[i])) || return nothing
  kinds(b)[i].kind in (Kind.fence, Kind.code) && return nothing   # !` in a code block is code
  line = b.lines[i]
  for m in eachmatch(r"!`([^`]+)`", line)
    m.offset > 1 && line[prevind(line, m.offset)] == '\\' && continue   # \!`code` is the code, written out
    from = length(line, 1, m.offset) + 1
    to = from + length(m[1])
    from <= col <= to && return (i, from, to)
  end
  nothing
end

"""
Run the code of the sum that the caret is in, for ⌘Return and ⇧Return, or the
part of it that's selected, like a name in the middle of it. What it comes to
shows in a box under that code, as it does after the code of a `julia` block.
The code runs in the page's module, where the sums and the `julia` blocks of
the page run. It's false when the caret isn't in the code of a sum. As rich
text, the caret stops at each end of what a sum shows, and that isn't in its
code: there the key does what it does in other places.
"""
run_sum_here!(e) = begin
  b = e.buf
  foreign(b.path) && return false   # an email runs no code
  at = sum_code_at(b, b.caret)
  (at !== nothing && sum_code_at(b, b.anchor) == at) || return false
  i, from, to = at
  rich(b) && !(from < b.caret[2] < to && from < b.anchor[2] < to) && return false
  lo, hi = selecting(b) ? minmax(b.caret[2], b.anchor[2]) : (from, to)
  code = excerpt(b, (i, lo), (i, hi))
  if !isempty(strip(code))
    o = outcome!(e, i:i, code)
    o.cols = (lo, hi)
  end
  touch!(e)
  true
end

"""
True while the caret is in the sum whose code the outcome `o` is of, so the sum
shows its code: as plain text, from its ! to after its last `, and as rich
text, in its code. A sum that shows its value has no box under it.
"""
in_its_sum(b::Buffer, o::Outcome) = begin
  at = sum_code_at(b, (o.first, o.cols[1]))
  (at !== nothing && b.caret[1] == o.first) || return false
  _, from, to = at
  rich(b) ? from < b.caret[2] < to : from - 2 <= b.caret[2] <= to + 1
end

"""
Where the box of `o`, an outcome of the code of a sum, goes: under the code
that ran, from the left of it, or from the left of the screen line that the
code ends on when the code wraps. It gives the left and the top of the box,
and the left of that screen line, from the top left of the page's text. It's
nothing when the line isn't laid out as text, or as a cell of a table.
"""
sum_box_place(e, o::Outcome) = begin
  lo, hi = o.cols
  it = item(e, o.first)
  g = it.content
  if g isa Flow
    f, x, y = g, 0px, it.top
  elseif g isa Grid && (at = gridcell(g, (o.first, lo))) !== nothing
    cx, cy = cell_origin(g, at...)
    f, x, y = g.flows[at[1]][at[2]], cx, it.top + cy
  else
    return nothing
  end
  isempty(f.lines) && return nothing
  k1, x1 = spot(f, lo)
  k2, _ = spot(f, max(lo, hi - 1))   # the screen line of the last character, as the end of a line is the start of the next
  vl = f.lines[k2]
  (left=x + (k1 == k2 ? x1 : vl.x), top=y + line_top(f, k2) + vl.high, line=x + vl.x)
end

"""
Run each piece of the code of a file of Julia code, from the top, and show what
each one comes to after it, as ⌘Return does for one piece. A piece that fails
doesn't stop the pieces under it, so every result shows. Then the first piece
that failed comes in sight, when one did. The caret stays where it was.
"""
run_all!(e) = begin
  b = e.buf
  julia_file(b) || error("Run All runs the code of a Julia file.")
  runs = statements(b.lines)
  run_pieces!(e, runs, [join(b.lines[r], "\n") for r in runs], after=bring_failed!)
  redraw_in!(e, 0)
  nothing
end
add_command!(run_all!, title="Run all the code of the file from the top, and show what each piece comes to", kind=:edit)

"After Run All, bring the piece whose outcome is `o` in sight, when one failed. `o` is nothing when none did."
bring_failed!(e, o) = begin
  # The code of a piece that changed since it ran, or a file that's no longer shown, has no outcome on the page
  (o === nothing || !any(p -> p === o, outcomes(e))) && return
  failed = o.first
  r = line_rect(e, failed)
  _, tall = window_size(e)
  if r === nothing || r.top < above_page(e) || r.top + r.height > tall
    note_place!(e)   # so ⌘⌥← goes back
    hold!(e, max(failed - 3, 1), 24px - PAGE_TOP)
  end
  redraw_in!(e, 0)
end

works_here(e, ::Val{:run_all}) = julia_file(e)

"""
Put each outcome of the page on the lines that its code is on now, and forget
the ones whose code changed. Lines that were added or taken away above an
outcome move its code down or up by that many lines.
"""
follow_outcomes!(e) = begin
  b = e.buf
  list = get(e.nodes, (:outcomes, b.path), nothing)
  list === nothing && return Outcome[]
  n = length(b.lines)
  Base.filter!(list) do o
    at(i) = i >= 1 && i + length(o.code) - 1 <= n && all(k -> b.lines[i+k-1] == o.code[k], eachindex(o.code))
    i = at(o.first) ? o.first : o.first + n - o.total
    at(i) || return false
    o.first, o.last, o.total = i, i + length(o.code) - 1, n
    # The box of a sum's code goes when the caret leaves the sum, which then shows its value
    o.cols === nothing || in_its_sum(b, o)
  end
end

"Take every outcome off the page, for Escape. It's false when the page had none."
forget_outcomes!(e) = begin
  list = get(e.nodes, (:outcomes, e.buf.path), nothing)
  (list === nothing || isempty(list)) && return false
  empty!(list)
  true
end

"""
The boxes of the page's outcomes, over the page. Each is after the end of the
last line of its code, and one that has no room there is under that line. The
rest of an outcome that's open is under its box.
"""
outcome_over(e) = begin
  list = follow_outcomes!(e)
  (isempty(list) || isempty(e.layout) || readonly(e.buf)) && return ()
  (zooming(e) === nothing && full_block(e) === nothing && e.popup == :none) || return ()
  w, h = window_size(e)
  side = side_w(e)
  x0 = text_left(e)
  y0 = above_page(e) + PAGE_TOP - e.scroll.offset
  size = body(e).size * 0.8
  wide = measure(outcome_face(size), "0")   # every character of the font is this wide
  # A whole number of pixels, like the top of each box, so that an open box meets the rest under it with no line between them
  high = px(round(num(size * 1.7)))
  at(top, left, node) = Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, left), node)
  # How many characters a box that starts at `left` has room for, beside its padding, its border and its arrow
  fits(left) = floor(Int, num(w - left - OUTCOME_EDGE - 34px) / num(wide))
  boxes, bodies = Any[], Any[]
  for o in list
    if o.cols === nothing
      it = item(e, o.last)
      f = it.content
      f isa Flow || continue
      vl = last(f.lines)
      left = x0 + xcol(vl, vl.to) + OUTCOME_GAP
      top = y0 + it.top + line_top(f, length(f.lines)) + (vl.high - high) / 2
      under = (x0 + vl.x, top + vl.high)
    else
      # The box of a sum's code is under that code, and so over none of it
      p = sum_box_place(e, o)
      p === nothing && continue
      left, top = x0 + p.left, y0 + p.top + 2px
      under = (x0 + p.line, top)
    end
    # While its code is down a level, the box shows the code of what ran, and not its value
    o.low = code_view(e, o)
    brief = o.low === nothing ? o.brief : o.low.title
    # A line that ends too near the edge of the window has the box under it, and a sum's box starts further left
    fits(left) < min(length(brief), 16) && ((left, top) = under)
    top = px(round(num(top)))
    # On a page that's scrolled sideways, a box that would go over the numbers of the lines doesn't show
    (top >= above_page(e) && top + high <= h && left >= x0 + sideways(e)) || continue
    n = max(fits(left), 1)
    o.shown = length(brief) > n ? first(brief, n - 1) * "…" : brief
    # The box of an outcome that's open shows the first line, so the rest starts at the second
    o.rest = o.low !== nothing ? "" : o.shown == o.brief ? String(chopprefix(chopprefix(o.full, o.brief), "\n")) : o.full
    o.from = o.shown == o.brief ? 2 : 1
    o.more = o.low !== nothing || o.node !== nothing || o.subject !== nothing || o.whole !== nothing || !isempty(o.rest)
    o.size, o.high = size, high
    (o.open && o.more) || (push!(boxes, at(top, left, o)); continue)
    o.body === nothing && (o.body = own!(e, OutcomeBody(of=o)))
    if o.low !== nothing
      # The lines of the code: as wide as the widest, and no taller than the room under the box
      o.body.wide = min(wide * max(o.low.cols, 28), w - side - 2OUTCOME_EDGE - 38px)
      o.body.tall = clamp(h - (top + high) - OUTCOME_EDGE - 10px, size * 1.45 * MEMBERS_LEAST, MEMBERS_H)
    elseif o.whole !== nothing
      o.body.members === nothing && (o.body.members = member_lines(o.body, o.whole, 0))
      # As wide as the widest line that shows, and no wider than the window has room for
      cols = max(maximum(length, printed_rest(o), init=0), maximum(member_cols, unfolded(o.body.members), init=0))
      o.body.wide = min(wide * cols, w - side - 2OUTCOME_EDGE - 38px)
      # No taller than the room between the box and the bottom of the window
      o.body.tall = clamp(h - (top + high) - OUTCOME_EDGE - 10px, size * 1.45 * MEMBERS_LEAST, MEMBERS_H)
    end
    # How wide the rest is, with the space around what it shows
    across = o.low !== nothing ? o.body.wide + 19px :
             o.subject !== nothing ? detail_wide(e) :
             o.node !== nothing ? OUTCOME_NODE_W + 22px :
             (o.whole !== nothing ? o.body.wide : wide * maximum(length, split(o.rest, '\n'))) + 19px
    under = max(side + 8px, min(left, w - across - OUTCOME_EDGE))
    natural = outcome_wide(o, wide)
    # The rest that starts under the left of the box is as wide as the box, and the box as wide as the rest
    under == left && (across = max(across, natural))
    # A rest that ends a little to the right of the box would make a small step there. The box is wider, and ends where the rest ends.
    step = under + across - left - natural
    o.across = under == left ? across : 0px < step < 3OUTCOME_ROUND ? natural + step : natural
    # A corner of the rest that the box stands on is square, so the two have one outline
    corner(gap) = gap >= OUTCOME_ROUND ? OUTCOME_ROUND : 0px
    o.body.across = across
    o.body.corners = radius(corner(left - under), corner(under + across - left - o.across), OUTCOME_ROUND, OUTCOME_ROUND)
    o.steps = (left - under, under + across - left - o.across)
    # The box is over the top line of the rest, so no line shows between them
    push!(bodies, at(top + high - 1px, under, o.body), at(top, left, o))
  end
  # The rest of an open outcome goes over the boxes of the lines under it
  (boxes..., bodies...)
end

"""
One line of what code came to, as a row of text. With `code`, its parts have
the colours that a code block gives Julia code. A character that the code font
lacks is drawn in a font that has it, in the room of one character, so the
columns of a matrix stay in line under it.
"""
value_row(text::AbstractString, o::Outcome; code=true) =
  Row(height(o.size * 1.45), Alignment.Center, value_parts(text, outcome_face(o.size, o.failed ? SPELL_RED : colours.ink); code)...)

"The parts of the row that `value_row` makes for `text`, in the font `face`"
value_parts(text::AbstractString, face::Face; code=true) = begin
  cell = measure(face, "0")
  parts = Any[]
  for tok in tokens(text, code ? "julia" : "")
    f = tok.kind == :plain ? face : Face(face, color=getfield(colours, tok.kind), style=tok.kind == :comment ? codeslant() : face.style)
    for (part, pf) in runs(tok.text, f)
      # A character from another font gets the room of one of this font's, so the columns of a matrix stay in line
      wide = pf.family == face.family ? measure(pf, part) : cell * length(part)
      push!(parts, Box(fixed(wide), Alignment.Start,
        Text(part, size=pf.size, family=pf.family, subfamily=pf.style, color=pf.color, wrap=WrapMode.none)))
    end
  end
  parts
end

"True when line `k` of all that the outcome `o` shows is a value, not text that the code printed or what went wrong"
isvalue(o::Outcome, k::Int) = !o.failed && k > o.printed

describe(o::Outcome) = begin
  arrow = o.more ? (Icon(o.open ? "chevron-down" : "chevron-right", size=o.size * 0.8, color=colours.dim),) : ()
  # While the code runs, the box has a spinner in it
  what = o.since > 0 ? Spinner(size=o.size) :
         o.low !== nothing ? value_row(o.shown, o) :
         isempty(o.full) && o.node === nothing ? Box(Icon("check", size=o.size, color=colours.dim)) :
         value_row(o.shown, o, code=isvalue(o, 1) && o.node === nothing)
  # The box of a field of a design is in the field, and the rest is under the field: it isn't one piece with the box
  joined = o.open && o.more && o.across > 0px
  # An open box keeps its colour under the mouse, because the colour would fill only the box and not the rest
  fill = o.more && !joined && ishovered(o) ? colours.hover : colours.float
  box(parts...; name="") = Row(parts..., padding(7px, 0px), child_gap=4px, Alignment.Center, name=name,
                               joined ? radius(OUTCOME_ROUND, OUTCOME_ROUND, 0px, 0px) : radius(5px),
                               background(fill), border(1px, :solid, outcome_line(o)), arrow..., what)
  joined || return box(height(o.high), name="Outcome")
  # An open box is one piece with the rest under it. Its bottom corners are square, and a strip of its
  # own colour is over the line along its bottom. A line on only three sides would have no round corners.
  Stack(fixed(o.across), height(o.high), name="Outcome",
        box(width(grow=grow), height(grow=grow)),
        Column(width(grow=grow), height(grow=grow), padding(1px, 0px),
               Box(width(grow=grow), height(grow=grow)), Box(width(grow=grow), height(1px), background(fill))))
end

describe(d::OutcomeBody) = begin
  o = d.of
  (o.subject === nothing || o.low !== nothing) || return detail_view(editor(d), d)
  inner = o.low !== nothing ? lowered_view(d) :
          d.members !== nothing ? members_view(d) :
          o.node !== nothing ? Box(fixed(OUTCOME_NODE_W), Alignment.Start, o.node) :
          Column(Alignment.Start, [value_row(line, o, code=isvalue(o, o.from + k - 1)) for (k, line) in enumerate(split(o.rest, '\n'))]...)
  # Text and the lines of a list start under the arrow of the box
  around = o.node !== nothing && o.low === nothing ? padding(10px, 8px) : padding(3px, 10px, 6px, 7px)
  Box(fixed(d.across), around, d.corners, background(colours.float), border(1px, :solid, outcome_line(o)), lifted, Alignment.Start,
      name="Outcome body", inner)
end

"""
The list of the parts of the value of the open box `d`: a line for each part,
with the lines of an open part's own parts under it. Text that the code
printed is over the list. A list that's taller than `MEMBERS_H`, or than the
room that the window has under the box, shows that much of itself, and the
wheel moves through the rest.
"""
members_view(d::OutcomeBody) = begin
  o = d.of
  said = [value_row(line, o, code=false) for line in printed_rest(o)]
  lines = unfolded(d.members)
  high = o.size * 1.45 * (length(said) + length(lines))
  inside = Column(width(grow=grow), Alignment.Start, said..., lines...)
  Box(width(grow=grow), height(min(high, d.tall)), Alignment.Start, clip=true, reuse!(d.scroll, inside))
end

describe(m::Member) = begin
  o = m.of.of
  face = outcome_face(o.size)
  cell = measure(face, "0")
  arrow = m.more ? (Icon(m.open ? "chevron-down" : "chevron-right", size=o.size * 0.7, color=colours.dim),) : ()
  Row(width(grow=grow), height(o.size * 1.45), Alignment.Center, radius(4px), name="Outcome part",
      padding(0px, 0px, 0px, cell * MEMBER_INDENT * m.depth), background(m.more && ishovered(m) ? colours.hover : clear),
      (m.room ? (Box(fixed(cell * MEMBER_INDENT), height(o.size * 1.45), arrow...),) : ())...,
      value_parts(m.name, face, code=false)..., value_parts(": ", Face(face, color=colours.dim), code=false)...,
      value_parts(m.text, face)...)
end

cursor(m::Member) = m.more ? :hand : :arrow
onmouse(::Member, ::MouseMove) = handled
onscroll(m::Member, ev::MouseScroll) = onscroll(m.of, ev)
# A click on a line whose value has parts shows them under the line, or hides them
onkey(m::Member, ::KeyPress{Keys.mouse_left}) = begin
  m.more || return handled
  m.inside === nothing && (m.inside = member_lines(m.of, m.value, m.depth + 1))
  m.open = !m.open
  handled
end

"A ring that turns, `size` across, in the box of an outcome whose code still runs"
@def mutable struct Spinner <: SemanticUI
  size::px = 12px
end

describe(s::Spinner) = Box(fixed(s.size), height(s.size), name="Spinner")

# A faint ring, with a quarter of it darker. The quarter goes round once in `SPIN_TURN` seconds.
draw(ctx, size, ui::ConcreteRect, s::Spinner) = begin
  wide = max(num(s.size) / 7, 1.5)
  r = Float32((min(num(ui.width), num(ui.height)) - wide) / 2)
  x, y = Float32(num(ui.left) + num(ui.width) / 2), Float32(num(ui.top) + num(ui.height) / 2)
  ring = ink(RGBA(colours.dim, 0.3), wide)
  Skia.sk_canvas_draw_circle(ctx, x, y, r, ring)
  Skia.sk_paint_delete(ring)
  oval = Ref(Skia.sk_rect_t(x - r, y - r, x + r, y + r))
  arc = ink(colours.dim, wide)
  Skia.sk_canvas_draw_arc(ctx, oval, Float32(360 * mod(time(), SPIN_TURN) / SPIN_TURN), 90f0, false, arc)
  Skia.sk_paint_delete(arc)
end

# Where the rest under an open box goes on past a side of the box, the box and the rest meet in an inside
# corner. That corner is round too, as the outside corners are, so the outline of the two has no sharp turn.
draw(ctx, size, ui::ConcreteRect, o::Outcome) = begin
  (o.open && o.more) || return
  y = num(ui.top + ui.height) - 0.5   # the middle of the line along the top of the rest
  for (gap, x, way) in ((o.steps[1], num(ui.left) + 0.5, -1), (o.steps[2], num(ui.left + ui.width) - 0.5, 1))
    # The rest has a round corner of its own at its end, so a short step leaves less room for this one
    r = min(num(gap) - num(OUTCOME_ROUND), num(OUTCOME_ROUND))
    r >= 2 && inside_corner(ctx, x, y, r, way, colours.float, outcome_line(o))
  end
end

"""
Round the inside corner where the side of a box, at `x`, comes down onto a line
across, at `y`. `way` is -1 when the line goes on to the left of the box and 1
when it goes on to the right. The corner is filled with `fill`, which covers
the two lines where they met, and a quarter circle of radius `r` joins them in
the colour `line`.
"""
inside_corner(ctx, x, y, r, way, fill, line) = begin
  cx, cy = x + way * r, y - r   # the middle of the circle
  oval = Ref(Skia.sk_rect_t(Float32(cx - r), Float32(cy - r), Float32(cx + r), Float32(cy + r)))
  # Skia measures angles clockwise from 3 o'clock. The quarter goes from the side of the box down to the line across.
  from, sweep = way < 0 ? (0f0, 90f0) : (180f0, -90f0)
  shape = Skia.sk_path_new()
  Skia.sk_path_move_to(shape, Float32(x - way * 0.6), Float32(y - r))
  Skia.sk_path_line_to(shape, Float32(x), Float32(y - r))
  Skia.sk_path_arc_to_with_oval(shape, oval, from, sweep, false)
  Skia.sk_path_line_to(shape, Float32(x + way * r), Float32(y + 0.6))
  Skia.sk_path_line_to(shape, Float32(x - way * 0.6), Float32(y + 0.6))
  Skia.sk_path_close(shape)
  paint = ink(fill)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_paint_delete(paint)
  Skia.sk_path_delete(shape)
  curve = Skia.sk_path_new()
  Skia.sk_path_arc_to_with_oval(curve, oval, from, sweep, true)
  paint = ink(line, 1.0)
  Skia.sk_canvas_draw_path(ctx, curve, paint)
  Skia.sk_paint_delete(paint)
  Skia.sk_path_delete(curve)
end

cursor(o::Outcome) = o.more ? :hand : :arrow
cursor(::OutcomeBody) = :arrow
# A click on a box shows the rest of what the code came to, or hides it. It doesn't move the caret.
onkey(o::Outcome, ::KeyPress{Keys.mouse_left}) = (o.more && (o.open = !o.open); handled)
onmouse(::Outcome, ::MouseMove) = handled
# A click on the rest is not a click on the text under it
onkey(::OutcomeBody, ::KeyPress{Keys.mouse_left}) = handled
onmouse(::OutcomeBody, ::MouseMove) = handled
# The wheel moves through the documentation and the table of a function or a module, not through the page under them
onscroll(d::OutcomeBody, ev::MouseScroll) = begin
  # The lines of code that a box shows while its code is down a level move as a list of parts does
  low = d.of.low !== nothing
  low && d.scroll.content_height <= d.scroll.viewport && return nothing
  # A list of parts that all shows leaves the wheel to the page
  (!low && d.detail === nothing && (d.members === nothing || d.scroll.content_height <= d.scroll.viewport)) && return nothing
  s = low || d.detail === nothing ? d.scroll : d.detail.scroll
  s.offset = clamp(s.offset - ev.delta[2] * 30, 0px, max(0px, s.content_height - s.viewport))
  handled
end
