# A check that fails, and the steps of a check
#
# A check of a file of Julia code that fails can ask an agent to fix it: the
# command Fix Check, or Fix It beside the check while the mouse or the caret
# is on its line. The agent gets the check, what it came to, and the function
# under it. It changes the function, or the check when the check is what's
# wrong, and says which. When it ends, the changed code runs, and so the check
# runs again. Ask For Checks asks an agent to write checks of a function, with
# the values that the function should give, which it works out from what the
# function is for. See "checks in a file of Julia code" and "ask for a change
# to a thing".

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use Colors: @colorant_str
@use "../base" exports...
@use "../additions" exports...
@use "../blocks/check_view" exports...
@use "../agent/ask" exports...
@use "../window/showed_before" note_place!

export check_now, checked_block, fix_check!, ask_for_checks!, check_button!, STEP_INK, arg_names, arg_name,
       noted, noted_line, first_call, called_names, definitions, check_steps, show_steps!, mark_steps, ShownSteps, shown_steps, hide_steps!

worded(c::FileCheck) = c.code
sidenote(c::FileCheck) = (c.went == :pass ? "passes" : c.went == :fail ? "fails" : "stops") * " · line $(c.line)"

"The checks of the file that the window of `e` shows, for the palette's list: the one on the caret's line first, then those that fail, from the top"
choices_for(::Type{FileCheck}, e) = begin
  at = e.buf.caret[1]
  sort!([FileCheck(i, r.code, r.went) for (i, r) in file_results(e)], by=c -> (c.line != at, c.went == :pass, c.line))
end
# The check on the caret's line is the one, or else the first that fails
chip_start(::Type{FileCheck}, e) = begin
  found = choices_for(FileCheck, e)
  isempty(found) || (first(found).line != e.buf.caret[1] && first(found).went == :pass) ? nothing : first(found)
end
shown_at(e, c::FileCheck) = line_rect(e, c.line)

"The check `c` as the file has it now: its line, and how it went when it last ran. It's an error when the file doesn't have it."
check_now(e, c::FileCheck) = begin
  found = file_results(e)
  k = findfirst(((i, r),) -> r.code == c.code && i == c.line, found)
  k === nothing && (k = findfirst(((_, r),) -> r.code == c.code, found))
  k === nothing && error("The file doesn't have the check $(c.code) now.")
  found[k]
end



"The block of code that the check on line `i` checks: the one that has the first line of code under it"
checked_block(e, i::Int) = begin
  at = code_start(e.buf.lines, i)
  blocks = code_blocks(e)
  k = findfirst(x -> x.first <= at <= x.last, blocks)
  (k === nothing || at == i) && error("Ladder can't find the function under the check on line $i.")
  blocks[k]
end

"""
Ask an agent to make the check `check` of the file that the window of `e`
shows pass. It changes the function under the check, or the check when the
check is what's wrong. See "a check that fails".
"""
fix_check!(e, check::FileCheck) = begin
  julia_file(e) || error("Fix Check is for a check of a file of Julia code.")
  i, r = check_now(e, check)
  r.went == :pass && error("This check passes.")
  needs_run(e, r) && error("The file's code hasn't run, so the check can't. Press ⌘Return in its function first.")
  agent_free(e)
  c = checked_block(e, i)
  _, start = thing_words(c)
  how = r.went == :fail ? (isempty(r.said) ? "Now it comes to false." : "Now it comes to false: $(r.said).") : "Now it stops: $(r.said)"
  prompt = """
    The user of the app Ladder asked for a check of a file of Julia code to pass.

    The check is the comment on line $i of the file $(c.file):

        $(strip(e.buf.lines[i]))

    Ladder runs the code after `# check:` in the module of the file's code, and it should come to true. $how

    It checks the code at lines $(c.first) to $(c.last) of the file, which starts:

        $start

    Change that code, or the code that it uses, so that the check passes. If the check is what's wrong, as when it expects a value that the code shouldn't give, change the check, and say so. Change only files in $(dirname(c.file)). Keep the change small, and write code that looks like the code around it. Ladder runs the changed code as soon as you end, so leave the file in a state that runs. Then say what you changed, in one short sentence.
    """
  words = "Fix the check $(r.code)"
  queue_ask!(e, words, [c], said -> ask_change!(e, [c], said; prompt=reworded(prompt, words, said)))
