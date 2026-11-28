# What a file adds to Ladder for itself: its commands, and what it does in each frame
#
# A part of Ladder says in its own file which of its functions are commands,
# and what it does in each frame. This file has the lists that they go in, so
# a file that loads early can add to them. commands.jl makes the key bindings
# page's groups from the list of commands, and windows.jl does the work of
# each frame.
#
#     add_command!(push_branch!, name=:push, title="Send the branch's new commits")   # git_page.jl
#     each_frame!(publish_tick!)                                                       # blog_page.jl

@use "./host" open_palette!

export ADDED_COMMANDS, Command, FRAME_TICKS, add_command!, add_commands!, each_frame!, first_words,
       frame_ticks!, list_commands!

# --- commands ----------------------------------------------------------------------------

"""
Something that a key does. `keys` are its shortcuts in the bundle called
Ladder. `run` gets the editor, its window, and true when ⇧ is held to grow
the selection. `call` is the function that the command palette calls, after
it asks for each thing that the function takes. It's nothing for a command
that takes nothing. See "the command palette".
"""
struct Command
  name::Symbol
  title::String   # what the key bindings page calls it
  kind::Symbol
  keys::String
  run::Function
  call::Any
end
Command(name, title, kind, keys, run) = Command(name, title, kind, keys, run, nothing)

"""
Each command that `add_commands!` added, with the name of its group, in the
order that they came: the order that the files load in. A file that loads
before commands.jl adds its commands here before there's a list of every
command, and commands.jl takes them in when it makes that list. A hot reload
makes that list again when a name in it changes, and takes them in again:
see `with_added`.
"""
const ADDED_COMMANDS = Pair{String,Command}[]

"""
Put `commands` in the group called `group` of the commands that the key
bindings page lists, and in the table of every command by its name.
commands.jl makes both, and has this function's method.
"""
function list_commands! end

"What the docstring of `f` starts with, for the title of its command. commands.jl has its method, so a file that loads before commands.jl gives each of its commands a `title`."
function first_words end

"""
Add `commands` to Ladder's commands, in the group called `group` on the key
bindings page. Each is a `Command`: its name, what the page calls it, its
kind, its keys, and what it does. A command that has the name of one that's
in the group takes its place. Two groups can each have a command with one
name: see `COMMANDS`.
"""
add_commands!(group::AbstractString, commands) = begin
  for c in commands
    k = findfirst(((g, o),) -> g == group && o.name == c.name, ADDED_COMMANDS)
    k === nothing ? push!(ADDED_COMMANDS, String(group) => c) : (ADDED_COMMANDS[k] = String(group) => c)
  end
  # Until commands.jl has loaded there are no lists to put them in. It takes them from `ADDED_COMMANDS` when it makes the lists.
  isempty(methods(list_commands!)) || list_commands!(group, commands)
  nothing
end

# --- commands that are functions ---
#
# `add_command!` makes a Julia function a command of the command palette. The
# palette asks for each thing that the function takes, by the argument's name
# and type, and calls the function with them. See "the command palette" for
# how a type is asked for, and how the methods of a function share its chips.
#
#     "Make the page's text `size` pixels tall"
#     text_size!(e, size::Real) = (e.zoom = zoom_for(size); rewrap!(e))
#     add_command!(text_size!)
#
# The command is called Text Size, and it asks for the size, a number. Its row
# says what the function's docstring starts with, or the `title` that
# `add_command!` is given. It has a place on the key bindings page, and its
# keys open the palette with the command taken.
#
# A function that takes a part of a page, a file or a kind of folder is a
# command only while one is in focus, and gets that one:
#
#     "Fetch what's new in a git folder"
#     fetch!(d::GitDirectory) = ...
#     add_command!(fetch!)
#
# See "what's in focus" in the section of the command palette.
#
# The line that makes a function a command is in the function's own file,
# under the function.

"""
Make the function `f` a command, in the group called `group` on the key
bindings page. `name` is the command's name, which the palette shows as
words: the function's own name, without a `!`. `title` says what it does:
the first line of the function's docstring. `kind` says where it works, and
`keys` are its shortcuts, as a `Command` has them.
"""
add_command!(f; name::Symbol=Symbol(rstrip(String(nameof(f)), '!')), title::AbstractString=first_words(f), kind::Symbol=:window,
             keys::AbstractString="", group::AbstractString="Commands that ask for something") =
  add_commands!(group, [Command(name, String(title), kind, String(keys), (e, w, _) -> open_palette!(e, name), f)])

# --- what a file does in each frame ----------------------------------------------------------
#
# Before a window lays out its page, it does what each part of Ladder needs
# in that frame: `describe_window` in windows.jl. Most of that work has an
# order, and `describe_window` calls it by name. A file whose work in a frame
# has no order adds it here, and needs no line in windows.jl:
#
#     "Do the next part of each publishing that's under way"
#     publish_tick!(e) = ...
#     each_frame!(publish_tick!)
#
# Work has no order when it reads nothing that the work of another file
# writes in a frame, and writes nothing that another reads: it only sees to
# things of its own, like a program that it waits for. Work that moves the
# caret, scrolls, changes the page's text or shows another file has an order,
# and stays named in `describe_window`.
#
# `EACH_FRAME`, in editor_type.jl, is the table for code from the startup
# page. It's done after these.

"""
What Ladder's own files do in each frame of each window, before the page is
laid out: `f(e)`, each with its function's name. They're done in this order,
which is the order that `each_frame!` added them in: the order that main.jl
loads the files in, and in a file from its top.
"""
const FRAME_TICKS = Pair{Symbol,Any}[]

"""
Do `f(e)` in each frame of each window, before the page is laid out, after
the ones that were added before. It's for work that doesn't depend on any
other work of the frame. A function with the name of one that's there takes
its place, so a file that loads twice adds its work once.
"""
each_frame!(f) = begin
  name = nameof(f)
  k = findfirst(((n, _),) -> n == name, FRAME_TICKS)
  k === nothing ? push!(FRAME_TICKS, name => f) : (FRAME_TICKS[k] = name => f)
  f
end

"Do what each file added with `each_frame!`, in the order that they were added"
frame_ticks!(e) = foreach(((_, f),) -> f(e), FRAME_TICKS)
