# Links that follow a rename: when a file gets a new name, the links to it in its project change with it

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" focus
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring with_pool
@use "./markdown" Kind classify
@use "./sheet" parts known shown
@use "./merge" changes combine
@use "./base" exports...
@use "./sheet_view" exports...
@use "./find_view" exports...
@use "./page_extras" exports...
@use "./wiki_links" exports...

export FileLink, caret_after, could_name, find_chars, found_beside, link_file, link_path_for,
       links_into, named_links, past_path, relink!, spelled_like, trash, trasher, wiki_name_for,
       with_names, nodes_inside, paths_inside

# --- links that follow a rename ------------------------------------------------------------
#
# When a page or another file gets a new name, or moves to another folder, the
# links to it in the pages of its project change with it, as in Obsidian:
# [[Ideas]] becomes [[Thoughts]], and [see](Ideas.md) becomes [see](Thoughts.md).
# A link keeps the words after its |, the heading after its #, and its form: a
# name with folders, like [[notes/Ideas]], gets the new folders, and a path
# from the page's folder stays a path from the page's folder. A page that moves
# to another folder keeps its own links to files working too. A link in a code
# block or between backticks is code, and stays as it is. A page that's open
# changes in its window, so its changes that aren't saved stay, and its file
# changes too. The window then says how many links changed.
#
# `links_into` reads the pages before the move, while each link still finds the
# file that it names, and `relink!` changes them after the move.

"A link in a page's text to a file: its line, the columns before and after the file's name in it, the name as it's written, whether it's a wiki link, and the file that it names"
struct FileLink
  line::Int
  from::Int
  to::Int
  name::String
  wiki::Bool
  file::String
end

"The index where `delim` next starts in `chars[from:to]`, or 0, as markdown.jl looks for one"
find_chars(chars, delim::String, from, to) = begin
  n = length(delim)
  for i in from:to-n+1
    all(chars[i+k-1] == delim[k] for k in 1:n) && return i
  end
  0
end

"""
The links in `lines` that name a file: each wiki link, like [[Ideas#Plans]] or
![[plan.png]], and each Markdown link to a path, like [see](Ideas.md) or
![a plan](plan.png). Each is its line, the columns before and after the name
of the file, the name, and whether it's a wiki link. A link in a code block or
between backticks is code. A link to a web page, or to a heading of its own
page, names no file.
"""
named_links(lines) = begin
  found = Tuple{Int,Int,Int,String,Bool}[]
  ks = classify(lines)
  for (i, line) in enumerate(lines)
    (ks[i].kind in (Kind.code, Kind.fence) || !occursin('[', line)) && continue
    chars = collect(line)
    n = length(chars)
    j = 1
    while j <= n
      c, next = chars[j], j < n ? chars[j+1] : '\0'
      if c == '\\' && ispunct(next)
        j += 2
      elseif c == '`'
        k = findnext(==('`'), chars, j + 1)
        j = k !== nothing && k > j + 1 ? k + 1 : j + 1
      elseif c == '[' && next == '['
        # A wiki link: the name runs to a | or a #, and a table writes its | as \|
        k = find_chars(chars, "]]", j + 2, n)
        if k == 0 || any(x -> x == '[' || x == ']', @view chars[j+2:k-1])
          j += 1
          continue
        end
        b = something(findnext(x -> x == '|' || x == '#', chars, j + 2), k)
        b = min(b, k) - 1
        b >= j + 2 && chars[b] == '\\' && b + 1 < k && chars[b+1] == '|' && (b -= 1)
        a = j + 2
        while a <= b && isspace(chars[a]); a += 1 end
        while b >= a && isspace(chars[b]); b -= 1 end
        b >= a && push!(found, (i, a - 1, b, String(chars[a:b]), true))
        j = k + 2
      elseif c == '[' && next == '^'
        # [^name] points to a footnote
        k = findnext(==(']'), chars, j + 2)
        j = k !== nothing && k > j + 2 && !any(isspace, @view chars[j+2:k-1]) ? k + 1 : j + 1
      elseif c == '['
        k = find_chars(chars, "](", j + 1, n)
        m = k == 0 ? 0 : find_chars(chars, ")", k + 2, n)
        if k > j + 1 && m != 0
          a = k + 2
          b = something(findnext(x -> x == '#' || isspace(x), chars, a), m) - 1
          b = min(b, m - 1)
          url = String(chars[a:b])
          (b >= a && !occursin("://", url) && !startswith(url, "mailto:") && !startswith(url, '<')) && push!(found, (i, a - 1, b, url, false))
          j = m + 1
        else
          j += 1
        end
      else
        j += 1
      end
    end
  end
  found
