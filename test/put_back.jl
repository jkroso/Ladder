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
