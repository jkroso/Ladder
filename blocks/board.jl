# A board shows the to-do items of a page as cards in columns. In a document
# the board is a code block in the language `board`:
#
#     ```board
#     columns: To do, Doing, Done
#
#     Lay the new pipe | Doing
#     ```
#
# `columns` names the columns, from the left. Without it, they are To do,
# Doing and Done. The last column holds the items that are ticked, so a card
# that's moved there ticks its item, and a card that's moved out of it takes
# the tick away. An item that isn't ticked is in the first column, unless a
# line under the columns names another for it: the item's text, a |, and the
# column.
#
# A line like `in: jobs` at the top makes it a board of a folder: it shows the
# to-do items of every page in the folder `jobs` beside the page, and in the
# folders inside that one. `in: .` is the page's own folder. A card that's
# moved to the last column ticks its item in the item's own page. A line of
# the block then names an item by its page and its text, like
# `plans/kitchen: Lay the new pipe | Doing`.
#
# This file reads and writes those lines, and works out the column of each
# item. It draws nothing.

@use "./schedule" Todo todos alike ALIKE

"The language of a code block that is a board"
const BOARD = "board"

"The columns of a board that names none"
const COLUMNS = ["To do", "Doing", "Done"]

mutable struct Board
  columns::Vector{String}
  placed::Vector{Pair{String,String}}   # the items that a line names a column for: each item's name, and the column
  other::Vector{String}                 # the lines at the top that this file doesn't know, kept as they are
end

Board() = Board(copy(COLUMNS), Pair{String,String}[], String[])

same(a::AbstractString, b::AbstractString) = lowercase(strip(a)) == lowercase(strip(b))

"Read a board from the lines of its block"
board(lines) = begin
  b = Board()
  for line in lines
    text = strip(line)
    isempty(text) && continue
    m = isempty(b.placed) ? match(r"^columns\s*:\s*(.*)$"i, text) : nothing
    if m !== nothing
      named = String[strip(c) for c in split(m[1], ',') if !isempty(strip(c))]
      length(named) >= 2 && (b.columns = unique(lowercase, named))
    elseif occursin('|', text)
      name, column = strip.(rsplit(text, '|', limit=2))
      isempty(name) || push!(b.placed, String(name) => String(column))
    elseif isempty(b.placed)
      push!(b.other, String(text))
    end
  end
  b
end

"The lines of a board's block. A board that says no more than an empty block says has no lines."
written(b::Board) = begin
  out = String[]
  b.columns == COLUMNS || push!(out, "columns: " * join(b.columns, ", "))
  append!(out, b.other)
  isempty(b.placed) || push!(out, "", ("$name | $column" for (name, column) in b.placed)...)
  !isempty(out) && isempty(out[1]) ? out[2:end] : out
end

"""
The folder whose pages the board shows the items of, as a line like `in: jobs`
names it: a folder beside the page, or `.` for the page's own folder. It's
nothing for a board of its own page's items.
"""
folder(b::Board) = begin
  for line in b.other
    m = match(r"^in\s*:\s*(.*)$"i, line)
    m === nothing || return (name = String(strip(m[1])); isempty(name) ? "." : name)
  end
  nothing
end

"The place of the column that `name` names, or nothing"
column(b::Board, name::AbstractString) = findfirst(c -> same(c, name), b.columns)

"""
The line of the board that's for each item of the page, by the item's name. An
item whose text was changed in the page keeps its line: a line that names no
item of the page goes to the item with no line whose new text is the most like
that name.
"""
entries(b::Board, items) = begin
  found = Dict{String,Int}()
  keys = Set(t.key for t in items)
  for (j, (name, _)) in enumerate(b.placed)
    name in keys && !haskey(found, name) && (found[name] = j)
  end
  for (j, (name, _)) in enumerate(b.placed)
    name in keys && continue
    best, most = nothing, ALIKE
    for t in items
      haskey(found, t.key) && continue
      like = alike(name, t.key)
      like >= most && ((best, most) = (t.key, like))
    end
    best === nothing || (found[best] = j)
  end
  found
end

"The place of the column that the item `t` is in. `found` holds the line of the board that's for each item, as `entries` gives it."
column(b::Board, t::Todo, found::Dict{String,Int}) = begin
  last = length(b.columns)
  t.done && return last
  k = get(found, t.key, nothing)
  k === nothing && return 1
  c = column(b, b.placed[k].second)
  c === nothing || c == last ? 1 : c
end

"The place of the column that the item `t` is in. `items` holds every to-do item of the page."
column(b::Board, t::Todo, items) = column(b, t, entries(b, items))

"The items of each column, in the order that the page has them"
arrange(b::Board, items) = begin
  out = [Todo[] for _ in b.columns]
  found = entries(b, items)
  foreach(t -> push!(out[column(b, t, found)], t), items)
  out
end

"""
Move the item `t` to column `c`. It gives true when the item's box has to be
ticked, false when its tick has to go, and nothing when its box stays as it is.
"""
move!(b::Board, t::Todo, c::Int, items) = begin
  last = length(b.columns)
  k = get(entries(b, items), t.key, nothing)
  k === nothing || deleteat!(b.placed, k)
  1 < c < last && push!(b.placed, t.key => b.columns[c])
  c == last ? (t.done ? nothing : true) : (t.done ? false : nothing)
end

"Forget the lines of items that the page no longer has, and give an item that was renamed its new name"
prune!(b::Board, items) = begin
  found = entries(b, items)
  b.placed = [t.key => b.placed[found[t.key]].second for t in items if haskey(found, t.key)]
  b
end