end

"What follows `at` in the path `p`, when `p` is `at` or is in the folder `at`: \"\" or \"/notes/a.md\". Capitals don't count, as on a Mac's disk. It's nothing for any other path."
past_path(p, at) = begin
  lp, la = lowercase(p), lowercase(at)
  lp == la && return ""
  (startswith(lp, la * "/") && isvalid(p, ncodeunits(at) + 1)) || return nothing
  p[ncodeunits(at)+1:end]
end

"`new` with each of its parts, from the end, written as the same part of `old` is when the two differ only in capitals. A part that's `keep` stays as it is."
spelled_like(old, new; keep=()) = begin
  a, b = split(old, '/'), String.(split(new, '/'))
  for i in 1:min(length(a), length(b))
    x, y = a[end-i+1], b[end-i+1]
    lowercase(x) == lowercase(y) && !(y in keep) && (b[end-i+1] = x)
  end
  join(b, '/')
end

"""
The name that a wiki link written as `name`, in a page in the folder `dir`,
gives the file at `file`, in the form of `name`: the file's name, the file's
folders too when `name` has folders, or a path from the page's folder when
`name` starts with ./ or ../. A page's name has no .md, unless `name` has
one. When the name finds another file, the folders over it come too, until it
finds this one. A part of `name` that's the same but for capitals keeps its
capitals, unless it's in `keep`.
"""
wiki_name_for(dir, name, file; keep=()) = begin
  plain = lowercase(splitext(file)[2]) == ".md" && !ismarkdown(name)
  shown(p) = spelled_like(name, plain ? String(chop(p, tail=3)) : p; keep)
  if startswith(name, '/') || startswith(name, '~') || startswith(name, "./") || startswith(name, "../")
    out = startswith(name, '/') ? file : startswith(name, '~') && inside_path(file, homedir()) ? "~" * file[ncodeunits(homedir())+1:end] : relpath(file, dir)
    startswith(name, "./") && !startswith(out, "../") && (out = "./" * out)
    return shown(out)
  end
  root = project_root(dir)
  inside_path(lowercase(file), lowercase(root)) || return shown(relpath(file, dir))
  parts = split(relpath(file, root), '/')
  for k in min(count(==('/'), name) + 1, length(parts)):length(parts)
    out = shown(join(parts[end-k+1:end], '/'))
    found = wiki_file(dir, out)
    found !== nothing && lowercase(found) == lowercase(file) && return out
  end
  shown(relpath(file, dir))
end

"The path that a Markdown link written as `url`, in a page in the folder `dir`, gives the file at `file`: from the page's folder, from the top folder, or from the home folder, as `url` is"
link_path_for(dir, url, file; keep=()) = begin
  out = startswith(url, '/') ? file :
        startswith(url, '~') && inside_path(file, homedir()) ? "~" * file[ncodeunits(homedir())+1:end] :
        relpath(file, dir)
  startswith(url, "./") && !startswith(out, "../") && (out = "./" * out)
  escaped(spelled_like(unescaped(url), out; keep))
end

"The file that the Markdown link to `url`, in a page in the folder `dir`, names, as `follow!` finds it, or nothing when it isn't there"
link_file(dir, url) = (path = abspath(dir, expanduser(unescaped(url))); ispath(path) ? path : nothing)

"True when a wiki link to `name` can name what's at `at` by its parts: the file by its name, or a file in the folder when the name has the folder's name in it"
could_name(name, at, folder) = begin
  parts = lowercase.(split(name, '/'))
  folder ? lowercase(basename(at)) in parts[1:end-1] : last(parts) in (lowercase(basename(at)), lowercase(title(at)))
end

"True when a wiki link to `name` finds a file in the folder `dir` itself"
found_beside(name, dir) = any(n -> isfile(abspath(dir, expanduser(n))), ismarkdown(name) ? (name,) : (name * ".md", name))