end
add_command!(fix_check!, title="Ask an agent to make a check of the file pass, by changing the function under it", kind=:edit)

works_here(e, ::Val{:fix_check}) = julia_file(e) && any(((_, r),) -> r.went != :pass, file_results(e))

"""
Ask an agent to write checks of `node`, a function of a file of Julia code, as
comments like `# check: share("70%") == 0.7` over it. The agent works out the
value that each call should give from what the function is for, and not from
what it does now. See "a check that fails".
"""
ask_for_checks!(e, node::ToChange) = begin
  (node.node === nothing && endswith(node.file, ".jl")) || error("Checks of this kind go over a function of a file of Julia code.")
  agent_free(e)
  what, start = thing_words(node)
  prompt = """
    The user of the app Ladder asked for checks of $what.

    It's in the file $(node.file), lines $(node.first) to $(node.last). It starts:

        $start

    A check is a comment over a function, like this one over a function called share:

        # check: share("70%") == 0.7

    Ladder runs the code after `# check:` in the module of the file's code. It shows a green dot when the code comes to true, and a red dot when it doesn't.

    Write two to four checks of each function in that code. Choose calls that show what the function is for, and one at an edge of what it takes. Work out the value that each call should give from what the function is for: its name, its documentation, and the code that calls it. Don't copy what the code does now, because a check finds a fault only when it says what the code should do. Put each check on a line of its own, after the function's documentation and the checks that it has, just over its first line of code. Each check is one line of Julia. Change nothing else. Then say what the checks check, in one short sentence.
    """
  queue_ask!(e, "Write checks", [node], said -> ask_change!(e, [node], said; prompt=reworded(prompt, "Write checks", said)))
end
add_command!(ask_for_checks!, title="Ask an agent to write checks of a function, with the values that it should give")

works_here(e, ::Val{:ask_for_checks}) = julia_file(e)

"""
What a click at the mouse of the window `w` does on a button beside a check
of a file of Julia code: Fix It or Show Steps. It's true when the click was on
one. What goes wrong shows under the top bar.
"""
check_button!(e, w) = begin
  found = check_buttons(e)
  isempty(found) && return false
  x, y = num(w.mouse[1]), num(w.mouse[2])
  for (action, (left, top, wide, tall), check) in found
    (left <= x <= left + wide && top <= y <= top + tall) || continue
    try
      Base.invokelatest(action == :fix ? fix_check! : show_steps!, e, check)
    catch err
      err isa InterruptException && rethrow()
      say_result!(e, first(split(sprint(showerror, err), '\n')))
    end
    return true
  end
  false
end

# --- the steps of a check ---
#
# Show Steps runs a check of a file of Julia code again, and writes what each
# line of the function that it calls came to, at the end of that line: what
# the function was given on its first line, and the value of each line after
# that. A line that ran more than once shows its last value and how many
# times it ran. The line where the function stopped says why. The function
# runs as the window has it, which can be newer than the code that ran last.
# The values go when the text changes, and with Esc. ⌘⌥← goes back to where
# the caret was, when the window scrolled to the function.

const STEP_INK = colorant"rgb(48,128,236)"





"The name of each value that the function of the definition `def` takes, from its first line, like `share(s; places=2)`"
arg_names(def) = begin
  out = Symbol[]
  for a in def_call(def).args[2:end], x in (Meta.isexpr(a, :parameters) ? a.args : (a,))
    n = arg_name(x)
    n === nothing || push!(out, n)
  end
  out
end

"The name of a value that a function takes, from how its definition writes it, like `s`, `s::String`, `places=2` or `rest...`. It's nothing for one with no name, like `::Int`."
arg_name(a) = a isa Symbol ? a :
  Meta.isexpr(a, :(::)) ? (length(a.args) == 2 ? arg_name(a.args[1]) : nothing) :
  Meta.isexpr(a, (:kw, :(=), :(...))) ? arg_name(a.args[1]) : nothing

