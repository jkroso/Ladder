# A page that an agent and you work on together. An agent is a program like
# Claude Code that writes a Markdown file, shows it to you in Ladder and
# waits. You read the page, change it, and send it back.
#
# The agent waits by running `ladder wait page.md` (the script is in
# plugin/bin). That script and Ladder talk through files in one folder:
#
#     ~/Library/Application Support/Ladder/agents/
#       4711.wait   the script wrote it. 4711 is the script's process. Its first
#                   line is the page's path, and its second is the agent's name.
#       4711.seen   Ladder wrote it, to say that it knows the script is waiting
#       812.app     Ladder wrote it as it opened. 812 is Ladder's process. While
#                   that runs, the script keeps waiting for a Ladder that's busy,
#                   like one that waits for you to answer a question from macOS.
#       4711.sent   Ladder wrote it when you sent the page. It holds what you
#                   changed. The script prints it and stops.
#
#     waiting("/notes/plan.md")   # the agents that wait for that page
#     send(waiter, text)          # give one of them what you changed
#     report(path, told, lines)   # what you changed, as the agent reads it
#     request(path, told, lines, words, things)   # a change you asked for, as the agent reads it
#     answer-….md  an agent wrote it: its answer to a question that you asked
#                  in place. The request names the file. See `answer_file`.

@use "./merge" unified

"A test names a folder of its own here, to keep out of the real one"
const place = Ref("")

"The folder that the script and Ladder talk through"
folder() = isempty(place[]) ? joinpath(homedir(), "Library", "Application Support", "Ladder", "agents") : place[]

"An agent that's waiting for you to send a page"
struct Waiter
  file::String   # its .wait file
  page::String   # the page it waits for
  name::String   # what to call the agent, like "Claude"
end

"""
Say that this Ladder is open and can send a page to an agent, with a file
that's named for its process. It does nothing the second time.
"""
announce(dir=folder()) = begin
  file = joinpath(dir, "$(getpid()).app")
  isfile(file) && return
  try
    mkpath(dir)
    touch(file)
  catch
  end
  nothing
end

"True while process `pid` runs"
running(pid::Integer) = ccall(:kill, Cint, (Cint, Cint), pid, 0) == 0

"""
Every agent that's waiting, for any page. Each one is told that Ladder has
seen it. The files of a script that has stopped are removed.
"""
waiters(dir=folder()) = begin
  out = Waiter[]
  isdir(dir) || return out
  for name in readdir(dir)
    file = joinpath(dir, name)
    # Each file's name starts with the process of the script that it's for
    pid = tryparse(Int, first(split(name, '.')))
    pid === nothing && continue
    running(pid) || (rm(file, force=true); continue)
    endswith(name, ".wait") || continue
    lines = try readlines(file) catch; String[] end
    isempty(lines) && continue
    isfile(mark(file, "seen")) || try touch(mark(file, "seen")) catch end
    push!(out, Waiter(file, lines[1], length(lines) > 1 && !isempty(lines[2]) ? lines[2] : "the agent"))
  end
  out
end

"The file beside a .wait file that ends in `kind`"
mark(file, kind) = chop(file, tail=4) * kind

"The agents that wait for the page at `path`"
waiting(path, dir=folder()) = begin
  isempty(path) && return Waiter[]
  all = waiters(dir)
  isempty(all) && return all
  real = ispath(path) ? realpath(path) : abspath(path)
  filter(w -> w.page == real, all)
end

"Give `w` the text `text`. Its script prints the text and stops waiting."
send(w::Waiter, text) = begin
  # The script reads the file as soon as it's there, so it gets its name when it's whole
  part = mark(w.file, "part")
  write(part, text)
  mv(part, mark(w.file, "sent"), force=true)
  # It waits no longer. The script removes its other files as it stops.
  rm(w.file, force=true)
end

"""
What the agent reads when you send the page at `path`: the lines you changed
since the text that the agent last knew, `told`. `lines` is the page as it is
now. `selected` is the text that's selected, if any, and `line` is the line
that it starts on.
"""
report(path, told, lines, line::Int=0, selected="") = begin
  io = IOBuffer()
  println(io, "The user sent ", path, " from Ladder.")
  println(io)
  diff = unified(told, lines)
  if isempty(diff)
    println(io, "The user changed nothing in it.")
  else
    println(io, "What the user changed since your last version of the file (- is your line, + is the user's):")
    println(io)
    print(io, diff)
  end
  if !isempty(selected)
    println(io)
    println(io, "The user selected this text, at line ", line, ":")
    println(io)
    println(io, selected)
  end
  String(take!(io))
end

"""
What the agent reads when you ask it for a change from the page at `path`, in
your words `words`. `things` are what you marked in the window, each already
in words for the agent, and the first is A. `talk` is what you asked about
them before, or "". Then come the lines that you changed since the text that
the agent last knew, `told`. `lines` is the page as it is now. With
`question` true, the words can ask a question as well as for a change. The
agent then writes its answer to the file `reply`, and Ladder shows it under
the things.
"""
request(path, told, lines, words, things, talk=""; question=false, reply="") = begin
  io = IOBuffer()
  println(io, question ? "The user asked you for a change, or asked you a question, from Ladder, on the page " :
                         "The user asked you for a change from Ladder, on the page ", path, ".")
  println(io)
  println(io, "The user's words: ", words)
  if !isempty(things)
    println(io)
    println(io, length(things) == 1 ? "The user marked this thing in the window as A:" :
                "The user marked these things in the window with letters, and the words can name them by their letters:")
    for (n, thing) in enumerate(things)
      println(io)
      println(io, 'A' + n - 1, ": ", thing)
    end
  end
  isempty(talk) || print(io, talk)
  diff = unified(told, lines)
  if !isempty(diff)
    println(io)
    println(io, "What the user changed in the page since your last version of it (- is your line, + is the user's):")
    println(io)
    print(io, diff)
  end
  if question
    println(io)
    if isempty(reply)
      println(io, "If the words ask a question, answer it in your reply, and change no file.")
    else
      println(io, "If the words ask a question, write your answer to the file ", reply, ", in a few short sentences of Markdown, and change no other file. Ladder shows the answer under what the user marked. Then run `ladder wait` again.")
    end
  end
  String(take!(io))
end

"""
A new file in the agents' folder for an agent's answer to a question. Its
name doesn't start with a number, so `waiters` leaves it alone.
"""
answer_file(dir=folder()) = joinpath(dir, "answer-$(getpid())-$(round(Int, time() * 1000)).md")
