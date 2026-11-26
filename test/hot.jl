# Run the tests in one Julia process that stays open, so that a change to a
# source file costs a reload of the changed code and not a new start of Julia.
# The script `test/hot` starts this file and sends it tests:
#
#     test/hot                          # start the process, and leave it running
#     test/hot test/board_view_test.jl  # run one test in it, from another terminal
#     test/hot all                      # run every test in it, and list what failed
#     test/hot stop                     # end the process
#
# The first test that loads main.jl takes about half a minute, since Kip loads
# each file from its source here. After that a test takes seconds. Before each
# test, the process loads what changed in the files that Kip has loaded. The
# code that reads a file and runs what changed in it is UI.jl's own, from its
# `examples/hot_reload.jl`, so a test sees a change the way the app does when
# you run it with hot reload.
#
# A request is a file in `test/.hot/req` whose name ends in `.req`, with three
# lines: the test file, the file for its output, and the file to write when
# the test is done ("pass" or "fail").
#
# What to know:
#   - A struct with new fields makes its file, and the files that use it, run
#     again from the top. That takes longer, once.
#   - A method that you delete stays until the process starts again.
#   - Every test shares the one process. When a test ends, each Ref that its
#     text sets, like `K.SETTINGS_FILE[] = ...` or `K.AGENT_COMMAND[] = ...`,
#     gets back the value it had before the test: see put_back.jl. Other things
#     stay as the test left them: the open windows, what's in a table of
#     Ladder's, a function that a test defined again with `@eval K`. So a test
#     can fail here and pass by itself. Run a test that fails here once in a
#     process of its own, and do the same with the tests of what you changed
#     before you call the work done:
#     `KIP_FROZEN=1 julia -O0 --project=. test/board_view_test.jl`.
#   - A test that saves pictures reads `LADDER_SHOTS` from this process, so
#     set it when you start the process.

using Kip, Logging
include("put_back.jl")

ENV["KIP_FROZEN"] = "1"   # Kip loads each file from its source, so each has a module to load changes into
const REQUESTS = joinpath(@__DIR__, ".hot", "req")

# UI.jl's folder is where Kip loads this small file of it from
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc
const UI = dirname(dirname(only(path for path in keys(Kip.modules) if endswith(path, joinpath("Interface", "objc.jl")))))

# The parts of hot_reload.jl that read a file's code and run what changed in it. The parts that
# are about its window stay out.
const WINDOW_PARTS = ("GLFW", "MiniFB", "ARGS", "started", "Threads.", "entry", "KIP_FROZEN", "while true", "using Kip")
for ex in Meta.parseall(read(joinpath(UI, "examples", "hot_reload.jl"), String)).args
  ex isa Expr || continue
  any(part -> occursin(part, string(ex)), WINDOW_PARTS) && continue
  Core.eval(@__MODULE__, ex)
end
const saved = Ref(false)
restart!() = (restart[] = true)

"Load every change since the last look. A struct with new fields makes its file and the files that use it run again."
reload_all!() =
  for _ in 1:20
    restart[] = false
    reload!()
    restart[] || break
  end

# Ladder is loaded before the first test, so that its Refs are known, with their values, before
# a test sets them. Then the first test's Refs go back too.
@use "../main" => Ladder
track!()

"What a test file's own `exit()` throws here, so that the process stays open"
struct Ended <: Exception
  code::Int
end

"Run the test file at `path` in a module of its own, with its output in the file `log`. True when it passed."
run_test(path, log) = open(log, "w") do io
  redirect_stdio(stdout=io, stderr=io) do
    t = time()
    m = Module(:HotTest)
    before = nothing
    ok = try
      reload_all!()
      before = refs_now()
      Core.eval(m, :(using Kip))
      Core.eval(m, :(include(path) = Base.include($m, path)))
      Core.eval(m, :(exit(code=0) = throw($Ended(code))))
      Base.include(m, path)
      true
    catch e
      # A file that ends with `exit()` is done. The error can come inside the one that says where it was thrown.
      while e isa LoadError
        e = e.error
      end
      e isa Ended ? e.code == 0 : (showerror(stderr, e, catch_backtrace()); println(stderr); false)
    end
    # The Refs that the test set go back to what they were, so the next test doesn't get them
    if before !== nothing
      try
        back = put_back!(before, path, m)
        isempty(back) || println("Put back: ", join(back, ", "))
      catch e
        println(stderr, "Couldn't put back the Refs that the test set: ", sprint(showerror, e))
      end
    end
    # Watch the files that this test loaded, as they are now, so that a change that's saved later is seen
    track!()
    println(ok ? "PASS " : "FAIL ", path, " in ", round(time() - t, digits=1), " s")
    flush(stdout); flush(stderr)
    ok
  end
end

mkpath(REQUESTS)
say("Ready. Run a test from another terminal: test/hot test/board_view_test.jl")
while true
  for name in sort(filter(endswith(".req"), readdir(REQUESTS)))
    lines = readlines(joinpath(REQUESTS, name))
    rm(joinpath(REQUESTS, name))
    name == "stop.req" && exit(0)
    length(lines) >= 3 || continue
    test, log, done = lines[1:3]
    say("Running ", short(test))
    ok = Base.invokelatest(run_test, abspath(test), log)
    write(done, ok ? "pass" : "fail")
    say(ok ? "  passed" : "  FAILED")
  end
  sleep(0.2)
end