"""
The block `ex` of a function's code, with each of its lines sending what it
came to and its line's number to `note` as it runs. The lines in an `if`, a
loop, a `let` or a `try` send theirs too. `line` is the line that the block
starts on.
"""
noted(ex, note, line::Int) = begin
  Meta.isexpr(ex, :block) || return noted_line(ex, note, line)
  out = Expr(:block)
  for x in ex.args
    x isa LineNumberNode ? (line = x.line; push!(out.args, x)) : push!(out.args, noted_line(x, note, line))
  end
  out
end

"One line `x` of a function's code, on line `line`, that sends what it came to to `note`: see `noted`"
noted_line(x, note, line) = begin
  x isa Expr || return Expr(:call, note, line, x)
  h = x.head
  h in (:if, :elseif, :while, :for, :let) && return Expr(h, x.args[1], (noted(a, note, line) for a in x.args[2:end])...)
  h == :try && return Expr(h, (Meta.isexpr(a, :block) ? noted(a, note, line) : a for a in x.args)...)
  h == :block && return noted(x, note, line)
  h == :return && return Expr(:return, Expr(:call, note, line, isempty(x.args) ? nothing : x.args[1]))
  # A line that defines something, or that goes to another line, has no value to show
  (h in (:function, :macro, :struct, :abstract, :primitive, :const, :global, :local, :break, :continue, :using, :import, :meta) ||
    definition_of(x) !== nothing || (h == :macrocall && x.args[1] in (Symbol("@goto"), Symbol("@label")))) && return x
  # A line in a block is still a line of the function, so a name that it gives a value to is the function's
  Expr(:call, note, line, Expr(:block, x))
end

"The first call in `ex`, from the outside in, of a name in `names`, or nothing"
first_call(ex, names) = begin
  ex isa Expr || return nothing
  Meta.isexpr(ex, :call) && ex.args[1] isa Symbol && ex.args[1] in names && return ex
  for a in ex.args
    found = first_call(a, names)
    found === nothing || return found
  end
  nothing
end

"Each name that `ex` calls, from the outside in, that a function of a file can have: not an operator like `==`"
called_names(ex, out=Symbol[]) = begin
  ex isa Expr || return out
  Meta.isexpr(ex, :call) && ex.args[1] isa Symbol && occursin(r"^[\p{L}_][\p{L}\p{N}_!]*$", String(ex.args[1])) && !(ex.args[1] in out) && push!(out, ex.args[1])
  foreach(a -> called_names(a, out), ex.args)
  out
end

"""
The definitions of the function called `name` in the lines `lines` of a file
of Julia code, each with the line that it starts on: one for each method.
Their lines have the numbers that they have in the file.
"""
definitions(lines::Vector{String}, name::Symbol) = begin
  out = Tuple{Int,Expr}[]
  word = String(name)
  for (first, code) in part_texts(lines)
    occursin(word, code) || continue
    def = definition_of(part_expr("\n"^(first - 1) * code))
    def !== nothing && def_call(def).args[1] == name && push!(out, (code_start(lines, first), def))
  end
  out
end

