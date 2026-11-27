# What a thing that a window shows says to an agent, and what it gives the
# agent to work with.
#
# An agent that works beside a page has a tool that runs Julia code inside
# Ladder: see repl.jl. In that code, `shown` is the thing that the window shows
# now, like the editor of a SolidCraft design. An agent can't know every kind of
# thing that Ladder shows, so it asks the thing itself:
#
#     guide(shown)     # what it is, and the functions that read it and change it
#     status(shown)    # what it shows now: what's selected, what isn't saved
#     look()           # a picture of the window, as a PNG file's path
#
# A kind of thing answers with three methods, in a file of its own that holds
# only what agents may call:
#
#     about(v::DesignView) = "A SolidCraft design, in Ladder's editor…"
#     status(v::DesignView) = "81 bodies. Nothing is selected."
#     tools(v::DesignView) = [Tool(bodies, "bodies(shown)", "The design's bodies, as a list"), …]
#
# Ladder gives the agent's code each function of `tools` by its name, so the
# agent calls `bodies(shown)`. `guide` is made from `about` and `tools`.
#
# The agent's code runs in a thread of its own, and in Ladder's sandbox
# (guard.jl). A function of `tools` isn't checked by the sandbox: it's
# Ladder's own code, and what it does is what the agent is offered. So it
# must do only that. It calls `on_main` for anything that touches a window,
# since a window's state is the main thread's alone, and it gives back
# values, like names and numbers, and never a part of the window that a later
# frame makes again.

"""
A function that a thing offers an agent. `use` shows how it's called, like
`bodies(shown)`, and `does` says what it does and gives, in a sentence or two.
The agent's code has `f` by its own name.
"""
struct Tool
  f::Function
  use::String
  does::String
end

"What `x` is and how an agent works with it, in a few sentences, or \"\" when Ladder has nothing to say of it"
about(x) = ""
about(::Nothing) = "The window shows text, or nothing that Ladder can say more of. Read and change its file with your own tools."

"The functions that `x` offers an agent: a list of `Tool`"
tools(x) = Tool[]

"What `x` shows now, in words: what's selected, what's open, what isn't saved. It goes to the agent with each thing that you say."
status(x) = ""

"What `x` is, how an agent works with it, and each function that it offers"
guide(x) = begin
  said = about(x)
  offered = tools(x)
  isempty(offered) && return isempty(said) ? "Ladder has no functions for this. Read and change its file with your own tools." : said
  list = join(("- `$(t.use)`: $(t.does)" for t in offered), "\n")
  (isempty(said) ? "" : said * "\n\n") * "Its functions:\n\n" * list
end

# --- what the agent's code is given while it runs ---

"What the code that runs now prints with `print` and `println`. repl.jl gives each run its own."
const OUT = Base.ScopedValues.ScopedValue{Any}(nothing)

"What saves a picture of the window that the code's session is in, and gives the file's path. repl.jl gives each run its session's."
const LOOK = Base.ScopedValues.ScopedValue{Any}(nothing)

"Print `xs` for the agent to read, with what the code comes to"
say(xs...) = (io = OUT[]; io === nothing || print(io, xs...); nothing)
sayln(xs...) = say(xs..., '\n')

"""
Save a picture of the window as it is now, and give the path of the PNG
file. An agent reads the file to see what the user sees.
"""
look() = begin
  f = LOOK[]
  f === nothing && error("No window shows beside this session, so there's nothing to take a picture of.")
  f()
end

"""
Run `f` on the main thread, which draws the windows, and give what `f` gives.
The code of a page and the code of an agent each run in a thread of their
own, and anything that acts on a window calls this, since AppKit and the
state of a window are the main thread's alone. The main thread runs `f`
between two frames.
"""
on_main(f) = begin
  Threads.threadid() == 1 && return f()
  t = Task(f)
  t.sticky = true
  ccall(:jl_set_task_tid, Cint, (Any, Cint), t, 0)
  schedule(t)
  try
    fetch(t)
  catch err
    err isa TaskFailedException ? throw(err.task.exception) : rethrow()
  end
end
