# The sites that you chose as favourites, apart from the window that shows
# them. main.jl shows them as icons on a desktop, when the window shows the
# browser folder.
#
# Ladder keeps them in a page of Markdown, `Favourites.md`, at the top of the
# browser folder. Each site is a link on a line of a list, so you change them
# as you change any page: the words of a link are the name under its icon.
#
#     - [Hacker News](https://news.ycombinator.com/)
#     - [Julia](https://julialang.org/)
#
#     list(file)                                    # [Site("Hacker News", "https://news.ycombinator.com/"), ...]
#     add!(file, "Hacker News", "https://news.ycombinator.com/")
#     remove!(file, "https://news.ycombinator.com/")
#
# The page can have other lines too, like a heading or a note. Ladder reads
# only the links of its lists, and leaves the other lines as they are.

@use "../web/url" site_name

"The name of the page that keeps the favourite sites, at the top of the browser folder"
const NAME = "Favourites.md"

"What Ladder writes at the top of the page, when it makes it"
const TOP = """
  # Favourites

  The sites that show on the page of the browser folder. Each link is one: its words are the name under its icon.

  """

"A favourite site: the name under its icon, and its web address"
struct Site
  name::String
  address::String
end

# A link on a line of a list: `- [words](https://…)`. The words can have a \] in them.
const LINK = r"^\s*[-*+]\s+\[((?:[^\]\\]|\\.)*)\]\(\s*<?(https?://[^\s<>()]+)>?\s*\)"i

"The words of a link, without the \\ that a [ or a ] in them has"
unescaped(s::AbstractString) = replace(s, r"\\(.)" => s"\1")

"The words `s`, as the words of a link: a [ or a ] has a \\ before it"
escaped(s::AbstractString) = replace(s, r"([\\\[\]])" => s"\\\1")

"The name of the site of the web address `address`, like example.com, or `address` itself when it isn't a web address"
host(address::AbstractString) = (name = site_name(address); isempty(name) ? String(address) : name)

"""
The web address `address`, as Ladder compares it with another: the scheme and
the computer's name in small letters, and no / at its end. So
https://Example.com/ and https://example.com are one site.
"""
same(address::AbstractString) = begin
  m = match(r"^(https?://[^/?#]*)(.*)$"i, address)
  m === nothing ? String(address) : lowercase(m[1]) * rstrip(m[2], '/')
end

"The number of each line of `lines` that's a link on a line of a list, with what the link matched. A line in a block of code isn't one."
links(lines) = begin
  out = Tuple{Int,RegexMatch}[]
  code = false
  for (i, line) in enumerate(lines)
    startswith(lstrip(line), "```") && (code = !code; continue)
    code && continue
    m = match(LINK, line)
    m === nothing || push!(out, (i, m))
  end
  out
end

# What each page of favourites listed, with the time that the page had changed when it was read. The
# star in the top bar asks on each frame, so the page is read again only when it has changed.
const READ = Dict{String,Tuple{Float64,Vector{Site}}}()

"""
The favourite sites that the page at `file` lists, in its order. A site that
comes twice counts once. Two sites with one name are told apart by a number
after the second one's name, since the desktop knows an icon by its name.
"""
list(file::AbstractString) = begin
  at = mtime(file)   # 0.0 for a page that isn't there
  kept = get(READ, file, nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  sites = read_sites(file)
  READ[file] = (at, sites)
  sites
end

"The favourite sites of the page at `file`, read from it now"
read_sites(file::AbstractString) = begin
  sites = Site[]
  lines = try readlines(file) catch; return sites end   # a page that isn't there, or that the Mac won't let Ladder read
  names, addresses = Set{String}(), Set{String}()
  for (_, m) in links(lines)
    address = String(m[2])
    same(address) in addresses && continue
    push!(addresses, same(address))
    name = String(strip(unescaped(m[1])))
    isempty(name) && (name = host(address))
    first, n = name, 1
    while name in names
      n += 1
      name = "$first $n"
    end
    push!(names, name)
    push!(sites, Site(name, address))
  end
  sites
end

"True when the page at `file` lists the site at `address`"
isfavourite(file::AbstractString, address::AbstractString) = any(s -> same(s.address) == same(address), list(file))

"""
Put the site at `address` at the end of the page at `file`, as a link with the
words `name`. It makes the page when it isn't there. A site that the page has
already stays as it is. It's true when the page changed.
"""
add!(file::AbstractString, name::AbstractString, address::AbstractString) = begin
  isfavourite(file, address) && return false
  name = replace(strip(name), r"\s+" => " ")
  text = isfile(file) ? read(file, String) : TOP
  isempty(text) || endswith(text, '\n') || (text *= "\n")
  mkpath(dirname(file))
  write(file, text * "- [" * escaped(isempty(name) ? host(address) : name) * "](" * address * ")\n")
  true
end

"Take the site at `address` off the page at `file`: each line of a list that links to it. It's true when the page changed."
remove!(file::AbstractString, address::AbstractString) = begin
  isfile(file) || return false
  lines = readlines(file, keep=true)
  gone = Set(i for (i, m) in links(lines) if same(m[2]) == same(address))
  isempty(gone) && return false
  write(file, join(line for (i, line) in enumerate(lines) if !(i in gone)))
  true
end
