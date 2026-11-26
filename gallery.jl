# A gallery shows the files and the folders of a folder as a grid of small
# squares. In a document it's a code block in the language `gallery`:
#
#     ```gallery
#     in: photos
#     sort: newest
#     size: large
#     plans/front.png
#     ```
#
# `in` names a folder beside the page. An empty block shows what's in the
# page's own folder. Any other line is the path of one file or folder, so a
# block can list what it shows by hand. A block that has such lines and no
# `in` line shows only what it lists. A gallery shows every kind of file:
# pictures, PDF files, videos, pages, code and the rest. It leaves out hidden
# files, whose names start with a dot.
#
# The folder's files are in the order of their names, as a person reads them:
# photo 2 comes before photo 10. The files that the block lists come after
# them, in the order of their lines. `sort: newest` puts every file in the
# order of its date, the newest first.
#
# `size` is small, medium or large, and says how big each square is at the
# least. Without it, the squares are medium.
#
# This file reads and writes those lines, lists the files, and works out the
# grid. It draws nothing.

@use "./numbers" sortkey

"The language of a code block that is a gallery"
const GALLERY = "gallery"

"The sizes that a gallery's squares can be, with the least px that a side of each is"
const SIDES = (small=80, medium=132, large=220)

"The sizes that the small picture of a file can be: how many pixels its longer side has"
const PIXELS = (256, 400, 640, 1024)

"The px between two squares of the grid"
const GAP = 8

mutable struct Gallery
  folder::Union{Nothing,String}   # the folder that `in` names, or nothing when the block has no such line
  sort::Symbol                    # :name or :newest
  size::Symbol                    # a key of SIDES
  listed::Vector{String}          # the files that the block lists by hand, as their lines write them
  other::Vector{String}           # the lines like `key: value` that this file doesn't know, kept as they are
end

Gallery() = Gallery(nothing, :name, :medium, String[], String[])

"""
One square of a gallery: a file or a folder. It has the path, the name, when
it last changed, its kind, and whether a line of the block names it. The kind
is `:picture`, `:folder`, or `:file` for a file of any other kind.
"""
struct Item
  path::String
  name::String
  at::Float64
  kind::Symbol
  listed::Bool
end

"Read a gallery from the lines of its block. A line that it can't read changes nothing."
gallery(lines) = begin
  g = Gallery()
  for line in lines
    text = strip(line)
    isempty(text) && continue
    # A line like `key: value` is never a path. One of the gallery's own keys needs no space after its colon.
    m = something(match(r"^(in|sort|size)\s*:\s*(.*)$"i, text), match(r"^([A-Za-z][\w -]*?)\s*:(?:\s+(.*))?$", text), Some(nothing))
    if m === nothing
      push!(g.listed, String(text))
      continue
    end
    key, value = lowercase(m[1]), String(strip(something(m[2], "")))
    if key == "in"
      g.folder = value in (".", "./") ? "" : String(rstrip(value, '/'))
    elseif key == "sort"
      lowercase(value) in ("newest", "new", "date") && (g.sort = :newest)
      lowercase(value) in ("name", "names") && (g.sort = :name)
    elseif key == "size"
      Symbol(lowercase(value)) in keys(SIDES) && (g.size = Symbol(lowercase(value)))
    else
      push!(g.other, String(text))
    end
  end
  g
end

"The lines of a gallery's block. A gallery that says no more than an empty block says has no lines."
written(g::Gallery) = begin
  out = String[]
  g.folder === nothing || push!(out, isempty(g.folder) ? "in: ." : "in: $(g.folder)")
  g.sort == :name || push!(out, "sort: $(g.sort)")
  g.size == :medium || push!(out, "size: $(g.size)")
  append!(out, g.other)
  append!(out, g.listed)
end

"The size after `size`, for a button that goes round the three sizes: medium, large, small and medium again"
next_size(size::Symbol) = size == :medium ? :large : size == :large ? :small : :medium

"""
The folder whose files the gallery shows, for a page in the folder `dir`.
It's nothing for a gallery that shows only the files that it lists.
"""
folder(g::Gallery, dir) = g.folder === nothing ? (isempty(g.listed) ? String(dir) : nothing) : abspath(joinpath(dir, expanduser(g.folder)))

"What the gallery calls its folder: the name that the block gives it, or “this folder” for the page's own"
folder_name(g::Gallery) = g.folder === nothing || isempty(g.folder) ? "this folder" : g.folder

"True when the name of the file at `path` ends as one of `kinds` does, like .png"
ispicture(path, kinds) = lowercase(splitext(path)[2]) in kinds

"""
The square of the file or the folder at `path`. `pictures` holds the ends of
the names of the files that are pictures, like .png. `listed` is true when a
line of the block names it.
"""
Item(path::AbstractString; pictures, listed=false) = begin
  path = String(rstrip(path, '/'))
  kind = isdir(path) ? :folder : ispicture(path, pictures) ? :picture : :file
  Item(path, basename(path), mtime(path), kind, listed)
end

