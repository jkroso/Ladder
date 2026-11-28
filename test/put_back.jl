# Putting back the Refs that a test set, so that the next test in the same
# process starts as it would in a process of its own. hot.jl does this around
# each test:
#
#     before = refs_now()
#     Base.include(m, path)          # the test, in its module `m`
#     put_back!(before, path, m)
#
# A test sets a Ref of Ladder's to give it something of the test's own: a
# settings file (`K.SETTINGS_FILE[]`), a clock, a fake browser or agent. Only
# the Refs that the test's text sets, as `K.AGENT_COMMAND[] = ...`, go back.
# Other Refs change as Ladder runs, like the count of changes that tells a kept
# layout it's out of date, or the flag that a thread is running. Putting those
# back would make Ladder believe what's no longer true.
#
# The environment goes back too, all of it: a test sets a variable like
# `GIT_AUTHOR_NAME`, `TZ` or `PATH` for the programs that it starts, and the
# next test's programs would get it.

using Kip

"Each Ref of the files that Kip has loaded, with its value now"
refs_now() = begin
  values_now = IdDict{Any,Any}()
  for m in values(Kip.modules), name in names(m, all=true)
    try
      isdefined(m, name) && isconst(m, name) || continue
      r = getglobal(m, name)
      r isa Base.RefValue && isassigned(r) && (values_now[r] = r[])
    catch
    end
  end
  values_now
end

"The names before `[] =` in the text of the file at `path`, like \"K.AGENT_COMMAND\""
set_refs(path) = Set(m.captures[1] for m in eachmatch(r"([A-Za-z_][\w.]*)\[\]\s*=(?!=)", read(path, String)))

"""
Give each Ref that the test file at `path` sets the value it had in `before`.
The test's module `m` says what each name in its text is, so `W.OPENER` finds
the Ref of webpage.jl when the test has `const W = K.Webpages`. A name that
leads to no Ref that was there before the test is left alone. The names of
the Refs put back are returned.
"""
put_back!(before, path, m) = begin
  done = String[]
  for name in sort!(collect(set_refs(path)))
    r = try Core.eval(m, Meta.parse(name)) catch; nothing end
    (r isa Base.RefValue && haskey(before, r)) || continue
    r[] === before[r] && continue
    r[] = before[r]
    push!(done, name)
  end
  done
end

"Each variable of the environment, with its value now"
env_now() = Dict{String,String}(ENV)

"Give the environment the variables that it had in `before`, and take away the ones that it didn't have. The names of those that changed are returned."
put_back_env!(before) = begin
  done = String[]
  for name in collect(keys(ENV))
    haskey(before, name) || (delete!(ENV, name); push!(done, name))
  end
  for (name, value) in before
    get(ENV, name, nothing) == value || (ENV[name] = value; push!(done, name))
  end
  sort!(done)
end

# A test leaves other things too, which the next test in the process would
# meet. These go back whether or not the test's text names them: hot.jl calls
# `left_now` before a test and `clear_left!` after it.
#
#   - What every window shows: the toasts, what live blocks said went wrong,
#     and the changes that agents made. The next test's window would show a
#     toast that it didn't make, and Undo Change would undo an older test's change.
#   - A window that the test opened as Ladder opens its own and didn't close.
#     It stays in the list of the open windows, which other tests count.

"The lists of main.jl that every window shows from"
const SHOWN_LISTS = (:TOASTS, :problems, :AGENT_CHANGES)

"What a test can leave behind, as it is now: the lists and the open windows of `ladder`, the module of main.jl"
left_now(ladder) = (lists=[copy(getglobal(ladder, name)) for name in SHOWN_LISTS], windows=copy(ladder.editors))

"""
Put back what `left_now` noted in `before`: each list gets what it held, and
each window that has opened since then closes. What went back is returned, as
words.
"""
clear_left!(ladder, before) = begin
  done = String[]
  for (name, was) in zip(SHOWN_LISTS, before.lists)
    list = getglobal(ladder, name)
    list == was || (empty!(list); append!(list, was); push!(done, String(name)))
  end
  for e in copy(ladder.editors)
    any(o -> o === e, before.windows) && continue
    w = ladder.window_of(e)
    w === nothing || close(w)
    filter!(o -> o !== e, ladder.editors)
    push!(done, "the window of $(isempty(e.buf.path) ? "a page with no file" : basename(e.buf.path))")
  end
  sort!(done)
end

"""
Make UI.jl forget what it keeps for every window: its popups, its last frame,
the node under the mouse. `draw` is UI.jl's Interface/draw, which keeps each
of these in a table by the window's id, and forgets a window's when the window
closes. Most tests never close their windows. Julia gives a later window the
id of one that it has freed, so a test's new window would start with the popups
of an old one. How many windows were forgotten is returned.
"""
forget_windows!(draw) = begin
  tables = Dict[]
  for name in names(draw, all=true)
    isdefined(draw, name) && isconst(draw, name) || continue
    t = getglobal(draw, name)
    t isa Dict && keytype(t) === UInt && push!(tables, t)
  end
  ids = Set{UInt}()
  foreach(t -> union!(ids, keys(t)), tables)
  foreach(empty!, tables)
  length(ids)
end
