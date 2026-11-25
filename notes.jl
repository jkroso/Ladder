# The links between the pages of a folder of notes, apart from the window that
# shows them. A page links to another with a wiki link, like [[Ideas]], or
# with a Markdown link to its file, like [my ideas](Ideas.md). This file reads
# every page of the folder and says which pages link to which.
#
#     w = web("/Users/jake/Notes")
#     w.notes                    # each page: its path, its name, when it changed, the names it links to
#     linked_from(w, path)       # the pages that link to the page at `path`
#     loose(w)                   # the pages that no page links to
#     w.wanted                   # "Garden" => [pages], for each name that pages link to and no page has
#
# A link's name finds a page as it does in Ladder's editor (`wiki_path` in
# main.jl): a page of that name beside the page with the link comes first, and
# then the page of that name that's nearest the top of the folder. Capitals
# don't count. A name can have folders, like `plans/Garden`.
#
# A page is read once, and again when its file changes. So a look at a folder
# whose pages are the same reads only the folder's list.

@use "github.com/jkroso/Prospects.jl" @def
@use "./folders" => Folders

"The endings of the files that are pages"
const PAGES = (".md", ".markdown", ".mdx")
"The most pages that a folder's web has. A bigger folder gives its first ones."
const MOST = 5000

"A page of a folder of notes"
@def struct Note
  path::String = ""
  name::String = ""                    # its file's name without the ending
  changed::Float64 = 0.0               # when its file last changed
  links::Vector{String} = String[]     # the names and the files that it links to, as it writes them
end

"The pages of a folder of notes and the links between them"
@def struct Web
  root::String = ""
  notes::Vector{Note} = Note[]                                                  # in the order of their names
  to::Dict{String,Vector{String}} = Dict{String,Vector{String}}()               # the paths that each page links to, by its path
  from::Dict{String,Vector{String}} = Dict{String,Vector{String}}()             # the paths that link to each page, by its path
  wanted::Vector{Pair{String,Vector{String}}} = Pair{String,Vector{String}}[]   # each name that no page has, with the pages that link to it
end

ispage(name) = lowercase(splitext(name)[2]) in PAGES

const WIKI = r"\[\[([^\[\]|#\n]*)(?:#[^\[\]|\n]*)?(?:\|[^\[\]\n]*)?\]\]"
const FILE_LINK = r"\]\(<?([^()<>#\s]+?\.(?:md|markdown|mdx))(?:#[^()\s]*)?>?(?:\s+\"[^\"]*\")?\)"i
const CODE_SPAN = r"`[^`\n]*`"

"""
What the page with the text `text` links to: the name of each wiki link, like
`Ideas` or `plans/Garden`, and the file of each Markdown link to a page, like
`../Ideas.md`. Each is there once, in the page's order. A link in a code
block or between two backticks isn't one.
"""
links(text::AbstractString) = begin
  found = String[]
  fence = ""
  for line in eachline(IOBuffer(text))
    s = lstrip(line)
    if isempty(fence)
      m = match(r"^(```+|~~~+)", s)
      m === nothing || (fence = m[1]; continue)
    else
      startswith(s, fence) && isempty(strip(s[nextind(s, 0, length(fence) + 1):end])) && (fence = "")
      continue
    end
    plain = replace(line, CODE_SPAN => "")
    for m in eachmatch(WIKI, plain)
      name = String(strip(m[1]))
      isempty(name) || name in found || push!(found, name)
    end
    for m in eachmatch(FILE_LINK, plain)
      file = String(m[1])
      occursin("://", file) || file in found || push!(found, file)
    end
  end
  found
end

"What each page links to, by its path, with when its file had changed. A page is read again when its file changes."
const READ = Dict{String,Tuple{Float64,Vector{String}}}()

"The files of the pages under `root`, the ones nearest the top first. Hidden folders, the ones that you ignore and `node_modules` are left out."
pages(root::AbstractString) = begin
  found = String[]
  level = [String(root)]
  ignored = Folders.ignored()
  while !isempty(level) && length(found) < MOST
    deeper = String[]
    for dir in level
      names = try sort!(readdir(dir), by=lowercase) catch; String[] end
      for name in names
        startswith(name, '.') && continue
        path = joinpath(dir, name)
        Folders.isignored(path, ignored) && continue
        if isdir(path)
          name == "node_modules" || push!(deeper, path)
        elseif ispage(name)
          push!(found, path)
        end
      end
    end
    level = deeper
  end
  length(found) > MOST ? found[1:MOST] : found