"""
The pages of the project of the file or folder at `old` that link to it, read
before it moves to `new`. Each is its path, the open page or nothing for its
file, its lines, and its links that name `old` or a file in it. A page that
moves to another folder comes with all its links to files, since a link from
its new folder can need another name. A page that's open in a window comes
as it shows, and its file as it's on the disk.
"""
links_into(e, old, new) = begin
  root = project_root(dirname(old))
  moves = lowercase(dirname(old)) != lowercase(dirname(new))
  folder = isdir(old)
  name = folder ? basename(old) : title(old)
  needles = unique(lowercase.([name, escaped(name)]))
  # A page that moves to another project looks for its wiki links' pages in that one
  shifts = moves && project_root(dirname(new)) != root
  # The pages that are open in a window, in this one first
  shown = Dict{String,Vector{Buffer}}()
  for o in (any(o -> o === e, editors) ? editors : [e; editors]), (p, b) in o.buffers
    (b.view == :markdown && !b.fixed && !isempty(p) && inside_path(p, root)) || continue
    push!(get!(() -> Buffer[], shown, p), b)
  end
  # A look at the project takes a second at most, as a big folder, like the home folder, could take minutes
  pages, _ = pages_under(root; budget=1.0)
  known = Dict{Tuple{String,String,Bool},Union{Nothing,String}}()
  found = NamedTuple{(:path, :buffer, :lines, :links),Tuple{String,Union{Nothing,Buffer},Vector{String},Vector{FileLink}}}[]
  for p in unique([pages; collect(keys(shown))])
    mover = moves && past_path(p, old) !== nothing
    texts = Tuple{Union{Nothing,Buffer},Vector{String}}[]
    isfile(p) && !protected(p) && push!(texts, (nothing, String.(split(try read(p, String) catch; "" end, '\n'))))
    foreach(b -> push!(texts, (b, copy(b.lines))), get(shown, p, Buffer[]))
    for (b, lines) in texts
      mover || any(n -> any(l -> occursin(n, lowercase(l)), lines), needles) || continue
      links = FileLink[]
      for (i, from, to, n, wiki) in named_links(lines)
        # A wiki link to a page that isn't there costs a look through the whole project, so a name that can't be
        # the file's isn't looked for. A page that moves needs its wiki links that find a page beside it, here or there.
        mine = !wiki || could_name(n, old, folder)
        mine || (mover && (shifts || found_beside(n, dirname(p)) || (p == old && found_beside(n, dirname(new))))) || continue
        file = get!(known, (dirname(p), n, wiki)) do
          wiki ? wiki_file(dirname(p), n) : link_file(dirname(p), n)
        end
        file === nothing && continue
        (mover || past_path(file, old) !== nothing) && push!(links, FileLink(i, from, to, n, wiki, file))
      end
      isempty(links) || push!(found, (path=p, buffer=b, lines=lines, links=links))
    end
  end
  found
end

"`lines` with each name that `changes` names in it, its line and the columns around it, in place of the name that's there"
with_names(lines, changes) = begin
  out = copy(lines)
  for (i, from, to, name) in sort(changes, by=c -> (c[1], -c[2]))
    chars = collect(out[i])
    out[i] = String([chars[1:from]; collect(name); chars[to+1:end]])
  end
  out
end

"Where the place `p` of a line is after `changes` put other names in the line. A place inside a name goes to the end of the new name."
caret_after(p, changes) = begin
  i, col = p
  c = col
  for (line, from, to, name) in changes
    (line == i && from < col) || continue
    c += to <= col ? length(name) - (to - from) : from + length(name) - col
  end
  (i, c)
end