"""
What the gallery shows, for a page in the folder `dir`. `pictures` holds the
ends of the names of the files that are pictures, like .png. `skip` holds
paths that the gallery leaves out, like the page that holds it. It gives:

- `items`: the files and the folders, in the order that the gallery shows them
- `lost`: the lines of the block that name nothing
- `problem`: why there's nothing to show, or "" when there's something
"""
items(g::Gallery, dir; pictures, skip=()) = begin
  out, lost = Item[], String[]
  skip = Set(abspath(String(p)) for p in skip)
  from = folder(g, dir)
  there = from !== nothing && isdir(from)
  if there
    names = try readdir(from) catch; String[] end
    for name in sort!(names, by=n -> (sortkey(n), n))
      path = joinpath(from, name)
      # A link that leads nowhere isn't there
      startswith(name, '.') || path in skip || !ispath(path) || push!(out, Item(path; pictures))
    end
  end
  for line in g.listed
    path = abspath(joinpath(dir, expanduser(line)))
    if !ispath(path)
      push!(lost, line)
    elseif !any(p -> p.path == rstrip(path, '/'), out)
      push!(out, Item(path; pictures, listed=true))
    end
  end
  g.sort == :newest && sort!(out, by=p -> (-p.at, sortkey(p.name)))
  problem = !isempty(out) ? "" :
            from !== nothing && !there ? "There's no folder called “$(g.folder)” beside this page." :
            from === nothing ? "Nothing to show" : "Nothing in $(folder_name(g))"
  (items=out, lost=lost, problem=problem)
end

"""
How a gallery counts `items`: “12 pictures” when each one is a picture, and
otherwise “3 files”, “2 folders” or “3 files and 2 folders”. A picture is a
file there.
"""
count_words(items) = begin
  said(k, one) = k == 1 ? "1 $one" : "$k $(one)s"
  all(p -> p.kind == :picture, items) && return said(length(items), "picture")
  folders = count(p -> p.kind == :folder, items)
  files = length(items) - folders
  folders == 0 ? said(files, "file") : files == 0 ? said(folders, "folder") : "$(said(files, "file")) and $(said(folders, "folder"))"
end

"What the top of a gallery says: how many files it shows and where they are, like “12 pictures in photos”"
summary(g::Gallery, found) = begin
  shown = found.items
  isempty(shown) && return found.problem
  (g.folder === nothing && !isempty(g.listed)) && return count_words(shown)
  inside = filter(p -> !p.listed, shown)
  rest = length(shown) - length(inside)
  rest == 0 ? "$(count_words(shown)) in $(folder_name(g))" : "$(count_words(inside)) in $(folder_name(g)), and $rest more"
end

"What a gallery says of the lines that name nothing, or \"\" when each line names a file or a folder"
lost_words(lost) = isempty(lost) ? "" : length(lost) == 1 ? "Nothing at $(lost[1])" : "Nothing at " * join(lost[1:end-1], ", ") * " or " * lost[end]

"""
The grid for `n` squares in a block whose squares have `wide` px of room: how
many columns it has, how many rows, and how many px a side of each square is.
It has as many columns as fit, and the squares grow to take all the room, so
the gap between them is always `GAP`.
"""
grid(n::Integer, wide::Real, size::Symbol) = begin
  least = SIDES[size]
  columns = max(1, floor(Int, (wide + GAP) / (least + GAP)))
  side = max(1.0, (wide - GAP * (columns - 1)) / columns)
  (columns=columns, rows=cld(n, columns), side=side)
end

"How tall a grid of `rows` rows is, with squares that are `side` px"
tall(rows::Integer, side::Real) = rows == 0 ? 0.0 : rows * side + (rows - 1) * GAP

"""
The rows of a grid that show between `top` and `bottom`, which are px down
from the top of the grid. It's empty when no row shows there.
"""
rows_between(top::Real, bottom::Real, rows::Integer, side::Real) = begin
  step = side + GAP
  from = max(1, floor(Int, top / step) + 1)
  to = min(rows, floor(Int, bottom / step) + 1)
  from:to
end

"""
How many pixels the longer side of a file's small picture has, for squares
that are `side` px. A square shows the middle of its picture, on a screen with
two pixels to the px, so a picture that's wider than it's tall needs more
pixels than twice the square's px.
"""
pixels(side::Real) = PIXELS[something(findfirst(>=(2.7side), PIXELS), lastindex(PIXELS))]

"The squares of row `r` of a grid with `columns` columns, as places among `n` squares"
row_places(r::Integer, columns::Integer, n::Integer) = (r - 1) * columns + 1:min(r * columns, n)

"""
The part of a picture that's `w` wide and `h` tall that a square shows: the
biggest square in its middle. It's a left, a top, a width and a height.
"""
crop(w::Real, h::Real) = (s = min(w, h); ((w - s) / 2, (h - s) / 2, s, s))

"""
Where a picture that's `w` wide and `h` tall goes in a space that's `wide` by
`high`: as big as fits, with its own shape, in the middle. It's a left and a
top from the corner of the space, a width and a height.
"""
fit(w::Real, h::Real, wide::Real, high::Real) = begin
  k = min(wide / w, high / h)
  ((wide - w * k) / 2, (high - h * k) / 2, w * k, h * k)
end

"""
Copy the file or the folder at `path` into `folder`, and return where it is
now. The folder is made if it isn't there. A file that's in the folder already
stays where it is. If the folder has another file of that name, the copy gets
a number after its name. It's nothing when the file can't be copied.
"""
keep(folder, path) = begin
  path = abspath(rstrip(path, '/'))
  dirname(path) == abspath(folder) && return path
  try
    mkpath(folder)
    stem, ext = isdir(path) ? (basename(path), "") : splitext(basename(path))
    to, n = joinpath(folder, stem * ext), 1
    while ispath(to)
      to = joinpath(folder, "$stem-$(n += 1)$ext")
    end
    cp(path, to)
    to
  catch
    nothing
  end
end