end

"The key of a name or a path that takes no account of capitals, of the ending of a page's file, or of a ./ at the start"
key(s::AbstractString) = begin
  s = lowercase(replace(s, '\\' => '/'))
  while startswith(s, "./")
    s = s[3:end]
  end
  ispage(s) ? splitext(s)[1] : s
end

"""
The path of the page that the link `link` of the page at `from` names, or
nothing when no page has the name. `under` has the paths of the pages by the
key of each end of their path from the root: `garden`, `plans/garden`.
"""
target(link::AbstractString, from::AbstractString, root::AbstractString, under::Dict{String,Vector{String}}) = begin
  # A link to a file is from the page's own folder, and it can go up with ..
  if ispage(link) && (occursin('/', link) || occursin("..", link))
    path = normpath(joinpath(dirname(from), link))
    hit = get(under, key(relpath(path, root)), String[])
    path in hit && return path
  end
  hit = get(under, key(link), String[])
  isempty(hit) && return nothing
  beside = findfirst(p -> dirname(p) == dirname(from), hit)
  beside === nothing ? first(hit) : hit[beside]
end

"The pages under the folder `root` and the links between them"
web(root::AbstractString) = begin
  root = String(rstrip(abspath(root), '/'))
  files = pages(root)
  notes = Note[]
  for path in files
    at = mtime(path)
    kept = get(READ, path, nothing)
    if kept === nothing || kept[1] != at
      kept = (at, try links(read(path, String)) catch; String[] end)
      READ[path] = kept
    end
    push!(notes, Note(path=path, name=splitext(basename(path))[1], changed=at, links=kept[2]))
  end
  # A page that left the folder is forgotten
  length(READ) > 4MOST && empty!(READ)
  # `files` has the pages nearest the top first, so the first page under each key is the nearest
  under = Dict{String,Vector{String}}()
  for path in files
    parts = split(key(relpath(path, root)), '/')
    for i in 1:length(parts)
      push!(get!(() -> String[], under, join(parts[i:end], '/')), path)
    end
  end
  to, from = Dict{String,Vector{String}}(), Dict{String,Vector{String}}()
  wanted = Dict{String,Tuple{String,Vector{String}}}()
  for n in notes
    for link in n.links
      path = target(link, n.path, root, under)
      if path === nothing
        # A link to a file that isn't a page, like [[plan.pdf]], wants no page
        isempty(splitext(link)[2]) || ispage(link) || continue
        name = ispage(link) ? splitext(link)[1] : link
        w = get!(() -> (name, String[]), wanted, key(name))
        n.path in w[2] || push!(w[2], n.path)
      elseif path != n.path
        a, b = get!(() -> String[], to, n.path), get!(() -> String[], from, path)
        path in a || push!(a, path)
        n.path in b || push!(b, n.path)
      end
    end
  end
  sort!(notes, by=n -> (lowercase(n.name), n.path))
  Web(root=root, notes=notes, to=to, from=from,
      wanted=sort!([name => pages for (name, pages) in values(wanted)], by=p -> lowercase(first(p))))
end

"The paths of the pages that link to the page at `path`, in the order of their names"
linked_from(w::Web, path::AbstractString) = sort(get(w.from, path, String[]), by=p -> lowercase(basename(p)))

"The pages that no page links to, in the order of their names"
loose(w::Web) = [n for n in w.notes if !haskey(w.from, n.path)]

"The `n` pages that changed last, the newest first"
latest(w::Web, n::Integer=8) = first(sort(w.notes, by=x -> -x.changed), n)

"The folder of the page at `path`, from the top folder of the notes: `plans/old`, or \"\" for a page at the top"
folder(w::Web, path::AbstractString) = (d = relpath(dirname(path), w.root); d == "." ? "" : d)
