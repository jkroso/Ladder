# What git says of a folder or a file of a repository, where Ladder shows it:
# the letters at the end of its row in the sidebar and in the page of a
# folder, like M for a change, and the bar at the top of a repository's page,
# which says how many of its files have changes. git.jl asks git. main.jl's
# git panel, its page of a repository and the page of a folder of notes use
# them.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"...
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI handled describe
@use "github.com/jkroso/UI.jl/Interface/draw" cursor ishovered redraw_in!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use "./git" => Git
@use "./base" exports...

export GIT_TOPS, git_top, watch_git!, GIT_LETTERS, GIT_WORDS, GIT_LIST_FRESH, git_marks, GitBar, changes_words

"The top folder of the repository of each folder that was asked about, and when it was looked for"
const GIT_TOPS = Dict{String,Tuple{Float64,String}}()

"The top folder of the repository that the folder `dir` is in, or \"\" when it's in none. It's looked for again after 5 seconds."
git_top(dir) = begin
  kept = get(GIT_TOPS, dir, nothing)
  kept !== nothing && time() - kept[1] < 5 && return kept[2]
  length(GIT_TOPS) > 2000 && empty!(GIT_TOPS)
  top = Git.top(dir)
  GIT_TOPS[dir] = (time(), top)
  top
end

"""
What git says about the repository whose top folder is `root`, as it last said
it. The window draws again when git has a newer answer: soon while git runs,
and after `fresh` seconds otherwise.
"""
watch_git!(e, root; fresh=Git.FRESH) = begin
  s = Git.state(root; fresh)
  # git's answer is read by a task, which gets its turn here
  Git.busy() ? (yield(); redraw_in!(e, 0.05)) : redraw_in!(e, fresh + 0.1)
  s
end

"The letter that the sidebar has for each change of a file"
const GIT_LETTERS = Dict(:changed => "M", :added => "A", :new => "U", :deleted => "D", :renamed => "R", :clash => "!")

"What the repository's page calls each change of a file"
const GIT_WORDS = Dict(:changed => "Changed", :added => "Added", :new => "New", :deleted => "Deleted", :renamed => "Renamed", :clash => "In two forms")

"How many seconds the branch of a repository in a list of folders stays good. A folder can hold many repositories, and each look starts a git."
const GIT_LIST_FRESH = 30.0

"""
What follows the name of `o` in the sidebar when git keeps it. The top folder
of a repository has its branch and how many files have changes. A file with
changes has its letter, and a folder with such a file in it has a dot.
"""
git_marks(e, o::FSObject) = begin
  path = string(o.path)
  root = git_top(o isa AbstractDirectory ? path : dirname(path))
  isempty(root) && return ()
  if root == path
    # Its row is in the list of the folder that it's in, which can hold many repositories
    s = watch_git!(e, root, fresh=GIT_LIST_FRESH)
    s.known || return ()
    n = length(s.changes)
    return (Box(label(s.branch, 11px, color=colours.faint)),
            (n == 0 ? () : (Box(label(string(n), 11px, color=git_colour(:changed), weight="Semibold")),))...)
  end
  kind = Git.mark(watch_git!(e, root), relpath(path, root))
  kind === nothing && return ()
  kind == :inside && return (Box(width(12px), Box(width(6px), height(6px), radius(3px), background(git_colour(:changed)))),)
  (Box(width(12px), label(GIT_LETTERS[kind], 11px, color=git_colour(kind), weight="Semibold")),)
end

"""
A line over the sidebar's list with the branch of a repository, under the
line of a folder of notes that git keeps. A folder of a repository has none:
git's panel beside the repository's page says it.
"""
@def mutable struct GitBar <: SemanticUI
  root::String = ""
end

"How many files of a repository have changes, in words"
changes_words(n) = n == 1 ? "1 change" : "$n changes"

describe(b::GitBar) = begin
  e = editor(b)
  s = watch_git!(e, b.root)
  n = length(s.changes)
  count(icon, k) = k == 0 ? () : (Row(child_gap=1px, Icon(icon, size=10px, color=colours.dim), Box(label(string(k), 11px, color=colours.dim))),)
  Row(width(grow=grow), height(26px), padding(16px, 0px), child_gap=6px, clip=true, name="Git",
      background(e.buf.path == b.root ? colours.active : ishovered(b) ? colours.hover : clear),
    Icon("git", size=12px, color=colours.dim),
    Box(label(s.known ? s.branch : "…", 12px, color=colours.ink, weight="Medium")),
    count("arrow-up", s.ahead)..., count("arrow-down", s.behind)...,
    Box(width(grow=grow)),
    (n == 0 ? () : (Box(label(changes_words(n), 11px, color=git_colour(:changed))),))...)
end

cursor(::GitBar) = :hand

onkey(b::GitBar, ::KeyPress{Keys.mouse_left}) = (show_beside!(editor(b), b.root); handled)