"""
Change the links that `links_into` found, now that what was at `old` is at
`new`: in the files of the pages, and in the pages that are open. An open page
keeps its caret where it was, and ⌘Z there takes the change back. The window
says how many links changed, in how many pages.
"""
relink!(e, found, old, new) = begin
  to(p) = (rest = past_path(p, old); rest === nothing ? p : new * rest)
  keep = isdir(new) ? (basename(new),) : (basename(new), title(new))
  changed = Dict{String,Int}()   # the links that changed in each page
  written = Set{String}()
  for t in found
    page = to(t.path)
    dir = dirname(page)
    changes = Tuple{Int,Int,Int,String}[]
    for l in t.links
      file = to(l.file)
      name = l.wiki ? wiki_name_for(dir, l.name, file; keep) : link_path_for(dir, l.name, file; keep)
      name == l.name || push!(changes, (l.line, l.from, l.to, name))
    end
    isempty(changes) && continue
    lines = with_names(t.lines, changes)
    b = t.buffer
    if b === nothing
      try
        write(page, join(lines, "\n"))
        push!(written, page)
      catch
        continue   # the disk said no, so the file stays as it was
      end
    elseif b.lines == t.lines
      clean = !dirty(b)
      caret, anchor = caret_after(b.caret, changes), caret_after(b.anchor, changes)
      lo, hi = extrema(first.(changes))
      edit!(b, (lo, 0), (hi, length(b.lines[hi])), join(lines[lo:hi], "\n"))
      b.caret, b.anchor = caret, anchor
      clean && (b.saved = b.version)   # the file gets the same change, so the page has nothing new to save
    else
      continue
    end
    changed[page] = max(get(changed, page, 0), length(changes))
  end
  # An open page whose file changed knows the file's new text, so it doesn't read the change in again
  for o in (any(o -> o === e, editors) ? editors : [e; editors]), b in values(o.buffers)
    b.path in written && isfile(b.path) || continue
    theirs = text(b.path)
    b.told = combine(b.disk, b.told, theirs, keep=:theirs)
    b.disk = theirs
    READ[b.path] = mtime(b.path)
  end
  n, pages = sum(values(changed), init=0), length(changed)
  n == 0 && return nothing
  place = lowercase(dirname(old)) == lowercase(dirname(new)) ? "name" : "place"
  say_result!(e, "Changed $n link$(n == 1 ? "" : "s") in $pages page$(pages == 1 ? "" : "s") to the new $place")
  nothing
end

"Move the file or the folder at `path` to the Trash. It's true when it went there."
trash(path) = begin
  Sys.isapple() || return false
  try
    with_pool() do
      url = msg(cls("NSURL"), "fileURLWithPath:", nsstring(path))
      ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
            msg(cls("NSFileManager"), "defaultManager"), sel("trashItemAtURL:resultingItemURL:error:"), url, C_NULL, C_NULL)
    end && !ispath(path)
  catch
    false
  end
end

# What moves a file to the Trash. A test puts a function of its own here, so it doesn't fill the Trash.
const trasher = Ref{Function}(trash)

"""
Move the file or the folder at `path` to the Trash and take it out of the
sidebar. A folder goes with everything in it. Changes that aren't saved are
written to their files first, so they are in the Trash too. Their tabs close.
If the file that was showing went, the tab under its tab shows, or with no
other tab open, the next file in the sidebar.
"""
trash!(e, path) = begin
  gone = paths_inside(e.buffers, path)
  foreach(p -> dirty(e.buffers[p]) && save!(e.buffers[p]), gone)
  ispath(path) && !trasher[](path) && return
  at = something(findfirst(==(path), e.files), 1)
  ts = tabs(e)
  # The tabs over the one of the file that shows, that stay open
  over = count(p -> !inside_path(p, path), ts[1:something(findfirst(==(e.buf.path), ts), length(ts) + 1)-1])
  filter!(p -> !inside_path(p, path), ts)
  foreach(p -> delete!(e.buffers, p), gone)
  foreach(p -> delete!(READ, p), paths_inside(READ, path))
  foreach(k -> delete!(e.nodes, k), nodes_inside(e, path))
  # The sidebar never lists a folder that went to the Trash
  inside_path(e.folder, path) && (e.folder = dirname(path))
  list_files!(e)
  if inside_path(e.buf.path, path)
    open!(e, !isempty(ts) ? ts[min(over + 1, end)] : isempty(e.files) ? joinpath(e.folder, "Untitled.md") : e.files[min(at, end)])
  else
    focus(e)
  end
  e
end

"The keys of the editor's nodes that it keeps for a file by its path, for the files at `at`"
nodes_inside(e, at; kinds=(:read, :outline, :fileview)) =
  [k for k in keys(e.nodes) if k isa Tuple{Symbol,String} && k[1] in kinds && inside_path(k[2], at)]

"The keys of `d` that are paths of what's at `at`: `at` itself, and what's in it when it's a folder"
paths_inside(d, at) = [p for p in keys(d) if inside_path(p, at)]
