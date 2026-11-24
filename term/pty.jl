# A program that runs on a pseudo-terminal, as a shell runs in a terminal app.
#
#     s = start(["/bin/zsh", "-l"], dir=homedir(), rows=24, cols=80)
#     send!(s, "ls\r")          # what the person types
#     bytes = take!(s)          # what the program wrote since this was last asked
#     resize!(s, 30, 100)       # the terminal has another size, and the program is told
#     alive(s)                  # false when the program has ended
#     stop!(s)
#
# The program thinks that it's in a terminal: it has a terminal for its input
# and its output, that terminal is the one that controls it, so Control-C
# stops what runs in it, and it's told when the size changes. What it writes
# has escape codes in it, which `screen.jl` reads.
#
# The program's output is read on a second thread, so it comes while the
# window waits for input. `wake` is called there each time more has come, and
# when the program ends. A window gives a function that makes it draw again.
#
# Julia does all its reading and writing on its main thread, in the moments
# when that thread has nothing else to do. A window keeps the main thread
# waiting for the keyboard and the mouse, so nothing would be read until a
# key went down. So from the first `start` on, a thread of its own does
# Julia's reading and writing: see `own_io!`.

const O_RDWR = Base.Filesystem.JL_O_RDWR
const O_NOCTTY = Base.Filesystem.JL_O_NOCTTY
# The number of the call that sets the size of a terminal
const SET_SIZE = Sys.isapple() ? 0x80087467 : 0x5414

const MOST_WAITING = 4_000_000   # bytes that a program can have written before it waits for them to be taken

mutable struct Shell
  fd::Cint
  io::Base.TTY
  process::Base.Process
  got::Vector{UInt8}               # what the program wrote and nothing took yet
  lock::ReentrantLock
  out::Channel{Vector{UInt8}}      # what waits to be sent to the program
  wake::Any
  ended::Bool                      # every program let go of the terminal: nothing more will be written
end

# A Shell shows as one word. Its process holds the whole environment, which has the person's keys and
# tokens in it, and an error's text must never print those.
Base.show(io::IO, s::Shell) = print(io, "Shell(", s.ended ? "ended" : "running", ")")

# sh makes the pseudo-terminal the one that controls it by opening it, sets its size, and becomes the program
const BECOME = "exec <\"\$0\" >\"\$0\" 2>&1; stty rows \"\$1\" cols \"\$2\"; shift 2; exec \"\$@\""

# What Ladder's own environment says of the place that Ladder was started from: that it shows no colour, which
# terminal app it is, how big it is, and that an agent runs there. None of it is true of this terminal. A Ladder
# that an agent started has NO_COLOR, and a program like Claude Code then shows no colour at all.
const NOT_OURS = ("NO_COLOR", "FORCE_COLOR", "CLICOLOR", "CLICOLOR_FORCE", "COLORFGBG", "TERM_PROGRAM_VERSION", "TERM_SESSION_ID",
                  "TERMINFO", "WINDOWID", "COLUMNS", "LINES", "CI", "CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT", "CLAUDE_CODE_SESSION_ID",
                  "CLAUDE_CODE_CHILD_NOTES_DIR", "CLAUDE_CODE_SSE_PORT", "AI_AGENT")
const NOT_OURS_STARTS = ("GHOSTTY_", "ITERM_", "KITTY_", "WEZTERM_", "ALACRITTY_", "VTE_", "TMUX")

"""
What a program in the terminal finds in its environment: what Ladder has,
without what describes the place that Ladder itself was started from, and
with the names that say what kind of terminal this is. A Ladder that the
Finder started has no language set, so text is said to be UTF-8.
"""
surroundings(extra=()) = begin
  env = Dict{String,String}(k => v for (k, v) in ENV if !(k in NOT_OURS) && !any(p -> startswith(k, p), NOT_OURS_STARTS))
  env["TERM"] = "xterm-256color"
  env["COLORTERM"] = "truecolor"
  env["TERM_PROGRAM"] = "Ladder"
  any(k -> !isempty(get(env, k, "")), ("LC_ALL", "LC_CTYPE", "LANG")) || (env["LANG"] = "en_US.UTF-8")
  for (k, v) in extra
    env[k] = v
  end
  env
end

"The shell that the person uses, with what makes it read their settings as a terminal app's shell does"
shell() = begin
  sh = get(ENV, "SHELL", "")
  [isfile(sh) ? sh : "/bin/zsh", "-l"]
end

const io_moved = Ref(false)

# A built app starts with what this held while it was built
__init__() = (io_moved[] = false; nothing)