"""
Run the check `check` of the file that the window of `e` shows again, with
each line of the function that it calls first sending what it came to: see
"the steps of a check". It gives the line that the function starts on, the
words for the end of each line, and the line where the function stopped, or 0.
"""
check_steps(e, check::FileCheck) = begin
  b = e.buf
  ex = Meta.parse(check.code, raise=false)
  Meta.isexpr(ex, (:error, :incomplete)) && error("Julia can't read this check.")
  name, defs = nothing, Tuple{Int,Expr}[]
  for n in called_names(ex)
    defs = definitions(b.lines, n)
    isempty(defs) || (name = n; break)
  end
  name === nothing && error("This check calls no function of this file.")
  # A name that no code can write, so the function is no other
  traced = Symbol("steps of ", name)
  seen = Dict{Int,Tuple{Any,Int}}()   # the last value of each line, and how many times it ran
  given = Dict{Int,Any}()             # what the function was given, by the line that it starts on
  note = (line, value) -> (was = get(seen, line, (nothing, 0)); seen[line] = (value, was[2] + 1); value)
  give = (line, values) -> (given[line] = values; nothing)
  call = first_call(ex, (name,))
  call.args[1] = traced
  stopped, why = 0, ""
  dir = isdir(docdir(e)) ? docdir(e) : pwd()
  cd(dir) do
    running_code(e) do m
      try
        for (line, def) in defs
          def = copy(def)
          head = def_call(def)
          head.args[1] = traced
          names = arg_names(def)
          body = noted(def.args[2], note, line)
          isempty(names) || pushfirst!(body.args, Expr(:call, give, line, Expr(:tuple, Expr(:parameters, names...))))
          Core.eval(m, Expr(def.head, def.args[1], body))
        end
        Core.eval(m, ex)
      catch err
        err isa InterruptException && rethrow()
        # The line of the function that was running when it stopped
        for f in stacktrace(catch_backtrace())
          f.func === traced && (stopped = f.line; break)
        end
        why = replace(String(first(split(trouble(err), '\n'))), r" in `Main\.[^`]*`" => "")
        stopped == 0 && !isempty(seen) && (stopped = maximum(keys(seen)))
      finally
        Base.invokelatest(isdefined, m, traced) && foreach(Base.delete_method, Base.invokelatest(methods, Base.invokelatest(getfield, m, traced)))
      end
    end
  end
  isempty(seen) && isempty(given) && error(isempty(why) ? "The check didn't call $name." : "The check stopped before it called $name: $why")
  words = Dict{Int,String}()
  for (line, (value, n)) in seen
    words[line] = "→ " * value_brief(value) * (n > 1 ? "  ($n times)" : "")
  end
  for (line, values) in given
    gave = join(("$k = $(value_brief(v))" for (k, v) in pairs(values)), ", ")
    words[line] = haskey(words, line) ? gave * "  " * words[line] : gave
  end
  stopped > 0 && (words[stopped] = get(words, stopped, "") * (haskey(words, stopped) ? "  " : "") * "stopped: $why")
  (first=minimum(first.(defs)), words=words, stopped=stopped)
end

"What each line of the function of Show Steps came to, which the window keeps while the text is as it was: see `show_steps!`"
@def mutable struct ShownSteps
  steps::Union{Nothing,NamedTuple} = nothing   # what `check_steps` gave, with the version of the text
end

"The steps that Show Steps shows in the window of `e`, or nothing when it shows none"
shown_steps(e) = state_of(e, ShownSteps).steps

"Take away the steps that Show Steps shows in the window of `e`"
hide_steps!(e) = (state_of(e, ShownSteps).steps = nothing; e)

"""
Run the check `check` of a file of Julia code again, and write what each line
of the function that it calls came to at the end of that line. See "the steps
of a check".
"""
show_steps!(e, check::FileCheck) = begin
  julia_file(e) || error("Show Steps is for a check of a file of Julia code.")
  steps = check_steps(e, check)
  state_of(e, ShownSteps).steps = (; steps..., version=e.buf.version)
  # The function comes in sight, near the top of the window, when it isn't
  r = line_rect(e, steps.first)
  _, tall = window_size(e)
  if r === nothing || r.top < above_page(e) || r.top + r.height > tall
    note_place!(e)
    hold!(e, max(steps.first - 3, 1), 24px - PAGE_TOP)
  end
  redraw_in!(e, 0)
  nothing
end
add_command!(show_steps!, title="Run a check of the file again, and show what each line of the function that it calls came to", kind=:look)

works_here(e, ::Val{:show_steps}) = julia_file(e) && !isempty(file_results(e))

"Draw what each line of the function of Show Steps came to, at the end of the line. The page's text is at `ui`."
mark_steps(ctx, e, ui) = begin
  s = shown_steps(e)
  s === nothing && return nothing
  s.version == e.buf.version || (hide_steps!(e); return nothing)
  for it in e.layout[e.shown]
    f = it.content
    f isa Flow || continue
    words = get(s.words, it.first, nothing)
    words === nothing && continue
    k = length(f.lines)
    vl = f.lines[k]
    right = isempty(vl.segs) ? 0px : last(vl.segs).x + last(vl.segs).w
    mid = num(ui.top + it.top + line_top(f, k) + vl.high / 2)
    write_ink(ctx, words, num(ui.left + right) + 14, mid + 4, Face(SANS, "", px(round(num(f.size) * 0.85)), it.first == s.stopped ? CHECK_BAD : STEP_INK, false))
  end
  nothing
end