"""
Give Julia's reading and writing a thread of its own, once. Without it, what
a program writes is read only when the main thread stops to look, and a
window that waits for input doesn't. A Julia that can't do this reads when
the window next draws.
"""
own_io!() = begin
  io_moved[] && return
  io_moved[] = true
  isdefined(Base.Experimental, :make_io_thread) && (try Base.Experimental.make_io_thread() catch end)
  nothing
end

"""
Start `command` on a pseudo-terminal of `rows` lines and `cols` cells, in the
folder `dir`. `env` adds names to its environment. `wake` is called, from
another thread, each time the program has written more and when it ends.
"""
start(command::Vector{String}=shell(); dir=homedir(), rows=24, cols=80, env=(), wake=() -> nothing) = begin
  own_io!()
  fd = ccall(:posix_openpt, Cint, (Cint,), O_RDWR | O_NOCTTY)
  fd == -1 && error("This Mac gave no pseudo-terminal.")
  if ccall(:grantpt, Cint, (Cint,), fd) != 0 || ccall(:unlockpt, Cint, (Cint,), fd) != 0
    ccall(:close, Cint, (Cint,), fd)
    error("The pseudo-terminal can't be used.")
  end
  name = unsafe_string(ccall(:ptsname, Cstring, (Cint,), fd))
  io = Base.TTY(RawFD(fd))
  # `detach` gives the program a session of its own, which is what lets the pseudo-terminal control it
  cmd = Cmd(Cmd(["/bin/sh", "-c", BECOME, name, string(rows), string(cols), command...]); detach=true, env=surroundings(env), dir=isdir(dir) ? dir : homedir())
  process = try
    run(pipeline(cmd, stdin=devnull, stdout=devnull, stderr=devnull), wait=false)
  catch
    close(io)
    rethrow()
  end
  s = Shell(fd, io, process, UInt8[], ReentrantLock(), Channel{Vector{UInt8}}(Inf), wake, false)
  Threads.@spawn read_all!(s)
  Threads.@spawn write_all!(s)
  # The reading ends when the last program that has the terminal lets go of it. A shell can end and leave one behind,
  # like a job that it started with &. So the end of the shell itself wakes the window too, a moment after, when what
  # it last wrote has been read.
  Threads.@spawn (wait(process); sleep(0.05); s.wake())
  s
end

read_all!(s::Shell) = begin
  try
    while !eof(s.io)
      bytes = readavailable(s.io)
      @lock s.lock append!(s.got, bytes)
      s.wake()
      # A program that writes faster than the window reads waits, as it does in any terminal
      while isopen(s.io) && @lock(s.lock, length(s.got)) > MOST_WAITING
        sleep(0.005)
      end
    end
  catch
    # A terminal that closes can end the reading with an error. Either way the program wrote all that it will.
  end
  s.ended = true
  close(s.out)
  s.wake()
  nothing
end

# A program that doesn't read what it's sent, like one that's busy, makes a write wait. So the writes
# wait here and not in the window.
write_all!(s::Shell) = begin
  try
    for bytes in s.out
      write(s.io, bytes)
    end
  catch
  end
  nothing
end

"Send bytes to the program, as typing does"
send!(s::Shell, bytes::Vector{UInt8}) = (isopen(s.out) && !isempty(bytes) && put!(s.out, bytes); s)
send!(s::Shell, words::AbstractString) = send!(s, Vector{UInt8}(codeunits(words)))

"What the program wrote since this was last asked"
Base.take!(s::Shell) = @lock s.lock begin
  bytes = s.got
  s.got = UInt8[]
  bytes
end

"True while the program runs"
alive(s::Shell) = process_running(s.process)

"""
True while a program that the shell started runs in the terminal, like `sleep`
or an editor, and false while the shell waits for a command. The program that
has the terminal's foreground is another than the shell then.
"""
busy(s::Shell) = !s.ended && alive(s) && (group = ccall(:tcgetpgrp, Cint, (Cint,), s.fd); group > 0 && group != getpid(s.process))

"True when the program has ended and all that it wrote has been taken"
done(s::Shell) = !alive(s) && @lock(s.lock, isempty(s.got))

"The number that the program ended with, or nothing while it runs"
status(s::Shell) = alive(s) ? nothing : s.process.exitcode

"Tell the program that its terminal has `rows` lines and `cols` cells now"
Base.resize!(s::Shell, rows::Integer, cols::Integer) = begin
  s.ended || ccall(:ioctl, Cint, (Cint, Culong, Ptr{UInt16}...), s.fd, SET_SIZE, UInt16[rows, cols, 0, 0])
  s
end

"End the program: it's told that its terminal has gone, as when a terminal app's window closes"
stop!(s::Shell) = begin
  alive(s) && (try kill(s.process, Base.SIGHUP) catch end)
  isopen(s.out) && close(s.out)
  isopen(s.io) && close(s.io)
  s
end
